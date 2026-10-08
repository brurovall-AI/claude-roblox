--!strict
--[[
	Pure gain math shared by server (authoritative) and client (previews / UI).
	Keep this free of side effects so it can be unit tested under Lune.
]]

local Config = script.Parent.Config
local Minigames = require(Config.Minigames)
local Progression = require(Config.Progression)
local Stations = require(Config.Stations)
local Tiers = require(Config.Tiers)

local Formulas = {}

export type Multipliers = {
	Gear: number, -- gear multiplier for the station's stat
	Companion: number, -- companion multiplier for the station's stat
	Boost: number, -- stat boost multiplier for the station's stat
	XPBoost: number,
	CashBoost: number,
	Rebirths: number,
	Party: number, -- social multiplier (party + friends nearby)
	DoubleCash: boolean,
	Electrolytes: boolean,
	Endurance: number, -- endurance stat (for energy cost)
}

export type RepResult = {
	Stat: string,
	StatGain: number,
	XP: number,
	Cash: number,
	EnergyDelta: number, -- negative = cost, positive = restore
}

function Formulas.defaultMultipliers(): Multipliers
	return {
		Gear = 1,
		Companion = 1,
		Boost = 1,
		XPBoost = 1,
		CashBoost = 1,
		Rebirths = 0,
		Party = 1,
		DoubleCash = false,
		Electrolytes = false,
		Endurance = 0,
	}
end

function Formulas.comboBonus(combo: number): number
	return math.min(Minigames.ComboMax, math.max(0, combo) * Minigames.ComboStep)
end

function Formulas.rep(stationType: string, tier: number, quality: number, combo: number, m: Multipliers): RepResult
	local def = Stations.get(stationType)
	assert(def, "unknown station " .. stationType)
	local t = Tiers.get(tier)
	local q = Minigames.QualityMult[math.clamp(math.floor(quality), 0, 3)]
	local comboMult = 1 + Formulas.comboBonus(combo)
	local rebirth = Progression.rebirthMult(m.Rebirths)

	local statGain = def.Gain * t.StatMult * q * comboMult * m.Gear * m.Companion * m.Boost * rebirth * m.Party
	local xp = 5 * t.XPMult * q * (1 + Formulas.comboBonus(combo) * 0.5) * m.XPBoost * m.Party
	local cash = 2 * t.CashMult * q * m.CashBoost * (if m.DoubleCash then 2 else 1) * (1 + 0.25 * m.Rebirths)

	local energy: number
	if def.Restores then
		energy = Progression.Energy.RecoveryRestore * (1 + 0.25 * (t.Index - 1)) * math.max(0.5, q)
	else
		local cost = def.EnergyCost * (1 + 0.15 * (t.Index - 1)) * Progression.energyCostMult(m.Endurance)
		if m.Electrolytes then
			cost *= 0.75
		end
		energy = -cost
	end

	return {
		Stat = def.Stat,
		StatGain = math.max(0.1, statGain),
		XP = math.max(1, math.floor(xp + 0.5)),
		Cash = math.max(0, math.floor(cash + 0.5)),
		EnergyDelta = energy,
	}
end

-- Social multiplier: +5% per nearby party member (max 4), +5% per nearby friend (max 2).
function Formulas.socialMult(partyNearby: number, friendsNearby: number): number
	return 1 + 0.05 * math.min(4, partyNearby) + 0.05 * math.min(2, friendsNearby)
end

return Formulas
