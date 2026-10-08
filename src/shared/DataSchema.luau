--!strict
--[[
	Persistent player data (DataStore "PlayerData_v1"). The server owns it; the
	client receives a read-only replica (DataController) plus path patches.

	Add new fields here with a default; DataService reconciles old saves.
	Never rename a field without a migration in DataService.migrate().
]]

export type MissionState = { Id: string, Target: number, Progress: number, Claimed: boolean }

export type PlayerData = {
	Version: number,
	Stats: { Strength: number, Endurance: number, Speed: number, Agility: number, Energy: number },
	Level: number,
	XP: number,
	Cash: number,
	Trophies: number,
	RebirthTokens: number,
	Rebirths: number,

	Owned: {
		Gear: { [string]: boolean },
		Companions: { [string]: boolean },
		Auras: { [string]: boolean },
		Titles: { [string]: boolean },
		Emotes: { [string]: boolean },
		Decor: { [string]: boolean },
	},
	Equipped: {
		Gear: { [string]: string }, -- slot -> gear id
		Companions: { string },
		Aura: string,
		Title: string,
		Emotes: { string },
		Decor: { string },
	},

	Boosts: { [string]: number }, -- active boost id -> expiry (os.time)
	BoostInventory: { [string]: number }, -- unused boost id -> count

	Daily: { Streak: number, Best: number, LastClaimDay: number, Cycle: number },
	Missions: {
		Day: number,
		Daily: { MissionState },
		Week: number,
		Weekly: { MissionState },
		WeeklyBonusClaimed: boolean,
		StationsToday: { [string]: boolean },
	},
	Achievements: { [string]: boolean },
	Counters: { [string]: number },
	Visited: { [string]: boolean },
	Unlocks: { [string]: boolean }, -- e.g. VIPTrophy (VIP unlocked with trophies), SeenTutorial
	Settings: {
		Music: number,
		Sfx: number,
		Ambience: number,
		CameraShake: boolean,
		ReducedEffects: boolean,
		ShowCompanions: boolean,
		ShowNameplates: boolean,
	},
	Weekly: { Week: number, XP: number }, -- weekly leaderboard accumulator
	Purchases: { [string]: boolean }, -- processed receipt ids (idempotency)
	FirstJoin: number,
	LastJoin: number,
	PlaySeconds: number,
	Energy: number,
}

local DataSchema = {}

DataSchema.Version = 1

DataSchema.Default = {
	Version = 1,
	Stats = { Strength = 0, Endurance = 0, Speed = 0, Agility = 0, Energy = 0 },
	Level = 1,
	XP = 0,
	Cash = 0,
	Trophies = 0,
	RebirthTokens = 0,
	Rebirths = 0,

	Owned = {
		Gear = {},
		Companions = {},
		Auras = {},
		Titles = { Newcomer = true },
		Emotes = { Wave = true, DoubleBicep = true, Clap = true },
		Decor = {},
	},
	Equipped = {
		Gear = {},
		Companions = {},
		Aura = "",
		Title = "Newcomer",
		Emotes = { "Wave", "DoubleBicep", "Clap" },
		Decor = {},
	},

	Boosts = {},
	BoostInventory = { PreWorkout = 1 },

	Daily = { Streak = 0, Best = 0, LastClaimDay = 0, Cycle = 1 },
	Missions = { Day = 0, Daily = {}, Week = 0, Weekly = {}, WeeklyBonusClaimed = false, StationsToday = {} },
	Achievements = {},
	Counters = {},
	Visited = {},
	Unlocks = {},
	Settings = {
		Music = 0.45,
		Sfx = 0.8,
		Ambience = 0.6,
		CameraShake = true,
		ReducedEffects = false,
		ShowCompanions = true,
		ShowNameplates = true,
	},
	Weekly = { Week = 0, XP = 0 },
	Purchases = {},
	FirstJoin = 0,
	LastJoin = 0,
	PlaySeconds = 0,
	Energy = 100,
} :: PlayerData

-- Day / week numbers (UTC) used for resets.
function DataSchema.dayNumber(t: number?): number
	return math.floor((t or os.time()) / 86400)
end

-- Weeks start Monday 00:00 UTC (epoch was a Thursday, so shift by 3 days).
function DataSchema.weekNumber(t: number?): number
	return math.floor(((t or os.time()) / 86400 + 3) / 7)
end

return DataSchema
