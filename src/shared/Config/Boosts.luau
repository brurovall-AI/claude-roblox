--!strict
--[[
	Timed boosts. Bought at the Juice Bar (or shop), granted by rewards.
	Stacking: buying an active boost extends its timer (capped at MaxStack).
]]

export type BoostDef = {
	Id: string,
	Name: string,
	Description: string,
	Duration: number,
	Effect: "StatGain" | "XP" | "Cash" | "Energy" | "Window",
	Stat: string?, -- for StatGain: a StatId or "All"
	Mult: number,
	BasePrice: number, -- scaled by level, see Boosts.price
	Color: Color3,
	Order: number,
}

local Boosts = {}

Boosts.MaxStack = 60 * 60 -- an hour of stacked time per boost

Boosts.List = {
	{ Id = "Protein", Name = "Protein Shake", Description = "+50% Strength gains", Duration = 600, Effect = "StatGain", Stat = "Strength", Mult = 1.5, BasePrice = 120, Color = Color3.fromRGB(232, 92, 74), Order = 1 },
	{ Id = "PreWorkout", Name = "Pre-Workout", Description = "+25% gains on every stat", Duration = 600, Effect = "StatGain", Stat = "All", Mult = 1.25, BasePrice = 200, Color = Color3.fromRGB(240, 146, 60), Order = 2 },
	{ Id = "Electrolytes", Name = "Electrolyte Mix", Description = "Energy regen x2, reps cost 25% less", Duration = 600, Effect = "Energy", Mult = 2, BasePrice = 90, Color = Color3.fromRGB(88, 176, 226), Order = 3 },
	{ Id = "Chalk", Name = "Lucky Chalk", Description = "Perfect window 40% wider", Duration = 600, Effect = "Window", Mult = 1.4, BasePrice = 150, Color = Color3.fromRGB(240, 240, 236), Order = 4 },
	{ Id = "Focus", Name = "Focus Shot", Description = "+50% XP", Duration = 600, Effect = "XP", Mult = 1.5, BasePrice = 160, Color = Color3.fromRGB(186, 128, 236), Order = 5 },
	{ Id = "Payday", Name = "Payday Bar", Description = "+50% Cash", Duration = 600, Effect = "Cash", Mult = 1.5, BasePrice = 160, Color = Color3.fromRGB(122, 214, 120), Order = 6 },
} :: { BoostDef }

Boosts.Defs = {} :: { [string]: BoostDef }
for _, b in Boosts.List do
	Boosts.Defs[b.Id] = b
end

-- Price scales gently with level so boosts stay relevant but never dominate.
function Boosts.price(def: BoostDef, level: number): number
	local p = def.BasePrice * math.pow(1 + level, 1.45)
	local mag = math.pow(10, math.max(0, math.floor(math.log10(p)) - 1))
	return math.floor(p / mag) * mag
end

return Boosts
