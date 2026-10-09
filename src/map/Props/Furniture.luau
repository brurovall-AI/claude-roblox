--!strict
--[[
	Furniture: benches, sofas, armchairs, stools, tables, patio umbrella
	sets, rugs and the recovery massage table.

	All props are floor-level (cf = bottom centre), front = cf.LookVector
	(the direction a seated person faces). Seats, tops and bodies collide;
	legs, piping, cushions-on-cushions and decor are Kit.DETAIL.
]]

local C = require("./Common")

type B = C.B

local L = C.L
local DETAIL = C.DETAIL
local FINE = C.FINE
local F = C.F

local function shade(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

---------------------------------------------------------------------------
-- Upholstery kinds
---------------------------------------------------------------------------
type Uph = { body: C.Fin, cushion: C.Fin, leg: C.Fin, pillow: C.Fin, roll: boolean }
local UPHOLSTERY: { [string]: Uph } = {
	Velvet = {
		body = C.tint("Velvet", C.rgb(56, 86, 67)),
		cushion = C.tint("Velvet", C.rgb(64, 96, 75)),
		leg = F.Brass,
		pillow = C.tint("Velvet", C.rgb(196, 146, 82)),
		roll = true,
	},
	Leather = {
		body = C.tint("LeatherCognac", C.rgb(128, 72, 40)),
		cushion = C.tint("LeatherCognac", C.rgb(142, 82, 46)),
		leg = F.PowderBlack,
		pillow = C.tint("FabricCream", C.rgb(214, 200, 176)),
		roll = false,
	},
	Fabric = {
		body = C.tint("FabricCream", C.rgb(206, 196, 178)),
		cushion = C.tint("FabricCream", C.rgb(218, 209, 192)),
		leg = F.OakSolid,
		pillow = C.tint("FabricRed", C.rgb(188, 98, 62)),
		roll = false,
	},
}

local function uph(kind: any): Uph
	return UPHOLSTERY[if type(kind) == "string" then kind else "Velvet"] or UPHOLSTERY.Velvet
end

-- Shared sofa/armchair body. W = overall width, n = seat count, D = depth.
local function seating(b: B, W: number, n: number, D: number, u: Uph, armW: number)
	local legH = 0.45
	local baseTop = 1.05
	-- legs (slightly inset from the corners), extra pair under long sofas
	local lx = W / 2 - 0.35
	local lz = D / 2 - 0.35
	local legXs = { -lx, lx }
	if n >= 3 then
		table.insert(legXs, 0)
	end
	for _, x in legXs do
		for _, z in { -lz, lz } do
			b.cylY(x, legH / 2, z, legH, 0.2, u.leg, DETAIL)
		end
	end
	-- frame / base rail and back
	b.box(0, legH + (baseTop - legH) / 2, 0, W, baseTop - legH, D, u.body)
	local backT = 0.55
	b.box(0, baseTop + 0.95, -D / 2 + backT / 2, W, 1.9, backT, u.body)
	-- arms (rolled top on velvet)
	local armTop = if u.roll then 2.15 else 2.3
	for _, sx in { -1, 1 } do
		local ax = sx * (W / 2 - armW / 2)
		b.box(ax, baseTop + (armTop - baseTop) / 2, 0.02, armW, armTop - baseTop, D - 0.04, u.body)
		if u.roll then
			b.cylZ(ax, armTop, 0.02, D - 0.04, armW, u.body, DETAIL)
		end
	end
	-- seat and back cushions
	local inner = W - 2 * armW
	local cw = inner / n
	local cushD = D - backT - 0.1
	for i = 1, n do
		local x = -inner / 2 + cw * (i - 0.5)
		b.box(x, baseTop + 0.24, D / 2 - cushD / 2 - 0.02, cw - 0.06, 0.48, cushD, u.cushion)
		b.part(L(x, baseTop + 0.48 + 0.66, -D / 2 + backT + 0.28, 9, 0, 0), Vector3.new(cw - 0.06, 1.32, 0.5), u.cushion, DETAIL)
	end
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------
return function(Props: C.Registry)
	Props.register("bench", function(parent: Instance, cf: CFrame, length: number, finish: C.Finish): Model
		local len = C.num(length, 6, 2, 40)
		local b = C.begin(parent, "Bench", cf)
		local topY = 1.6
		-- two boards with a shadow gap
		for _, z in { -0.38, 0.38 } do
			b.box(0, topY - 0.15, z, len, 0.3, 0.72, finish)
		end
		-- powder-coated sled legs
		local legs = { -(len / 2 - 0.8), len / 2 - 0.8 }
		if len > 9 then
			table.insert(legs, 0)
		end
		for _, x in legs do
			b.box(x, topY - 0.36, 0, 0.2, 0.12, 1.36, F.PowderBlack, DETAIL)
			b.box(x, 0.06, 0, 0.2, 0.12, 1.44, F.PowderBlack, DETAIL)
			for _, z in { -0.62, 0.62 } do
				b.box(x, (topY - 0.3) / 2, z, 0.2, topY - 0.3, 0.2, F.PowderBlack, DETAIL)
			end
		end
		return b.model
	end)

	Props.register("sofa", function(parent: Instance, cf: CFrame, seats: number, kind: string): Model
		local n = math.floor(C.num(seats, 3, 1, 4))
		local u = uph(kind)
		local b = C.begin(parent, "Sofa", cf)
		local W = n * 3
		local D = 3.2
		seating(b, W, n, D, u, if n == 1 then 0.7 else 0.6)
		-- throw pillows leaning into the corners
		if n >= 2 then
			for _, sx in { -1, 1 } do
				local x = sx * (W / 2 - 0.6 - 0.75)
				b.part(L(x, 2.05, -D / 2 + 1.02, 14, sx * 6, sx * 4), Vector3.new(1.15, 1.1, 0.44), u.pillow, DETAIL)
			end
		end
		return b.model
	end)

	Props.register("armchair", function(parent: Instance, cf: CFrame, kind: string): Model
		local u = uph(kind)
		local b = C.begin(parent, "Armchair", cf)
		seating(b, 3.2, 1, 3.1, u, 0.62)
		b.part(L(0, 2.1, -0.55, 12, 0, 4), Vector3.new(1.0, 1.0, 0.34), u.pillow, DETAIL)
		return b.model
	end)

	Props.register("stool", function(parent: Instance, cf: CFrame, finish: C.Finish): Model
		local b = C.begin(parent, "Stool", cf)
		local seatY = 2.75
		local top, bot = 0.4, 0.62
		local legs = { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1) }
		local ringY = 0.95
		local t = ringY / (seatY - 0.1)
		local ringR = bot + (top - bot) * t
		for i, d in legs do
			b.span(Vector3.new(d.X * bot, 0, d.Z * bot), Vector3.new(d.X * top, seatY - 0.1, d.Z * top), 0.13, F.PowderBlack, DETAIL)
			-- footrest ring segment to the next leg
			local e = legs[i % 4 + 1]
			b.span(Vector3.new(d.X * ringR, ringY, d.Z * ringR), Vector3.new(e.X * ringR, ringY, e.Z * ringR), 0.1, F.Brass, FINE)
		end
		b.cylY(0, seatY - 0.05, 0, 0.12, 1.1, F.PowderBlack)
		b.cylY(0, seatY + 0.13, 0, 0.26, 1.3, finish, DETAIL)
		return b.model
	end)

	Props.register("coffeeTable", function(parent: Instance, cf: CFrame, size: Vector3, finish: C.Finish): Model
		local X, H, Z = C.num(size.X, 4, 1, 20), C.num(size.Y, 1.4, 0.6, 4), C.num(size.Z, 2.4, 1, 20)
		local b = C.begin(parent, "CoffeeTable", cf)
		local r = C.rng(cf, 5)
		b.box(0, H - 0.11, 0, X, 0.22, Z, finish)
		b.box(0, 0.4, 0, X - 0.6, 0.1, Z - 0.5, finish, DETAIL) -- lower shelf
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				b.box(sx * (X / 2 - 0.25), (H - 0.22) / 2, sz * (Z / 2 - 0.25), 0.16, H - 0.22, 0.16, F.PowderBlack, DETAIL)
			end
		end
		-- styling: a short stack of books and a small ceramic bowl
		local bx = -X / 4
		b.part(L(bx, H + 0.06, 0, 0, r.range(-12, 12), 0), Vector3.new(1.1, 0.12, 0.8), C.tint("Plastic", C.rgb(44, 58, 78)), FINE)
		b.part(L(bx + 0.05, H + 0.17, 0.02, 0, r.range(-20, 20), 0), Vector3.new(0.95, 0.1, 0.7), C.tint("Plastic", C.rgb(222, 212, 192)), FINE)
		b.cylY(X / 4, H + 0.12, 0.1, 0.24, 0.7, C.tint("Plastic", C.rgb(196, 112, 76)), FINE)
		return b.model
	end)

	Props.register("table", function(parent: Instance, cf: CFrame, size: Vector3, finish: C.Finish): Model
		local X, H, Z = C.num(size.X, 4, 1.5, 30), C.num(size.Y, 2.6, 1, 4.5), C.num(size.Z, 4, 1.5, 30)
		local b = C.begin(parent, "Table", cf)
		if math.min(X, Z) <= 3 then
			-- cafe pedestal table: round top, slim column, weighted disc base
			local d = math.min(X, Z)
			b.cylY(0, H - 0.09, 0, 0.18, d, finish)
			b.cylY(0, H - 0.22, 0, 0.08, d * 0.4, F.PowderBlack, FINE)
			b.cylY(0, H / 2, 0, H - 0.2, 0.26, F.PowderBlack, DETAIL)
			b.cylY(0, 0.06, 0, 0.12, d * 0.62, F.PowderBlack, DETAIL)
		else
			b.box(0, H - 0.1, 0, X, 0.2, Z, finish)
			-- apron + four square legs
			b.box(0, H - 0.35, Z / 2 - 0.4, X - 0.8, 0.3, 0.1, F.PowderBlack, DETAIL)
			b.box(0, H - 0.35, -Z / 2 + 0.4, X - 0.8, 0.3, 0.1, F.PowderBlack, DETAIL)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					b.box(sx * (X / 2 - 0.4), (H - 0.2) / 2, sz * (Z / 2 - 0.4), 0.22, H - 0.2, 0.22, F.PowderBlack, DETAIL)
				end
			end
		end
		return b.model
	end)

	Props.register("umbrellaTable", function(parent: Instance, cf: CFrame, canopy: C.Finish): Model
		local b = C.begin(parent, "UmbrellaTable", cf)
		local topY = 2.5
		b.cylY(0, topY - 0.08, 0, 0.16, 3.6, F.Teak)
		b.cylY(0, topY / 2, 0, topY - 0.2, 0.3, F.PowderBlack, DETAIL)
		b.cylY(0, 0.07, 0, 0.14, 1.8, F.PowderBlack, DETAIL)
		-- pole through the table, ribbed eight-panel canopy, finial
		local yb, rise, R = 7.0, 1.2, 4.2
		b.cylY(0, (yb + rise) / 2, 0, yb + rise, 0.16, F.PowderWhite, DETAIL)
		local w = 2 * R * math.tan(math.rad(22.5))
		for i = 0, 7 do
			b.wedge(L(0, yb + rise / 2, 0, 0, i * 45, 0) * CFrame.new(0, 0, -R / 2), Vector3.new(w, rise, R), canopy, { Collide = false, Shadow = true })
		end
		b.ball(0, yb + rise + 0.12, 0, 0.3, F.PowderWhite, FINE)
		-- two chairs facing the table
		for _, side in { -1, 1 } do
			local chair = L(side * 2.6, 0, 0, 0, side * 90, 0)
			local function at(x: number, y: number, z: number): CFrame
				return chair * CFrame.new(x, y, -z)
			end
			b.part(at(0, 1.55, 0), Vector3.new(1.5, 0.14, 1.4), F.Teak)
			b.part(at(0, 2.35, -0.7) * CFrame.Angles(math.rad(10), 0, 0), Vector3.new(1.5, 1.2, 0.12), F.Teak, DETAIL)
			for _, sx in { -1, 1 } do
				-- side frame: front leg + rear leg rising into the back support
				b.part(at(sx * 0.68, 0.74, 0.55), Vector3.new(0.1, 1.48, 0.1), F.PowderBlack, DETAIL)
				b.part(at(sx * 0.68, 1.4, -0.62) * CFrame.Angles(math.rad(6), 0, 0), Vector3.new(0.1, 2.8, 0.1), F.PowderBlack, DETAIL)
			end
		end
		return b.model
	end)

	Props.register("rug", function(parent: Instance, cf: CFrame, size: Vector2, finish: C.Finish): Model
		local X, Z = C.num(size.X, 8, 1, 60), C.num(size.Y, 5, 1, 60)
		local b = C.begin(parent, "Rug", cf)
		local c = C.colorOf(finish)
		local border = C.retint(finish, shade(c, 0.62))
		local line = C.retint(finish, c:Lerp(Color3.fromRGB(226, 206, 160), 0.55))
		local bw = math.clamp(math.min(X, Z) * 0.08, 0.3, 0.8)
		b.box(0, 0.03, 0, X, 0.06, Z, border, FINE)
		b.box(0, 0.04, 0, X - bw * 2, 0.06, Z - bw * 2, line, FINE)
		b.box(0, 0.05, 0, X - bw * 2 - 0.24, 0.06, Z - bw * 2 - 0.24, finish, FINE)
		return b.model
	end)

	Props.register("massageTable", function(parent: Instance, cf: CFrame): Model
		local b = C.begin(parent, "MassageTable", cf)
		local vinyl = C.tint("VinylBlack", C.rgb(118, 128, 112))
		local wood = F.Birch
		local topY = 2.45
		-- padded top (head end toward -z / back), birch apron, legs, stretchers
		b.box(0, topY - 0.17, 0.3, 2.6, 0.34, 6.0, vinyl)
		b.box(0, topY - 0.5, 0.3, 2.3, 0.32, 5.6, wood, DETAIL)
		for _, sx in { -1, 1 } do
			for _, z in { -2.1, 2.7 } do
				b.box(sx * 1.0, (topY - 0.66) / 2, z, 0.26, topY - 0.66, 0.26, wood, DETAIL)
			end
			b.box(sx * 1.0, 0.5, 0.3, 0.14, 0.14, 4.6, wood, FINE)
		end
		-- face cradle on two rods at the head end
		b.span(Vector3.new(-0.5, topY - 0.45, -2.6), Vector3.new(-0.5, topY - 0.3, -3.1), 0.1, F.SteelBrushed, FINE)
		b.span(Vector3.new(0.5, topY - 0.45, -2.6), Vector3.new(0.5, topY - 0.3, -3.1), 0.1, F.SteelBrushed, FINE)
		b.box(0, topY - 0.22, -3.3, 1.5, 0.28, 0.9, vinyl, DETAIL)
		b.box(0, topY - 0.07, -3.32, 0.6, 0.02, 0.36, C.tint("PlasticBlack", C.rgb(40, 42, 40)), FINE)
		-- rolled bolster + folded towel at the foot end
		b.cylX(0, topY + 0.28, 1.6, 2.2, 0.56, C.tint("FabricWhite", C.rgb(228, 226, 218)), DETAIL)
		b.box(0, topY + 0.1, 2.75, 1.8, 0.2, 0.9, C.tint("FabricWhite", C.rgb(242, 240, 234)), FINE)
		return b.model
	end)
end
