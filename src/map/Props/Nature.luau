--!strict
--[[
	Nature props: potted plants, planters, trees, hanging plants.

	Plants are split into a pot builder and a foliage builder so planters can
	reuse the foliage without pots. Foliage layers several angled leaf plates
	or LeafyGrass balls in two or three greens; the deterministic RNG (seeded
	by position) varies leaf angles so a row of identical plants never looks
	copy-pasted. Everything except pots, planter walls and tree trunks is
	Kit.DETAIL (no collision).
]]

local C = require("./Common")

type B = C.B
type Rng = C.Rng

local L = C.L
local DETAIL = C.DETAIL
local FINE = C.FINE

-- greens (Grass reads as broad glossy leaves, LeafyGrass as bushy foliage)
local LEAF_DEEP = C.tint("LeafDark", C.rgb(38, 82, 48))
local LEAF_MID = C.tint("LeafDark", C.rgb(56, 104, 56))
local LEAF_FRESH = C.tint("Leaf", C.rgb(92, 138, 64))
local BUSH_A = C.tint("Leaf", C.rgb(62, 108, 56))
local BUSH_B = C.tint("Leaf", C.rgb(78, 124, 60))
local BUSH_C = C.tint("Leaf", C.rgb(50, 92, 50))
local OLIVE_A = C.tint("Leaf", C.rgb(118, 136, 98))
local OLIVE_B = C.tint("Leaf", C.rgb(100, 120, 86))
local SNAKE_A = C.tint("LeafDark", C.rgb(44, 84, 56))
local SNAKE_B = C.tint("LeafDark", C.rgb(96, 124, 62))
local BARK = C.F.Bark
local BARK_LIGHT = C.tint("Bark", C.rgb(120, 96, 74))
local SOIL = C.F.Soil

-- pot finishes
local POT_CREAM = C.tint("Plastic", C.rgb(232, 226, 214))
local POT_CHARCOAL = C.tint("Concrete", C.rgb(64, 64, 66))
local POT_TERRACOTTA = C.tint("Concrete", C.rgb(176, 100, 68))
local POT_STONE = C.tint("Concrete", C.rgb(164, 158, 148))
local POT_BASKET = C.tint("FabricCream", C.rgb(196, 170, 128))
local POT_DARKBAND = C.tint("Plastic", C.rgb(40, 40, 42))
local POT_FOOT = C.tint("PlasticBlack", C.rgb(34, 34, 36))

---------------------------------------------------------------------------
-- Pots: build at local (x, 0, z), return the soil-top height
---------------------------------------------------------------------------
type PotFn = (b: B, x: number, z: number, s: number) -> number

local function cylinderPot(finish: C.Finish, band: C.Finish, dia: number, h: number): PotFn
	return function(b: B, x: number, z: number, s: number): number
		local d, hh = dia * s, h * s
		b.cylY(x, 0.08 * s, z, 0.16 * s, d * 0.82, POT_FOOT, DETAIL) -- shadow-gap foot
		b.cylY(x, 0.16 * s + (hh - 0.16 * s) / 2, z, hh - 0.16 * s, d, finish)
		b.cylY(x, hh - 0.16 * s, z, 0.22 * s, d + 0.08 * s, band, DETAIL) -- lip band
		b.cylY(x, hh + 0.01, z, 0.06, d - 0.22 * s, SOIL, FINE)
		return hh
	end
end

local function squarePot(finish: C.Finish, w: number, h: number): PotFn
	return function(b: B, x: number, z: number, s: number): number
		local ww, hh = w * s, h * s
		b.box(x, 0.08 * s, z, ww * 0.86, 0.16 * s, ww * 0.86, POT_FOOT, DETAIL)
		b.box(x, 0.16 * s + (hh - 0.16 * s) / 2, z, ww, hh - 0.16 * s, ww, finish)
		b.box(x, hh + 0.01, z, ww - 0.2 * s, 0.06, ww - 0.2 * s, SOIL, FINE)
		return hh
	end
end

local function bowlPot(finish: C.Finish, dia: number, h: number): PotFn
	return function(b: B, x: number, z: number, s: number): number
		local d, hh = dia * s, h * s
		b.cylY(x, 0.2 * s, z, 0.4 * s, d * 0.5, finish) -- pedestal foot
		b.cylY(x, 0.4 * s + (hh - 0.4 * s) / 2, z, hh - 0.4 * s, d, finish)
		b.cylY(x, hh + 0.01, z, 0.06, d - 0.24 * s, SOIL, FINE)
		return hh
	end
end

local POTS: { [string]: PotFn } = {
	Fiddle = cylinderPot(POT_CREAM, POT_CREAM, 1.6, 1.7),
	Snake = squarePot(POT_CHARCOAL, 1.3, 1.5),
	Olive = cylinderPot(POT_TERRACOTTA, C.tint("Concrete", C.rgb(156, 86, 58)), 1.7, 1.6),
	Palm = cylinderPot(POT_CHARCOAL, POT_DARKBAND, 2.0, 1.8),
	Bush = bowlPot(POT_STONE, 2.3, 1.2),
	Fern = cylinderPot(POT_BASKET, C.tint("FabricCream", C.rgb(150, 124, 88)), 1.6, 1.2),
	Monstera = cylinderPot(POT_CREAM, POT_DARKBAND, 1.9, 1.4),
}

---------------------------------------------------------------------------
-- Foliage: rooted at local (x, y0, z), scale s
---------------------------------------------------------------------------
type FoliageFn = (b: B, x: number, y0: number, z: number, s: number, r: Rng) -> ()

-- flat leaf plate radiating from (x, y, z): yaw around the stem, pitch tilts the
-- tip up (+) or down (-), roll twists the blade about its own length axis
local function leaf(b: B, x: number, y: number, z: number, yaw: number, pitch: number, out: number, w: number, len: number, f: C.Finish, roll: number?)
	local lcf = L(x, y, z, 0, yaw, 0) * CFrame.new(0, 0, -out) * CFrame.Angles(math.rad(pitch), 0, math.rad(roll or 0)) * CFrame.new(0, 0, -len / 2)
	b.part(lcf, Vector3.new(w, 0.06, len), f, DETAIL)
end

local FOLIAGE: { [string]: FoliageFn } = {}

FOLIAGE.Fiddle = function(b: B, x: number, y0: number, z: number, s: number, r: Rng)
	local top = y0 + 3.7 * s
	b.cylY(x, (y0 + top) / 2, z, top - y0, 0.16 * s, BARK, DETAIL)
	local yaw = r.range(0, 360)
	local n = 12
	for i = 1, n do
		local t = (i - 1) / (n - 1)
		local y = y0 + (1.5 + 2.3 * t) * s
		-- leaves are biggest mid-crown, smaller and more upright at the top
		local size = (0.78 + 0.38 * math.sin(math.pi * (0.25 + 0.75 * t))) * s
		local pitch = r.range(18, 42) + 22 * t
		leaf(b, x, y, z, yaw, pitch, 0.05 * s, size * 0.8, size * 1.15, if i % 3 == 0 then LEAF_MID else LEAF_DEEP, r.range(-28, 28))
		yaw += 137.5
	end
end

FOLIAGE.Snake = function(b: B, x: number, y0: number, z: number, s: number, r: Rng)
	local yaw = r.range(0, 360)
	for i = 1, 8 do
		local h = r.range(1.7, 2.7) * s
		local lean = r.range(4, 14)
		local out = (0.12 + 0.05 * (i % 3)) * s
		-- tall thin wedge = pointed sword leaf (thin along local X)
		local lcf = L(x, y0, z, 0, yaw, 0) * CFrame.new(0, 0, -out) * CFrame.Angles(math.rad(-lean), math.rad(r.range(60, 120)), 0) * CFrame.new(0, h / 2, 0)
		b.wedge(lcf, Vector3.new(0.07 * s, h, 0.42 * s), if i % 2 == 0 then SNAKE_B else SNAKE_A, DETAIL)
		yaw += 137.5
	end
end

FOLIAGE.Olive = function(b: B, x: number, y0: number, z: number, s: number, r: Rng)
	local p0 = Vector3.new(x, y0 - 0.1, z)
	local p1 = Vector3.new(x + 0.18 * s, y0 + 1.7 * s, z - 0.1 * s)
	local p2 = Vector3.new(x - 0.08 * s, y0 + 3.3 * s, z + 0.12 * s)
	b.span(p0, p1, 0.24 * s, BARK_LIGHT, DETAIL)
	b.span(p1, p2, 0.18 * s, BARK_LIGHT, DETAIL)
	local cy = y0 + 3.9 * s
	b.ball(x, cy, z, 1.7 * s, OLIVE_A, DETAIL)
	local yaw = r.range(0, 360)
	for i = 1, 5 do
		local a = math.rad(yaw)
		local rr = 0.75 * s
		local dy = (if i % 2 == 0 then 0.35 else -0.2) * s
		b.ball(x + math.cos(a) * rr, cy + dy, z + math.sin(a) * rr, r.range(1.0, 1.35) * s, if i % 2 == 0 then OLIVE_B else OLIVE_A, DETAIL)
		yaw += 72
	end
end

FOLIAGE.Palm = function(b: B, x: number, y0: number, z: number, s: number, r: Rng)
	b.cylY(x, y0 + 0.35 * s, z, 0.7 * s, 0.34 * s, C.tint("Bark", C.rgb(110, 92, 64)), DETAIL)
	local yaw = r.range(0, 360)
	local n = 8
	for i = 1, n do
		-- two narrow plates per frond: a rising inner blade and a drooping tip that
		-- starts exactly where the first ends, so the frond reads as one arch
		local p1 = r.range(42, 62)
		local l1 = r.range(1.7, 2.1) * s
		local base = y0 + 0.5 * s
		local g1, g2 = if i % 2 == 0 then LEAF_MID else BUSH_A, if i % 2 == 0 then BUSH_A else LEAF_MID
		leaf(b, x, base, z, yaw, p1, 0, 0.42 * s, l1, g1, r.range(-12, 12))
		local a = math.rad(p1)
		local d = math.rad(yaw)
		-- leaf() yaw convention: direction (-sin yaw, cos yaw) in (x, z-forward)
		local ox, oz = -math.sin(d) * math.cos(a) * l1, math.cos(d) * math.cos(a) * l1
		leaf(b, x + ox, base + math.sin(a) * l1 - 0.02, z + oz, yaw, r.range(-38, -14), 0, 0.5 * s, r.range(1.6, 2.0) * s, g2, r.range(-12, 12))
		yaw += 360 / n + r.range(-12, 12)
	end
end

FOLIAGE.Bush = function(b: B, x: number, y0: number, z: number, s: number, r: Rng)
	b.ball(x, y0 + 0.55 * s, z, 1.5 * s, BUSH_A, DETAIL)
	local yaw = r.range(0, 360)
	for i = 1, 4 do
		local a = math.rad(yaw)
		local rr = 0.55 * s
		b.ball(x + math.cos(a) * rr, y0 + r.range(0.35, 0.6) * s, z + math.sin(a) * rr, r.range(0.95, 1.2) * s, if i % 2 == 0 then BUSH_B else BUSH_C, DETAIL)
		yaw += 90 + r.range(-15, 15)
	end
end

FOLIAGE.Fern = function(b: B, x: number, y0: number, z: number, s: number, r: Rng)
	-- lush low dome of foliage with a few fronds spilling over the rim
	b.ball(x, y0 + 0.3 * s, z, 1.1 * s, LEAF_FRESH, DETAIL)
	local yaw = r.range(0, 360)
	for i = 1, 4 do
		local a = math.rad(yaw)
		b.ball(x + math.cos(a) * 0.42 * s, y0 + r.range(0.15, 0.4) * s, z + math.sin(a) * 0.42 * s, r.range(0.7, 0.9) * s, if i % 2 == 0 then BUSH_B else LEAF_FRESH, DETAIL)
		leaf(b, x, y0 + 0.35 * s, z, yaw + 45, r.range(-48, -30), 0.45 * s, 0.38 * s, r.range(0.8, 1.0) * s, BUSH_B, r.range(-15, 15))
		yaw += 90 + r.range(-10, 10)
	end
end

FOLIAGE.Monstera = function(b: B, x: number, y0: number, z: number, s: number, r: Rng)
	local yaw = r.range(0, 360)
	for i = 1, 6 do
		local h = r.range(0.9, 2.5) * s
		local out = r.range(0.45, 0.95) * s
		local a = math.rad(yaw)
		local tip = Vector3.new(x + math.cos(a) * out, y0 + h, z + math.sin(a) * out)
		b.span(Vector3.new(x, y0, z), tip, 0.09 * s, LEAF_MID, FINE)
		-- big split leaf: two plates either side of the midrib, tilted outward
		local lcf = L(tip.X, tip.Y, tip.Z, 0, yaw - 90, 0) * CFrame.Angles(math.rad(r.range(-48, 12)), 0, 0) * CFrame.new(0, 0, -0.55 * s)
		b.part(lcf * CFrame.new(-0.3 * s, 0, 0) * CFrame.Angles(0, 0, math.rad(14)), Vector3.new(0.66 * s, 0.06, 1.3 * s), if i % 2 == 0 then LEAF_DEEP else LEAF_MID, DETAIL)
		b.part(lcf * CFrame.new(0.3 * s, 0, 0) * CFrame.Angles(0, 0, math.rad(-14)), Vector3.new(0.66 * s, 0.06, 1.3 * s), if i % 2 == 0 then LEAF_MID else LEAF_DEEP, DETAIL)
		yaw += 60 + r.range(-10, 10)
	end
end

-- Ornamental grass tuft (planters only): low mound + fanned blades
FOLIAGE.Grass = function(b: B, x: number, y0: number, z: number, s: number, r: Rng)
	b.ball(x, y0 + 0.1 * s, z, 0.8 * s, C.tint("Leaf", C.rgb(104, 128, 72)), DETAIL)
	local yaw = r.range(0, 360)
	for i = 1, 3 do
		local h = r.range(1.5, 2.1) * s
		local lcf = L(x, y0, z, 0, yaw, 0) * CFrame.Angles(math.rad(-r.range(10, 20)), 0, 0) * CFrame.new(0, h / 2, -0.12 * s)
		b.wedge(lcf, Vector3.new(0.08, h, 0.7 * s), if i % 2 == 0 then C.tint("Leaf", C.rgb(150, 156, 96)) else C.tint("Leaf", C.rgb(118, 136, 78)), DETAIL)
		yaw += 120
	end
end

local function kindOf(kind: any): string
	if type(kind) == "string" and FOLIAGE[kind] then
		return kind
	end
	return "Fiddle"
end

---------------------------------------------------------------------------
-- Trees
---------------------------------------------------------------------------
local OAK = { C.tint("Leaf", C.rgb(58, 100, 50)), C.tint("Leaf", C.rgb(72, 116, 56)), C.tint("Leaf", C.rgb(48, 86, 46)) }
local BIRCH = { C.tint("Leaf", C.rgb(108, 142, 70)), C.tint("Leaf", C.rgb(124, 150, 76)), C.tint("Leaf", C.rgb(92, 128, 64)) }
local PINE = { C.tint("LeafDark", C.rgb(36, 72, 50)), C.tint("LeafDark", C.rgb(44, 82, 54)) }

local function crown(b: B, r: Rng, cx: number, cy: number, cz: number, n: number, spread: number, rise: number, dMin: number, dMax: number, greens: { C.Fin })
	b.ball(cx, cy, cz, dMax * 1.05, greens[1], DETAIL)
	local yaw = r.range(0, 360)
	for i = 1, n do
		local a = math.rad(yaw)
		local rr = spread * r.range(0.75, 1.05)
		local dy = rise * (if i % 2 == 0 then r.range(0.2, 0.6) else r.range(-0.5, 0.1))
		b.ball(cx + math.cos(a) * rr, cy + dy, cz + math.sin(a) * rr, r.range(dMin, dMax), greens[1 + (i % #greens)], DETAIL)
		yaw += 360 / n + r.range(-14, 14)
	end
end

local function tree(parent: Instance, cf: CFrame, kind: string, scale: number): Model
	local s = C.num(scale, 1, 0.3, 4)
	local b = C.begin(parent, "Tree", cf)
	local r = C.rng(cf, 7)
	if kind == "Pine" then
		b.cylY(0, 2.6 * s - 0.3, 0, 5.2 * s + 0.6, 0.9 * s, BARK)
		-- each tier = two crossed "tents" (pairs of back-to-back wedges)
		local tiers = { { y = 2.4, R = 4.4, h = 5.0 }, { y = 5.6, R = 3.4, h = 4.6 }, { y = 8.8, R = 2.3, h = 4.4 } }
		for ti, t in tiers do
			for q = 0, 3 do
				local yaw = (q % 2) * 90 + (if q >= 2 then 180 else 0) + (ti % 2) * 45
				local R, h = t.R * s, t.h * s
				local lcf = L(0, t.y * s + h / 2, 0, 0, yaw, 0) * CFrame.new(0, 0, -R / 2)
				b.wedge(lcf, Vector3.new(R * 0.9, h, R), PINE[1 + (q + ti) % 2], { Collide = false, Shadow = true })
			end
		end
		b.ball(0, 13.1 * s, 0, 0.7 * s, PINE[1], DETAIL)
	elseif kind == "Birch" then
		local trunk = C.tint("Plaster", C.rgb(226, 222, 212))
		b.cylY(0, 4.5 * s - 0.3, 0, 9 * s + 0.6, 0.8 * s, trunk)
		b.span(Vector3.new(0, 8.6 * s, 0), Vector3.new(0.5 * s, 12.6 * s, 0.2 * s), 0.45 * s, trunk, DETAIL)
		for i, y in { 1.4, 3.1, 5.2, 7.4 } do
			b.cylY(0, y * s, 0, (0.12 + 0.04 * (i % 2)) * s, 0.74 * s, C.tint("Slate", C.rgb(46, 44, 42)), FINE)
		end
		-- tall, loose crown: two stacked clusters
		crown(b, r, 0.2 * s, 9.6 * s, 0, 4, 1.6 * s, 1.2 * s, 2.6 * s, 3.4 * s, BIRCH)
		crown(b, r, 0.3 * s, 12.8 * s, 0.1 * s, 3, 1.2 * s, 1.0 * s, 2.2 * s, 2.9 * s, BIRCH)
	elseif kind == "Street" then
		-- cast-iron tree grate flush with the pavement
		b.box(0, 0.04, 0, 3.6 * s, 0.08, 3.6 * s, C.F.CastIron, DETAIL)
		b.cylY(0, 3.6 * s - 0.3, 0, 7.2 * s + 0.6, 0.75 * s, BARK)
		b.span(Vector3.new(0, 5.8 * s, 0), Vector3.new(1.4 * s, 8.2 * s, 0.4 * s), 0.38 * s, BARK, DETAIL)
		b.span(Vector3.new(0, 6.2 * s, 0), Vector3.new(-1.1 * s, 8.4 * s, -0.6 * s), 0.34 * s, BARK, DETAIL)
		crown(b, r, 0, 9.6 * s, 0, 5, 1.9 * s, 1.8 * s, 3.4 * s, 4.4 * s, OAK)
	else -- Oak
		b.cylY(0, 0.25 * s, 0, 0.5 * s + 0.6, 1.9 * s, BARK) -- root flare
		b.cylY(0, 3.2 * s - 0.3, 0, 6.4 * s + 0.6, 1.3 * s, BARK)
		b.span(Vector3.new(0, 6.0 * s, 0), Vector3.new(0.3 * s, 9.6 * s, -0.2 * s), 1.0 * s, BARK, DETAIL)
		b.span(Vector3.new(0, 6.4 * s, 0), Vector3.new(2.6 * s, 9.4 * s, 0.6 * s), 0.6 * s, BARK, DETAIL)
		b.span(Vector3.new(0, 6.8 * s, 0), Vector3.new(-2.2 * s, 9.8 * s, -1.0 * s), 0.55 * s, BARK, DETAIL)
		crown(b, r, 0, 12.0 * s, 0, 8, 3.2 * s, 2.6 * s, 3.8 * s, 5.4 * s, OAK)
	end
	return b.model
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------
return function(Props: C.Registry)
	Props.register("plant", function(parent: Instance, cf: CFrame, kind: string, scale: number): Model
		local k = kindOf(kind)
		local s = C.num(scale, 1, 0.3, 4)
		local b = C.begin(parent, "Plant_" .. k, cf)
		local soil = POTS[k](b, 0, 0, s)
		FOLIAGE[k](b, 0, soil, 0, s, C.rng(cf))
		return b.model
	end)

	Props.register("planter", function(parent: Instance, cf: CFrame, size: Vector3, finish: C.Finish, plantKind: string): Model
		local b = C.begin(parent, "Planter", cf)
		local r = C.rng(cf, 3)
		local X, H, Z = math.max(size.X, 1.5), math.max(size.Y, 0.6), math.max(size.Z, 1.5)
		local t = math.clamp(math.min(X, Z) * 0.07, 0.3, 0.55)
		local gap = 0.15
		-- recessed plinth, four walls, soil fill
		b.box(0, gap / 2, 0, X - 0.24, gap, Z - 0.24, POT_FOOT, DETAIL)
		local wh = H - gap
		b.box(0, gap + wh / 2, Z / 2 - t / 2, X, wh, t, finish)
		b.box(0, gap + wh / 2, -Z / 2 + t / 2, X, wh, t, finish)
		b.box(X / 2 - t / 2, gap + wh / 2, 0, t, wh, Z - 2 * t, finish)
		b.box(-X / 2 + t / 2, gap + wh / 2, 0, t, wh, Z - 2 * t, finish)
		local soilTop = H - 0.22
		b.box(0, (gap + soilTop) / 2, 0, X - 2 * t, soilTop - gap, Z - 2 * t, SOIL, { Collide = true, Shadow = false })
		-- planting
		local k = if type(plantKind) == "string" then plantKind else "Bush"
		local ix, iz = X - 2 * t - 0.4, Z - 2 * t - 0.4
		if k == "Fiddle" or k == "Olive" or k == "Palm" or k == "Monstera" then
			-- feature plants along the long axis, low shrubs at the ends
			local long = math.max(ix, iz)
			local n = math.max(1, math.floor(long / 6))
			for i = 1, n do
				local u = (i - 0.5) / n - 0.5
				local px, pz = if ix >= iz then u * ix else 0, if ix >= iz then 0 else u * iz
				FOLIAGE[k](b, px, soilTop, pz, math.clamp(math.min(ix, iz) / 2.2, 0.6, 1.3), r)
			end
			if long > 4 then
				for _, e in { -0.42, 0.42 } do
					local px, pz = if ix >= iz then e * ix else 0, if ix >= iz then 0 else e * iz
					FOLIAGE.Bush(b, px, soilTop, pz, 0.7, r)
				end
			end
		else
			local fn = FOLIAGE[k] or FOLIAGE.Bush
			-- grid pitch grows with the planter so big beds stay within ~24 clumps
			local pitch = math.max(if k == "Bush" then 1.5 else 1.4, math.sqrt(ix * iz / 24))
			local nx = math.max(1, math.floor(ix / pitch + 0.5))
			local nz = math.max(1, math.floor(iz / pitch + 0.5))
			for gx = 1, nx do
				for gz = 1, nz do
					local px = ((gx - 0.5) / nx - 0.5) * ix + r.range(-0.25, 0.25)
					local pz = ((gz - 0.5) / nz - 0.5) * iz + r.range(-0.25, 0.25)
					if k == "Bush" then
						-- one generous shrub ball per cell keeps big planters inside budget
						local d = math.max(ix / nx, iz / nz) * r.range(1.15, 1.4)
						local greens: { C.Fin } = { BUSH_A, BUSH_B, BUSH_C }
						b.ball(px, soilTop + d * 0.3, pz, d, greens[1 + ((gx + gz) % 3)], DETAIL)
					else
						fn(b, px, soilTop, pz, 0.75, r)
					end
				end
			end
		end
		return b.model
	end)

	Props.register("tree", function(parent: Instance, cf: CFrame, kind: string, scale: number): Model
		return tree(parent, cf, if type(kind) == "string" then kind else "Oak", scale)
	end)

	Props.register("hangingPlant", function(parent: Instance, cf: CFrame): Model
		local b = C.begin(parent, "HangingPlant", cf)
		local r = C.rng(cf, 11)
		b.cylY(0, -0.05, 0, 0.1, 0.45, C.F.Brass, FINE) -- ceiling hook rose
		local potTop = -2.6
		for i = 0, 2 do
			local a = math.rad(i * 120 + 30)
			b.span(Vector3.new(0, -0.1, 0), Vector3.new(math.cos(a) * 0.52, potTop + 0.05, math.sin(a) * 0.52), 0.05, C.F.Rope, FINE)
		end
		b.cylY(0, potTop - 0.4, 0, 0.8, 1.2, POT_TERRACOTTA, DETAIL)
		b.cylY(0, potTop - 0.06, 0, 0.12, 1.26, C.tint("Concrete", C.rgb(156, 86, 58)), FINE)
		-- pothos mound + trailing vines (chains of shrinking leaf clusters)
		local yaw = r.range(0, 360)
		for i = 1, 3 do
			local a = math.rad(yaw)
			b.ball(math.cos(a) * 0.3, potTop + 0.15, math.sin(a) * 0.3, r.range(0.6, 0.8), if i % 2 == 0 then BUSH_B else LEAF_FRESH, DETAIL)
			yaw += 120
		end
		for i = 1, 4 do
			local a = math.rad(yaw + i * 90 + r.range(-20, 20))
			local len = r.range(0.9, 1.4)
			for k = 1, 3 do
				local t = k / 3
				local rr = 0.62 + 0.12 * t
				b.ball(math.cos(a) * rr, potTop - 0.25 - len * t, math.sin(a) * rr, 0.6 - 0.07 * k, if (i + k) % 2 == 0 then LEAF_FRESH else BUSH_A, FINE)
			end
		end
		return b.model
	end)
end
