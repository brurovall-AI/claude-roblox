--!strict
--[[
	Decor equipment (not trainable): DumbbellRack, PlateTree, BarbellRack,
	KettlebellRack, MedBallRack, BenchFlat, Rig, PlyoBoxSet, DuelTable.

	cf is a floor-level CFrame. Racks and the rig run along cf.RightVector
	(length via opts.Length) with their front facing cf.LookVector. The duel
	table's long axis runs along cf.LookVector (markers added by Equipment).
	Local frame: x right, y up, z FORWARD.
]]

local Kit = require("../../Kit")
local S = require("./Shared")
local R = require("./Racks")

local F = S.F
local DETAIL, SOLID = S.DETAIL, S.SOLID

local function rotY(deg: number): CFrame
	return CFrame.Angles(0, math.rad(deg), 0)
end

local PURPLE = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(120, 84, 160) } :: S.Finish
local DARK_LEATHER = { Material = Enum.Material.Leather, Color = Color3.fromRGB(40, 44, 50) } :: S.Finish
-- competition kettlebell colours by weight (Beginner / Professional)
local KB_COMP = { F.PlasticCoral, F.FabricBlue, F.PlasticYellow, PURPLE, F.PlasticTeal, F.PowderRed }

---------------------------------------------------------------------------
-- Dumbbell rack
---------------------------------------------------------------------------
local function dumbbellRack(c: S.Ctx, o: S.DecorOpts)
	local len = math.max(3, o.Length or 8)
	R.dumbbellRack(c, c.model, c.at(0, 0, 0), len, len > 6 or c.tier <= 3)
end

---------------------------------------------------------------------------
-- Plate tree: three levels of horns at alternating orientations so the
-- plates never intersect (big front/back, medium sideways, small front/back).
---------------------------------------------------------------------------
local function plateTree(c: S.Ctx, _o: S.DecorOpts)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local tube = c.tr.tube * 1.1
	local H = 5.9
	-- base
	if t == 1 then
		Kit.cylY(m, at(0, 0.12, 0), 0.24, 3.0, F.RubberCoral, SOLID)
	elseif t == 6 then
		Kit.cylY(m, at(0, 0.05, 0), 0.1, 2.6, F.PlasticBlack, SOLID)
		Kit.cylY(m, at(0, 0.11, 0), 0.03, 2.8, c.st.Light or F.LightCyan, DETAIL)
		Kit.cylY(m, at(0, 0.24, 0), 0.22, 3.2, F.Carbon, SOLID)
	else
		for _, rot in { 0, 90 } do
			Kit.box(m, at(0, tube / 2, 0) * rotY(rot), Vector3.new(3.0, tube, tube), st.Frame, SOLID)
		end
		for _, p in { { 1.4, 0 }, { -1.4, 0 }, { 0, 1.4 }, { 0, -1.4 } } do
			S.foot(c, m, at(p[1], 0, p[2]), 0.45, 0.45)
		end
		if t == 5 then
			Kit.box(m, at(0, 0.2, 0), Vector3.new(1.0, 0.4, 1.0), F.MarbleDark, SOLID)
		end
	end
	S.tube(c, m, pt(0, 0, 0), pt(0, H, 0), tube)
	S.cap(c, m, pt(0, H, 0), tube)
	S.band(c, m, pt(0, H - 0.3, 0), tube)
	S.band(c, m, pt(0, 0.6, 0), tube)
	local levels = {
		{ y = 1.35, d = 2.5, t = 0.32, n = 3, axis = "z" },
		{ y = 3.55, d = 1.75, t = 0.26, n = 2, axis = "x" },
		{ y = 5.05, d = 1.15, t = 0.2, n = 2, axis = "z" },
	}
	for li, lv in levels do
		for _, s in { -1, 1 } do
			local hornLen = 0.25 + lv.n * (lv.t + 0.02) + 0.2
			local dir = if lv.axis == "z" then Vector3.new(0, 0, s) else Vector3.new(s, 0, 0)
			local a = pt(dir.X * tube / 2, lv.y, dir.Z * tube / 2)
			local b = pt(dir.X * (tube / 2 + hornLen), lv.y, dir.Z * (tube / 2 + hornLen))
			Kit.span(m, a, b, 0.26, st.Metal, DETAIL)
			for i = 1, lv.n do
				local off = tube / 2 + 0.2 + (i - 0.5) * (lv.t + 0.02)
				local cf = at(dir.X * off, lv.y, dir.Z * off)
				if lv.axis == "z" then
					cf *= rotY(90)
				end
				S.plate(c, m, cf, lv.d, lv.t, li + i)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Barbell rack: vertical storage with six bars standing in sleeves.
---------------------------------------------------------------------------
local function barbellRack(c: S.Ctx, _o: S.DecorOpts)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local baseF = if t == 4 then F.OakSolid elseif t == 5 then F.Walnut elseif t == 6 then F.Composite elseif t == 1 then F.PowderWhite else st.Frame
	Kit.box(m, at(0, 0.45, 0.2), Vector3.new(3.2, 0.9, 1.5), baseF, SOLID)
	Kit.box(m, at(0, 0.91, 0.2), Vector3.new(3.24, 0.04, 1.54), if t >= 4 then st.Trim else F.PlasticBlack, DETAIL)
	-- back post + top bracket
	S.tube(c, m, pt(0, 0.9, -0.75), pt(0, 6.0, -0.75), c.tr.tube * 1.1)
	S.cap(c, m, pt(0, 6.0, -0.75))
	S.tube(c, m, pt(-1.5, 5.5, -0.75), pt(1.5, 5.5, -0.75), c.tr.tube)
	local _, sleeveF, collarF = (function(): (S.Finish, S.Finish, S.Finish)
		if t == 5 then
			return F.BlackChrome, F.Gold, F.Gold
		elseif t == 4 then
			return F.SteelBrushed, F.SteelBrushed, F.Brass
		elseif t == 6 then
			return F.Titanium, F.Titanium, (st.Light or F.LightCyan)
		elseif t == 3 then
			return F.Chrome, F.Chrome, F.PowderRed
		end
		return F.Steel, F.Steel, F.SteelDark
	end)()
	local shaftF = if t == 5 then F.BlackChrome elseif t == 6 then F.Titanium else st.Metal
	for i = 0, 5 do
		local x = -1.25 + i * 0.5
		local z = if i % 2 == 0 then 0.45 else -0.05
		Kit.cylY(m, at(x, 0.93, z), 0.04, 0.36, F.PlasticBlack, DETAIL)
		local lean = CFrame.Angles(math.rad(-4), 0, 0)
		local b = at(x, 0.95, z) * lean
		Kit.cylY(m, b * CFrame.new(0, 0.12, 0), 0.24, 0.44, collarF, DETAIL)
		Kit.cylY(m, b * CFrame.new(0, 2.5, 0), 4.6, 0.17, shaftF, DETAIL)
		Kit.cylY(m, b * CFrame.new(0, 4.85, 0), 0.1, 0.44, collarF, DETAIL)
		Kit.cylY(m, b * CFrame.new(0, 5.6, 0), 1.4, 0.27, sleeveF, DETAIL)
	end
	-- retaining hooks on the top bracket
	for i = 0, 5 do
		Kit.box(m, at(-1.25 + i * 0.5, 5.5, -0.5), Vector3.new(0.06, 0.12, 0.4), st.FrameAccent, DETAIL)
	end
end

---------------------------------------------------------------------------
-- Kettlebell rack: two shelves, ascending sizes left to right.
---------------------------------------------------------------------------
local function kettlebell(c: S.Ctx, parent: Instance, cf: CFrame, s: number, idx: number)
	local t = c.tier
	local d = 0.62 + 0.42 * s
	local bodyF: S.Finish = if t == 1 then KB_COMP[(idx - 1) % 3 + 1] elseif t == 3 then KB_COMP[(idx - 1) % #KB_COMP + 1] elseif t == 5 then F.BlackChrome elseif t == 6 then F.Composite else F.CastIron
	local handleF = if t == 4 then F.Brass elseif t == 5 then F.Gold elseif t == 6 then F.Titanium elseif t == 3 then F.SteelBrushed else F.SteelDark
	Kit.ball(parent, cf * CFrame.new(0, d / 2, 0), d, bodyF, DETAIL)
	Kit.cylY(parent, cf * CFrame.new(0, 0.04, 0), 0.08, d * 0.62, bodyF, DETAIL)
	local hw, hh = d * 0.62, 0.42 + 0.2 * s
	for _, sx in { -1, 1 } do
		Kit.box(parent, cf * CFrame.new(sx * hw / 2, d * 0.85 + hh / 2 - 0.05, 0), Vector3.new(0.12, hh, 0.12), handleF, DETAIL)
	end
	Kit.cyl(parent, cf * CFrame.new(0, d * 0.85 + hh - 0.05, 0), hw + 0.12, 0.13, handleF, DETAIL)
	if t == 6 then
		Kit.cylY(parent, cf * CFrame.new(0, d / 2, 0), 0.04, d + 0.02, c.st.Light or F.LightCyan, DETAIL)
	end
end

local function kettlebellRack(c: S.Ctx, o: S.DecorOpts)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local len = math.max(3, o.Length or 6)
	local shelfF = if t == 4 then F.OakSolid elseif t == 5 then F.Walnut elseif t == 6 then F.Composite elseif t == 1 then F.PlasticCoral else st.FrameAccent
	local shelves = { { y = 0.55, z = 0.3, s0 = 0.6, s1 = 1.0 }, { y = 2.0, z = -0.25, s0 = 0.05, s1 = 0.5 } }
	for _, sh in shelves do
		Kit.box(m, at(0, sh.y - 0.08, sh.z), Vector3.new(len - 0.3, 0.16, 1.25), shelfF, SOLID)
		Kit.box(m, at(0, sh.y + 0.05, sh.z + 0.62), Vector3.new(len - 0.3, 0.12, 0.06), if t >= 4 then st.Trim else st.Frame, DETAIL)
	end
	for _, sx in { -1, 1 } do
		local x = sx * (len / 2 - 0.1)
		S.tube(c, m, pt(x, 0, 0.85), pt(x, 0.55, 0.85))
		S.tube(c, m, pt(x, 0, -0.85), pt(x, 2.0, -0.85))
		S.tube(c, m, pt(x, 0.45, 0.85), pt(x, 0.45, -0.85))
		S.tube(c, m, pt(x, 1.9, 0.3), pt(x, 1.9, -0.85))
		S.tube(c, m, pt(x, 0.45, 0.3), pt(x, 1.9, 0.3))
		S.cap(c, m, pt(x, 2.0, -0.85))
		S.foot(c, m, at(x, 0, 0.85), 0.45, 0.45)
		S.foot(c, m, at(x, 0, -0.85), 0.45, 0.45)
	end
	local idx = 0
	for _, sh in shelves do
		local n = math.max(2, math.floor((len - 0.6) / (0.62 + 0.42 * (sh.s0 + sh.s1) / 2 + 0.2)))
		local used = 0
		local sizes = {}
		for i = 1, n do
			local s = sh.s0 + (sh.s1 - sh.s0) * (i - 1) / math.max(1, n - 1)
			sizes[i] = s
			used += 0.62 + 0.42 * s + 0.18
		end
		local x = -used / 2
		for i = 1, n do
			local w = 0.62 + 0.42 * sizes[i] + 0.18
			x += w / 2
			idx += 1
			kettlebell(c, m, at(x, sh.y, sh.z), sizes[i], idx)
			x += w / 2
		end
	end
end

---------------------------------------------------------------------------
-- Med ball rack: A-frame ladder with three cradle tiers.
---------------------------------------------------------------------------
local function medBallRack(c: S.Ctx, _o: S.DecorOpts)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local W = 4.2
	local ballF: { S.Finish } = if t == 1 then { F.PlasticCoral, F.PlasticTeal, F.PlasticYellow }
		elseif t == 3 then { F.VinylRed, F.VinylBlack, F.VinylRed }
		elseif t == 4 then { F.LeatherTan, F.LeatherCognac, F.LeatherTan }
		elseif t == 5 then { F.LeatherBlack, F.LeatherBlack, F.LeatherBlack }
		elseif t == 6 then { F.Composite, F.Carbon, F.Composite }
		else { F.Rubber, F.RubberGrip, F.Rubber }
	local bandF = if t == 4 then F.Brass elseif t == 5 then F.Gold elseif t == 6 then (st.Light or F.LightCyan) elseif t == 1 then F.FabricWhite else F.PowderYellow
	for _, sx in { -1, 1 } do
		local x = sx * W / 2
		S.tube(c, m, pt(x, 0, 0.9), pt(x, 5.8, 0.15))
		S.tube(c, m, pt(x, 0, -0.9), pt(x, 5.8, -0.15))
		S.cap(c, m, pt(x, 5.85, 0))
		S.foot(c, m, at(x, 0, 0.9), 0.4, 0.5)
		S.foot(c, m, at(x, 0, -0.9), 0.4, 0.5)
	end
	for tier = 0, 2 do
		local y = 0.9 + tier * 1.7
		local zf = 0.9 - (y / 5.8) * 0.75
		for _, sz in { -1, 1 } do
			S.tube(c, m, pt(-W / 2, y, sz * (zf - 0.25)), pt(W / 2, y, sz * (zf - 0.25)), c.tr.tube * 0.8)
		end
		for i, x in { -1.0, 1.0 } do
			local d = 1.25 - tier * 0.12
			local cf = at(x, y + d / 2 - 0.05, 0)
			Kit.ball(m, cf, d, ballF[(tier + i) % 3 + 1], DETAIL)
			Kit.cyl(m, cf * CFrame.Angles(0, 0, math.rad(90)) * rotY(i * 30), 0.08, d + 0.02, bandF, DETAIL)
		end
	end
end

---------------------------------------------------------------------------
-- Flat bench (utility): pad on a spine, transport wheels + handle.
---------------------------------------------------------------------------
local function benchFlat(c: S.Ctx, _o: S.DecorOpts)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local tube = c.tr.tube
	local P = 1.55
	local padH = if t == 1 then 0.46 else 0.4
	S.pad(c, m, at(0, P - padH / 2, 0), Vector3.new(if t == 1 then 1.75 else 1.6, padH, 4.3))
	local ySp = P - padH - 0.1 - tube / 2
	S.tube(c, m, pt(0, ySp, -1.9), pt(0, ySp, 1.9))
	for _, z in { -1.6, 1.6 } do
		S.tube(c, m, pt(0, tube / 2, z), pt(0, ySp, z))
		S.tube(c, m, pt(-0.95, tube / 2, z), pt(0.95, tube / 2, z))
		for _, sx in { -1, 1 } do
			S.foot(c, m, at(sx * 0.95, 0, z), 0.45, 0.5)
		end
	end
	if t >= 2 then
		-- wheels at the head end, handle at the foot end
		for _, sx in { -1, 1 } do
			Kit.cyl(m, at(sx * 1.08, 0.22, -1.6), 0.14, 0.44, F.Rubber, DETAIL)
		end
		S.rod(c, m, pt(0, ySp, 1.9), pt(0, 0.8, 2.4), 0.16, st.Metal)
		Kit.cyl(m, at(0, 0.8, 2.4), 0.8, 0.22, st.Grip, DETAIL)
	end
	if t == 6 then
		S.glow(c, m, pt(0, ySp - tube / 2 - 0.01, -1.6), pt(0, ySp - tube / 2 - 0.01, 1.6), 0.04)
	end
end

---------------------------------------------------------------------------
-- Rig: functional training rig. Bays ~4 wide, pull-up bars front + back,
-- J-hooks and safety arms on the front uprights, plate horns at the back,
-- monkey-bar rungs over the middle bay.
---------------------------------------------------------------------------
local function rig(c: S.Ctx, o: S.DecorOpts)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local len = math.max(4, o.Length or 12)
	local bays = math.max(1, math.floor(len / 4 + 0.5))
	local bw = len / bays
	local tube = c.tr.tube * 1.15
	local H = 9.0
	local zF, zB = 1.9, -1.9
	for i = 0, bays do
		local x = -len / 2 + i * bw
		for _, z in { zF, zB } do
			S.tube(c, m, pt(x, 0, z), pt(x, H, z), tube)
			S.cap(c, m, pt(x, H, z), tube)
			S.foot(c, m, at(x, 0, z), 0.6, 0.6)
			S.band(c, m, pt(x, 0.5, z), tube)
		end
		S.tube(c, m, pt(x, H - tube / 2, zF), pt(x, H - tube / 2, zB), tube)
		S.tube(c, m, pt(x, tube / 2, zF), pt(x, tube / 2, zB), tube)
		-- hole column on the front face
		Kit.box(m, at(x, 4.4, zF + tube / 2 + 0.005), Vector3.new(0.08, 6.6, 0.02), if t == 6 then (st.Light or F.LightCyan) else F.Iron, DETAIL)
		-- plate horn on the back face
		if i > 0 and i < bays or bays == 1 then
			Kit.cylZ(m, at(x, 1.3, zB - tube / 2 - 0.45), 0.9, 0.24, st.Metal, DETAIL)
		end
	end
	for _, z in { zF, zB } do
		S.tube(c, m, pt(-len / 2, H - tube / 2, z), pt(len / 2, H - tube / 2, z), tube)
	end
	-- per bay: pull-up bars, J-hooks
	for b = 0, bays - 1 do
		local x0 = -len / 2 + b * bw
		Kit.cyl(m, at(x0 + bw / 2, H - 0.75, zF + 0.4), bw - tube, 0.2, st.Metal, DETAIL)
		Kit.cyl(m, at(x0 + bw / 2, H - 0.75, zB - 0.4), bw - tube, 0.2, st.Metal, DETAIL)
		for _, sx in { 0, 1 } do
			local x = x0 + sx * bw
			Kit.box(m, at(x - (sx * 2 - 1) * 0.0, 4.4, zF + tube / 2 + 0.2), Vector3.new(0.3, 0.14, 0.4), if t == 4 then F.Brass elseif t == 5 then F.Gold else F.Chrome, DETAIL)
		end
	end
	-- monkey-bar rungs over the middle bay
	local mb = math.floor(bays / 2)
	local mx0 = -len / 2 + mb * bw
	for k = 1, 3 do
		local x = mx0 + bw * k / 4
		S.rod(c, m, pt(x, H - tube / 2, zF), pt(x, H - tube / 2, zB), 0.18, st.Metal)
	end
	if t >= 4 then
		local f = if t == 4 then F.OakSolid elseif t == 5 then F.Walnut else F.Composite
		Kit.box(m, at(0, H - tube / 2, zF + tube / 2 + 0.03), Vector3.new(math.min(len - 1, 5), tube * 0.8, 0.05), f, DETAIL)
		S.placard(c, m, at(0, H - tube / 2, zF + tube / 2 + 0.07), 1.5, "TRAINING RIG")
	end
end

---------------------------------------------------------------------------
-- Plyo box set: three heights in a stair arrangement.
---------------------------------------------------------------------------
local function plyoBoxSet(c: S.Ctx, _o: S.DecorOpts)
	local at = c.at
	R.plyoBox(c, c.model, at(-2.2, 0, 0), 2.2, 1.2, 2.0)
	R.plyoBox(c, c.model, at(0, 0, 0), 2.2, 1.8, 2.0)
	R.plyoBox(c, c.model, at(2.2, 0, 0), 2.2, 2.4, 2.0)
end

---------------------------------------------------------------------------
-- Duel table (arm wrestling): top at 3.2, long axis along the LookVector,
-- elbow pads either side of the centre line, hand pegs, pin pads, foot rail.
---------------------------------------------------------------------------
local function duelTable(c: S.Ctx, _o: S.DecorOpts)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local top = 3.2
	local tw, tl, tt = 2.5, 3.1, 0.24
	local topF = if t == 4 then F.OakSolid elseif t == 5 then F.Walnut elseif t == 6 then F.Composite elseif t == 1 then F.PowderWhite elseif t == 3 then F.PowderGraphite else F.PowderBlack
	local padF = if t == 1 then F.VinylCoral elseif t == 3 then F.VinylRed elseif t == 4 then F.LeatherTan elseif t == 5 then F.LeatherBlack elseif t == 6 then DARK_LEATHER else F.VinylBlack
	local metalF = if t == 4 then F.Brass elseif t == 5 then F.Gold elseif t == 6 then F.Titanium elseif t == 1 then F.PlasticTeal else F.Chrome
	-- top + edge band
	Kit.box(m, at(0, top - tt / 2, 0), Vector3.new(tw, tt, tl), topF, SOLID)
	Kit.box(m, at(0, top - tt - 0.04, 0), Vector3.new(tw + 0.08, 0.08, tl + 0.08), if t >= 4 then st.Trim else st.Frame, DETAIL)
	-- centre line across the table (between the competitors)
	Kit.box(m, at(0, top + 0.005, 0), Vector3.new(tw - 0.2, 0.01, 0.06), if t == 6 then (st.Light or F.LightCyan) else F.FabricWhite, DETAIL)
	-- elbow pads (one per side of the line)
	for _, sz in { -1, 1 } do
		S.pad(c, m, at(0, top + 0.07, sz * 0.75), Vector3.new(0.8, 0.14, 0.8), true)
	end
	-- pin pads along the lateral edges
	for _, sx in { -1, 1 } do
		Kit.box(m, at(sx * (tw / 2 - 0.2), top + 0.08, 0), Vector3.new(0.3, 0.16, 1.3), padF, DETAIL)
	end
	-- hand pegs (vertical grips), one on each competitor's free-hand side
	for _, p in { { -0.95, 1.05 }, { 0.95, -1.05 }, { 0.95, 1.05 }, { -0.95, -1.05 } } do
		Kit.cylY(m, at(p[1], top + 0.45, p[2]), 0.9, 0.22, metalF, DETAIL)
		Kit.cylY(m, at(p[1], top + 0.92, p[2]), 0.06, 0.3, metalF, DETAIL)
		Kit.cylY(m, at(p[1], top + 0.03, p[2]), 0.06, 0.36, metalF, DETAIL)
	end
	-- sturdy base: pedestal (T1, T6) or splayed four-leg steel frame
	if t == 1 or t == 6 then
		local bf = if t == 1 then F.PowderWhite else F.Composite
		Kit.box(m, at(0, (top - tt) / 2 + 0.2, 0), Vector3.new(1.1, top - tt - 0.4, 1.4), bf, SOLID)
		Kit.box(m, at(0, 0.15, 0), Vector3.new(2.2, 0.3, 2.6), if t == 1 then F.RubberCoral else F.Carbon, SOLID)
		if t == 6 then
			Kit.box(m, at(0, 0.33, 0), Vector3.new(2.0, 0.04, 2.4), st.Light or F.LightCyan, DETAIL)
		end
	else
		local tube = c.tr.tube * 1.1
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				S.tube(c, m, pt(sx * 1.05, 0, sz * 1.3), pt(sx * 0.8, top - tt, sz * 1.0), tube)
				S.foot(c, m, at(sx * 1.05, 0, sz * 1.3), 0.5, 0.5)
			end
			S.tube(c, m, pt(sx * 0.92, 1.3, -1.15), pt(sx * 0.92, 1.3, 1.15), tube * 0.8)
		end
		for _, sz in { -1, 1 } do
			-- foot rails at each competitor's end
			S.tube(c, m, pt(-1.0, 0.6, sz * 1.22), pt(1.0, 0.6, sz * 1.22), tube * 0.8, metalF)
		end
		if t == 5 then
			Kit.box(m, at(0, 0.15, 0), Vector3.new(2.6, 0.3, 3.2), F.MarbleDark, SOLID)
		end
	end
	S.placard(c, m, at(0, top - tt / 2, tl / 2 + 0.02) * rotY(180), 0.9, "ARM WRESTLING")
end

return function(E: S.Lib)
	S.decor(E, "DumbbellRack", dumbbellRack)
	S.decor(E, "PlateTree", plateTree)
	S.decor(E, "BarbellRack", barbellRack)
	S.decor(E, "KettlebellRack", kettlebellRack)
	S.decor(E, "MedBallRack", medBallRack)
	S.decor(E, "BenchFlat", benchFlat)
	S.decor(E, "Rig", rig)
	S.decor(E, "PlyoBoxSet", plyoBoxSet)
	S.decor(E, "DuelTable", duelTable)
end
