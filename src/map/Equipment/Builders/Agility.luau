--!strict
--[[
	Agility & combat stations: AgilityLadder, SpeedBag, HeavyBag, PlyoBox.

	Bags hang inside a Swinger (pivot at the swivel / chain hook, swinging about
	the local X axis toward the trainee). Local frame: x right, y up, z FORWARD.
]]

local Kit = require("../../Kit")
local S = require("./Shared")
local R = require("./Racks")

local F = S.F
local DETAIL, SOLID = S.DETAIL, S.SOLID

-- Training cone (two tapered cylinders + square base). cf = floor point.
local function cone(parent: Instance, cf: CFrame, f: Kit.FinishArg)
	Kit.box(parent, cf * CFrame.new(0, 0.03, 0), Vector3.new(0.62, 0.06, 0.62), f, DETAIL)
	Kit.cylY(parent, cf * CFrame.new(0, 0.3, 0), 0.5, 0.42, f, DETAIL)
	Kit.cylY(parent, cf * CFrame.new(0, 0.66, 0), 0.26, 0.22, f, DETAIL)
end

-- Mini hurdle across the lane (cf = floor centre).
local function hurdle(c: S.Ctx, parent: Instance, cf: CFrame, w: number, f: Kit.FinishArg)
	for _, sx in { -1, 1 } do
		Kit.box(parent, cf * CFrame.new(sx * w / 2, 0.35, 0), Vector3.new(0.12, 0.7, 0.12), f, DETAIL)
		Kit.box(parent, cf * CFrame.new(sx * w / 2, 0.03, 0), Vector3.new(0.14, 0.06, 0.6), f, DETAIL)
	end
	Kit.box(parent, cf * CFrame.new(0, 0.66, 0), Vector3.new(w, 0.1, 0.1), f, DETAIL)
	local _ = c
end

---------------------------------------------------------------------------
-- AgilityLadder: ladder on a lane mat, cones and mini hurdles at the far end.
---------------------------------------------------------------------------
local function agilityLadder(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at = c.at
	local L, W = 15.4, 3.6
	local h0 = S.plinth(c, m, at(0, 0, 0), W + 0.4, L + 0.4)
	local matF = if t == 1 then F.RubberTeal elseif t == 2 then F.RubberFloor elseif t == 3 then F.TurfDark elseif t == 5 then F.WalnutPlanks elseif t == 6 then F.Carbon else F.RubberFleck
	Kit.box(m, at(0, h0 + 0.04, 0), Vector3.new(W, 0.08, L), matF, SOLID)
	local edgeF = if t == 1 then F.RubberCoral elseif t == 5 then F.Gold elseif t == 6 then (st.Light or F.LightCyan) elseif t == 3 then F.FabricWhite else F.PowderYellow
	for _, sx in { -1, 1 } do
		Kit.box(m, at(sx * (W / 2 - 0.1), h0 + 0.085, 0), Vector3.new(0.08, 0.01, L - 0.2), edgeF, DETAIL)
	end
	-- ladder: two straps + flat rungs
	local z0, z1 = -5.6, 5.4
	local lw = 1.9
	local strapF = if t == 5 then F.LeatherBlack elseif t == 6 then F.Composite elseif t == 1 then F.PlasticCoral else F.PlasticBlack
	local rungF = if t == 1 then F.PlasticYellow elseif t == 2 then F.PowderYellow elseif t == 3 then F.PowderRed elseif t == 4 then F.Brass elseif t == 5 then F.Gold else F.Titanium
	local y = h0 + 0.09
	for _, sx in { -1, 1 } do
		Kit.box(m, at(sx * lw / 2, y + 0.015, (z0 + z1) / 2), Vector3.new(0.12, 0.03, z1 - z0), strapF, DETAIL)
	end
	local n = 10
	for i = 0, n do
		local z = z0 + (z1 - z0) * i / n
		Kit.box(m, at(0, y + 0.025, z), Vector3.new(lw + 0.08, 0.05, 0.16), rungF, DETAIL)
	end
	-- start + finish lines
	Kit.box(m, at(0, y + 0.002, z0 - 0.9), Vector3.new(W - 0.6, 0.01, 0.14), edgeF, DETAIL)
	-- cones beside the ladder, hurdles beyond it
	local coneF = if t == 1 then F.PlasticCoral elseif t == 3 then F.PowderRed elseif t == 5 then F.Gold elseif t == 6 then F.Composite else F.PlasticYellow
	if t ~= 6 then
		for _, p in { { -1.4, -3.0 }, { 1.4, -0.5 }, { -1.4, 2.0 }, { 1.4, 4.5 } } do
			cone(m, at(p[1], y, p[2]), coneF)
		end
	end
	if t >= 2 then
		local hf = if t == 5 then F.BlackChrome elseif t == 6 then F.Composite else st.FrameAccent
		hurdle(c, m, at(0, y, 6.4), 2.0, hf)
		hurdle(c, m, at(0, y, 7.2), 2.0, hf)
	end
	if t >= 5 then
		-- entry bollards with crowns
		for _, sx in { -1, 1 } do
			local px = sx * (W / 2 - 0.35)
			Kit.cylY(m, at(px, y + 0.6, -L / 2 + 0.5), 1.2, 0.36, if t == 6 then F.Composite else F.BlackChrome, SOLID)
			Kit.cylY(m, at(px, y + 1.24, -L / 2 + 0.5), 0.08, 0.42, if t == 6 then (st.Light or F.LightCyan) else F.Gold, DETAIL)
			Kit.cylY(m, at(px, y + 0.03, -L / 2 + 0.5), 0.06, 0.5, if t == 6 then F.Titanium else F.Gold, DETAIL)
		end
	end
	-- sign post at the start
	S.tube(c, m, c.pt(-W / 2 + 0.35, y, -L / 2 + 0.35), c.pt(-W / 2 + 0.35, y + 1.6, -L / 2 + 0.35), 0.14, st.Frame, false)
	S.placard(c, m, at(-W / 2 + 0.35, y + 1.75, -L / 2 + 0.28) * CFrame.Angles(0, math.rad(180), 0), 1.0, S.NAMES.AgilityLadder)
	c.E.standingSpot(m, at(0, y, z0 - 1.5))
end

---------------------------------------------------------------------------
-- SpeedBag: rebound board on a free-standing post; bag in a Swinger.
---------------------------------------------------------------------------
local function speedBag(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local h0 = S.plinth(c, m, at(0, 0, 0.9), 4.6, 4.6)
	local boardY = h0 + 6.05
	local zSw = 1.15
	local zPost = 2.7
	local tube = c.tr.tube * 1.2
	-- base + post + adjustment sleeve
	Kit.box(m, at(0, h0 + 0.12, zPost - 0.2), Vector3.new(2.6, 0.24, 1.8), st.Frame, SOLID)
	for _, sx in { -1, 1 } do
		S.foot(c, m, at(sx * 1.1, h0, zPost - 0.9), 0.45, 0.45)
		S.foot(c, m, at(sx * 1.1, h0, zPost + 0.5), 0.45, 0.45)
	end
	S.tube(c, m, pt(0, h0 + 0.24, zPost), pt(0, boardY - 0.3, zPost), tube)
	S.tube(c, m, pt(0, h0 + 3.2, zPost), pt(0, h0 + 4.4, zPost), tube + 0.12, st.FrameAccent)
	S.knob(c, m, at(0, h0 + 3.8, zPost - (tube + 0.12) / 2 - 0.05))
	S.band(c, m, pt(0, h0 + 4.45, zPost), tube + 0.12)
	-- bracket arms to the board
	for _, sx in { -1, 1 } do
		S.tube(c, m, pt(sx * 0.6, boardY - 0.3, zPost), pt(sx * 0.6, boardY - 0.3, zSw + 0.2), 0.2, st.Frame)
	end
	S.tube(c, m, pt(-0.6, boardY - 0.3, zPost), pt(0.6, boardY - 0.3, zPost), 0.24, st.Frame)
	S.tube(c, m, pt(0, boardY - 1.3, zPost), pt(0, boardY - 0.35, zPost - 0.9), 0.18, st.Frame, false)
	-- rebound board (round) with rim
	local boardF = if t == 4 then F.OakSolid elseif t == 5 then F.Walnut elseif t == 6 then F.Composite else F.PlasticBlack
	local rimF = if t == 3 then F.PowderRed elseif t == 4 then F.Brass elseif t == 5 then F.Gold elseif t == 6 then (st.Light or F.LightCyan) else F.SteelDark
	local bcf = at(0, boardY, zSw + 0.45)
	Kit.cylY(m, bcf, 0.32, 3.1, boardF, SOLID)
	Kit.cylY(m, bcf * CFrame.new(0, -0.17, 0), 0.04, 3.16, rimF, DETAIL)
	Kit.cylY(m, bcf * CFrame.new(0, 0.18, 0), 0.04, 2.0, rimF, DETAIL)
	-- swivel + bag (Swinger)
	local swF = if t == 4 then F.Brass elseif t == 5 then F.Gold else F.Chrome
	Kit.cylY(m, at(0, boardY - 0.22, zSw), 0.12, 0.3, swF, DETAIL)
	local pivot = at(0, boardY - 0.3, zSw)
	local sw = c.E.swinger(m, pivot)
	local bagF = if t == 4 then F.LeatherTan elseif t == 5 then F.LeatherBlack elseif t == 6 then F.Composite else F.VinylRed
	Kit.cylY(sw, pivot * CFrame.new(0, -0.12, 0), 0.24, 0.08, swF, DETAIL)
	Kit.cylY(sw, pivot * CFrame.new(0, -0.32, 0), 0.22, 0.32, bagF, DETAIL)
	Kit.cylY(sw, pivot * CFrame.new(0, -0.62, 0), 0.5, 0.72, bagF, DETAIL)
	Kit.ball(sw, pivot * CFrame.new(0, -0.88, 0), 0.72, bagF, DETAIL)
	Kit.cylY(sw, pivot * CFrame.new(0, -0.62, 0), 0.06, 0.74, if t == 4 then F.FabricCream else F.PlasticBlack, DETAIL)
	-- spare bag on a hook + a pair of gloves resting on the base
	Kit.box(m, at(0, h0 + 2.7, zPost - tube / 2 - 0.12), Vector3.new(0.08, 0.08, 0.26), swF, DETAIL)
	Kit.cylY(m, at(0, h0 + 2.35, zPost - tube / 2 - 0.3), 0.5, 0.62, bagF, DETAIL)
	Kit.ball(m, at(0, h0 + 2.05, zPost - tube / 2 - 0.3), 0.62, bagF, DETAIL)
	local gloveF = if t == 4 then F.LeatherCognac elseif t == 5 then F.LeatherBlack elseif t == 6 then F.Composite else F.VinylRed
	for _, sx in { -1, 1 } do
		local g = at(sx * 0.7, h0 + 0.24, zPost + 0.3) * CFrame.Angles(0, math.rad(sx * 20), 0)
		Kit.box(m, g * CFrame.new(0, 0.22, 0), Vector3.new(0.55, 0.44, 0.7), gloveF, DETAIL)
		Kit.box(m, g * CFrame.new(0, 0.18, 0.42), Vector3.new(0.5, 0.36, 0.2), F.FabricWhite, DETAIL)
	end
	if t >= 4 then
		-- round timer bell on the post, oak base cladding, towel on the bracket
		Kit.cylZ(m, at(0, h0 + 4.9, zPost - tube / 2 - 0.08), 0.14, 0.6, swF, DETAIL)
		Kit.cylZ(m, at(0, h0 + 4.9, zPost - tube / 2 - 0.16), 0.02, 0.48, F.FabricCream, DETAIL)
		Kit.box(m, at(0, h0 + 0.25, zPost - 0.2), Vector3.new(2.62, 0.04, 1.82), F.OakSolid, DETAIL)
		Kit.box(m, at(0.6, boardY - 0.75, zPost - 0.6), Vector3.new(0.12, 0.8, 0.5), F.FabricWhite, DETAIL)
		Kit.box(m, at(0, h0 + 2.0, zPost + tube / 2 + 0.2), Vector3.new(1.0, 0.08, 0.4), st.FrameAccent, DETAIL)
	end
	S.placard(c, m, at(0, h0 + 0.12, zPost - 1.12), 1.3, S.NAMES.SpeedBag)
	c.E.standingSpot(m, at(0, h0, 0))
end

---------------------------------------------------------------------------
-- HeavyBag: bag on a cantilever stand; bag + chains in a Swinger.
---------------------------------------------------------------------------
local function heavyBag(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at, pt = c.at, c.pt
	local h0 = S.plinth(c, m, at(0, 0, 0.6), 5.6, 5.8)
	local zBag, zMast = 0.4, 2.75
	local boomY = h0 + 8.6
	local tube = c.tr.tube * 1.3
	-- H-base with counterweight horns, mast, boom with gusset
	S.tube(c, m, pt(-2.0, h0 + tube / 2, zMast), pt(2.0, h0 + tube / 2, zMast), tube)
	for _, sx in { -1, 1 } do
		S.tube(c, m, pt(sx * 2.0, h0 + tube / 2, zMast + 0.8), pt(sx * 2.0, h0 + tube / 2, zBag - 0.9), tube)
		S.foot(c, m, at(sx * 2.0, h0, zMast + 0.7), 0.6, 0.6)
		S.foot(c, m, at(sx * 2.0, h0, zBag - 0.8), 0.6, 0.6)
		-- counterweight plates on the back corners
		Kit.cylY(m, at(sx * 1.3, h0 + 0.6, zMast + 0.5), 1.0, 0.24, st.Metal, DETAIL)
		for i = 1, 2 do
			S.plate(c, m, at(sx * 1.3, h0 + 0.2 + (i - 1) * 0.34, zMast + 0.5) * CFrame.Angles(0, 0, math.rad(90)), 1.9, 0.3, i)
		end
	end
	S.tube(c, m, pt(0, h0, zMast), pt(0, boomY + 0.2, zMast), tube * 1.15)
	S.cap(c, m, pt(0, boomY + 0.2, zMast), tube * 1.15)
	S.tube(c, m, pt(0, boomY, zMast + 0.2), pt(0, boomY, zBag - 0.4), tube)
	S.tube(c, m, pt(0, boomY - 1.6, zMast), pt(0, boomY - 0.1, zMast - 1.4), tube * 0.7)
	for _, y in { h0 + 0.6, boomY - 0.6 } do
		S.band(c, m, pt(0, y, zMast), tube * 1.15)
	end
	if t == 6 then
		S.glow(c, m, pt(0, h0 + 0.5, zMast - tube * 0.58), pt(0, boomY - 0.4, zMast - tube * 0.58), 0.04)
	end
	-- hook + swivel
	local hookF = if t == 4 then F.Brass elseif t == 5 then F.Gold else F.Chrome
	Kit.cylY(m, at(0, boomY - 0.32, zBag), 0.3, 0.2, hookF, DETAIL)
	local pivot = at(0, boomY - 0.5, zBag)
	local sw = c.E.swinger(m, pivot)
	-- four chains to the bag top
	local bagTop = h0 + 6.05
	local bagH, bagD = 4.2, 1.7
	for i = 0, 3 do
		local a = (i + 0.5) / 4 * math.pi * 2
		local p = (pivot * CFrame.new(math.cos(a) * 0.62, -(boomY - 0.5 - bagTop) + 0.05, math.sin(a) * 0.62)).Position
		Kit.span(sw, pivot.Position, p, 0.07, F.SteelDark, DETAIL)
	end
	-- bag body, top cap, bands, D-rings
	local bagF = if t == 4 then F.LeatherTan elseif t == 5 then F.LeatherBlack elseif t == 6 then F.Composite else F.VinylRed
	local bc = at(0, bagTop - bagH / 2, zBag)
	Kit.cylY(sw, bc, bagH, bagD, bagF, DETAIL)
	Kit.cylY(sw, bc * CFrame.new(0, bagH / 2 + 0.05, 0), 0.12, bagD - 0.15, F.PlasticBlack, DETAIL)
	Kit.cylY(sw, bc * CFrame.new(0, -bagH / 2 - 0.04, 0), 0.1, bagD - 0.2, if t == 4 then F.LeatherCognac else F.PlasticBlack, DETAIL)
	local bandF = if t == 3 then F.PlasticBlack elseif t == 4 then F.LeatherCognac elseif t == 5 then F.Gold else (st.Light or F.LightCyan)
	for _, dy in { bagH / 2 - 0.45, -bagH / 2 + 0.45 } do
		Kit.cylY(sw, bc * CFrame.new(0, dy, 0), 0.16, bagD + 0.03, bandF, DETAIL)
	end
	-- logo strip facing the trainee
	Kit.box(sw, bc * CFrame.new(0, 0.3, bagD / 2 - 0.02), Vector3.new(0.5, 1.6, 0.06), if t == 4 then F.FabricCream elseif t == 5 then F.Gold else F.FabricWhite, DETAIL)
	if t >= 4 then
		for i = 0, 3 do
			local a = (i + 0.5) / 4 * math.pi * 2
			Kit.ball(sw, (bc * CFrame.new(math.cos(a) * bagD * 0.42, bagH / 2 + 0.02, math.sin(a) * bagD * 0.42)).Position, 0.16, hookF, DETAIL)
		end
	end
	-- static collider standing in for the swinging bag
	local col = Kit.cylY(m, bc, bagH, bagD, F.Rubber, { Collide = true, Transparency = 1, Shadow = false })
	col.Name = "Collider"
	S.placard(c, m, at(0, h0 + 2.2, zMast - tube * 0.58 - 0.04), 0.7, nil)
	c.E.standingSpot(m, at(0, h0, zBag - 1.95))
end

---------------------------------------------------------------------------
-- PlyoBox: jump box + landing mat + step box. T1 soft foam, T2 plywood,
-- T3 steel-framed, T5 walnut + leather top.
---------------------------------------------------------------------------
local function plyoBox(c: S.Ctx)
	local m, st, t = c.model, c.st, c.tier
	local at = c.at
	local h0 = S.plinth(c, m, at(0, 0, 0), 4.8, 5.8)
	local bw, bh, bd = 2.7, 2.4, 2.2
	local zB = 1.15
	-- landing mat under the take-off spot
	local matF = if t == 1 then F.RubberTeal elseif t == 3 then F.RubberFleck elseif t == 5 then F.LeatherBlack elseif t == 6 then F.Carbon else F.RubberFloor
	Kit.box(m, at(0, h0 + 0.05, -1.25), Vector3.new(3.4, 0.1, 2.6), matF, SOLID)
	local markF = if t == 1 then F.PlasticCoral elseif t == 3 then F.PowderRed elseif t == 5 then F.Gold elseif t == 6 then (st.Light or F.LightCyan) else F.PowderYellow
	Kit.box(m, at(0, h0 + 0.105, -0.4), Vector3.new(2.4, 0.01, 0.1), markF, DETAIL)

	R.plyoBox(c, m, at(0, h0, zB), bw, bh, bd)
	R.plyoBox(c, m, at(0.7, h0, zB + 1.75), 1.4, 1.2, 1.1)
	R.plyoBox(c, m, at(-1.0, h0, zB + 1.75), 1.2, 0.8, 1.0)
	-- water bottle on the mat corner
	Kit.cylY(m, at(1.45, h0 + 0.42, -2.25), 0.64, 0.26, if t >= 5 then F.Gold elseif t == 4 then F.Brass else F.SteelBrushed, DETAIL)
	Kit.cylY(m, at(1.45, h0 + 0.8, -2.25), 0.12, 0.18, F.PlasticBlack, DETAIL)
	-- mat edging + numbered plaques on the bigger boxes (T4+)
	for _, sz in { -1, 1 } do
		Kit.box(m, at(0, h0 + 0.06, -1.25 + sz * 1.3), Vector3.new(3.4, 0.12, 0.08), markF, DETAIL)
	end
	if t >= 4 then
		local plaque = if t == 4 then F.Brass elseif t == 5 then F.Gold else (st.Light or F.LightCyan)
		Kit.box(m, at(0.9, h0 + bh * 0.62, zB - bd / 2 - 0.03), Vector3.new(0.4, 0.4, 0.03), plaque, DETAIL)
		Kit.box(m, at(-1.0, h0 + 0.55, zB + 1.75 - 0.53), Vector3.new(0.3, 0.3, 0.03), plaque, DETAIL)
	end
	if t ~= 1 then
		S.placard(c, m, at(0, h0 + bh * 0.62, zB - bd / 2 - 0.04), 1.1, S.NAMES.PlyoBox)
	end
	c.E.standingSpot(m, at(0, h0 + 0.1, -1.35))
end

return function(E: S.Lib)
	S.station(E, "AgilityLadder", agilityLadder)
	S.station(E, "SpeedBag", speedBag)
	S.station(E, "HeavyBag", heavyBag)
	S.station(E, "PlyoBox", plyoBox)
end
