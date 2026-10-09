--!strict
--[[
	Free-weight & strongman stations: DumbbellCurl, BenchPress, SquatRack,
	Deadlift, PullUpBar, TireFlip, LogPress, AtlasStone.

	Local frame (see Shared): x right, y up, z FORWARD (the way the trainee faces).
	Each builder places the UserSpot per the pose contract in Equipment/init.luau
	and puts animated parts in Mover with the documented MoverTravel.
]]

local Kit = require("../../Kit")
local Palette = require("../../Palette")
local S = require("./Shared")
local R = require("./Racks")

local F = S.F
local DETAIL, SOLID = S.DETAIL, S.SOLID

local STONE = Palette.tint("Concrete", Color3.fromRGB(150, 146, 140))
local ROT90 = CFrame.Angles(0, math.rad(90), 0)

-- Invisible collider standing in for animated (non-colliding) mover parts.
local function collider(parent: Instance, cf: CFrame, size: Vector3, cylinderY: boolean?)
	local p = if cylinderY
		then Kit.cylY(parent, cf, size.Y, size.X, F.Rubber, { Collide = true, Transparency = 1, Shadow = false })
		else Kit.box(parent, cf, size, F.Rubber, { Collide = true, Transparency = 1, Shadow = false })
	p.Name = "Collider"
end

-- J-hook holding a bar at (x, yBar, zBar) from a post face at zPost (z forward).
local function jHook(c: S.Ctx, parent: Instance, x: number, yBar: number, zPost: number, zBar: number)
	local t = c.tier
	local hookF = if t == 1 then F.PlasticCoral elseif t == 4 then F.Brass elseif t == 5 then F.Gold elseif t == 6 then F.Titanium elseif t == 3 then F.Chrome else F.Steel
	local zFront = zBar + 0.22
	local y = yBar - 0.085 - 0.07
	local len = zFront - zPost
	Kit.box(parent, c.at(x, y, zPost + len / 2), Vector3.new(0.3, 0.14, len), hookF, DETAIL)
	if t == 1 then
		Kit.ball(parent, c.pt(x, y + 0.12, zFront), 0.26, F.PlasticCoral, DETAIL)
	else
		Kit.box(parent, c.at(x, y + 0.13, zFront - 0.03), Vector3.new(0.3, 0.26, 0.08), hookF, DETAIL)
		if t >= 4 then
			-- UHMW liner under the bar
			Kit.box(parent, c.at(x, y + 0.08, zBar), Vector3.new(0.26, 0.02, 0.3), F.PlasticBlack, DETAIL)
		end
	end
	-- mounting sleeve around the post
	if t ~= 1 then
		Kit.box(parent, c.at(x, y, zPost), Vector3.new(c.tr.tube + 0.08, 0.5, c.tr.tube + 0.08), if t == 6 then F.Composite else c.st.FrameAccent, DETAIL)
	end
end

-- Chalk bowl on a short pedestal (cf = floor point).
local function chalkStand(c: S.Ctx, parent: Instance, cf: CFrame)
	local t = c.tier
	local bowlF = if t == 4 then F.Brass elseif t == 5 then F.Gold elseif t == 6 then F.Titanium else F.SteelDark
	S.tube(c, parent, cf.Position, (cf * CFrame.new(0, 2.6, 0)).Position, 0.24)
	Kit.box(parent, cf * CFrame.new(0, 0.06, 0), Vector3.new(0.9, 0.12, 0.9), c.st.Frame, DETAIL)
	Kit.cylY(parent, cf * CFrame.new(0, 2.75, 0), 0.3, 1.0, bowlF, DETAIL)
	Kit.cylY(parent, cf * CFrame.new(0, 2.9, 0), 0.02, 0.86, F.FabricWhite, DETAIL)
end

---------------------------------------------------------------------------
-- DumbbellCurl: stand on the mat facing out; the dumbbell rack sits behind.
---------------------------------------------------------------------------
local function dumbbellCurl(c: S.Ctx)
	local m, t = c.model, c.tier
	local h0 = S.plinth(c, m, c.at(0, 0, 0), 6, 6, true)
	c.E.standingSpot(m, c.at(0, h0, 1.2))
	R.dumbbellRack(c, m, c.at(0, h0, -1.55), 5.2, t <= 3)
	-- standing mark on the mat
	local markF = if t == 1 then F.PlasticTeal elseif t == 4 then F.Brass elseif t == 5 then F.Gold elseif t == 6 then (c.st.Light or F.LightCyan) elseif t == 3 then F.PowderRed else F.PowderGraphite
	for _, sx in { -1, 1 } do
		Kit.box(m, c.at(sx * 1.25, h0 + 0.01, 1.2), Vector3.new(0.08, 0.02, 1.6), markF, DETAIL)
	end
	Kit.box(m, c.at(0, h0 + 0.01, 2.0), Vector3.new(2.58, 0.02, 0.08), markF, DETAIL)
	if t >= 2 then
		S.placard(c, m, c.at(0, h0 + 0.3, 2.99), 1.6, S.NAMES.DumbbellCurl)
	end
end

---------------------------------------------------------------------------
-- BenchPress: flat bench, uprights at the head end, loaded bar on J-hooks.
-- Head toward -z (back); feet toward the LookVector.
---------------------------------------------------------------------------
local function benchPress(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local tube = c.tr.tube
	local h0 = S.plinth(c, m, at(0, 0, -0.7), 7.8, 7.4)
	local padH = if t == 1 then 0.46 else 0.4
	local padW = if t == 1 then 1.75 else 1.6
	local P = h0 + 1.55
	local zPad, padL = -0.3, 4.4
	local zHrp = -0.2
	local zBar = zHrp - 1.3
	local yBar = P + 3.0
	local zUp = zBar - 0.5
	local xUp = 2.05

	-- pad + spine + legs
	S.pad(c, m, at(0, P - padH / 2, zPad), Vector3.new(padW, padH, padL))
	local ySp = P - padH - 0.1 - tube / 2
	S.tube(c, m, pt(0, ySp, zPad - padL / 2 + 0.2), pt(0, ySp, zPad + padL / 2 - 0.35))
	S.tube(c, m, pt(0, h0, 1.55), pt(0, ySp, 1.55))
	S.tube(c, m, pt(-1.0, h0 + tube / 2, 1.55), pt(1.0, h0 + tube / 2, 1.55))
	S.tube(c, m, pt(0, h0, zUp), pt(0, ySp, zPad - padL / 2 + 0.3))
	for _, sx in { -1, 1 } do
		S.foot(c, m, at(sx * 1.0, h0, 1.55), 0.5, 0.6)
		S.cap(c, m, pt(sx * 1.0, h0 + tube / 2, 1.55))
	end
	if t == 2 or t >= 4 then
		S.bolt(c, m, at(0.0, ySp, 1.55 + tube / 2 + 0.01))
	end

	-- uprights + base
	local yTop = yBar + (if t == 1 then 0.5 elseif t >= 4 then 1.3 else 0.9)
	local upT = if t >= 4 and t <= 5 then tube * 1.25 else tube
	for _, sx in { -1, 1 } do
		local x = sx * xUp
		S.tube(c, m, pt(x, h0, zUp), pt(x, yTop, zUp), upT)
		S.tube(c, m, pt(x, h0 + tube / 2, zUp + 1.0), pt(x, h0 + tube / 2, zUp - 1.0))
		S.foot(c, m, at(x, h0, zUp + 0.95), 0.5, 0.5)
		S.foot(c, m, at(x, h0, zUp - 0.95), 0.5, 0.5)
		S.cap(c, m, pt(x, yTop, zUp), upT)
		jHook(c, m, x, yBar, zUp + upT / 2, zBar)
		if t >= 2 then
			-- rear brace + plate horn with a stored plate
			S.tube(c, m, pt(x, h0 + tube, zUp - 0.95), pt(x, yBar - 1.6, zUp - upT / 2), tube * 0.8)
			if t <= 5 then
				Kit.cylZ(m, at(x, h0 + 1.3, zUp - 0.75), 1.1, 0.26, st.Metal, DETAIL)
				S.plate(c, m, at(x, h0 + 1.3, zUp - 0.95) * ROT90, 2.5, 0.32, 1)
			end
		end
		if t >= 3 then
			-- safety catch arms
			S.tube(c, m, pt(x, P + 0.8, zUp + upT / 2), pt(x, P + 0.8, zBar + 1.2), tube * 0.75, st.FrameAccent)
			S.cap(c, m, pt(x, P + 0.8, zBar + 1.2), tube * 0.75)
		end
		S.band(c, m, pt(x, yBar - 0.6, zUp), upT)
		S.band(c, m, pt(x, h0 + 0.5, zUp), upT)
		if t == 4 then
			-- oak inlay on the upright faces
			Kit.box(m, at(x, (h0 + yTop) / 2 + 0.2, zUp + upT / 2 + 0.01), Vector3.new(upT * 0.6, (yTop - h0) * 0.55, 0.03), F.OakSolid, DETAIL)
		elseif t == 6 then
			S.glow(c, m, pt(x, h0 + 0.5, zUp + upT / 2 + 0.01), pt(x, yTop - 0.3, zUp + upT / 2 + 0.01), 0.04)
		end
	end
	S.tube(c, m, pt(-xUp, h0 + tube / 2, zUp), pt(xUp, h0 + tube / 2, zUp))
	if t >= 4 then
		-- top header between the uprights (behind the bar path)
		S.tube(c, m, pt(-xUp, yTop - 0.2, zUp), pt(xUp, yTop - 0.2, zUp), upT * 0.8)
		S.placard(c, m, at(0, yTop - 0.2, zUp + upT * 0.4 + 0.04), 1.3, S.NAMES.BenchPress)
	elseif t >= 2 then
		S.placard(c, m, at(-xUp, h0 + 2.5, zUp + upT / 2 + 0.04), 0.55, nil)
	end

	-- spotter deck
	if t >= 3 then
		local deckF = if t == 4 then F.OakSolid elseif t == 5 then F.Walnut elseif t == 6 then F.Composite else F.RubberFleck
		Kit.box(m, at(0, h0 + 0.62, zUp - 0.85), Vector3.new(1.3, 0.14, 1.1), deckF, SOLID)
		S.tube(c, m, pt(0, h0, zUp - 1.2), pt(0, h0 + 0.55, zUp - 1.2), tube * 0.8)
		S.tube(c, m, pt(0, h0 + 0.55, zUp - 1.3), pt(0, h0 + 0.55, zUp), tube * 0.8)
	end

	-- trainee + loaded bar
	c.E.benchSpot(m, pt(0, P, zHrp), -c.cf.LookVector)
	local mover = c.E.mover(m, Vector3.new(0, -1.9, 0))
	local plates: { S.PlateSpec } = if t == 1
		then { { d = 1.7, t = 0.3 } }
		elseif t == 2 then { { d = 2.5, t = 0.42 }, { d = 1.6, t = 0.26 } }
		elseif t == 3 then { { d = 2.5, t = 0.32 }, { d = 2.5, t = 0.32 } }
		else { { d = 2.5, t = 0.32 }, { d = 2.5, t = 0.32 }, { d = 1.7, t = 0.22 } }
	S.barbell(c, mover, at(0, yBar, zBar), plates, if t == 1 then 6.0 else 7.2)
	collider(m, at(0, P - 0.6, zPad), Vector3.new(padW, 1.2, padL))
end

---------------------------------------------------------------------------
-- SquatRack: trainee stands in the front plane of the rack with the bar on
-- the J-hooks / their upper back (floor + 4.6). T3 half rack, T4+ power rack.
---------------------------------------------------------------------------
local function squatRack(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local tube = c.tr.tube * 1.1
	local h0 = S.plinth(c, m, at(0, 0, -1.6), 8.4, 7.6, true)
	local xP = 2.0
	local zF, zB = -0.85, if t == 3 then -3.4 else -4.1
	local H = h0 + (if t == 3 then 8.0 else 8.6)
	local Hb = if t == 3 then h0 + 5.6 else H
	local yBar, zBar = h0 + 4.6, -0.55

	for _, sx in { -1, 1 } do
		local x = sx * xP
		S.tube(c, m, pt(x, h0, zF), pt(x, H, zF), tube)
		S.tube(c, m, pt(x, h0, zB), pt(x, Hb, zB), tube)
		S.cap(c, m, pt(x, H, zF), tube)
		S.cap(c, m, pt(x, Hb, zB), tube)
		-- side base + top rails
		S.tube(c, m, pt(x, h0 + tube / 2, zF + 0.5), pt(x, h0 + tube / 2, zB - 0.5), tube)
		S.tube(c, m, pt(x, Hb - tube / 2, zF), pt(x, Hb - tube / 2, zB), tube)
		for _, z in { zF + 0.45, zB - 0.45 } do
			S.foot(c, m, at(x, h0, z), 0.55, 0.55)
		end
		-- hole columns on the uprights' front faces
		local holeF = if t == 6 then (st.Light or F.LightCyan) else F.Iron
		Kit.box(m, at(x, (h0 + H) / 2 + 0.6, zF + tube / 2 + 0.005), Vector3.new(0.08, H - h0 - 2.4, 0.02), holeF, DETAIL)
		jHook(c, m, x, yBar, zF + tube / 2, zBar)
		-- safety arms (inside the trainee's stance width, below the bar's lowest point)
		S.tube(c, m, pt(x, h0 + 2.15, zB + tube / 2), pt(x, h0 + 2.15, zF + 2.4), tube * 0.8, st.FrameAccent)
		S.cap(c, m, pt(x, h0 + 2.15, zF + 2.4), tube * 0.8)
		-- plate storage horns on the rear posts (outward)
		for i, y in { h0 + 1.32, h0 + 3.2 } do
			if i == 1 or t >= 4 then
				Kit.cyl(m, at(x + sx * 0.55, y, zB), 0.9, 0.24, st.Metal, DETAIL)
				S.plate(c, m, at(x + sx * (tube / 2 + 0.3), y, zB), 2.5, 0.32, i)
			end
		end
		for _, y in { h0 + 0.6, H - 0.6 } do
			S.band(c, m, pt(x, y, zF), tube)
		end
		if t == 6 then
			S.glow(c, m, pt(x, h0 + 0.4, zB - tube / 2 - 0.01), pt(x, Hb - 0.4, zB - tube / 2 - 0.01), 0.04)
		end
	end
	-- cross members
	S.tube(c, m, pt(-xP, h0 + tube / 2, zB), pt(xP, h0 + tube / 2, zB), tube)
	S.tube(c, m, pt(-xP, Hb - tube / 2, zB), pt(xP, Hb - tube / 2, zB), tube)
	-- pull-up bar across the front top
	Kit.cyl(m, at(0, H - 0.25, zF + 0.05), xP * 2 + 0.2, 0.2, st.Metal, DETAIL)
	S.tube(c, m, pt(-xP, H - tube / 2, zF), pt(xP, H - tube / 2, zF), tube)
	if t == 4 then
		-- oak header plaque + band pegs
		Kit.box(m, at(0, H - tube / 2, zF + tube / 2 + 0.03), Vector3.new(xP * 2 - 0.4, tube * 0.8, 0.05), F.OakSolid, DETAIL)
		S.placard(c, m, at(0, H - tube / 2, zF + tube / 2 + 0.07), 1.4, S.NAMES.SquatRack)
	elseif t == 5 then
		-- walnut back panel with gold inlay and crown header
		Kit.box(m, at(0, (h0 + 3.6 + Hb - 0.6) / 2, zB - 0.02), Vector3.new(xP * 2 - tube, Hb - h0 - 4.2, 0.12), F.WalnutPlanks, SOLID)
		Kit.box(m, at(0, h0 + 3.55, zB - 0.02), Vector3.new(xP * 2 - tube, 0.06, 0.14), F.Gold, DETAIL)
		Kit.box(m, at(0, H + 0.12, (zF + zB) / 2), Vector3.new(xP * 2 + tube + 0.3, 0.24, zF - zB + tube + 0.3), F.BlackChrome, SOLID)
		Kit.box(m, at(0, H + 0.02, (zF + zB) / 2), Vector3.new(xP * 2 + tube + 0.34, 0.05, zF - zB + tube + 0.34), F.Gold, DETAIL)
		S.placard(c, m, at(0, H - tube / 2, zF + tube / 2 + 0.04), 1.4, S.NAMES.SquatRack)
	else
		S.placard(c, m, at(-xP, h0 + 6.2, zF + tube / 2 + 0.04), 0.6, nil)
	end

	c.E.standingSpot(m, at(0, h0, 0))
	local mover = c.E.mover(m, Vector3.new(0, -2.0, 0))
	local plates: { S.PlateSpec } = if t <= 3
		then { { d = 2.5, t = 0.36 }, { d = 2.5, t = 0.36 } }
		else { { d = 2.5, t = 0.32 }, { d = 2.5, t = 0.32 }, { d = 2.5, t = 0.32 }, { d = 1.6, t = 0.22 } }
	S.barbell(c, mover, at(0, yBar, zBar), plates)
end

---------------------------------------------------------------------------
-- Deadlift: lifting platform, bar on the floor at plate radius.
---------------------------------------------------------------------------
local function deadlift(c: S.Ctx)
	local m, t = c.model, c.tier
	local at = c.at
	local W, D = 10.2, 7.6
	local h = if t == 5 then 0.3 else 0.22
	local sideF = if t == 5 then F.MarbleDark elseif t == 6 then F.Carbon else F.RubberFloor
	local midF = if t == 3 then F.Plywood elseif t == 4 then F.Oak elseif t == 5 then F.WalnutPlanks elseif t == 6 then F.Composite elseif t == 2 then F.Plywood else F.RubberCoral
	local trimF = if t == 3 then F.PowderGraphite elseif t == 4 then F.Brass elseif t == 5 then F.Gold elseif t == 6 then (c.st.Light or F.LightCyan) else F.PowderBlack
	-- platform: centre strip + rubber (or marble) wings + edge trims
	Kit.box(m, at(0, h / 2, 0), Vector3.new(3.4, h, D), midF, SOLID)
	for _, sx in { -1, 1 } do
		Kit.box(m, at(sx * (1.7 + (W / 2 - 1.7) / 2), h / 2, 0), Vector3.new(W / 2 - 1.7, h, D), sideF, SOLID)
		Kit.box(m, at(sx * 1.7, h - 0.005, 0), Vector3.new(0.08, 0.02, D), trimF, DETAIL)
		Kit.box(m, at(sx * (W / 2 + 0.05), h / 2, 0), Vector3.new(0.1, h + 0.02, D + 0.2), trimF, DETAIL)
	end
	for _, sz in { -1, 1 } do
		Kit.box(m, at(0, h / 2, sz * (D / 2 + 0.05)), Vector3.new(W + 0.2, h + 0.02, 0.1), trimF, DETAIL)
	end
	if t >= 3 then
		-- lane marking where the feet go
		local markF = if t == 3 then F.PowderRed elseif t == 4 then F.Brass elseif t == 5 then F.Gold else trimF
		Kit.box(m, at(0, h, -1.15), Vector3.new(2.6, 0.02, 0.07), markF, DETAIL)
	end
	S.placard(c, m, at(0, h / 2, D / 2 + 0.12), 1.8, S.NAMES.Deadlift)

	-- bar on the floor (centre at plate radius), trainee behind it
	local yBar, zBar = h + 1.25, 0.35
	c.E.standingSpot(m, at(0, h, zBar - 0.6))
	local mover = c.E.mover(m, Vector3.new(0, 1.3, 0))
	local plates: { S.PlateSpec } = if t <= 3
		then { { d = 2.5, t = 0.38 }, { d = 2.5, t = 0.38 }, { d = 1.7, t = 0.26 } }
		else { { d = 2.5, t = 0.34 }, { d = 2.5, t = 0.34 }, { d = 2.5, t = 0.34 }, { d = 1.7, t = 0.24 } }
	S.barbell(c, mover, at(0, yBar, zBar), plates)

	-- chalk stand + spare plates stacked flat in the back corners
	chalkStand(c, m, at(-W / 2 + 0.8, h, -D / 2 + 0.8))
	for i = 1, (if t >= 4 then 3 else 2) do
		local d = if i == 1 then 2.5 else 1.7 + (3 - i) * 0.3
		S.plate(c, m, at(W / 2 - 1.5, h + 0.2 + (i - 1) * 0.36, -D / 2 + 1.5) * CFrame.Angles(0, 0, math.rad(90)), d, 0.34, i)
	end
	if t >= 4 then
		-- deadlift bar jack resting at the side
		local jackF = if t == 4 then F.Brass else F.Gold
		S.tube(c, m, c.pt(W / 2 - 0.6, h + 0.25, 2.2), c.pt(W / 2 - 0.6, h + 0.25, -0.6), 0.16, c.st.Frame, false)
		Kit.box(m, at(W / 2 - 0.6, h + 0.45, 2.2), Vector3.new(0.3, 0.5, 0.2), jackF, DETAIL)
		Kit.box(m, at(W / 2 - 0.6, h + 0.12, 1.6), Vector3.new(0.7, 0.24, 0.5), c.st.Frame, DETAIL)
	end
end

---------------------------------------------------------------------------
-- PullUpBar: free-standing pull-up frame; T3 power tower, T5 monument.
---------------------------------------------------------------------------
local function pullUpBar(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local tube = c.tr.tube
	local h0 = S.plinth(c, m, at(0, 0, 0), 6.6, 4.6)
	local H = h0 + 8.6
	local zBar = 0.15
	local xU = if t == 5 then 2.6 else 2.4
	local upT = if t == 5 then 0.55 else tube * 1.1
	for _, sx in { -1, 1 } do
		local x = sx * xU
		S.tube(c, m, pt(x, h0, zBar), pt(x, H + 0.35, zBar), upT)
		S.cap(c, m, pt(x, H + 0.35, zBar), upT)
		S.tube(c, m, pt(x, h0 + tube / 2, -1.9), pt(x, h0 + tube / 2, 2.0), tube)
		S.tube(c, m, pt(x, h0 + tube, -1.75), pt(x, h0 + 3.6, zBar - upT / 2), tube * 0.85)
		S.tube(c, m, pt(x, h0 + tube, 1.85), pt(x, h0 + 3.6, zBar + upT / 2), tube * 0.85)
		S.foot(c, m, at(x, h0, -1.85), 0.5, 0.5)
		S.foot(c, m, at(x, h0, 1.9), 0.5, 0.5)
		for _, y in { h0 + 0.5, h0 + 4.0, H - 0.4 } do
			S.band(c, m, pt(x, y, zBar), upT)
		end
		-- angled wide grips at the ends of the bar
		local gripF = if t == 5 then F.Walnut elseif t == 3 then F.FabricRed else st.Grip
		S.rod(c, m, pt(x - sx * upT / 2, H, zBar), pt(x - sx * 0.95, H - 0.1, zBar + 0.75), 0.2, st.Metal)
		Kit.span(m, pt(x - sx * 0.62, H - 0.05, zBar + 0.38), pt(x - sx * 0.9, H - 0.09, zBar + 0.7), 0.26, gripF, DETAIL)
		if t == 6 then
			S.glow(c, m, pt(x, h0 + 0.5, zBar + upT / 2 + 0.01), pt(x, H, zBar + upT / 2 + 0.01), 0.04)
		end
	end
	-- straight bar (with grip sleeves) + top cross member
	Kit.cyl(m, at(0, H, zBar), xU * 2, 0.2, st.Metal, SOLID)
	for _, sx in { -1, 1 } do
		Kit.cyl(m, at(sx * 1.45, H, zBar), 0.7, 0.24, if t == 5 then F.Walnut else st.Grip, DETAIL)
	end
	S.tube(c, m, pt(-xU, H + 0.35 - upT / 2, zBar - 0.02), pt(xU, H + 0.35 - upT / 2, zBar - 0.02), upT * 0.8)
	-- neutral grips
	for _, sx in { -1, 1 } do
		S.rod(c, m, pt(sx * 0.75, H, zBar), pt(sx * 0.75, H, zBar + 0.9), 0.18, st.Metal)
	end
	S.tube(c, m, pt(-1.0, H, zBar + 0.9), pt(1.0, H, zBar + 0.9), 0.16, st.Metal, false)

	if t == 3 or t == 6 then
		-- power tower: dip handles in front, back pad + arm rests behind
		for _, sx in { -1, 1 } do
			S.tube(c, m, pt(sx * xU, h0 + 4.3, zBar + upT / 2), pt(sx * 1.05, h0 + 4.3, zBar + 1.0), tube * 0.8)
			Kit.cylZ(m, at(sx * 1.05, h0 + 4.3, zBar + 1.35), 0.7, 0.24, F.FabricRed, DETAIL)
			S.tube(c, m, pt(sx * xU, h0 + 5.3, zBar - upT / 2), pt(sx * 1.4, h0 + 5.3, -0.45), tube * 0.8)
			S.pad(c, m, at(sx * 1.4, h0 + 5.48, -0.15), Vector3.new(0.5, 0.22, 1.0), true)
		end
		S.tube(c, m, pt(-xU, h0 + 3.2, -0.95), pt(xU, h0 + 3.2, -0.95), tube * 0.8)
		S.pad(c, m, at(0, h0 + 4.0, -0.95) * CFrame.Angles(math.rad(90), 0, 0), Vector3.new(1.3, 0.3, 1.6), true)
	end
	if t == 5 then
		-- monument: walnut-clad header, gold crown, gymnastic rings
		Kit.box(m, at(0, H + 0.85, zBar), Vector3.new(xU * 2 + upT, 0.7, upT + 0.1), F.Walnut, SOLID)
		Kit.box(m, at(0, H + 1.25, zBar), Vector3.new(xU * 2 + upT + 0.2, 0.1, upT + 0.3), F.Gold, DETAIL)
		Kit.box(m, at(0, H + 0.48, zBar), Vector3.new(xU * 2 + upT + 0.1, 0.05, upT + 0.15), F.Gold, DETAIL)
		S.placard(c, m, at(0, H + 0.85, zBar + upT / 2 + 0.1), 1.6, S.NAMES.PullUpBar)
		for _, sx in { -1, 1 } do
			local x = sx * (xU - 0.9)
			Kit.box(m, at(x, H - 1.1, zBar - 0.45), Vector3.new(0.12, 2.2, 0.03), F.LeatherBlack, DETAIL)
			Kit.cylZ(m, at(x, H - 2.45, zBar - 0.45), 0.1, 0.6, F.Walnut, DETAIL)
			Kit.cylZ(m, at(x, H - 2.45, zBar - 0.45), 0.12, 0.34, F.PlasticBlack, DETAIL)
		end
	else
		S.placard(c, m, at(-xU, h0 + 6.6, zBar + upT / 2 + 0.04), 0.6, nil)
	end
	-- chalk-friendly step box under the bar (T2-3) / footplate
	if t <= 3 then
		local boxF = if t == 3 then F.RubberFleck else F.Plywood
		Kit.box(m, at(0, h0 + 0.5, -1.4), Vector3.new(2.0, 1.0, 1.2), boxF, SOLID)
		Kit.box(m, at(0, h0 + 1.01, -1.4), Vector3.new(1.9, 0.02, 1.1), F.RubberGrip, DETAIL)
	end
	if t >= 4 then
		chalkStand(c, m, at(-xU - 0.9, h0, -1.4))
	end
	-- hanging trainee: HRP 3.8 below the bar, directly under it
	c.E.userSpot(m, at(0, H - 3.8, 0))
	Kit.marker(m, "PromptPart", at(0, h0 + 3.0, 0.4), Vector3.new(2, 2, 2))
end

---------------------------------------------------------------------------
-- TireFlip: tractor tire lying flat on a turf pad; the whole tire is the Mover.
---------------------------------------------------------------------------
local function ring(c: S.Ctx, parent: Instance, centre: CFrame, rOut: number, rIn: number, h: number, n: number, f: Kit.FinishArg, opts: Kit.Opts)
	local mid = (rOut + rIn) / 2
	local chord = 2 * rOut * math.sin(math.pi / n) + 0.04
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		Kit.box(parent, centre * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -mid), Vector3.new(chord, h, rOut - rIn), f, opts)
	end
	local _ = c
end

local function tireFlip(c: S.Ctx)
	local m, t = c.model, c.tier
	local at = c.at
	local h0 = S.plinth(c, m, at(0, 0, 0.3), 8.0, 10.0)
	-- turf pad with border + start line
	local padF = F.TurfDark
	local borderF = if t == 5 then F.Walnut elseif t == 6 then F.Composite else F.RubberFloor
	Kit.box(m, at(0, h0 + 0.06, 0.3), Vector3.new(7.2, 0.12, 9.4), padF, SOLID)
	for _, sx in { -1, 1 } do
		Kit.box(m, at(sx * 3.7, h0 + 0.08, 0.3), Vector3.new(0.3, 0.16, 9.8), borderF, DETAIL)
	end
	for _, sz in { -1, 1 } do
		Kit.box(m, at(0, h0 + 0.08, 0.3 + sz * 4.85), Vector3.new(7.7, 0.16, 0.3), borderF, DETAIL)
	end
	local lineF = if t == 5 then F.Gold else F.FabricWhite
	Kit.box(m, at(0, h0 + 0.125, -1.05), Vector3.new(6.6, 0.01, 0.12), lineF, DETAIL)
	Kit.box(m, at(0, h0 + 0.125, 4.4), Vector3.new(6.6, 0.01, 0.12), lineF, DETAIL)

	local zT = 1.55
	local yT = h0 + 0.12 + 0.75
	local mover = c.E.mover(m, Vector3.new(0, 1.4, 0))
	local n = if t >= 4 then 20 else 16
	ring(c, mover, at(0, yT, zT), 2.8, 1.35, 1.5, n, F.Rubber, DETAIL)
	-- tread lugs (chevrons) around the outside
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local sgn = if i % 2 == 0 then 1 else -1
		Kit.box(mover, at(0, yT, zT) * CFrame.Angles(0, a, 0) * CFrame.new(0, sgn * 0.3, -2.84) * CFrame.Angles(0, 0, math.rad(sgn * 25)), Vector3.new(0.5, 0.42, 0.12), F.RubberGrip, DETAIL)
	end
	-- sidewall bead (gold on Legendary) on the top face
	if t >= 5 then
		ring(c, mover, at(0, yT + 0.755, zT), 2.25, 2.1, 0.02, n, F.Gold, DETAIL)
	else
		ring(c, mover, at(0, yT + 0.755, zT), 1.55, 1.4, 0.02, 12, F.RubberGrip, DETAIL)
	end
	collider(m, at(0, yT, zT), Vector3.new(5.6, 1.5, 5.6), true)
	c.E.standingSpot(m, at(0, h0 + 0.12, zT - 3.6))

	-- sledgehammer lying beside the pad + placard post
	local hx = 3.0
	Kit.span(m, c.pt(hx, h0 + 0.2, -3.2), c.pt(hx, h0 + 0.2, -0.4), 0.16, if t == 5 then F.Walnut else F.WornTimber, DETAIL)
	Kit.box(m, at(hx, h0 + 0.33, -0.25), Vector3.new(0.45, 0.42, 0.85), if t == 5 then F.Gold else F.SteelDark, DETAIL)
	Kit.box(m, at(-2.4, h0 + 0.42, -4.75), Vector3.new(1.5, 0.52, 0.12), c.st.Frame, DETAIL)
	S.placard(c, m, at(-2.4, h0 + 0.42, -4.83) * CFrame.Angles(0, math.rad(180), 0), 1.3, S.NAMES.TireFlip)
end

---------------------------------------------------------------------------
-- LogPress: steel strongman log resting at shoulder height on jerk blocks.
---------------------------------------------------------------------------
local function logPress(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at = c.at
	local h0 = S.plinth(c, m, at(0, 0, 0), 9.2, 6.8)
	-- strongman platform
	Kit.box(m, at(0, h0 + 0.11, 0), Vector3.new(9.2, 0.22, 6.8), F.RubberFloor, SOLID)
	Kit.box(m, at(0, h0 + 0.115, 0), Vector3.new(3.0, 0.22, 6.82), if t >= 4 then F.Oak else F.Plywood, SOLID)
	for _, sx in { -1, 1 } do
		Kit.box(m, at(sx * 1.5, h0 + 0.225, 0), Vector3.new(0.06, 0.01, 6.8), F.PowderRed, DETAIL)
	end
	local base = h0 + 0.22
	local yLog, zLog, rLog = base + 4.2, 0.95, 0.6
	-- jerk blocks (stacked, alternating rubber/timber)
	for _, sx in { -1, 1 } do
		local x = sx * 2.75
		local y = base
		local heights = { 1.3, 1.2, yLog - rLog - base - 2.5 }
		for i, bh in heights do
			local f = if i % 2 == 1 then F.RubberGrip else F.WornTimber
			Kit.box(m, at(x, y + bh / 2, zLog), Vector3.new(1.5, bh - 0.02, 1.5), f, SOLID)
			Kit.box(m, at(x, y + bh - 0.05, zLog - 0.76), Vector3.new(1.52, 0.1, 0.03), st.Frame, DETAIL)
			y += bh
		end
		Kit.box(m, at(x, y - 0.02, zLog), Vector3.new(0.9, 0.04, 0.9), F.Rubber, DETAIL)
	end
	-- the log (Mover): graphite steel tube, chrome end caps, recessed handles, red bands
	local mover = c.E.mover(m, Vector3.new(0, 3.2, 0))
	local logCf = at(0, yLog, zLog)
	Kit.cyl(mover, logCf, 6.6, rLog * 2, st.Frame, DETAIL)
	for _, sx in { -1, 1 } do
		Kit.cyl(mover, logCf * CFrame.new(sx * 3.32, 0, 0), 0.06, rLog * 2 - 0.1, F.Chrome, DETAIL)
		Kit.cyl(mover, logCf * CFrame.new(sx * 2.2, 0, 0), 0.18, rLog * 2 + 0.02, F.PowderRed, DETAIL)
		-- handle recess facing the trainee + handle bar
		local hx = sx * 0.62
		Kit.box(mover, logCf * CFrame.new(hx, 0, rLog - 0.12), Vector3.new(0.55, 0.9, 0.3), F.PlasticBlack, DETAIL)
		Kit.cylY(mover, logCf * CFrame.new(hx, 0, rLog - 0.15), 0.85, 0.16, F.Chrome, DETAIL)
	end
	c.E.standingSpot(m, at(0, base, -0.15))
	collider(m, logCf, Vector3.new(6.6, 1.2, 1.2))
	chalkStand(c, m, at(-3.9, base, -2.6))
	S.placard(c, m, at(0, h0 + 0.11, 3.42), 1.5, S.NAMES.LogPress)
	-- spare kegs/sandbag for context
	Kit.cylY(m, at(3.8, base + 0.85, -2.5), 1.7, 1.25, F.SteelDark, SOLID)
	Kit.cylY(m, at(3.8, base + 1.72, -2.5), 0.06, 1.28, F.PowderRed, DETAIL)
	Kit.cylY(m, at(3.8, base + 0.02, -2.5), 0.06, 1.28, F.PowderRed, DETAIL)
end

---------------------------------------------------------------------------
-- AtlasStone: stone on a rubber ring; the loading platform sits just in
-- front of the stone's vertical path, so at the top of the lift (+3.5) the
-- stone arrives level with the platform lip without clipping through it.
---------------------------------------------------------------------------
local function atlasStone(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local h0 = S.plinth(c, m, at(0, 0, 0), 8, 8)
	Kit.box(m, at(0, h0 + 0.08, 0), Vector3.new(7.6, 0.16, 7.6), F.RubberFloor, SOLID)
	local base = h0 + 0.16
	local zS, rS = -0.35, 1.0
	-- rubber seat ring + stone
	ring(c, m, at(0, base + 0.09, zS), 0.72, 0.42, 0.18, 8, F.RubberGrip, DETAIL)
	local mover = c.E.mover(m, Vector3.new(0, 3.5, 0))
	local stoneCf = at(0, base + 0.05 + rS, zS)
	Kit.ball(mover, stoneCf, rS * 2, STONE, DETAIL)
	collider(m, stoneCf, Vector3.new(1.8, 1.8, 1.8))
	c.E.standingSpot(m, at(0, base, zS - 1.15))

	-- loading platform: steel frame, timber top, its back face just outside the stone path
	local top = base + 0.05 + 3.5
	local z0, z1 = zS + rS + 0.04, 2.9
	local zc, dz = (z0 + z1) / 2, z1 - z0
	Kit.box(m, at(0, top - 0.2, zc), Vector3.new(2.8, 0.4, dz), F.WornTimber, SOLID)
	Kit.box(m, at(0, top - 0.42, zc), Vector3.new(2.9, 0.06, dz + 0.1), st.Frame, DETAIL)
	for _, sx in { -1, 1 } do
		for _, z in { z0 + 0.18, z1 - 0.18 } do
			S.tube(c, m, pt(sx * 1.25, base, z), pt(sx * 1.25, top - 0.45, z), 0.36)
		end
		S.tube(c, m, pt(sx * 1.25, base + 0.9, z0 + 0.18), pt(sx * 1.25, base + 0.9, z1 - 0.18), 0.28)
		S.tube(c, m, pt(sx * 1.25, base + 0.9, z0 + 0.18), pt(sx * 1.25, top - 0.6, z1 - 0.18), 0.22)
	end
	-- plywood skins on the sides and front make it read as a solid loading box
	for _, sx in { -1, 1 } do
		Kit.box(m, at(sx * 1.44, (base + top - 0.45) / 2, zc), Vector3.new(0.06, top - 0.45 - base, dz - 0.1), F.Plywood, DETAIL)
	end
	Kit.box(m, at(0, (base + top - 0.45) / 2, z1 - 0.02), Vector3.new(2.84, top - 0.45 - base, 0.06), F.Plywood, DETAIL)
	-- back face: rubber bumper so the stone has something to roll onto
	Kit.box(m, at(0, top - 0.75, z0 + 0.02), Vector3.new(2.5, 0.5, 0.06), F.RubberGrip, DETAIL)
	Kit.box(m, at(0, top + 0.005, zc), Vector3.new(2.2, 0.02, dz - 0.4), F.RubberGrip, DETAIL)
	S.placard(c, m, at(0, top - 0.75, z1 + 0.04), 1.2, S.NAMES.AtlasStone)
	-- a lighter stone waiting at the side
	ring(c, m, at(2.7, base + 0.07, -1.9), 0.55, 0.32, 0.14, 8, F.RubberGrip, DETAIL)
	Kit.ball(m, at(2.7, base + 0.78, -1.9), 1.5, STONE, SOLID)
	chalkStand(c, m, at(-3.0, base, -2.6))
	local _ = t
end

return function(E: S.Lib)
	S.station(E, "DumbbellCurl", dumbbellCurl)
	S.station(E, "BenchPress", benchPress)
	S.station(E, "SquatRack", squatRack)
	S.station(E, "Deadlift", deadlift)
	S.station(E, "PullUpBar", pullUpBar)
	S.station(E, "TireFlip", tireFlip)
	S.station(E, "LogPress", logPress)
	S.station(E, "AtlasStone", atlasStone)
end
