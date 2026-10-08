--!strict
--[[
	Equipment tiers. Higher tiers multiply gains and demand sharper timing.
	Visual language (used by the map's equipment builders):
	  1 Beginner     colourful vinyl + white frames, friendly rounded shapes
	  2 Amateur      black powder-coated steel, rubber, plain black vinyl
	  3 Professional brushed steel + graphite, red upholstery, chrome details
	  4 Elite        matte graphite, oak accents, tan leather, brass collars
	  5 Legendary    black chrome + gold trim, walnut, quilted leather, marble
	  6 Ultimate     white composite + titanium + carbon, floating parts, light lines
]]

export type TierDef = {
	Index: number,
	Name: string,
	Color: Color3,
	LevelReq: number,
	RebirthReq: number,
	StatMult: number, -- stat gain multiplier per rep
	XPMult: number,
	CashMult: number,
	Difficulty: number, -- 0..1, scales minigame speed / window size
}

local Tiers = {}

Tiers.List = {
	{ Index = 1, Name = "Beginner", Color = Color3.fromRGB(150, 214, 168), LevelReq = 1, RebirthReq = 0, StatMult = 1, XPMult = 1, CashMult = 1, Difficulty = 0.0 },
	{ Index = 2, Name = "Amateur", Color = Color3.fromRGB(170, 178, 189), LevelReq = 4, RebirthReq = 0, StatMult = 3, XPMult = 2, CashMult = 2.5, Difficulty = 0.15 },
	{ Index = 3, Name = "Professional", Color = Color3.fromRGB(96, 165, 230), LevelReq = 10, RebirthReq = 0, StatMult = 9, XPMult = 4, CashMult = 6, Difficulty = 0.3 },
	{ Index = 4, Name = "Elite", Color = Color3.fromRGB(186, 128, 236), LevelReq = 20, RebirthReq = 0, StatMult = 27, XPMult = 8, CashMult = 15, Difficulty = 0.45 },
	{ Index = 5, Name = "Legendary", Color = Color3.fromRGB(240, 178, 64), LevelReq = 32, RebirthReq = 0, StatMult = 81, XPMult = 16, CashMult = 38, Difficulty = 0.6 },
	{ Index = 6, Name = "Ultimate", Color = Color3.fromRGB(110, 226, 236), LevelReq = 50, RebirthReq = 1, StatMult = 243, XPMult = 32, CashMult = 95, Difficulty = 0.75 },
} :: { TierDef }

function Tiers.get(index: number): TierDef
	return Tiers.List[math.clamp(math.floor(index), 1, #Tiers.List)]
end

return Tiers
