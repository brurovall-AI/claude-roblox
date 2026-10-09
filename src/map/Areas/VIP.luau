--!strict
-- VIP Club: marble, walnut, brass; legendary-tier equipment and a members' lounge.
local Context = require("../Context")
local Fit = require("./Fit")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")

local M = {}

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "VIP")
	local r = Layout.L2.VIP
	local y = Layout.Y.L2
	local keep = { Fit.doorKeepout(Layout.door("L2", "EastHallToVIP"), 12), Fit.rect(60, 92, -100, -60) }
	Fit.pack(f, Fit.rect(94, r.X1, r.Z0, r.Z1), y, "E", {
		{ Decor = "DumbbellRack", Tier = 5, Length = 10 },
		{ Type = "DumbbellCurl", Tier = 5, Count = 3 },
		{ Type = "BenchPress", Tier = 5, Count = 2 },
		{ Type = "SquatRack", Tier = 5 },
		{ Type = "CableCrossover", Tier = 5 },
		{ Type = "Treadmill", Tier = 5, Count = 2 },
		{ Type = "Rower", Tier = 5, Count = 2 },
	}, keep, { AreaId = "VIP", Aisle = 6 })
	Fit.pack(f, Fit.rect(62, 92, -58, r.Z1), y, "W", {
		{ Type = "YogaMat", Tier = 5, Count = 2 },
		{ Type = "IceBath", Tier = 5 },
	}, keep, { AreaId = "VIP" })
	-- members' lounge with smoothie bar (south-west)
	Props.rug(f, CFrame.new(76, y, -80), Vector2.new(24, 30), "CarpetBurgundy")
	Props.counter(f, Kit.place(64.5, y, -80, -90), 16, 3, "Marble", "Walnut")
	Props.sofa(f, Kit.place(80, y, -90, 180), 3, "Velvet")
	Props.sofa(f, Kit.place(80, y, -70, 0), 3, "Velvet")
	Props.coffeeTable(f, Kit.place(80, y, -80, 0), nil, "MarbleDark")
	Props.plant(f, CFrame.new(90, y, -96), "Olive", 1.3)
	Props.wallSign(f, Fit.wallCf(r, "N", 120, y + 14, 0.6), "VIP CLUB", Vector2.new(16, 3), "Brand")
	Props.logo(f, Fit.wallCf(r, "S", 76, y + 12, 1.15), 12, "Brass")
	Fit.cornerPlants(f, r, y, "Palm")
	Fit.lights(f, r, Layout.CEIL.L2, "Pendant", 20, nil, { Drop = 8, Brightness = 1.6, Range = 26 })
end

return M
