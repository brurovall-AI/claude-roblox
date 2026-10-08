--!strict
--[[
	Training companions: small, tasteful helpers that follow you around and
	react when you train. Bought directly (no loot boxes). Bonus multiplies
	stat gains (Stat = "All" or a specific stat).
	Visual: client-side builder key in client/World/CompanionModels.
]]

local Currency = require(script.Parent.Currency)

export type CompanionDef = {
	Id: string,
	Name: string,
	Description: string,
	Visual: string,
	Stat: string, -- "All" or a StatId
	Bonus: number, -- e.g. 0.1 => +10%
	Cost: Currency.Cost,
	LevelReq: number,
	RebirthReq: number,
	Rarity: "Common" | "Rare" | "Epic" | "Legendary" | "Mythic",
	Order: number,
}

local Companions = {}

Companions.RarityColor = {
	Common = Color3.fromRGB(176, 180, 186),
	Rare = Color3.fromRGB(96, 165, 230),
	Epic = Color3.fromRGB(186, 128, 236),
	Legendary = Color3.fromRGB(240, 178, 64),
	Mythic = Color3.fromRGB(110, 226, 236),
}

local list: { CompanionDef } = {
	{ Id = "RookieRex", Name = "Rookie Rex", Description = "Ironhaven's plush rhino mascot. Cheers on every rep.", Visual = "Rhino", Stat = "All", Bonus = 0.05, Cost = { Currency = "Cash", Amount = 1500 }, LevelReq = 2, RebirthReq = 0, Rarity = "Common", Order = 1 },
	{ Id = "SpotterBot", Name = "Spotter Bot", Description = "A hovering spotter drone with a counting display.", Visual = "Drone", Stat = "Strength", Bonus = 0.12, Cost = { Currency = "Cash", Amount = 12000 }, LevelReq = 8, RebirthReq = 0, Rarity = "Rare", Order = 2 },
	{ Id = "CoachKettle", Name = "Coach Kettle", Description = "A tough-love kettlebell with a whistle.", Visual = "Kettlebell", Stat = "Endurance", Bonus = 0.12, Cost = { Currency = "Cash", Amount = 12000 }, LevelReq = 8, RebirthReq = 0, Rarity = "Rare", Order = 3 },
	{ Id = "Pacer", Name = "Pacer", Description = "A mini running robot that sets your tempo.", Visual = "Pacer", Stat = "Speed", Bonus = 0.12, Cost = { Currency = "Cash", Amount = 12000 }, LevelReq = 8, RebirthReq = 0, Rarity = "Rare", Order = 4 },
	{ Id = "CoachMini", Name = "Coach Mini", Description = "A pocket-sized personal trainer with a clipboard.", Visual = "Trainer", Stat = "Agility", Bonus = 0.12, Cost = { Currency = "Cash", Amount = 12000 }, LevelReq = 8, RebirthReq = 0, Rarity = "Rare", Order = 5 },
	{ Id = "ZenOrb", Name = "Zen Orb", Description = "A calm floating orb that steadies your breathing.", Visual = "Orb", Stat = "Energy", Bonus = 0.18, Cost = { Currency = "Cash", Amount = 45000 }, LevelReq = 16, RebirthReq = 0, Rarity = "Epic", Order = 6 },
	{ Id = "PlateGolem", Name = "Plate Golem", Description = "A little robot built from bumper plates. Strong opinions about form.", Visual = "Golem", Stat = "Strength", Bonus = 0.25, Cost = { Currency = "Trophies", Amount = 600 }, LevelReq = 12, RebirthReq = 0, Rarity = "Epic", Order = 7 },
	{ Id = "IronRex", Name = "Iron Rex", Description = "The armoured championship edition of the mascot.", Visual = "RhinoIron", Stat = "All", Bonus = 0.2, Cost = { Currency = "Trophies", Amount = 1500 }, LevelReq = 20, RebirthReq = 0, Rarity = "Legendary", Order = 8 },
	{ Id = "ApexDrone", Name = "Apex Drone MK-II", Description = "Research-grade training assistant from the Apex Lab.", Visual = "ApexDrone", Stat = "All", Bonus = 0.3, Cost = { Currency = "Cash", Amount = 2500000 }, LevelReq = 45, RebirthReq = 0, Rarity = "Legendary", Order = 9 },
	{ Id = "GoldenRex", Name = "Golden Rex", Description = "Awarded only to those who have started over. Twice.", Visual = "RhinoGold", Stat = "All", Bonus = 0.4, Cost = { Currency = "RebirthTokens", Amount = 3 }, LevelReq = 1, RebirthReq = 2, Rarity = "Mythic", Order = 10 },
}

Companions.Defs = {} :: { [string]: CompanionDef }
Companions.List = list
for _, c in list do
	Companions.Defs[c.Id] = c
end

-- Equip slots: 1 by default, 2 from Rebirth 2.
function Companions.slots(rebirths: number): number
	return if rebirths >= 2 then 2 else 1
end

return Companions
