--!strict
--[[
	Selectorized machines: ChestPress, LegPress, CableCrossover, LatPulldown.

	Each has a guided weight stack whose top 3 plates + pin + cap form the
	Mover (MoverTravel (0, 2.5, 0)), cables over pulleys to the working arm,
	upholstered pads and an adjustment pop-pin. Shrouds from Professional up.
	Local frame: x right, y up, z FORWARD (the trainee's facing).
]]

local Kit = require("../../Kit")
local S = require("./Shared")

local F = S.F
local DETAIL, SOLID = S.DETAIL, S.SOLID

local STACK_TRAVEL = Vector3.new(0, 2.5, 0)

local function rotY(deg: number): CFrame
	return CFrame.Angles(0, math.rad(deg), 0)
end

-- Seat post with a pop-pin height adjuster; returns nothing.
local function seatPost(c: S.Ctx, parent: Instance, x: number, z: number, y0: number, y1: number)
	local tube = c.tr.tube
	S.tube(c, parent, c.pt(x, y0, z), c.pt(x, y1, z), tube * 1.15)
	-- inner sleeve + knob on the front
	if c.tier >= 4 then
		S.tube(c, parent, c.pt(x, y1 - 0.5, z), c.pt(x, y1 + 0.05, z), tube * 0.8, c.st.Metal, false)
	end
	S.knob(c, parent, c.at(x, y1 - 0.75, z + tube * 0.6 + 0.05))
end

---------------------------------------------------------------------------
-- ChestPress: seated converging press. Arms hinge above/behind the shoulders;
-- the stack sits behind the tower, pin side facing the machine's left.
---------------------------------------------------------------------------
local function chestPress(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local tube = c.tr.tube
	local h0 = S.plinth(c, m, at(0, 0, -0.9), 6.0, 7.2)
	local Sy = h0 + 1.65
	local H = h0 + 7.3
	local zT = -1.55 -- tower posts

	-- base
	S.tube(c, m, pt(0, h0 + tube / 2, 1.5), pt(0, h0 + tube / 2, -3.4))
	S.tube(c, m, pt(-1.3, h0 + tube / 2, 1.5), pt(1.3, h0 + tube / 2, 1.5))
	S.tube(c, m, pt(-1.3, h0 + tube / 2, zT), pt(1.3, h0 + tube / 2, zT))
	for _, sx in { -1, 1 } do
		S.foot(c, m, at(sx * 1.3, h0, 1.5), 0.5, 0.5)
		S.foot(c, m, at(sx * 1.3, h0, zT), 0.5, 0.5)
	end
	-- seat + back pad
	seatPost(c, m, 0, 0.15, h0, Sy - 0.55)
	S.pad(c, m, at(0, Sy - 0.2, 0.15), Vector3.new(1.8, 0.4, 1.5))
	local backCf = at(0, Sy + 1.65, -0.78) * CFrame.Angles(math.rad(-8), 0, 0)
	S.pad(c, m, backCf * CFrame.Angles(math.rad(90), 0, 0), Vector3.new(1.7, 0.4, 2.7))
	S.tube(c, m, pt(0, h0 + tube, -1.2), pt(0, Sy + 1.2, -1.1), tube)
	-- footrest
	S.tube(c, m, pt(0, h0 + tube, 1.5), pt(0, h0 + 0.62, 1.75), tube * 0.8)
	Kit.box(m, at(0, h0 + 0.65, 1.8) * CFrame.Angles(math.rad(-25), 0, 0), Vector3.new(1.6, 0.08, 0.6), F.RubberGrip, DETAIL)

	-- tower
	for _, sx in { -1, 1 } do
		S.tube(c, m, pt(sx * 1.2, h0, zT), pt(sx * 1.2, H, zT), tube * 1.1)
		S.cap(c, m, pt(sx * 1.2, H, zT), tube * 1.1)
		S.band(c, m, pt(sx * 1.2, H - 0.5, zT), tube * 1.1)
		-- arm: pivot hub above the shoulder, tube forward-down to the handle
		local piv = pt(sx * 1.45, Sy + 3.55, zT + 0.2)
		local hand = pt(sx * 1.4, Sy + 2.1, 0.95)
		Kit.cyl(m, at(sx * 1.32, Sy + 3.55, zT + 0.2), 0.42, 0.5, st.FrameAccent, DETAIL)
		S.tube(c, m, piv, hand + Vector3.new(0, 0.25, 0), tube)
		-- vertical grip with end caps
		local gripF = if t == 4 then F.LeatherTan elseif t == 5 then F.LeatherBlack else st.Grip
		Kit.span(m, hand + Vector3.new(0, -0.45, 0), hand + Vector3.new(0, 0.45, 0), 0.22, gripF, DETAIL)
		Kit.ball(m, hand + Vector3.new(0, 0.48, 0), 0.26, st.FrameAccent, DETAIL)
		if t >= 4 then
			Kit.ball(m, hand + Vector3.new(0, -0.48, 0), 0.26, st.FrameAccent, DETAIL)
		end
	end
	S.tube(c, m, pt(-1.2, H - tube / 2, zT), pt(1.2, H - tube / 2, zT), tube * 1.1)
	S.tube(c, m, pt(-1.2, Sy + 3.55, zT), pt(1.2, Sy + 3.55, zT), tube)

	-- weight stack behind the tower, pin facing the machine's left side
	local mover = c.E.mover(m, STACK_TRAVEL)
	local stackBase = at(0, h0, -2.75) * rotY(90)
	local capTop, rodTop = S.stack(c, m, mover, stackBase, if t <= 3 then 7 else 10, true)
	-- cable: cap -> top pulley -> tower top -> arm cam
	local p1 = pt(0, H - 0.3, -2.75)
	local p2 = pt(0, H - 0.3, zT - 0.05)
	S.pulley(c, m, at(0, H - 0.3, -2.75), 0.5)
	S.pulley(c, m, at(0, H - 0.3, zT), 0.5)
	S.cable(m, capTop, p1 - Vector3.new(0, 0.25, 0))
	S.cable(m, p1 + (c.cf.UpVector * 0.25), p2 + (c.cf.UpVector * 0.25))
	S.cable(m, p2, pt(0, Sy + 3.55, zT))
	-- stack frame ties into the tower
	S.tube(c, m, pt(0, rodTop + 0.12, -2.75), pt(0, rodTop + 0.12, zT), tube * 0.8)
	S.tube(c, m, pt(0, H - 0.05, -2.75), pt(0, rodTop + 0.24, -2.75), tube * 0.8)

	-- branding on the tower cross member, facing the trainee's front
	S.placard(c, m, at(0, H - tube / 2, zT + tube * 0.55 + 0.04), 1.3, S.NAMES.ChestPress)
	c.E.userSpot(m, at(0, Sy + 1.3, 0))
	if t == 6 then
		for _, sx in { -1, 1 } do
			S.glow(c, m, pt(sx * 1.2, h0 + 0.5, zT + tube * 0.56), pt(sx * 1.2, H - 0.5, zT + tube * 0.56), 0.04)
		end
	end
end

---------------------------------------------------------------------------
-- LegPress: reclined seat (40 deg), foot plate high in front, side stack.
---------------------------------------------------------------------------
local function legPress(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local tube = c.tr.tube
	local h0 = S.plinth(c, m, at(0.4, 0, 0.3), 6.8, 7.6)
	local Sy = h0 + 1.5
	local spot = at(0, Sy + 1.3, -0.6) * CFrame.Angles(math.rad(40), 0, 0)
	c.E.userSpot(m, spot)

	-- base rail + feet
	S.tube(c, m, pt(0, h0 + tube / 2, -2.6), pt(0, h0 + tube / 2, 3.6))
	S.tube(c, m, pt(-1.2, h0 + tube / 2, -2.6), pt(1.2, h0 + tube / 2, -2.6))
	for _, sx in { -1, 1 } do
		S.foot(c, m, at(sx * 1.2, h0, -2.6), 0.5, 0.5)
	end
	-- seat and back pads follow the reclined body
	local seatCf = spot * CFrame.new(0, -1.52, -0.4)
	S.pad(c, m, seatCf, Vector3.new(1.85, 0.4, 1.5))
	local backCf = spot * CFrame.new(0, 0.35, 0.72) * CFrame.Angles(math.rad(-90), 0, 0)
	S.pad(c, m, backCf, Vector3.new(1.75, 0.4, 2.9))
	-- seat carriage: post under the seat and a strut under the back pad
	local seatUnder = (seatCf * CFrame.new(0, -0.35, 0)).Position
	S.tube(c, m, pt(0, h0 + tube, 0.0), seatUnder, tube * 1.1)
	local backUnder = (backCf * CFrame.new(0, -0.35, 0.4)).Position
	S.tube(c, m, pt(0, h0 + tube, -2.2), backUnder, tube)
	-- side handles beside the seat
	for _, sx in { -1, 1 } do
		local a = (seatCf * CFrame.new(sx * 1.05, -0.2, 0.5)).Position
		local b = (seatCf * CFrame.new(sx * 1.25, 0.15, -0.4)).Position
		S.tube(c, m, a, b, tube * 0.7, nil, false)
		Kit.span(m, b, (seatCf * CFrame.new(sx * 1.25, 0.25, -0.9)).Position, 0.22, st.Grip, DETAIL)
	end
	-- 45-degree sled: foot plate on a carriage riding two inclined rails
	local plateCf = spot * CFrame.new(0, -0.65, -3.15)
	local plateF = if t == 6 then F.Composite elseif t >= 4 then st.FrameAccent else F.SteelDark
	Kit.box(m, plateCf, Vector3.new(2.7, 2.3, 0.16), plateF, SOLID)
	Kit.box(m, plateCf * CFrame.new(0, 0, 0.1), Vector3.new(2.5, 2.1, 0.04), F.RubberGrip, DETAIL)
	Kit.box(m, plateCf * CFrame.new(0, -0.55, -0.35), Vector3.new(2.0, 0.5, 0.6), st.Frame, DETAIL)
	local railEnds: { [number]: Vector3 } = {}
	for _, sx in { -1, 1 } do
		local r0 = (spot * CFrame.new(sx * 0.8, -1.55, -2.5)).Position
		local r1 = (spot * CFrame.new(sx * 0.8, -1.55, -5.5)).Position
		S.tube(c, m, r0, r1, tube)
		railEnds[sx] = r1
		-- rail supports down to the base
		local floorPt = Vector3.new(r1.X, c.cf.Position.Y + h0, r1.Z)
		S.tube(c, m, r1, floorPt, tube)
		S.foot(c, m, CFrame.new(floorPt) * c.cf.Rotation, 0.5, 0.5)
		S.cap(c, m, r1, tube)
	end
	S.tube(c, m, railEnds[-1], railEnds[1], tube)
	local mid = (spot * CFrame.new(0, -1.55, -2.7)).Position
	S.tube(c, m, pt(-0.8, h0 + tube / 2, 3.4), pt(0.8, h0 + tube / 2, 3.4), tube)
	S.tube(c, m, (spot * CFrame.new(-0.8, -1.55, -2.7)).Position, (spot * CFrame.new(0.8, -1.55, -2.7)).Position, tube)
	S.tube(c, m, pt(0, h0 + tube, 2.2), mid, tube)

	-- weight stack on the right, pin side facing outward (+x)
	local mover = c.E.mover(m, STACK_TRAVEL)
	local sx0 = 2.55
	local stackBase = at(sx0, h0, -0.4) * rotY(-90)
	local capTop, rodTop = S.stack(c, m, mover, stackBase, if t <= 3 then 7 else 10, true)
	-- tie the stack to the base and run the cable to the foot-plate linkage
	S.tube(c, m, pt(0, h0 + tube / 2, -0.4), pt(sx0 - 0.6, h0 + tube / 2, -0.4), tube)
	local head = pt(sx0, rodTop + 0.45, -0.4)
	S.pulley(c, m, at(sx0, rodTop + 0.45, -0.4) * rotY(90), 0.5)
	S.cable(m, capTop, head - Vector3.new(0, 0.25, 0))
	S.cable(m, head + c.cf.LookVector * 0.25, pt(sx0, rodTop + 0.2, 2.4))
	S.cable(m, pt(sx0, rodTop + 0.2, 2.4), (plateCf * CFrame.new(0.9, -0.55, -0.35)).Position)
	S.pulley(c, m, at(sx0, rodTop + 0.2, 2.4) * rotY(90), 0.4)
	S.tube(c, m, pt(sx0, h0, 2.4), pt(sx0, rodTop + 0.2, 2.4), tube * 0.8)
	-- placard on the stack head, facing outward
	S.placard(c, m, at(sx0 + 0.3, rodTop + 0.12, -0.4) * rotY(-90), 1.0, S.NAMES.LegPress)
	Kit.marker(m, "PromptPart", at(0.8, h0 + 3.0, 0.4), Vector3.new(2, 2, 2))
end

---------------------------------------------------------------------------
-- CableCrossover: two stack towers joined by an overhead beam. Trainee stands
-- between them, slightly forward; D-handles hang from the high pulleys.
---------------------------------------------------------------------------
local function cableCrossover(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local h0 = S.plinth(c, m, at(0, 0, -0.4), 14.2, 4.6)
	local H = h0 + 9.4
	local zT = -0.8
	local xT = 5.9
	local mover = c.E.mover(m, STACK_TRAVEL)
	local plates = if t <= 3 then 7 else 10
	local colW = if t >= 4 then 0.75 else 0.6
	for _, sx in { -1, 1 } do
		local x0 = sx * xT
		local xs = x0 + sx * 0.15 -- stack centre
		local xc = x0 - sx * 0.95 -- pulley column
		local xr = x0 + sx * 0.95 -- rear column (outboard of the stack)
		-- tower: outboard column, top arm over the stack to the pulley column, base plate
		Kit.box(m, at(xr, (h0 + H) / 2, zT), Vector3.new(colW, H - h0, colW + 0.3), if t == 6 then F.Composite else st.Frame, SOLID)
		S.bar(c, m, pt(xr, H - 0.25, zT), pt(xc, H - 0.25, zT), 0.5, 0.5, st.Frame, SOLID)
		Kit.box(m, at(x0, h0 + 0.08, zT), Vector3.new(2.9, 0.16, 1.9), if t == 6 then F.Carbon else st.Frame, SOLID)
		-- stack facing inward
		local base = at(xs, h0 + 0.16, zT) * rotY(sx * 90)
		local capTop = S.stack(c, m, mover, base, plates, false, t <= 3)
		-- adjustable pulley column + carriage
		S.tube(c, m, pt(xc, h0 + 0.16, zT), pt(xc, H - 0.5, zT), 0.36, st.FrameAccent)
		local yCar = h0 + 6.4
		Kit.box(m, at(xc, yCar, zT), Vector3.new(0.5, 0.75, 0.5), st.Frame, DETAIL)
		local pc = at(xc - sx * 0.34, yCar - 0.45, zT) * rotY(90)
		S.pulley(c, m, pc, 0.42)
		-- cables: cap -> top arm -> down the column -> carriage -> handle
		S.cable(m, capTop, pt(xs, H - 0.5, zT))
		S.cable(m, pt(xc, H - 0.5, zT), pt(xc, yCar + 0.38, zT))
		local hTop = pt(xc - sx * 0.34, yCar - 0.62, zT)
		local hBot = pt(xc - sx * 0.34, yCar - 1.4, zT)
		S.cable(m, hTop, hBot)
		-- D-handle hanging at rest
		local gripF = if t == 4 then F.LeatherTan elseif t == 5 then F.LeatherBlack else st.Grip
		Kit.box(m, CFrame.new(hBot + Vector3.new(0, -0.18, 0)) * c.cf.Rotation, Vector3.new(0.06, 0.36, 0.5), st.Metal, DETAIL)
		Kit.cylZ(m, CFrame.new(hBot + Vector3.new(0, -0.38, 0)) * c.cf.Rotation, 0.5, 0.18, gripF, DETAIL)
		if t >= 3 then
			S.knob(c, m, at(xc - sx * 0.05, yCar - 0.1, zT + 0.3))
		end
		if t >= 4 then
			-- shroud panels front/back of the stack + trim
			local shF = if t == 4 then F.OakSolid elseif t == 5 then F.Walnut else F.Composite
			for _, dz in { -1, 1 } do
				Kit.box(m, at(xs, h0 + 2.6, zT + dz * 0.98), Vector3.new(1.3, 4.6, 0.08), shF, SOLID)
				Kit.box(m, at(xs, h0 + 4.95, zT + dz * 0.98), Vector3.new(1.32, 0.06, 0.1), st.Trim, DETAIL)
			end
			Kit.box(m, at(xr, H - 0.6, zT), Vector3.new(colW + 0.04, 0.12, colW + 0.34), st.Trim, DETAIL)
			Kit.box(m, at(xr, h0 + 0.5, zT), Vector3.new(colW + 0.04, 0.12, colW + 0.34), st.Trim, DETAIL)
			-- column hole strip + accessory hooks with a spare rope handle
			Kit.box(m, at(xc - sx * 0.19, (h0 + H) / 2, zT), Vector3.new(0.02, H - h0 - 2, 0.08), if t == 6 then (st.Light or F.LightCyan) else F.Iron, DETAIL)
			Kit.box(m, at(xr - sx * (colW / 2 + 0.15), h0 + 4.2, zT - 0.3), Vector3.new(0.3, 0.06, 0.06), st.Metal, DETAIL)
			Kit.box(m, at(xr - sx * (colW / 2 + 0.3), h0 + 3.7, zT - 0.3), Vector3.new(0.12, 1.0, 0.12), F.PlasticBlack, DETAIL)
		end
		if t == 6 then
			S.glow(c, m, pt(xc - sx * 0.19, h0 + 0.6, zT), pt(xc - sx * 0.19, H - 0.8, zT), 0.04)
		end
	end
	-- overhead beam with pull-up handles + branding
	S.tube(c, m, pt(-xT + 0.95, H - 0.25, zT), pt(xT - 0.95, H - 0.25, zT), 0.5)
	for _, sx in { -1, 1 } do
		S.rod(c, m, pt(sx * 1.4, H - 0.5, zT), pt(sx * 1.4, H - 0.5, zT + 0.9), 0.18, st.Metal)
		if t >= 4 then
			Kit.cylZ(m, at(sx * 1.4, H - 0.5, zT + 0.62), 0.5, 0.24, st.Grip, DETAIL)
		end
	end
	if t >= 4 then
		local f = if t == 4 then F.OakSolid elseif t == 6 then F.Composite else F.Walnut
		Kit.box(m, at(0, H - 0.25, zT + 0.27), Vector3.new(4.2, 0.4, 0.04), f, DETAIL)
	end
	S.placard(c, m, at(0, H - 0.25, zT + 0.31), 1.5, S.NAMES.CableCrossover)
	c.E.standingSpot(m, at(0, h0, 0.7))
end

---------------------------------------------------------------------------
-- LatPulldown: seated facing the stack; boom carries the top pulley over the
-- trainee's head; thigh rollers hold them down.
---------------------------------------------------------------------------
local function latPulldown(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local tube = c.tr.tube
	local h0 = S.plinth(c, m, at(0, 0, 1.0), 5.2, 6.6)
	local Sy = h0 + 1.6
	local H = h0 + 8.3
	local zS = 2.45 -- stack centre
	local zBar = 0.15
	local yBar = Sy + 5.15

	-- base
	S.tube(c, m, pt(0, h0 + tube / 2, -1.2), pt(0, h0 + tube / 2, 3.4))
	S.tube(c, m, pt(-1.2, h0 + tube / 2, -1.2), pt(1.2, h0 + tube / 2, -1.2))
	S.tube(c, m, pt(-1.25, h0 + tube / 2, 3.4), pt(1.25, h0 + tube / 2, 3.4))
	for _, sx in { -1, 1 } do
		S.foot(c, m, at(sx * 1.2, h0, -1.2), 0.5, 0.5)
		S.foot(c, m, at(sx * 1.25, h0, 3.4), 0.5, 0.5)
	end
	-- seat + thigh rollers
	seatPost(c, m, 0, 0.2, h0, Sy - 0.55)
	S.pad(c, m, at(0, Sy - 0.2, 0.2), Vector3.new(1.8, 0.4, 1.5))
	S.tube(c, m, pt(0, h0 + tube, 1.25), pt(0, Sy + 0.85, 1.25), tube)
	S.knob(c, m, at(0, Sy + 0.3, 1.25 + tube * 0.6 + 0.05))
	S.tube(c, m, pt(0, Sy + 0.85, 1.25), pt(0, Sy + 1.05, 0.7), tube * 0.9)
	for _, sx in { -1, 1 } do
		local roller = at(sx * 0.55, Sy + 1.05, 0.7)
		Kit.cyl(m, roller, 0.85, 0.5, st.Upholstery, SOLID)
		if t >= 4 then
			Kit.cyl(m, roller * CFrame.new(sx * 0.44, 0, 0), 0.04, 0.42, if t == 4 then F.Brass elseif t == 5 then F.Gold else F.PlasticBlack, DETAIL)
		end
	end
	Kit.cyl(m, at(0, Sy + 1.05, 0.7), 0.3, 0.14, st.Metal, DETAIL)

	-- tower beside the stack + boom over the trainee
	for _, sx in { -1, 1 } do
		S.tube(c, m, pt(sx * 1.05, h0, zS), pt(sx * 1.05, H, zS), tube * 1.1)
		S.cap(c, m, pt(sx * 1.05, H, zS), tube * 1.1)
		S.band(c, m, pt(sx * 1.05, H - 0.5, zS), tube * 1.1)
	end
	S.tube(c, m, pt(-1.05, H - tube / 2, zS), pt(1.05, H - tube / 2, zS), tube * 1.1)
	S.tube(c, m, pt(0, H - tube / 2, zS + 0.2), pt(0, H - 0.25, zBar - 0.2), tube)
	S.tube(c, m, pt(0, H - 1.8, zS - 0.2), pt(0, H - tube, 1.2), tube * 0.8)

	local mover = c.E.mover(m, STACK_TRAVEL)
	local base = at(0, h0, zS) * rotY(180)
	local capTop = S.stack(c, m, mover, base, if t <= 3 then 7 else 10, true)
	-- pulleys + cable: cap -> tower top -> boom end -> bar
	S.pulley(c, m, at(0, H - 0.65, zS) * rotY(90), 0.5)
	S.pulley(c, m, at(0, H - 0.55, zBar) * rotY(90), 0.5)
	S.cable(m, capTop, pt(0, H - 0.9, zS))
	S.cable(m, pt(0, H - 0.4, zS - 0.25), pt(0, H - 0.3, zBar + 0.1))
	S.cable(m, pt(0, H - 0.8, zBar), pt(0, yBar + 0.12, zBar))
	-- lat bar with bent ends + grips
	local barCf = at(0, yBar, zBar)
	Kit.cyl(m, barCf, 3.0, 0.16, st.Metal, DETAIL)
	Kit.box(m, barCf * CFrame.new(0, 0.06, 0), Vector3.new(0.2, 0.18, 0.2), st.Frame, DETAIL)
	local gripF = if t == 4 then F.LeatherTan elseif t == 5 then F.LeatherBlack else st.Grip
	for _, sx in { -1, 1 } do
		local a = pt(sx * 1.5, yBar, zBar)
		local b = pt(sx * 2.45, yBar - 0.4, zBar)
		Kit.span(m, a, b, 0.16, st.Metal, DETAIL)
		Kit.span(m, a:Lerp(b, 0.25), a:Lerp(b, 0.95), 0.22, gripF, DETAIL)
	end
	S.placard(c, m, at(0, H - tube / 2, zS - tube * 0.55 - 0.04) * rotY(180), 1.3, S.NAMES.LatPulldown)
	c.E.userSpot(m, at(0, Sy + 1.3, 0))
	if t == 6 then
		for _, sx in { -1, 1 } do
			S.glow(c, m, pt(sx * 1.05, h0 + 0.5, zS - tube * 0.56), pt(sx * 1.05, H - 0.5, zS - tube * 0.56), 0.04)
		end
	end
end

return function(E: S.Lib)
	S.station(E, "ChestPress", chestPress)
	S.station(E, "LegPress", legPress)
	S.station(E, "CableCrossover", cableCrossover)
	S.station(E, "LatPulldown", latPulldown)
end
