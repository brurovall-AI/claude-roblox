--!strict
--[[
	MissionService: daily missions (reset 00:00 UTC), weekly challenges (reset
	Monday 00:00 UTC) and the first-join tutorial reward.

	Rolling: deterministic per player + day / week (the same picks on any server
	that day), filtered by MinLevel, no duplicates, target = Missions.target(t, level).
	Sets are rolled on load and whenever the UTC day / week changes (checked
	every minute for online players and before every progress update or claim).

	Progress: every Core/Events key is matched against the rolled templates'
	Event. "ComboReached" is a high-water mark (amount = combo reached); every
	other key adds `amount`. "StationUsed" (meta.StationType) records the type in
	data.Missions.StationsToday and fires "NewStationToday" the first time a
	type is used that day (the "different machines" mission listens to that).

	Requests:
	  Missions.Claim { Kind = "Daily" | "Weekly", Index }  -> template Reward(level)
	  Missions.ClaimWeeklyBonus                            -> Missions.WeeklyBonusTrophies
	  Tutorial.Complete                                    -> Unlocks.SeenTutorial + starter kit
	Client feedback: GameEvent "MissionComplete" { Kind, Index, Id } when a
	mission reaches its target. All state lives in data.Missions (DataService).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local DataSchema = require(Shared.DataSchema)
local Missions = require(Config.Missions)
local Net = require(Shared.Util.Net)
local Rewards = require(Config.Rewards)

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local Events = require(script.Parent.Parent.Core.Events)
local Notify = require(script.Parent.Parent.Core.Notify)

type PlayerData = DataSchema.PlayerData
type MissionState = DataSchema.MissionState
type Template = Missions.MissionTemplate
type Kind = "Daily" | "Weekly"

local MissionService = {}
MissionService.Priority = 40

local ROLLOVER_CHECK = 60 -- seconds between reset checks for online players
local MAX_AMOUNT = 1e9 -- sanity clamp for a single event amount
local MAX_INDEX = 16
local DAILY_SALT = 17
local WEEKLY_SALT = 9311

-- Keys whose amount is a reached value (best-of) instead of an increment.
local HIGH_WATER: { [string]: boolean } = { ComboReached = true }

local TUTORIAL_REWARD: Rewards.Reward = { Cash = 300, Boosts = { PreWorkout = 1 } }

local byId: { [Kind]: { [string]: Template } } = { Daily = {}, Weekly = {} }
local watched: { [string]: boolean } = {} -- every Event any template listens to

for _, t in Missions.Daily do
	byId.Daily[t.Id] = t
	watched[t.Event] = true
end
for _, t in Missions.Weekly do
	byId.Weekly[t.Id] = t
	watched[t.Event] = true
end

---------------------------------------------------------------------------
-- Rolling
---------------------------------------------------------------------------
local function seedFor(player: Player, period: number, salt: number): number
	-- stays well inside double precision for any UserId / period
	return (player.UserId % 2147483647) * 7 + period * 104729 + salt
end

local function roll(player: Player, pool: { Template }, count: number, period: number, salt: number, level: number): { MissionState }
	local eligible: { Template } = {}
	for _, t in pool do
		if level >= t.MinLevel then
			table.insert(eligible, t)
		end
	end
	-- seeded Fisher-Yates; the first `count` entries are the picks (no duplicates)
	local rng = Random.new(seedFor(player, period, salt))
	for i = #eligible, 2, -1 do
		local j = rng:NextInteger(1, i)
		eligible[i], eligible[j] = eligible[j], eligible[i]
	end
	local out: { MissionState } = {}
	for i = 1, math.min(count, #eligible) do
		local t = eligible[i]
		table.insert(out, { Id = t.Id, Target = Missions.target(t, level), Progress = 0, Claimed = false })
	end
	return out
end

-- A rolled set is stale when it is empty or references a removed template.
local function valid(list: { MissionState }, kind: Kind): boolean
	if #list == 0 then
		return false
	end
	for _, m in list do
		if not byId[kind][m.Id] then
			return false
		end
	end
	return true
end

-- Rerolls whatever is out of date. Cheap when nothing changed.
local function ensureCurrent(player: Player, data: PlayerData)
	local m = data.Missions
	local day = DataSchema.dayNumber()
	local week = DataSchema.weekNumber()
	if m.Day ~= day or not valid(m.Daily, "Daily") then
		if m.Day ~= day then
			DataService.set(player, { "Missions", "StationsToday" }, {})
		end
		DataService.set(player, { "Missions", "Daily" }, roll(player, Missions.Daily, Missions.DailyCount, day, DAILY_SALT, data.Level))
		DataService.set(player, { "Missions", "Day" }, day)
	end
	if m.Week ~= week or not valid(m.Weekly, "Weekly") then
		if m.Week ~= week then
			DataService.set(player, { "Missions", "WeeklyBonusClaimed" }, false)
		end
		DataService.set(player, { "Missions", "Weekly" }, roll(player, Missions.Weekly, Missions.WeeklyCount, week, WEEKLY_SALT, data.Level))
		DataService.set(player, { "Missions", "Week" }, week)
	end
end

---------------------------------------------------------------------------
-- Progress
---------------------------------------------------------------------------
local function advance(player: Player, data: PlayerData, kind: Kind, key: string, amount: number)
	local list = if kind == "Daily" then data.Missions.Daily else data.Missions.Weekly
	for i, m in list do
		local t = byId[kind][m.Id]
		if t and t.Event == key and not m.Claimed and m.Progress < m.Target then
			local value = if HIGH_WATER[key] then math.max(m.Progress, amount) else m.Progress + amount
			value = math.min(m.Target, value)
			if value ~= m.Progress then
				DataService.set(player, { "Missions", kind, i, "Progress" }, value)
				if value >= m.Target then
					Notify.event(player, "MissionComplete", { Kind = kind, Index = i, Id = m.Id })
				end
			end
		end
	end
end

local function onEvent(player: Player, key: string, amount: number, _meta: { [string]: any }?)
	if not watched[key] then
		return
	end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	ensureCurrent(player, data)
	local n = math.min(amount, MAX_AMOUNT)
	advance(player, data, "Daily", key, n)
	advance(player, data, "Weekly", key, n)
end

local function onStationUsed(player: Player, _amount: number, meta: { [string]: any }?)
	local stationType = if meta then meta.StationType else nil
	if type(stationType) ~= "string" or #stationType == 0 or #stationType > 64 then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	ensureCurrent(player, data)
	if data.Missions.StationsToday[stationType] then
		return
	end
	DataService.set(player, { "Missions", "StationsToday", stationType }, true)
	Events.fire(player, "NewStationToday", 1, { StationType = stationType })
end

---------------------------------------------------------------------------
-- Requests
---------------------------------------------------------------------------
local function isIndex(v: any): boolean
	return type(v) == "number" and v == v and v % 1 == 0 and v >= 1 and v <= MAX_INDEX
end

local function claim(player: Player, payload: any): (boolean, any)
	if not Net.allow(player, "Missions.Claim", 3, 6) then
		return false, "Slow down!"
	end
	if type(payload) ~= "table" then
		return false, "Bad request."
	end
	local kindRaw, index = payload.Kind, payload.Index
	if (kindRaw ~= "Daily" and kindRaw ~= "Weekly") or not isIndex(index) then
		return false, "Bad request."
	end
	local kind: Kind = kindRaw
	local data = DataService.get(player)
	if not data then
		return false, "Still loading, try again in a moment."
	end
	ensureCurrent(player, data)
	local list = if kind == "Daily" then data.Missions.Daily else data.Missions.Weekly
	local m = list[index]
	local t = if m then byId[kind][m.Id] else nil
	if not m or not t then
		return false, "That mission has expired."
	end
	if m.Claimed then
		return false, "Already claimed."
	end
	if m.Progress < m.Target then
		return false, "Not finished yet."
	end
	-- mark first so a re-entrant request can never pay twice
	DataService.set(player, { "Missions", kind, index, "Claimed" }, true)
	ProgressionService.award(player, t.Reward(data.Level), if kind == "Daily" then "Daily mission" else "Weekly challenge")
	ProgressionService.count(player, "MissionsClaimed", 1)
	if kind == "Daily" then
		Events.fire(player, "DailyMissionDone", 1, { Id = m.Id })
	end
	return true, { Kind = kind, Index = index }
end

local function claimWeeklyBonus(player: Player, _payload: any): (boolean, any)
	if not Net.allow(player, "Missions.ClaimWeeklyBonus", 1, 3) then
		return false, "Slow down!"
	end
	local data = DataService.get(player)
	if not data then
		return false, "Still loading, try again in a moment."
	end
	ensureCurrent(player, data)
	local m = data.Missions
	if m.WeeklyBonusClaimed then
		return false, "Weekly bonus already claimed."
	end
	if #m.Weekly == 0 then
		return false, "No weekly challenges yet."
	end
	for _, w in m.Weekly do
		if not w.Claimed then
			return false, "Claim every weekly challenge first."
		end
	end
	DataService.set(player, { "Missions", "WeeklyBonusClaimed" }, true)
	ProgressionService.award(player, { Trophies = Missions.WeeklyBonusTrophies }, "Weekly bonus")
	return true, { Trophies = Missions.WeeklyBonusTrophies }
end

local function completeTutorial(player: Player, _payload: any): (boolean, any)
	if not Net.allow(player, "Tutorial.Complete", 0.5, 2) then
		return false, "Slow down!"
	end
	local data = DataService.get(player)
	if not data then
		return false, "Still loading, try again in a moment."
	end
	if data.Unlocks.SeenTutorial then
		return true, { Already = true } -- idempotent: never pays twice
	end
	DataService.set(player, { "Unlocks", "SeenTutorial" }, true)
	ProgressionService.award(player, TUTORIAL_REWARD, "Tutorial complete")
	return true, {}
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
local function sweep()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if data then
			ensureCurrent(player, data)
		end
	end
end

function MissionService.Init()
	Net.handle("Missions.Claim", claim)
	Net.handle("Missions.ClaimWeeklyBonus", claimWeeklyBonus)
	Net.handle("Tutorial.Complete", completeTutorial)

	-- connected in Init so a Loaded that fires during DataService.Start is never missed
	DataService.Loaded:Connect(function(player: Player, data: PlayerData)
		ensureCurrent(player, data)
	end)
	Events.any(onEvent)
	Events.on("StationUsed", onStationUsed)
end

function MissionService.Start()
	sweep()
	while true do
		-- wake right after midnight UTC as well as every minute
		local untilMidnight = 86400 - os.time() % 86400 + 1
		task.wait(math.clamp(untilMidnight, 1, ROLLOVER_CHECK))
		sweep()
	end
end

return MissionService
