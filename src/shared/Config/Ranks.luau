--!strict
-- Ranks are earned from total Power (sum of all five stats). Shown above heads.

export type RankDef = { Index: number, Name: string, Power: number, Color: Color3 }

local Ranks = {}

Ranks.List = {
	{ Index = 1, Name = "Rookie", Power = 0, Color = Color3.fromRGB(176, 180, 186) },
	{ Index = 2, Name = "Regular", Power = 250, Color = Color3.fromRGB(150, 206, 160) },
	{ Index = 3, Name = "Athlete", Power = 2500, Color = Color3.fromRGB(110, 190, 220) },
	{ Index = 4, Name = "Contender", Power = 15000, Color = Color3.fromRGB(120, 150, 236) },
	{ Index = 5, Name = "Pro", Power = 75000, Color = Color3.fromRGB(170, 130, 236) },
	{ Index = 6, Name = "Elite", Power = 300000, Color = Color3.fromRGB(226, 120, 196) },
	{ Index = 7, Name = "Champion", Power = 1200000, Color = Color3.fromRGB(236, 120, 96) },
	{ Index = 8, Name = "Legend", Power = 5000000, Color = Color3.fromRGB(240, 178, 64) },
	{ Index = 9, Name = "Titan", Power = 25000000, Color = Color3.fromRGB(250, 214, 120) },
	{ Index = 10, Name = "Olympian", Power = 120000000, Color = Color3.fromRGB(255, 240, 200) },
} :: { RankDef }

function Ranks.forPower(power: number): RankDef
	local best = Ranks.List[1]
	for _, r in Ranks.List do
		if power >= r.Power then
			best = r
		end
	end
	return best
end

function Ranks.next(rank: RankDef): RankDef?
	return Ranks.List[rank.Index + 1]
end

return Ranks
