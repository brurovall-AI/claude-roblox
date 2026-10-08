--!strict
--[[
	Personal training gear: five slots, six tiers each. Bought with Cash, equipped
	one per slot, multiplies gains for its stat. Visuals are built from parts and
	welded to the character (see server CharacterService / GearVisuals).
]]

export type GearSlot = "Gloves" | "Shoes" | "Belt" | "Wraps" | "Headband"

export type GearDef = {
	Id: string,
	Slot: GearSlot,
	Tier: number,
	Name: string,
	Stat: string,
	Mult: number,
	Price: number,
	LevelReq: number,
	Primary: Color3,
	Secondary: Color3,
	Material: string, -- Enum.Material name for the main surface
}

local Gear = {}

Gear.Slots = { "Gloves", "Shoes", "Belt", "Wraps", "Headband" } :: { GearSlot }

Gear.SlotInfo = {
	Gloves = { Name = "Lifting Gloves", Stat = "Strength" },
	Shoes = { Name = "Trainers", Stat = "Speed" },
	Belt = { Name = "Lifting Belt", Stat = "Endurance" },
	Wraps = { Name = "Wrist Wraps", Stat = "Agility" },
	Headband = { Name = "Headband", Stat = "Energy" },
}

local TIER_MULT = { 1.15, 1.35, 1.65, 2.0, 2.5, 3.2 }
local TIER_PRICE = { 250, 1500, 9000, 50000, 250000, 1200000 }
local TIER_LEVEL = { 1, 4, 10, 20, 32, 50 }
local TIER_PREFIX = { "Starter", "Club", "Pro", "Elite", "Legend", "Apex" }
local TIER_STYLE = {
	{ Primary = Color3.fromRGB(242, 140, 90), Secondary = Color3.fromRGB(245, 245, 240), Material = "SmoothPlastic" },
	{ Primary = Color3.fromRGB(40, 42, 46), Secondary = Color3.fromRGB(120, 124, 130), Material = "Fabric" },
	{ Primary = Color3.fromRGB(176, 42, 44), Secondary = Color3.fromRGB(30, 30, 32), Material = "Leather" },
	{ Primary = Color3.fromRGB(176, 128, 82), Secondary = Color3.fromRGB(196, 160, 90), Material = "Leather" },
	{ Primary = Color3.fromRGB(24, 24, 26), Secondary = Color3.fromRGB(212, 170, 72), Material = "Leather" },
	{ Primary = Color3.fromRGB(236, 238, 240), Secondary = Color3.fromRGB(110, 226, 236), Material = "SmoothPlastic" },
}

Gear.Defs = {} :: { [string]: GearDef }
Gear.BySlot = {} :: { [GearSlot]: { GearDef } }

for _, slot in Gear.Slots do
	Gear.BySlot[slot] = {}
	for tier = 1, 6 do
		local info = (Gear.SlotInfo :: any)[slot]
		local style = TIER_STYLE[tier]
		local d: GearDef = {
			Id = slot .. tier,
			Slot = slot,
			Tier = tier,
			Name = `{TIER_PREFIX[tier]} {info.Name}`,
			Stat = info.Stat,
			Mult = TIER_MULT[tier],
			Price = TIER_PRICE[tier],
			LevelReq = TIER_LEVEL[tier],
			Primary = style.Primary,
			Secondary = style.Secondary,
			Material = style.Material,
		}
		Gear.Defs[d.Id] = d
		table.insert(Gear.BySlot[slot], d)
	end
end

function Gear.get(id: string): GearDef?
	return Gear.Defs[id]
end

return Gear
