--!strict
--[[
	Outdoor props: lamp posts, fences, park benches, parked cars, bike racks,
	bollards and flag poles. Floor-level CFrames; lamp heads, flood heads and
	cars face cf.LookVector. Fences run along floor points a -> b.

	Street-scale lights keep shadows off (dozens line the site); the flood
	pole carries one wide SpotLight for all three heads.
]]

local C = require("./Common")

type B = C.B

local L = C.L
local DETAIL = C.DETAIL
local FINE = C.FINE
local SOLID = C.SOLID
local F = C.F

local POLE = C.tint("PowderGraphite", C.rgb(48, 50, 54))

return function(Props: C.Registry)
	Props.register("lampPost", function(parent: Instance, cf: CFrame, kind: string): Model
		local k = if type(kind) == "string" then kind else "Park"
		local b = C.begin(parent, "LampPost_" .. k, cf)
		if k == "Street" then
			b.cylY(0, 0.4, 0, 0.8, 1.0, F.ConcreteDark, SOLID)
			b.cylY(0, 0.8 + 5, 0, 10, 0.5, POLE, SOLID)
			b.cylY(0, 10.8 + 3.6, 0, 7.2, 0.36, POLE, DETAIL)
			b.span(Vector3.new(0, 17.6, 0), Vector3.new(0, 18.0, 3.6), 0.22, POLE, FINE)
			b.part(L(0, 17.9, 4.3, 4, 0, 0), Vector3.new(1.0, 0.3, 1.8), POLE, FINE)
			local lens = b.part(L(0, 17.73, 4.32, 4, 0, 0), Vector3.new(0.8, 0.04, 1.5), C.tint("LightPanel", C.rgb(255, 240, 220)), FINE)
			lens.Name = "Lens"
			C.light(lens, "Spot", nil, { Color = C.NEUTRAL, Brightness = 2, Range = 40, Angle = 120, Face = Enum.NormalId.Bottom })
		elseif k == "Flood" then
			b.cylY(0, 0.5, 0, 1.0, 1.4, F.ConcreteDark, SOLID)
			b.cylY(0, 1.0 + 10.5, 0, 21, 0.6, F.SteelBrushed, SOLID)
			b.box(0, 21.6, 0.35, 4.4, 0.25, 0.25, F.SteelBrushed, FINE)
			local center: Part? = nil
			for i = -1, 1 do
				local head = L(i * 1.4, 21.3, 0.75, -35, 0, 0)
				b.part(head, Vector3.new(1.2, 0.85, 0.4), F.SteelDark, FINE)
				local lens = b.part(head * CFrame.new(0, 0, -0.21), Vector3.new(1.0, 0.65, 0.02), C.tint("LightCool", C.rgb(236, 244, 255)), FINE)
				if i == 0 then
					center = lens
				end
			end
			if center then
				center.Name = "Lens"
				C.light(center, "Spot", nil, { Color = C.COOL, Brightness = 2.2, Range = 60, Angle = 90, Face = Enum.NormalId.Front })
			end
		else -- Park: slim post with an opal lantern
			b.cylY(0, 0.3, 0, 0.6, 0.8, POLE, SOLID)
			b.cylY(0, 0.6 + 4.6, 0, 9.2, 0.3, POLE, SOLID)
			b.cylY(0, 9.9, 0, 0.16, 0.7, POLE, FINE)
			local glow = b.cylY(0, 10.6, 0, 1.25, 0.8, C.tint("LightWarm", C.rgb(255, 228, 190)), FINE)
			glow.Name = "Lantern"
			b.cylY(0, 11.3, 0, 0.18, 1.05, POLE, FINE)
			b.ball(0, 11.45, 0, 0.3, POLE, FINE)
			C.light(glow, "Point", nil, { Color = C.WARM, Brightness = 1.2, Range = 24 })
		end
		return b.model
	end)

	Props.register("fence", function(parent: Instance, cf: CFrame, bPoint: Vector3, height: number, kind: string): Model
		local a = cf.Position
		local frame, len = C.floorFrame(a, if typeof(bPoint) == "Vector3" then bPoint else a + Vector3.new(8, 0, 0))
		local h = C.num(height, 6, 1, 30)
		local k = if type(kind) == "string" then kind else "Chainlink"
		local b = C.begin(parent, "Fence_" .. k, frame, true)
		local function posts(pitch: number, fn: (x: number) -> ())
			local n = math.max(1, math.floor(len / pitch + 0.5))
			for i = 0, n do
				fn(len * i / n)
			end
		end
		if k == "Rail" then
			local blk = F.PowderBlack
			posts(6, function(x: number)
				b.box(x, h / 2, 0, 0.2, h, 0.2, blk, DETAIL)
			end)
			b.box(len / 2, h - 0.06, 0, len + 0.2, 0.12, 0.24, blk, SOLID)
			b.box(len / 2, h * 0.55, 0, len, 0.1, 0.12, blk, SOLID)
			b.box(len / 2, 0.4, 0, len, 0.1, 0.12, blk, SOLID)
		elseif k == "Glass" then
			b.box(len / 2, 0.15, 0, len, 0.3, 0.4, F.SteelDark, SOLID)
			b.box(len / 2, (h - 0.12) / 2 + 0.15, 0, len - 0.1, h - 0.42, 0.12, F.Glass, { Collide = true, Shadow = false })
			b.box(len / 2, h - 0.06, 0, len + 0.1, 0.12, 0.34, F.SteelBrushed, DETAIL)
			posts(6, function(x: number)
				b.box(x, h / 2, 0, 0.16, h - 0.1, 0.24, F.SteelBrushed, FINE)
			end)
		elseif k == "Timber" then
			-- horizontal slatted screen on steel posts
			posts(6, function(x: number)
				b.box(x, h / 2, -0.12, 0.36, h, 0.36, F.PowderBlack, DETAIL)
			end)
			local boards = math.max(2, math.floor(h / 0.72))
			local pitch = (h - 0.2) / boards
			for i = 0, boards - 1 do
				b.box(len / 2, 0.15 + pitch * (i + 0.5), 0.12, len + 0.36, pitch - 0.16, 0.14, F.Teak, if i == 0 then SOLID else DETAIL)
			end
			b.box(len / 2, h + 0.05, 0, len + 0.4, 0.1, 0.5, F.PowderBlack, DETAIL)
			-- invisible collider so the gaps never snag players
			b.box(len / 2, h / 2, 0.12, len, h, 0.14, F.Plastic, { Collide = true, Transparency = 1, Shadow = false })
		else -- Chainlink
			local galv = C.tint("SteelBrushed", C.rgb(160, 164, 168))
			posts(8, function(x: number)
				b.cylY(x, (h + 0.2) / 2, 0, h + 0.2, 0.25, galv, DETAIL)
				b.ball(x, h + 0.22, 0, 0.3, galv, FINE)
			end)
			b.cylX(len / 2, h - 0.05, 0, len, 0.16, galv, FINE)
			b.cylX(len / 2, 0.25, 0, len, 0.05, galv, FINE)
			b.box(len / 2, (h + 0.2) / 2, 0, len, h - 0.2, 0.04, C.tint("Steel", C.rgb(150, 154, 160)), { Collide = true, Shadow = false, Transparency = 0.62 })
		end
		return b.model
	end)

	Props.register("parkBench", function(parent: Instance, cf: CFrame): Model
		local b = C.begin(parent, "ParkBench", cf)
		local iron = F.CastIron
		for _, sx in { -1, 1 } do
			local x = sx * 2.2
			b.box(x, 1.05, 0.55, 0.18, 2.1, 0.18, iron, DETAIL) -- front leg + arm post
			b.part(L(x, 1.4, -0.55, 12, 0, 0), Vector3.new(0.18, 2.9, 0.18), iron, DETAIL) -- rear leg / back
			b.box(x, 2.15, 0.05, 0.2, 0.1, 1.45, iron, FINE) -- armrest
			b.box(x, 1.32, 0, 0.16, 0.14, 1.4, iron, FINE) -- seat bearer
		end
		for i = 0, 3 do
			b.box(0, 1.46, 0.5 - i * 0.34, 4.8, 0.13, 0.28, F.Teak, if i == 0 then SOLID else DETAIL)
		end
		for i = 0, 1 do
			b.part(L(0, 2.05 + i * 0.45, -0.72 - i * 0.1, 12, 0, 0), Vector3.new(4.8, 0.3, 0.11), F.Teak, DETAIL)
		end
		return b.model
	end)

	Props.register("car", function(parent: Instance, cf: CFrame, color: Color3): Model
		local b = C.begin(parent, "Car", cf)
		local c = if typeof(color) == "Color3" then color else C.rgb(60, 64, 70)
		local paint = { Material = Enum.Material.SmoothPlastic, Color = c, Reflectance = 0.12 } :: C.Fin
		local trim = C.tint("PlasticBlack", C.rgb(30, 31, 34))
		local glass = { Material = Enum.Material.Glass, Color = C.rgb(40, 48, 56), Reflectance = 0.15, Transparency = 0.3 } :: C.Fin
		-- body, bumpers, interior volume behind the glass
		-- lower body, shoulder line with sloped nose and tail, bumpers
		b.box(0, 1.2, 0, 5.8, 1.2, 14.2, paint, SOLID)
		b.box(0, 2.05, -0.1, 5.6, 0.5, 12.6, paint, DETAIL)
		b.wedge(L(0, 2.05, 6.4, 0, 0, 0), Vector3.new(5.6, 0.5, 0.4 + 0.2), paint, FINE)
		b.wedge(L(0, 2.05, -6.65, 0, 180, 0), Vector3.new(5.6, 0.5, 0.5), paint, FINE)
		b.box(0, 1.0, 7.15, 6.0, 0.6, 0.3, trim, DETAIL)
		b.box(0, 1.0, -7.15, 6.0, 0.6, 0.3, trim, DETAIL)
		-- dark interior volume kept inside the side glass so it never pokes through
		b.box(0, 3.0, -0.6, 5.1, 1.3, 4.7, C.tint("PlasticBlack", C.rgb(22, 22, 24)), FINE)
		-- greenhouse: raked windscreen, side glass, roof, B-pillar, rear window
		b.wedge(L(0, 2.3 + 0.82, 2.95, 0, 0, 0), Vector3.new(5.3, 1.64, 2.3), glass, DETAIL)
		b.box(0, 2.3 + 0.8, -0.6, 5.3, 1.6, 4.9, glass, DETAIL)
		b.box(0, 3.99, -0.6, 5.36, 0.18, 4.9, paint, DETAIL)
		b.box(0, 3.1, -0.35, 5.36, 1.6, 0.26, paint, FINE)
		b.wedge(L(0, 2.3 + 0.82, -4.05, 0, 180, 0), Vector3.new(5.3, 1.64, 2.0), glass, DETAIL)
		-- wheels: tyre + rim, slightly proud of the body sides
		for _, sx in { -1, 1 } do
			for _, z in { 4.6, -4.6 } do
				b.cylX(sx * 2.78, 1.12, z, 0.82, 2.24, F.Rubber, DETAIL)
				b.cylX(sx * 2.8, 1.12, z, 0.84, 1.3, F.SteelBrushed, FINE)
			end
		end
		-- lamps and grille
		for _, sx in { -1, 1 } do
			b.box(sx * 2.1, 1.55, 7.11, 1.3, 0.34, 0.06, C.tint("Plastic", C.rgb(236, 236, 228)), FINE)
			b.box(sx * 2.15, 1.55, -7.11, 1.2, 0.32, 0.06, C.tint("Plastic", C.rgb(176, 30, 34)), FINE)
		end
		b.box(0, 1.5, 7.11, 2.4, 0.42, 0.04, trim, FINE)
		return b.model
	end)

	Props.register("bikeRack", function(parent: Instance, cf: CFrame): Model
		local b = C.begin(parent, "BikeRack", cf)
		local steel = C.tint("SteelBrushed", C.rgb(160, 164, 168))
		for _, x in { -2, 0, 2 } do
			for _, z in { -0.7, 0.7 } do
				b.cylY(x, 1.15, z, 2.3, 0.16, steel, DETAIL)
			end
			b.cylZ(x, 2.3, 0, 1.56, 0.16, steel, DETAIL)
		end
		return b.model
	end)

	Props.register("bollard", function(parent: Instance, cf: CFrame): Model
		local b = C.begin(parent, "Bollard", cf)
		b.cylY(0, 1.15, 0, 2.3, 0.7, POLE, SOLID)
		b.cylY(0, 1.95, 0, 0.14, 0.72, C.tint("Plastic", C.rgb(236, 236, 230)), FINE)
		b.ball(0, 2.3, 0, 0.7, POLE, FINE)
		return b.model
	end)

	Props.register("flag", function(parent: Instance, cf: CFrame, color: Color3): Model
		local b = C.begin(parent, "Flag", cf)
		local c = if typeof(color) == "Color3" then color else C.rgb(242, 169, 59)
		b.box(0, 0.2, 0, 1.2, 0.4, 1.2, F.ConcreteDark, SOLID)
		b.cylY(0, 0.4 + 6, 0, 12, 0.32, F.SteelBrushed, SOLID)
		b.cylY(0, 12.4 + 3.9, 0, 7.8, 0.22, F.SteelBrushed, DETAIL)
		b.ball(0, 20.35, 0, 0.42, F.Gold, FINE)
		b.span(Vector3.new(0.2, 0.5, 0), Vector3.new(0.2, 20.0, 0), 0.03, C.tint("Plastic", C.rgb(220, 220, 216)), FINE)
		-- three gently waving panels
		local cloth = C.tint("FabricWhite", c)
		local seg = 1.4
		local pos = Vector3.new(0.12, 18.5, 0)
		local yaw = 0
		for _, turn in { 10, -16, 14 } do
			yaw += turn
			local dir = Vector3.new(math.cos(math.rad(yaw)), 0, math.sin(math.rad(yaw)))
			local mid = pos + dir * (seg / 2)
			b.part(L(mid.X, mid.Y, mid.Z, 0, yaw, 0), Vector3.new(seg + 0.02, 2.6, 0.05), cloth, FINE)
			pos += dir * seg
		end
		return b.model
	end)
end
