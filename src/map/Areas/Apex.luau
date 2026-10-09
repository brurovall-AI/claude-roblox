--!strict
-- Apex Lab: ultimate-tier research gym in the floating annex.
local Context = require("../Context")
local Fit = require("./Fit")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")

local M = {}

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "Apex")
	local r = Layout.Apex.Rect
	local y = Layout.Apex.Floor
	local keep = { Fit.rect(r.X0, r.X0 + 14, -10, 10) } -- skybridge entry
	Fit.pack(f, r, y, "E", {
		{ Type = "GravPress", Tier = 6, Count = 2 },
		{ Type = "ReflexWall", Tier = 6, Count = 2 },
		{ Type = "HyperTreadmill", Tier = 6, Count = 2 },
		{ Type = "HydroRower", Tier = 6, Count = 2 },
		{ Type = "DumbbellCurl", Tier = 6, Count = 2 },
		{ Type = "CryoPod", Tier = 6, Count = 2 },
	}, keep, { AreaId = "Apex", Aisle = 7, Gap = 4 })
	Props.wallSign(f, Fit.wallCf(r, "W", 30, y + 12, 1.15), "APEX LAB", Vector2.new(16, 2.6), "Neon")
	Props.tv(f, Fit.wallCf(r, "W", -30, y + 9, 1.15), 10, "BIOMETRICS ONLINE · ULTIMATE TIER")
	Fit.lights(f, r, Layout.Apex.Ceiling, "Panel", 18, nil, { Brightness = 1.6, Range = 28, Color = Color3.fromRGB(226, 240, 255) })
end

return M
