--!strict
--[[
	Props implementation modules. Each returns a function that registers
	implementations on the Props facade:

		return function(Props)
			Props.register("plant", function(parent, cf, kind, scale) ... return model end)
		end

	Implementation functions receive exactly the arguments the facade passes
	(see Props/init.luau `call(...)`): (parent, cf, ...extra).
]]

return {
	require("./Nature"),
	require("./Furniture"),
	require("./Fixtures"),
	require("./Clutter"),
	require("./Signage"),
	require("./Lighting"),
	require("./Services"),
	require("./Outdoor"),
} :: { (any) -> () }
