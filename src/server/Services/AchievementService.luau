--!strict
--[[
	AchievementService: unlocks Config/Achievements automatically.

	Every change to a tracked data root (Counters, Level, Rebirths, Owned,
	Visited, Daily) and every ProgressionService.StatsChanged (total power)
	schedules one debounced evaluation per player. Each newly met achievement:
	  data.Achievements[id] = true
	  ProgressionService.award(player, def.Reward, "Achievement")
	  Notify.event(player, "Achievement", { Id = id })
	When a single pass unlocks several at once (old saves, config additions)
	rewards are granted quietly and the client gets ONE event
	{ Id = first, Ids = { ... } } plus one summary toast instead of a flood.

	AchievementService.progress(def, data) -> (current, target, done) is the
	same rule the client mirrors for progress bars.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local Achievements = require(Config.Achievements)
local DataSchema = require(Shared.DataSchema)
local Progression = require(Config.Progression)

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local Notify = require(script.Parent.Parent.Core.Notify)

type PlayerData = DataSchema.PlayerData
type AchievementDef = Achievements.AchievementDef

local AchievementService = {}
AchievementService.Priority = 45

local DEBOUNCE = 0.75 -- seconds; coalesces rep spam into one pass
local BATCH_AT = 3 -- this many unlocks in one pass => quiet batch

local WATCHED: { [string]: boolean } = {
	Counters = true,
	Level = true,
	Rebirths = true,
	Owned = true,
	Visited = true,
	Daily = true,
}

local scheduled: { [Player]: boolean } = {}

local function countTrue(t: { [string]: boolean }): number
	local n = 0
	for _, v in t do
		if v then
			n += 1
		end
	end
	return n
end

-- Current value for a definition's track, its target and whether it is met.
function AchievementService.progress(def: AchievementDef, data: PlayerData): (number, number, boolean)
	local track = def.Track
	local target = def.Target
	if track == "Counter" then
		local v = data.Counters[def.Key or ""] or 0
		return v, target, v >= target
	elseif track == "Min" then
		-- best times: any recorded time at or under the target
		local v = data.Counters[def.Key or ""] or 0
		return v, target, v > 0 and v <= target
	elseif track == "Level" then
		return data.Level, target, data.Level >= target
	elseif track == "Power" then
		local p = Progression.power(data.Stats :: any)
		return p, target, p >= target
	elseif track == "Rebirths" then
		return data.Rebirths, target, data.Rebirths >= target
	elseif track == "Owned" then
		local n = countTrue(data.Owned.Companions)
		return n, target, n >= target
	elseif track == "Visited" then
		local n = countTrue(data.Visited)
		return n, target, n >= target
	elseif track == "Streak" then
		return data.Daily.Best, target, data.Daily.Best >= target
	end
	return 0, target, false
end

local function evaluate(player: Player)
	scheduled[player] = nil
	if not player.Parent then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local unlocked: { AchievementDef } = {}
	for _, def in Achievements.List do
		if not data.Achievements[def.Id] then
			local _, _, done = AchievementService.progress(def, data)
			if done then
				table.insert(unlocked, def)
			end
		end
	end
	if #unlocked == 0 then
		return
	end

	local batch = #unlocked >= BATCH_AT
	local ids: { string } = {}
	for _, def in unlocked do
		-- flag first: the award below changes watched data and re-schedules us
		DataService.set(player, { "Achievements", def.Id }, true)
		ProgressionService.award(player, def.Reward, "Achievement", batch)
		table.insert(ids, def.Id)
		if not batch then
			Notify.event(player, "Achievement", { Id = def.Id })
		end
	end
	if batch then
		Notify.event(player, "Achievement", { Id = ids[1], Ids = ids })
		Notify.toast(player, `{#ids} achievements unlocked`, "Their rewards have been added to your account.", "Reward")
	end
end

local function schedule(player: Player)
	if scheduled[player] then
		return
	end
	scheduled[player] = true
	task.delay(DEBOUNCE, evaluate, player)
end

function AchievementService.Init()
	DataService.Changed:Connect(function(player: Player, path: { any }, _value: any)
		local root = path[1]
		if type(root) == "string" and WATCHED[root] then
			schedule(player)
		end
	end)
	ProgressionService.StatsChanged:Connect(schedule)
	-- catch up on load (achievements added to the config since the last session)
	DataService.Loaded:Connect(function(player: Player)
		schedule(player)
	end)
end

function AchievementService.Start()
	for _, player in Players:GetPlayers() do
		if DataService.get(player) then
			schedule(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		scheduled[player] = nil
	end)
end

return AchievementService
