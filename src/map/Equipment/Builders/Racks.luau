--!strict
--[[
	Storage racks shared by stations and decor: the two-tier dumbbell rack
	(curl station + DumbbellRack decor).

	`base` is a floor-level CFrame at the rack centre; the rack runs along
	base.RightVector and its front (where people stand) faces base.LookVector.
]]

local Kit = require("../../Kit")
local S = require("./Shared")

local F = S.F
local DETAIL, SOLID = S.DETAIL, S.SOLID

local R = {}

-- Rest height (head centre above the shelf) for a dumbbell of class s.
local function restHeight(c: S.Ctx, s: number): number
	local hd = 0.46 + 0.34 * s
	if c.tier == 1 then
		return hd * 0.43
	elseif c.tier == 2 then
		return hd * 0.4
	end
	return hd / 2
end

local function headDia(s: number): number
	return 0.46 + 0.34 * s
end

--[[
	Fills a shelf (cf = shelf top centre, axes = shelf axes) with ascending pairs
	of dumbbells lying front-to-back (handles toward the user).
]]
local function fillShelf(c: S.Ctx, parent: Instance, shelf: CFrame, width: number, s0: number, s1: number, lite: boolean, float: boolean)
	-- how many pairs fit: average pitch from the mean head size
	local pitch = headDia((s0 + s1) / 2) + 0.16
	local pairs = math.max(1, math.floor(width / (pitch * 2)))
	local total = pairs * 2
	local used = 0
	local sizes = {}
	for p = 1, pairs do
		local s = if pairs == 1 then s0 else s0 + (s1 - s0) * (p - 1) / (pairs - 1)
		table.insert(sizes, s)
		used += (headDia(s) + 0.16) * 2
	end
	local x = -used / 2
	local lift = if float then 0.14 else 0
	for p = 1, pairs do
		local s = sizes[p]
		local step = headDia(s) + 0.16
		for _ = 1, 2 do
			x += step / 2
			local cf = shelf * CFrame.new(x, restHeight(c, s) + lift, 0) * CFrame.Angles(0, math.rad(90), 0)
			S.dumbbell(c, parent, cf, s, lite)
			x += step / 2
		end
	end
	local _ = total
end

--[[
	Two-tier dumbbell rack. len = length along RightVector (>= 3).
	Lower front shelf holds the heavy pairs, upper back shelf the light ones.
	lite = 3-part dumbbells (keeps long decor racks inside part budgets).
]]
function R.dumbbellRack(c: S.Ctx, parent: Instance, base: CFrame, len: number, lite: boolean?)
	local t, st = c.tier, c.st
	local function at(x: number, y: number, z: number): CFrame
		return base * CFrame.new(x, y, -z)
	end
	local function pt(x: number, y: number, z: number): Vector3
		return (base * CFrame.new(x, y, -z)).Position
	end
	local isLite = lite == true
	local tube = c.tr.tube * 0.9
	local tilt = CFrame.Angles(math.rad(-10), 0, 0)
	local lower = at(0, 1.05, 0.55) * tilt
	local upper = at(0, 2.25, -0.62) * tilt
	local inner = len - 0.5
	local railF = if t == 1 then F.PlasticCoral elseif t == 4 then F.OakSolid elseif t == 5 then F.Walnut elseif t == 6 then F.Composite else st.FrameAccent

	-- shelves: two saddle rails per shelf (T1: one moulded tray)
	for _, shelf in { lower, upper } do
		if t == 1 then
			Kit.box(parent, shelf * CFrame.new(0, -0.07, 0), Vector3.new(inner, 0.14, 1.5), railF, SOLID)
			Kit.box(parent, shelf * CFrame.new(0, 0.0, -0.78), Vector3.new(inner, 0.14, 0.08), F.PlasticTeal, DETAIL)
		else
			for _, sz in { -0.6, 0.6 } do
				Kit.box(parent, shelf * CFrame.new(0, -0.08, sz), Vector3.new(inner, 0.16, 0.34), railF, SOLID)
			end
			if t == 6 then
				Kit.box(parent, shelf * CFrame.new(0, -0.17, 0), Vector3.new(inner - 0.4, 0.03, 0.6), st.Light or F.LightCyan, DETAIL)
			elseif t == 5 then
				Kit.box(parent, shelf * CFrame.new(0, 0.005, -0.79), Vector3.new(inner, 0.04, 0.04), F.Gold, DETAIL)
			elseif t == 3 then
				Kit.box(parent, shelf * CFrame.new(0, -0.1, -0.78), Vector3.new(inner, 0.08, 0.02), F.PowderRed, DETAIL)
			end
		end
	end

	-- end frames (side profile: front post, back post, two sloped shelf arms)
	for _, sx in { -1, 1 } do
		local x = sx * (len / 2 - 0.2)
		if t == 6 then
			-- sculpted composite fin with a light seam
			local fin = Kit.wedge(parent, at(x, 1.35, -0.05) * CFrame.Angles(0, 0, 0), Vector3.new(0.18, 2.7, 2.7), F.Composite, SOLID)
			fin.Name = "Fin"
			S.glow(c, parent, pt(x - sx * 0.1, 0.25, 1.2), pt(x - sx * 0.1, 2.5, -1.3), 0.04)
		else
			S.tube(c, parent, pt(x, 0, 1.25), pt(x, 0.95, 1.25), tube)
			S.tube(c, parent, pt(x, 0, -1.3), pt(x, 2.45, -1.3), tube)
			S.tube(c, parent, pt(x, tube / 2, 1.35), pt(x, tube / 2, -1.4), tube)
			S.tube(c, parent, pt(x, 0.82, 1.25), pt(x, 1.27, -1.3), tube)
			S.tube(c, parent, pt(x, 1.05, 0.15), pt(x, 2.02, 0.15), tube)
			S.tube(c, parent, pt(x, 2.02, 0.15), pt(x, 2.27, -1.3), tube)
			S.cap(c, parent, pt(x, 0.98, 1.25), tube)
			S.cap(c, parent, pt(x, 2.48, -1.3), tube)
			S.foot(c, parent, at(x, 0, 1.25), 0.5, 0.5)
			S.foot(c, parent, at(x, 0, -1.3), 0.5, 0.5)
		end
	end
	if t ~= 6 then
		-- rear stretcher
		S.tube(c, parent, pt(-(len / 2 - 0.2), 0.5, -1.3), pt(len / 2 - 0.2, 0.5, -1.3), tube * 0.9)
	end

	local lift = c.tr.float
	fillShelf(c, parent, lower, inner - 0.2, 0.6, 1.0, isLite, lift)
	fillShelf(c, parent, upper, inner - 0.2, 0.08, 0.5, isLite, lift)
end

--[[
	Plyometric box standing on floor-level `base` (front = base.LookVector).
	T1 soft foam, T2 plywood with hand holds, T3 steel frame, T4 oak / T5 walnut
	with leather top + metal edges, T6 composite with a light line.
]]
function R.plyoBox(c: S.Ctx, parent: Instance, base: CFrame, w: number, h: number, d: number)
	local m, st, t = parent, c.st, c.tier
	local cf = base * CFrame.new(0, h / 2, 0)
	if t == 1 then
		-- soft foam: coral body, teal top, rounded top edges, white piping
		Kit.box(m, cf * CFrame.new(0, -0.1, 0), Vector3.new(w, h - 0.2, d), F.VinylCoral, SOLID)
		Kit.box(m, cf * CFrame.new(0, h / 2 - 0.15, 0), Vector3.new(w - 0.3, 0.3, d - 0.3), F.VinylTeal, SOLID)
		for _, sz in { -1, 1 } do
			Kit.cyl(m, cf * CFrame.new(0, h / 2 - 0.15, sz * (d / 2 - 0.15)), w - 0.3, 0.3, F.VinylTeal, DETAIL)
		end
		for _, sx in { -1, 1 } do
			Kit.cylZ(m, cf * CFrame.new(sx * (w / 2 - 0.15), h / 2 - 0.15, 0), d - 0.3, 0.3, F.VinylTeal, DETAIL)
		end
		Kit.box(m, cf * CFrame.new(0, h / 2 - 0.3, 0), Vector3.new(w + 0.02, 0.05, d + 0.02), F.FabricWhite, DETAIL)
	elseif t == 2 then
		Kit.box(m, cf, Vector3.new(w, h, d), F.Plywood, SOLID)
		for _, sx in { -1, 1 } do
			Kit.box(m, cf * CFrame.new(sx * (w / 2 + 0.005), h * 0.28, 0), Vector3.new(0.02, 0.28, 0.9), F.PlasticBlack, DETAIL)
		end
		Kit.box(m, cf * CFrame.new(0, h / 2 + 0.01, 0), Vector3.new(w - 0.2, 0.02, d - 0.2), F.RubberGrip, DETAIL)
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				S.bolt(c, m, cf * CFrame.new(sx * (w / 2 - 0.15), sy * (h / 2 - 0.15), -d / 2 - 0.01))
			end
		end
	elseif t == 5 or t == 4 then
		local body = if t == 5 then F.Walnut else F.OakSolid
		local trim = if t == 5 then F.Gold else F.Brass
		Kit.box(m, cf * CFrame.new(0, -0.15, 0), Vector3.new(w, h - 0.3, d), body, SOLID)
		S.pad(c, m, cf * CFrame.new(0, h / 2 - 0.15, 0), Vector3.new(w, 0.3, d), true)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				Kit.box(m, cf * CFrame.new(sx * (w / 2 - 0.02), -0.15, sz * (d / 2 - 0.02)), Vector3.new(0.08, h - 0.3, 0.08), trim, DETAIL)
			end
		end
		Kit.box(m, cf * CFrame.new(0, h / 2 - 0.31, 0), Vector3.new(w + 0.04, 0.04, d + 0.04), trim, DETAIL)
		Kit.box(m, cf * CFrame.new(0, -h / 2 + 0.03, 0), Vector3.new(w + 0.04, 0.06, d + 0.04), trim, DETAIL)
	else
		-- steel-framed (T3) / composite (T6): frame edges + panels + rubber top
		local panel = if t == 6 then F.Composite else F.PowderBlack
		local edge = if t == 6 then F.Titanium else st.Frame
		Kit.box(m, cf, Vector3.new(w - 0.1, h - 0.1, d - 0.1), panel, SOLID)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				Kit.box(m, cf * CFrame.new(sx * (w / 2 - 0.08), 0, sz * (d / 2 - 0.08)), Vector3.new(0.16, h, 0.16), edge, DETAIL)
			end
			Kit.box(m, cf * CFrame.new(sx * (w / 2 - 0.08), h / 2 - 0.08, 0), Vector3.new(0.16, 0.16, d), edge, DETAIL)
		end
		Kit.box(m, cf * CFrame.new(0, h / 2 + 0.02, 0), Vector3.new(w - 0.25, 0.04, d - 0.25), F.RubberGrip, DETAIL)
		local accent = if t == 6 then (st.Light or F.LightCyan) else F.PowderRed
		Kit.box(m, cf * CFrame.new(0, h * 0.2, -d / 2 + 0.03), Vector3.new(w - 0.3, 0.12, 0.04), accent, DETAIL)
	end
end

return R
