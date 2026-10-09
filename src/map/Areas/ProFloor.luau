--!strict
-- Pro Floor: polished concrete, copper accents, tier-4 equipment facing the north windows.
local Context = require("../Context")
local Fit = require("./Fit")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")

local M = {}

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "ProFloor")
	local r = Layout.L2.ProFloor
	local y = Layout.Y.L2
	local rs = Layout.RoofStair.Shaft
	local keep = {
		Fit.doorKeepout(Layout.door("L2", "HallwayToProFloor"), 10),
		Fit.rect(rs.X0 - 2, rs.X1 + 2, rs.Z0 - 10, rs.Z1 + 2),
	}
	Fit.pack(f, r, y, "N", {
		{ Type = "Treadmill", Tier = 4, Count = 4 },
		{ Type = "Rower", Tier = 4, Count = 2 },
		{ Type = "Bike", Tier = 4, Count = 3 },
		{ Type = "CableCrossover", Tier = 4, Count = 2 },
		{ Decor = "DumbbellRack", Tier = 4, Length = 12 },
		{ Type = "DumbbellCurl", Tier = 4, Count = 4 },
		{ Type = "ChestPress", Tier = 4, Count = 2 },
		{ Type = "LatPulldown", Tier = 4, Count = 2 },
	}, keep, { AreaId = "ProFloor", Aisle = 6 })
	Props.wallSign(f, Fit.wallCf(r, "S", -34, y + 15, 0.6), "PRO FLOOR", Vector2.new(20, 3), "Area")
	Props.cleaningStation(f, Fit.againstWall(r, "S", -52, y, 1.6))
	Props.cleaningStation(f, Fit.againstWall(r, "S", 30, y, 1.6))
	Fit.cornerPlants(f, r, y, "Olive")
	Fit.lights(f, r, Layout.CEIL.L2, "Linear", 22, nil, { Brightness = 1.8, Range = 36, Drop = 3, Color = Color3.fromRGB(255, 236, 214) })
end

return M
