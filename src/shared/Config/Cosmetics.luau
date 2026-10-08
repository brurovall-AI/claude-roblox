--!strict
--[[
	Cosmetics: auras, titles, emotes and locker decorations. None of these
	affect gains: they are pure expression, earned or bought.
]]

local Currency = require(script.Parent.Currency)

export type AuraDef = { Id: string, Name: string, Description: string, Effect: string, Cost: Currency.Cost?, Source: string, Order: number }
export type TitleDef = { Id: string, Text: string, Color: Color3, Cost: Currency.Cost?, Source: string, Order: number }
export type EmoteDef = { Id: string, Name: string, Pose: string, Cost: Currency.Cost?, Source: string, Loop: boolean, Order: number }
export type DecorDef = { Id: string, Name: string, Visual: string, Cost: Currency.Cost?, Source: string, Order: number }

local Cosmetics = {}

local function index<T>(list: { T }): { [string]: T }
	local out = {}
	for i, d in list do
		(d :: any).Order = i
		out[(d :: any).Id] = d
	end
	return out
end

-- Auras: subtle, low-particle effects (Effect key read by client EffectsController).
Cosmetics.AuraList = {
	{ Id = "Chalk", Name = "Chalk Dust", Description = "A faint drift of chalk from your hands.", Effect = "Chalk", Cost = { Currency = "Cash", Amount = 25000 }, Source = "Shop" },
	{ Id = "Steam", Name = "Post-Set Steam", Description = "Soft heat rising off your shoulders.", Effect = "Steam", Cost = { Currency = "Cash", Amount = 90000 }, Source = "Shop" },
	{ Id = "Embers", Name = "Embers", Description = "A few warm embers around your feet.", Effect = "Embers", Cost = { Currency = "Trophies", Amount = 400 }, Source = "Shop" },
	{ Id = "Frost", Name = "Frost Breath", Description = "Cold air and the occasional ice glint.", Effect = "Frost", Cost = { Currency = "Trophies", Amount = 900 }, Source = "Shop" },
	{ Id = "Glint", Name = "Golden Glint", Description = "Rare golden sparkles. Earned by champions.", Effect = "Glint", Cost = nil, Source = "Tournament" },
	{ Id = "Storm", Name = "Static Charge", Description = "Tiny arcs of static across your arms.", Effect = "Storm", Cost = { Currency = "RebirthTokens", Amount = 2 }, Source = "Shop" },
	{ Id = "Halo", Name = "Olympian Halo", Description = "A thin light ring. Reserved for Olympian rank.", Effect = "Halo", Cost = nil, Source = "Rank" },
} :: { AuraDef }
Cosmetics.Auras = index(Cosmetics.AuraList)

Cosmetics.TitleList = {
	{ Id = "Newcomer", Text = "Newcomer", Color = Color3.fromRGB(200, 200, 204), Cost = nil, Source = "Default" },
	{ Id = "GymRat", Text = "Gym Rat", Color = Color3.fromRGB(170, 200, 150), Cost = { Currency = "Cash", Amount = 5000 }, Source = "Shop" },
	{ Id = "IronAddict", Text = "Iron Addict", Color = Color3.fromRGB(200, 170, 140), Cost = { Currency = "Cash", Amount = 60000 }, Source = "Shop" },
	{ Id = "Dedicated", Text = "Dedicated", Color = Color3.fromRGB(120, 200, 230), Cost = nil, Source = "Daily" },
	{ Id = "PerfectForm", Text = "Perfect Form", Color = Color3.fromRGB(255, 206, 92), Cost = nil, Source = "Achievement" },
	{ Id = "Speedster", Text = "Speedster", Color = Color3.fromRGB(236, 200, 72), Cost = nil, Source = "Achievement" },
	{ Id = "Unbreakable", Text = "Unbreakable", Color = Color3.fromRGB(240, 146, 60), Cost = nil, Source = "Achievement" },
	{ Id = "Explorer", Text = "Explorer", Color = Color3.fromRGB(118, 160, 120), Cost = nil, Source = "Achievement" },
	{ Id = "ArmWrestler", Text = "Arm Wrestler", Color = Color3.fromRGB(232, 92, 74), Cost = nil, Source = "Achievement" },
	{ Id = "Champion", Text = "Tournament Champion", Color = Color3.fromRGB(240, 178, 64), Cost = nil, Source = "Tournament" },
	{ Id = "Reborn", Text = "Reborn", Color = Color3.fromRGB(196, 140, 255), Cost = nil, Source = "Rebirth" },
	{ Id = "Ascended", Text = "Ascended", Color = Color3.fromRGB(150, 230, 255), Cost = { Currency = "RebirthTokens", Amount = 5 }, Source = "Shop" },
	{ Id = "Socialite", Text = "Socialite", Color = Color3.fromRGB(226, 150, 196), Cost = nil, Source = "Achievement" },
	{ Id = "Collector", Text = "Collector", Color = Color3.fromRGB(186, 128, 236), Cost = nil, Source = "Achievement" },
	{ Id = "VIP", Text = "VIP", Color = Color3.fromRGB(46, 160, 110), Cost = nil, Source = "VIP" },
	{ Id = "Olympian", Text = "Olympian", Color = Color3.fromRGB(255, 240, 200), Cost = nil, Source = "Rank" },
} :: { TitleDef }
Cosmetics.Titles = index(Cosmetics.TitleList)

-- Emotes: procedural poses (client EmoteController builds them from Pose keys).
Cosmetics.EmoteList = {
	{ Id = "Wave", Name = "Wave", Pose = "Wave", Cost = nil, Source = "Default", Loop = false },
	{ Id = "DoubleBicep", Name = "Double Bicep", Pose = "DoubleBicep", Cost = nil, Source = "Default", Loop = false },
	{ Id = "Clap", Name = "Clap", Pose = "Clap", Cost = nil, Source = "Default", Loop = true },
	{ Id = "SideChest", Name = "Side Chest", Pose = "SideChest", Cost = { Currency = "Cash", Amount = 3000 }, Source = "Shop" , Loop = false },
	{ Id = "MostMuscular", Name = "Most Muscular", Pose = "MostMuscular", Cost = { Currency = "Cash", Amount = 15000 }, Source = "Shop", Loop = false },
	{ Id = "LatSpread", Name = "Lat Spread", Pose = "LatSpread", Cost = { Currency = "Cash", Amount = 40000 }, Source = "Shop", Loop = false },
	{ Id = "PushUps", Name = "Push-Ups", Pose = "PushUps", Cost = { Currency = "Cash", Amount = 8000 }, Source = "Shop", Loop = true },
	{ Id = "Victory", Name = "Victory", Pose = "Victory", Cost = { Currency = "Trophies", Amount = 150 }, Source = "Shop", Loop = false },
	{ Id = "Stretch", Name = "Stretch", Pose = "Stretch", Cost = nil, Source = "Daily", Loop = true },
	{ Id = "Dance", Name = "Gym Groove", Pose = "Dance", Cost = { Currency = "Trophies", Amount = 300 }, Source = "Shop", Loop = true },
	{ Id = "Salute", Name = "Salute", Pose = "Salute", Cost = nil, Source = "Achievement", Loop = false },
	{ Id = "Meditate", Name = "Meditate", Pose = "Meditate", Cost = { Currency = "Cash", Amount = 20000 }, Source = "Shop", Loop = true },
} :: { EmoteDef }
Cosmetics.Emotes = index(Cosmetics.EmoteList)
Cosmetics.MaxEquippedEmotes = 8

-- Locker decorations, displayed on your assigned locker in the Locker Rooms.
Cosmetics.DecorList = {
	{ Id = "Plant", Name = "Desk Plant", Visual = "Plant", Cost = { Currency = "Cash", Amount = 2000 }, Source = "Shop" },
	{ Id = "Shaker", Name = "Signature Shaker", Visual = "Shaker", Cost = { Currency = "Cash", Amount = 4000 }, Source = "Shop" },
	{ Id = "Poster", Name = "Classic Poster", Visual = "Poster", Cost = { Currency = "Cash", Amount = 9000 }, Source = "Shop" },
	{ Id = "Kettlebell", Name = "Gold Kettlebell", Visual = "GoldKettlebell", Cost = { Currency = "Cash", Amount = 50000 }, Source = "Shop" },
	{ Id = "Medal", Name = "Medal Rack", Visual = "Medals", Cost = { Currency = "Trophies", Amount = 250 }, Source = "Shop" },
	{ Id = "Trophy", Name = "Championship Cup", Visual = "Cup", Cost = nil, Source = "Tournament" },
	{ Id = "Neon", Name = "Name Light", Visual = "NameLight", Cost = { Currency = "Cash", Amount = 120000 }, Source = "Shop" },
	{ Id = "Boombox", Name = "Boombox", Visual = "Boombox", Cost = { Currency = "Trophies", Amount = 500 }, Source = "Shop" },
} :: { DecorDef }
Cosmetics.Decor = index(Cosmetics.DecorList)
Cosmetics.MaxDecor = 4

return Cosmetics
