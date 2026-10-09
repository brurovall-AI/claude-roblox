--!strict
-- Private Suites: three glass-walled suites with elite equipment.
local Context = require("../Context")
local Fit = require("./Fit")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")

local M = {}

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "Private")
	local r = Layout.B1.Private
	local y = Layout.Y.B1
	-- entry hall along the south side, suites to the north
	for _, x in { -20, 20 } do
		Kit.box(f, CFrame.new(x, y + 9, 35), Vector3.new(0.4, 18, 50), "GlassSmoked")
		Kit.box(f, CFrame.new(x, y + 0.1, 35), Vector3.new(0.6, 0.2, 50), "Walnut", Kit.DETAIL)
	end
	for i, x0 in { -60, -20, 20 } do
		local rect = Fit.rect(x0, x0 + 40, 12, r.Z1)
		Kit.box(f, CFrame.new(x0 + 20, y + 0.05, 36), Vector3.new(38, 0.1, 47), "WalnutPlanks", Kit.DETAIL)
		Fit.pack(f, rect, y, "N", {
			{ Type = "BenchPress", Tier = 4 },
			{ Type = "DumbbellCurl", Tier = 4 },
			{ Type = "Rower", Tier = 4 },
		}, nil, { AreaId = "Private", Gap = 4 })
		Props.wallSign(f, Kit.place(x0 + 20, y + 10, 11.7, 0), "SUITE " .. i, Vector2.new(6, 1.4), "Wayfinding")
		Props.plant(f, CFrame.new(x0 + 4, y, 15), "Snake", 1)
	end
	Fit.lights(f, r, Layout.CEIL.B1, "Linear", 20, nil, { Brightness = 1.3, Range = 30, Drop = 2, Color = Color3.fromRGB(255, 226, 196) })
end

return M
