--!strict
-- Hall of Fame balcony around the atrium + the L2 hallway.
local Context = require("../Context")
local Fit = require("./Fit")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")

local M = {}

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "Mezzanine")
	local r, hall = Layout.L2.Mezzanine, Layout.L2.Hallway
	local y = Layout.Y.L2
	local void = Layout.AtriumVoid

	Props.trophyCase(f, Fit.againstWall(r, "S", -35, y, 2), 18)
	Props.trophyCase(f, Fit.againstWall(r, "S", 35, y, 2), 18)
	Props.wallSign(f, Fit.wallCf(r, "S", 0, y + 13, 1.15), "HALL OF FAME", Vector2.new(26, 3.6), "Brand")
	for i, x in { -48, -38, 38, 48 } do
		Props.poster(f, Fit.wallCf(r, if x < 0 then "W" else "E", -80 + (i % 2) * 22, y + 7), Vector2.new(5, 7), if i % 2 == 0 then "Vintage" else "Strength")
	end
	-- lounge seating facing the atrium on the east and west balconies
	for _, x in { -45, 45 } do
		Props.rug(f, CFrame.new(x, y, -60), Vector2.new(14, 18), "Carpet")
		Props.sofa(f, Kit.place(x + (if x < 0 then -4 else 4), y, -60, if x < 0 then -90 else 90), 3, "Leather")
		Props.coffeeTable(f, Kit.place(x, y, -60, 90))
		Props.plant(f, CFrame.new(x, y, -75), "Fiddle", 1.2)
	end
	Props.wallSign(f, Fit.wallCf(hall, "N", -30, y + 14, 0.6), "←  THE FOUNDRY", Vector2.new(14, 1.8), "Wayfinding")
	Props.wallSign(f, Fit.wallCf(hall, "N", 30, y + 14, 0.6), "ARENA · VIP  →", Vector2.new(14, 1.8), "Wayfinding")
	Fit.lights(f, r, Layout.CEIL.L2, "Downlight", 22, { void }, { Brightness = 1.3, Range = 32 })
	Fit.lights(f, hall, Layout.CEIL.L2, "Downlight", 22, nil, { Brightness = 1.3, Range = 32 })
end

return M
