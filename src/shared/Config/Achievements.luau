--!strict
--[[
	Achievements. Track kinds:
	  Counter  data.Counters[Key] >= Target
	  Min      data.Counters[Key] > 0 and <= Target   (best times, seconds)
	  Level    data.Level >= Target
	  Power    total power >= Target
	  Rebirths data.Rebirths >= Target
	  Owned    number of owned companions >= Target
	  Visited  number of areas visited >= Target
	  Streak   data.Daily.Best >= Target
]]

local Rewards = require(script.Parent.Rewards)

export type AchievementDef = {
	Id: string,
	Name: string,
	Description: string,
	Track: "Counter" | "Min" | "Level" | "Power" | "Rebirths" | "Owned" | "Visited" | "Streak",
	Key: string?,
	Target: number,
	Reward: Rewards.Reward,
	Category: string,
	Order: number,
}

local list: { any } = {
	-- Training
	{ Id = "FirstRep", Name = "First Rep", Description = "Complete your first rep.", Track = "Counter", Key = "Reps", Target = 1, Reward = { Cash = 100 }, Category = "Training" },
	{ Id = "Reps500", Name = "Warming Up", Description = "Complete 500 reps.", Track = "Counter", Key = "Reps", Target = 500, Reward = { Cash = 2500, Trophies = 10 }, Category = "Training" },
	{ Id = "Reps5k", Name = "Grinder", Description = "Complete 5,000 reps.", Track = "Counter", Key = "Reps", Target = 5000, Reward = { Cash = 40000, Trophies = 40 }, Category = "Training" },
	{ Id = "Reps50k", Name = "Iron Will", Description = "Complete 50,000 reps.", Track = "Counter", Key = "Reps", Target = 50000, Reward = { Trophies = 200, Title = "IronAddict" }, Category = "Training" },
	{ Id = "Perfect100", Name = "Clean Reps", Description = "Land 100 Perfect reps.", Track = "Counter", Key = "PerfectReps", Target = 100, Reward = { Cash = 3000, Trophies = 15 }, Category = "Training" },
	{ Id = "Perfect5k", Name = "Perfect Form", Description = "Land 5,000 Perfect reps.", Track = "Counter", Key = "PerfectReps", Target = 5000, Reward = { Trophies = 120, Title = "PerfectForm" }, Category = "Training" },
	{ Id = "Combo25", Name = "In the Zone", Description = "Reach a x25 combo.", Track = "Counter", Key = "BestCombo", Target = 25, Reward = { Cash = 5000, Trophies = 20 }, Category = "Training" },
	{ Id = "Combo75", Name = "Flow State", Description = "Reach a x75 combo.", Track = "Counter", Key = "BestCombo", Target = 75, Reward = { Trophies = 80, Emote = "Salute" }, Category = "Training" },
	{ Id = "Recover200", Name = "Recovery Matters", Description = "Do 200 recovery reps.", Track = "Counter", Key = "RecoveryReps", Target = 200, Reward = { Cash = 8000, Trophies = 20 }, Category = "Training" },
	-- Progression
	{ Id = "Level10", Name = "Regular", Description = "Reach level 10.", Track = "Level", Target = 10, Reward = { Cash = 5000, Trophies = 15 }, Category = "Progress" },
	{ Id = "Level25", Name = "Committed", Description = "Reach level 25.", Track = "Level", Target = 25, Reward = { Cash = 60000, Trophies = 40 }, Category = "Progress" },
	{ Id = "Level50", Name = "Half Century", Description = "Reach level 50.", Track = "Level", Target = 50, Reward = { Trophies = 150 }, Category = "Progress" },
	{ Id = "PowerPro", Name = "Going Pro", Description = "Reach 75K total power.", Track = "Power", Target = 75000, Reward = { Trophies = 60 }, Category = "Progress" },
	{ Id = "PowerLegend", Name = "Living Legend", Description = "Reach 5M total power.", Track = "Power", Target = 5000000, Reward = { Trophies = 250 }, Category = "Progress" },
	{ Id = "Rebirth1", Name = "Reborn", Description = "Rebirth for the first time.", Track = "Rebirths", Target = 1, Reward = { Trophies = 100, Title = "Reborn" }, Category = "Progress" },
	{ Id = "Rebirth5", Name = "Cycle of Iron", Description = "Rebirth 5 times.", Track = "Rebirths", Target = 5, Reward = { Trophies = 400, RebirthTokens = 2 }, Category = "Progress" },
	-- Competition
	{ Id = "Duel1", Name = "Arm Day", Description = "Win an arm-wrestling duel.", Track = "Counter", Key = "DuelWins", Target = 1, Reward = { Trophies = 15 }, Category = "Compete" },
	{ Id = "Duel50", Name = "Arm Wrestler", Description = "Win 50 arm-wrestling duels.", Track = "Counter", Key = "DuelWins", Target = 50, Reward = { Trophies = 150, Title = "ArmWrestler" }, Category = "Compete" },
	{ Id = "Event1", Name = "Competitor", Description = "Win a competition.", Track = "Counter", Key = "EventWins", Target = 1, Reward = { Trophies = 30 }, Category = "Compete" },
	{ Id = "Event25", Name = "Podium Regular", Description = "Finish top 3 in 25 competitions.", Track = "Counter", Key = "EventPodiums", Target = 25, Reward = { Trophies = 160 }, Category = "Compete" },
	{ Id = "Tourney1", Name = "Champion", Description = "Win a gym tournament.", Track = "Counter", Key = "TournamentWins", Target = 1, Reward = { Trophies = 200, Title = "Champion", Aura = "Glint", Decor = "Trophy" }, Category = "Compete" },
	{ Id = "Sprint9", Name = "Speedster", Description = "Run the Yard sprint in under 9 seconds.", Track = "Min", Key = "SprintBest", Target = 9, Reward = { Trophies = 60, Title = "Speedster" }, Category = "Compete" },
	{ Id = "Obstacle40", Name = "Parkour Pro", Description = "Clear the obstacle course in under 40 seconds.", Track = "Min", Key = "ObstacleBest", Target = 40, Reward = { Trophies = 60 }, Category = "Compete" },
	{ Id = "Endure120", Name = "Unbreakable", Description = "Last 120 seconds in Endurance Hold.", Track = "Counter", Key = "EnduranceBest", Target = 120, Reward = { Trophies = 80, Title = "Unbreakable" }, Category = "Compete" },
	-- Social & exploration
	{ Id = "Party1", Name = "Spotter", Description = "Do 100 reps with a party nearby.", Track = "Counter", Key = "PartyReps", Target = 100, Reward = { Cash = 4000, Trophies = 15 }, Category = "Social" },
	{ Id = "Party2k", Name = "Socialite", Description = "Do 2,000 reps with a party nearby.", Track = "Counter", Key = "PartyReps", Target = 2000, Reward = { Trophies = 100, Title = "Socialite" }, Category = "Social" },
	{ Id = "Emote50", Name = "Showboat", Description = "Use emotes 50 times.", Track = "Counter", Key = "EmotesUsed", Target = 50, Reward = { Cash = 6000, Emote = "Victory" }, Category = "Social" },
	{ Id = "Explorer", Name = "Explorer", Description = "Visit 15 different areas.", Track = "Visited", Target = 15, Reward = { Trophies = 60, Title = "Explorer" }, Category = "Social" },
	{ Id = "Collector", Name = "Collector", Description = "Own 5 companions.", Track = "Owned", Target = 5, Reward = { Trophies = 120, Title = "Collector" }, Category = "Social" },
	{ Id = "Streak7", Name = "Dedicated", Description = "Claim daily rewards 7 days in a row.", Track = "Streak", Target = 7, Reward = { Trophies = 50, Title = "Dedicated" }, Category = "Social" },
}

local Achievements = {}
Achievements.List = {} :: { AchievementDef }
Achievements.Defs = {} :: { [string]: AchievementDef }
for i, d in list do
	d.Order = i
	table.insert(Achievements.List, d :: AchievementDef)
	Achievements.Defs[d.Id] = d :: AchievementDef
end

return Achievements
