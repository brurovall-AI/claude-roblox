--!strict
--[[
	Ultimate-only stations (Apex Lab): GravPress, HydroRower, HyperTreadmill,
	ReflexWall, CryoPod.

	Language: white composite shells, carbon, titanium, smoked glass, thin cyan
	light lines and genuinely floating elements (consistent shadow gaps with a
	light line beneath, never random hovering). Built for any tier but styled
	from the tier's finishes, so they still read if placed at a lower tier.
	Local frame: x right, y up, z FORWARD (the trainee's facing).
]]

local Kit = require("../../Kit")
local S = require("./Shared")

local F = S.F
local DETAIL, SOLID = S.DETAIL, S.SOLID

local function rotY(deg: number): CFrame
	return CFrame.Angles(0, math.rad(deg), 0)
end

local function lightF(c: S.Ctx): S.Finish
	return c.st.Light or F.LightCyan
end

-- Floating round platform: dark recessed base, light ring in the shadow gap,
-- carbon slab, composite top. Returns the top height.
local function disc(c: S.Ctx, parent: Instance, cf: CFrame, d: number): number
	Kit.cylY(parent, cf * CFrame.new(0, 0.07, 0), 0.14, d - 0.7, F.PlasticBlack, SOLID)
	Kit.cylY(parent, cf * CFrame.new(0, 0.16, 0), 0.04, d - 0.5, lightF(c), DETAIL)
	Kit.cylY(parent, cf * CFrame.new(0, 0.3, 0), 0.24, d, F.Carbon, SOLID)
	Kit.cylY(parent, cf * CFrame.new(0, 0.425, 0), 0.02, d - 0.25, F.Composite, DETAIL)
	Kit.cylY(parent, cf * CFrame.new(0, 0.437, 0), 0.01, d - 0.6, F.Carbon, DETAIL)
	return 0.44
end

-- Ring of n box segments in the XZ plane (cf = centre). Thin/flat by default.
local function ring(parent: Instance, cf: CFrame, r: number, n: number, w: number, h: number, f: Kit.FinishArg)
	local chord = 2 * r * math.sin(math.pi / n) + 0.02
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		Kit.box(parent, cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r), Vector3.new(chord, h, w), f, DETAIL)
	end
end

-- Arc of segments in the station's XY plane (an arch / portal), centre cf.
local function arch(parent: Instance, cf: CFrame, r: number, n: number, w: number, d: number, f: Kit.FinishArg, opts: Kit.Opts)
	local chord = 2 * r * math.sin(math.pi / (2 * n)) + 0.03
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi -- 0..pi from right to left
		local p = cf * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0)
		Kit.box(parent, p * CFrame.Angles(0, 0, a + math.pi / 2), Vector3.new(chord, w, d), f, opts)
	end
end

---------------------------------------------------------------------------
-- GravPress: twin composite pylons project a floating bar with energy discs.
---------------------------------------------------------------------------
local function gravPress(c: S.Ctx)
	local m, st = c.model, c.st
	local at, pt = c.at, c.pt
	local top = disc(c, m, at(0, 0, 0), 7.6)
	local yBar, zBar = top + 4.4, 0.55
	local xP = 3.7
	local H = top + 8.2
	for _, sx in { -1, 1 } do
		local x = sx * xP
		-- pylon: wide lower plinth, tall shell, carbon inner face, light seam
		Kit.box(m, at(x, top + 0.6, zBar), Vector3.new(1.3, 1.2, 1.7), F.Composite, SOLID)
		Kit.box(m, at(x, (top + 1.2 + H) / 2, zBar), Vector3.new(0.9, H - top - 1.2, 1.3), F.Composite, SOLID)
		Kit.box(m, at(x - sx * 0.46, (top + 1.4 + H - 0.3) / 2, zBar), Vector3.new(0.04, H - top - 1.7, 0.9), F.Carbon, DETAIL)
		S.glow(c, m, pt(x - sx * 0.49, yBar - 0.4, zBar), pt(x - sx * 0.49, yBar + 3.4, zBar), 0.06)
		Kit.box(m, at(x, top + 1.22, zBar), Vector3.new(1.32, 0.04, 1.72), lightF(c), DETAIL)
		-- floating cap
		Kit.box(m, at(x, H + 0.28, zBar), Vector3.new(1.0, 0.36, 1.4), F.Carbon, DETAIL)
		Kit.box(m, at(x, H + 0.08, zBar), Vector3.new(0.7, 0.04, 1.0), lightF(c), DETAIL)
		-- emitter facing the bar
		local em = at(x - sx * 0.5, yBar, zBar)
		Kit.cyl(m, em, 0.14, 1.3, F.Titanium, DETAIL)
		Kit.cyl(m, em * CFrame.new(-sx * 0.05, 0, 0), 0.06, 0.9, lightF(c), DETAIL)
		Kit.cyl(m, em * CFrame.new(-sx * 0.08, 0, 0), 0.04, 0.5, F.Carbon, DETAIL)
		-- titanium trim strips on the outer face
		Kit.box(m, at(x + sx * 0.46, (top + H) / 2 + 0.6, zBar), Vector3.new(0.02, H - top - 2.4, 0.12), F.Titanium, DETAIL)
	end
	-- floating crossbeam + halo above the lifter
	Kit.box(m, at(0, H + 0.9, zBar), Vector3.new(xP * 2 + 0.6, 0.3, 0.6), F.Composite, SOLID)
	S.glow(c, m, pt(-xP + 0.5, H + 0.73, zBar), pt(xP - 0.5, H + 0.73, zBar), 0.05)
	ring(m, at(0, H - 0.4, 0), 1.6, 14, 0.12, 0.06, F.Titanium)
	ring(m, at(0, H - 0.46, 0), 1.6, 14, 0.04, 0.03, lightF(c))
	-- floating bar (Mover): titanium shaft, carbon grips, composite energy discs
	local mover = c.E.mover(m, Vector3.new(0, 3.0, 0))
	local bar = at(0, yBar, zBar)
	Kit.cyl(mover, bar, 5.6, 0.18, F.Titanium, DETAIL)
	for _, sx in { -1, 1 } do
		Kit.cyl(mover, bar * CFrame.new(sx * 0.95, 0, 0), 0.9, 0.22, F.Carbon, DETAIL)
		Kit.cyl(mover, bar * CFrame.new(sx * 2.15, 0, 0), 0.08, 0.36, lightF(c), DETAIL)
		S.plate(c, mover, bar * CFrame.new(sx * 2.45, 0, 0), 1.9, 0.28, 1)
		S.plate(c, mover, bar * CFrame.new(sx * 2.78, 0, 0), 1.5, 0.22, 2)
	end
	S.placard(c, m, at(0, top - 0.12, 3.82), 1.4, S.NAMES.GravPress)
	c.E.standingSpot(m, at(0, top, 0))
	local _ = st
end

---------------------------------------------------------------------------
-- HydroRower: sculpted composite monorail, see-through water drum with a
-- paddle Spinner, floating seat Mover, holographic console.
---------------------------------------------------------------------------
local function hydroRower(c: S.Ctx)
	local m = c.model
	local at, pt = c.at, c.pt
	local base = S.plinth(c, m, at(0, 0, -0.6), 4.4, 11.4)
	local Sy = base + 1.5
	local railTop = Sy - 0.42
	local z0, z1 = -5.0, 2.5
	-- floating rail on two carbon pylons with light underglow
	Kit.box(m, at(0, railTop - 0.2, (z0 + z1) / 2), Vector3.new(0.9, 0.4, z1 - z0), F.Composite, SOLID)
	Kit.box(m, at(0, railTop + 0.005, (z0 + z1) / 2), Vector3.new(0.3, 0.02, z1 - z0 - 0.6), F.Carbon, DETAIL)
	for _, sx in { -1, 1 } do
		Kit.box(m, at(sx * 0.455, railTop - 0.2, (z0 + z1) / 2), Vector3.new(0.02, 0.05, z1 - z0 - 0.4), lightF(c), DETAIL)
	end
	for _, z in { z0 + 0.6, -0.9 } do
		Kit.box(m, at(0, (base + railTop - 0.5) / 2, z), Vector3.new(0.5, railTop - 0.5 - base, 0.5), F.Carbon, SOLID)
		Kit.box(m, at(0, base + 0.05, z), Vector3.new(1.6, 0.1, 0.7), F.Carbon, SOLID)
		Kit.box(m, at(0, base + 0.11, z), Vector3.new(1.3, 0.02, 0.45), lightF(c), DETAIL)
	end
	-- front body + water drum
	local dz, dy, dd = 3.7, base + 1.9, 2.7
	Kit.box(m, at(0, base + 0.9, dz), Vector3.new(1.1, 1.8, 1.6), F.Composite, SOLID)
	Kit.box(m, at(0, base + 0.05, dz), Vector3.new(2.6, 0.1, 1.4), F.Carbon, SOLID)
	S.bar(c, m, pt(0, railTop - 0.2, z1 - 0.2), pt(0, base + 1.4, dz - 0.7), 0.7, 0.4, F.Composite, SOLID)
	Kit.cyl(m, at(0, dy, dz), 1.0, dd, F.Water, DETAIL)
	for _, sx in { -1, 1 } do
		Kit.cyl(m, at(sx * 0.53, dy, dz), 0.08, dd + 0.2, F.Composite, SOLID)
		Kit.cyl(m, at(sx * 0.58, dy, dz), 0.03, dd - 0.3, lightF(c), DETAIL)
		Kit.cyl(m, at(sx * 0.6, dy, dz), 0.04, dd - 0.6, F.Titanium, DETAIL)
	end
	local spin = c.E.spinner(m, at(0, dy, dz), 10)
	Kit.cyl(spin, at(0, dy, dz), 0.96, 0.36, F.Titanium, DETAIL)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		Kit.box(spin, at(0, dy, dz) * CFrame.Angles(a, 0, 0) * CFrame.new(0, dd * 0.27, 0), Vector3.new(0.8, dd * 0.42, 0.06), F.Composite, DETAIL)
	end
	-- footplates
	for _, sx in { -1, 1 } do
		local cf = at(sx * 0.45, base + 0.95, 2.05) * CFrame.Angles(math.rad(50), 0, 0)
		Kit.box(m, cf, Vector3.new(0.62, 0.1, 1.05), F.Carbon, DETAIL)
		Kit.box(m, cf * CFrame.new(0, 0.07, 0.05), Vector3.new(0.64, 0.04, 0.05), lightF(c), DETAIL)
	end
	-- handle in its cradle
	local hy, hz = dy - 0.1, dz - 1.55
	Kit.cyl(m, at(0, hy, hz), 1.7, 0.18, F.Titanium, DETAIL)
	for _, sx in { -1, 1 } do
		Kit.cyl(m, at(sx * 0.6, hy, hz), 0.5, 0.24, F.Carbon, DETAIL)
	end
	S.cable(m, pt(0, hy, hz), pt(0, dy - 0.3, dz - dd / 2 + 0.2), 0.05)
	-- holo console on a slim titanium arm
	S.rod(c, m, pt(0, dy + dd / 2, dz - 0.2), pt(0, base + 3.9, dz - 1.0), 0.1, F.Titanium)
	local con = at(0, base + 4.1, dz - 1.05) * CFrame.Angles(math.rad(15), 0, 0)
	Kit.box(m, con, Vector3.new(1.2, 0.8, 0.04), F.GlassSmoked, DETAIL)
	Kit.box(m, con * CFrame.new(0, -0.42, 0), Vector3.new(1.2, 0.03, 0.05), lightF(c), DETAIL)
	-- seat (Mover)
	local mover = c.E.mover(m, -c.cf.LookVector * 2.2)
	Kit.box(mover, at(0, railTop + 0.16, 0), Vector3.new(0.9, 0.18, 0.9), F.Carbon, DETAIL)
	Kit.box(mover, at(0, railTop + 0.06, 0), Vector3.new(0.7, 0.03, 0.7), lightF(c), DETAIL)
	S.pad(c, mover, at(0, Sy - 0.12, 0), Vector3.new(1.25, 0.24, 1.1), true)
	Kit.box(mover, at(0, Sy - 0.26, 0), Vector3.new(1.3, 0.06, 1.15), F.Composite, DETAIL)
	S.placard(c, m, at(0.56, base + 0.9, dz) * rotY(-90), 0.9, S.NAMES.HydroRower)
	c.E.userSpot(m, at(0, Sy + 1.3, 0))
end

---------------------------------------------------------------------------
-- HyperTreadmill: floating deck under a composite portal arch with a
-- holographic display; rear roller = Spinner.
---------------------------------------------------------------------------
local function hyperTreadmill(c: S.Ctx)
	local m = c.model
	local at, pt = c.at, c.pt
	local base = S.plinth(c, m, at(0, 0, 0), 5.6, 9.6)
	local dw, dl = 3.2, 7.6
	local zc = -0.4
	local deckTop = base + 1.0
	-- recessed carbon core + light line in the shadow gap
	Kit.box(m, at(0, base + 0.3, zc), Vector3.new(dw - 0.8, 0.6, dl - 0.8), F.PlasticBlack, SOLID)
	Kit.box(m, at(0, base + 0.62, zc), Vector3.new(dw - 0.5, 0.04, dl - 0.5), lightF(c), DETAIL)
	-- floating deck: composite shell, carbon belt, titanium edge strips
	Kit.box(m, at(0, deckTop - 0.18, zc), Vector3.new(dw, 0.36, dl), F.Composite, SOLID)
	Kit.box(m, at(0, deckTop + 0.01, zc - 0.1), Vector3.new(2.1, 0.02, dl - 0.5), F.Carbon, DETAIL)
	for _, sx in { -1, 1 } do
		Kit.box(m, at(sx * 1.08, deckTop + 0.012, zc), Vector3.new(0.04, 0.02, dl - 0.4), lightF(c), DETAIL)
		Kit.box(m, at(sx * (dw / 2 + 0.01), deckTop - 0.18, zc), Vector3.new(0.02, 0.08, dl - 0.6), F.Titanium, DETAIL)
	end
	local rCf = at(0, deckTop - 0.18, zc - dl / 2 + 0.2)
	local sp = c.E.spinner(m, rCf, 20)
	Kit.cyl(sp, rCf, 2.1, 0.32, F.Titanium, DETAIL)
	Kit.box(sp, rCf * CFrame.new(0, 0.15, 0), Vector3.new(2.0, 0.04, 0.06), lightF(c), DETAIL)
	-- portal arch at the front of the deck
	local az = zc + dl / 2 - 0.9
	local r = 3.45
	local archCf = at(0, deckTop - 0.2, az)
	arch(m, archCf, r, 9, 0.5, 0.7, F.Composite, SOLID)
	arch(m, archCf * CFrame.new(0, 0, -0.36), r - 0.27, 9, 0.04, 0.03, lightF(c), DETAIL)
	arch(m, archCf * CFrame.new(0, 0, 0.36), r + 0.05, 9, 0.12, 0.02, F.Carbon, DETAIL)
	-- floating holographic display inside the arch, angled at the runner
	local disp = at(0, deckTop + 2.05, az - 0.1) * CFrame.Angles(math.rad(28), 0, 0)
	Kit.box(m, disp, Vector3.new(2.6, 1.3, 0.04), F.GlassSmoked, DETAIL)
	for _, dy in { -0.67, 0.67 } do
		Kit.box(m, disp * CFrame.new(0, dy, 0), Vector3.new(2.6, 0.03, 0.05), lightF(c), DETAIL)
	end
	Kit.box(m, disp * CFrame.new(0, 0, 0.03), Vector3.new(1.6, 0.06, 0.02), F.LightCool, DETAIL)
	-- sensor fins beside the deck front
	for _, sx in { -1, 1 } do
		local fin = at(sx * (dw / 2 + 0.35), deckTop + 1.4, az - 1.2)
		Kit.box(m, fin, Vector3.new(0.12, 2.6, 0.9), F.Composite, SOLID)
		S.glow(c, m, (fin * CFrame.new(-sx * 0.07, -1.1, 0)).Position, (fin * CFrame.new(-sx * 0.07, 1.1, 0)).Position, 0.04)
		Kit.box(m, fin * CFrame.new(0, 1.35, 0), Vector3.new(0.16, 0.1, 0.94), F.Titanium, DETAIL)
		S.bar(c, m, (fin * CFrame.new(0, -1.3, 0)).Position, pt(sx * (dw / 2), deckTop - 0.1, az - 1.2), 0.12, 0.3, F.Carbon, DETAIL)
	end
	S.placard(c, m, at(0, deckTop - 0.18, zc - dl / 2 - 0.02) * rotY(180), 1.2, S.NAMES.HyperTreadmill)
	c.E.userSpot(m, at(0, deckTop + 3.0, zc - 0.6))
end

---------------------------------------------------------------------------
-- ReflexWall: curved three-panel wall of light targets, floating wings.
---------------------------------------------------------------------------
local function reflexWall(c: S.Ctx)
	local m = c.model
	local at = c.at
	local base = S.plinth(c, m, at(0, 0, 1.0), 9.8, 4.4)
	local zW = 2.3
	local ph, pw = 7.2, 3.2
	local function panel(cf: CFrame, cols: number, rows: number)
		Kit.box(m, cf * CFrame.new(0, ph / 2, 0), Vector3.new(pw, ph, 0.4), F.Composite, SOLID)
		Kit.box(m, cf * CFrame.new(0, ph / 2, 0.22), Vector3.new(pw - 0.1, ph - 0.1, 0.04), F.Carbon, DETAIL)
		Kit.box(m, cf * CFrame.new(0, ph + 0.05, 0), Vector3.new(pw + 0.02, 0.06, 0.42), F.Titanium, DETAIL)
		-- target pads facing the trainee (panel LookVector)
		for ix = 1, cols do
			for iy = 1, rows do
				local x = (ix - (cols + 1) / 2) * 0.95
				local y = 1.3 + (iy - 1) * 1.45
				local tcf = cf * CFrame.new(x, y, -0.2)
				Kit.cylZ(m, tcf, 0.1, 0.62, F.Carbon, DETAIL)
				Kit.cylZ(m, tcf * CFrame.new(0, 0, -0.04), 0.06, 0.46, if (ix + iy) % 3 == 0 then lightF(c) else F.Titanium, DETAIL)
			end
		end
	end
	-- centre panel + angled wings (wings float on carbon stems)
	panel(at(0, base + 0.15, zW) * rotY(180), 3, 4)
	for _, sx in { -1, 1 } do
		local wing = at(sx * 3.35, base + 0.45, zW - 0.75) * rotY(180 - sx * 28)
		panel(wing, 2, 4)
		Kit.box(m, wing * CFrame.new(0, -0.15, 0), Vector3.new(0.6, 0.3, 0.3), F.Carbon, SOLID)
		Kit.box(m, wing * CFrame.new(0, -0.02, 0), Vector3.new(pw - 0.3, 0.03, 0.3), lightF(c), DETAIL)
	end
	Kit.box(m, at(0, base + 0.08, zW), Vector3.new(pw + 0.1, 0.16, 0.6), F.Carbon, SOLID)
	-- floor stance ring under the trainee
	Kit.cylY(m, at(0, base + 0.01, 0), 0.02, 2.4, lightF(c), DETAIL)
	Kit.cylY(m, at(0, base + 0.02, 0), 0.03, 2.2, F.Carbon, DETAIL)
	S.placard(c, m, at(0, base + 0.75, zW - 0.25) * rotY(180), 1.4, S.NAMES.ReflexWall)
	c.E.standingSpot(m, at(0, base, 0))
end

---------------------------------------------------------------------------
-- CryoPod: upright capsule open to the front, glass doors swung aside,
-- lit interior, control pedestal.
---------------------------------------------------------------------------
local function cryoPod(c: S.Ctx)
	local m = c.model
	local at, pt = c.at, c.pt
	local r = 1.95
	local zc = -0.4
	-- base plinth (round) with light ring
	Kit.cylY(m, at(0, 0.08, zc), 0.16, 4.2, F.PlasticBlack, SOLID)
	Kit.cylY(m, at(0, 0.18, zc), 0.04, 4.4, lightF(c), DETAIL)
	Kit.cylY(m, at(0, 0.42, zc), 0.44, 4.8, F.Composite, SOLID)
	Kit.cylY(m, at(0, 0.645, zc), 0.01, 3.6, F.Carbon, DETAIL)
	local floor = 0.65
	local H = 7.3
	-- shell: segments around the back 230 degrees (open toward the LookVector)
	local n = 12
	local span = math.rad(230)
	local chord = 2 * r * math.sin(span / n / 2) + 0.05
	for i = 0, n - 1 do
		local a = math.pi + (i + 0.5 - n / 2) * span / n -- centred on the back
		local p = at(math.sin(a) * r, floor + H / 2, zc + math.cos(a) * r)
		local seg = p * CFrame.Angles(0, -a, 0) -- front (-Z) faces outward
		Kit.box(m, seg, Vector3.new(chord, H, 0.32), F.Composite, SOLID)
		Kit.box(m, seg * CFrame.new(0, 0, 0.18), Vector3.new(chord, H - 0.4, 0.04), F.Carbon, DETAIL)
	end
	-- interior light spine at the back + soft cool light
	local spine = Kit.box(m, at(0, floor + H / 2, zc - r + 0.25), Vector3.new(0.08, H - 1.2, 0.04), lightF(c), DETAIL)
	Kit.light(spine, "Point", { Color = Color3.fromRGB(170, 236, 244), Brightness = 0.9, Range = 9 })
	-- top cap with halo + carbon underside
	Kit.cylY(m, at(0, floor + H + 0.3, zc), 0.6, 4.6, F.Composite, SOLID)
	Kit.cylY(m, at(0, floor + H - 0.02, zc), 0.04, 4.0, lightF(c), DETAIL)
	Kit.cylY(m, at(0, floor + H + 0.64, zc), 0.08, 3.0, F.Titanium, DETAIL)
	-- glass doors swung open to either side of the opening
	for _, sx in { -1, 1 } do
		local edgeA = math.pi + sx * span / 2
		local hinge = pt(math.sin(edgeA) * r, floor + H / 2, zc + math.cos(edgeA) * r)
		local dir = (c.cf.RightVector * sx * 0.55 + c.cf.LookVector * 0.85).Unit
		for k = 0, 2 do
			local a0 = hinge + dir * (0.45 + k * 0.9)
			local cf = CFrame.lookAt(a0, a0 + dir:Cross(Vector3.new(0, 1, 0)))
			Kit.box(m, cf, Vector3.new(0.9, H - 0.6, 0.08), F.GlassFrosted, DETAIL)
		end
		Kit.box(m, CFrame.lookAt(hinge + dir * 2.75, hinge + dir * 3), Vector3.new(0.12, H - 0.5, 0.12), F.Titanium, DETAIL)
		Kit.box(m, CFrame.new(hinge) * c.cf.Rotation, Vector3.new(0.3, H, 0.3), F.Titanium, SOLID)
	end
	-- control pedestal front-right
	local ped = at(2.55, 0, zc + 1.9)
	Kit.box(m, ped * CFrame.new(0, 0.6, 0), Vector3.new(0.5, 1.2, 0.5), F.Composite, SOLID)
	Kit.box(m, ped * CFrame.new(0, 2.3, 0), Vector3.new(0.3, 2.2, 0.3), F.Composite, SOLID)
	Kit.box(m, ped * CFrame.new(0, 1.22, 0), Vector3.new(0.52, 0.04, 0.52), lightF(c), DETAIL)
	local scr = ped * CFrame.new(0, 3.6, 0) * rotY(-30) * CFrame.Angles(math.rad(-20), 0, 0)
	Kit.box(m, scr, Vector3.new(1.1, 0.75, 0.05), F.GlassSmoked, DETAIL)
	Kit.box(m, scr * CFrame.new(0, -0.39, 0), Vector3.new(1.1, 0.03, 0.06), lightF(c), DETAIL)
	S.placard(c, m, at(0, 0.42, zc + 2.42), 1.3, S.NAMES.CryoPod)
	c.E.userSpot(m, at(0, floor + 3.2, zc - 0.2))
end

return function(E: S.Lib)
	S.station(E, "GravPress", gravPress)
	S.station(E, "HydroRower", hydroRower)
	S.station(E, "HyperTreadmill", hyperTreadmill)
	S.station(E, "ReflexWall", reflexWall)
	S.station(E, "CryoPod", cryoPod)
end
