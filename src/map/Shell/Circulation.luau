--!strict
--[[
	Vertical circulation:
	  * Grand stair (Layout.GrandStair): stone flight 1 on the lobby floor, a
	    solid stone landing pier at Y = 14, then a floating flight 2 (sloped
	    soffit, bronze stringers) arriving at the L2 hallway edge. Frameless
	    glass balustrades with brass handrails.
	  * Basement stair (Layout.BasementStair): floating upper flight, landing,
	    lower flight onto the concourse; a full-height glass enclosure around
	    the slab opening keeps the gate at the stair head meaningful.
	  * Roof stair (Layout.RoofStair): switchback inside the shaft, L2 -> roof.
	    Entry landing (Y 28) -> flight A (west half, north) -> mid landing (Y 41)
	    -> flight B (east half, south) -> roof deck at Z 57. The roof slab is
	    open only above flight B (Shell/Roof cuts ROOF_STAIR_HOLE).
	  * Elevator core (Layout.Elevator): travertine shaft from B1 to the roof
	    penthouse, bronze portal wall on the east face at every floor with
	    closed brushed-steel doors and a floor indicator. ElevatorStop panels
	    (Gameplay) sit on the portal wall face at X = DoorX + 0.2.
	Walkability: every flight uses an invisible collision ramp (Kit.stairs or
	the same construction in floatingFlight).
]]

local Context = require("../Context")
local Ground = require("./Ground")
local Kit = require("../Kit")
local Layout = require("../Layout")

local Shell = Ground.Shell
local F = Shell.F

local M = {}

-- Roof slab opening above flight B of the roof stair (used by Shell/Roof).
M.ROOF_STAIR_HOLE = Shell.rect(48.25, 55.5, 57, 70)
-- Underside of the penthouse roofs (elevator shaft walls end here; Shell/Roof).
M.PENTHOUSE_TOP = Layout.Y.ROOF + 13

---------------------------------------------------------------------------
-- Flights
---------------------------------------------------------------------------
type FlightOpts = {
	Width: number,
	Rise: number,
	Steps: number,
	Run: number,
	Tread: Kit.FinishArg,
	Nosing: Kit.FinishArg?,
	Soffit: Kit.FinishArg,
	Stringer: Kit.FinishArg,
}

--[[
	Floating flight: chunky step blocks on a sloped waist slab (clean soffit
	underneath), side stringers, invisible collision ramp. `base` = centre of
	the bottom step's front edge, LookVector = climbing direction.
]]
local function floatingFlight(parent: Instance, base: CFrame, o: FlightOpts): Model
	local m = Kit.model(parent, "Flight", base)
	local stepH = o.Rise / o.Steps
	local total = o.Run * o.Steps
	local angle = math.atan2(o.Rise, total)
	local c = math.cos(angle)
	local slopeLen = math.sqrt(total * total + o.Rise * o.Rise)
	for i = 1, o.Steps do
		local top = stepH * i
		Kit.box(m, base * CFrame.new(0, top - stepH, -(i - 0.5) * o.Run), Vector3.new(o.Width, stepH * 2, o.Run), o.Tread, { Collide = false })
		if o.Nosing then
			Kit.box(m, base * CFrame.new(0, top - 0.05, -(i - 1) * o.Run - 0.15), Vector3.new(o.Width - 0.3, 0.12, 0.32), o.Nosing, Kit.DETAIL)
		end
	end
	-- frame along the slope: v = 0 runs through the back corners of the treads
	local slope = base * CFrame.Angles(angle, 0, 0)
	local t = 1.1
	local vTop = -stepH * c
	Kit.box(m, slope * CFrame.new(0, vTop - t / 2, -slopeLen / 2), Vector3.new(o.Width, t, slopeLen + 0.6), o.Soffit, { Collide = false })
	for _, side in { -1, 1 } do
		local x = side * (o.Width / 2 + 0.2)
		local v0, v1 = vTop - t - 0.25, stepH * c + 0.45
		Kit.box(m, slope * CFrame.new(x, (v0 + v1) / 2, -slopeLen / 2), Vector3.new(0.4, v1 - v0, slopeLen + 0.4), o.Stringer, { Collide = true })
	end
	local ramp = Kit.box(m, base * CFrame.new(0, o.Rise / 2, -total / 2) * CFrame.Angles(angle, 0, 0), Vector3.new(o.Width, 0.4, slopeLen), "Concrete", { Collide = true, Shadow = false })
	ramp.Transparency = 1
	ramp.Name = "Ramp"
	return m
end

-- Sloped frameless glass balustrade + handrail on one side of a flight.
local function slopedBalustrade(parent: Instance, base: CFrame, width: number, rise: number, steps: number, run: number, side: number, rail: Kit.FinishArg, raise: number?)
	local stepH = rise / steps
	local total = run * steps
	local angle = math.atan2(rise, total)
	local c = math.cos(angle)
	local slopeLen = math.sqrt(total * total + rise * rise)
	local slope = base * CFrame.Angles(angle, 0, 0)
	local x = side * (width / 2 + 0.2)
	local v0 = stepH * c + (raise or 0.45)
	local h = 3.4
	Kit.box(parent, slope * CFrame.new(x, v0 + h / 2, -slopeLen / 2), Vector3.new(0.15, h, slopeLen), "Glass", { Collide = true, Shadow = false })
	local p0 = (slope * CFrame.new(x, v0 + h + 0.15, 0)).Position
	local p1 = (slope * CFrame.new(x, v0 + h + 0.15, -slopeLen)).Position
	Kit.span(parent, p0, p1, 0.32, rail, Kit.DETAIL)
end

---------------------------------------------------------------------------
-- Grand stair
---------------------------------------------------------------------------
local function grandStair(parent: Instance)
	local gs = Layout.GrandStair
	local m = Kit.model(parent, "GrandStair")
	local width = gs.X1 - gs.X0
	local cx = (gs.X0 + gs.X1) / 2
	local rise = (Layout.Y.L2 - Layout.Y.G) / 2
	local yL = Layout.Y.G + rise
	local stone = F.StoneLight

	-- flight 1: solid stone on the lobby floor
	local b1 = Kit.place(cx, Layout.Y.G, gs.StartZ, 180)
	Kit.stairs(m, b1, width, rise, gs.Steps, gs.Run, stone, "Brass")
	-- landing pier
	Shell.plate(m, gs.X0, gs.X1, gs.LandingZ0, gs.LandingZ1, Layout.Y.G, yL, stone)
	Shell.plate(m, gs.X0 - 0.05, gs.X1 + 0.05, gs.LandingZ0 - 0.05, gs.LandingZ0 + 0.25, yL - 0.12, yL + 0.01, "Brass", Kit.DETAIL)
	-- flight 2: floating
	local b2 = Kit.place(cx, yL, gs.LandingZ1, 180)
	floatingFlight(m, b2, { Width = width, Rise = rise, Steps = gs.Steps, Run = gs.Run, Tread = stone, Nosing = "Brass", Soffit = stone, Stringer = F.BronzeDeep })

	-- flight 1 side stringers + balustrades, landing rails, flight 2 balustrades
	local total = gs.Steps * gs.Run
	local angle = math.atan2(rise, total)
	local c = math.cos(angle)
	local slopeLen = math.sqrt(total * total + rise * rise)
	local stepH = rise / gs.Steps
	for _, side in { -1, 1 } do
		local slope = b1 * CFrame.Angles(angle, 0, 0)
		local v0, v1 = -stepH * c - 0.5, stepH * c + 0.45
		Kit.box(m, slope * CFrame.new(side * (width / 2 + 0.2), (v0 + v1) / 2, -slopeLen / 2), Vector3.new(0.4, v1 - v0, slopeLen + 0.4), F.BronzeDeep)
		slopedBalustrade(m, b1, width, rise, gs.Steps, gs.Run, side, "Brass")
		slopedBalustrade(m, b2, width, rise, gs.Steps, gs.Run, side, "Brass")
		local x = cx + side * (width / 2 + 0.2)
		Kit.railing(m, Vector3.new(x, yL, gs.LandingZ0 - 0.3), Vector3.new(x, yL, gs.LandingZ1 + 0.3), 3.85, "Glass", "Brass")
		-- bronze band capping the landing sides (continues the stringer line)
		Shell.plate(m, x - 0.2, x + 0.2, gs.LandingZ0, gs.LandingZ1, yL - 1.4, yL + 0.45, F.BronzeDeep)
	end
end

---------------------------------------------------------------------------
-- Basement stair
---------------------------------------------------------------------------
local function basementStair(parent: Instance)
	local bs = Layout.BasementStair
	local op = bs.Opening
	local m = Kit.model(parent, "BasementStair")
	local cx = (op.X0 + op.X1) / 2
	local width = op.X1 - op.X0
	local yB, yG = Layout.Y.B1, Layout.Y.G
	local yL = (yB + yG) / 2
	local rise = yG - yL

	-- upper flight (floating, visible from the concourse), landing block, lower flight
	local up = Kit.place(cx, yL, bs.LandingZ0, 180)
	floatingFlight(m, up, { Width = width, Rise = rise, Steps = bs.Steps, Run = bs.Run, Tread = "Terrazzo", Nosing = "SteelBrushed", Soffit = "ConcreteWarm", Stringer = F.Bronze })
	Shell.plate(m, op.X0, op.X1, bs.LandingZ1, bs.LandingZ0, yB, yL, "ConcreteWarm")
	Shell.plate(m, op.X0, op.X1, bs.LandingZ1, bs.LandingZ0, yL - 0.2, yL, "Terrazzo")
	local low = Kit.place(cx, yB, bs.BottomZ, 180)
	Kit.stairs(m, low, width, rise, bs.Steps, bs.Run, "Terrazzo", "SteelBrushed")

	for _, side in { -1, 1 } do
		slopedBalustrade(m, up, width, rise, bs.Steps, bs.Run, side, "SteelBrushed")
		slopedBalustrade(m, low, width, rise, bs.Steps, bs.Run, side, "SteelBrushed", 0.1)
		local x = cx + side * (width / 2 + 0.2)
		Kit.railing(m, Vector3.new(x, yL, bs.LandingZ1 - 0.2), Vector3.new(x, yL, bs.LandingZ0 + 0.2), 3.6, "Glass", "SteelBrushed")
	end

	-- glass enclosure around the ground-floor opening (gate model closes the north side)
	local h = 11.8
	local encl = Kit.model(m, "Enclosure")
	local zMid = (op.Z0 + op.Z1) / 2
	local len = op.Z1 - op.Z0
	Kit.glazing(encl, Kit.place(op.X0 - 0.2, yG + h / 2, zMid, 90), len, h, F.Bronze, 5, "Glass")
	Kit.glazing(encl, Kit.place(op.X1 + 0.2, yG + h / 2, zMid, -90), len, h, F.Bronze, 5, "Glass")
	Kit.glazing(encl, Kit.place(cx, yG + h / 2, op.Z0 - 0.2, 0), width + 0.4, h, F.Bronze, 2, "Glass")
	Shell.plate(encl, op.X0 - 0.5, op.X0 + 0.1, op.Z0 - 0.5, op.Z1, yG + h, yG + h + 0.4, F.Bronze)
	Shell.plate(encl, op.X1 - 0.1, op.X1 + 0.5, op.Z0 - 0.5, op.Z1, yG + h, yG + h + 0.4, F.Bronze)
	Shell.plate(encl, op.X0 - 0.5, op.X1 + 0.5, op.Z0 - 0.5, op.Z0 + 0.1, yG + h, yG + h + 0.4, F.Bronze)
	-- bronze kerb around the slab edge
	Shell.plate(encl, op.X0 - 0.5, op.X1 + 0.5, op.Z0 - 0.5, op.Z0 + 0.1, yG, yG + 0.3, F.Bronze)
	Shell.plate(encl, op.X0 - 0.5, op.X0 + 0.1, op.Z0, op.Z1, yG, yG + 0.3, F.Bronze)
	Shell.plate(encl, op.X1 - 0.1, op.X1 + 0.5, op.Z0, op.Z1, yG, yG + 0.3, F.Bronze)
end

---------------------------------------------------------------------------
-- Roof stair (switchback in Layout.RoofStair.Shaft)
---------------------------------------------------------------------------
local function roofStair(parent: Instance)
	local rs = Layout.RoofStair
	local s = rs.Shaft
	local m = Kit.model(parent, "RoofStair")
	local y0, y1 = Layout.Y.L2, Layout.CEIL.L2
	local outside: Kit.FinishArg = "PlasterGraphite"
	for _, r in Shell.SPECS.L2.Rooms do
		if r.Id == "ProFloor" then
			outside = r.Wall
		end
	end
	local inside: Kit.FinishArg = "ConcreteWarm"
	local t = Layout.INT_WALL

	-- shaft walls: two leaves (Pro Floor face outside, concrete inside); gated door south
	local gateW, gateH = 8, 10
	local cuts: { Ground.Box2 } = {
		{ a0 = rs.DoorX - gateW / 2, a1 = rs.DoorX + gateW / 2, b0 = y0 - 1, b1 = y0 + gateH },
		{ a0 = rs.DoorX - gateW / 2 - 0.2, a1 = rs.DoorX + gateW / 2 + 0.2, b0 = y0 + gateH - 0.01, b1 = y0 + gateH + 1.9 },
	}
	local function wall(axis: string, cst: number, a0: number, a1: number, outwardSign: number, wallCuts: { Ground.Box2 }?)
		local oo0, oo1 = if outwardSign > 0 then 0 else -t / 2, if outwardSign > 0 then t / 2 else 0
		local io0, io1 = if outwardSign > 0 then -t / 2 else 0, if outwardSign > 0 then 0 else t / 2
		Shell.leaf(m, axis, cst, a0, a1, oo0, oo1, y0, y1, outside, wallCuts)
		Shell.leaf(m, axis, cst, a0, a1, io0, io1, y0, y1, inside, wallCuts)
	end
	wall("X", s.Z0, s.X0 - t / 2, s.X1 + t / 2, -1, cuts)
	wall("X", s.Z1, s.X0 - t / 2, s.X1 + t / 2, 1)
	wall("Z", s.X0, s.Z0 + t / 2, s.Z1 - t / 2, -1)
	wall("Z", s.X1, s.Z0 + t / 2, s.Z1 - t / 2, 1)

	local ix0, ix1 = s.X0 + t / 2, s.X1 - t / 2 -- interior X 40.5 .. 55.5
	local mid = (s.X0 + s.X1) / 2
	local zA, zMid = 57, 73.25
	local rise = 13
	local steps, run = 13, 1.25
	local wA = mid - 0.25 - ix0
	local wB = ix1 - (mid + 0.25)

	-- flight A (west half, climbing north), solid mass + mid landing, flight B (east half, south)
	Kit.stairs(m, Kit.place((ix0 + mid - 0.25) / 2, y0, zA, 180), wA, rise, steps, run, "Concrete", "PowderYellow")
	Shell.plate(m, ix0, ix1, zMid, s.Z1 - t / 2, y0, y0 + rise, "ConcreteWarm")
	Shell.plate(m, mid + 0.25, ix1, zA, zMid, y0, y0 + rise, "ConcreteWarm")
	Kit.stairs(m, Kit.place((mid + 0.25 + ix1) / 2, y0 + rise, zMid, 0), wB, rise, steps, run, "Concrete", "PowderYellow")
	-- divider wall between the flights
	Shell.plate(m, mid - 0.25, mid + 0.25, zA, zMid, y0, y1, inside)

	-- handrails along the walls and the divider
	local function rail(x: number, zLow: number, yLow: number, zHigh: number, yHigh: number)
		Kit.span(m, Vector3.new(x, yLow + 3.2, zLow), Vector3.new(x, yHigh + 3.2, zHigh), 0.25, "SteelBrushed", Kit.DETAIL)
	end
	rail(ix0 + 0.3, zA, y0, zMid, y0 + rise)
	rail(mid - 0.55, zA, y0, zMid, y0 + rise)
	rail(mid + 0.55, zMid, y0 + rise, zA, y0 + 2 * rise)
	rail(ix1 - 0.3, zMid, y0 + rise, zA, y0 + 2 * rise)

	-- railings around the roof-level opening above flight B
	local h = M.ROOF_STAIR_HOLE
	local yr = Layout.Y.ROOF
	Kit.railing(m, Vector3.new(h.X0 - 0.2, yr, h.Z0), Vector3.new(h.X0 - 0.2, yr, h.Z1 + 0.2), 3.6, "Glass", "SteelBrushed")
	Kit.railing(m, Vector3.new(h.X0 - 0.2, yr, h.Z1 + 0.2), Vector3.new(h.X1 + 0.2, yr, h.Z1 + 0.2), 3.6, "Glass", "SteelBrushed")
	Kit.railing(m, Vector3.new(h.X1 + 0.2, yr, h.Z0), Vector3.new(h.X1 + 0.2, yr, h.Z1 + 0.2), 3.6, "Glass", "SteelBrushed")
end

---------------------------------------------------------------------------
-- Elevator core
---------------------------------------------------------------------------
local FLOOR_LABEL = { B1 = "B1", G = "G", L2 = "2", Roof = "R" }

local function elevator(parent: Instance)
	local e = Layout.Elevator
	local s = e.Shaft
	local m = Kit.model(parent, "ElevatorCore")
	local top = M.PENTHOUSE_TOP
	local doorH = 10
	local z0, z1 = e.DoorZ - e.DoorWidth / 2, e.DoorZ + e.DoorWidth / 2
	local stops: { { name: string, y: number } } = {
		{ name = "B1", y = Layout.Y.B1 },
		{ name = "G", y = Layout.Y.G },
		{ name = "L2", y = Layout.Y.L2 },
		{ name = "Roof", y = Layout.Y.ROOF },
	}
	local cuts: { Ground.Box2 } = {}
	for _, st in stops do
		table.insert(cuts, { a0 = z0, a1 = z1, b0 = st.y, b1 = st.y + doorH })
	end
	-- shaft walls inside the rect (east face at DoorX); B1 portion in concourse concrete
	for _, band in { { y0 = Layout.Y.B1, y1 = Layout.Y.G, f = "ConcreteWarm" :: Kit.FinishArg }, { y0 = Layout.Y.G, y1 = top, f = "Travertine" :: Kit.FinishArg } } do
		Shell.leaf(m, "Z", s.X0, s.Z0, s.Z1, 0, 1, band.y0, band.y1, band.f)
		Shell.leaf(m, "Z", s.X1, s.Z0, s.Z1, -1, 0, band.y0, band.y1, band.f, cuts)
		Shell.leaf(m, "X", s.Z0, s.X0 + 1, s.X1 - 1, 0, 1, band.y0, band.y1, band.f)
		Shell.leaf(m, "X", s.Z1, s.X0 + 1, s.X1 - 1, -1, 0, band.y0, band.y1, band.f)
	end

	local x = e.DoorX
	for _, st in stops do
		local y = st.y
		-- bronze portal wall (call panels mount on its face at X = DoorX + 0.2)
		Shell.leaf(m, "Z", x, s.Z0, s.Z1, 0, 0.2, y, math.min(y + 14, top), F.Bronze, { { a0 = z0, a1 = z1, b0 = y - 1, b1 = y + doorH } })
		-- closed brushed-steel leaves with a dark centre seam
		Shell.wbox(m, "Z", x, z0, e.DoorZ - 0.03, -0.75, -0.55, y, y + doorH, "SteelBrushed")
		Shell.wbox(m, "Z", x, e.DoorZ + 0.03, z1, -0.75, -0.55, y, y + doorH, "SteelBrushed")
		Shell.wbox(m, "Z", x, e.DoorZ - 0.03, e.DoorZ + 0.03, -0.8, -0.7, y, y + doorH, "PowderBlack", Kit.DETAIL)
		-- steel sill + frame
		Shell.wbox(m, "Z", x, z0 - 0.45, z1 + 0.45, -1, 0.4, y - 0.2, y + 0.04, "SteelBrushed", Kit.DETAIL)
		Shell.wbox(m, "Z", x, z0 - 0.45, z0, -0.5, 0.4, y, y + doorH + 0.45, "SteelBrushed", Kit.DETAIL)
		Shell.wbox(m, "Z", x, z1, z1 + 0.45, -0.5, 0.4, y, y + doorH + 0.45, "SteelBrushed", Kit.DETAIL)
		Shell.wbox(m, "Z", x, z0 - 0.45, z1 + 0.45, -0.5, 0.4, y + doorH, y + doorH + 0.45, "SteelBrushed", Kit.DETAIL)
		-- floor indicator
		local ind = Shell.wbox(m, "Z", x, e.DoorZ - 1.3, e.DoorZ + 1.3, 0.2, 0.3, y + doorH + 1.1, y + doorH + 2.1, "Ink", Kit.DETAIL)
		ind.Name = "FloorIndicator"
		local sg = Kit.sign(ind, FLOOR_LABEL[st.name] or st.name, {
			Face = Enum.NormalId.Right,
			TextColor = Color3.fromRGB(255, 186, 92),
			LightInfluence = 0,
			Brightness = 1.4,
			PixelsPerStud = 40,
			Padding = 0.1,
		})
		sg.Name = "FloorIndicator"
	end
end

function M.build(ctx: Context.Ctx)
	local root = Kit.folder(ctx.Structure, "Circulation")
	grandStair(root)
	basementStair(root)
	roofStair(root)
	elevator(root)
end

return M
