--!strict
-- Lower Concourse: arrival hall for the lower level.
local Context = require("../Context")
local Fit = require("./Fit")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")

local M = {}

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "Concourse")
	local r = Layout.B1.Concourse
	local y = Layout.Y.B1
	Props.wallSign(f, Fit.wallCf(r, "W", -52, y + 10, 1.15), "←  BOXING GYM", Vector2.new(12, 1.8), "Wayfinding")
	Props.wallSign(f, Fit.wallCf(r, "E", -52, y + 10, 1.15), "RECOVERY STUDIO  →", Vector2.new(14, 1.8), "Wayfinding")
	Props.wallSign(f, Fit.wallCf(r, "N", -20, y + 10, 0.6), "PRIVATE SUITES", Vector2.new(12, 1.8), "Wayfinding")
	Props.vending(f, Fit.againstWall(r, "S", -20, y, 3), "Drinks")
	Props.vending(f, Fit.againstWall(r, "S", -15, y, 3), "Snacks")
	Props.waterFountain(f, Fit.wallCf(r, "S", -8, y + 1.8))
	for _, x in { -30, -10, 10 } do
		Props.bench(f, Kit.place(x, y, -70, 0), 8, "Walnut")
	end
	for i, x in { -40, 0, 20 } do
		Props.poster(f, Fit.wallCf(r, "S", x + 6, y + 7), Vector2.new(5, 7), if i == 1 then "Boxing" elseif i == 2 then "Recovery" else "Vintage")
	end
	Fit.cornerPlants(f, r, y, "Fern")
	Fit.lights(f, r, Layout.CEIL.B1, "Downlight", 22, { Fit.rect(34, 50, -58, -14) }, { Brightness = 1.3, Range = 32, Color = Color3.fromRGB(255, 222, 186) })
end

return M
