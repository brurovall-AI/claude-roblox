--!strict
--[[
	Daily missions (3, reset 00:00 UTC) and weekly challenges (5, reset Monday
	00:00 UTC). Each template listens to a server event key (see server
	Core/Events): progress += amount for every matching event.
	Targets and rewards scale with the player's level when rolled.
]]

local Rewards = require(script.Parent.Rewards)

export type MissionTemplate = {
	Id: string,
	Text: string, -- "{n}" is replaced with the target
	Event: string,
	Base: number, -- target at level 1
	PerLevel: number, -- + per level (rounded to a nice number)
	Reward: (level: number) -> Rewards.Reward,
	MinLevel: number,
}

local function cash(mult: number): (number) -> Rewards.Reward
	return function(level: number)
		return { Cash = math.floor(150 * mult * math.pow(1 + level, 1.35)), XP = math.floor(40 * mult * math.pow(1 + level, 1.5)) }
	end
end

local Missions = {}

Missions.DailyCount = 3
Missions.WeeklyCount = 5

Missions.Daily = {
	{ Id = "d_reps", Text = "Complete {n} reps", Event = "Rep", Base = 60, PerLevel = 2, Reward = cash(1), MinLevel = 1 },
	{ Id = "d_perfect", Text = "Land {n} Perfect reps", Event = "PerfectRep", Base = 20, PerLevel = 1, Reward = cash(1.2), MinLevel = 1 },
	{ Id = "d_strength", Text = "Do {n} Strength reps", Event = "Rep:Strength", Base = 35, PerLevel = 1, Reward = cash(1), MinLevel = 1 },
	{ Id = "d_endurance", Text = "Do {n} Endurance reps", Event = "Rep:Endurance", Base = 30, PerLevel = 1, Reward = cash(1), MinLevel = 4 },
	{ Id = "d_speed", Text = "Do {n} Speed reps", Event = "Rep:Speed", Base = 30, PerLevel = 1, Reward = cash(1), MinLevel = 1 },
	{ Id = "d_agility", Text = "Do {n} Agility reps", Event = "Rep:Agility", Base = 25, PerLevel = 1, Reward = cash(1), MinLevel = 1 },
	{ Id = "d_energy", Text = "Do {n} Recovery reps", Event = "Rep:Energy", Base = 15, PerLevel = 0.5, Reward = cash(0.8), MinLevel = 1 },
	{ Id = "d_combo", Text = "Reach a x{n} combo streak", Event = "ComboReached", Base = 10, PerLevel = 0.2, Reward = cash(1.1), MinLevel = 1 },
	{ Id = "d_cash", Text = "Earn ${n} from training", Event = "TrainCash", Base = 400, PerLevel = 120, Reward = cash(1), MinLevel = 1 },
	{ Id = "d_juice", Text = "Grab {n} drinks at the Juice Bar", Event = "BoostBought", Base = 1, PerLevel = 0, Reward = cash(0.7), MinLevel = 2 },
	{ Id = "d_event", Text = "Take part in {n} competitions", Event = "EventJoined", Base = 1, PerLevel = 0, Reward = cash(1.3), MinLevel = 3 },
	{ Id = "d_duel", Text = "Win {n} arm-wrestling duel", Event = "DuelWin", Base = 1, PerLevel = 0, Reward = cash(1.3), MinLevel = 5 },
	{ Id = "d_party", Text = "Do {n} reps with a party nearby", Event = "PartyRep", Base = 40, PerLevel = 1, Reward = cash(1.2), MinLevel = 3 },
	{ Id = "d_course", Text = "Finish the Yard sprint or obstacle course {n} times", Event = "CourseFinish", Base = 2, PerLevel = 0, Reward = cash(1.2), MinLevel = 12 },
	{ Id = "d_variety", Text = "Train on {n} different machines", Event = "NewStationToday", Base = 4, PerLevel = 0.05, Reward = cash(1), MinLevel = 1 },
} :: { MissionTemplate }

Missions.Weekly = {
	{ Id = "w_reps", Text = "Complete {n} reps", Event = "Rep", Base = 1200, PerLevel = 30, Reward = cash(8), MinLevel = 1 },
	{ Id = "w_perfect", Text = "Land {n} Perfect reps", Event = "PerfectRep", Base = 400, PerLevel = 12, Reward = cash(8), MinLevel = 1 },
	{ Id = "w_levels", Text = "Gain {n} levels", Event = "LevelUp", Base = 4, PerLevel = 0, Reward = cash(10), MinLevel = 1 },
	{ Id = "w_podium", Text = "Finish top 3 in {n} competitions", Event = "EventPodium", Base = 3, PerLevel = 0, Reward = cash(12), MinLevel = 1 },
	{ Id = "w_duels", Text = "Win {n} arm-wrestling duels", Event = "DuelWin", Base = 6, PerLevel = 0, Reward = cash(10), MinLevel = 5 },
	{ Id = "w_cash", Text = "Earn ${n} from training", Event = "TrainCash", Base = 15000, PerLevel = 3000, Reward = cash(8), MinLevel = 1 },
	{ Id = "w_party", Text = "Do {n} reps with a party nearby", Event = "PartyRep", Base = 600, PerLevel = 10, Reward = cash(9), MinLevel = 3 },
	{ Id = "w_course", Text = "Finish {n} Yard courses", Event = "CourseFinish", Base = 12, PerLevel = 0, Reward = cash(9), MinLevel = 12 },
	{ Id = "w_daily", Text = "Complete {n} daily missions", Event = "DailyMissionDone", Base = 12, PerLevel = 0, Reward = cash(12), MinLevel = 1 },
} :: { MissionTemplate }

Missions.WeeklyBonusTrophies = 120 -- extra for finishing all weekly challenges

local function nice(n: number): number
	if n < 10 then
		return math.max(1, math.floor(n + 0.5))
	end
	local mag = math.pow(10, math.floor(math.log10(n)) - 1)
	return math.floor(n / mag + 0.5) * mag
end

function Missions.target(t: MissionTemplate, level: number): number
	return nice(t.Base + t.PerLevel * (level - 1))
end

function Missions.find(id: string): MissionTemplate?
	for _, t in Missions.Daily do
		if t.Id == id then
			return t
		end
	end
	for _, t in Missions.Weekly do
		if t.Id == id then
			return t
		end
	end
	return nil
end

return Missions
