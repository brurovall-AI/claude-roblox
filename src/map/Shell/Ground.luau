--!strict
--[[
	Ground floor (Y = 0) architecture + the shared shell engine.

	The engine (Ground.Shell) turns the room rects of a floor into slabs, floor
	finishes, partition walls and door portals. Second/Lower/Facade/Roof and
	Circulation reuse it so the whole building speaks one language.

	  * Rooms carry Floor / Wall / Ceiling finishes (Shell.SPECS).
	  * A slab is two layers: structure (top-2 .. top-0.2) split by the rooms
	    BELOW it (its underside is their ceiling) + 0.2 finish plates split by the
	    rooms ON it (flush inlays supported). Walk surface = Layout.Y exactly.
	  * Partitions are 1 thick, centred on the rect edges, built as two 0.5
	    leaves so each face carries its own room's finish (one leaf when both
	    sides match). Edges with a room on one side only are exterior: Facade.
	  * Doors come from Layout. Gated doorways (Layout.Gates) stay EMPTY; their
	    wall gets a notch above the opening so the gate's requirement sign
	    (Gameplay.gate: h+0.1 .. h+1.7, on the wall line) stays visible.
	    Other doors get a 0.4 portal liner (clear size stays Width x Height).
	  * Walls are carved with Shell.carve (rect minus holes -> few boxes), which
	    unlike Kit.wall supports overlapping cut-outs (door + sign notch).
]]

local Context = require("../Context")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Palette = require("../Palette")

type Rect = Layout.Rect
type Door = Layout.Door
type FinishArg = Kit.FinishArg

export type Box2 = { a0: number, a1: number, b0: number, b1: number }
export type Room = { Id: string, Rect: Rect, Floor: FinishArg, Wall: FinishArg, Ceiling: FinishArg }
export type Inlay = { Rect: Rect, Finish: FinishArg }
export type FloorSpec = {
	Name: string, -- "B1" | "G" | "L2" (Layout.Gates floor names)
	Y: number, -- walk surface (slab top)
	Ceil: number, -- ceiling underside
	Rooms: { Room },
	Doors: { [string]: Door },
	Holes: { Rect }, -- holes through THIS floor's slab
	Open: { [string]: boolean }, -- "IdA|IdB" (sorted) pairs with no wall between them
	Inlays: { Inlay }, -- flush floor inlays (within one room)
}
-- A wall run on a rect edge. Axis "X": runs along X at Z = C. Axis "Z": runs along Z at X = C.
export type Segment = { Axis: string, C: number, A0: number, A1: number, Neg: Room?, Pos: Room? }
export type DoorCut = { Name: string, Door: Door, At: number, Gated: boolean }

local Shell = {}

local EPS = 1e-3
local PORTAL = 0.4 -- door liner width

---------------------------------------------------------------------------
-- Shared finishes (same table instances everywhere so equality merges work)
---------------------------------------------------------------------------
Shell.F = {
	Bronze = Palette.tint("SteelDark", Color3.fromRGB(72, 60, 48)),
	BronzeDeep = Palette.tint("SteelDark", Color3.fromRGB(44, 39, 34)),
	Emerald = Palette.tint("Plaster", Color3.fromRGB(38, 74, 61)),
	Felt = Palette.tint("FabricGrey", Color3.fromRGB(190, 186, 178)),
	GraniteDark = Palette.tint("Granite", Color3.fromRGB(74, 72, 70)),
	Paver = Palette.tint("Pavement", Color3.fromRGB(182, 176, 166)),
	StoneLight = Palette.tint("Travertine", Color3.fromRGB(228, 216, 194)),
}
local F = Shell.F

-- Portal liner finish per door name (default bronze).
local TRIM: { [string]: FinishArg } = {
	LobbyToWestCorridor = "Brass",
	LobbyToLounge = "Brass",
	LoungeToEastCorridor = "Brass",
	HallwayToEastHall = "Brass",
	EastHallToArena = "Brass",
}

local GATED: { [string]: boolean } = {}
for _, g in Layout.Gates do
	GATED[g.Floor .. "/" .. g.Door] = true
end

function Shell.isGated(floor: string, door: string): boolean
	return GATED[floor .. "/" .. door] == true
end

---------------------------------------------------------------------------
-- Geometry helpers
---------------------------------------------------------------------------
local function uniq(list: { number }): { number }
	table.sort(list)
	local out: { number } = {}
	for _, v in list do
		if #out == 0 or v - out[#out] > EPS then
			table.insert(out, v)
		end
	end
	return out
end

-- Rectangle [a0,a1] x [b0,b1] minus `holes` -> a small set of boxes covering
-- the remainder (grid decomposition + greedy merge, rows first).
function Shell.carve(a0: number, a1: number, b0: number, b1: number, holes: { Box2 }?): { Box2 }
	local as: { number } = { a0, a1 }
	local bs: { number } = { b0, b1 }
	local clipped: { Box2 } = {}
	for _, h in holes or {} do
		local h0, h1 = math.max(h.a0, a0), math.min(h.a1, a1)
		local v0, v1 = math.max(h.b0, b0), math.min(h.b1, b1)
		if h1 - h0 > EPS and v1 - v0 > EPS then
			table.insert(clipped, { a0 = h0, a1 = h1, b0 = v0, b1 = v1 })
			table.insert(as, h0)
			table.insert(as, h1)
			table.insert(bs, v0)
			table.insert(bs, v1)
		end
	end
	if #clipped == 0 then
		return { { a0 = a0, a1 = a1, b0 = b0, b1 = b1 } }
	end
	as, bs = uniq(as), uniq(bs)
	local na, nb = #as - 1, #bs - 1
	local solid: { { boolean } } = {}
	local used: { { boolean } } = {}
	for i = 1, na do
		solid[i], used[i] = {}, {}
		local ca = (as[i] + as[i + 1]) / 2
		for j = 1, nb do
			local cb = (bs[j] + bs[j + 1]) / 2
			local s = true
			for _, h in clipped do
				if ca > h.a0 and ca < h.a1 and cb > h.b0 and cb < h.b1 then
					s = false
					break
				end
			end
			solid[i][j], used[i][j] = s, false
		end
	end
	local out: { Box2 } = {}
	for j = 1, nb do
		for i = 1, na do
			if solid[i][j] and not used[i][j] then
				local i2 = i
				while i2 < na and solid[i2 + 1][j] and not used[i2 + 1][j] do
					i2 += 1
				end
				local j2 = j
				while j2 < nb do
					local ok = true
					for k = i, i2 do
						if not solid[k][j2 + 1] or used[k][j2 + 1] then
							ok = false
							break
						end
					end
					if not ok then
						break
					end
					j2 += 1
				end
				for k = i, i2 do
					for l = j, j2 do
						used[k][l] = true
					end
				end
				table.insert(out, { a0 = as[i], a1 = as[i2 + 1], b0 = bs[j], b1 = bs[j2 + 1] })
			end
		end
	end
	return out
end

function Shell.box2(r: Rect): Box2
	return { a0 = r.X0, a1 = r.X1, b0 = r.Z0, b1 = r.Z1 }
end

function Shell.rect(x0: number, x1: number, z0: number, z1: number): Rect
	return { X0 = x0, X1 = x1, Z0 = z0, Z1 = z1 }
end

-- Horizontal plate over plan rect r from y0 to y1.
function Shell.plate(parent: Instance, x0: number, x1: number, z0: number, z1: number, y0: number, y1: number, finish: FinishArg, opts: Kit.Opts?): Part
	return Kit.box(parent, CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), Vector3.new(x1 - x0, y1 - y0, z1 - z0), finish, opts)
end

-- Plan rect minus holes, as plates.
function Shell.plates(parent: Instance, r: Rect, holes: { Rect }, y0: number, y1: number, finish: FinishArg, opts: Kit.Opts?)
	local hs: { Box2 } = {}
	for _, h in holes do
		table.insert(hs, Shell.box2(h))
	end
	for _, b in Shell.carve(r.X0, r.X1, r.Z0, r.Z1, hs) do
		Shell.plate(parent, b.a0, b.a1, b.b0, b.b1, y0, y1, finish, opts)
	end
end

--[[
	Box in wall-local coordinates: `a` along the wall, `o` across it (offset from
	the wall line C), `y` vertical. Axis "X": wall along X at Z = C.
]]
function Shell.wbox(parent: Instance, axis: string, c: number, a0: number, a1: number, o0: number, o1: number, y0: number, y1: number, finish: FinishArg, opts: Kit.Opts?): Part
	local am, om, ym = (a0 + a1) / 2, c + (o0 + o1) / 2, (y0 + y1) / 2
	if axis == "X" then
		return Kit.box(parent, CFrame.new(am, ym, om), Vector3.new(a1 - a0, y1 - y0, o1 - o0), finish, opts)
	end
	return Kit.box(parent, CFrame.new(om, ym, am), Vector3.new(o1 - o0, y1 - y0, a1 - a0), finish, opts)
end

-- Wall leaf [a0,a1] x [y0,y1] at offsets [o0,o1] with cut-outs (a = along, b = height).
function Shell.leaf(parent: Instance, axis: string, c: number, a0: number, a1: number, o0: number, o1: number, y0: number, y1: number, finish: FinishArg, cuts: { Box2 }?)
	for _, b in Shell.carve(a0, a1, y0, y1, cuts) do
		Shell.wbox(parent, axis, c, b.a0, b.a1, o0, o1, b.b0, b.b1, finish)
	end
end

---------------------------------------------------------------------------
-- Rooms, segments, doors
---------------------------------------------------------------------------
function Shell.roomAt(spec: FloorSpec, x: number, z: number): Room?
	for _, r in spec.Rooms do
		local q = r.Rect
		if x > q.X0 + EPS and x < q.X1 - EPS and z > q.Z0 + EPS and z < q.Z1 - EPS then
			return r
		end
	end
	return nil
end

local function pairKey(a: Room, b: Room): string
	if a.Id < b.Id then
		return a.Id .. "|" .. b.Id
	end
	return b.Id .. "|" .. a.Id
end

local function sameWall(a: Room?, b: Room?): boolean
	if a == nil or b == nil then
		return a == nil and b == nil
	end
	return a.Wall == b.Wall
end

-- Every wall run of a floor (interior: both sides set; exterior: one side nil).
-- Consecutive pieces with identical side finishes are merged.
function Shell.segments(spec: FloorSpec): { Segment }
	type Line = { axis: string, c: number, pts: { number } }
	local lines: { [string]: Line } = {}
	local function add(axis: string, c: number, p0: number, p1: number)
		local key = string.format("%s%09.2f", axis, c)
		local l = lines[key]
		if not l then
			l = { axis = axis, c = c, pts = {} }
			lines[key] = l
		end
		table.insert(l.pts, p0)
		table.insert(l.pts, p1)
	end
	for _, r in spec.Rooms do
		local q = r.Rect
		add("X", q.Z0, q.X0, q.X1)
		add("X", q.Z1, q.X0, q.X1)
		add("Z", q.X0, q.Z0, q.Z1)
		add("Z", q.X1, q.Z0, q.Z1)
	end
	local keys: { string } = {}
	for k in lines do
		table.insert(keys, k)
	end
	table.sort(keys)

	local segs: { Segment } = {}
	for _, k in keys do
		local l = lines[k]
		local pts = uniq(l.pts)
		local cur: Segment? = nil
		for i = 1, #pts - 1 do
			local p0, p1 = pts[i], pts[i + 1]
			local mid = (p0 + p1) / 2
			local nx, nz = if l.axis == "X" then mid else l.c - 0.5, if l.axis == "X" then l.c - 0.5 else mid
			local px, pz = if l.axis == "X" then mid else l.c + 0.5, if l.axis == "X" then l.c + 0.5 else mid
			local neg: Room? = Shell.roomAt(spec, nx, nz)
			local pos: Room? = Shell.roomAt(spec, px, pz)
			local wall = (neg ~= nil or pos ~= nil) and neg ~= pos
			if neg and pos and spec.Open[pairKey(neg, pos)] then
				wall = false
			end
			if not wall then
				cur = nil
				continue
			end
			local c0 = cur
			if
				c0
				and math.abs(c0.A1 - p0) < EPS
				and sameWall(c0.Neg, neg)
				and sameWall(c0.Pos, pos)
			then
				c0.A1 = p1
			else
				local s: Segment = { Axis = l.axis, C = l.c, A0 = p0, A1 = p1, Neg = neg, Pos = pos }
				table.insert(segs, s)
				cur = s
			end
		end
	end
	return segs
end

-- Doors lying on a segment (door axis: "NS" wall = runs along Z = Axis "Z").
function Shell.doorsOn(spec: FloorSpec, seg: Segment): { DoorCut }
	local out: { DoorCut } = {}
	local names: { string } = {}
	for name in spec.Doors do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		local d = spec.Doors[name]
		local axis = if d.Wall == "NS" then "Z" else "X"
		local c = if axis == "Z" then d.X else d.Z
		local at = if axis == "Z" then d.Z else d.X
		if axis == seg.Axis and math.abs(c - seg.C) < EPS and at > seg.A0 and at < seg.A1 then
			table.insert(out, { Name = name, Door = d, At = at, Gated = Shell.isGated(spec.Name, name) })
		end
	end
	return out
end

-- Cut-outs for a door at floor y: gated = exact opening + sign notch;
-- open portals = opening enlarged by the liner.
function Shell.doorCuts(cut: DoorCut, y: number): { Box2 }
	local d = cut.Door
	local w, h, at = d.Width, d.Height, cut.At
	if cut.Gated then
		local sw = math.min(w, 12) / 2 + 0.2
		return {
			{ a0 = at - w / 2, a1 = at + w / 2, b0 = y - 1, b1 = y + h },
			{ a0 = at - sw, a1 = at + sw, b0 = y + h - 0.01, b1 = y + h + 1.9 },
		}
	end
	return { { a0 = at - w / 2 - PORTAL, a1 = at + w / 2 + PORTAL, b0 = y - 1, b1 = y + h + PORTAL } }
end

--[[
	Door portal liner: two jambs + head of width PORTAL, `depth` deep (wall
	thickness + reveal), clear opening w x h, plus a brushed threshold strip.
]]
function Shell.portal(parent: Instance, axis: string, c: number, at: number, w: number, h: number, y: number, depth: number, finish: FinishArg)
	local m = Kit.model(parent, "Portal")
	local d = depth / 2
	Shell.wbox(m, axis, c, at - w / 2 - PORTAL, at - w / 2, -d, d, y, y + h + PORTAL, finish)
	Shell.wbox(m, axis, c, at + w / 2, at + w / 2 + PORTAL, -d, d, y, y + h + PORTAL, finish)
	Shell.wbox(m, axis, c, at - w / 2 - PORTAL, at + w / 2 + PORTAL, -d, d, y + h, y + h + PORTAL, finish)
	Shell.wbox(m, axis, c, at - w / 2, at + w / 2, -d + 0.1, d - 0.1, y, y + 0.03, finish, Kit.DETAIL)
end

function Shell.trim(name: string): FinishArg
	return TRIM[name] or F.Bronze
end

---------------------------------------------------------------------------
-- Builders
---------------------------------------------------------------------------
--[[
	Interior partitions of a floor: walls on shared room edges with door cuts,
	portals and gate sign notches. Exterior edges are skipped (Facade).
]]
function Shell.partitions(parent: Instance, spec: FloorSpec)
	local folder = Kit.folder(parent, "Partitions")
	local t = Layout.INT_WALL
	local y0, y1 = spec.Y, spec.Ceil
	for _, seg in Shell.segments(spec) do
		local neg, pos = seg.Neg, seg.Pos
		if not (neg and pos) then
			continue
		end
		local cuts: { Box2 } = {}
		local doors = Shell.doorsOn(spec, seg)
		for _, dc in doors do
			for _, b in Shell.doorCuts(dc, y0) do
				table.insert(cuts, b)
			end
		end
		if neg.Wall == pos.Wall then
			Shell.leaf(folder, seg.Axis, seg.C, seg.A0, seg.A1, -t / 2, t / 2, y0, y1, neg.Wall, cuts)
		else
			Shell.leaf(folder, seg.Axis, seg.C, seg.A0, seg.A1, -t / 2, 0, y0, y1, neg.Wall, cuts)
			Shell.leaf(folder, seg.Axis, seg.C, seg.A0, seg.A1, 0, t / 2, y0, y1, pos.Wall, cuts)
		end
		for _, dc in doors do
			if not dc.Gated then
				Shell.portal(folder, seg.Axis, seg.C, dc.At, dc.Door.Width, dc.Door.Height, y0, t + 0.3, Shell.trim(dc.Name))
			end
		end
	end
end

--[[
	Structural slab layer (top-2 .. top-0.2) under `footprint`. Split by the
	rooms of `below` so each room's ceiling carries its Ceiling finish; the rest
	(no room below) is plain concrete.
]]
function Shell.slabStructure(parent: Instance, footprint: Rect, top: number, holes: { Rect }, below: FloorSpec?)
	local y0, y1 = top - Layout.SLAB, top - 0.2
	local hs: { Box2 } = {}
	for _, h in holes do
		table.insert(hs, Shell.box2(h))
	end
	local rest: { Box2 } = table.clone(hs)
	if below then
		for _, r in below.Rooms do
			local q = r.Rect
			local x0, x1 = math.max(q.X0, footprint.X0), math.min(q.X1, footprint.X1)
			local z0, z1 = math.max(q.Z0, footprint.Z0), math.min(q.Z1, footprint.Z1)
			if x1 - x0 > EPS and z1 - z0 > EPS then
				for _, b in Shell.carve(x0, x1, z0, z1, hs) do
					Shell.plate(parent, b.a0, b.a1, b.b0, b.b1, y0, y1, r.Ceiling)
				end
				table.insert(rest, { a0 = x0, a1 = x1, b0 = z0, b1 = z1 })
			end
		end
	end
	for _, b in Shell.carve(footprint.X0, footprint.X1, footprint.Z0, footprint.Z1, rest) do
		Shell.plate(parent, b.a0, b.a1, b.b0, b.b1, y0, y1, "Concrete")
	end
end

-- Finish layer (Y-0.2 .. Y) split per room, with flush inlays.
function Shell.slabFinish(parent: Instance, spec: FloorSpec)
	local y0, y1 = spec.Y - 0.2, spec.Y
	local hs: { Box2 } = {}
	for _, h in spec.Holes do
		table.insert(hs, Shell.box2(h))
	end
	for _, r in spec.Rooms do
		local q = r.Rect
		local cuts: { Box2 } = table.clone(hs)
		for _, inl in spec.Inlays do
			local i = inl.Rect
			local x0, x1 = math.max(i.X0, q.X0), math.min(i.X1, q.X1)
			local z0, z1 = math.max(i.Z0, q.Z0), math.min(i.Z1, q.Z1)
			if x1 - x0 > EPS and z1 - z0 > EPS then
				table.insert(cuts, { a0 = x0, a1 = x1, b0 = z0, b1 = z1 })
				for _, b in Shell.carve(x0, x1, z0, z1, hs) do
					Shell.plate(parent, b.a0, b.a1, b.b0, b.b1, y0, y1, inl.Finish)
				end
			end
		end
		for _, b in Shell.carve(q.X0, q.X1, q.Z0, q.Z1, cuts) do
			Shell.plate(parent, b.a0, b.a1, b.b0, b.b1, y0, y1, r.Floor)
		end
	end
end

-- Free-standing structural column (2.4 x 2.4) with a slim base collar.
function Shell.column(parent: Instance, x: number, z: number, y0: number, y1: number, finish: FinishArg, collar: FinishArg)
	Kit.box(parent, CFrame.new(x, (y0 + y1) / 2, z), Vector3.new(2.4, y1 - y0, 2.4), finish)
	Kit.box(parent, CFrame.new(x, y0 + 0.3, z), Vector3.new(2.7, 0.6, 2.7), collar, Kit.DETAIL)
end

---------------------------------------------------------------------------
-- Floor specs (finish identities; see Palette header)
---------------------------------------------------------------------------
local function room(id: string, r: Rect, floor: FinishArg, wall: FinishArg, ceiling: FinishArg): Room
	return { Id = id, Rect = r, Floor = floor, Wall = wall, Ceiling = ceiling }
end

local G, L2, B1 = Layout.G, Layout.L2, Layout.B1
local R = Shell.rect
local AV = Layout.AtriumVoid

Shell.SPECS = {
	G = {
		Name = "G",
		Y = Layout.Y.G,
		Ceil = Layout.CEIL.G,
		Rooms = {
			room("Lobby", G.Lobby, "Travertine", "Plaster", "Oak"),
			room("WestCorridor", G.WestCorridor, "Travertine", "Plaster", "Plaster"),
			room("Beginner", G.Beginner, "Birch", "Plaster", "Plaster"),
			room("FreeWeights", G.FreeWeights, "RubberFloor", "PlasterGreen", "ConcreteDark"),
			room("Cables", G.Cables, "RubberFleck", "PlasterSlate", "ConcreteDark"),
			room("MainHall", G.MainHall, "ConcretePolished", "Concrete", "ConcreteDark"),
			room("Lounge", G.Lounge, "Terrazzo", "PlasterWarm", "PlasterWarm"),
			room("EastCorridor", G.EastCorridor, "Terrazzo", "Plaster", "Plaster"),
			room("LockersA", G.LockersA, "TileWhite", "TileWhite", "Plaster"),
			room("LockersB", G.LockersB, "TileWhite", "TileWhite", "Plaster"),
			room("Cardio", G.Cardio, "ConcretePolished", "ConcreteWarm", "Plaster"),
		},
		Doors = Layout.GDoors,
		Holes = { Layout.BasementStair.Opening, Layout.Elevator.Shaft },
		Open = {},
		Inlays = {
			-- dark marble band tracing the atrium footprint + recessed entrance mat
			{ Rect = R(AV.X0 - 1.5, AV.X1 + 1.5, AV.Z0 - 1.5, AV.Z0), Finish = "MarbleDark" },
			{ Rect = R(AV.X0 - 1.5, AV.X0, AV.Z0, AV.Z1), Finish = "MarbleDark" },
			{ Rect = R(AV.X1, AV.X1 + 1.5, AV.Z0, AV.Z1), Finish = "MarbleDark" },
			{ Rect = R(-12, 12, -99, -93), Finish = "Carpet" },
		},
	} :: FloorSpec,
	L2 = {
		Name = "L2",
		Y = Layout.Y.L2,
		Ceil = Layout.CEIL.L2,
		Rooms = {
			room("Mezzanine", L2.Mezzanine, "Travertine", "Plaster", "Plaster"),
			room("Hallway", L2.Hallway, "Travertine", "Plaster", "Plaster"),
			room("ProFloor", L2.ProFloor, "ConcretePolished", "PlasterGraphite", "PlasterCharcoal"),
			room("Foundry", L2.Foundry, "ConcreteDark", "Concrete", "ConcreteDark"),
			room("EastHall", L2.EastHall, "Carpet", "PlasterCharcoal", "PlasterCharcoal"),
			room("VIP", L2.VIP, "WalnutPlanks", F.Emerald, "Plaster"),
			room("Arena", L2.Arena, "ConcreteDark", "PlasterCharcoal", "PlasterCharcoal"),
		},
		Doors = Layout.L2Doors,
		Holes = { Layout.AtriumVoid, Layout.Elevator.Shaft },
		Open = { ["Hallway|Mezzanine"] = true },
		Inlays = {
			-- Foundry: diamond-plate aisle strips either side of the column line
			{ Rect = R(-123, -120, -96, 96), Finish = "DiamondPlate" },
			{ Rect = R(-90, -87, -96, 96), Finish = "DiamondPlate" },
			-- VIP: marble foyer inside the gate
			{ Rect = R(90, 120, -28, -8), Finish = "Marble" },
		},
	} :: FloorSpec,
	B1 = {
		Name = "B1",
		Y = Layout.Y.B1,
		Ceil = Layout.CEIL.B1,
		Rooms = {
			room("Concourse", B1.Concourse, "Terrazzo", "ConcreteWarm", "Plaster"),
			room("Boxing", B1.Boxing, "WornTimber", "Brick", "ConcreteDark"),
			room("Private", B1.Private, "WalnutPlanks", "PlasterCharcoal", "PlasterCharcoal"),
			room("Recovery", B1.Recovery, "Birch", "PlasterSage", "Plaster"),
		},
		Doors = Layout.B1Doors,
		Holes = {},
		Open = {},
		Inlays = {},
	} :: FloorSpec,
}

---------------------------------------------------------------------------
-- Ground floor
---------------------------------------------------------------------------
local M = {}
M.Shell = Shell

function M.build(ctx: Context.Ctx)
	local spec = Shell.SPECS.G
	local root = Kit.folder(ctx.Structure, "Ground")

	-- slab: structure (B1 ceilings below, plain concrete north of the basement) + finishes
	local slab = Kit.folder(root, "Slab")
	Shell.slabStructure(slab, Layout.Building, spec.Y, spec.Holes, Shell.SPECS.B1)
	Shell.slabFinish(slab, spec)

	Shell.partitions(root, spec)

	-- Main Hall: concrete columns + exposed steel girders on the column lines
	local hall = Kit.folder(root, "MainHallStructure")
	local mh = G.MainHall
	local beamY0, beamY1 = spec.Ceil - 2.2, spec.Ceil
	for _, x in { -30, 30 } do
		for _, z in { 30, 70 } do
			Shell.column(hall, x, z, spec.Y, spec.Ceil, "Concrete", "SteelDark")
		end
		Shell.plate(hall, x - 0.6, x + 0.6, mh.Z0 + 0.5, mh.Z1 - 1, beamY0, beamY1, "SteelDark")
	end
	for _, z in { 30, 70 } do
		Shell.plate(hall, mh.X0 + 0.5, mh.X1 - 0.5, z - 0.5, z + 0.5, beamY0 + 0.4, beamY1, "SteelDark")
	end

	-- Cardio: suspended acoustic baffles running north-south (gaps for fixtures)
	local cardio = Kit.folder(root, "CardioCeiling")
	local cr = G.Cardio
	for x = cr.X0 + 10, cr.X1 - 8, 10 do
		Shell.plate(cardio, x - 0.2, x + 0.2, cr.Z0 + 6, cr.Z1 - 6, spec.Ceil - 1.8, spec.Ceil, F.Felt, { Shadow = false })
	end
end

return M
