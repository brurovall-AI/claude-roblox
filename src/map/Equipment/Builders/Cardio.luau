--!strict
--[[
	Cardio & conditioning stations: Rower, Bike, BattleRopes, Treadmill, SledPush.

	Contract notes: rower seat = Mover (travel -LookVector * 2.2); bike flywheel
	+ crank and treadmill rollers / rower fan = Spinner (local X axis); sled =
	Mover (travel LookVector * 1.2).
	Local frame: x right, y up, z FORWARD (the trainee's facing).
]]

local Kit = require("../../Kit")
local S = require("./Shared")

local F = S.F
local DETAIL, SOLID = S.DETAIL, S.SOLID

local function rotY(deg: number): CFrame
	return CFrame.Angles(0, math.rad(deg), 0)
end

-- Spoked wheel (Spinner contents): rim disc + hub + n spokes, axis along cf.RightVector.
local function spokedWheel(parent: Instance, cf: CFrame, d: number, w: number, rimF: Kit.FinishArg, spokeF: Kit.FinishArg, n: number)
	Kit.cyl(parent, cf, w, d, rimF, DETAIL)
	Kit.cyl(parent, cf, w + 0.06, d * 0.22, spokeF, DETAIL)
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		Kit.box(parent, cf * CFrame.Angles(a, 0, 0) * CFrame.new(0, d * 0.3, 0), Vector3.new(w + 0.04, d * 0.36, 0.1), spokeF, DETAIL)
	end
end

-- Console screen panel (cf = screen centre, LookVector toward the user).
local function console(c: S.Ctx, parent: Instance, cf: CFrame, w: number, h: number)
	local t = c.tier
	local body = if t == 1 then F.PowderWhite elseif t == 6 then F.Composite elseif t == 4 then F.PowderGraphite else F.PlasticBlack
	Kit.box(parent, cf * CFrame.new(0, 0, 0.06), Vector3.new(w, h, 0.18), body, DETAIL)
	Kit.box(parent, cf * CFrame.new(0, 0.04, -0.035), Vector3.new(w * 0.8, h * 0.66, 0.02), if t == 1 then F.ScreenLit else S.SCREEN, DETAIL)
	if t == 1 then
		for i = -1, 1 do
			Kit.cylZ(parent, cf * CFrame.new(i * w * 0.25, -h * 0.38, -0.04), 0.04, 0.16, if i == 0 then F.PlasticCoral else F.PlasticTeal, DETAIL)
		end
	elseif t >= 3 then
		local trim = if t == 3 then F.PowderRed elseif t == 4 then F.Brass elseif t == 5 then F.Gold else (c.st.Light or F.LightCyan)
		Kit.box(parent, cf * CFrame.new(0, -h / 2 + 0.03, -0.03), Vector3.new(w * 0.9, 0.03, 0.02), trim, DETAIL)
	end
end

---------------------------------------------------------------------------
-- Rower: air/flywheel rower. T2-3 aluminium monorail; T4 oak twin rails;
-- T5 walnut twin rails + black chrome; seat carriage = Mover.
---------------------------------------------------------------------------
local function rower(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local h0 = S.plinth(c, m, at(0, 0, -0.8), 3.6, 10.6)
	local Sy = h0 + 1.45
	local railTop = Sy - 0.45
	local z0, z1 = -5.0, 2.7
	local twin = t >= 4
	local railF = if t == 4 then F.OakSolid elseif t == 5 then F.Walnut elseif t == 6 then F.Composite else F.SteelBrushed
	-- rails
	if twin then
		for _, sx in { -1, 1 } do
			Kit.box(m, at(sx * 0.42, railTop - 0.22, (z0 + z1) / 2), Vector3.new(0.28, 0.44, z1 - z0), railF, SOLID)
			if t == 5 then
				Kit.box(m, at(sx * 0.565, railTop - 0.22, (z0 + z1) / 2), Vector3.new(0.02, 0.06, z1 - z0 - 0.2), F.Gold, DETAIL)
			end
		end
		Kit.box(m, at(0, railTop - 0.4, z0 + 0.3), Vector3.new(1.2, 0.08, 0.5), railF, DETAIL)
	else
		Kit.box(m, at(0, railTop - 0.16, (z0 + z1) / 2), Vector3.new(0.5, 0.32, z1 - z0), railF, SOLID)
		Kit.box(m, at(0, railTop + 0.005, (z0 + z1) / 2), Vector3.new(0.18, 0.02, z1 - z0 - 0.4), F.SteelDark, DETAIL)
	end
	-- rear leg + foot
	S.tube(c, m, pt(0, h0, z0 + 0.3), pt(0, railTop - 0.3, z0 + 0.3), 0.3, st.Frame)
	S.tube(c, m, pt(-0.9, h0 + 0.12, z0 + 0.3), pt(0.9, h0 + 0.12, z0 + 0.3), 0.24, st.Frame)
	for _, sx in { -1, 1 } do
		S.foot(c, m, at(sx * 0.9, h0, z0 + 0.3), 0.4, 0.4)
	end
	-- front body: frame from the rail up to the flywheel, front stabiliser
	local fz, fy = 3.45, h0 + 2.0
	local fd = 2.0
	S.tube(c, m, pt(0, railTop - 0.2, z1 - 0.1), pt(0, fy - 0.4, fz - 0.4), 0.42, st.Frame)
	S.tube(c, m, pt(0, h0, fz + 0.6), pt(0, fy - 0.5, fz), 0.36, st.Frame)
	S.tube(c, m, pt(-1.0, h0 + 0.12, fz + 0.6), pt(1.0, h0 + 0.12, fz + 0.6), 0.26, st.Frame)
	for _, sx in { -1, 1 } do
		S.foot(c, m, at(sx * 1.0, h0, fz + 0.6), 0.4, 0.4)
	end
	-- flywheel cage: side discs + see-through drum; fan inside spins
	local cageF = if t == 4 then F.OakSolid elseif t == 5 then F.BlackChrome elseif t == 6 then F.Composite else st.Frame
	for _, sx in { -1, 1 } do
		Kit.cyl(m, at(sx * 0.5, fy, fz), 0.08, fd + 0.1, cageF, SOLID)
		local ringF = if t == 3 then F.PowderRed elseif t == 4 then F.Brass elseif t == 5 then F.Gold elseif t == 6 then (st.Light or F.LightCyan) else F.SteelDark
		Kit.cyl(m, at(sx * 0.55, fy, fz), 0.03, fd * 0.45, ringF, DETAIL)
	end
	Kit.cyl(m, at(0, fy, fz), 0.92, fd, F.GlassSmoked, DETAIL)
	local spin = c.E.spinner(m, at(0, fy, fz), 12)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		Kit.box(spin, at(0, fy, fz) * CFrame.Angles(a, 0, 0) * CFrame.new(0, fd * 0.26, 0), Vector3.new(0.78, fd * 0.44, 0.05), if t >= 4 then st.Metal else F.SteelDark, DETAIL)
	end
	Kit.cyl(spin, at(0, fy, fz), 0.84, 0.3, st.Metal, DETAIL)
	-- footrests (angled) with straps
	local fr = 1.95
	for _, sx in { -1, 1 } do
		local cf = at(sx * 0.42, h0 + 0.82, fr) * CFrame.Angles(math.rad(50), 0, 0)
		Kit.box(m, cf, Vector3.new(0.62, 0.1, 1.05), if t == 1 then F.PlasticTeal else F.PlasticBlack, DETAIL)
		Kit.box(m, cf * CFrame.new(0, 0.1, 0.05), Vector3.new(0.64, 0.06, 0.2), if t == 4 then F.LeatherTan elseif t == 5 then F.LeatherBlack else F.RubberGrip, DETAIL)
	end
	Kit.box(m, at(0, h0 + 0.62, fr + 0.2), Vector3.new(1.3, 0.16, 0.5), st.Frame, DETAIL)
	-- handle resting in its holder + chain into the cage
	local hy, hz = fy - 0.05, fz - 1.15
	Kit.cyl(m, at(0, hy, hz), 1.7, 0.2, if t == 4 then F.OakSolid elseif t == 5 then F.Walnut else st.Grip, DETAIL)
	Kit.box(m, at(0, hy, hz + 0.02), Vector3.new(0.22, 0.22, 0.22), st.Metal, DETAIL)
	S.cable(m, pt(0, hy, hz), pt(0, fy - 0.2, fz - fd / 2 + 0.1), 0.06)
	-- monitor arm (T3+)
	if t >= 3 then
		S.tube(c, m, pt(0, fy + fd / 2, fz - 0.2), pt(0, h0 + 3.6, fz - 0.9), 0.18, st.Frame, false)
		console(c, m, at(0, h0 + 3.75, fz - 1.0) * rotY(180) * CFrame.Angles(math.rad(-15), 0, 0) * rotY(180), 0.95, 0.8)
	end
	-- seat carriage (Mover)
	local mover = c.E.mover(m, -c.cf.LookVector * 2.2)
	local seatZ = 0.0
	Kit.box(mover, at(0, railTop + 0.14, seatZ), Vector3.new(if twin then 1.0 else 0.62, 0.22, 0.9), st.Frame, DETAIL)
	for _, dz in { -0.32, 0.32 } do
		Kit.cyl(mover, at(0, railTop + 0.08, seatZ + dz), if twin then 1.08 else 0.7, 0.16, F.PlasticBlack, DETAIL)
	end
	S.pad(c, mover, at(0, Sy - 0.13, seatZ), Vector3.new(1.25, 0.26, 1.15), true)
	-- end stops + placard
	Kit.box(m, at(0, railTop + 0.12, z0 + 0.1), Vector3.new(0.6, 0.24, 0.2), F.Rubber, DETAIL)
	S.placard(c, m, at(0.55, fy, fz) * rotY(-90), 0.9, S.NAMES.Rower)
	c.E.userSpot(m, at(0, Sy + 1.3, seatZ))
end

---------------------------------------------------------------------------
-- Bike: spin / upright bike. Flywheel and crank are Spinners.
---------------------------------------------------------------------------
local function bike(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local h0 = S.plinth(c, m, at(0, 0, 0.2), 3.2, 5.0)
	local Sy = h0 + 2.5
	local zSeat = -0.85
	local crank = pt(0, h0 + 1.25, 0.2)
	local crankY, crankZ = h0 + 1.25, 0.2
	local fwY, fwZ, fwD = h0 + 1.45, 1.55, 1.7
	local barY, barZ = h0 + 3.75, 1.25
	local frameF = if t == 4 then F.OakSolid else st.Frame
	local tube = if t == 1 then 0.42 elseif t == 4 then 0.4 else 0.34

	-- base: front + rear stabilisers and a spine
	S.tube(c, m, pt(0, h0 + 0.18, -1.7), pt(0, h0 + 0.18, 2.1), 0.3, st.Frame)
	for _, z in { -1.7, 2.1 } do
		S.tube(c, m, pt(-1.1, h0 + 0.15, z), pt(1.1, h0 + 0.15, z), 0.3, st.Frame)
		for _, sx in { -1, 1 } do
			S.foot(c, m, at(sx * 1.1, h0, z), 0.36, 0.36)
		end
	end
	-- seat tube (rear), down tube (front), top tube
	local seatBase = pt(0, h0 + 0.3, -0.35)
	local seatTop = pt(0, Sy - 0.7, zSeat)
	S.tube(c, m, seatBase, seatTop, tube, frameF)
	local head = pt(0, h0 + 3.05, 1.05)
	S.tube(c, m, pt(0, h0 + 0.3, 1.9), head, tube, frameF)
	S.tube(c, m, pt(0, h0 + 1.7, -0.55), pt(0, h0 + 2.55, 1.0), tube * 0.9, frameF)
	S.tube(c, m, pt(0, h0 + 0.3, -0.35), pt(0, crankY, crankZ), tube * 0.9, frameF)
	-- seat post + saddle
	S.tube(c, m, seatTop, pt(0, Sy - 0.2, zSeat), 0.16, st.Metal, false)
	S.knob(c, m, at(0, Sy - 0.9, zSeat - 0.2) * rotY(180))
	if t == 1 then
		-- wide comfort saddle
		S.pad(c, m, at(0, Sy - 0.14, zSeat), Vector3.new(1.4, 0.3, 1.1), true)
	else
		S.pad(c, m, at(0, Sy - 0.12, zSeat - 0.1), Vector3.new(1.05, 0.24, 0.8), true)
		S.pad(c, m, at(0, Sy - 0.13, zSeat + 0.45), Vector3.new(0.42, 0.22, 0.6), true)
	end
	-- handlebar stem + bars
	S.tube(c, m, head, pt(0, barY - 0.15, barZ), 0.18, st.Metal, false)
	local gripF = if t == 4 then F.LeatherTan elseif t == 5 then F.LeatherBlack else st.Grip
	S.rod(c, m, pt(-0.85, barY, barZ), pt(0.85, barY, barZ), 0.16, st.Metal)
	for _, sx in { -1, 1 } do
		S.rod(c, m, pt(sx * 0.85, barY, barZ), pt(sx * 0.7, barY + 0.1, barZ + 0.75), 0.16, st.Metal)
		Kit.span(m, pt(sx * 0.82, barY + 0.02, barZ + 0.15), pt(sx * 0.72, barY + 0.09, barZ + 0.7), 0.22, gripF, DETAIL)
	end
	-- console on the bars
	if t >= 2 then
		console(c, m, at(0, barY + 0.35, barZ + 0.2) * rotY(180) * CFrame.Angles(math.rad(-25), 0, 0) * rotY(180), 0.7, 0.5)
	end
	-- flywheel (Spinner) + guard
	local fwCf = at(0, fwY, fwZ)
	local spin = c.E.spinner(m, fwCf, 14)
	local rimF = if t == 2 then F.Chrome elseif t == 3 then F.Chrome elseif t == 4 then F.Brass elseif t == 5 then F.Gold elseif t == 6 then F.Titanium else F.PlasticTeal
	spokedWheel(spin, fwCf, fwD, 0.24, rimF, if t == 1 then F.PowderWhite else F.SteelDark, 5)
	for _, sx in { -1, 1 } do
		if t == 1 then
			Kit.cyl(m, fwCf * CFrame.new(sx * 0.2, 0, 0), 0.08, fwD + 0.2, F.PowderWhite, SOLID)
			Kit.cyl(m, fwCf * CFrame.new(sx * 0.25, 0, 0), 0.03, fwD * 0.5, F.PlasticCoral, DETAIL)
		else
			Kit.box(m, fwCf * CFrame.new(sx * 0.2, 0.25, -0.25) * CFrame.Angles(math.rad(-45), 0, 0), Vector3.new(0.06, fwD * 0.35, fwD * 0.9), st.FrameAccent, DETAIL)
		end
		S.tube(c, m, pt(sx * 0.24, h0 + 0.3, 1.9), pt(sx * 0.24, fwY, fwZ), 0.18, frameF, false)
	end
	-- brake / resistance knob
	S.knob(c, m, at(0, h0 + 2.65, 1.25) * CFrame.Angles(math.rad(-90), 0, 0))
	-- crank (Spinner): arms + pedals
	local crankCf = CFrame.new(crank) * c.cf.Rotation
	local cs = c.E.spinner(m, crankCf, 8)
	Kit.cyl(cs, crankCf, 0.5, 0.5, st.Metal, DETAIL)
	for _, sx in { -1, 1 } do
		local sgn = sx
		Kit.box(cs, crankCf * CFrame.new(sx * 0.32, sgn * 0.3, 0), Vector3.new(0.1, 0.7, 0.16), F.SteelDark, DETAIL)
		Kit.box(cs, crankCf * CFrame.new(sx * 0.58, sgn * 0.6, 0), Vector3.new(0.42, 0.1, 0.32), F.PlasticBlack, DETAIL)
	end
	-- belt guard between crank and flywheel
	S.bar(c, m, crank + c.cf.RightVector * 0.3, pt(0.3, fwY, fwZ), 0.12, 0.42, st.FrameAccent, DETAIL)
	-- bottle holder (T2+)
	if t >= 2 then
		Kit.cylY(m, at(0, h0 + 2.55, 0.85), 0.55, 0.3, if t == 3 then F.PowderRed else F.PlasticBlack, DETAIL)
	end
	if t >= 3 then
		S.placard(c, m, at(0.22, h0 + 2.2, 1.45) * rotY(-90) * CFrame.Angles(0, 0, math.rad(-36)), 0.8, S.NAMES.Bike)
	end
	if t == 4 then
		-- brass collar where oak meets steel
		S.band(c, m, seatTop, tube)
		S.band(c, m, head, tube)
	end
	c.E.userSpot(m, at(0, Sy + 1.3, zSeat))
end

---------------------------------------------------------------------------
-- BattleRopes: anchor at the far end of a lane, rope halves snaking back.
---------------------------------------------------------------------------
local function battleRopes(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local L, W = 19.2, 4.6
	local h0 = S.plinth(c, m, at(0, 0, 0), W + 0.6, L + 0.6)
	local laneF = if t == 2 then F.RubberFloor elseif t == 5 then F.TurfDark else F.Turf
	Kit.box(m, at(0, h0 + 0.05, 0), Vector3.new(W, 0.1, L), laneF, SOLID)
	local edgeF = if t == 5 then F.Walnut elseif t == 6 then F.Composite elseif t == 3 then F.RubberFloor else F.PowderBlack
	for _, sx in { -1, 1 } do
		Kit.box(m, at(sx * (W / 2 + 0.12), h0 + 0.07, 0), Vector3.new(0.24, 0.14, L + 0.48), edgeF, DETAIL)
	end
	for _, sz in { -1, 1 } do
		Kit.box(m, at(0, h0 + 0.07, sz * (L / 2 + 0.12)), Vector3.new(W, 0.14, 0.24), edgeF, DETAIL)
	end
	local lineF = if t == 2 then F.PowderYellow elseif t == 5 then F.Gold else F.FabricWhite
	for _, z in { -L / 2 + 2.6, L / 2 - 4 } do
		Kit.box(m, at(0, h0 + 0.105, z), Vector3.new(W - 0.6, 0.01, 0.12), lineF, DETAIL)
	end
	-- anchor
	local az = L / 2 - 1.6
	local ab = h0 + 0.1
	if t == 2 then
		Kit.box(m, at(0, ab + 0.05, az), Vector3.new(1.4, 0.1, 1.4), F.SteelDark, SOLID)
		Kit.box(m, at(0, ab + 0.5, az), Vector3.new(0.4, 0.9, 0.4), st.Frame, SOLID)
		for _, sx in { -1, 1 } do
			S.bolt(c, m, at(sx * 0.5, ab + 0.11, az + 0.5) * CFrame.Angles(math.rad(90), 0, 0))
			S.bolt(c, m, at(sx * 0.5, ab + 0.11, az - 0.5) * CFrame.Angles(math.rad(90), 0, 0))
		end
	else
		local postF = if t == 5 then F.BlackChrome elseif t == 6 then F.Composite else st.Frame
		Kit.box(m, at(0, ab + 0.08, az), Vector3.new(1.6, 0.16, 1.6), if t == 5 then F.MarbleDark else F.SteelDark, SOLID)
		S.tube(c, m, pt(0, ab, az + 0.2), pt(0, ab + 2.2, az + 0.2), 0.5, postF)
		S.cap(c, m, pt(0, ab + 2.2, az + 0.2), 0.5)
		-- plate-loaded horn for mass
		Kit.cylZ(m, at(0, ab + 0.95, az + 0.75), 0.7, 0.24, st.Metal, DETAIL)
		S.plate(c, m, at(0, ab + 0.95, az + 0.75) * rotY(90), 1.8, 0.3, 1)
		S.band(c, m, pt(0, ab + 1.9, az + 0.2), 0.5)
	end
	-- strap around the anchor
	local strapF = if t == 3 then F.FabricRed elseif t == 5 then F.LeatherBlack else F.PlasticBlack
	Kit.box(m, at(0, ab + 0.4, az - 0.05), Vector3.new(0.62, 0.3, 0.62), strapF, DETAIL)
	-- rope halves: gentle S-curves lying on the lane
	local ropeF = if t == 5 then F.PlasticBlack else F.Rope
	local d = 0.42
	local endZ = -L / 2 + 2.9
	for _, sx in { -1, 1 } do
		local n = 7
		local prev = pt(sx * 0.32, ab + d / 2, az - 0.3)
		for i = 1, n do
			local f = i / n
			local z = (az - 0.3) + (endZ - (az - 0.3)) * f
			local x = sx * (0.32 + 0.6 * f + math.sin(f * math.pi * 2.2) * 0.32 * (1 - f * 0.6))
			local p = pt(x, ab + d / 2, z)
			Kit.span(m, prev, p, d, ropeF, DETAIL)
			if i < n then
				Kit.ball(m, p, d, ropeF, DETAIL)
			end
			prev = p
		end
		-- handle sleeve + end cap
		local hEnd = prev + (prev - pt(sx * 0.9, ab + d / 2, endZ + 1)).Unit * 0.7
		Kit.span(m, prev, hEnd, d + 0.08, if t == 5 then F.LeatherBlack else F.Rubber, DETAIL)
		Kit.ball(m, hEnd, d + 0.06, if t == 5 then F.Gold elseif t == 3 then F.PowderRed else F.Rubber, DETAIL)
	end
	S.placard(c, m, at(0, h0 + 0.2, -L / 2 - 0.25) * rotY(180), 1.4, S.NAMES.BattleRopes)
	c.E.standingSpot(m, at(0, h0 + 0.1, -L / 2 + 1.5))
end

---------------------------------------------------------------------------
-- Treadmill. T1-4 motorised (hood, uprights, console, rails); T5 curved
-- self-powered slat treadmill. Rear roller = Spinner.
---------------------------------------------------------------------------
local function treadmill(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local h0 = S.plinth(c, m, at(0, 0, 0.2), 3.8, 7.8)
	local deckW = if t == 1 then 2.7 else 2.6
	local belt = 1.9
	local zBack, zFront = -3.3, 2.4
	local deckTop = h0 + 0.85
	local sideF = if t == 4 then F.OakSolid elseif t == 5 then F.Walnut elseif t == 1 then F.PlasticTeal else st.Frame
	local spotZ = -0.6

	if t == 5 then
		-- curved slat deck: lowest point at the trainee's spot
		local R = 9.0
		local n = 15
		local span = 6.4
		local cz = spotZ + 0.2
		for i = 0, n - 1 do
			local z = -span / 2 + (i + 0.5) * span / n + cz
			local dz = z - cz
			local y = deckTop + (R - math.sqrt(R * R - dz * dz))
			local ang = math.asin(dz / R)
			Kit.box(m, at(0, y - 0.08, z) * CFrame.Angles(ang, 0, 0), Vector3.new(belt, 0.16, span / n - 0.04), F.RubberGrip, DETAIL)
		end
		local edgeH = 1.25
		for _, sx in { -1, 1 } do
			Kit.box(m, at(sx * (belt / 2 + 0.2), h0 + edgeH / 2, cz), Vector3.new(0.4, edgeH, span + 0.6), F.Walnut, SOLID)
			Kit.box(m, at(sx * (belt / 2 + 0.2), h0 + edgeH + 0.02, cz), Vector3.new(0.42, 0.04, span + 0.62), F.Gold, DETAIL)
			Kit.box(m, at(sx * (belt / 2 + 0.41), h0 + 0.5, cz), Vector3.new(0.02, 0.05, span + 0.4), F.Gold, DETAIL)
		end
		-- black chrome bowl ends under the curve
		for _, sz in { -1, 1 } do
			Kit.box(m, at(0, h0 + 0.5, cz + sz * (span / 2 + 0.15)), Vector3.new(belt + 0.8, 1.0, 0.3), F.BlackChrome, SOLID)
		end
		Kit.box(m, at(0, h0 + 0.2, cz), Vector3.new(belt, 0.4, span), F.BlackChrome, SOLID)
		-- front handlebar loop + slim console mast
		local fz = cz + span / 2 + 0.3
		for _, sx in { -1, 1 } do
			S.tube(c, m, pt(sx * (belt / 2 + 0.2), h0 + 1.2, fz), pt(sx * 1.0, h0 + 4.0, fz + 0.2), 0.22, F.BlackChrome)
		end
		S.rod(c, m, pt(-1.0, h0 + 4.0, fz + 0.2), pt(1.0, h0 + 4.0, fz + 0.2), 0.22, F.LeatherBlack)
		S.tube(c, m, pt(0, h0 + 1.0, fz + 0.1), pt(0, h0 + 4.3, fz + 0.3), 0.24, F.BlackChrome)
		console(c, m, at(0, h0 + 4.6, fz + 0.3) * rotY(180) * CFrame.Angles(math.rad(-20), 0, 0) * rotY(180), 1.0, 0.7)
		-- rollers (Spinner) at both ends of the curve
		for _, sz in { -1, 1 } do
			local rz = cz + sz * (span / 2 - 0.25)
			local ry = deckTop + (R - math.sqrt(R * R - (span / 2 - 0.25) ^ 2)) - 0.3
			local sp = c.E.spinner(m, at(0, ry, rz), 18)
			Kit.cyl(sp, at(0, ry, rz), belt + 0.1, 0.4, F.SteelDark, DETAIL)
			Kit.box(sp, at(0, ry + 0.18, rz), Vector3.new(belt, 0.04, 0.06), F.Gold, DETAIL)
		end
		-- gold levelling feet + rear rubber bumpers
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				Kit.cylY(m, at(sx * (belt / 2 + 0.2), h0 + 0.04, cz + sz * (span / 2 + 0.1)), 0.08, 0.4, F.Gold, DETAIL)
			end
			Kit.box(m, at(sx * 0.6, h0 + 0.6, cz - span / 2 - 0.34), Vector3.new(0.4, 0.4, 0.1), F.Rubber, DETAIL)
		end
		S.placard(c, m, at(belt / 2 + 0.42, h0 + 0.85, cz) * rotY(-90), 1.2, S.NAMES.Treadmill)
		c.E.userSpot(m, at(0, deckTop + 3.0, spotZ))
		return
	end

	-- deck: frame + belt + side foot rails
	Kit.box(m, at(0, deckTop - 0.3, (zBack + zFront) / 2), Vector3.new(deckW, 0.5, zFront - zBack), st.Frame, SOLID)
	Kit.box(m, at(0, deckTop - 0.03, (zBack + zFront) / 2 - 0.1), Vector3.new(belt, 0.06, zFront - zBack - 0.4), F.RubberGrip, DETAIL)
	for _, sx in { -1, 1 } do
		Kit.box(m, at(sx * (belt / 2 + (deckW - belt) / 4), deckTop - 0.04, (zBack + zFront) / 2), Vector3.new((deckW - belt) / 2, 0.1, zFront - zBack), sideF, DETAIL)
		if t >= 2 then
			Kit.box(m, at(sx * (deckW / 2 + 0.005), deckTop - 0.3, (zBack + zFront) / 2), Vector3.new(0.02, 0.06, zFront - zBack - 0.4), if t == 4 then F.Brass elseif t == 3 then F.PowderRed else F.SteelDark, DETAIL)
		end
		S.foot(c, m, at(sx * (deckW / 2 - 0.3), h0, zBack + 0.3), 0.4, 0.4)
	end
	-- rear roller (Spinner)
	local rCf = at(0, deckTop - 0.25, zBack + 0.05)
	local sp = c.E.spinner(m, rCf, 18)
	Kit.cyl(sp, rCf, belt, 0.42, F.SteelDark, DETAIL)
	Kit.box(sp, rCf * CFrame.new(0, 0.19, 0), Vector3.new(belt - 0.1, 0.04, 0.08), F.SteelBrushed, DETAIL)
	-- motor hood
	local hoodF = if t == 1 then F.PowderWhite elseif t == 6 then F.Composite else st.FrameAccent
	local hz = zFront + 0.55
	if t == 1 then
		Kit.box(m, at(0, deckTop - 0.1, hz), Vector3.new(deckW, 0.9, 1.1), hoodF, SOLID)
		Kit.cyl(m, at(0, deckTop + 0.35, hz - 0.55), deckW, 0.6, hoodF, DETAIL)
		Kit.box(m, at(0, deckTop + 0.2, hz - 0.5), Vector3.new(deckW + 0.02, 0.12, 0.08), F.PlasticCoral, DETAIL)
	else
		Kit.box(m, at(0, deckTop - 0.15, hz), Vector3.new(deckW, 0.8, 1.1), hoodF, SOLID)
		Kit.wedge(m, at(0, deckTop + 0.4, hz) * rotY(180), Vector3.new(deckW, 0.3, 1.1), hoodF, DETAIL)
	end
	-- uprights, console, handrails
	local cy, cz = h0 + 4.55, zFront + 0.25
	local railY = h0 + 3.55
	for _, sx in { -1, 1 } do
		local x = sx * (deckW / 2 - 0.15)
		S.tube(c, m, pt(x, deckTop - 0.1, hz + 0.1), pt(x, cy - 0.3, cz + 0.1), if t == 1 then 0.42 else 0.34, st.Frame)
		local gripF = if t == 4 then F.LeatherTan elseif t == 1 then F.PlasticCoral else st.Grip
		S.rod(c, m, pt(x, railY + 0.4, cz - 0.1), pt(x, railY, cz - 1.0), 0.2, st.Metal)
		Kit.span(m, pt(x, railY, cz - 1.0), pt(x, railY, cz - 2.4), 0.24, gripF, DETAIL)
		Kit.ball(m, pt(x, railY, cz - 2.4), 0.26, st.FrameAccent, DETAIL)
		if t == 4 then
			S.band(c, m, pt(x, cy - 0.5, cz + 0.07), 0.34)
		end
	end
	local consoleW = if t == 1 then 2.0 else 2.3
	console(c, m, at(0, cy, cz) * rotY(180) * CFrame.Angles(math.rad(-25), 0, 0) * rotY(180), consoleW, if t >= 3 then 1.25 else 0.9)
	-- front grab bar under the console
	S.rod(c, m, pt(-(deckW / 2 - 0.2), cy - 0.75, cz - 0.35), pt(deckW / 2 - 0.2, cy - 0.75, cz - 0.35), 0.2, if t == 1 then F.PlasticTeal else st.Metal)
	if t == 1 then
		-- safety key on a coral lanyard
		Kit.box(m, at(0.6, cy - 0.45, cz - 0.15), Vector3.new(0.18, 0.18, 0.08), F.PlasticCoral, DETAIL)
	end
	-- front feet, rear end caps
	for _, sx in { -1, 1 } do
		S.foot(c, m, at(sx * (deckW / 2 - 0.3), h0, hz + 0.3), 0.4, 0.4)
		Kit.box(m, at(sx * (deckW / 2 - 0.25), deckTop - 0.3, zBack - 0.08), Vector3.new(0.5, 0.5, 0.2), if t == 1 then F.PlasticCoral else F.PlasticBlack, DETAIL)
	end
	if t >= 2 then
		-- heart-rate sensor plates on the rails + cup holders beside the console
		for _, sx in { -1, 1 } do
			local x = sx * (deckW / 2 - 0.15)
			Kit.box(m, at(x, railY + 0.02, cz - 1.25), Vector3.new(0.27, 0.27, 0.5), F.SteelBrushed, DETAIL)
			Kit.cylY(m, at(sx * (consoleW / 2 + 0.1), cy - 0.45, cz - 0.1), 0.35, 0.34, if t == 4 then F.Brass elseif t == 3 then F.PowderRed else F.PlasticBlack, DETAIL)
		end
	end
	if t >= 4 then
		-- oak hood cheeks with a brass reveal
		for _, sx in { -1, 1 } do
			Kit.box(m, at(sx * (deckW / 2 + 0.03), deckTop - 0.15, hz), Vector3.new(0.06, 0.8, 1.1), F.OakSolid, DETAIL)
		end
		Kit.box(m, at(0, deckTop + 0.26, hz - 0.56), Vector3.new(deckW, 0.04, 0.03), F.Brass, DETAIL)
	end
	S.placard(c, m, at(0, deckTop - 0.1, hz + 0.56) * rotY(180), 1.2, S.NAMES.Treadmill)
	c.E.userSpot(m, at(0, deckTop + 3.0, spotZ))
end

---------------------------------------------------------------------------
-- SledPush: prowler sled at the start of a turf lane; the sled is the Mover.
---------------------------------------------------------------------------
local function sledPush(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local L, W = 29.2, 4.6
	local h0 = S.plinth(c, m, at(0, 0, 0), W + 0.6, L + 0.6)
	local laneF = if t == 2 then F.RubberFloor elseif t == 5 then F.TurfDark else F.Turf
	Kit.box(m, at(0, h0 + 0.05, 0), Vector3.new(W, 0.1, L), laneF, SOLID)
	local edgeF = if t == 5 then F.Walnut elseif t == 6 then F.Composite else F.PowderBlack
	for _, sx in { -1, 1 } do
		Kit.box(m, at(sx * (W / 2 + 0.12), h0 + 0.07, 0), Vector3.new(0.24, 0.14, L + 0.48), edgeF, DETAIL)
	end
	local lineF = if t == 2 then F.PowderYellow elseif t == 5 then F.Gold else F.FabricWhite
	for i = 0, 5 do
		local z = -L / 2 + 3 + i * 5
		Kit.box(m, at(0, h0 + 0.105, z), Vector3.new(W - 0.4, 0.01, if i == 0 or i == 5 then 0.18 else 0.08), lineF, DETAIL)
	end
	if t >= 5 then
		-- distance bollards along the lane edges
		for i = 1, 3 do
			local z = -L / 2 + 3 + i * 5 + 2.5
			for _, sx in { -1, 1 } do
				Kit.cylY(m, at(sx * (W / 2 + 0.12), h0 + 0.5, z), 0.8, 0.3, if t == 6 then F.Composite else F.BlackChrome, DETAIL)
				Kit.cylY(m, at(sx * (W / 2 + 0.12), h0 + 0.93, z), 0.06, 0.34, if t == 6 then (st.Light or F.LightCyan) else F.Gold, DETAIL)
			end
		end
	end
	-- padded end bumper
	local bz = L / 2 - 0.4
	Kit.box(m, at(0, h0 + 1.0, bz), Vector3.new(W, 1.8, 0.5), if t == 5 then F.LeatherBlack elseif t == 3 then F.VinylRed else F.VinylBlack, SOLID)
	Kit.box(m, at(0, h0 + 0.05, bz + 0.1), Vector3.new(W + 0.2, 0.1, 0.8), st.Frame, DETAIL)
	S.placard(c, m, at(0, h0 + 1.3, bz - 0.26), 1.6, S.NAMES.SledPush)

	-- sled (Mover)
	local mover = c.E.mover(m, c.cf.LookVector * 1.2)
	local sz = -L / 2 + 4.6
	local sledF = if t == 3 then F.PowderRed elseif t == 5 then F.BlackChrome elseif t == 6 then F.Composite else st.Frame
	local yb = h0 + 0.1
	for _, sx in { -1, 1 } do
		-- skid with upturned nose
		Kit.box(mover, at(sx * 0.9, yb + 0.1, sz), Vector3.new(0.3, 0.2, 2.6), sledF, DETAIL)
		Kit.box(mover, at(sx * 0.9, yb + 0.22, sz + 1.4) * CFrame.Angles(math.rad(35), 0, 0), Vector3.new(0.3, 0.16, 0.6), sledF, DETAIL)
		-- push poles: tall rear uprights with high + low handles
		S.tube(c, mover, pt(sx * 0.9, yb + 0.2, sz - 1.1), pt(sx * 0.95, yb + 3.4, sz - 1.65), 0.24, sledF, false)
		local gripF = if t == 5 then F.LeatherBlack else st.Grip
		Kit.span(mover, pt(sx * 0.95, yb + 2.4, sz - 1.55), pt(sx * 0.95, yb + 3.4, sz - 1.7), 0.3, gripF, DETAIL)
		S.cap(c, mover, pt(sx * 0.95, yb + 3.45, sz - 1.67), 0.24)
	end
	for _, dz in { -1.0, 1.0 } do
		Kit.box(mover, at(0, yb + 0.25, sz + dz), Vector3.new(1.8, 0.14, 0.24), sledF, DETAIL)
	end
	-- plate horn with stacked plates
	Kit.cylY(mover, at(0, yb + 0.9, sz + 0.2), 1.3, 0.26, st.Metal, DETAIL)
	for i = 1, (if t >= 5 then 3 else 2) do
		local d = 2.3 - (i - 1) * 0.35
		S.plate(c, mover, at(0, yb + 0.35 + (i - 1) * 0.34, sz + 0.2) * CFrame.Angles(0, 0, math.rad(90)), d, 0.3, i)
	end
	-- low push bar between the poles
	S.tube(c, mover, pt(-0.9, yb + 1.3, sz - 1.25), pt(0.9, yb + 1.3, sz - 1.25), 0.2, sledF, false)
	c.E.standingSpot(m, at(0, h0 + 0.1, sz - 2.9))
end

return function(E: S.Lib)
	S.station(E, "Rower", rower)
	S.station(E, "Bike", bike)
	S.station(E, "BattleRopes", battleRopes)
	S.station(E, "Treadmill", treadmill)
	S.station(E, "SledPush", sledPush)
end
