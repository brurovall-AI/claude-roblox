--!strict
--[[
	Recovery stations (restore Energy): YogaMat, Sauna, IceBath.
	Local frame: x right, y up, z FORWARD (the trainee's facing).
]]

local Kit = require("../../Kit")
local S = require("./Shared")

local F = S.F
local DETAIL, SOLID = S.DETAIL, S.SOLID

local CORK = { Material = Enum.Material.Sand, Color = Color3.fromRGB(176, 134, 92) } :: S.Finish

-- Water bottle standing at cf (floor point).
local function bottle(parent: Instance, cf: CFrame, body: Kit.FinishArg, cap: Kit.FinishArg)
	Kit.cylY(parent, cf * CFrame.new(0, 0.32, 0), 0.64, 0.26, body, DETAIL)
	Kit.cylY(parent, cf * CFrame.new(0, 0.7, 0), 0.12, 0.18, cap, DETAIL)
end

-- Folded towel (cf = bottom centre).
local function towel(parent: Instance, cf: CFrame, f: Kit.FinishArg, stripe: Kit.FinishArg?)
	Kit.box(parent, cf * CFrame.new(0, 0.12, 0), Vector3.new(1.0, 0.24, 0.7), f, DETAIL)
	if stripe then
		Kit.box(parent, cf * CFrame.new(0, 0.12, 0.25), Vector3.new(1.02, 0.25, 0.06), stripe, DETAIL)
	end
end

---------------------------------------------------------------------------
-- YogaMat: mat (T4 on an oak platform, T5 on a marble plinth) with blocks,
-- strap, bolster, rolled spare mat and small calm details.
---------------------------------------------------------------------------
local function yogaMat(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at = c.at
	local h0 = S.plinth(c, m, at(0, 0, 0), 2.95, 6.95)
	local matF = if t == 1 then F.VinylCoral elseif t == 3 then F.VinylRed elseif t == 4 then CORK elseif t == 5 then F.LeatherBlack elseif t == 6 then F.Composite else F.VinylBlack
	local accent = if t == 1 then F.PlasticTeal elseif t == 3 then F.PlasticBlack elseif t == 4 then F.Brass elseif t == 5 then F.Gold elseif t == 6 then (st.Light or F.LightCyan) else F.PowderGraphite
	local mw, ml, mt = 2.3, 6.1, if t >= 3 then 0.1 else 0.07
	Kit.box(m, at(0, h0 + mt / 2, 0), Vector3.new(mw, mt, ml), matF, SOLID)
	-- alignment line + edge binding
	Kit.box(m, at(0, h0 + mt + 0.002, 0), Vector3.new(0.04, 0.01, ml - 0.5), accent, DETAIL)
	if t >= 3 then
		for _, sx in { -1, 1 } do
			Kit.box(m, at(sx * (mw / 2 - 0.02), h0 + mt / 2, 0), Vector3.new(0.05, mt + 0.02, ml), accent, DETAIL)
		end
	end
	if t == 5 then
		for i = 1, 6 do
			Kit.box(m, at(0, h0 + mt + 0.004, -ml / 2 + ml * i / 7), Vector3.new(mw - 0.2, 0.01, 0.03), S.THREAD, DETAIL)
		end
	end
	local top = h0 + mt
	-- rolled spare mat at the back end
	local rollF = if t == 1 then F.VinylTeal elseif t == 4 then F.FabricCream elseif t == 5 then F.LeatherCognac else F.FabricGrey
	Kit.cyl(m, at(0, top + 0.28, -ml / 2 + 0.35), mw - 0.2, 0.56, rollF, DETAIL)
	for _, sx in { -1, 1 } do
		Kit.cyl(m, at(sx * 0.7, top + 0.28, -ml / 2 + 0.35), 0.08, 0.6, accent, DETAIL)
	end
	-- brand patch at the head of the mat
	Kit.box(m, at(0, top + 0.004, ml / 2 - 0.25), Vector3.new(0.6, 0.01, 0.2), accent, DETAIL)
	-- blocks + strap at the front end
	local blockF = if t == 4 then CORK elseif t == 5 then F.Walnut elseif t == 1 then F.PlasticTeal elseif t == 6 then F.Carbon else F.Foam
	for i, x in { -0.6, 0.5 } do
		local cf = at(x, top + 0.25, ml / 2 - 0.45) * CFrame.Angles(0, math.rad(i * 12 - 18), 0)
		Kit.box(m, cf * CFrame.new(0, -0.07, 0), Vector3.new(0.8, 0.36, 0.55), blockF, DETAIL)
		if t >= 4 then
			Kit.box(m, cf * CFrame.new(0, 0.115, 0), Vector3.new(0.55, 0.01, 0.06), accent, DETAIL)
		end
	end
	local strapF = if t == 3 then F.FabricRed elseif t == 5 then F.Gold else F.FabricCream
	Kit.box(m, at(0.95, top + 0.03, ml / 2 - 1.15), Vector3.new(0.18, 0.06, 0.9), strapF, DETAIL)
	Kit.box(m, at(0.95, top + 0.07, ml / 2 - 0.8), Vector3.new(0.24, 0.08, 0.18), F.SteelBrushed, DETAIL)
	-- towel + bottle beside the mat front
	towel(m, at(-0.75, top, ml / 2 - 1.3), if t == 5 then F.FabricWhite else F.FabricCream, accent)
	bottle(m, at(-0.85, top, ml / 2 - 2.0), if t >= 4 then (if t == 4 then F.Brass else F.Gold) else F.SteelBrushed, F.PlasticBlack)
	-- bolster (every tier) + foam roller
	local bF = if t == 4 then F.LeatherTan elseif t == 5 then F.LeatherBlack elseif t == 1 then F.FabricCream elseif t == 6 then F.Composite else F.FabricGrey
	Kit.cyl(m, at(-0.4, top + 0.3, -ml / 2 + 1.0), 1.3, 0.6, bF, DETAIL)
	for _, sx in { -1, 1 } do
		Kit.cyl(m, at(-0.4 + sx * 0.66, top + 0.3, -ml / 2 + 1.0), 0.04, 0.62, accent, DETAIL)
	end
	-- foam roller set aside behind the trainee
	local rollerF = if t == 1 then F.PlasticTeal elseif t == 3 then F.PlasticBlack elseif t == 6 then F.Carbon else F.Foam
	Kit.cyl(m, at(0.3, top + 0.25, -1.45), 1.1, 0.5, rollerF, DETAIL)
	for _, sx in { -1, 1 } do
		Kit.cyl(m, at(0.3 + sx * 0.56, top + 0.25, -1.45), 0.02, 0.36, accent, DETAIL)
	end
	if t <= 3 then
		-- soft zone underlay with accent edging
		Kit.box(m, at(0, h0 + 0.01, 0), Vector3.new(2.9, 0.02, 6.9), st.Base, DETAIL)
		for _, sz in { -1, 1 } do
			Kit.box(m, at(0, h0 + 0.025, sz * 3.4), Vector3.new(2.9, 0.02, 0.1), accent, DETAIL)
		end
		for _, sx in { -1, 1 } do
			Kit.box(m, at(sx * 1.4, h0 + 0.025, 0), Vector3.new(0.1, 0.02, 6.7), accent, DETAIL)
		end
	end
	if t >= 4 then
		-- folded blanket + incense holder
		Kit.box(m, at(0.72, top + 0.1, -ml / 2 + 1.0), Vector3.new(0.6, 0.2, 0.7), if t == 4 then F.FabricCream else F.FabricGrey, DETAIL)
		Kit.box(m, at(0.72, top + 0.21, -ml / 2 + 1.0), Vector3.new(0.62, 0.03, 0.1), accent, DETAIL)
		Kit.box(m, at(0.2, top + 0.03, ml / 2 - 0.15), Vector3.new(0.6, 0.06, 0.14), F.Walnut, DETAIL)
		S.rod(c, m, c.pt(0.05, top + 0.06, ml / 2 - 0.15), c.pt(0.35, top + 0.5, ml / 2 - 0.15), 0.02, F.WornTimber)
		-- singing bowl + candles on the front corner
		Kit.cylY(m, at(0.85, top + 0.03, ml / 2 - 2.0), 0.06, 0.5, F.Walnut, DETAIL)
		Kit.cylY(m, at(0.85, top + 0.18, ml / 2 - 2.0), 0.24, 0.62, accent, DETAIL)
		Kit.cylY(m, at(0.85, top + 0.29, ml / 2 - 2.0), 0.02, 0.5, F.PlasticBlack, DETAIL)
		for i, p in { { -0.35, 0.18 }, { -0.1, 0.08 }, { -0.25, -0.12 } } do
			local cf = at(p[1] - 0.6, top, ml / 2 - 0.12 + p[2] - 0.05)
			local hh = 0.2 + i * 0.08
			Kit.cylY(m, cf * CFrame.new(0, hh / 2, 0), hh, 0.16, F.FabricCream, DETAIL)
			Kit.cylY(m, cf * CFrame.new(0, hh + 0.03, 0), 0.06, 0.04, F.LightWarm, DETAIL)
		end
		-- small potted plant
		local pot = at(-0.92, top, -1.4)
		Kit.cylY(m, pot * CFrame.new(0, 0.22, 0), 0.44, 0.42, if t == 5 then F.MarbleDark else F.PlasterWarm, DETAIL)
		for k = 0, 2 do
			local a = k * 2.1
			Kit.box(m, pot * CFrame.new(math.cos(a) * 0.08, 0.6, math.sin(a) * 0.08) * CFrame.Angles(math.rad(18), a, 0), Vector3.new(0.18, 0.5, 0.04), F.Leaf, DETAIL)
		end
	end
	c.E.userSpot(m, at(0, top + 1.3, -0.4))
	Kit.marker(m, "PromptPart", at(0, top + 2.0, 0), Vector3.new(2, 2, 2))
end

---------------------------------------------------------------------------
-- Sauna: two-tier slatted cedar bench with backrest, headrest, bucket + ladle.
---------------------------------------------------------------------------
local function sauna(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local wood = F.Cedar
	local woodDark = { Material = Enum.Material.Wood, Color = Color3.fromRGB(140, 94, 58) } :: S.Finish
	local trim = if t == 5 then F.Gold elseif t == 6 then F.Titanium elseif t <= 3 then F.SteelDark else F.Brass
	local W = 3.9
	local Sy = 1.7
	local zBack, zFront = -1.4, 0.35
	-- upper seat slats
	local n = 6
	for i = 0, n - 1 do
		local z = zBack + 0.15 + (zFront - zBack - 0.3) * i / (n - 1)
		Kit.box(m, at(0, Sy - 0.06, z), Vector3.new(W, 0.12, 0.25), wood, SOLID)
	end
	-- lower foot bench
	for i = 0, 2 do
		Kit.box(m, at(0, 0.48, 0.65 + i * 0.32), Vector3.new(W, 0.1, 0.26), wood, SOLID)
	end
	-- frame: legs, aprons
	for _, sx in { -1, 1 } do
		local x = sx * (W / 2 - 0.2)
		S.bar(c, m, pt(x, 0, zFront - 0.12), pt(x, Sy - 0.12, zFront - 0.12), 0.22, nil, woodDark, SOLID)
		S.bar(c, m, pt(x, 0, zBack + 0.1), pt(x, 3.95, zBack + 0.1), 0.22, nil, woodDark, SOLID)
		S.bar(c, m, pt(x, Sy - 0.22, zBack + 0.1), pt(x, Sy - 0.22, zFront - 0.12), 0.18, nil, woodDark, DETAIL)
		S.bar(c, m, pt(x, 0, 1.35), pt(x, 0.43, 1.35), 0.18, nil, woodDark, DETAIL)
		S.bar(c, m, pt(x, 0.38, zFront - 0.12), pt(x, 0.38, 1.35), 0.16, nil, woodDark, DETAIL)
	end
	Kit.box(m, at(0, Sy - 0.3, zFront - 0.12), Vector3.new(W - 0.6, 0.3, 0.1), woodDark, DETAIL)
	Kit.box(m, at(0, 0.24, zFront - 0.1), Vector3.new(W - 0.6, 0.48, 0.08), wood, DETAIL)
	-- backrest slats (slight recline) + headrest
	for i = 0, 4 do
		local y = Sy + 0.6 + i * 0.4
		Kit.box(m, at(0, y, zBack - 0.02 + i * -0.04) * CFrame.Angles(math.rad(8), 0, 0), Vector3.new(W - 0.5, 0.26, 0.08), wood, SOLID)
	end
	-- vertical battens behind the slats
	for _, sx in { -1, 1 } do
		Kit.box(m, at(sx * 1.0, Sy + 1.4, zBack - 0.2) * CFrame.Angles(math.rad(8), 0, 0), Vector3.new(0.18, 1.9, 0.08), woodDark, DETAIL)
	end
	-- curved headrest resting on the top slat
	Kit.box(m, at(0, Sy + 2.32, zBack - 0.06) * CFrame.Angles(math.rad(-25), 0, 0), Vector3.new(1.2, 0.34, 0.16), woodDark, DETAIL)
	-- sand timer on the left post + oil bottle on the foot bench
	local tm = at(-(W / 2 - 0.2), 2.6, zBack + 0.3)
	Kit.box(m, tm, Vector3.new(0.3, 0.06, 0.16), woodDark, DETAIL)
	Kit.cylY(m, tm * CFrame.new(0, 0.2, 0), 0.34, 0.16, F.GlassFrosted, DETAIL)
	Kit.box(m, tm * CFrame.new(0, 0.4, 0), Vector3.new(0.3, 0.06, 0.16), woodDark, DETAIL)
	Kit.cylY(m, at(-0.6, 0.66, 1.0), 0.32, 0.16, F.GlassTint, DETAIL)
	Kit.cylY(m, at(-0.6, 0.86, 1.0), 0.08, 0.1, trim, DETAIL)
	-- brass thermometer + hygrometer plaque on the backrest
	Kit.cylZ(m, at(1.3, Sy + 2.0, zBack + 0.06), 0.06, 0.42, trim, DETAIL)
	Kit.cylZ(m, at(1.3, Sy + 2.0, zBack + 0.1), 0.02, 0.34, F.FabricCream, DETAIL)
	-- bucket + ladle on the foot bench, towel on the seat
	local bc = at(-1.3, 0.53, 0.95)
	Kit.cylY(m, bc * CFrame.new(0, 0.3, 0), 0.6, 0.62, wood, DETAIL)
	for _, dy in { 0.1, 0.5 } do
		Kit.cylY(m, bc * CFrame.new(0, dy, 0), 0.06, 0.65, trim, DETAIL)
	end
	Kit.cylY(m, bc * CFrame.new(0, 0.58, 0), 0.02, 0.54, F.Water, DETAIL)
	S.bar(c, m, (bc * CFrame.new(0, 0.5, 0)).Position, (bc * CFrame.new(0.55, 1.15, 0.2)).Position, 0.06, nil, woodDark, DETAIL)
	towel(m, at(1.1, Sy, -0.4), F.FabricWhite, F.FabricGrey)
	S.placard(c, m, at(0, Sy - 0.3, zFront - 0.02), 1.0, S.NAMES.Sauna)
	-- hanging brass hooks with a robe towel on the right post
	Kit.box(m, at(W / 2 - 0.2, 3.3, zBack + 0.25), Vector3.new(0.06, 0.06, 0.2), trim, DETAIL)
	Kit.box(m, at(W / 2 - 0.2, 2.85, zBack + 0.33), Vector3.new(0.5, 0.9, 0.08), F.FabricCream, DETAIL)
	c.E.userSpot(m, at(0, Sy + 1.3, -0.75))
	local _ = st
end

---------------------------------------------------------------------------
-- IceBath: long tub (T4 oak staves + brass hoops, T5 black marble + gold),
-- water with floating ice, steps, chiller and towel bench.
---------------------------------------------------------------------------
local function iceBath(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local h0 = S.plinth(c, m, at(0, 0, 0), 5.8, 7.8)
	local ow, ol, oh = 3.9, 6.4, 3.0
	local wall = 0.35
	local zT = 0.1
	local wallF = if t == 4 then F.Oak elseif t == 5 then F.MarbleDark elseif t == 6 then F.Composite else st.Frame
	local trim = if t == 4 then F.Brass elseif t == 5 then F.Gold elseif t == 6 then (st.Light or F.LightCyan) else st.Metal
	-- walls + floor
	Kit.box(m, at(0, h0 + 0.15, zT), Vector3.new(ow, 0.3, ol), wallF, SOLID)
	for _, sx in { -1, 1 } do
		Kit.box(m, at(sx * (ow / 2 - wall / 2), h0 + oh / 2, zT), Vector3.new(wall, oh, ol), wallF, SOLID)
	end
	for _, sz in { -1, 1 } do
		Kit.box(m, at(0, h0 + oh / 2, zT + sz * (ol / 2 - wall / 2)), Vector3.new(ow - wall * 2, oh, wall), wallF, SOLID)
	end
	-- rim cap
	local rimF = if t == 4 then F.OakSolid elseif t == 5 then F.Marble else F.Composite
	for _, sx in { -1, 1 } do
		Kit.box(m, at(sx * (ow / 2 - wall / 2), h0 + oh + 0.06, zT), Vector3.new(wall + 0.12, 0.12, ol + 0.12), rimF, DETAIL)
	end
	for _, sz in { -1, 1 } do
		Kit.box(m, at(0, h0 + oh + 0.06, zT + sz * (ol / 2 - wall / 2)), Vector3.new(ow - wall * 2, 0.12, wall + 0.12), rimF, DETAIL)
	end
	if t == 4 then
		-- brass hoops + vertical stave lines
		for _, y in { 0.5, oh - 0.5 } do
			for _, sx in { -1, 1 } do
				Kit.box(m, at(sx * (ow / 2 + 0.01), h0 + y, zT), Vector3.new(0.03, 0.14, ol + 0.04), trim, DETAIL)
			end
			for _, sz in { -1, 1 } do
				Kit.box(m, at(0, h0 + y, zT + sz * (ol / 2 + 0.01)), Vector3.new(ow + 0.04, 0.14, 0.03), trim, DETAIL)
			end
		end
	else
		for _, sx in { -1, 1 } do
			Kit.box(m, at(sx * (ow / 2 + 0.01), h0 + oh - 0.25, zT), Vector3.new(0.02, 0.06, ol), trim, DETAIL)
		end
		Kit.box(m, at(0, h0 + oh - 0.25, zT - ol / 2 - 0.01), Vector3.new(ow, 0.06, 0.02), trim, DETAIL)
	end
	-- interior seat ledge + water + ice
	local Sy = h0 + 0.95
	local zSeat = zT - ol / 2 + 1.1
	Kit.box(m, at(0, Sy - 0.32, zSeat), Vector3.new(ow - wall * 2, 0.64, 1.2), wallF, SOLID)
	local water = h0 + 2.55
	Kit.box(m, at(0, (h0 + 0.3 + water) / 2, zT), Vector3.new(ow - wall * 2 - 0.02, water - h0 - 0.3, ol - wall * 2 - 0.02), F.Water, DETAIL)
	local ice = { { -0.8, 0.6, 15 }, { 0.6, 1.4, 40 }, { -0.3, 2.2, 70 }, { 0.9, -0.2, 20 }, { -0.9, 1.7, 55 }, { 0.2, 0.3, 5 } }
	for _, p in ice do
		Kit.box(m, at(p[1], water, zT + p[2]) * CFrame.Angles(0, math.rad(p[3]), math.rad(8)), Vector3.new(0.38, 0.32, 0.38), F.Ice, DETAIL)
	end
	-- spout at the front end
	local spoutF = if t == 4 then F.Brass elseif t == 5 then F.Gold else F.Titanium
	S.rod(c, m, pt(0, h0 + oh + 0.12, zT + ol / 2 - 0.15), pt(0, h0 + oh + 0.45, zT + ol / 2 - 0.15), 0.16, spoutF)
	S.rod(c, m, pt(0, h0 + oh + 0.45, zT + ol / 2 - 0.15), pt(0, h0 + oh + 0.3, zT + ol / 2 - 0.75), 0.14, spoutF)
	-- steps on the right side + grab rail
	local stepF = if t == 4 then F.OakSolid elseif t == 5 then F.Walnut else F.Carbon
	for i = 1, 2 do
		local hh = oh * i / 3
		Kit.box(m, at(ow / 2 + 0.95 - (i - 1) * 0.45, h0 + hh / 2, zT - 1.6), Vector3.new(1.4 - (i - 1) * 0.5, hh, 1.6), stepF, SOLID)
	end
	for _, z in { zT - 2.3, zT - 0.9 } do
		S.rod(c, m, pt(ow / 2 + 0.15, h0 + oh + 0.1, z), pt(ow / 2 + 0.15, h0 + oh + 1.1, z), 0.14, spoutF)
		Kit.ball(m, pt(ow / 2 + 0.15, h0 + oh + 1.1, z), 0.14, spoutF, DETAIL)
	end
	S.rod(c, m, pt(ow / 2 + 0.15, h0 + oh + 1.1, zT - 2.3), pt(ow / 2 + 0.15, h0 + oh + 1.1, zT - 0.9), 0.14, spoutF)
	-- corner trims (T4 stave joints, T5 gold edges) + rim thermometer
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Kit.box(m, at(sx * (ow / 2 - 0.02), h0 + oh / 2, zT + sz * (ol / 2 - 0.02)), Vector3.new(0.1, oh, 0.1), if t == 4 then F.OakSolid else trim, DETAIL)
		end
	end
	Kit.cylY(m, at(-ow / 2 + wall / 2, h0 + oh + 0.14, zT + 1.2), 0.06, 0.32, spoutF, DETAIL)
	Kit.cylY(m, at(-ow / 2 + wall / 2, h0 + oh + 0.18, zT + 1.2), 0.02, 0.24, F.FabricCream, DETAIL)
	-- chiller unit at the back left + towel bench
	local chF = if t == 5 then F.BlackChrome elseif t == 4 then F.PowderGraphite else F.Composite
	Kit.box(m, at(-ow / 2 - 0.75, h0 + 1.0, zT - ol / 2 + 0.9), Vector3.new(1.2, 2.0, 1.4), chF, SOLID)
	for i = 0, 3 do
		Kit.box(m, at(-ow / 2 - 0.75, h0 + 0.5 + i * 0.3, zT - ol / 2 + 0.19), Vector3.new(0.9, 0.06, 0.02), F.PlasticBlack, DETAIL)
	end
	Kit.box(m, at(-ow / 2 - 0.75, h0 + 1.75, zT - ol / 2 + 0.19), Vector3.new(0.6, 0.3, 0.02), S.SCREEN, DETAIL)
	S.cable(m, pt(-ow / 2 - 0.15, h0 + 0.4, zT - ol / 2 + 0.9), pt(-ow / 2, h0 + 0.4, zT - ol / 2 + 0.9), 0.14)
	towel(m, at(ow / 2 + 0.9, h0 + oh * 2 / 3, zT - 1.6), F.FabricWhite, trim)
	S.placard(c, m, at(0, h0 + oh - 0.6, zT + ol / 2 + 0.02), 1.2, S.NAMES.IceBath)
	c.E.userSpot(m, at(0, Sy + 1.3, zSeat))
	Kit.marker(m, "PromptPart", at(ow / 2 + 0.5, h0 + 3.0, zT - 0.5), Vector3.new(2, 2, 2))
end

return function(E: S.Lib)
	S.station(E, "YogaMat", yogaMat)
	S.station(E, "Sauna", sauna)
	S.station(E, "IceBath", iceBath)
end
