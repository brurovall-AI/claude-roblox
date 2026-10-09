--!strict
--[[
	List of equipment builder modules. Each module returns a function that
	receives the Equipment library and registers builders:

		return function(Equipment)
			Equipment.register("BenchPress", function(model, tier, cf, style) ... end)
		end

	Shared.luau holds the tier-aware building blocks (tubes, pads, plates, bars,
	stacks, plinths); Racks.luau the storage racks used by stations and decor.
]]

return {
	require("./Strength"),
	require("./Machines"),
	require("./Cardio"),
	require("./Agility"),
	require("./Recovery"),
	require("./Ultimate"),
	require("./Decor"),
} :: { (any) -> () }
