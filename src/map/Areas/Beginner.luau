--!strict
-- Beginner Studio: bright, friendly, every tier-1 machine type.
local Context = require("../Context")
local Fit = require("./Fit")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")

local M = {}

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "Beginner")
	local r = Layout.G.Beginner
	local y = Layout.Y.G
	local door = Fit.doorKeepout(Layout.door("G", "WestCorridorToBeginner"), 10)
	local opts = { AreaId = "Beginner" }

	-- cardio strip facing the south windows
	Fit.pack(f, Fit.rect(r.X0, r.X1 - 4, r.Z0, r.Z0 + 16), y, "S", {
		{ Type = "Treadmill", Tier = 1, Count = 3 },
		{ Type = "Bike", Tier = 1, Count = 3 },
	}, { door }, opts)
	-- free weights facing the mirror wall
	Fit.pack(f, Fit.rect(r.X0, -112, r.Z0 + 20, r.Z1), y, "W", {
		{ Decor = "DumbbellRack", Tier = 1, Length = 10 },
		{ Type = "DumbbellCurl", Tier = 1, Count = 3 },
		{ Type = "BenchPress", Tier = 1, Count = 2 },
	}, { door }, opts)
	-- mobility / agility corner
	Fit.pack(f, Fit.rect(-108, r.X1, r.Z0 + 20, r.Z1), y, "N", {
		{ Type = "YogaMat", Tier = 1, Count = 3 },
		{ Type = "PlyoBox", Tier = 1, Count = 2 },
		{ Type = "AgilityLadder", Tier = 1 },
	}, { door }, opts)

	Props.mirror(f, Fit.wallCf(r, "W", -60, y + 5.5, 1.15), 34, 8, "Oak")
	Props.wallSign(f, Fit.wallCf(r, "N", -111, y + 15), "EVERY LEGEND STARTED HERE", Vector2.new(34, 3), "Motto")
	Props.wallSign(f, Fit.wallCf(r, "E", -84, y + 12), "BEGINNER STUDIO", Vector2.new(16, 2.4), "Area")
	Props.poster(f, Fit.wallCf(r, "N", -134, y + 7), Vector2.new(5, 7), "Strength")
	Props.poster(f, Fit.wallCf(r, "N", -88, y + 7), Vector2.new(5, 7), "Agility")
	Props.cleaningStation(f, Fit.againstWall(r, "E", -48, y, 1.6))
	Props.towelStack(f, CFrame.new(-146, y, -44), 6)
	Props.waterFountain(f, Fit.wallCf(r, "E", -54, y + 1.8))
	Fit.cornerPlants(f, r, y, "Fiddle")
	Fit.lights(f, r, Layout.CEIL.G, "Panel", 14, nil, { Brightness = 1.2, Range = 22 })
end

return M
