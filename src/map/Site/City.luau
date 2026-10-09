--!strict
--[[
	City ring around the site, inside Layout.CityBounds, plus a low-detail
	horizon beyond it.

	  * Street grid: E-W streets at Z = -430, 180, 380 (+ the main street from
	    Shell/Site, extended here to the bounds); N-S streets at X = -640,
	    -480, 280, 480, 660 through every band and at -290, -100, 100 only in
	    the bands north / south of the site. Every block gets a paved pad
	    (top = 0, kerb to the asphalt at -0.5).
	  * ~70 buildings with few parts each: glass towers (mullion strips +
	    floor rings), stone-spandrel offices, brick mid-rises (window bands +
	    piers, water tanks), three stepped landmark towers. Heights grow with
	    distance from the gym (40-90 next to the site, up to 260 far out) so
	    Ironhaven stays the hero. Two blocks are parks (north of the building
	    and across the street from the plaza).
	  * Streaming: each building is an Atomic model with
	    LevelOfDetail = StreamingMesh (imposter when outside the stream radius);
	    the far ground + horizon blocks are a Persistent model so the skyline
	    is always present.
	Deterministic: a fixed-seed Park-Miller generator, no math.random.
]]

local Context = require("../Context")
local Ground = require("../Shell/Ground")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Palette = require("../Palette")
local Site = require("./Site")

local Shell = Ground.Shell
type Finish = Palette.Finish

local M = {}

local CB = Layout.CityBounds
local ST = Layout.Street
local HALF = 10 -- street half width
local ZS = { -430, 180, 380 }
local XS_FULL = { -640, -480, 280, 480, 660 }
local XS_OUTER = { -290, -100, 100 }

---------------------------------------------------------------------------
-- Deterministic random
---------------------------------------------------------------------------
local seed = 20261008
local function rnd(): number
	seed = (seed * 16807) % 2147483647
	return seed / 2147483647
end
local function range(a: number, b: number): number
	return a + (b - a) * rnd()
end
local function pick<T>(list: { T }): T
	return list[math.min(#list, math.floor(rnd() * #list) + 1)]
end

---------------------------------------------------------------------------
-- Finishes
---------------------------------------------------------------------------
local function glass(c: Color3): Finish
	return { Material = Enum.Material.Glass, Color = c, Reflectance = 0.22 }
end
local GLASS = {
	glass(Color3.fromRGB(92, 116, 132)),
	glass(Color3.fromRGB(70, 96, 108)),
	glass(Color3.fromRGB(112, 128, 136)),
	glass(Color3.fromRGB(86, 100, 92)),
	glass(Color3.fromRGB(104, 96, 86)),
}
local DARK_GLASS = glass(Color3.fromRGB(46, 54, 62))
local STONE = {
	Palette.tint("Concrete", Color3.fromRGB(196, 190, 178)),
	Palette.tint("Travertine", Color3.fromRGB(204, 192, 170)),
	Palette.tint("Concrete", Color3.fromRGB(164, 160, 154)),
	Palette.tint("Concrete", Color3.fromRGB(214, 210, 202)),
}
local BRICK = {
	Palette.get("Brick"),
	Palette.get("BrickDark"),
	Palette.tint("Brick", Color3.fromRGB(162, 96, 70)),
	Palette.tint("Brick", Color3.fromRGB(120, 84, 70)),
	Palette.get("BrickWhite"),
}
local METAL = { Palette.get("SteelDark"), Palette.get("Iron"), Palette.tint("Steel", Color3.fromRGB(176, 178, 180)) }
local LEAF = Palette.get("LeafDark")

---------------------------------------------------------------------------
-- Building types (cx, cz = footprint centre; w along X, d along Z)
---------------------------------------------------------------------------
type Bld = { cx: number, cz: number, w: number, d: number, h: number }

local function cityModel(parent: Instance, name: string, b: Bld): Model
	local m = Kit.model(parent, name, CFrame.new(b.cx, 0, b.cz))
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.LevelOfDetail = (Enum :: any).ModelLevelOfDetail.StreamingMesh
	return m
end

local function box(parent: Instance, cx: number, y0: number, cz: number, w: number, h: number, d: number, f: Kit.FinishArg, detail: boolean?): Part
	return Kit.box(parent, CFrame.new(cx, y0 + h / 2, cz), Vector3.new(w, h, d), f, if detail then Kit.DETAIL else nil)
end

-- Rooftop clutter: plant room box, optional antenna.
local function rooftop(m: Model, b: Bld, top: number, antenna: boolean)
	local mw, md = math.min(b.w * 0.4, 18), math.min(b.d * 0.35, 14)
	box(m, b.cx + range(-0.15, 0.15) * b.w, top, b.cz + range(-0.15, 0.15) * b.d, mw, range(4, 7), md, pick(METAL), true)
	if antenna then
		Kit.cylY(m, CFrame.new(b.cx, top + 14, b.cz), 28, 0.6, "SteelDark", Kit.DETAIL)
	end
end

local function glassTower(parent: Instance, b: Bld)
	local m = cityModel(parent, "GlassTower", b)
	local f = pick(GLASS)
	local metal = pick(METAL)
	local y0 = 0
	if b.h > 110 then
		box(m, b.cx, 0, b.cz, b.w + 8, 14, b.d + 8, pick(STONE))
		y0 = 14
	end
	local h = b.h - y0
	box(m, b.cx, y0, b.cz, b.w, h, b.d, f)
	-- mullion strips on every face
	local nx = math.clamp(math.floor(b.w / 12), 2, 5)
	local nz = math.clamp(math.floor(b.d / 12), 2, 5)
	for i = 1, nx do
		local x = b.cx - b.w / 2 + b.w * i / (nx + 1)
		box(m, x, y0, b.cz - b.d / 2 - 0.2, 0.6, h, 0.5, metal, true)
		box(m, x, y0, b.cz + b.d / 2 + 0.2, 0.6, h, 0.5, metal, true)
	end
	for i = 1, nz do
		local z = b.cz - b.d / 2 + b.d * i / (nz + 1)
		box(m, b.cx - b.w / 2 - 0.2, y0, z, 0.5, h, 0.6, metal, true)
		box(m, b.cx + b.w / 2 + 0.2, y0, z, 0.5, h, 0.6, metal, true)
	end
	-- floor rings every 16 studs
	local y = y0 + 16
	while y < b.h - 6 do
		box(m, b.cx, y, b.cz, b.w + 0.5, 0.6, b.d + 0.5, metal, true)
		y += 16
	end
	box(m, b.cx, b.h - 2.5, b.cz, b.w + 1, 2.7, b.d + 1, metal)
	rooftop(m, b, b.h + 0.2, b.h > 150)
end

local function office(parent: Instance, b: Bld)
	local m = cityModel(parent, "Office", b)
	local stone = pick(STONE)
	box(m, b.cx, 0, b.cz, b.w - 0.4, b.h, b.d - 0.4, DARK_GLASS)
	box(m, b.cx, 0, b.cz, b.w + 0.4, 6, b.d + 0.4, stone)
	local floorH = range(11, 13)
	local y = 6 + floorH - 3
	while y < b.h - 4 do
		box(m, b.cx, y, b.cz, b.w + 0.4, 3, b.d + 0.4, stone)
		y += floorH
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(m, b.cx + sx * (b.w / 2 - 0.6), 0, b.cz + sz * (b.d / 2 - 0.6), 1.8, b.h, 1.8, stone)
		end
	end
	box(m, b.cx, b.h, b.cz, b.w + 0.8, 1.4, b.d + 0.8, stone)
	rooftop(m, b, b.h + 1.4, false)
end

local function brick(parent: Instance, b: Bld)
	local m = cityModel(parent, "BrickBlock", b)
	local f = pick(BRICK)
	local stone = pick(STONE)
	box(m, b.cx, 0, b.cz, b.w, b.h, b.d, f)
	box(m, b.cx, 0, b.cz, b.w + 0.6, 7, b.d + 0.6, stone)
	local floorH = 11
	local y = 9.5
	while y + 5 < b.h - 3 do
		box(m, b.cx, y, b.cz, b.w + 0.3, 5.2, b.d - 3, DARK_GLASS, true)
		box(m, b.cx, y, b.cz, b.w - 3, 5.2, b.d + 0.3, DARK_GLASS, true)
		y += floorH
	end
	-- piers break the bands into windows
	local px = math.clamp(math.floor(b.w / 9), 2, 6)
	local pz = math.clamp(math.floor(b.d / 9), 2, 6)
	for i = 1, px - 1 do
		local x = b.cx - b.w / 2 + b.w * i / px
		box(m, x, 7, b.cz - b.d / 2 - 0.25, 1.6, b.h - 9, 0.7, f, true)
		box(m, x, 7, b.cz + b.d / 2 + 0.25, 1.6, b.h - 9, 0.7, f, true)
	end
	for i = 1, pz - 1 do
		local z = b.cz - b.d / 2 + b.d * i / pz
		box(m, b.cx - b.w / 2 - 0.25, 7, z, 0.7, b.h - 9, 1.6, f, true)
		box(m, b.cx + b.w / 2 + 0.25, 7, z, 0.7, b.h - 9, 1.6, f, true)
	end
	box(m, b.cx, b.h - 1.5, b.cz, b.w + 1.4, 1.7, b.d + 1.4, stone)
	if rnd() < 0.6 then
		-- timber water tank on steel legs
		local tx, tz = b.cx + b.w * 0.2, b.cz - b.d * 0.15
		box(m, tx, b.h, tz, 6, 4, 6, "SteelDark", true)
		Kit.cylY(m, CFrame.new(tx, b.h + 8, tz), 8, 7, "WornTimber", Kit.DETAIL)
		Kit.wedge(m, CFrame.new(tx, b.h + 13, tz), Vector3.new(7, 2, 7), "SteelDark", Kit.DETAIL)
	else
		rooftop(m, b, b.h, false)
	end
end

local function landmark(parent: Instance, b: Bld)
	local m = cityModel(parent, "Landmark", b)
	local f = pick(GLASS)
	local metal = METAL[3]
	box(m, b.cx, 0, b.cz, b.w + 12, 18, b.d + 12, pick(STONE))
	local tiers = { { s = 1, h = 0.58 }, { s = 0.76, h = 0.27 }, { s = 0.52, h = 0.15 } }
	local y = 18
	for _, t in tiers do
		local w, d = b.w * t.s, b.d * t.s
		local h = (b.h - 18) * t.h
		box(m, b.cx, y, b.cz, w, h, d, f)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(m, b.cx + sx * w / 2, y, b.cz + sz * d / 2, 1.4, h, 1.4, metal, true)
			end
		end
		local ry = y + 24
		while ry < y + h - 4 do
			box(m, b.cx, ry, b.cz, w + 0.6, 0.8, d + 0.6, metal, true)
			ry += 24
		end
		box(m, b.cx, y + h - 1.5, b.cz, w + 1.4, 1.7, d + 1.4, metal)
		y += h
	end
	-- open crown + spire
	local cw = b.w * 0.52
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			box(m, b.cx + sx * cw / 2, y, b.cz + sz * cw / 2, 1, 12, 1, metal, true)
		end
	end
	box(m, b.cx, y + 11, b.cz, cw + 1, 1, cw + 1, metal, true)
	Kit.cylY(m, CFrame.new(b.cx, y + 30, b.cz), 40, 1.2, metal, Kit.DETAIL)
	Kit.ball(m, Vector3.new(b.cx, y + 50.5, b.cz), 1.4, "LightRed", Kit.DETAIL)
end

local function tree(parent: Instance, x: number, z: number, s: number)
	Kit.cylY(parent, CFrame.new(x, 3 * s, z), 6 * s, 0.9 * s, "Bark", Kit.DETAIL)
	Kit.ball(parent, Vector3.new(x, 8 * s, z), 8 * s, LEAF, { Collide = false, Shadow = true })
	Kit.ball(parent, Vector3.new(x + 1.5 * s, 10.5 * s, z - s), 5.5 * s, "Leaf", { Collide = false, Shadow = true })
end

local function park(parent: Instance, x0: number, x1: number, z0: number, z1: number)
	local m = Kit.model(parent, "Park")
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	Shell.plate(m, x0 + 6, x1 - 6, z0 + 6, z1 - 6, 0, 0.12, "Grass")
	Shell.plate(m, cx - 4, cx + 4, z0 + 6, z1 - 6, 0.12, 0.16, "Pavement", Kit.DETAIL)
	Shell.plate(m, x0 + 6, x1 - 6, cz - 4, cz + 4, 0.12, 0.16, "Pavement", Kit.DETAIL)
	-- fountain at the crossing
	Kit.cylY(m, CFrame.new(cx, 0.6, cz), 1, 18, "Concrete")
	Kit.cylY(m, CFrame.new(cx, 0.9, cz), 0.6, 16, "Water", { Collide = false, Shadow = false })
	Kit.cylY(m, CFrame.new(cx, 2.2, cz), 3.4, 3, "Concrete", Kit.DETAIL)
	-- trees in the four lawns, benches along the paths
	for _, q in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local lx0 = if q[1] < 0 then x0 + 12 else cx + 10
		local lx1 = if q[1] < 0 then cx - 10 else x1 - 12
		local lz0 = if q[2] < 0 then z0 + 12 else cz + 10
		local lz1 = if q[2] < 0 then cz - 10 else z1 - 12
		for _ = 1, 6 do
			tree(m, range(lx0, lx1), range(lz0, lz1), range(0.9, 1.45))
		end
		Kit.box(m, CFrame.new(cx + q[1] * 7, 0.9, cz + q[2] * 22), Vector3.new(1.4, 0.4, 6), "Teak", { Collide = true })
		Kit.box(m, CFrame.new(cx + q[1] * 7, 0.45, cz + q[2] * 22), Vector3.new(1, 0.9, 4.6), "ConcreteDark", Kit.DETAIL)
	end
end

---------------------------------------------------------------------------
-- Blocks
---------------------------------------------------------------------------
local LANDMARK_BLOCKS = { ["390:490"] = true, ["390:-280"] = true, ["-620:290"] = true }
local PARK_BLOCKS = { ["190:-90"] = true, ["-420:-90"] = true }

local function heightFor(cx: number, cz: number): number
	local d = math.sqrt(cx * cx + cz * cz)
	if d < 430 then
		return range(40, 92)
	elseif d < 640 then
		return range(60, 150)
	end
	return range(90, 225)
end

local function building(parent: Instance, b: Bld)
	if b.h > 115 then
		if rnd() < 0.7 then
			glassTower(parent, b)
		else
			office(parent, b)
		end
	else
		local r = rnd()
		if r < 0.42 then
			brick(parent, b)
		elseif r < 0.75 then
			office(parent, b)
		else
			glassTower(parent, b)
		end
	end
end

-- Fill one block lot with 1-4 buildings.
local function fillBlock(parent: Instance, x0: number, x1: number, z0: number, z1: number, key: string)
	local inset = 8
	local lx0, lx1, lz0, lz1 = x0 + inset, x1 - inset, z0 + inset, z1 - inset
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	if LANDMARK_BLOCKS[key] then
		local s = math.min(lx1 - lx0, lz1 - lz0) * 0.42
		landmark(parent, { cx = cx, cz = cz, w = s, d = s, h = range(235, 262) })
		return
	end
	local w, d = lx1 - lx0, lz1 - lz0
	-- split the longer side into 1-3 parts, the shorter into 1-2 (~65 buildings overall)
	local long, short = math.max(w, d), math.min(w, d)
	local nl = if long > 260 then (if rnd() < 0.35 then 3 else 2) elseif long > 150 then (if rnd() < 0.55 then 2 else 1) else 1
	local ns = if short > 150 and rnd() < 0.25 then 2 else 1
	local nx, nz = if w >= d then nl else ns, if w >= d then ns else nl
	local gap = 10
	local cw, cd = (w - gap * (nx - 1)) / nx, (d - gap * (nz - 1)) / nz
	for ix = 1, nx do
		for iz = 1, nz do
			local px = lx0 + (ix - 1) * (cw + gap) + cw / 2
			local pz = lz0 + (iz - 1) * (cd + gap) + cd / 2
			local bw = math.min(cw * range(0.62, 0.92), 78)
			local bd = math.min(cd * range(0.62, 0.92), 78)
			local h = heightFor(px, pz)
			-- slender towers get smaller footprints
			if h > 140 then
				bw = math.min(bw, 56)
				bd = math.min(bd, 56)
			end
			building(parent, {
				cx = px + range(-0.5, 0.5) * (cw - bw),
				cz = pz + range(-0.5, 0.5) * (cd - bd),
				w = bw,
				d = bd,
				h = h,
			})
		end
	end
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function asphalt(parent: Instance, x0: number, x1: number, z0: number, z1: number, alongX: boolean)
	Shell.plate(parent, x0, x1, z0, z1, -1.5, -0.5, "Asphalt")
	local paint: Kit.Opts = { Collide = false, Shadow = false }
	if alongX then
		local zc = (z0 + z1) / 2
		Shell.plate(parent, x0, x1, zc - 0.15, zc + 0.15, -0.5, -0.47, "Cream", paint)
	else
		local xc = (x0 + x1) / 2
		Shell.plate(parent, xc - 0.15, xc + 0.15, z0, z1, -0.5, -0.47, "Cream", paint)
	end
end

local function horizon(parent: Instance)
	local m = Kit.model(parent, "Horizon")
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	-- far ground ring (top -0.6) out to ~2 km
	local far = Palette.tint("Concrete", Color3.fromRGB(92, 96, 92))
	local E = 2000
	local spanX = (CB.X1 + E - (CB.X0 - E)) / 3 -- three plates per strip (part size limit 2048)
	for i = 1, 3 do
		local x0 = CB.X0 - E + (i - 1) * spanX
		Shell.plate(m, x0, x0 + spanX, CB.Z1, CB.Z1 + E, -2, -0.6, far, { Shadow = false })
		Shell.plate(m, x0, x0 + spanX, CB.Z0 - E, CB.Z0, -2, -0.6, far, { Shadow = false })
	end
	Shell.plate(m, CB.X0 - E, CB.X0, CB.Z0, CB.Z1, -2, -0.6, far, { Shadow = false })
	Shell.plate(m, CB.X1, CB.X1 + E, CB.Z0, CB.Z1, -2, -0.6, far, { Shadow = false })

	-- hazy blocks: denser and taller toward the north-east "downtown"
	local hazes = {
		Palette.tint("Plastic", Color3.fromRGB(150, 158, 168)),
		Palette.tint("Plastic", Color3.fromRGB(136, 144, 154)),
		Palette.tint("Plastic", Color3.fromRGB(164, 168, 172)),
		Palette.tint("Plastic", Color3.fromRGB(122, 130, 142)),
	}
	local cx, cz = (CB.X0 + CB.X1) / 2, (CB.Z0 + CB.Z1) / 2
	for i = 1, 76 do
		local ang = (i / 76) * math.pi * 2 + range(-0.03, 0.03)
		local dist = range(1050, 1650)
		local x, z = cx + math.cos(ang) * dist, cz + math.sin(ang) * dist
		local downtown = math.cos(ang - math.rad(50)) -- 1 toward north-east
		local h = range(40, 120) + math.max(0, downtown) * range(60, 240)
		local w, d = range(50, 130), range(50, 130)
		box(m, x, -0.6, z, w, h, d, pick(hazes))
	end
end

function M.build(ctx: Context.Ctx)
	local root = Kit.folder(ctx.Exterior, "City")
	local streets = Kit.model(root, "Streets")
	local blocks = Kit.folder(root, "Blocks")

	-- E-W streets, main street extensions
	for _, z in ZS do
		asphalt(streets, CB.X0, CB.X1, z - HALF, z + HALF, true)
	end
	asphalt(streets, CB.X0, ST.X0, ST.Z0, ST.Z1, true)
	asphalt(streets, ST.X1, CB.X1, ST.Z0, ST.Z1, true)

	local bands: { { z0: number, z1: number, outer: boolean } } = {
		{ z0 = CB.Z0, z1 = ZS[1] - HALF, outer = true },
		{ z0 = ZS[1] + HALF, z1 = ST.Z0, outer = true },
		{ z0 = ST.Z1, z1 = ZS[2] - HALF, outer = false },
		{ z0 = ZS[2] + HALF, z1 = ZS[3] - HALF, outer = true },
		{ z0 = ZS[3] + HALF, z1 = CB.Z1, outer = true },
	}
	local lot = Site.LOT
	for _, band in bands do
		local cuts: { number } = table.clone(XS_FULL)
		if band.outer then
			for _, x in XS_OUTER do
				table.insert(cuts, x)
			end
		end
		table.sort(cuts)
		for _, x in cuts do
			asphalt(streets, x - HALF, x + HALF, band.z0, band.z1, false)
		end
		local edges: { number } = { CB.X0 }
		for _, x in cuts do
			table.insert(edges, x - HALF)
			table.insert(edges, x + HALF)
		end
		table.insert(edges, CB.X1)
		for i = 1, #edges, 2 do
			local x0, x1 = edges[i], edges[i + 1]
			local inSite = not band.outer and x0 >= lot.X0 - 1 and x1 <= lot.X1 + 1
			if not inSite and x1 - x0 > 20 then
				local key = string.format("%d:%d", math.floor(band.z0 + 0.5), math.floor(x0 + 0.5))
				Shell.plate(blocks, x0, x1, band.z0, band.z1, -1, 0, "Pavement")
				if PARK_BLOCKS[key] then
					park(blocks, x0, x1, band.z0, band.z1)
				else
					fillBlock(blocks, x0, x1, band.z0, band.z1, key)
				end
			end
		end
	end

	horizon(root)
end

return M
