--!strict
--[[
	Gym clutter and small life details: towels, bottles, shakers, bags,
	cleaning stations, bins, chalk, foam rollers, medicine balls, kettlebells,
	loose plates and queue stanchions.

	Floor-level props (cf = bottom centre, front = LookVector). Nearly every
	part here is Kit.DETAIL / no-shadow so scattering dozens of these around an
	area stays cheap; only bins, racks and the cleaning-station bin collide.
]]

local C = require("./Common")

type B = C.B

local L = C.L
local DETAIL = C.DETAIL
local FINE = C.FINE
local SOLID = C.SOLID
local F = C.F

local INK = C.tint("PlasticBlack", C.rgb(26, 26, 28))

local function fabric(color: Color3): C.Fin
	return C.tint("FabricWhite", color)
end

local function plastic(color: Color3): C.Fin
	return C.tint("Plastic", color)
end

-- slightly darker version of a colour (towel borders, end caps)
local function deeper(c: Color3, k: number): Color3
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

local function color3(v: any, default: Color3): Color3
	return if typeof(v) == "Color3" then v :: Color3 else default
end

-- folded towel lying flat at local (x, y, z): body, rolled fold edge, border stripe
local function foldedTowel(b: B, x: number, y: number, z: number, yaw: number, c: Color3, stripe: boolean)
	local base = L(x, y, z, 0, yaw, 0)
	b.part(base * CFrame.new(-0.06, 0.12, 0), Vector3.new(1.06, 0.24, 0.8), fabric(c), FINE)
	b.cyl(base * CFrame.new(0.47, 0.12, 0) * CFrame.Angles(0, math.rad(90), 0), 0.8, 0.24, fabric(c), FINE) -- rolled fold edge
	if stripe then
		b.part(base * CFrame.new(-0.3, 0.245, 0), Vector3.new(0.12, 0.012, 0.8), fabric(deeper(c, 0.82)), FINE)
	end
end

return function(Props: C.Registry)
	Props.register("towel", function(parent: Instance, cf: CFrame, color: Color3): Model
		local b = C.begin(parent, "Towel", cf)
		foldedTowel(b, 0, 0, 0, 0, color3(color, Color3.fromRGB(240, 240, 236)), true)
		return b.model
	end)

	Props.register("towelStack", function(parent: Instance, cf: CFrame, count: number, color: Color3): Model
		local n = math.floor(C.num(count, 5, 1, 8))
		local c = color3(color, Color3.fromRGB(240, 240, 236))
		local b = C.begin(parent, "TowelStack", cf)
		local r = C.rng(cf, 31)
		for i = 1, n do
			local y = (i - 1) * 0.24
			if i == n then
				foldedTowel(b, r.range(-0.03, 0.03), y, 0, r.range(-5, 5), c, true)
			else
				b.part(L(r.range(-0.04, 0.04), y + 0.12, r.range(-0.03, 0.03), 0, r.range(-4, 4), 0), Vector3.new(1.18, 0.23, 0.8), fabric(if i % 2 == 0 then c else deeper(c, 0.95)), FINE)
			end
		end
		return b.model
	end)

	Props.register("towelRack", function(parent: Instance, cf: CFrame): Model
		local b = C.begin(parent, "TowelRack", cf)
		local W, D, H = 2.9, 1.3, 5
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				b.cylY(sx * (W / 2 - 0.06), H / 2, sz * (D / 2 - 0.06), H, 0.1, F.Chrome, DETAIL)
			end
		end
		for _, y in { 0.35, 2.55, 4.0 } do
			b.box(0, y, 0, W, 0.06, D, F.SteelBrushed, DETAIL)
		end
		-- two rows of rolled towels, laundry hamper for used ones on the base
		for _, y in { 2.83, 4.28 } do
			for i = 0, 4 do
				b.cylZ(-1.08 + i * 0.54, y, 0, 1.1, 0.5, fabric(Color3.fromRGB(242, 241, 236)), FINE)
			end
		end
		b.box(0, 0.38 + 0.6, 0, 2.5, 1.2, 1.1, C.tint("FabricGrey", C.rgb(96, 98, 102)), SOLID)
		return b.model
	end)

	Props.register("waterBottle", function(parent: Instance, cf: CFrame, color: Color3): Model
		local b = C.begin(parent, "WaterBottle", cf)
		local c = color3(color, Color3.fromRGB(60, 168, 156))
		b.cylY(0, 0.34, 0, 0.68, 0.32, C.tint("PowderWhite", c), FINE)
		b.cylY(0, 0.76, 0, 0.16, 0.26, INK, FINE)
		b.box(0, 0.88, 0, 0.05, 0.1, 0.18, INK, FINE) -- carry loop
		return b.model
	end)

	Props.register("shaker", function(parent: Instance, cf: CFrame, color: Color3): Model
		local b = C.begin(parent, "Shaker", cf)
		local c = color3(color, Color3.fromRGB(30, 30, 32))
		b.cylY(0, 0.29, 0, 0.58, 0.38, plastic(c), FINE)
		b.cylY(0, 0.65, 0, 0.14, 0.41, INK, FINE)
		b.cylY(0.06, 0.75, 0, 0.07, 0.16, F.Amber, FINE)
		return b.model
	end)

	Props.register("gymBag", function(parent: Instance, cf: CFrame, color: Color3): Model
		local b = C.begin(parent, "GymBag", cf)
		local c = color3(color, Color3.fromRGB(40, 42, 46))
		local body = C.tint("FabricGrey", c)
		-- barrel duffel resting on a slightly flattened base, round end caps
		b.cylX(0, 0.5, 0, 1.9, 1.0, body, FINE)
		b.box(0, 0.12, 0, 1.7, 0.24, 0.78, body, FINE)
		for _, sx in { -1, 1 } do
			b.cylX(sx * 0.96, 0.5, 0, 0.06, 1.03, C.tint("FabricGrey", deeper(c, 0.62)), FINE)
		end
		b.box(0, 1.0, 0, 1.6, 0.02, 0.07, INK, FINE) -- zipper
		b.cylX(0, 1.3, 0, 0.8, 0.08, INK, FINE) -- carry handle
		for _, sx in { -1, 1 } do
			b.box(sx * 0.42, 1.15, 0, 0.1, 0.32, 0.06, INK, FINE)
		end
		b.box(0.3, 0.5, 0.505, 0.5, 0.2, 0.02, F.Amber, FINE) -- brand patch
		return b.model
	end)

	Props.register("cleaningStation", function(parent: Instance, cf: CFrame): Model
		local b = C.begin(parent, "CleaningStation", cf)
		local white = F.PowderWhite
		b.box(0, 0.04, 0, 2.0, 0.08, 1.4, INK, DETAIL)
		for _, sx in { -1, 1 } do
			b.box(sx * 0.75, 0.55, -0.55, 0.12, 1.0, 0.12, F.PowderGraphite, DETAIL)
		end
		b.box(0, 2.55, -0.55, 1.8, 3.1, 0.1, white, SOLID)
		b.box(0, 4.25, -0.55, 1.8, 0.5, 0.16, C.tint("PlasticTeal", C.rgb(44, 120, 112)), DETAIL)
		b.box(0, 4.25, -0.46, 1.2, 0.08, 0.02, white, FINE) -- header pinstripe
		-- paper towel dispenser
		b.box(0, 3.35, -0.27, 1.0, 0.9, 0.46, INK, DETAIL)
		b.box(0, 2.86, -0.1, 0.5, 0.14, 0.02, C.tint("Plaster", C.rgb(240, 238, 232)), FINE)
		-- shelf with spray bottles and a wipes canister
		b.box(0, 2.05, -0.27, 1.6, 0.06, 0.5, F.SteelBrushed, DETAIL)
		for i, x in { -0.55, -0.15 } do
			local bottle = if i == 1 then C.tint("Plastic", C.rgb(232, 236, 238)) else C.tint("PlasticTeal", C.rgb(70, 170, 160))
			b.cylY(x, 2.36, -0.25, 0.56, 0.28, bottle, FINE)
			b.box(x, 2.74, -0.22, 0.14, 0.2, 0.3, INK, FINE) -- trigger head
		end
		b.cylY(0.45, 2.33, -0.25, 0.5, 0.42, C.tint("Plastic", C.rgb(220, 224, 226)), FINE)
		b.cylY(0.45, 2.62, -0.25, 0.08, 0.44, C.tint("PlasticTeal", C.rgb(44, 120, 112)), FINE)
		-- bin with swing lid
		b.box(0, 0.08 + 0.66, 0.08, 1.3, 1.32, 0.9, C.tint("PowderGraphite", C.rgb(84, 86, 90)), SOLID)
		b.box(0, 1.47, 0.08, 1.36, 0.14, 0.96, INK, DETAIL)
		return b.model
	end)

	Props.register("trashBin", function(parent: Instance, cf: CFrame, finish: C.Finish): Model
		local b = C.begin(parent, "TrashBin", cf)
		b.cylY(0, 0.04, 0, 0.08, 1.2, INK, FINE)
		b.cylY(0, 0.08 + 1.06, 0, 2.12, 1.3, finish, SOLID)
		b.cylY(0, 2.26, 0, 0.14, 1.36, F.PowderBlack, DETAIL)
		b.cylY(0, 2.335, 0, 0.02, 0.86, C.tint("PlasticBlack", C.rgb(12, 12, 14)), FINE)
		return b.model
	end)

	Props.register("chalkBowl", function(parent: Instance, cf: CFrame): Model
		local b = C.begin(parent, "ChalkBowl", cf)
		local r = C.rng(cf, 37)
		local chalk = C.tint("Plaster", C.rgb(244, 243, 240))
		b.cylY(0, 0.012, 0, 0.02, 2.4, C.tint("Plaster", C.rgb(236, 236, 232)), { Collide = false, Shadow = false, Transparency = 0.55 })
		b.cylY(0, 0.06, 0, 0.12, 1.5, F.CastIron, DETAIL)
		b.cylY(0, 1.5, 0, 2.8, 0.3, F.SteelBrushed, SOLID)
		b.cylY(0, 3.1, 0, 0.5, 1.8, F.Rubber, DETAIL)
		b.cylY(0, 3.33, 0, 0.06, 1.62, chalk, FINE)
		b.part(L(0.25, 3.43, 0.1, 0, r.range(0, 90), 8), Vector3.new(0.45, 0.25, 0.32), chalk, FINE)
		b.part(L(-0.3, 3.42, -0.15, 0, r.range(0, 90), -6), Vector3.new(0.38, 0.22, 0.3), chalk, FINE)
		return b.model
	end)

	Props.register("foamRollers", function(parent: Instance, cf: CFrame): Model
		local b = C.begin(parent, "FoamRollers", cf)
		local W, D = 2.9, 1.3
		for _, sx in { -1, 1 } do
			b.box(sx * (W / 2 - 0.05), 1.0, 0, 0.1, 2.0, D, F.PowderBlack, SOLID)
		end
		local colors: { C.Fin } = {
			C.tint("Foam", C.rgb(36, 36, 40)),
			C.tint("Foam", C.rgb(52, 140, 132)),
			C.tint("Foam", C.rgb(214, 104, 76)),
			C.tint("Foam", C.rgb(140, 142, 146)),
		}
		for k, y in { 0.12, 1.1, 1.98 } do
			b.box(0, y, 0, W - 0.2, 0.08, D, F.PowderBlack, DETAIL)
			if k < 3 then
				for i = 0, 2 do
					b.cylZ(-0.86 + i * 0.86, y + 0.39, 0, 1.15, 0.7, colors[1 + (i + k) % #colors], FINE)
				end
			else
				-- a few standing on top
				for i = 0, 2 do
					b.cylY(-0.8 + i * 0.8, y + 0.54, 0, 1.0, 0.6, colors[1 + (i + 2) % #colors], FINE)
				end
			end
		end
		return b.model
	end)

	Props.register("medBalls", function(parent: Instance, cf: CFrame): Model
		local b = C.begin(parent, "MedBalls", cf)
		local W = 4.8
		for _, sx in { -1, 1 } do
			b.box(sx * (W / 2 - 0.06), 1.95, 0, 0.1, 3.9, 1.5, F.PowderGraphite, SOLID)
		end
		local balls: { C.Fin } = {
			C.tint("Rubber", C.rgb(36, 36, 38)),
			C.tint("Rubber", C.rgb(150, 44, 40)),
			C.tint("Rubber", C.rgb(46, 74, 120)),
			C.tint("Rubber", C.rgb(196, 140, 44)),
			C.tint("Rubber", C.rgb(64, 110, 70)),
		}
		-- three stepped tiers (deepest at the bottom), two rails each
		for k, t in { { y = 0.6, z = 0.25 }, { y = 1.85, z = 0.0 }, { y = 3.1, z = -0.25 } } do
			for _, dz in { -0.28, 0.28 } do
				b.cylX(0, t.y, t.z + dz, W - 0.1, 0.1, F.SteelBrushed, FINE)
			end
			local d = 1.05 - 0.12 * (k - 1)
			for i = 0, 3 do
				b.ball(-1.65 + i * 1.1, t.y + d * 0.42, t.z, d, balls[1 + (i + k) % #balls], FINE)
			end
		end
		return b.model
	end)

	Props.register("kettlebells", function(parent: Instance, cf: CFrame, count: number): Model
		local n = math.floor(C.num(count, 6, 1, 10))
		local b = C.begin(parent, "Kettlebells", cf)
		-- competition colours by weight: 8 12 16 20 24 28 32 36 40 48 kg
		local colors = {
			C.rgb(228, 120, 160), C.rgb(60, 110, 190), C.rgb(232, 196, 60), C.rgb(120, 70, 150), C.rgb(70, 140, 80),
			C.rgb(232, 128, 50), C.rgb(196, 50, 46), C.rgb(130, 132, 136), C.rgb(236, 236, 232), C.rgb(40, 40, 42),
		}
		local pitch = 1.05
		local Wm = n * pitch + 0.3
		b.box(0, 0.03, 0, Wm, 0.06, 1.4, F.RubberFloor, FINE)
		for i = 1, n do
			local x = -Wm / 2 + 0.15 + pitch * (i - 0.5)
			local d = 0.72 + 0.03 * i
			local body = C.tint("PowderWhite", colors[i])
			b.ball(x, 0.06 + d / 2, 0, d, body, FINE)
			local hy = 0.06 + d * 0.92
			local hw = d * 0.56
			for _, sx in { -1, 1 } do
				b.cylY(x + sx * hw / 2, hy + 0.12, 0, 0.3, 0.13, F.CastIron, FINE)
			end
			b.cylX(x, hy + 0.3, 0, hw + 0.13, 0.13, F.CastIron, FINE)
		end
		return b.model
	end)

	Props.register("plateStack", function(parent: Instance, cf: CFrame, finish: C.Finish, count: number): Model
		local n = math.floor(C.num(count, 4, 1, 8))
		local b = C.begin(parent, "PlateStack", cf)
		local r = C.rng(cf, 41)
		local y = 0
		for i = 1, n do
			local d = 2.45 - (i - 1) * (0.7 / math.max(1, n - 1))
			local t = 0.24 - 0.02 * math.min(i - 1, 3)
			b.cylY(r.range(-0.06, 0.06), y + t / 2, r.range(-0.06, 0.06), t, d, finish, if i == 1 then DETAIL else FINE)
			y += t
		end
		b.cylY(0, y + 0.01, 0, 0.02, 0.62, F.SteelBrushed, FINE) -- hub insert
		return b.model
	end)

	Props.register("stanchions", function(parent: Instance, cf: CFrame, bPoint: Vector3): Model
		local a = cf.Position
		local frame, len = C.floorFrame(a, if typeof(bPoint) == "Vector3" then bPoint else a + Vector3.new(4, 0, 0))
		local b = C.begin(parent, "Stanchions", frame, true)
		local n = math.max(2, math.ceil(len / 4) + 1)
		local rope = C.tint("Velvet", C.rgb(110, 30, 42))
		local topY = 2.8
		for i = 0, n - 1 do
			local x = len * i / (n - 1)
			b.cylY(x, 0.05, 0, 0.1, 0.9, F.Brass, DETAIL)
			b.cylY(x, topY / 2, 0, topY, 0.16, F.Brass, DETAIL)
			b.ball(x, topY + 0.1, 0, 0.26, F.Brass, FINE)
			if i < n - 1 then
				local x1 = len * (i + 1) / (n - 1)
				local mid = Vector3.new((x + x1) / 2, topY - 0.15 - math.min(0.5, (x1 - x) * 0.12), 0)
				b.span(Vector3.new(x + 0.1, topY - 0.15, 0), mid, 0.13, rope, FINE)
				b.span(mid, Vector3.new(x1 - 0.1, topY - 0.15, 0), 0.13, rope, FINE)
			end
		end
		return b.model
	end)
end
