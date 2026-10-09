--!strict
--[[
	Site around the Ironhaven building (Y = 0 is the lobby floor / plaza level):
	  * grass ground over the site lot (Site.LOT; the city's block pads and
	    streets cover everything else inside Layout.CityBounds);
	  * entrance plaza: pale stone walkway on the main axis, two reflecting
	    pools, planters with trees, benches, flags, bollards, park lamps;
	  * main street (Layout.Street): asphalt, lane markings, zebra crossing on
	    the plaza axis, street lamps and street trees along both kerbs;
	  * parking strip south of the Apex pavilion with a paved forecourt under it;
	  * the Yard: grass ground, concrete entry apron + promenade, a 10-stud
	    mesh fence around Layout.Yard.Bounds with the gate opening left EMPTY,
	    and the concrete path from the Free Weights door (Layout.Yard.Path).
	The Yard's track / sprint / obstacle / strongman content belongs to the
	Yard area engineer. Heights: plaza, sidewalks, paths, yard top = 0;
	grass top = -0.3; street asphalt top = -0.5 (kerb = sidewalk edge).
]]

local Context = require("../Context")
local Ground = require("../Shell/Ground")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Palette = require("../Palette")
local Props = require("../Props")

local Shell = Ground.Shell
local F = Shell.F
local R = Shell.rect

local M = {}

M.LOT = R(-470, 270, -140, 170) -- grass lot of the site (city streets run along its edges)
M.PARKING = R(184, 262, -134, -66)
M.DRIVEWAY = R(236, 250, -150, -134)

local LINE_YELLOW = Palette.tint("PlasticYellow", Color3.fromRGB(214, 170, 62))
local ASPHALT_TOP = -0.5
local GRASS_TOP = -0.3

local function paint(parent: Instance, x0: number, x1: number, z0: number, z1: number, finish: Kit.FinishArg)
	Shell.plate(parent, x0, x1, z0, z1, ASPHALT_TOP, ASPHALT_TOP + 0.03, finish, { Collide = false, Shadow = false })
end

---------------------------------------------------------------------------
-- Entrance plaza
---------------------------------------------------------------------------
local function plaza(parent: Instance)
	local p = Layout.Plaza
	local m = Kit.model(parent, "Plaza")
	local walk = R(-16, 16, p.Z0, p.Z1)
	local pools = { R(-62, -26, -136, -114), R(26, 62, -136, -114) }
	local holes = { Shell.box2(walk), Shell.box2(pools[1]), Shell.box2(pools[2]) }
	for _, b in Shell.carve(p.X0, p.X1, p.Z0, p.Z1, holes) do
		Shell.plate(m, b.a0, b.a1, b.b0, b.b1, -1, 0, F.Paver)
	end
	Shell.plate(m, walk.X0, walk.X1, walk.Z0, walk.Z1, -1, 0, F.StoneLight)
	-- granite banding across the paver field (clear of the pools) + edging along the walkway
	for _, z in { -146, -140.5, -109.5 } do
		for _, sx in { -1, 1 } do
			Shell.plate(m, math.min(sx * 17, sx * 149), math.max(sx * 17, sx * 149), z - 0.4, z + 0.4, 0, 0.03, F.GraniteDark, { Collide = false, Shadow = false })
		end
	end
	Shell.plate(m, walk.X0 - 0.8, walk.X0, p.Z0, p.Z1, 0, 0.04, F.GraniteDark, Kit.DETAIL)
	Shell.plate(m, walk.X1, walk.X1 + 0.8, p.Z0, p.Z1, 0, 0.04, F.GraniteDark, Kit.DETAIL)

	-- reflecting pools: granite rim, dark basin, still water
	for _, q in pools do
		Shell.plate(m, q.X0, q.X1, q.Z0, q.Z1, -1, 0, "Slate")
		Shell.plate(m, q.X0 - 0.4, q.X1 + 0.4, q.Z0 - 0.4, q.Z0 + 0.8, 0, 0.7, F.GraniteDark)
		Shell.plate(m, q.X0 - 0.4, q.X1 + 0.4, q.Z1 - 0.8, q.Z1 + 0.4, 0, 0.7, F.GraniteDark)
		Shell.plate(m, q.X0 - 0.4, q.X0 + 0.8, q.Z0 + 0.8, q.Z1 - 0.8, 0, 0.7, F.GraniteDark)
		Shell.plate(m, q.X1 - 0.8, q.X1 + 0.4, q.Z0 + 0.8, q.Z1 - 0.8, 0, 0.7, F.GraniteDark)
		Shell.plate(m, q.X0 + 0.8, q.X1 - 0.8, q.Z0 + 0.8, q.Z1 - 0.8, 0.2, 0.35, "Water", { Collide = false, Shadow = false })
		local cx = (q.X0 + q.X1) / 2
		Props.bench(m, Kit.place(cx, 0, q.Z1 + 4, 0), 10, "Teak")
		Props.bench(m, Kit.place(cx, 0, q.Z0 - 4, 180), 10, "Teak")
	end

	-- planters with trees on the wings, flags by the east wing, bike rack
	for _, x in { -125, -92, 92, 125 } do
		Props.planter(m, Kit.place(x, 0, -124, 0), Vector3.new(16, 1.8, 12), F.GraniteDark, "Bush")
		Props.tree(m, Kit.place(x, 1.8, -124, 0), "Oak", 1.15)
	end
	for i, c in { Color3.fromRGB(242, 169, 59), Color3.fromRGB(28, 28, 30), Color3.fromRGB(244, 238, 226) } do
		Props.flag(m, Kit.place(72 + i * 7, 0, -106, 0), c)
	end
	-- stone monument with the wordmark facing the street
	Shell.plate(m, -47, -29, -145.2, -143.2, 0, 3.4, F.StoneLight)
	Shell.plate(m, -47.4, -28.6, -145.6, -142.8, 0, 0.5, F.GraniteDark)
	local face = Shell.plate(m, -45.5, -30.5, -145.32, -145.2, 0.9, 2.7, F.BronzeDeep, Kit.DETAIL)
	face.Name = "MonumentSign"
	Kit.sign(face, "IRONHAVEN", {
		Face = Enum.NormalId.Front,
		Font = Font.new("rbxasset://fonts/families/Michroma.json", Enum.FontWeight.Regular),
		TextColor = Color3.fromRGB(246, 238, 222),
		PixelsPerStud = 30,
		LightInfluence = 0.4,
		Padding = 0.12,
	})
	Props.bikeRack(m, Kit.place(-80, 0, -104, 0))
	Props.bikeRack(m, Kit.place(-72, 0, -104, 0))
	for x = -14, 14, 4 do
		Props.bollard(m, Kit.place(x, 0, p.Z0 + 1.5, 0))
	end
	for _, x in { -20, 20 } do
		for _, z in { -110, -140 } do
			Props.lampPost(m, Kit.place(x, 0, z, if x < 0 then -90 else 90), "Park")
		end
	end
end

---------------------------------------------------------------------------
-- Main street + sidewalk
---------------------------------------------------------------------------
local function street(parent: Instance)
	local s = Layout.Street
	local m = Kit.model(parent, "Street")
	local lot = M.LOT
	Shell.plate(m, s.X0, s.X1, s.Z0, s.Z1, -1.5, ASPHALT_TOP, "Asphalt")
	local zc = (s.Z0 + s.Z1) / 2
	paint(m, s.X0, s.X1, zc - 0.65, zc - 0.35, LINE_YELLOW)
	paint(m, s.X0, s.X1, zc + 0.35, zc + 0.65, LINE_YELLOW)
	paint(m, s.X0, s.X1, s.Z0 + 1.6, s.Z0 + 1.9, "Cream")
	paint(m, s.X0, s.X1, s.Z1 - 1.9, s.Z1 - 1.6, "Cream")
	-- dashed lane dividers near the site, zebra crossing + stop lines on the plaza axis
	for _, lz in { zc - 12.5, zc + 12.5 } do
		for x = -440, 440, 16 do
			if math.abs(x) > 26 then
				paint(m, x - 3, x + 3, lz - 0.15, lz + 0.15, "Cream")
			end
		end
	end
	for x = -11, 11, 3.15 do
		paint(m, x - 0.8, x + 0.8, s.Z0 + 3, s.Z1 - 3, "Cream")
	end
	paint(m, -19.5, -18.5, s.Z0 + 2, zc - 1, "Cream")
	paint(m, 18.5, 19.5, zc + 1, s.Z1 - 2, "Cream")

	-- north sidewalk outside the plaza (driveway into the parking strip cut out)
	local d = M.DRIVEWAY
	local walkHoles = { Shell.box2(R(Layout.Plaza.X0, Layout.Plaza.X1, s.Z1, s.Z1 + 10)), Shell.box2(d) }
	for _, b in Shell.carve(lot.X0, lot.X1, s.Z1, s.Z1 + 10, walkHoles) do
		Shell.plate(m, b.a0, b.a1, b.b0, b.b1, -1, 0, "Pavement")
	end

	-- street lamps + trees along both kerbs (south kerb stands on the city pads)
	for x = -640, 640, 80 do
		if math.abs(x) > 30 then
			Props.lampPost(m, Kit.place(x, 0, s.Z1 + 3, 0), "Street")
			Props.lampPost(m, Kit.place(x + 40, 0, s.Z0 - 3, 180), "Street")
		end
		if math.abs(x + 40) > 50 and math.abs(x + 40 - 243) > 14 then
			Props.tree(m, Kit.place(x + 40, 0, s.Z1 + 5, 0), "Street", 1)
		end
		Props.tree(m, Kit.place(x, 0, s.Z0 - 5, 0), "Street", 1)
	end
end

---------------------------------------------------------------------------
-- Parking strip + Apex forecourt
---------------------------------------------------------------------------
local function parking(parent: Instance)
	local m = Kit.model(parent, "Parking")
	local p, d = M.PARKING, M.DRIVEWAY
	Shell.plate(m, p.X0, p.X1, p.Z0, p.Z1, -1, 0, "Asphalt")
	Shell.plate(m, d.X0, d.X1, d.Z0, d.Z1, -1, 0, "Asphalt")
	-- bay lines: north row (nose north) and south row (nose south) around the aisle
	local bay = 9
	for i = 0, 8 do
		local x = p.X0 + 2 + i * bay
		Shell.plate(m, x - 0.15, x + 0.15, p.Z1 - 17, p.Z1 - 1, 0, 0.03, "Cream", { Collide = false, Shadow = false })
		Shell.plate(m, x - 0.15, x + 0.15, p.Z0 + 1, p.Z0 + 17, 0, 0.03, "Cream", { Collide = false, Shadow = false })
	end
	-- kerb stops / planting strip between rows
	local colors = {
		Color3.fromRGB(28, 30, 34),
		Color3.fromRGB(196, 198, 200),
		Color3.fromRGB(96, 24, 30),
		Color3.fromRGB(58, 70, 86),
		Color3.fromRGB(232, 232, 228),
		Color3.fromRGB(70, 72, 74),
	}
	local spots = { { 1, 1 }, { 3, 1 }, { 4, 1 }, { 7, 1 }, { 2, -1 }, { 6, -1 } }
	for i, sp in spots do
		local x = p.X0 + 2 + (sp[1] - 0.5) * bay
		local z = if sp[2] > 0 then p.Z1 - 9 else p.Z0 + 9
		Props.car(m, Kit.place(x, 0, z, if sp[2] > 0 then 180 else 0), colors[i])
	end
	for _, x in { p.X0 + 20, p.X1 - 20 } do
		Props.lampPost(m, Kit.place(x, 0, (p.Z0 + p.Z1) / 2, 90), "Street")
	end
	-- forecourt under the Apex pavilion + link path to the parking
	local a = Layout.Apex.Rect
	Shell.plate(m, a.X0 - 4, a.X1 + 4, a.Z0 - 4, a.Z1 + 4, -1, 0, F.Paver)
	Shell.plate(m, 204, 240, p.Z1, a.Z0 - 4, -1, 0, F.Paver)
end

---------------------------------------------------------------------------
-- Yard ground, paths and fence
---------------------------------------------------------------------------
local function fenceRun(parent: Instance, a: Vector3, b: Vector3, h: number)
	local dir = b - a
	local len = dir.Magnitude
	local mid = (a + b) / 2
	local alongX = math.abs(dir.X) > math.abs(dir.Z)
	local size = if alongX then Vector3.new(len, 1, 0.12) else Vector3.new(0.12, 1, len)
	local function bar(y0: number, y1: number, finish: Kit.FinishArg, opts: Kit.Opts?, thick: number?)
		local t = thick or 0.12
		local sz = if alongX then Vector3.new(size.X, y1 - y0, t) else Vector3.new(t, y1 - y0, size.Z)
		return Kit.box(parent, CFrame.new(mid.X, (y0 + y1) / 2, mid.Z), sz, finish, opts)
	end
	-- welded mesh panel (semi-transparent dark), rails
	local mesh = bar(0.4, h - 0.3, "PowderBlack", { Collide = true, Shadow = false, Transparency = 0.55 })
	mesh.Name = "FenceMesh"
	bar(h - 0.3, h, "PowderGraphite", Kit.DETAIL, 0.3)
	bar(0, 0.4, "ConcreteDark", { Collide = true }, 0.6)
	bar(h * 0.5 - 0.1, h * 0.5 + 0.1, "PowderGraphite", Kit.DETAIL, 0.2)
	local n = math.max(1, math.floor(len / 15 + 0.5))
	for i = 0, n do
		local p = a + dir * (i / n)
		Kit.box(parent, CFrame.new(p.X, h / 2, p.Z), Vector3.new(0.45, h, 0.45), "PowderGraphite", { Collide = true })
	end
end

local function yard(parent: Instance)
	local y = Layout.Yard
	local b = y.Bounds
	local m = Kit.model(parent, "YardSite")
	local apron = R(-202, b.X1, -14, 10)
	local prom = R(-212, -202, b.Z0 + 10, b.Z1 - 10)
	for _, q in Shell.carve(b.X0, b.X1, b.Z0, b.Z1, { Shell.box2(apron), Shell.box2(prom) }) do
		Shell.plate(m, q.a0, q.a1, q.b0, q.b1, -1, 0, "Grass")
	end
	Shell.plate(m, apron.X0, apron.X1, apron.Z0, apron.Z1, -1, 0, "Concrete")
	for _, q in Shell.carve(prom.X0, prom.X1, prom.Z0, prom.Z1, { Shell.box2(apron) }) do
		Shell.plate(m, q.a0, q.a1, q.b0, q.b1, -1, 0, "Concrete")
	end
	-- path from the Free Weights door to the gate
	local p = y.Path
	Shell.plate(m, p.X0, Layout.Building.X0, p.Z0, p.Z1, -1, 0, "Concrete")
	Shell.plate(m, p.X0, Layout.Building.X0 - 1, p.Z0 - 0.5, p.Z0, -0.6, 0.08, F.GraniteDark, Kit.DETAIL)
	Shell.plate(m, p.X0, Layout.Building.X0 - 1, p.Z1, p.Z1 + 0.5, -0.6, 0.08, F.GraniteDark, Kit.DETAIL)

	-- fence (gate opening on the east side stays empty for the gate model)
	local h = 10
	local g0, g1 = y.Gate.Z - y.Gate.Width / 2, y.Gate.Z + y.Gate.Width / 2
	local fence = Kit.model(m, "Fence")
	fenceRun(fence, Vector3.new(b.X0, 0, b.Z0), Vector3.new(b.X1, 0, b.Z0), h)
	fenceRun(fence, Vector3.new(b.X0, 0, b.Z1), Vector3.new(b.X1, 0, b.Z1), h)
	fenceRun(fence, Vector3.new(b.X0, 0, b.Z0), Vector3.new(b.X0, 0, b.Z1), h)
	fenceRun(fence, Vector3.new(b.X1, 0, b.Z0), Vector3.new(b.X1, 0, g0 - 0.4), h)
	fenceRun(fence, Vector3.new(b.X1, 0, g1 + 0.4), Vector3.new(b.X1, 0, b.Z1), h)
	-- heavier gate piers either side of the opening
	for _, z in { g0 - 0.9, g1 + 0.9 } do
		Kit.box(fence, CFrame.new(b.X1, (h + 1.4) / 2, z), Vector3.new(1.2, h + 1.4, 1), F.GraniteDark)
	end
	for _, z in { apron.Z0 + 1, apron.Z1 - 1 } do
		Props.lampPost(m, Kit.place(apron.X0 + 2, 0, z, -90), "Park")
	end
end

---------------------------------------------------------------------------
-- Landscape: trees around the building
---------------------------------------------------------------------------
local function landscape(parent: Instance)
	local m = Kit.model(parent, "Landscape")
	for x = -135, 135, 30 do
		local z = if x % 60 == 15 then 138 else 130
		Props.tree(m, Kit.place(x, GRASS_TOP, z, 0), if x % 90 == 45 then "Birch" else "Oak", 1.1)
	end
	for _, z in { -88, -64, 30, 60, 88 } do
		Props.tree(m, Kit.place(162, GRASS_TOP, z, 0), "Birch", 1)
	end
	for _, z in { -120, -60, 60, 120 } do
		Props.tree(m, Kit.place(-455, GRASS_TOP, z, 0), "Pine", 1.2)
	end
	for _, x in { 186, 258 } do
		for _, z in { -30, 30 } do
			Props.planter(m, Kit.place(x, 0, z, 0), Vector3.new(6, 1.6, 6), F.GraniteDark, "Bush")
		end
	end
end

function M.build(ctx: Context.Ctx)
	local root = Kit.folder(ctx.Exterior, "Site")
	local lot = M.LOT
	local b = Layout.Building
	Shell.plates(root, lot, { R(b.X0 - 1, b.X1 + 1, b.Z0 - 1, b.Z1 + 1) }, -4, GRASS_TOP, "Grass")
	plaza(root)
	street(root)
	parking(root)
	yard(root)
	landscape(root)
end

return M
