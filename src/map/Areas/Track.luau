--!strict
--[[
	Running track surfaces built from straight panels and arc segments.

	Track.stadium(parent, center, halfStraight, innerRadius, lanes, laneWidth, axis)
	  axis "Z": straights run along Z (curves at the north/south ends)
	  axis "X": straights run along X
	Track.rounded(parent, center, outerHalf (Vector2 X/Z), cornerRadius, width)
	  rounded-rectangle track (rooftop)
]]
local Kit = require("../Kit")

local Track = {}

local SURFACE = "TrackRed"
local LINE = "FabricWhite"

local function arc(parent: Instance, c: Vector3, r0: number, r1: number, a0: number, a1: number, lanes: number, segs: number)
	local mid = (r0 + r1) / 2
	local step = (a1 - a0) / segs
	local chord = 2 * r1 * math.sin(step / 2) + 0.35
	for i = 0, segs - 1 do
		local a = a0 + step * (i + 0.5)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = c + dir * mid
		local cf = CFrame.lookAt(pos, pos + dir)
		Kit.box(parent, cf * CFrame.new(0, 0.06, 0), Vector3.new(chord, 0.12, r1 - r0), SURFACE, { Collide = false, Shadow = false })
		for l = 0, lanes do
			local rr = r0 + (r1 - r0) * l / lanes
			local p = c + dir * rr
			local lcf = CFrame.lookAt(p, p + dir)
			Kit.box(parent, lcf * CFrame.new(0, 0.13, 0), Vector3.new(2 * rr * math.sin(step / 2) + 0.05, 0.02, 0.18), LINE, Kit.DETAIL)
		end
	end
end

local function straight(parent: Instance, cf: CFrame, length: number, width: number, lanes: number)
	Kit.box(parent, cf * CFrame.new(0, 0.06, 0), Vector3.new(width, 0.12, length), SURFACE, { Collide = false, Shadow = false })
	for l = 0, lanes do
		local x = -width / 2 + width * l / lanes
		Kit.box(parent, cf * CFrame.new(x, 0.13, 0), Vector3.new(0.18, 0.02, length), LINE, Kit.DETAIL)
	end
end

function Track.stadium(parent: Instance, center: Vector3, halfStraight: number, innerRadius: number, lanes: number, laneWidth: number)
	local width = lanes * laneWidth
	local m = Kit.model(parent, "Track", CFrame.new(center))
	local r0, r1 = innerRadius, innerRadius + width
	for _, side in { -1, 1 } do
		straight(m, CFrame.new(center + Vector3.new(side * (r0 + width / 2), 0, 0)), halfStraight * 2, width, lanes)
		-- curve at the end in direction `side` along Z
		local c = center + Vector3.new(0, 0, side * halfStraight)
		local a0 = if side > 0 then 0 else math.pi
		arc(m, c, r0, r1, a0, a0 + math.pi, lanes, 18)
	end
	-- start/finish line
	Kit.box(m, CFrame.new(center + Vector3.new(r0 + width / 2, 0.14, 0)), Vector3.new(width, 0.02, 0.6), LINE, Kit.DETAIL)
end

function Track.rounded(parent: Instance, center: Vector3, outerHalf: Vector2, radius: number, width: number, lanes: number)
	local m = Kit.model(parent, "Track", CFrame.new(center))
	local hx, hz = outerHalf.X, outerHalf.Y
	local r0, r1 = radius - width, radius
	-- straights
	straight(m, CFrame.new(center + Vector3.new(0, 0, hz - width / 2)) * CFrame.Angles(0, math.rad(90), 0), (hx - radius) * 2, width, lanes)
	straight(m, CFrame.new(center + Vector3.new(0, 0, -hz + width / 2)) * CFrame.Angles(0, math.rad(90), 0), (hx - radius) * 2, width, lanes)
	straight(m, CFrame.new(center + Vector3.new(hx - width / 2, 0, 0)), (hz - radius) * 2, width, lanes)
	straight(m, CFrame.new(center + Vector3.new(-hx + width / 2, 0, 0)), (hz - radius) * 2, width, lanes)
	-- corners
	local corners = {
		{ x = hx - radius, z = hz - radius, a = 0 },
		{ x = -(hx - radius), z = hz - radius, a = math.pi / 2 },
		{ x = -(hx - radius), z = -(hz - radius), a = math.pi },
		{ x = hx - radius, z = -(hz - radius), a = math.pi * 1.5 },
	}
	for _, c in corners do
		arc(m, center + Vector3.new(c.x, 0, c.z), r0, r1, c.a, c.a + math.pi / 2, lanes, 10)
	end
end

return Track
