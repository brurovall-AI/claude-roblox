--!strict
--[[
	Exterior envelope of the Ironhaven building (B1 retaining walls, G, L2,
	parapet) and the south entrance composition.

	Design: a warm travertine volume on a dark granite plinth with dark-bronze
	metalwork. The south front is framed by a deep stone portal (two piers + a
	crown lintel carrying the IRONHAVEN wordmark) around a two-storey glazed
	entrance hall with bronze fins; a cantilevered canopy with a walnut soffit
	marks the walk-through main entrance. Wings: big bronze-framed windows on
	the ground floor under a calm stone upper storey with clerestory ribbons.
	Cardio wraps its north-east corner in full-height glazing (city view).

	Exterior walls are 2 thick, centred on the footprint edge: an outer leaf
	(1.6, cladding) per side and floor, and an inner leaf (0.4) per room with
	that room's wall finish. Window openings are cut through both leaves.
]]

local Context = require("../Context")
local Ground = require("./Ground")
local Kit = require("../Kit")
local Layout = require("../Layout")

local Shell = Ground.Shell
local F = Shell.F
type Box2 = Ground.Box2

type Opening = { Side: string, A0: number, A1: number, Y0: number, Y1: number, Kind: string, Div: number? }
type Side = { Axis: string, C: number, S: number, A0: number, A1: number }

local OPENINGS: { Opening } = {}
local function add(side: string, a0: number, a1: number, y0: number, y1: number, kind: string, div: number?)
	table.insert(OPENINGS, { Side = side, A0 = a0, A1 = a1, Y0 = y0, Y1 = y1, Kind = kind, Div = div })
end

local L2Y = Layout.Y.L2

-- South: entrance hall, wings (Beginner / Lounge windows, Foundry / VIP clerestories)
add("S", -52, 52, 0, 46, "Curtain")
for _, s in { -1, 1 } do
	for _, w in { { 125.5, 145.5 }, { 101, 121 }, { 76.5, 96.5 } } do
		add("S", math.min(s * w[1], s * w[2]), math.max(s * w[1], s * w[2]), 1.5, 22, "Window", 3)
	end
	for _, w in { { 109, 146 }, { 64, 101 } } do
		add("S", math.min(s * w[1], s * w[2]), math.max(s * w[1], s * w[2]), L2Y + 16, L2Y + 22, "Clerestory")
	end
end
-- North: Cables slots, Main Hall clerestory, Cardio glass, Foundry clerestory, Pro Floor windows
for _, x in { -138, -123, -108, -93, -78 } do
	add("N", x - 1.5, x + 1.5, 3, 21, "Slot")
end
add("N", -56, -32, 17, 24, "Clerestory")
add("N", -28, 28, 17, 24, "Clerestory")
add("N", 32, 56, 17, 24, "Clerestory")
add("N", 61, 149, 1, 25, "Glazing")
add("N", -146, -109, L2Y + 16, L2Y + 22, "Clerestory")
add("N", -101, -64, L2Y + 16, L2Y + 22, "Clerestory")
for _, x in { -56, -27, 2, 31 } do
	add("N", x, x + 25, L2Y + 3, L2Y + 20, "Window", 4)
end
-- East: Lounge windows, frosted locker strips, Cardio glass, VIP windows, skybridge gate
add("E", -95.5, -72.25, 1.5, 22, "Window", 3)
add("E", -67.75, -44.5, 1.5, 22, "Window", 3)
add("E", -36, -11, 17, 23, "Frosted", 4)
add("E", -3, 22, 17, 23, "Frosted", 4)
add("E", 27, 99, 1, 25, "Glazing")
for _, z in { -96, -67, -38 } do
	add("E", z, z + 25, L2Y + 3, L2Y + 20, "Window", 4)
end
local sky = Layout.L2Doors.EastHallToSkybridge
add("E", sky.Z - sky.Width / 2, sky.Z + sky.Width / 2, L2Y, L2Y + sky.Height, "Gate")
-- West: Beginner windows, Free Weights windows + Yard door, Cables slots, Foundry clerestory
add("W", -95.5, -72.25, 1.5, 22, "Window", 3)
add("W", -67.75, -44.5, 1.5, 22, "Window", 3)
add("W", -34, -18, 3, 20, "Window", 2)
add("W", 12, 28, 3, 20, "Window", 2)
local yard = Layout.GDoors.FreeWeightsToYard
add("W", yard.Z - yard.Width / 2, yard.Z + yard.Width / 2, 0, yard.Height, "Door")
for _, z in { 52, 66, 80, 94 } do
	add("W", z - 1.5, z + 1.5, 3, 21, "Slot")
end
for _, z in { -96, -46, 4, 54 } do
	add("W", z, z + 42, L2Y + 16, L2Y + 22, "Clerestory")
end

local function sides(north: number, zMax: number): { [string]: Side }
	return {
		S = { Axis = "X", C = -100, S = -1, A0 = -151, A1 = 151 },
		N = { Axis = "X", C = north, S = 1, A0 = -151, A1 = 151 },
		E = { Axis = "Z", C = 150, S = 1, A0 = -99, A1 = zMax },
		W = { Axis = "Z", C = -150, S = -1, A0 = -99, A1 = zMax },
	}
end

-- Offsets across the wall: outward face at s*1; outer leaf 1.6 thick, inner leaf 0.4.
local function outerRange(s: number): (number, number)
	return math.min(s * 1, -s * 0.6), math.max(s * 1, -s * 0.6)
end
local function innerRange(s: number): (number, number)
	return math.min(-s * 0.6, -s * 1), math.max(-s * 0.6, -s * 1)
end

-- Cut-outs of one side (doors padded for their portal, gates get a sign notch).
local function cutsFor(side: string): { Box2 }
	local out: { Box2 } = {}
	for _, o in OPENINGS do
		if o.Side ~= side then
			continue
		end
		if o.Kind == "Door" then
			table.insert(out, { a0 = o.A0 - 0.4, a1 = o.A1 + 0.4, b0 = o.Y0 - 1, b1 = o.Y1 + 0.4 })
		elseif o.Kind == "Gate" then
			local mid, sw = (o.A0 + o.A1) / 2, math.min(o.A1 - o.A0, 12) / 2 + 0.2
			table.insert(out, { a0 = o.A0, a1 = o.A1, b0 = o.Y0, b1 = o.Y1 })
			table.insert(out, { a0 = mid - sw, a1 = mid + sw, b0 = o.Y1 - 0.01, b1 = o.Y1 + 1.9 })
		elseif o.Kind == "Curtain" then
			table.insert(out, { a0 = o.A0, a1 = o.A1, b0 = o.Y0 - 1, b1 = o.Y1 })
		else
			table.insert(out, { a0 = o.A0, a1 = o.A1, b0 = o.Y0, b1 = o.Y1 })
		end
	end
	return out
end

-- CFrame at a point on a side's wall line facing outward.
local function faceCF(sd: Side, a: number, y: number, off: number?): CFrame
	local o = sd.C + sd.S * (off or 0)
	if sd.Axis == "X" then
		return CFrame.new(a, y, o) * CFrame.Angles(0, if sd.S > 0 then math.pi else 0, 0)
	end
	return CFrame.new(o, y, a) * CFrame.Angles(0, math.rad(if sd.S > 0 then -90 else 90), 0)
end

-- Box on a side: along [a0,a1], outward offsets [d0,d1] (positive = outside), y [y0,y1].
local function sbox(parent: Instance, sd: Side, a0: number, a1: number, d0: number, d1: number, y0: number, y1: number, finish: Kit.FinishArg, opts: Kit.Opts?): Part
	local o0, o1 = sd.S * d0, sd.S * d1
	return Shell.wbox(parent, sd.Axis, sd.C, a0, a1, math.min(o0, o1), math.max(o0, o1), y0, y1, finish, opts)
end

---------------------------------------------------------------------------
-- Window dressing
---------------------------------------------------------------------------
local function surround(parent: Instance, sd: Side, o: Opening, proud: number, w: number)
	local a0, a1 = o.A0 - w, o.A1 + w
	sbox(parent, sd, a0, a1, 1, 1 + proud, o.Y1, o.Y1 + w, F.Bronze, Kit.DETAIL)
	sbox(parent, sd, a0, a1, 1, 1 + proud, o.Y0 - w, o.Y0, F.Bronze, Kit.DETAIL)
	sbox(parent, sd, a0, o.A0, 1, 1 + proud, o.Y0, o.Y1, F.Bronze, Kit.DETAIL)
	sbox(parent, sd, o.A1, a1, 1, 1 + proud, o.Y0, o.Y1, F.Bronze, Kit.DETAIL)
end

local function dressOpening(parent: Instance, sd: Side, o: Opening)
	local w, h = o.A1 - o.A0, o.Y1 - o.Y0
	local cf = faceCF(sd, (o.A0 + o.A1) / 2, (o.Y0 + o.Y1) / 2)
	if o.Kind == "Window" then
		Kit.glazing(parent, cf, w, h, F.Bronze, o.Div, "GlassTint")
		surround(parent, sd, o, 1.4, 0.6)
	elseif o.Kind == "Slot" then
		Kit.glazing(parent, cf, w, h, F.Bronze, 1, "GlassTint")
		surround(parent, sd, o, 1.0, 0.45)
	elseif o.Kind == "Clerestory" then
		Kit.glazing(parent, cf, w, h, F.Bronze, math.max(2, math.floor(w / 6)), "GlassTint")
		-- slim eyebrow casting a shadow line over the ribbon
		sbox(parent, sd, o.A0 - 0.6, o.A1 + 0.6, 1, 2.2, o.Y1, o.Y1 + 0.5, F.Bronze, Kit.DETAIL)
	elseif o.Kind == "Frosted" then
		Kit.glazing(parent, cf, w, h, F.Bronze, o.Div, "GlassFrosted")
	elseif o.Kind == "Glazing" then
		local div = math.max(2, math.floor(w / 7.5))
		Kit.glazing(parent, cf, w, h, F.Bronze, div, "Glass")
		for i = 1, div - 1 do
			local a = o.A0 + w * i / div
			sbox(parent, sd, a - 0.2, a + 0.2, 0.2, 2.2, o.Y0, o.Y1, F.Bronze, Kit.DETAIL)
		end
	elseif o.Kind == "Door" then
		local mid = (o.A0 + o.A1) / 2
		Shell.portal(parent, sd.Axis, sd.C, mid, w, h, Layout.Y.G, 2.4, F.Bronze)
		-- slim bronze canopy over the door
		sbox(parent, sd, o.A0 - 3, o.A1 + 3, 1, 6, o.Y1 + 1.2, o.Y1 + 1.8, F.Bronze)
	end
end

---------------------------------------------------------------------------
-- South entrance: stone portal frame, curtain wall, canopy, wordmark
---------------------------------------------------------------------------
local WORDMARK_FONT = Font.new("rbxasset://fonts/families/Michroma.json", Enum.FontWeight.Regular)

local function entrance(parent: Instance, sd: Side)
	local m = Kit.model(parent, "Entrance")
	local door = Layout.GDoors.MainEntrance
	local dw, dh = door.Width / 2 + 0.6, door.Height + 0.6
	local stone = F.StoneLight

	-- portal frame: two piers + crown lintel projecting 4 studs, coping on top
	sbox(m, sd, -60, -52, 0.6, 4, -1, 60, stone)
	sbox(m, sd, 52, 60, 0.6, 4, -1, 60, stone)
	sbox(m, sd, -52, 52, 0.6, 4, 46, 60, stone)
	sbox(m, sd, -60.3, 60.3, 0.4, 4.3, 60, 60.5, stone)
	-- deep bronze reveal lining the inside of the frame
	sbox(m, sd, -52.4, -52, 0.6, 3.6, 0, 46, F.BronzeDeep, Kit.DETAIL)
	sbox(m, sd, 52, 52.4, 0.6, 3.6, 0, 46, F.BronzeDeep, Kit.DETAIL)
	sbox(m, sd, -52.4, 52.4, 0.6, 3.6, 45.6, 46, F.BronzeDeep, Kit.DETAIL)

	-- glass (walk-through doorway left open)
	for _, b in Shell.carve(-52, 52, 0, 46, { { a0 = -dw, a1 = dw, b0 = -1, b1 = dh } }) do
		sbox(m, sd, b.a0, b.a1, -0.1, 0.1, b.b0, b.b1, "Glass", { Shadow = false })
	end
	-- transoms / spandrel / base rail
	sbox(m, sd, -52, -dw, -0.2, 0.4, 0, 0.5, F.Bronze, Kit.DETAIL)
	sbox(m, sd, dw, 52, -0.2, 0.4, 0, 0.5, F.Bronze, Kit.DETAIL)
	sbox(m, sd, -52, 52, -0.2, 0.4, dh - 0.3, dh + 0.1, F.Bronze, Kit.DETAIL)
	sbox(m, sd, -52, 52, 0.15, 0.7, 25.6, 28.6, F.Bronze, Kit.DETAIL)
	sbox(m, sd, -52, 52, -0.2, 0.4, 37, 37.3, F.Bronze, Kit.DETAIL)

	-- vertical fins (cut short by the canopy over the entrance)
	local canopyW = 26
	local x = -52 + 6.5
	while x < 52 - 1 do
		if math.abs(x) <= canopyW then
			sbox(m, sd, x - 0.25, x + 0.25, 0.1, 2.6, 17.6, 46, F.Bronze, Kit.DETAIL)
			if math.abs(x) > dw then
				sbox(m, sd, x - 0.15, x + 0.15, -0.2, 0.4, 0, 15.4, F.Bronze, Kit.DETAIL)
			end
		else
			sbox(m, sd, x - 0.25, x + 0.25, 0.1, 2.6, 0, 46, F.Bronze, Kit.DETAIL)
		end
		x += 6.5
	end

	-- doorway portal: deep bronze surround
	sbox(m, sd, -dw - 0.8, -dw, -1.2, 2.8, 0, dh + 0.8, F.BronzeDeep)
	sbox(m, sd, dw, dw + 0.8, -1.2, 2.8, 0, dh + 0.8, F.BronzeDeep)
	sbox(m, sd, -dw - 0.8, dw + 0.8, -1.2, 2.8, dh, dh + 0.8, F.BronzeDeep)

	-- cantilevered canopy: bronze body, walnut soffit, tie rods to the spandrel
	local c0, c1 = 0.8, 21
	local yb, yt = 15.9, 17.2
	sbox(m, sd, -canopyW, canopyW, c0, c1, yb, yt, F.BronzeDeep)
	sbox(m, sd, -canopyW + 0.5, canopyW - 0.5, c0 + 0.3, c1 - 0.5, yb - 0.2, yb, "WalnutPlanks", Kit.DETAIL)
	for _, rx in { -22, -9, 9, 22 } do
		local p0 = faceCF(sd, rx, yt, c1 - 1.5).Position
		local p1 = faceCF(sd, rx, 27.2, 0.8).Position
		Kit.span(m, p0, p1, 0.32, F.Bronze, Kit.DETAIL)
	end
	-- warm downlights in the soffit
	for _, lx in { -17, -6, 6, 17 } do
		for _, d in { 7, 15 } do
			local lp = sbox(m, sd, lx - 0.5, lx + 0.5, d - 0.5, d + 0.5, yb - 0.26, yb - 0.2, "LightWarm", Kit.DETAIL)
			if d == 15 then
				Kit.light(lp, "Spot", { Face = Enum.NormalId.Bottom, Angle = 80, Range = 22, Brightness = 2.2, Color = Color3.fromRGB(255, 214, 170) })
			end
		end
	end

	-- wordmark on a slim bronze panel set into the crown
	local panel = sbox(m, sd, -33, 33, 4, 4.3, 49.6, 56.4, F.BronzeDeep, Kit.DETAIL)
	panel.Name = "Wordmark"
	Kit.sign(panel, "IRONHAVEN", {
		Face = Enum.NormalId.Front,
		Font = WORDMARK_FONT,
		TextColor = Color3.fromRGB(246, 238, 222),
		PixelsPerStud = 20,
		LightInfluence = 0.35,
		Brightness = 1.3,
		MaxDistance = 1200,
		Padding = 0.14,
	})
	-- grazing uplights on the portal piers
	for _, px in { -56, 56 } do
		local fx = sbox(m, sd, px - 0.8, px + 0.8, 4.2, 4.9, 0, 0.35, F.BronzeDeep, Kit.DETAIL)
		Kit.light(fx, "Spot", { Face = Enum.NormalId.Top, Angle = 28, Range = 46, Brightness = 2.6, Color = Color3.fromRGB(255, 220, 180) })
	end
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local M = {}

function M.build(ctx: Context.Ctx)
	local root = Kit.folder(ctx.Structure, "Facade")
	local SP = Shell.SPECS
	local floors = {
		{ spec = SP.B1, y0 = Layout.Y.B1 - Layout.SLAB, y1 = -1, sides = sides(60, 59), clad = "Concrete" :: Kit.FinishArg },
		{ spec = SP.G, y0 = -1, y1 = L2Y, sides = sides(100, 99), clad = "Travertine" :: Kit.FinishArg },
		{ spec = SP.L2, y0 = L2Y, y1 = Layout.Y.ROOF, sides = sides(100, 99), clad = "Travertine" :: Kit.FinishArg },
	}
	local CUTS: { [string]: { Box2 } } = {}
	for _, k in { "S", "N", "E", "W" } do
		CUTS[k] = cutsFor(k)
	end
	local function sideKey(axis: string, c: number): string
		if axis == "X" then
			return if c < 0 then "S" else "N"
		end
		return if c > 0 then "E" else "W"
	end

	-- walls: outer leaf per side and floor, inner leaf per room
	local walls = Kit.folder(root, "Walls")
	for _, fl in floors do
		for key, sd in fl.sides do
			local o0, o1 = outerRange(sd.S)
			Shell.leaf(walls, sd.Axis, sd.C, sd.A0, sd.A1, o0, o1, fl.y0, fl.y1, fl.clad, CUTS[key])
		end
		for _, seg in Shell.segments(fl.spec) do
			local room = seg.Neg or seg.Pos
			if room and (seg.Neg == nil or seg.Pos == nil) then
				local s = if seg.Neg then 1 else -1 -- outward direction
				local i0, i1 = innerRange(s)
				Shell.leaf(walls, seg.Axis, seg.C, seg.A0, seg.A1, i0, i1, fl.spec.Y, fl.spec.Ceil, room.Wall, CUTS[sideKey(seg.Axis, seg.C)])
			end
		end
	end

	-- parapet, coping, plinth and the bronze floor-line band
	local trim = Kit.folder(root, "Trim")
	local top = sides(100, 99)
	for key, sd in top do
		Shell.leaf(trim, sd.Axis, sd.C, sd.A0, sd.A1, -1, 1, Layout.Y.ROOF, Layout.Y.ROOF + 2.6, "Travertine")
		sbox(trim, sd, sd.A0 - 0.3, sd.A1 + 0.3, -1.3, 1.3, Layout.Y.ROOF + 2.6, Layout.Y.ROOF + 3, F.StoneLight)
		local plinthCuts: { Box2 } = {}
		for _, o in OPENINGS do
			if o.Side == key and o.Y0 < 1 then
				table.insert(plinthCuts, { a0 = o.A0 - 0.4, a1 = o.A1 + 0.4, b0 = -2, b1 = 2 })
			end
		end
		for _, b in Shell.carve(sd.A0 - 0.35, sd.A1 + 0.35, -0.6, 1, plinthCuts) do
			sbox(trim, sd, b.a0, b.a1, 0.5, 1.35, b.b0, b.b1, F.GraniteDark)
		end
		local bandCuts: { Box2 } = if key == "S" then { { a0 = -60, a1 = 60, b0 = 0, b1 = 40 } } else {}
		for _, b in Shell.carve(sd.A0 - 0.3, sd.A1 + 0.3, 26.6, 27.6, bandCuts) do
			sbox(trim, sd, b.a0, b.a1, 0.9, 1.3, b.b0, b.b1, F.Bronze, Kit.DETAIL)
		end
	end

	-- upper storey: rhythm of deep dark-bronze fins over the stone (skips windows / portal)
	local fins = Kit.folder(root, "Fins")
	for key, sd in top do
		local a = sd.A0 + 2.5
		while a < sd.A1 - 2.4 do
			local clear = not (key == "S" and math.abs(a) < 62)
			for _, o in OPENINGS do
				if clear and o.Side == key and o.Y0 >= L2Y and o.Kind ~= "Clerestory" and a > o.A0 - 2 and a < o.A1 + 2 then
					clear = false
				end
			end
			if clear and key == "E" and math.abs(a) < 8.5 then
				clear = false
			end
			if clear then
				sbox(fins, sd, a - 0.25, a + 0.25, 1, 3.4, L2Y + 0.2, Layout.Y.ROOF - 0.2, F.BronzeDeep, Kit.DETAIL)
			end
			a += 3.5
		end
	end

	-- openings
	local glazing = Kit.folder(root, "Openings")
	local G = sides(100, 99)
	for _, o in OPENINGS do
		if o.Kind ~= "Curtain" and o.Kind ~= "Gate" then
			dressOpening(glazing, G[o.Side], o)
		end
	end
	entrance(root, G.S)

	-- warm wall-washers on the ground-floor piers of the south wings
	local lights = Kit.folder(root, "WallWashers")
	for _, x in { -147.75, -123.25, -98.75, -74.25, 74.25, 98.75, 123.25, 147.75 } do
		local fx = sbox(lights, G.S, x - 0.5, x + 0.5, 1, 1.6, 11.4, 12.6, F.BronzeDeep, Kit.DETAIL)
		sbox(lights, G.S, x - 0.35, x + 0.35, 1.6, 1.7, 12.5, 12.62, "LightWarm", Kit.DETAIL)
		Kit.light(fx, "Spot", { Face = Enum.NormalId.Top, Angle = 36, Range = 16, Brightness = 1.6, Color = Color3.fromRGB(255, 212, 166) })
	end
end

return M
