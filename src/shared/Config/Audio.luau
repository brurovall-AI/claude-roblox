--!strict
--[[
	Sound design table. Every key maps to one or more variants; the AudioController
	picks a random variant and applies small pitch/volume jitter so repeated
	sounds never feel mechanical.

	Built-in engine sounds (rbxasset://) are used as defaults so the game is
	audible out of the box. For the full experience, replace/add Creator Store
	audio ids (rbxassetid://123...) in the slots marked "ASSET SLOT".
]]

export type SoundDef = { Ids: { string }, Volume: number, Pitch: number, Jitter: number, Rolloff: number? }

local function s(ids: { string }, volume: number, pitch: number?, jitter: number?, rolloff: number?): SoundDef
	return { Ids = ids, Volume = volume, Pitch = pitch or 1, Jitter = jitter or 0.06, Rolloff = rolloff }
end

local CLICK = "rbxasset://sounds/clickfast.wav"
local BUTTON = "rbxasset://sounds/button.wav"
local SWOOSH = "rbxasset://sounds/swoosh.wav"
local PING = "rbxasset://sounds/electronicpingshort.wav"
local VICTORY = "rbxasset://sounds/victory.wav"
local LAND = "rbxasset://sounds/action_jump_land.mp3"
local STEP = "rbxasset://sounds/action_footsteps_plastic.mp3"
local SNAP = "rbxasset://sounds/snap.wav"
local COLLIDE = "rbxasset://sounds/collide.wav"
local SPLASH = "rbxasset://sounds/impact_water.mp3"
local SLASH = "rbxasset://sounds/swordslash.wav"

local Audio = {}

Audio.Sfx = {
	-- UI
	UIClick = s({ CLICK }, 0.35, 1.15, 0.04),
	UIHover = s({ BUTTON }, 0.08, 1.6, 0.03),
	UIOpen = s({ SWOOSH }, 0.18, 1.5, 0.03),
	UIClose = s({ SWOOSH }, 0.14, 1.25, 0.03),
	UINotify = s({ PING }, 0.25, 1.1, 0.02),
	UIError = s({ BUTTON }, 0.3, 0.6, 0.02),
	UIPurchase = s({ PING }, 0.35, 1.35, 0.02),
	Reward = s({ VICTORY }, 0.35, 1.0, 0.0),
	LevelUp = s({ VICTORY }, 0.5, 1.0, 0.0),
	RankUp = s({ VICTORY }, 0.55, 0.85, 0.0),
	Unlock = s({ VICTORY }, 0.5, 0.92, 0.0),

	-- Training feedback
	RepPerfect = s({ PING }, 0.32, 1.55, 0.02),
	RepGood = s({ PING }, 0.18, 1.25, 0.03),
	RepMiss = s({ BUTTON }, 0.2, 0.55, 0.04),
	ComboBreak = s({ SWOOSH }, 0.2, 0.7, 0.03),
	Tick = s({ CLICK }, 0.12, 1.8, 0.05),

	-- Equipment (3D, played at the station). ASSET SLOT: swap in real gym foley.
	Iron = s({ COLLIDE, SNAP }, 0.45, 0.62, 0.08, 40),
	Barbell = s({ COLLIDE }, 0.6, 0.5, 0.07, 50),
	Drop = s({ LAND, COLLIDE }, 0.8, 0.45, 0.06, 60),
	Stack = s({ COLLIDE, SNAP }, 0.4, 0.75, 0.08, 35),
	Grip = s({ SNAP }, 0.25, 0.8, 0.1, 30),
	Thud = s({ LAND }, 0.8, 0.5, 0.08, 60),
	Rower = s({ SWOOSH }, 0.25, 0.55, 0.08, 30),
	Bike = s({ SWOOSH }, 0.12, 0.9, 0.08, 25),
	Rope = s({ SLASH, SWOOSH }, 0.25, 0.6, 0.1, 35),
	Treadmill = s({ STEP }, 0.3, 1.05, 0.08, 30),
	Sled = s({ STEP }, 0.35, 0.7, 0.08, 35),
	Footwork = s({ STEP }, 0.3, 1.25, 0.12, 30),
	SpeedBag = s({ SNAP }, 0.35, 1.2, 0.1, 30),
	Punch = s({ LAND }, 0.45, 0.8, 0.1, 40),
	Land = s({ LAND }, 0.5, 0.85, 0.08, 40),
	Breath = s({ SWOOSH }, 0.12, 0.45, 0.06, 20),
	Steam = s({ SWOOSH }, 0.18, 0.35, 0.06, 25),
	Water = s({ SPLASH }, 0.35, 0.9, 0.1, 30),
	Tech = s({ PING }, 0.18, 0.7, 0.05, 30),

	-- World
	Door = s({ SWOOSH }, 0.3, 0.8, 0.05, 40),
	Elevator = s({ PING }, 0.3, 0.9, 0.0, 40),
	Turnstile = s({ SNAP }, 0.3, 0.7, 0.05, 30),
	Countdown = s({ CLICK }, 0.45, 1.0, 0.0),
	Go = s({ PING }, 0.5, 1.2, 0.0),
	Cheer = s({ VICTORY }, 0.25, 1.2, 0.03, 80),
	Camera = s({ CLICK }, 0.6, 0.7, 0.0),
} :: { [string]: SoundDef }

-- Per-area ambience. Loop: ASSET SLOT for a looping ambience bed (leave "" to
-- skip). OneShots: distant gym life (clanks, footsteps) scheduled randomly
-- around the listener so every area sounds busy without a long audio file.
-- Reverb: SoundService.AmbientReverb preset while inside the area.
export type AmbienceDef = {
	Loop: string,
	LoopVolume: number,
	OneShots: { string }, -- Sfx keys
	Rate: number, -- average one-shots per second
	Reverb: string, -- Enum.ReverbType name
	Music: string, -- music playlist key
}

Audio.Ambience = {
	Lobby = { Loop = "", LoopVolume = 0.3, OneShots = { "Iron", "Footwork" }, Rate = 0.15, Reverb = "Hallway", Music = "Lobby" },
	Lounge = { Loop = "", LoopVolume = 0.3, OneShots = { "Footwork" }, Rate = 0.08, Reverb = "LivingRoom", Music = "Lounge" },
	Lockers = { Loop = "", LoopVolume = 0.25, OneShots = { "Door", "Water" }, Rate = 0.12, Reverb = "Bathroom", Music = "Lounge" },
	Studio = { Loop = "", LoopVolume = 0.25, OneShots = { "Iron", "Land" }, Rate = 0.2, Reverb = "Room", Music = "Train" },
	Cardio = { Loop = "", LoopVolume = 0.3, OneShots = { "Treadmill", "Bike" }, Rate = 0.35, Reverb = "Room", Music = "Train" },
	Weights = { Loop = "", LoopVolume = 0.3, OneShots = { "Iron", "Barbell", "Stack" }, Rate = 0.4, Reverb = "Hangar", Music = "Train" },
	Hall = { Loop = "", LoopVolume = 0.3, OneShots = { "Iron", "Stack", "Thud", "Rope" }, Rate = 0.45, Reverb = "Hangar", Music = "Train" },
	Outdoor = { Loop = "", LoopVolume = 0.35, OneShots = { "Thud", "Footwork" }, Rate = 0.2, Reverb = "Plain", Music = "Outdoor" },
	Concourse = { Loop = "", LoopVolume = 0.25, OneShots = { "Footwork", "Door" }, Rate = 0.1, Reverb = "StoneCorridor", Music = "Lobby" },
	Boxing = { Loop = "", LoopVolume = 0.3, OneShots = { "Punch", "SpeedBag", "Footwork" }, Rate = 0.5, Reverb = "StoneRoom", Music = "Boxing" },
	Recovery = { Loop = "", LoopVolume = 0.25, OneShots = { "Water", "Breath" }, Rate = 0.08, Reverb = "Room", Music = "Calm" },
	Private = { Loop = "", LoopVolume = 0.2, OneShots = { "Iron" }, Rate = 0.1, Reverb = "Room", Music = "Lounge" },
	Arena = { Loop = "", LoopVolume = 0.35, OneShots = { "Cheer", "Barbell" }, Rate = 0.12, Reverb = "Arena", Music = "Arena" },
	Pro = { Loop = "", LoopVolume = 0.3, OneShots = { "Iron", "Stack" }, Rate = 0.35, Reverb = "Hangar", Music = "Train" },
	Foundry = { Loop = "", LoopVolume = 0.35, OneShots = { "Drop", "Barbell", "Iron" }, Rate = 0.5, Reverb = "Hangar", Music = "Heavy" },
	VIP = { Loop = "", LoopVolume = 0.2, OneShots = { "Iron" }, Rate = 0.08, Reverb = "LivingRoom", Music = "Lounge" },
	Rooftop = { Loop = "", LoopVolume = 0.4, OneShots = { "Footwork" }, Rate = 0.12, Reverb = "Plain", Music = "Outdoor" },
	Apex = { Loop = "", LoopVolume = 0.3, OneShots = { "Tech" }, Rate = 0.2, Reverb = "Hallway", Music = "Apex" },
} :: { [string]: AmbienceDef }

-- Music playlists. ASSET SLOT: add licensed tracks from the Creator Store.
-- Empty playlists simply stay silent (ambience still plays).
Audio.Music = {
	Lobby = {},
	Lounge = {},
	Train = {},
	Outdoor = {},
	Boxing = {},
	Calm = {},
	Arena = {},
	Heavy = {},
	Apex = {},
} :: { [string]: { string } }

return Audio
