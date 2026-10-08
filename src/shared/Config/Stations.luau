--!strict
--[[
	Training station catalogue. A station in the map is a Model tagged "Station"
	with attributes StationType (key below), Tier (1-6), StationId and AreaId.

	Pose: procedural animation program the client plays on the R15 rig.
	Held: prop welded to the hands while training ("Dumbbells", "Kettlebell", "Log", "Gloves").
	Continuous: cardio-style loop (animation runs constantly at cadence) vs discrete reps.
	Restores: Energy stations refill the energy bar instead of costing energy.
	Sound: SFX family played on each rep (see Config/Sounds).
]]

local Minigames = require(script.Parent.Minigames)

export type PoseId =
	"StandCurl"
	| "StandPress"
	| "Bench"
	| "Squat"
	| "Deadlift"
	| "SeatedPress"
	| "LegPress"
	| "CableFly"
	| "Pulldown"
	| "Hang"
	| "TireFlip"
	| "Row"
	| "Bike"
	| "Ropes"
	| "Run"
	| "Push"
	| "Footwork"
	| "BoxHigh"
	| "Box"
	| "Jump"
	| "Yoga"
	| "SitRelax"
	| "Float"

export type StationDef = {
	Id: string,
	Name: string,
	Stat: string,
	Minigame: Minigames.MinigameKind,
	Pose: PoseId,
	Verb: string,
	Held: string?,
	Continuous: boolean,
	Restores: boolean,
	Gain: number, -- base stat per rep before tier/quality multipliers
	EnergyCost: number, -- energy per rep at tier 1 (scaled by Formulas)
	Sound: string,
	Tiers: { number }, -- tiers this station exists in
}

local S: { [string]: StationDef } = {}

local function def(d: StationDef)
	S[d.Id] = d
end

-- Strength -------------------------------------------------------------------
def({ Id = "DumbbellCurl", Name = "Dumbbell Curl", Stat = "Strength", Minigame = "Timing", Pose = "StandCurl", Verb = "Curl", Held = "Dumbbells", Continuous = false, Restores = false, Gain = 1.0, EnergyCost = 2, Sound = "Iron", Tiers = { 1, 2, 3, 4, 5, 6 } })
def({ Id = "BenchPress", Name = "Bench Press", Stat = "Strength", Minigame = "Timing", Pose = "Bench", Verb = "Bench", Continuous = false, Restores = false, Gain = 1.25, EnergyCost = 2.5, Sound = "Barbell", Tiers = { 1, 2, 3, 4, 5 } })
def({ Id = "SquatRack", Name = "Squat Rack", Stat = "Strength", Minigame = "Charge", Pose = "Squat", Verb = "Squat", Continuous = false, Restores = false, Gain = 1.4, EnergyCost = 3, Sound = "Barbell", Tiers = { 3, 4, 5 } })
def({ Id = "Deadlift", Name = "Deadlift Platform", Stat = "Strength", Minigame = "Charge", Pose = "Deadlift", Verb = "Pull", Continuous = false, Restores = false, Gain = 1.5, EnergyCost = 3.2, Sound = "Drop", Tiers = { 3, 4, 5 } })
def({ Id = "ChestPress", Name = "Chest Press", Stat = "Strength", Minigame = "Timing", Pose = "SeatedPress", Verb = "Press", Continuous = false, Restores = false, Gain = 1.1, EnergyCost = 2, Sound = "Stack", Tiers = { 2, 3, 4 } })
def({ Id = "LegPress", Name = "Leg Press", Stat = "Strength", Minigame = "Charge", Pose = "LegPress", Verb = "Press", Continuous = false, Restores = false, Gain = 1.3, EnergyCost = 2.8, Sound = "Stack", Tiers = { 2, 3, 4 } })
def({ Id = "CableCrossover", Name = "Cable Crossover", Stat = "Strength", Minigame = "Timing", Pose = "CableFly", Verb = "Fly", Continuous = false, Restores = false, Gain = 1.15, EnergyCost = 2.2, Sound = "Stack", Tiers = { 3, 4, 5 } })
def({ Id = "LatPulldown", Name = "Lat Pulldown", Stat = "Strength", Minigame = "Timing", Pose = "Pulldown", Verb = "Pull", Continuous = false, Restores = false, Gain = 1.1, EnergyCost = 2.2, Sound = "Stack", Tiers = { 2, 3, 4 } })
def({ Id = "PullUpBar", Name = "Pull-Up Bar", Stat = "Strength", Minigame = "Timing", Pose = "Hang", Verb = "Pull-up", Continuous = false, Restores = false, Gain = 1.2, EnergyCost = 2.6, Sound = "Grip", Tiers = { 2, 3, 5 } })
def({ Id = "TireFlip", Name = "Tire Flip", Stat = "Strength", Minigame = "Charge", Pose = "TireFlip", Verb = "Flip", Continuous = false, Restores = false, Gain = 1.6, EnergyCost = 3.5, Sound = "Thud", Tiers = { 3, 5 } })
def({ Id = "LogPress", Name = "Log Press", Stat = "Strength", Minigame = "Timing", Pose = "StandPress", Verb = "Press", Continuous = false, Restores = false, Gain = 1.5, EnergyCost = 3.2, Sound = "Thud", Tiers = { 3 } })
def({ Id = "AtlasStone", Name = "Atlas Stone", Stat = "Strength", Minigame = "Charge", Pose = "Deadlift", Verb = "Load", Continuous = false, Restores = false, Gain = 1.7, EnergyCost = 3.6, Sound = "Thud", Tiers = { 3 } })
def({ Id = "GravPress", Name = "Grav-Press", Stat = "Strength", Minigame = "Timing", Pose = "StandPress", Verb = "Press", Continuous = false, Restores = false, Gain = 1.6, EnergyCost = 2.5, Sound = "Tech", Tiers = { 6 } })

-- Endurance ------------------------------------------------------------------
def({ Id = "Rower", Name = "Rowing Machine", Stat = "Endurance", Minigame = "Rhythm", Pose = "Row", Verb = "Row", Continuous = true, Restores = false, Gain = 1.0, EnergyCost = 1.6, Sound = "Rower", Tiers = { 2, 3, 4, 5 } })
def({ Id = "Bike", Name = "Spin Bike", Stat = "Endurance", Minigame = "Rhythm", Pose = "Bike", Verb = "Ride", Continuous = true, Restores = false, Gain = 0.9, EnergyCost = 1.4, Sound = "Bike", Tiers = { 1, 2, 3, 4 } })
def({ Id = "BattleRopes", Name = "Battle Ropes", Stat = "Endurance", Minigame = "Rhythm", Pose = "Ropes", Verb = "Slam", Continuous = true, Restores = false, Gain = 1.15, EnergyCost = 1.9, Sound = "Rope", Tiers = { 2, 3, 5 } })
def({ Id = "HydroRower", Name = "Hydro-Rower", Stat = "Endurance", Minigame = "Rhythm", Pose = "Row", Verb = "Row", Continuous = true, Restores = false, Gain = 1.2, EnergyCost = 1.5, Sound = "Tech", Tiers = { 6 } })

-- Speed ----------------------------------------------------------------------
def({ Id = "Treadmill", Name = "Treadmill", Stat = "Speed", Minigame = "Cadence", Pose = "Run", Verb = "Run", Continuous = true, Restores = false, Gain = 1.0, EnergyCost = 1.5, Sound = "Treadmill", Tiers = { 1, 2, 3, 4, 5 } })
def({ Id = "SledPush", Name = "Sled Push", Stat = "Speed", Minigame = "Cadence", Pose = "Push", Verb = "Drive", Continuous = true, Restores = false, Gain = 1.2, EnergyCost = 2, Sound = "Sled", Tiers = { 2, 3, 5 } })
def({ Id = "HyperTreadmill", Name = "Hyper-Treadmill", Stat = "Speed", Minigame = "Cadence", Pose = "Run", Verb = "Sprint", Continuous = true, Restores = false, Gain = 1.3, EnergyCost = 1.4, Sound = "Tech", Tiers = { 6 } })

-- Agility --------------------------------------------------------------------
def({ Id = "AgilityLadder", Name = "Agility Ladder", Stat = "Agility", Minigame = "Sequence", Pose = "Footwork", Verb = "Drill", Continuous = false, Restores = false, Gain = 1.0, EnergyCost = 1.8, Sound = "Footwork", Tiers = { 1, 2, 3, 5 } })
def({ Id = "SpeedBag", Name = "Speed Bag", Stat = "Agility", Minigame = "Sequence", Pose = "BoxHigh", Verb = "Hit", Held = "Gloves", Continuous = false, Restores = false, Gain = 1.05, EnergyCost = 1.7, Sound = "SpeedBag", Tiers = { 3, 4 } })
def({ Id = "HeavyBag", Name = "Heavy Bag", Stat = "Agility", Minigame = "Sequence", Pose = "Box", Verb = "Strike", Held = "Gloves", Continuous = false, Restores = false, Gain = 1.2, EnergyCost = 2.2, Sound = "Punch", Tiers = { 3, 4 } })
def({ Id = "PlyoBox", Name = "Plyo Box", Stat = "Agility", Minigame = "Sequence", Pose = "Jump", Verb = "Jump", Continuous = false, Restores = false, Gain = 1.1, EnergyCost = 2, Sound = "Land", Tiers = { 1, 2, 3, 5 } })
def({ Id = "ReflexWall", Name = "Reflex Wall", Stat = "Agility", Minigame = "Sequence", Pose = "Box", Verb = "React", Continuous = false, Restores = false, Gain = 1.4, EnergyCost = 1.8, Sound = "Tech", Tiers = { 6 } })

-- Energy (recovery: restores the energy bar while training the Energy stat) ----
def({ Id = "YogaMat", Name = "Yoga Mat", Stat = "Energy", Minigame = "Breath", Pose = "Yoga", Verb = "Flow", Continuous = false, Restores = true, Gain = 1.0, EnergyCost = 0, Sound = "Breath", Tiers = { 1, 3, 4, 5 } })
def({ Id = "Sauna", Name = "Sauna Bench", Stat = "Energy", Minigame = "Breath", Pose = "SitRelax", Verb = "Relax", Continuous = false, Restores = true, Gain = 1.2, EnergyCost = 0, Sound = "Steam", Tiers = { 4 } })
def({ Id = "IceBath", Name = "Ice Bath", Stat = "Energy", Minigame = "Breath", Pose = "SitRelax", Verb = "Plunge", Continuous = false, Restores = true, Gain = 1.3, EnergyCost = 0, Sound = "Water", Tiers = { 4, 5 } })
def({ Id = "CryoPod", Name = "Cryo Pod", Stat = "Energy", Minigame = "Breath", Pose = "Float", Verb = "Recharge", Continuous = false, Restores = true, Gain = 1.4, EnergyCost = 0, Sound = "Tech", Tiers = { 6 } })

local Stations = {}
Stations.Defs = S

function Stations.get(id: string): StationDef?
	return S[id]
end

return Stations
