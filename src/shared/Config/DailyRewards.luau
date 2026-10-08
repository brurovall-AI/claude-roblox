--!strict
-- 7-day login streak. Missing a day (>48h since last claim) resets to day 1.
-- After day 7 the cycle repeats with a growing multiplier (cycle 2 = x1.5, ...).

local Rewards = require(script.Parent.Rewards)

local DailyRewards = {}

DailyRewards.Days = {
	{ Label = "Cash", Reward = { Cash = 500 } },
	{ Label = "Pre-Workout x2", Reward = { Boosts = { PreWorkout = 2 } } },
	{ Label = "Cash", Reward = { Cash = 2500 } },
	{ Label = "Trophies", Reward = { Trophies = 25 } },
	{ Label = "Boost Pack", Reward = { Boosts = { Protein = 1, Focus = 1, Electrolytes = 1 } } },
	{ Label = "Cash", Reward = { Cash = 10000 } },
	{ Label = "Title + Trophies", Reward = { Trophies = 60, Title = "Dedicated", Emote = "Stretch" } },
} :: { { Label: string, Reward: Rewards.Reward } }

-- Cash rewards scale with level so they stay meaningful.
function DailyRewards.scaled(day: number, cycle: number, level: number): Rewards.Reward
	local base = DailyRewards.Days[day].Reward
	local mult = (1 + 0.5 * (cycle - 1)) * math.max(1, math.pow(level, 1.2) / 4)
	local out: Rewards.Reward = table.clone(base)
	if base.Cash then
		out.Cash = math.floor(base.Cash * mult)
	end
	if base.Trophies then
		out.Trophies = math.floor(base.Trophies * (1 + 0.5 * (cycle - 1)))
	end
	return out
end

return DailyRewards
