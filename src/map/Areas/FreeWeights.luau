--!strict
-- Free Weights: rubber floor, oak platforms, long mirror wall, tier-2 iron.
local Context = require("../Context")
local Fit = require("./Fit")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")

local M = {}

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "FreeWeights")
	local r = Layout.G.FreeWeights
	local y = Layout.Y.G
	local keep = {
		Fit.doorKeepout(Layout.door("G", "WestCorridorToFreeWeights"), 10),
		Fit.doorKeepout(Layout.door("G", "MainHallToFreeWeights"), 12),
		Fit.doorKeepout(Layout.door("G", "FreeWeightsToCables"), 10),
		Fit.doorKeepout(Layout.door("G", "FreeWeightsToYard"), 12),
		Fit.rect(-113, -97, -40, 36), -- walkway between the gates
	}
	Fit.pack(f, r, y, "W", {
		{ Decor = "DumbbellRack", Tier = 2, Length = 12 },
		{ Type = "DumbbellCurl", Tier = 2, Count = 3 },
		{ Decor = "DumbbellRack", Tier = 2, Length = 12 },
		{ Type = "DumbbellCurl", Tier = 2, Count = 3 },
		{ Type = "BenchPress", Tier = 2, Count = 4 },
		{ Decor = "PlateTree", Tier = 2, Count = 2 },
		{ Decor = "BenchFlat", Tier = 2, Count = 2 },
	}, keep, { AreaId = "FreeWeights", Aisle = 6 })

	Props.mirror(f, Fit.wallCf(r, "W", -24, y + 5.5, 1.15), 26, 8, "PowderBlack")
	Props.mirror(f, Fit.wallCf(r, "W", 21, y + 5.5, 1.15), 22, 8, "PowderBlack")
	Props.wallSign(f, Fit.wallCf(r, "N", -130, y + 15), "FREE WEIGHTS", Vector2.new(20, 3), "Area")
	Props.wallSign(f, Fit.wallCf(r, "E", -26, y + 14), "RE-RACK YOUR WEIGHTS", Vector2.new(16, 1.6), "Motto")
	Props.chalkBowl(f, CFrame.new(-100, y, -6))
	Props.cleaningStation(f, Fit.againstWall(r, "S", -84, y, 1.6))
	Props.towelRack(f, Fit.againstWall(r, "S", -128, y, 1.4))
	Props.plateStack(f, CFrame.new(-70, y, 30), "Rubber", 4)
	Props.waterBottle(f, CFrame.new(-131, y, -30))
	Fit.cornerPlants(f, r, y, "Snake")
	Fit.lights(f, r, Layout.CEIL.G, "Linear", 16, nil, { Brightness = 2, Range = 30, Drop = 3 })
end

return M
