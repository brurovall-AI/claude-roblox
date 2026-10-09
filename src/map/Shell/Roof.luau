--!strict
--[[
	Roof (deck at Y = 54): roof slab (its underside is the L2 ceiling), paver
	deck with a dark granite border, perimeter glass railing, gabled atrium
	skylight on a stone curb, elevator + stair penthouses and a few
	mechanical units parked in the deck corners.

	The Rooftop area engineer builds the running track (rounded rectangle,
	outer half extents 138 x 88, corner radius 36, 3 lanes x 4): everything
	here stays out of that band (mechanical units sit outside its corners, the
	stair penthouse ends at Z = 74, two studs short of the track's inner edge).
]]

local Circulation = require("./Circulation")
local Context = require("../Context")
local Ground = require("./Ground")
local Kit = require("../Kit")
local Layout = require("../Layout")

local Shell = Ground.Shell
local F = Shell.F

local M = {}

local Y = Layout.Y.ROOF
local HOUSE_TOP = Circulation.PENTHOUSE_TOP -- penthouse roof slab bottom
M.STAIR_HOUSE = Shell.rect(38, 58, 50, 74)

---------------------------------------------------------------------------
-- Skylight: stone curb + steel-framed glass gable over the atrium
---------------------------------------------------------------------------
local function skylight(parent: Instance)
	local s = Layout.Roof.Skylight
	local m = Kit.model(parent, "Skylight")
	local curbTop = Y + 3.5
	local rise = 4
	local cw = 1.5
	-- curb (also lines the slab edge seen from the atrium)
	Shell.plate(m, s.X0 - cw, s.X1 + cw, s.Z0 - cw, s.Z0 + 0.3, Y - 2.6, curbTop, F.StoneLight)
	Shell.plate(m, s.X0 - cw, s.X1 + cw, s.Z1 - 0.3, s.Z1 + cw, Y - 2.6, curbTop, F.StoneLight)
	Shell.plate(m, s.X0 - cw, s.X0 + 0.3, s.Z0 + 0.3, s.Z1 - 0.3, Y - 2.6, curbTop, F.StoneLight)
	Shell.plate(m, s.X1 - 0.3, s.X1 + cw, s.Z0 + 0.3, s.Z1 - 0.3, Y - 2.6, curbTop, F.StoneLight)
	Shell.plate(m, s.X0 - cw - 0.2, s.X1 + cw + 0.2, s.Z0 - cw - 0.2, s.Z0 - cw + 0.4, curbTop, curbTop + 0.3, F.Bronze, Kit.DETAIL)
	Shell.plate(m, s.X0 - cw - 0.2, s.X1 + cw + 0.2, s.Z1 + cw - 0.4, s.Z1 + cw + 0.2, curbTop, curbTop + 0.3, F.Bronze, Kit.DETAIL)

	local cx, cz = (s.X0 + s.X1) / 2, (s.Z0 + s.Z1) / 2
	local half = (s.X1 - s.X0) / 2
	local len = s.Z1 - s.Z0
	local angle = math.atan2(rise, half)
	local slopeLen = math.sqrt(half * half + rise * rise)
	for _, side in { -1, 1 } do
		local plane = CFrame.new(cx + side * half / 2, curbTop + rise / 2, cz) * CFrame.Angles(0, 0, -side * angle)
		Kit.box(m, plane, Vector3.new(slopeLen, 0.2, len), "Glass", { Collide = true, Shadow = false })
		-- rafters under the glass
		local bays = 8
		for i = 0, bays do
			local z = -len / 2 + len * i / bays
			Kit.box(m, plane * CFrame.new(0, -0.55, z), Vector3.new(slopeLen, 0.9, 0.45), "SteelDark", Kit.DETAIL)
		end
		-- purlin at mid-slope + eaves beam
		Kit.box(m, plane * CFrame.new(0, -0.45, 0), Vector3.new(0.4, 0.7, len), "SteelDark", Kit.DETAIL)
		Kit.box(m, CFrame.new(cx + side * half, curbTop + 0.3, cz), Vector3.new(0.8, 0.6, len), "SteelDark", Kit.DETAIL)
		-- glass gable ends (two wedges per end)
		for _, ez in { s.Z0, s.Z1 } do
			local xAxis = Vector3.new(0, 0, side)
			local cf = CFrame.fromMatrix(Vector3.new(cx + side * half / 2, curbTop + rise / 2, ez), xAxis, Vector3.new(0, 1, 0))
			Kit.wedge(m, cf, Vector3.new(0.2, rise, half), "Glass", { Collide = true, Shadow = false })
		end
	end
	Kit.box(m, CFrame.new(cx, curbTop + rise + 0.1, cz), Vector3.new(0.9, 0.9, len + 0.4), "SteelDark", Kit.DETAIL)
end

---------------------------------------------------------------------------
-- Penthouses
---------------------------------------------------------------------------
local function elevatorHouse(parent: Instance)
	local r = Layout.Roof.ElevatorHouse
	local e = Layout.Elevator
	local m = Kit.model(parent, "ElevatorHouse")
	local y1 = HOUSE_TOP
	-- west / north / south walls inside the rect; east side opens onto the lift doors
	Shell.plate(m, r.X0, r.X0 + 1, r.Z0, r.Z1, Y, y1, "Travertine")
	Shell.plate(m, r.X0 + 1, r.X1, r.Z0, r.Z0 + 1, Y, y1, "Travertine")
	Shell.plate(m, r.X0 + 1, r.X1, r.Z1 - 1, r.Z1, Y, y1, "Travertine")
	Shell.plate(m, r.X1 - 1, r.X1, r.Z0 + 1, e.Shaft.Z0, Y, y1, "Travertine")
	Shell.plate(m, r.X1 - 1, r.X1, e.Shaft.Z1, r.Z1 - 1, Y, y1, "Travertine")
	-- roof slab cantilevering over the alcove, thin bronze fascia, granite kerb
	Shell.plate(m, r.X0 - 0.5, r.X1 + 4, r.Z0 - 0.5, r.Z1 + 0.5, y1, y1 + 1, F.StoneLight)
	Shell.plate(m, r.X0 - 0.6, r.X1 + 4.1, r.Z0 - 0.6, r.Z1 + 0.6, y1 - 0.35, y1, F.Bronze, Kit.DETAIL)
	Shell.plate(m, r.X0 - 0.5, r.X1 - 1, r.Z0 - 0.5, r.Z1 + 0.5, Y, Y + 0.6, F.GraniteDark)
end

local function stairHouse(parent: Instance)
	local r = M.STAIR_HOUSE
	local rs = Layout.RoofStair
	local m = Kit.model(parent, "StairHouse")
	local y1 = HOUSE_TOP
	local h = y1 - Y - 0.6
	local yMid = Y + 0.6 + h / 2
	-- glass walls in bronze frames on west / east / north, travertine south wall with the doorway
	Kit.glazing(m, Kit.place(r.X0 + 0.5, yMid, (r.Z0 + r.Z1) / 2 + 0.5, 90), r.Z1 - r.Z0 - 1, h, F.Bronze, 4, "GlassTint")
	Kit.glazing(m, Kit.place(r.X1 - 0.5, yMid, (r.Z0 + r.Z1) / 2 + 0.5, -90), r.Z1 - r.Z0 - 1, h, F.Bronze, 4, "GlassTint")
	Kit.glazing(m, Kit.place((r.X0 + r.X1) / 2, yMid, r.Z1 - 0.5, 180), r.X1 - r.X0 - 1, h, F.Bronze, 3, "GlassTint")
	local doorW, doorH = 8, 10
	Shell.leaf(m, "X", r.Z0 + 0.5, r.X0, r.X1, -0.5, 0.5, Y, y1, "Travertine", {
		{ a0 = rs.DoorX - doorW / 2 - 0.4, a1 = rs.DoorX + doorW / 2 + 0.4, b0 = Y - 1, b1 = Y + doorH + 0.4 },
	})
	Shell.portal(m, "X", r.Z0 + 0.5, rs.DoorX, doorW, doorH, Y, 1.3, F.Bronze)
	-- kerb, corner posts, roof slab with a thin bronze fascia
	Shell.plate(m, r.X0, r.X0 + 1, r.Z0 + 1, r.Z1, Y, Y + 0.6, "Travertine")
	Shell.plate(m, r.X1 - 1, r.X1, r.Z0 + 1, r.Z1, Y, Y + 0.6, "Travertine")
	Shell.plate(m, r.X0 + 1, r.X1 - 1, r.Z1 - 1, r.Z1, Y, Y + 0.6, "Travertine")
	for _, p in { { r.X0, r.Z1 }, { r.X1, r.Z1 } } do
		local px = if p[1] < 48 then p[1] + 0.5 else p[1] - 0.5
		Shell.plate(m, px - 0.5, px + 0.5, p[2] - 1, p[2], Y, y1, F.Bronze)
	end
	Shell.plate(m, r.X0 - 1, r.X1 + 1, r.Z0 - 2.5, r.Z1 + 0.5, y1, y1 + 1, F.StoneLight)
	Shell.plate(m, r.X0 - 1.1, r.X1 + 1.1, r.Z0 - 2.6, r.Z1 + 0.6, y1 - 0.35, y1, F.Bronze, Kit.DETAIL)
end

---------------------------------------------------------------------------
-- Mechanical units (outside the track's rounded corners)
---------------------------------------------------------------------------
local function hvac(parent: Instance, x: number, z: number)
	local m = Kit.model(parent, "RooftopUnit", CFrame.new(x, Y, z))
	Shell.plate(m, x - 6.6, x + 6.6, z - 4, z + 4, Y, Y + 0.6, "ConcreteDark")
	Shell.plate(m, x - 6, x + 6, z - 3.4, z + 3.4, Y + 0.6, Y + 5.2, "PowderGraphite")
	Shell.plate(m, x - 6.1, x + 6.1, z - 3.5, z + 3.5, Y + 5.2, Y + 5.5, "SteelBrushed", Kit.DETAIL)
	for _, fx in { -3, 3 } do
		Kit.cylY(m, CFrame.new(x + fx, Y + 6, z), 1, 4.4, "SteelBrushed", Kit.DETAIL)
		Kit.cylY(m, CFrame.new(x + fx, Y + 6.52, z), 0.06, 3.8, "PowderBlack", Kit.DETAIL)
	end
	-- louvre lines on both long faces
	for _, side in { -1, 1 } do
		for i = 0, 3 do
			Shell.plate(m, x - 5.4, x + 5.4, z + side * 3.4 - 0.08, z + side * 3.4 + 0.08, Y + 1.4 + i * 0.9, Y + 1.7 + i * 0.9, "PowderBlack", Kit.DETAIL)
		end
	end
	return m
end

function M.build(ctx: Context.Ctx)
	local root = Kit.folder(ctx.Structure, "Roof")
	local b = Layout.Building
	local holes = { Layout.Roof.Skylight, Layout.Elevator.Shaft, Circulation.ROOF_STAIR_HOLE }

	-- slab + deck (concrete pavers, dark granite border band)
	local slab = Kit.folder(root, "Slab")
	Shell.slabStructure(slab, b, Y, holes, Shell.SPECS.L2)
	local field = Shell.rect(b.X0 + 7, b.X1 - 7, b.Z0 + 7, b.Z1 - 7)
	local deckHoles: { Ground.Box2 } = {}
	for _, h in holes do
		table.insert(deckHoles, Shell.box2(h))
	end
	for _, r in Shell.carve(field.X0, field.X1, field.Z0, field.Z1, deckHoles) do
		Shell.plate(slab, r.a0, r.a1, r.b0, r.b1, Y - 0.2, Y, F.Paver)
	end
	for _, r in Shell.carve(b.X0, b.X1, b.Z0, b.Z1, { Shell.box2(field) }) do
		Shell.plate(slab, r.a0, r.a1, r.b0, r.b1, Y - 0.2, Y, F.GraniteDark)
	end

	-- perimeter glass railing just inside the parapet
	local rail = Kit.folder(root, "Railing")
	local ix, iz = b.X1 - 1.5, b.Z1 - 1.5
	local corners = {
		Vector3.new(-ix, Y, -iz),
		Vector3.new(ix, Y, -iz),
		Vector3.new(ix, Y, iz),
		Vector3.new(-ix, Y, iz),
	}
	for i = 1, 4 do
		Kit.railing(rail, corners[i], corners[i % 4 + 1], 4.4, "Glass", "SteelBrushed")
	end

	skylight(root)
	elevatorHouse(root)
	stairHouse(root)

	local mech = Kit.folder(root, "Mechanical")
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			hvac(mech, sx * 136, sz * 92)
		end
	end
end

return M
