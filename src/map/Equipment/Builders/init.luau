--!strict
--[[
	List of equipment builder modules. Each module returns a function that
	receives the Equipment library and registers builders:

		return function(Equipment)
			Equipment.register("BenchPress", function(model, tier, cf, style) ... end)
		end
]]

return {} :: { (any) -> () }
