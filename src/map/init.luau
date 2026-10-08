--!strict
--[[
	Map entry point (executed by tools/bake/bake.luau under Lune).
	Builds the whole Ironhaven complex and returns the Map model.

	Order: architecture shell -> site -> gameplay volumes/gates -> area dressing.
	Every module exports build(ctx). A failing module is reported and skipped
	so one mistake never blocks the rest of the bake.
]]

local Context = require("./Context")
local Gameplay = require("./Gameplay")
local Kit = require("./Kit")

type Module = { build: (ctx: Context.Ctx) -> () }

local SHELL: { { name: string, mod: Module } } = {
	{ name = "Shell/Ground", mod = require("./Shell/Ground") },
	{ name = "Shell/Second", mod = require("./Shell/Second") },
	{ name = "Shell/Lower", mod = require("./Shell/Lower") },
	{ name = "Shell/Roof", mod = require("./Shell/Roof") },
	{ name = "Shell/Circulation", mod = require("./Shell/Circulation") },
	{ name = "Shell/Facade", mod = require("./Shell/Facade") },
	{ name = "Shell/Apex", mod = require("./Shell/Apex") },
	{ name = "Site/Site", mod = require("./Site/Site") },
	{ name = "Site/City", mod = require("./Site/City") },
}

local AREAS: { { name: string, mod: Module } } = {
	{ name = "Areas/Lobby", mod = require("./Areas/Lobby") },
	{ name = "Areas/Beginner", mod = require("./Areas/Beginner") },
	{ name = "Areas/FreeWeights", mod = require("./Areas/FreeWeights") },
	{ name = "Areas/Cables", mod = require("./Areas/Cables") },
	{ name = "Areas/MainHall", mod = require("./Areas/MainHall") },
	{ name = "Areas/Lounge", mod = require("./Areas/Lounge") },
	{ name = "Areas/Lockers", mod = require("./Areas/Lockers") },
	{ name = "Areas/Cardio", mod = require("./Areas/Cardio") },
	{ name = "Areas/Mezzanine", mod = require("./Areas/Mezzanine") },
	{ name = "Areas/ProFloor", mod = require("./Areas/ProFloor") },
	{ name = "Areas/Foundry", mod = require("./Areas/Foundry") },
	{ name = "Areas/VIP", mod = require("./Areas/VIP") },
	{ name = "Areas/Arena", mod = require("./Areas/Arena") },
	{ name = "Areas/Concourse", mod = require("./Areas/Concourse") },
	{ name = "Areas/Boxing", mod = require("./Areas/Boxing") },
	{ name = "Areas/Recovery", mod = require("./Areas/Recovery") },
	{ name = "Areas/Private", mod = require("./Areas/Private") },
	{ name = "Areas/Rooftop", mod = require("./Areas/Rooftop") },
	{ name = "Areas/Yard", mod = require("./Areas/Yard") },
	{ name = "Areas/Apex", mod = require("./Areas/Apex") },
}

local function run(list: { { name: string, mod: Module } }, ctx: Context.Ctx)
	for _, entry in list do
		local ok, err = pcall(entry.mod.build, ctx)
		if not ok then
			print(`[map] {entry.name} FAILED: {err}`)
		end
	end
end

return function(): Model
	local map = Instance.new("Model")
	map.Name = "Map"
	map.WorldPivot = CFrame.new()
	local ctx: Context.Ctx = {
		Map = map,
		Structure = Kit.folder(map, "Structure"),
		Areas = Kit.folder(map, "Areas"),
		Gameplay = Kit.folder(map, "Gameplay"),
		Exterior = Kit.folder(map, "Exterior"),
	}
	run(SHELL, ctx)
	Gameplay.buildZones(map)
	Gameplay.buildGates(ctx.Gameplay)
	Gameplay.buildElevatorStops(ctx.Gameplay)
	Gameplay.buildSpawn(ctx.Gameplay)
	run(AREAS, ctx)
	return map
end
