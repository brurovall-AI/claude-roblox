--!strict
-- Cable & Machine Room: precise rows of selectorised machines.
local Context = require("../Context")
local Fit = require("./Fit")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")

local M = {}

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "Cables")
	local r = Layout.G.Cables
	local y = Layout.Y.G
	local keep = {
		Fit.doorKeepout(Layout.door("G", "FreeWeightsToCables"), 10),
		Fit.doorKeepout(Layout.door("G", "MainHallToCables"), 12),
	}
	Fit.pack(f, r, y, "N", {
		{ Type = "CableCrossover", Tier = 3, Count = 3 },
		{ Type = "LatPulldown", Tier = 3, Count = 3 },
		{ Type = "LatPulldown", Tier = 2, Count = 2 },
		{ Type = "ChestPress", Tier = 3, Count = 3 },
		{ Type = "ChestPress", Tier = 2, Count = 2 },
		{ Type = "LegPress", Tier = 3, Count = 3 },
		{ Type = "LegPress", Tier = 2, Count = 2 },
	}, keep, { AreaId = "Cables", Gap = 2.5, Aisle = 4 })
	Props.wallSign(f, Fit.wallCf(r, "S", -130, y + 15), "CABLES & MACHINES", Vector2.new(24, 3), "Area")
	Props.cleaningStation(f, Fit.againstWall(r, "S", -84, y, 1.6))
	Props.trashBin(f, CFrame.new(-146, y, 40))
	Fit.cornerPlants(f, r, y, "Snake")
	Fit.lights(f, r, Layout.CEIL.G, "Linear", 15, nil, { Brightness = 2, Range = 30, Drop = 3 })
end

return M
