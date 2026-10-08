--!strict
-- Level curve, energy model, stat effects and rebirth rules. Pure data + math.

local Progression = {}

Progression.MaxLevel = 120

-- XP required to go from `level` to `level + 1`.
function Progression.xpToNext(level: number): number
	return math.floor(50 * math.pow(math.max(1, level), 1.75))
end

-- Rebirth ----------------------------------------------------------------------
Progression.Rebirth = {
	BaseLevel = 50, -- level needed for the first rebirth
	LevelStep = 5, -- +5 levels per rebirth already done
	MaxLevelReq = 95,
	GainPerRebirth = 0.35, -- additive permanent multiplier per rebirth
	TokensPerRebirth = 1,
	-- what is kept: owned items, trophies, achievements, cosmetics, companions,
	-- settings, rebirth tokens. Reset: level, XP, stats, cash, active boosts.
}

function Progression.rebirthLevelReq(rebirths: number): number
	local r = Progression.Rebirth
	return math.min(r.MaxLevelReq, r.BaseLevel + r.LevelStep * rebirths)
end

function Progression.rebirthMult(rebirths: number): number
	return 1 + Progression.Rebirth.GainPerRebirth * rebirths
end

-- Energy -----------------------------------------------------------------------
Progression.Energy = {
	Base = 100,
	RegenBase = 3, -- per second while not training
	RecoveryRestore = 12, -- per Breath rep on Energy stations (scaled by tier)
}

function Progression.maxEnergy(energyStat: number): number
	return Progression.Energy.Base + math.floor(math.sqrt(math.max(0, energyStat)) * 4)
end

function Progression.energyRegen(energyStat: number): number
	return Progression.Energy.RegenBase + math.sqrt(math.max(0, energyStat)) * 0.08
end

-- Endurance makes reps cheaper, up to 60% off.
function Progression.energyCostMult(enduranceStat: number): number
	local e = math.max(0, enduranceStat)
	return 1 - 0.6 * (e / (e + 6000))
end

-- Stat effects -------------------------------------------------------------------
local function saturate(x: number, half: number): number
	x = math.max(0, x)
	return x / (x + half)
end

function Progression.walkSpeed(speedStat: number): number
	return 16 + 14 * saturate(speedStat, 5000)
end

function Progression.jumpHeight(agilityStat: number): number
	return 7.2 + 5 * saturate(agilityStat, 5000)
end

-- Multiplier applied on top of the avatar's own BodyWidth/DepthScale.
function Progression.muscleScale(strengthStat: number): number
	return 1 + 0.32 * saturate(strengthStat, 20000)
end

function Progression.power(stats: { [string]: number }): number
	local total = 0
	for _, v in stats do
		total += v
	end
	return total
end

return Progression
