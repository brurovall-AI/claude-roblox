--!strict
--[[
	DailyRewardService: 7-day login streak (Config/DailyRewards), UTC days.

	data.Daily = { Streak, Best, LastClaimDay, Cycle }
	  Streak        consecutive days claimed (unbounded); day-in-cycle = (Streak - 1) % 7 + 1
	  Cycle         cycle of the last claim (1 = first week, 2 after day 7, ...)
	  LastClaimDay  DataSchema.dayNumber() of the last claim (0 = never)
	  Best          longest streak ever (Streak achievements)

	Daily.Claim (no payload):
	  claimed today already  -> refused
	  claimed yesterday      -> Streak + 1 (day 7 -> next claim starts the next cycle at day 1)
	  gap > 1 day / never    -> Streak = 1, Cycle = 1
	Reward = DailyRewards.scaled(day, min(cycle, MAX_CYCLE), level); VIP (player
	attribute) adds one Pre-Workout. Fires Events "DailyClaimed" (amount = day).

	DailyRewardService.preview(data, today) is shared logic for what the next
	claim would be (the client window mirrors it).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local DailyRewards = require(Config.DailyRewards)
local DataSchema = require(Shared.DataSchema)
local Net = require(Shared.Util.Net)
local Rewards = require(Config.Rewards)

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local Events = require(script.Parent.Parent.Core.Events)

type PlayerData = DataSchema.PlayerData

local DailyRewardService = {}
DailyRewardService.Priority = 40

-- Reward growth stops after this many cycles (x3 on cash and trophies) so a
-- months-long streak stays generous without breaking the economy.
DailyRewardService.MaxCycle = 5

export type Preview = { Claimable: boolean, Streak: number, Day: number, Cycle: number, Reset: boolean }

-- What the next claim would grant, given the stored state and today's day number.
function DailyRewardService.preview(data: PlayerData, today: number): Preview
	local d = data.Daily
	local last = d.LastClaimDay
	if last >= today and last > 0 then
		local day = (math.max(d.Streak, 1) - 1) % #DailyRewards.Days + 1
		return { Claimable = false, Streak = d.Streak, Day = day, Cycle = math.max(1, d.Cycle), Reset = false }
	end
	local continuing = last > 0 and today - last == 1 and d.Streak > 0
	local streak = if continuing then d.Streak + 1 else 1
	local days = #DailyRewards.Days
	return {
		Claimable = true,
		Streak = streak,
		Day = (streak - 1) % days + 1,
		Cycle = (streak - 1) // days + 1,
		Reset = not continuing and d.Streak > 0,
	}
end

local function rewardFor(player: Player, day: number, cycle: number, level: number): Rewards.Reward
	local reward = DailyRewards.scaled(day, math.min(cycle, DailyRewardService.MaxCycle), level)
	if player:GetAttribute("VIP") == true then
		-- scaled() clones shallowly: copy Boosts before editing so the config is untouched
		local boosts: { [string]: number } = if reward.Boosts then table.clone(reward.Boosts) else {}
		boosts.PreWorkout = (boosts.PreWorkout or 0) + 1
		reward.Boosts = boosts
	end
	return reward
end

local function claim(player: Player, _payload: any): (boolean, any)
	if not Net.allow(player, "Daily.Claim", 1, 3) then
		return false, "Slow down!"
	end
	local data = DataService.get(player)
	if not data then
		return false, "Still loading, try again in a moment."
	end
	local today = DataSchema.dayNumber()
	local p = DailyRewardService.preview(data, today)
	if not p.Claimable then
		return false, "Already claimed today. Come back tomorrow!"
	end
	DataService.set(player, { "Daily" }, {
		Streak = p.Streak,
		Best = math.max(data.Daily.Best, p.Streak),
		LastClaimDay = today,
		Cycle = p.Cycle,
	})
	ProgressionService.award(player, rewardFor(player, p.Day, p.Cycle, data.Level), `Daily reward · Day {p.Day}`)
	ProgressionService.count(player, "DailyClaims", 1)
	Events.fire(player, "DailyClaimed", p.Day, { Streak = p.Streak, Cycle = p.Cycle })
	return true, { Day = p.Day, Cycle = p.Cycle, Streak = p.Streak }
end

function DailyRewardService.Init()
	Net.handle("Daily.Claim", claim)
end

return DailyRewardService
