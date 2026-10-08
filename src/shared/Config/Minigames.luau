--!strict
--[[
	Minigame tuning. Every minigame boils down to a stream of "reps", each graded:
	  0 Miss, 1 Ok, 2 Good, 3 Perfect
	The client runs the minigame; the server re-checks rep cadence and caps gains,
	so the best a cheater can do is play perfectly.

	Kinds:
	  Timing   A needle sweeps a curved meter; tap when it crosses the lit window.
	  Charge   Hold to build power; release while the gauge is inside the window.
	  Rhythm   Keep the marker inside a drifting target band by holding/releasing.
	  Cadence  Alternate two inputs (L / R) to keep your turnover inside the band.
	  Sequence Hit the shown direction prompts in order before the timer runs out.
	  Breath   Hold to inhale as the ring expands, release at the top, exhale slowly.
]]

export type MinigameKind = "Timing" | "Charge" | "Rhythm" | "Cadence" | "Sequence" | "Breath"

local Minigames = {}

Minigames.QualityNames = { [0] = "Miss", [1] = "Ok", [2] = "Good", [3] = "Perfect" }
Minigames.QualityMult = { [0] = 0.2, [1] = 0.6, [2] = 1.0, [3] = 1.5 }
Minigames.QualityColor = {
	[0] = Color3.fromRGB(150, 150, 156),
	[1] = Color3.fromRGB(210, 210, 214),
	[2] = Color3.fromRGB(122, 214, 150),
	[3] = Color3.fromRGB(255, 206, 92),
}

-- Combo: consecutive Good/Perfect reps. Each step adds ComboStep, capped at ComboMax.
Minigames.ComboStep = 0.04
Minigames.ComboMax = 1.0 -- => up to x2.0
Minigames.ComboBreakQuality = 1 -- Ok or worse breaks the combo

-- d = tier difficulty 0..1 (see Tiers). Lerped between Easy and Hard values.
Minigames.Params = {
	Timing = {
		Easy = { Period = 1.5, Perfect = 0.075, Good = 0.17, Ok = 0.28 },
		Hard = { Period = 0.95, Perfect = 0.045, Good = 0.11, Ok = 0.2 },
	},
	Charge = {
		Easy = { FillTime = 1.25, Perfect = 0.06, Good = 0.13, Ok = 0.22 },
		Hard = { FillTime = 0.8, Perfect = 0.04, Good = 0.09, Ok = 0.16 },
	},
	Rhythm = {
		-- band drifts; one rep is scored every StrokeTime from % of time inside band
		Easy = { StrokeTime = 1.4, BandSize = 0.3, Drift = 0.35 },
		Hard = { StrokeTime = 1.1, BandSize = 0.2, Drift = 0.7 },
	},
	Cadence = {
		-- taps/sec target band; one rep scored every StrokeTime
		Easy = { StrokeTime = 1.2, MinRate = 3.0, MaxRate = 7.0, Ideal = 5.0 },
		Hard = { StrokeTime = 1.0, MinRate = 4.5, MaxRate = 8.5, Ideal = 6.5 },
	},
	Sequence = {
		Easy = { Length = 3, TimePerInput = 0.9 },
		Hard = { Length = 5, TimePerInput = 0.55 },
	},
	Breath = {
		Easy = { Inhale = 2.0, Perfect = 0.08, Good = 0.16, Ok = 0.26 },
		Hard = { Inhale = 1.6, Perfect = 0.06, Good = 0.12, Ok = 0.2 },
	},
}

function Minigames.params(kind: MinigameKind, difficulty: number): { [string]: number }
	local p = (Minigames.Params :: any)[kind]
	local out = {}
	for k, easy in p.Easy do
		local hard = p.Hard[k]
		out[k] = easy + (hard - easy) * math.clamp(difficulty, 0, 1)
	end
	return out
end

-- Shortest legal time between two reps (server check uses 80% of this).
function Minigames.minRepInterval(kind: MinigameKind, difficulty: number): number
	local p = Minigames.params(kind, difficulty)
	if kind == "Timing" then
		return p.Period * 0.5
	elseif kind == "Charge" then
		return p.FillTime * 0.6
	elseif kind == "Rhythm" or kind == "Cadence" then
		return p.StrokeTime
	elseif kind == "Sequence" then
		return p.Length * 0.18
	else
		return p.Inhale
	end
end

return Minigames
