--!strict
--[[
	Apex Lab annex: a futuristic pavilion floating on slim titanium pillars
	east of the main building (Layout.Apex: floor 28, ceiling 54), reached by
	the glass skybridge (Layout.Skybridge) from the L2 East Hall gate.

	Language: white composite shell, smoked-glass walls behind white fins,
	rounded corner posts, a tapered belly under the floor slab and thin cyan
	light lines (tiny neon) tracing the slab and roof edges. The interior is
	left empty for the Apex area engineer (floor = Composite at Y 28,
	ceiling = Composite underside at Y 54, walls inside the rect).
]]

local Context = require("../Context")
local Ground = require("./Ground")
local Kit = require("../Kit")
local Layout = require("../Layout")

local Shell = Ground.Shell

local M = {}

local CYAN = "LightCyan"

-- Upside-down wedge under a slab edge: flat top, vertical inner face, slope up to the outer edge.
-- `inward` = horizontal direction pointing into the building.
local function belly(parent: Instance, centre: Vector3, inward: Vector3, length: number, depth: number, width: number)
	local z = inward.Unit
	local y = Vector3.new(0, -1, 0)
	local x = y:Cross(z)
	Kit.wedge(parent, CFrame.fromMatrix(centre, x, y, z), Vector3.new(length, depth, width), "Composite", { Collide = true })
end

local function pavilion(parent: Instance)
	local a = Layout.Apex
	local r = a.Rect
	local m = Kit.model(parent, "ApexPavilion")
	local fy, cy = a.Floor, a.Ceiling
	local cx, cz = (r.X0 + r.X1) / 2, (r.Z0 + r.Z1) / 2
	local w, d = r.X1 - r.X0, r.Z1 - r.Z0

	-- floor slab + tapered belly
	Shell.plate(m, r.X0, r.X1, r.Z0, r.Z1, fy - 2, fy, "Composite")
	local inset, drop = 7, 2.5
	Shell.plate(m, r.X0 + inset, r.X1 - inset, r.Z0 + inset, r.Z1 - inset, fy - 2 - drop, fy - 2, "Composite")
	local by = fy - 2 - drop / 2
	belly(m, Vector3.new(cx, by, r.Z0 + inset / 2), Vector3.new(0, 0, 1), w, drop, inset)
	belly(m, Vector3.new(cx, by, r.Z1 - inset / 2), Vector3.new(0, 0, -1), w, drop, inset)
	belly(m, Vector3.new(r.X0 + inset / 2, by, cz), Vector3.new(1, 0, 0), d, drop, inset)
	belly(m, Vector3.new(r.X1 - inset / 2, by, cz), Vector3.new(-1, 0, 0), d, drop, inset)

	-- titanium V-struts on round plinths
	local pillarTop = fy - 2 - drop
	for _, px in { cx - 20, cx + 20 } do
		for _, pz in { cz - 30, cz, cz + 30 } do
			Kit.cylY(m, CFrame.new(px, 0.35, pz), 0.7, 4.2, "Composite")
			for _, sx in { -1, 1 } do
				Kit.span(m, Vector3.new(px, 0.6, pz), Vector3.new(px + sx * 7, pillarTop + 0.2, pz), 1.5, "Titanium")
			end
		end
	end

	-- walls: composite plinth band + smoked-glass ribbon + composite fascia band, a
	-- cyan line in the shadow gap; the west wall is solid with the skybridge portal
	local sb = Layout.Skybridge
	local bridgeTop = fy + 15
	Shell.leaf(m, "Z", r.X0, r.Z0, r.Z1, 0, 1, fy, cy, "Composite", {
		{ a0 = sb.Z0, a1 = sb.Z1, b0 = fy - 1, b1 = bridgeTop },
	})
	local g0, g1 = fy + 3.4, cy - 3.6
	local function glassSide(axis: string, c: number, a0: number, a1: number, s: number)
		-- s = outward sign across the wall line
		local o0, o1 = math.min(0, -s * 1.2), math.max(0, -s * 1.2)
		Shell.wbox(m, axis, c, a0, a1, o0, o1, fy, g0 - 0.2, "Composite")
		Shell.wbox(m, axis, c, a0, a1, o0, o1, g1, cy, "Composite")
		Shell.wbox(m, axis, c, a0, a1, -s * 0.5 - 0.1, -s * 0.5 + 0.1, g0 - 0.2, g1, "GlassSmoked", { Collide = true, Shadow = false })
		local l0, l1 = math.min(-s * 0.1, s * 0.05), math.max(-s * 0.1, s * 0.05)
		Shell.wbox(m, axis, c, a0, a1, l0, l1, g0 - 0.2, g0, CYAN, Kit.DETAIL)
		local n = math.floor((a1 - a0) / 15)
		for i = 1, n - 1 do
			local at = a0 + (a1 - a0) * i / n
			local f0, f1 = math.min(-s * 0.6, s * 0.15), math.max(-s * 0.6, s * 0.15)
			Shell.wbox(m, axis, c, at - 0.2, at + 0.2, f0, f1, g0, g1, "Titanium", Kit.DETAIL)
		end
	end
	glassSide("X", r.Z0, r.X0 + 1, r.X1, -1)
	glassSide("X", r.Z1, r.X0 + 1, r.X1, 1)
	glassSide("Z", r.X1, r.Z0, r.Z1, 1)
	-- rounded corner posts
	for _, p in { { r.X0, r.Z0 }, { r.X1, r.Z0 }, { r.X0, r.Z1 }, { r.X1, r.Z1 } } do
		Kit.cylY(m, CFrame.new(p[1], (fy - 2 + cy) / 2, p[2]), cy - fy + 2, 4, "Composite")
	end

	-- roof: overhanging composite slab, titanium edge band, cyan line under the overhang
	local o = 5
	Shell.plate(m, r.X0 - o, r.X1 + o, r.Z0 - o, r.Z1 + o, cy, cy + 1.6, "Composite")
	Shell.plate(m, r.X0 - o + 0.2, r.X1 + o - 0.2, r.Z0 - o + 0.2, r.Z1 + o - 0.2, cy + 1.6, cy + 2.4, "Titanium")
	local function ring(x0: number, x1: number, z0: number, z1: number, y0: number, y1: number, t: number)
		Shell.plate(m, x0, x1, z0, z0 + t, y0, y1, CYAN, Kit.DETAIL)
		Shell.plate(m, x0, x1, z1 - t, z1, y0, y1, CYAN, Kit.DETAIL)
		Shell.plate(m, x0, x0 + t, z0 + t, z1 - t, y0, y1, CYAN, Kit.DETAIL)
		Shell.plate(m, x1 - t, x1, z0 + t, z1 - t, y0, y1, CYAN, Kit.DETAIL)
	end
	ring(r.X0 - o + 0.8, r.X1 + o - 0.8, r.Z0 - o + 0.8, r.Z1 + o - 0.8, cy - 0.12, cy, 0.25)
	-- cyan line along the floor slab edge
	ring(r.X0 - 0.12, r.X1 + 0.12, r.Z0 - 0.12, r.Z1 + 0.12, fy - 1.25, fy - 1.05, 0.12)
	-- roof lantern: smoked glass box in a titanium frame
	local lx0, lx1, lz0, lz1 = cx - 16, cx + 16, cz - 22, cz + 22
	Shell.plate(m, lx0, lx1, lz0, lz1, cy + 2.4, cy + 4.6, "GlassSmoked", { Shadow = false })
	Shell.plate(m, lx0 - 0.4, lx1 + 0.4, lz0 - 0.4, lz1 + 0.4, cy + 4.6, cy + 5, "Titanium")

	-- cool soffit lights under the belly (exterior: lights the forecourt below)
	for _, lx in { cx - 20, cx + 20 } do
		for _, lz in { cz - 22, cz + 22 } do
			local fx = Shell.plate(m, lx - 1.5, lx + 1.5, lz - 1.5, lz + 1.5, pillarTop - 0.08, pillarTop, "LightCool", Kit.DETAIL)
			Kit.light(fx, "Surface", { Face = Enum.NormalId.Bottom, Angle = 90, Range = 30, Brightness = 1.4, Color = Color3.fromRGB(226, 240, 255) })
		end
	end
end

local function skybridge(parent: Instance)
	local sb = Layout.Skybridge
	local m = Kit.model(parent, "Skybridge")
	local y = Layout.Y.L2
	local top = y + 15
	local x0, x1 = sb.X0 + 1, sb.X1 -- starts at the building's outer wall face
	local zc = (sb.Z0 + sb.Z1) / 2

	-- deck: composite with a walkable glass centre strip, titanium edge beams below
	Shell.plate(m, x0, x1, sb.Z0, zc - 1.6, y - 1.2, y, "Composite")
	Shell.plate(m, x0, x1, zc + 1.6, sb.Z1, y - 1.2, y, "Composite")
	Shell.plate(m, x0, x1, zc - 1.6, zc + 1.6, y - 0.3, y, "GlassSmoked", { Collide = true, Shadow = false })
	for _, ez in { sb.Z0, sb.Z1 } do
		Shell.plate(m, x0, x1, ez - 0.6, ez + 0.6, y - 2.6, y - 1.2, "Titanium")
	end
	-- glass sides + composite roof
	for _, s in { -1, 1 } do
		local ez = if s < 0 then sb.Z0 else sb.Z1
		Shell.plate(m, x0, x1, ez - 0.1, ez + 0.1, y, top, "Glass", { Collide = true, Shadow = false })
		Shell.plate(m, x0, x1, ez - s * 0.55 - 0.3, ez - s * 0.55 + 0.3, y + 3.6, y + 3.9, "Titanium", Kit.DETAIL)
	end
	Shell.plate(m, x0 - 0.5, x1, sb.Z0 - 0.8, sb.Z1 + 0.8, top, top + 1, "Composite")
	-- titanium portal ribs
	local n = 5
	for i = 0, n - 1 do
		local rx = x0 + 2.5 + (x1 - x0 - 5) * i / (n - 1)
		Shell.plate(m, rx - 0.25, rx + 0.25, sb.Z0 - 0.5, sb.Z0 - 0.1, y - 1.2, top, "Titanium", Kit.DETAIL)
		Shell.plate(m, rx - 0.25, rx + 0.25, sb.Z1 + 0.1, sb.Z1 + 0.5, y - 1.2, top, "Titanium", Kit.DETAIL)
		Shell.plate(m, rx - 0.25, rx + 0.25, sb.Z0 - 0.5, sb.Z1 + 0.5, top - 0.5, top, "Titanium", Kit.DETAIL)
	end
	-- cyan lines along both roof edges
	Shell.plate(m, x0, x1, sb.Z0 - 0.8, sb.Z0 - 0.55, top - 0.1, top, CYAN, Kit.DETAIL)
	Shell.plate(m, x0, x1, sb.Z1 + 0.55, sb.Z1 + 0.8, top - 0.1, top, CYAN, Kit.DETAIL)
end

function M.build(ctx: Context.Ctx)
	local root = Kit.folder(ctx.Structure, "Apex")
	pavilion(root)
	skybridge(root)
end

return M
