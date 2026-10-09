--!strict
--[[
	Fixtures: counters, stocked shelving, locker banks, bleachers, trophy
	cases, vending machines, drinks fridges and the wall water fountain.

	Floor props are centred on cf (bottom centre) with their front facing
	cf.LookVector, so a prop of depth D against a wall goes at wall + D/2.
	The water fountain is wall mounted (cf = wall surface point at the
	unit's centre, LookVector out of the wall).

	Stock (supplement tubs, towels, merch, books ...) follows a simple
	planogram per shelf level with facings of identical products, which reads
	far more "retail" than random colours, and is varied by the position-
	seeded RNG. Locker numbers and vents are drawn in ONE SurfaceGui overlay
	per bank to keep part and SurfaceGui budgets low.
]]

local C = require("./Common")

type B = C.B
type Rng = C.Rng

local L = C.L
local DETAIL = C.DETAIL
local FINE = C.FINE
local SOLID = C.SOLID
local F = C.F

local INK = C.tint("PlasticBlack", C.rgb(24, 24, 26))
local SHADOW = C.tint("PlasticBlack", C.rgb(16, 16, 18))
local p = C.tint

-- product finishes
local PRODUCT: { C.Fin } = {
	p("Plastic", C.rgb(28, 28, 30)), -- black
	p("Plastic", C.rgb(238, 236, 230)), -- white
	p("Plastic", C.rgb(242, 169, 59)), -- amber (house brand)
	p("Plastic", C.rgb(52, 140, 132)), -- teal
	p("Plastic", C.rgb(214, 96, 70)), -- coral
	p("Plastic", C.rgb(40, 62, 104)), -- navy
	p("Plastic", C.rgb(120, 48, 64)), -- berry
	p("Plastic", C.rgb(112, 150, 72)), -- lime
}
local LIDS: { C.Fin } = { p("Plastic", C.rgb(30, 30, 32)), p("Plastic", C.rgb(240, 238, 232)), p("Plastic", C.rgb(242, 169, 59)) }
local TOWELS: { C.Fin } = {
	p("FabricWhite", C.rgb(242, 241, 236)),
	p("FabricWhite", C.rgb(200, 198, 192)),
	p("FabricWhite", C.rgb(150, 166, 146)),
	p("FabricWhite", C.rgb(64, 66, 70)),
}
local BOOKS: { C.Fin } = {
	p("Plastic", C.rgb(44, 58, 82)),
	p("Plastic", C.rgb(118, 40, 46)),
	p("Plastic", C.rgb(52, 82, 62)),
	p("Plastic", C.rgb(226, 216, 196)),
	p("Plastic", C.rgb(30, 30, 32)),
	p("Plastic", C.rgb(176, 120, 64)),
}
local GOLD = F.Gold
local SILVER = F.Chrome

---------------------------------------------------------------------------
-- Stock builders: one shelf level at board-top height y, usable width w
---------------------------------------------------------------------------
type StockFn = (b: B, level: number, y: number, w: number, maxH: number, r: Rng) -> ()

-- walks facings left to right: `place(x, item)` for `count` items of width `iw`
local function facings(w: number, iw: number, gap: number, groupOf: number, groupGap: number, place: (x: number, group: number) -> ())
	local x = -w / 2 + iw / 2
	local i = 0
	while x + iw / 2 <= w / 2 + 1e-3 do
		local g = i // groupOf
		place(x, g)
		i += 1
		x += iw + gap + (if i % groupOf == 0 then groupGap else 0)
	end
end

local STOCK: { [string]: StockFn } = {}

STOCK.Supplements = function(b: B, level: number, y: number, w: number, maxH: number, r: Rng)
	local kind = (level - 1) % 3
	local offset = r.int(0, #PRODUCT - 1)
	if kind == 0 then
		-- big protein tubs, facings of two
		local d, h = 0.82, math.min(1.05, maxH)
		facings(w, d, 0.08, 2, 0.3, function(x: number, g: number)
			local body = PRODUCT[1 + (g + offset) % #PRODUCT]
			b.cylY(x, y + (h - 0.14) / 2, 0.05, h - 0.14, d, body, FINE)
			b.cylY(x, y + h - 0.07, 0.05, 0.14, d + 0.04, LIDS[1 + g % #LIDS], FINE)
		end)
	elseif kind == 1 then
		-- pre-workout tubs, facings of three
		local d, h = 0.6, math.min(0.8, maxH)
		facings(w, d, 0.07, 3, 0.32, function(x: number, g: number)
			local body = PRODUCT[1 + (g * 3 + offset + 2) % #PRODUCT]
			b.cylY(x, y + (h - 0.12) / 2, 0.05, h - 0.12, d, body, FINE)
			b.cylY(x, y + h - 0.06, 0.05, 0.12, d + 0.03, LIDS[1 + (g + 1) % #LIDS], FINE)
		end)
	else
		-- boxed bars / sachets
		local bw, h = 0.95, math.min(0.75, maxH)
		facings(w, bw, 0.1, 1, 0, function(x: number, g: number)
			b.box(x, y + h / 2, 0.1, bw, h, 0.9, PRODUCT[1 + (g + offset + 4) % #PRODUCT], FINE)
		end)
	end
end

STOCK.Shakers = function(b: B, level: number, y: number, w: number, maxH: number, r: Rng)
	local offset = r.int(0, #PRODUCT - 1)
	if level % 2 == 0 then
		-- boxed shaker packs
		local h = math.min(0.9, maxH)
		facings(w, 0.8, 0.22, 1, 0, function(x: number, g: number)
			b.box(x, y + h / 2, 0.08, 0.8, h, 0.8, PRODUCT[1 + (g + offset) % #PRODUCT], FINE)
		end)
		return
	end
	local h = math.min(0.85, maxH)
	facings(w, 0.48, 0.14, 2, 0.34, function(x: number, g: number)
		b.cylY(x, y + (h - 0.2) / 2, 0.05, h - 0.2, 0.44, PRODUCT[1 + (g + offset + level) % #PRODUCT], FINE)
		b.cylY(x, y + h - 0.1, 0.05, 0.2, 0.46, LIDS[1], FINE)
	end)
end

STOCK.Towels = function(b: B, level: number, y: number, w: number, maxH: number, r: Rng)
	if level == 1 then
		-- rolled towels, one neat row
		facings(w, 0.5, 0.04, 99, 0, function(x: number, _g: number)
			b.cylZ(x, y + 0.25, 0.05, 1.2, 0.5, TOWELS[1], FINE)
		end)
	else
		local h = math.min(1.0, maxH)
		local offset = r.int(0, #TOWELS - 1)
		facings(w, 1.1, 0.22, 1, 0, function(x: number, g: number)
			-- two loosely aligned bundles read as a stack of folded towels
			local f = TOWELS[1 + (g + offset) % #TOWELS]
			b.box(x, y + h * 0.26, 0.05, 1.1, h * 0.52, 1.0, f, FINE)
			b.part(L(x + r.range(-0.05, 0.05), y + h * 0.76, 0.03, 0, r.range(-4, 4), 0), Vector3.new(1.06, h * 0.48, 0.96), f, FINE)
		end)
	end
end

STOCK.Merch = function(b: B, level: number, y: number, w: number, maxH: number, r: Rng)
	local tees: { C.Fin } = { PRODUCT[1], PRODUCT[2], PRODUCT[3], p("FabricGrey", C.rgb(120, 120, 122)), PRODUCT[6] }
	if level % 3 == 0 then
		-- caps: crown (ball) + brim
		facings(w, 0.9, 0.35, 1, 0, function(x: number, g: number)
			local c = tees[1 + g % #tees]
			b.ball(x, y + 0.12, 0, 0.62, c, FINE)
			b.box(x, y + 0.05, 0.42, 0.56, 0.04, 0.4, c, FINE)
		end)
	else
		-- folded tee stacks
		local h = math.min(0.55 + 0.15 * (level % 2), maxH)
		local offset = r.int(0, #tees - 1)
		facings(w, 1.0, 0.2, 1, 0, function(x: number, g: number)
			b.box(x, y + h / 2, 0.05, 1.0, h, 0.95, tees[1 + (g + offset + level) % #tees], FINE)
		end)
	end
end

STOCK.Trophies = function(b: B, level: number, y: number, w: number, maxH: number, r: Rng)
	local n = math.max(2, math.floor(w / 1.6))
	for i = 1, n do
		local x = -w / 2 + w * (i - 0.5) / n
		local design = (i + level + r.int(0, 2)) % 3
		local metal = if (i + level) % 4 == 0 then SILVER else GOLD
		if design == 0 then
			-- cup on a stepped base
			local h = math.min(1.2, maxH)
			b.box(x, y + 0.14, 0, 0.5, 0.28, 0.5, F.MarbleDark, FINE)
			b.cylY(x, y + 0.28 + (h - 0.28) * 0.25, 0, (h - 0.28) * 0.5, 0.12, metal, FINE)
			b.cylY(x, y + h - (h - 0.28) * 0.25, 0, (h - 0.28) * 0.5, 0.48, metal, FINE)
		elseif design == 1 then
			-- standing plaque
			b.part(L(x, y + 0.5, -0.1, -8, 0, 0), Vector3.new(0.8, 1.0, 0.1), F.Walnut, FINE)
			b.part(L(x, y + 0.55, -0.04, -8, 0, 0), Vector3.new(0.5, 0.3, 0.02), metal, FINE)
		else
			-- figure / column trophy
			local h = math.min(1.1, maxH)
			b.box(x, y + 0.1, 0, 0.44, 0.2, 0.44, F.MarbleDark, FINE)
			b.box(x, y + 0.2 + (h - 0.2) / 2, 0, 0.18, h - 0.2, 0.18, metal, FINE)
		end
	end
end

STOCK.Books = function(b: B, level: number, y: number, w: number, maxH: number, r: Rng)
	local x = -w / 2 + 0.1 + r.range(0, 0.6)
	local n = r.int(4, 6)
	for _ = 1, n do
		local t = r.range(0.14, 0.24)
		local h = math.min(r.range(0.75, 1.05), maxH)
		b.box(x + t / 2, y + h / 2, 0, t, h, r.range(0.8, 1.0), BOOKS[r.int(1, #BOOKS)], FINE)
		x += t + 0.015
	end
	-- one leaning book, then a small object
	local lh = math.min(0.9, maxH)
	b.part(L(x + 0.35, y + lh / 2 - 0.05, 0, 0, 0, -22), Vector3.new(0.18, lh, 0.85), BOOKS[r.int(1, #BOOKS)], FINE)
	local ox = math.min(w / 2 - 0.5, x + 1.6)
	if level % 2 == 0 then
		b.cylY(ox, y + 0.3, 0, 0.6, 0.45, p("Plastic", C.rgb(226, 220, 208)), FINE)
	else
		b.ball(ox, y + 0.28, 0, 0.56, p("Leaf", C.rgb(70, 112, 60)), FINE)
		b.cylY(ox, y + 0.12, 0, 0.24, 0.42, p("Concrete", C.rgb(176, 100, 68)), FINE)
	end
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------
return function(Props: C.Registry)
	Props.register("counter", function(parent: Instance, cf: CFrame, length: number, depth: number, top: C.Finish, body: C.Finish): Model
		local Lx = C.num(length, 10, 2, 60)
		local D = C.num(depth, 3, 1.4, 8)
		local H = 3.6
		local b = C.begin(parent, "Counter", cf)
		local front = D / 2 - 0.25 -- body front face (top overhangs it)
		local carcD = math.min(1.3, D * 0.5)
		-- customer-side carcass on a recessed kick plate
		b.box(0, 0.2, front - carcD / 2 - 0.15, Lx - 0.3, 0.4, carcD - 0.3, INK, DETAIL)
		b.box(0, 0.4 + (H - 0.6) / 2, front - carcD / 2, Lx, H - 0.6, carcD, body, SOLID)
		-- staff side: end panels, open shelf, back kick
		for _, sx in { -1, 1 } do
			b.box(sx * (Lx / 2 - 0.15), (H - 0.2) / 2, front - D / 2 + 0.12, 0.3, H - 0.2, D - 0.24, body, SOLID)
		end
		local shelfD = D - carcD - 0.5
		if shelfD > 0.4 then
			b.box(0, 1.5, front - carcD - shelfD / 2, Lx - 0.6, 0.1, shelfD, body, DETAIL)
			b.box(0, 0.2, front - carcD - shelfD / 2, Lx - 0.6, 0.4, shelfD, INK, DETAIL)
		end
		-- panel reveals and a brass inlay line on the front
		local panels = math.max(1, math.floor(Lx / 3 + 0.5))
		for i = 1, panels - 1 do
			b.box(-Lx / 2 + Lx * i / panels, 0.4 + (H - 0.6) / 2, front + 0.01, 0.06, H - 0.6, 0.04, SHADOW, FINE)
		end
		b.box(0, H - 0.5, front + 0.012, Lx - 0.02, 0.07, 0.04, F.Brass, FINE)
		-- countertop: 0.4 front overhang, 0.15 at the ends
		b.box(0, H - 0.1, 0.075, Lx + 0.3, 0.2, D + 0.15, top, SOLID)
		-- bar foot rail on long counters
		if Lx >= 6 then
			local rz = front + 0.55
			b.cylX(0, 0.7, rz, Lx - 1.2, 0.18, F.Brass, DETAIL)
			local brackets = math.max(2, math.floor(Lx / 4) + 1)
			for i = 0, brackets - 1 do
				local x = -(Lx - 1.6) / 2 + (Lx - 1.6) * i / (brackets - 1)
				b.span(Vector3.new(x, 0.7, rz), Vector3.new(x, 0.95, front), 0.1, F.Brass, FINE)
			end
		end
		-- point-of-sale screen near one end on the staff side
		local px = Lx / 2 - 1.4
		b.box(px, H + 0.05, front - carcD + 0.4, 0.5, 0.1, 0.4, INK, FINE)
		b.box(px, H + 0.4, front - carcD + 0.42, 0.1, 0.6, 0.1, INK, FINE)
		b.part(L(px, H + 0.85, front - carcD + 0.36, -12, 180, 0), Vector3.new(1.3, 0.85, 0.08), C.F.Screen, FINE)
		return b.model
	end)

	Props.register("shelf", function(parent: Instance, cf: CFrame, width: number, height: number, items: string): Model
		local W = C.num(width, 6, 1.5, 30)
		local H = C.num(height, 6, 1.5, 14)
		local kind = if type(items) == "string" and STOCK[items] then items else "Supplements"
		local b = C.begin(parent, "Shelf_" .. kind, cf)
		local r = C.rng(cf, 13)
		local D = 1.6
		local upright: C.Fin = F.PowderBlack
		local board: C.Fin = F.Oak
		local back: C.Fin = F.PowderGraphite
		if kind == "Trophies" or kind == "Books" then
			upright = F.Walnut
			board = F.Walnut
			back = C.tint("PlasterCharcoal", C.rgb(46, 44, 44))
		elseif kind == "Towels" then
			upright = F.PowderWhite
			board = F.Birch
			back = C.tint("Plaster", C.rgb(226, 222, 214))
		end
		local t = 0.14
		for _, sx in { -1, 1 } do
			b.box(sx * (W / 2 - t / 2), H / 2, 0, t, H, D, upright, SOLID)
		end
		b.box(0, H / 2, -D / 2 + 0.05, W - 2 * t, H, 0.1, back, DETAIL)
		local n = math.max(1, math.floor((H - 0.5) / 1.5 + 0.5))
		local y0, y1 = 0.42, H - 0.06
		local pitch = (y1 - y0) / n
		b.box(0, 0.21, 0.05, W - 2 * t, 0.42, D - 0.1, upright, DETAIL) -- plinth
		for k = 0, n do
			local y = y0 + pitch * k
			b.box(0, y, 0.05, W - 2 * t, if k == n then 0.12 else 0.1, D - 0.1, board, DETAIL)
			if k < n then
				STOCK[kind](b, n - k, y + 0.05, W - 2 * t - 0.3, pitch - 0.2, r)
			end
		end
		return b.model
	end)

	Props.register("lockers", function(parent: Instance, cf: CFrame, columns: number, rows: number, finish: C.Finish): Model
		local nc = math.floor(C.num(columns, 4, 1, 16))
		local nr = math.floor(C.num(rows, 2, 1, 4))
		local b = C.begin(parent, "Lockers", cf)
		local W, H, D = nc * 2, nr * 3.2, 2
		local plinth, cap = 0.4, 0.12
		local carcass = C.tint("PowderGraphite", C.rgb(52, 54, 58))
		b.box(0, plinth / 2, -0.15, W - 0.2, plinth, D - 0.4, INK, DETAIL)
		b.box(0, plinth + (H - plinth - cap) / 2, -0.05, W, H - plinth - cap, D - 0.1, carcass, SOLID)
		b.box(0, H - cap / 2, 0, W + 0.1, cap, D + 0.04, carcass, DETAIL)
		local doorTop = H - cap - 0.04
		local dh = (doorTop - plinth - 0.04) / nr
		local frontZ = D / 2 - 0.1
		for c = 1, nc do
			for rr = 1, nr do
				local x = -W / 2 + 2 * (c - 0.5)
				local y = doorTop - dh * (rr - 0.5)
				b.box(x, y, frontZ + 0.04, 1.92, dh - 0.08, 0.08, finish, DETAIL)
				b.box(x + 0.66, y - dh * 0.12, frontZ + 0.12, 0.08, math.min(0.7, dh * 0.3), 0.08, F.Brass, FINE)
			end
		end
		-- one overlay SurfaceGui: vent slots + brass number plates for every door
		local overlayH = doorTop - plinth
		local ov = b.box(0, plinth + overlayH / 2, frontZ + 0.09, W, overlayH, 0.02, F.Plastic, { Collide = false, Transparency = 1, Shadow = false })
		ov.Name = "LockerFaces"
		local sg, label = C.gui(ov, "", C.Font.Bold, C.Brand.Ink, { PixelsPerStud = math.clamp(900 / math.max(W, overlayH), 16, 48), MaxDistance = 90 })
		label.Visible = false
		local start = 100 * (1 + C.rng(cf, 17).int(0, 3))
		local num = 0
		for c = 1, nc do
			for rr = 1, nr do
				num += 1
				local u0 = (c - 1) / nc
				local du = 1 / nc
				local v0 = (rr - 1) / nr
				local dv = 1 / nr
				-- three louvre slots near the top of the door
				for s = 0, 2 do
					local slot = C.frame(sg, u0 + du * 0.24, v0 + dv * (0.08 + s * 0.045), du * 0.52, dv * 0.022, Color3.fromRGB(14, 14, 16), 2, 0.15)
					C.corner(slot, 0.5)
				end
				local plate = C.frame(sg, u0 + du * 0.36, v0 + dv * 0.26, du * 0.28, dv * 0.085, Color3.fromRGB(196, 160, 90), 2)
				C.corner(plate, 0.2)
				C.text(plate, string.format("%03d", start + num), 0.08, 0.1, 0.84, 0.8, C.Font.Bold, Color3.fromRGB(30, 26, 20), 3)
			end
		end
		return b.model
	end)

	Props.register("bleachers", function(parent: Instance, cf: CFrame, width: number, rows: number, finish: C.Finish): Model
		local W = C.num(width, 20, 4, 80)
		local n = math.floor(C.num(rows, 5, 1, 12))
		local b = C.begin(parent, "Bleachers", cf)
		local rise, run = 1.6, 2.6
		local D = n * run
		local seat = C.tint("VinylRed", C.rgb(124, 32, 44))
		local nosing = C.tint("PowderYellow", C.rgb(214, 160, 52))
		local structure = 2 * n + 1 + 6 + math.floor(W / 6) + 2
		local perRow = math.max(1, math.floor((120 - structure) / (n * 2)))
		local sections = math.clamp(perRow, 1, math.max(1, math.floor(W / 2)))
		local secW = (W - 0.8) / sections
		for i = 1, n do
			local yTop = (i - 1) * rise + 0.6
			local zFront = D / 2 - (i - 1) * run
			-- solid stepped tier + safety nosing
			b.box(0, yTop / 2, zFront - run / 2, W, yTop, run, finish, SOLID)
			b.box(0, yTop + 0.02, zFront - 0.15, W, 0.04, 0.3, nosing, FINE)
			-- seat sections cantilevered off the riser behind (back wall on the top row)
			local zBack = zFront - run
			for s = 1, sections do
				local x = -W / 2 + 0.4 + secW * (s - 0.5)
				b.box(x, yTop + 1.3, zBack + 0.75, secW - 0.25, 0.16, 1.0, seat, DETAIL)
				b.part(L(x, yTop + 1.95, zBack + 0.22, 8, 0, 0), Vector3.new(secW - 0.25, 1.0, 0.14), seat, DETAIL)
			end
		end
		-- back wall behind the top row + guard rail
		local topY = (n - 1) * rise + 0.6
		local zEnd = D / 2 - n * run
		b.box(0, (topY + 1.6) / 2, zEnd - 0.15, W, topY + 1.6, 0.3, finish, SOLID)
		local posts = math.max(1, math.floor(W / 6))
		for i = 0, posts do
			local x = -W / 2 + 0.2 + (W - 0.4) * i / posts
			b.box(x, topY + 1.6 + 1.0, zEnd - 0.15, 0.14, 2.0, 0.14, F.SteelBrushed, FINE)
		end
		b.cylX(0, topY + 3.6, zEnd - 0.15, W, 0.16, F.SteelBrushed, FINE)
		-- raking handrails at both ends
		for _, sx in { -1, 1 } do
			local x = sx * (W / 2 - 0.25)
			local a = Vector3.new(x, 0.6 + 3.0, D / 2 - 0.4)
			local c = Vector3.new(x, topY + 3.0, zEnd + run - 0.6)
			b.span(a, c, 0.14, F.SteelBrushed, FINE)
			b.box(x, 0.6 + 1.5, D / 2 - 0.4, 0.14, 3.0, 0.14, F.SteelBrushed, FINE)
			b.box(x, topY + 1.5, zEnd + run - 0.6, 0.14, 3.0, 0.14, F.SteelBrushed, FINE)
		end
		return b.model
	end)

	Props.register("trophyCase", function(parent: Instance, cf: CFrame, width: number): Model
		local W = C.num(width, 6, 2, 24)
		local b = C.begin(parent, "TrophyCase", cf)
		local r = C.rng(cf, 19)
		local D, baseH, topY = 2, 2.6, 6.6
		-- walnut base cabinet with doors and brass pulls
		b.box(0, baseH / 2, 0, W, baseH, D, F.Walnut, SOLID)
		local doors = if W >= 4 then 2 else 1
		for i = 1, doors do
			local dw = (W - 0.3) / doors
			local x = -W / 2 + 0.15 + dw * (i - 0.5)
			b.box(x, baseH / 2 + 0.1, D / 2 + 0.03, dw - 0.08, baseH - 0.6, 0.06, F.WalnutPlanks, FINE)
			b.cylZ(x + (if i == 1 and doors == 2 then dw / 2 - 0.3 else -dw / 2 + 0.3), baseH / 2 + 0.3, D / 2 + 0.1, 0.1, 0.14, F.Brass, FINE)
		end
		-- display: charcoal back, walnut uprights, glass front + shelves, cornice
		b.box(0, (baseH + topY) / 2, -D / 2 + 0.05, W - 0.2, topY - baseH, 0.1, C.tint("Velvet", C.rgb(34, 34, 36)), DETAIL)
		for _, sx in { -1, 1 } do
			b.box(sx * (W / 2 - 0.1), (baseH + topY) / 2, 0, 0.2, topY - baseH, D, F.Walnut, SOLID)
		end
		b.box(0, (baseH + topY) / 2, D / 2 - 0.08, W - 0.4, topY - baseH, 0.06, F.Glass, { Collide = true, Shadow = false })
		local shelves = { baseH, baseH + 1.35, baseH + 2.7 }
		for k = 2, 3 do
			b.box(0, shelves[k], -0.05, W - 0.4, 0.06, D - 0.3, F.GlassFrosted, { Collide = false, Shadow = false })
		end
		b.box(0, topY + 0.2, 0, W + 0.1, 0.4, D + 0.1, F.Walnut, SOLID)
		local strip = b.box(0, topY - 0.03, 0.2, W - 0.6, 0.04, 0.2, F.LightWarm, FINE)
		C.light(strip, "Surface", nil, { Color = C.WARM, Brightness = 1.2, Range = 7, Angle = 120, Face = Enum.NormalId.Bottom })
		for k = 1, 3 do
			STOCK.Trophies(b, k, shelves[k] + 0.03, W - 0.7, 1.2, r)
		end
		return b.model
	end)

	Props.register("vending", function(parent: Instance, cf: CFrame, kind: string): Model
		local snacks = kind == "Snacks"
		local b = C.begin(parent, "Vending_" .. (if snacks then "Snacks" else "Drinks"), cf)
		local r = C.rng(cf, 23)
		local W, H, D = 3.4, 7, 3
		local bodyF = if snacks then C.tint("PowderGraphite", C.rgb(58, 60, 64)) else F.PowderBlack
		local accent = if snacks then C.tint("PlasticTeal", C.rgb(52, 140, 132)) else F.Amber
		b.box(0, 0.1, -0.1, W - 0.2, 0.2, D - 0.4, INK, DETAIL)
		local fz = D / 2 - 0.1
		local wx, ww, wy0, wy1 = -0.42, 2.2, 2.0, 6.2
		-- cabinet built around an open display cavity (1.0 deep)
		local cav = 1.0
		local rearD = D - 0.1 - cav
		b.box(0, 0.2 + (H - 0.2) / 2, fz - cav - rearD / 2, W, H - 0.2, rearD, bodyF, SOLID)
		local left, right = wx - ww / 2, wx + ww / 2
		b.box((-W / 2 + left) / 2, 0.2 + (H - 0.2) / 2, fz - cav / 2, left + W / 2, H - 0.2, cav, bodyF, DETAIL)
		b.box((right + W / 2) / 2, 0.2 + (H - 0.2) / 2, fz - cav / 2, W / 2 - right, H - 0.2, cav, bodyF, SOLID)
		b.box(wx, (wy1 + H) / 2, fz - cav / 2, ww, H - wy1, cav, bodyF, DETAIL)
		b.box(wx, (0.2 + wy0) / 2, fz - cav / 2, ww, wy0 - 0.2, cav, bodyF, SOLID)
		-- lit display: back light, product rows, glass
		local back = b.box(wx, (wy0 + wy1) / 2, fz - cav + 0.03, ww, wy1 - wy0, 0.05, C.tint("LightPanel", C.rgb(255, 244, 228)), FINE)
		C.light(back, "Surface", nil, { Color = C.NEUTRAL, Brightness = 0.6, Range = 8, Angle = 120, Face = Enum.NormalId.Front })
		local rowsN = 4
		local rowH = (wy1 - wy0) / rowsN
		local offset = r.int(0, #PRODUCT - 1)
		for row = 1, rowsN do
			local y = wy0 + rowH * (row - 1)
			b.box(wx, y + 0.04, fz - 0.5, ww, 0.06, 0.8, F.SteelDark, FINE)
			for i = 1, 4 do
				local x = wx - ww / 2 + ww * (i - 0.5) / 4
				local f = PRODUCT[1 + (row * 2 + i + offset) % #PRODUCT]
				if snacks then
					b.box(x, y + 0.42, fz - 0.45, 0.42, 0.68, 0.12, f, FINE)
				else
					b.cylY(x, y + 0.42, fz - 0.45, 0.72, 0.3, f, FINE)
				end
			end
		end
		b.box(wx, (wy0 + wy1) / 2, fz + 0.02, ww + 0.1, wy1 - wy0 + 0.1, 0.06, F.Glass, { Collide = false, Shadow = false })
		-- header band, keypad column, delivery bin
		b.box(0, H - 0.4, fz + 0.03, W - 0.2, 0.5, 0.06, accent, FINE)
		b.box(1.15, 4.6, fz + 0.03, 0.7, 2.0, 0.06, INK, FINE)
		b.box(1.15, 5.25, fz + 0.07, 0.48, 0.32, 0.02, C.F.ScreenLit, FINE)
		b.box(1.15, 4.5, fz + 0.08, 0.44, 0.7, 0.04, F.SteelBrushed, FINE)
		b.box(wx, 1.15, fz + 0.03, ww, 0.6, 0.06, SHADOW, FINE)
		return b.model
	end)

	Props.register("fridge", function(parent: Instance, cf: CFrame): Model
		local b = C.begin(parent, "Fridge", cf)
		local r = C.rng(cf, 29)
		local W, H, D = 3, 7, 2.4
		local fz = D / 2 - 0.1
		local y0, y1 = 0.7, 6.1
		-- insulated shell around an open, lit interior
		b.box(0, H / 2, -D / 2 + 0.15, W, H, 0.3, F.PowderBlack, SOLID)
		for _, sx in { -1, 1 } do
			b.box(sx * (W / 2 - 0.1), H / 2, 0.1, 0.2, H, D - 0.5, F.PowderBlack, SOLID)
		end
		b.box(0, (y1 + H) / 2, 0.1, W - 0.4, H - y1, D - 0.5, F.PowderBlack, DETAIL)
		b.box(0, y0 / 2, 0.1, W - 0.4, y0, D - 0.5, F.PowderBlack, SOLID)
		b.box(0, 0.3, fz + 0.02, W - 0.3, 0.4, 0.04, C.tint("SteelDark", C.rgb(40, 42, 46)), FINE) -- base grille
		-- cool backlight + wire shelves of bottles
		local back = b.box(0, (y0 + y1) / 2, -D / 2 + 0.33, W - 0.5, y1 - y0, 0.05, C.tint("LightCool", C.rgb(232, 242, 255)), FINE)
		C.light(back, "Surface", nil, { Color = C.COOL, Brightness = 0.5, Range = 7, Angle = 120, Face = Enum.NormalId.Front })
		local drinks: { C.Fin } = {
			C.tint("Glass", C.rgb(170, 210, 230)),
			p("Plastic", C.rgb(120, 170, 70)),
			p("Plastic", C.rgb(240, 150, 50)),
			p("Plastic", C.rgb(200, 60, 70)),
		}
		for k = 0, 3 do
			local y = y0 + (y1 - y0) * k / 4
			b.box(0, y, 0, W - 0.5, 0.05, D - 0.6, F.SteelDark, FINE)
			local f = drinks[1 + (k + r.int(0, 3)) % #drinks]
			for i = 1, 4 do
				b.cylY(-0.9 + 0.6 * (i - 1), y + 0.5, 0.3, 0.9, 0.34, f, FINE)
			end
		end
		-- door: frame strips, glass, handle, lit header
		b.box(0, (y0 + y1) / 2, fz + 0.06, W - 0.4, y1 - y0 + 0.2, 0.04, F.Glass, { Collide = false, Shadow = false })
		for _, sx in { -1, 1 } do
			b.box(sx * (W / 2 - 0.13), (y0 + y1) / 2, fz + 0.06, 0.18, y1 - y0 + 0.4, 0.1, F.SteelDark, FINE)
		end
		b.box(0, y1 + 0.17, fz + 0.06, W - 0.1, 0.14, 0.1, F.SteelDark, FINE)
		b.box(0, y0 - 0.17, fz + 0.06, W - 0.1, 0.14, 0.1, F.SteelDark, FINE)
		b.box(W / 2 - 0.42, (y0 + y1) / 2, fz + 0.18, 0.1, 2.4, 0.1, F.Chrome, FINE)
		b.box(0, H - 0.42, fz + 0.03, W - 0.3, 0.5, 0.04, F.Amber, FINE)
		return b.model
	end)

	Props.register("waterFountain", function(parent: Instance, cf: CFrame): Model
		local b = C.begin(parent, "WaterFountain", cf)
		local steel = F.SteelBrushed
		-- backplate, bottle-filler niche (upper), bubbler basin (lower)
		b.box(0, 0, 0.05, 1.9, 3.5, 0.1, steel, DETAIL)
		b.box(0, 0.95, 0.27, 1.4, 1.5, 0.34, steel, DETAIL)
		b.box(0, 0.92, 0.45, 1.1, 1.18, 0.02, C.tint("SteelBrushed", C.rgb(132, 136, 142)), FINE)
		b.cylY(0, 1.42, 0.38, 0.14, 0.12, F.Chrome, FINE)
		b.box(0.4, 1.42, 0.46, 0.08, 0.08, 0.02, C.tint("LightCyan", C.rgb(120, 220, 160)), FINE)
		b.box(0, 0.38, 0.4, 0.9, 0.06, 0.26, F.SteelDark, FINE)
		b.box(0, -0.62, 0.68, 1.8, 0.5, 1.26, steel, SOLID)
		b.box(0, -0.36, 0.72, 1.4, 0.02, 0.86, C.tint("SteelDark", C.rgb(70, 72, 76)), FINE)
		b.span(Vector3.new(0, -0.36, 0.5), Vector3.new(0.08, -0.12, 0.62), 0.09, F.Chrome, FINE)
		b.box(0, -0.62, 1.32, 1.2, 0.24, 0.04, C.tint("PlasticBlack", C.rgb(36, 36, 40)), FINE)
		b.wedge(L(0, -1.3, 0.38, 0, 0, 180), Vector3.new(1.2, 0.86, 0.6), steel, DETAIL) -- tapered shroud
		return b.model
	end)
end
