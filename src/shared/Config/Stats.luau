--!strict
-- The five trainable attributes. Order here is the display order everywhere.

export type StatId = "Strength" | "Endurance" | "Speed" | "Agility" | "Energy"

export type StatDef = {
	Id: StatId,
	Name: string,
	Short: string,
	Color: Color3,
	Description: string,
	Effect: string,
}

local Stats = {}

Stats.Order = { "Strength", "Endurance", "Speed", "Agility", "Energy" } :: { StatId }

Stats.Defs = {
	Strength = {
		Id = "Strength",
		Name = "Strength",
		Short = "STR",
		Color = Color3.fromRGB(232, 92, 74),
		Description = "Raw lifting power. Builds visible muscle and wins 1v1 arm-wrestling.",
		Effect = "Muscle size, duel power, Max Lift score",
	},
	Endurance = {
		Id = "Endurance",
		Name = "Endurance",
		Short = "END",
		Color = Color3.fromRGB(240, 146, 60),
		Description = "Work capacity. Every rep costs less energy.",
		Effect = "Lower energy cost per rep, Endurance Hold score",
	},
	Speed = {
		Id = "Speed",
		Name = "Speed",
		Short = "SPD",
		Color = Color3.fromRGB(236, 200, 72),
		Description = "Leg drive and turnover. You literally run faster.",
		Effect = "Walk speed, Sprint Race pace",
	},
	Agility = {
		Id = "Agility",
		Name = "Agility",
		Short = "AGI",
		Color = Color3.fromRGB(86, 196, 128),
		Description = "Coordination and spring. Jump higher, move sharper.",
		Effect = "Jump height, Obstacle Dash",
	},
	Energy = {
		Id = "Energy",
		Name = "Energy",
		Short = "ENG",
		Color = Color3.fromRGB(88, 176, 226),
		Description = "Recovery capacity. A bigger tank that refills faster.",
		Effect = "Max energy and regeneration",
	},
} :: { [StatId]: StatDef }

function Stats.isStat(id: any): boolean
	return type(id) == "string" and Stats.Defs[id :: StatId] ~= nil
end

return Stats
