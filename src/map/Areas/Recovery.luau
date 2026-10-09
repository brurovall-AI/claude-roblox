--!strict
-- Recovery Studio: yoga studio, cedar sauna, ice baths, massage.
local Context = require("../Context")
local Fit = require("./Fit")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")

local M = {}

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "Recovery")
	local r = Layout.B1.Recovery
	local y = Layout.Y.B1
	local door = Fit.doorKeepout(Layout.door("B1", "ConcourseToRecovery"), 12)

	-- yoga studio (south half)
	Fit.pack(f, Fit.rect(72, r.X1, r.Z0, -40), y, "E", {
		{ Type = "YogaMat", Tier = 3, Count = 4 },
		{ Type = "YogaMat", Tier = 4, Count = 3 },
	}, { door }, { AreaId = "Recovery", Gap = 2 })
	Props.mirror(f, Fit.wallCf(r, "E", -70, y + 5.5, 1.15), 40, 8, "Birch")
	Props.foamRollers(f, Fit.againstWall(r, "S", 120, y, 1.4))

	-- cedar sauna room (north-east)
	local sx0, sx1, sz0, sz1 = 120, 149, 24, 59
	for _, w in {
		{ cf = CFrame.new((sx0 + sx1) / 2, y + 5, sz0), size = Vector3.new(sx1 - sx0, 10, 0.6) },
		{ cf = CFrame.new(sx0, y + 5, (sz0 + sz1) / 2 + 4), size = Vector3.new(0.6, 10, sz1 - sz0 - 8) },
	} do
		Kit.box(f, w.cf, w.size, "Cedar")
	end
	Kit.box(f, CFrame.new(sx0, y + 5, sz0 + 2), Vector3.new(0.3, 10, 4), "GlassFrosted", { Collide = false })
	Fit.pack(f, Fit.rect(sx0 + 1, sx1, sz0 + 1, sz1), y, "E", {
		{ Type = "Sauna", Tier = 4, Count = 3 },
	}, nil, { AreaId = "Recovery", Margin = 2 })

	-- cold zone (north-west): ice baths on stone
	Kit.box(f, CFrame.new(94, y + 0.06, 40), Vector3.new(44, 0.12, 36), "Stone", Kit.DETAIL)
	Fit.pack(f, Fit.rect(72, 116, 22, 58), y, "N", {
		{ Type = "IceBath", Tier = 4, Count = 2 },
		{ Type = "IceBath", Tier = 5 },
	}, nil, { AreaId = "Recovery", Gap = 4 })

	-- massage + lounge (middle)
	Props.massageTable(f, Kit.place(96, y, -20, 90))
	Props.massageTable(f, Kit.place(110, y, -20, 90))
	Props.towelStack(f, CFrame.new(125, y, -24), 6)
	Props.wallSign(f, Fit.wallCf(r, "S", 110, y + 13, 1.15), "RECOVERY STUDIO", Vector2.new(20, 2.6), "Area")
	Fit.cornerPlants(f, r, y, "Fern")
	Props.plant(f, CFrame.new(80, y, -10), "Monstera", 1.2)
	Fit.lights(f, r, Layout.CEIL.B1, "Downlight", 24, nil, { Brightness = 1.1, Range = 34, Color = Color3.fromRGB(255, 214, 170) })
end

return M
