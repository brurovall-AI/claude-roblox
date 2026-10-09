--!strict
--[[
	Building services and structure: spiral ducts, pipes, cable trays,
	Warren trusses, columns and fans.

	Runs (duct / pipe / cableTray / truss) take world points a -> b:
	  duct, pipe, cableTray  a/b are the CENTRELINE; hanger rods rise 1.5
	                         studs above the top, so place runs with their top
	                         0.3-1.5 below the ceiling (rods bury into the slab)
	  truss                  a/b are the TOP CHORD; the truss hangs `depth` below
	Vertical runs (|dir.Y| > 0.7) get collars/brackets instead of hangers.

	Overhead parts never collide. Columns and floor fans collide.
]]

local C = require("./Common")

type B = C.B

local L = C.L
local DETAIL = C.DETAIL
local FINE = C.FINE
local SOLID = C.SOLID
local F = C.F

local ROD = F.SteelDark

local function isVertical(a: Vector3, b: Vector3): boolean
	local d = b - a
	return d.Magnitude > 1e-3 and math.abs(d.Unit.Y) > 0.7
end

-- evenly spaced stations along a run, inset from the ends
local function stations(len: number, pitch: number, inset: number): { number }
	local out: { number } = {}
	local usable = len - 2 * inset
	if usable <= 0 then
		table.insert(out, len / 2)
		return out
	end
	local n = math.max(1, math.floor(usable / pitch + 0.5))
	for i = 0, n do
		table.insert(out, inset + usable * i / n)
	end
	return out
end

-- vertical hanger rod + ceiling plate above a run point (world-up even on slight slopes)
local function hanger(b: B, x: number, top: number, rise: number)
	b.span(Vector3.new(x, top, 0), Vector3.new(x, top + rise, 0), 0.08, ROD, FINE)
	b.box(x, top + rise - 0.03, 0, 0.36, 0.06, 0.36, ROD, FINE)
end

-- fan head (motor, two grilles, blades); `base` is a LOCAL frame (builder
-- space, Roblox axes) whose LookVector is the airflow direction
local function fanHead(b: B, base: CFrame, dia: number)
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, -z)
	end
	b.cyl(at(0, 0, -0.35) * CFrame.Angles(0, math.rad(90), 0), 0.6, 0.62, F.PowderBlack, FINE) -- motor
	local grille = C.tint("SteelDark", C.rgb(60, 62, 66))
	local grilleOpts = { Collide = false, Shadow = false, Transparency = 0.55 } :: C.Opts
	b.cyl(at(0, 0, 0.18) * CFrame.Angles(0, math.rad(90), 0), 0.04, dia, grille, grilleOpts)
	b.cyl(at(0, 0, -0.08) * CFrame.Angles(0, math.rad(90), 0), 0.04, dia, grille, grilleOpts)
	b.cyl(at(0, 0, 0.05) * CFrame.Angles(0, math.rad(90), 0), 0.3, dia + 0.04, F.PowderBlack, { Collide = false, Shadow = false, Transparency = 0.8 })
	b.cyl(at(0, 0, 0.06) * CFrame.Angles(0, math.rad(90), 0), 0.12, 0.3, F.PowderBlack, FINE) -- hub
	for i = 0, 2 do
		b.part(at(0, 0, 0.05) * CFrame.Angles(0, 0, math.rad(i * 120)) * CFrame.new(0, dia * 0.25, 0) * CFrame.Angles(0, math.rad(32), 0), Vector3.new(dia * 0.2, dia * 0.38, 0.04), C.tint("Plastic", C.rgb(210, 214, 218)), FINE)
	end
end

return function(Props: C.Registry)
	Props.register("duct", function(parent: Instance, cf: CFrame, bPoint: Vector3, diameter: number, finish: C.Finish): Model
		local a = cf.Position
		local frame, len = C.runFrame(a, bPoint)
		local d = C.num(diameter, 2.4, 0.4, 8)
		local b = C.begin(parent, "Duct", frame, true)
		b.cylX(len / 2, 0, 0, len, d, finish, { Collide = false, Shadow = true })
		-- end flanges + seam collars + hangers
		for _, x in { 0.08, len - 0.08 } do
			b.cylX(x, 0, 0, 0.16, d + 0.14, finish, FINE)
		end
		local vertical = isVertical(a, bPoint)
		for i, x in stations(len, 8, 1.5) do
			b.cylX(x, 0, 0, 0.22, d + 0.1, finish, FINE)
			if not vertical and i % 2 == 1 then
				hanger(b, x, d / 2 + 0.05, 1.5)
			end
		end
		-- linear slot diffusers on the underside every ~12 studs
		if not vertical then
			for _, x in stations(len, 12, 4) do
				b.box(x, -d / 2 + 0.06, 0, 1.6, 0.06, d * 0.36, C.tint("SteelDark", C.rgb(46, 48, 52)), FINE)
			end
		end
		return b.model
	end)

	Props.register("pipe", function(parent: Instance, cf: CFrame, bPoint: Vector3, diameter: number, finish: C.Finish): Model
		local a = cf.Position
		local frame, len = C.runFrame(a, bPoint)
		local d = C.num(diameter, 0.4, 0.1, 4)
		local b = C.begin(parent, "Pipe", frame, true)
		b.cylX(len / 2, 0, 0, len, d, finish, { Collide = false, Shadow = d >= 0.6 })
		for _, x in { 0.1, len - 0.1 } do
			b.cylX(x, 0, 0, 0.2, d * 1.45, finish, FINE) -- flanges
		end
		local vertical = isVertical(a, bPoint)
		for _, x in stations(len, 8, 1.2) do
			b.cylX(x, 0, 0, 0.14, d * 1.3, ROD, FINE) -- clamp
			if not vertical then
				hanger(b, x, d / 2 + 0.05, 1.2)
			end
		end
		return b.model
	end)

	Props.register("cableTray", function(parent: Instance, cf: CFrame, bPoint: Vector3): Model
		local a = cf.Position
		local frame, len = C.runFrame(a, bPoint)
		local b = C.begin(parent, "CableTray", frame, true)
		local galv = C.tint("SteelBrushed", C.rgb(168, 172, 176))
		local w = 1.2
		b.box(len / 2, -0.17, 0, len, 0.04, w, galv, FINE)
		for _, sz in { -1, 1 } do
			b.box(len / 2, 0, sz * (w / 2 - 0.03), len, 0.38, 0.06, galv, FINE)
		end
		-- a loom of cables lying in the tray
		local cables = { { z = -0.3, d = 0.18, c = C.rgb(28, 28, 30) }, { z = -0.08, d = 0.14, c = C.rgb(70, 72, 76) }, { z = 0.12, d = 0.16, c = C.rgb(196, 110, 40) }, { z = 0.32, d = 0.12, c = C.rgb(28, 28, 30) } }
		for _, cb in cables do
			b.cylX(len / 2, -0.15 + cb.d / 2, cb.z, len - 0.1, cb.d, C.tint("Rubber", cb.c), FINE)
		end
		if not isVertical(a, bPoint) then
			-- trapeze hangers: strut under the tray on two rods
			for _, x in stations(len, 8, 1) do
				b.box(x, -0.27, 0, 0.16, 0.16, w + 0.5, ROD, FINE)
				for _, sz in { -1, 1 } do
					b.span(Vector3.new(x, -0.27, sz * (w / 2 + 0.14)), Vector3.new(x, 1.5, sz * (w / 2 + 0.14)), 0.06, ROD, FINE)
				end
			end
		end
		return b.model
	end)

	Props.register("truss", function(parent: Instance, cf: CFrame, bPoint: Vector3, depth: number, finish: C.Finish): Model
		local a = cf.Position
		local frame, len = C.runFrame(a, bPoint)
		local dep = C.num(depth, 3, 0.8, 12)
		local b = C.begin(parent, "Truss", frame, true)
		local chord, web = 0.45, 0.26
		local n = math.max(2, math.floor(len / dep + 0.5))
		local p = len / n
		-- chords: top full length, bottom between the first and last bottom nodes
		b.box(len / 2, -chord / 2, 0, len, chord, chord, finish, { Collide = false, Shadow = true })
		b.box(len / 2, -dep + chord / 2, 0, len - p, chord, chord, finish, { Collide = false, Shadow = true })
		-- Warren web: top(0) -> bottom(p/2) -> top(p) -> ...
		local yt, yb = -chord / 2, -dep + chord / 2
		for i = 0, n - 1 do
			local x0 = i * p
			b.span(Vector3.new(x0, yt, 0), Vector3.new(x0 + p / 2, yb, 0), web, finish, DETAIL, true)
			b.span(Vector3.new(x0 + p / 2, yb, 0), Vector3.new(x0 + p, yt, 0), web, finish, DETAIL, true)
		end
		-- end verticals + bearing plates
		for _, x in { 0.15, len - 0.15 } do
			b.box(x, -dep / 2 + 0.15, 0, 0.3, dep - 0.3, 0.3, finish, FINE)
			b.box(x, -0.03, 0, 0.6, 0.06, 0.8, finish, FINE)
		end
		return b.model
	end)

	Props.register("column", function(parent: Instance, cf: CFrame, height: number, kind: string): Model
		local H = C.num(height, 12, 1, 200)
		local k = if type(kind) == "string" then kind else "Concrete"
		local b = C.begin(parent, "Column_" .. k, cf)
		if k == "Steel" then
			-- wide-flange H section on a bolted base plate
			local steel = F.SteelDark
			for _, sz in { -1, 1 } do
				b.box(0, H / 2, sz * 1.1, 2.4, H, 0.2, steel, SOLID)
			end
			b.box(0, H / 2, 0, 0.2, H, 2.0, steel, SOLID)
			b.box(0, 0.06, 0, 2.9, 0.12, 2.9, steel, DETAIL)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					b.cylY(sx * 1.2, 0.17, sz * 1.2, 0.1, 0.18, F.SteelBrushed, FINE)
				end
			end
			-- safety-yellow impact guard at the base
			b.box(0, 1.6, 0, 2.7, 3.2, 2.7, C.tint("PowderYellow", C.rgb(224, 165, 38)), SOLID)
			b.box(0, 3.25, 0, 2.74, 0.1, 2.74, C.tint("PlasticBlack", C.rgb(26, 26, 28)), FINE)
		elseif k == "Clad" then
			b.box(0, H / 2, 0, 2.4, H, 2.4, F.WalnutPlanks, SOLID)
			b.box(0, 0.2, 0, 2.56, 0.4, 2.56, C.tint("MarbleDark", C.rgb(40, 40, 42)), DETAIL)
			for _, y in { 3.2, H - 0.6 } do
				if y > 0.8 and y < H - 0.2 then
					b.box(0, y, 0, 2.46, 0.08, 2.46, F.Brass, FINE)
				end
			end
		elseif k == "Round" then
			b.cylY(0, H / 2, 0, H, 2.4, F.Plaster, SOLID)
			b.cylY(0, 0.2, 0, 0.4, 2.62, F.ConcreteWarm, DETAIL)
			b.cylY(0, H - 0.15, 0, 0.3, 2.6, F.Plaster, DETAIL)
		else
			-- board-formed concrete with a rubber kick band and steel corner guards
			b.box(0, H / 2, 0, 2.4, H, 2.4, F.Concrete, SOLID)
			b.box(0, 0.25, 0, 2.5, 0.5, 2.5, F.RubberFloor, DETAIL)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					b.box(sx * 1.2, 2.5, sz * 1.2, 0.14, 4, 0.14, F.SteelBrushed, FINE)
				end
			end
		end
		return b.model
	end)

	Props.register("fan", function(parent: Instance, cf: CFrame, kind: string): Model
		local k = if type(kind) == "string" then kind else "Standing"
		local b = C.begin(parent, "Fan_" .. k, cf)
		if k == "Ceiling" then
			-- 5-blade industrial ceiling fan hanging from cf
			b.cylY(0, -0.1, 0, 0.2, 0.6, F.PowderBlack, FINE)
			b.span(Vector3.new(0, -0.2, 0), Vector3.new(0, -1.5, 0), 0.14, F.PowderBlack, FINE)
			b.cylY(0, -1.75, 0, 0.5, 1.1, F.PowderBlack, FINE)
			for i = 0, 4 do
				b.part(L(0, -1.75, 0, 0, i * 72, 0) * CFrame.new(0, 0, -2.2) * CFrame.Angles(0, 0, math.rad(10)), Vector3.new(0.6, 0.06, 3.3), F.SteelBrushed, FINE)
			end
		elseif k == "Wall" then
			b.box(0, 0, 0.04, 0.5, 0.7, 0.08, F.PowderBlack, FINE)
			b.span(Vector3.new(0, 0, 0.08), Vector3.new(0, -0.3, 0.7), 0.12, F.PowderBlack, FINE)
			fanHead(b, L(0, -0.4, 1.3, -15, 0, 0), 2.0)
		else
			-- pedestal fan
			b.cylY(0, 0.06, 0, 0.12, 1.6, F.PowderBlack, DETAIL)
			b.cylY(0, 2.0, 0, 3.8, 0.16, F.SteelBrushed, FINE)
			fanHead(b, L(0, 4.2, 0.2, -6, 0, 0), 2.0)
		end
		return b.model
	end)
end
