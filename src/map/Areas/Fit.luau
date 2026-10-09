--!strict
--[[
	Fit: layout helpers for area dressing.

	  Fit.pack(parent, rect, floorY, facing, items, keepouts, opts)
	      Places stations/decor in tidy rows inside `rect`, everyone facing
	      `facing` ("N"|"S"|"E"|"W" = the wall trainees look at). Rows start at
	      that wall; items never overlap each other or any keepout rect.
	  Fit.lights(parent, rect, ceilY, kind, step, keepouts?, opts?)
	      Grid of ceiling fixtures (Props.ceilingLight) skipping keepouts.
	  Fit.doorKeepout(door, depth)  -> Rect clearing a doorway on both sides
	  Fit.wallCf(rect, side, along, y, inset) -> CFrame on a wall face, looking into the room
]]

local Equipment = require("../Equipment")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")

export type Rect = Layout.Rect
export type Item = {
	Type: string?, -- station type
	Decor: string?, -- decor kind (Equipment.decor)
	Tier: number,
	Count: number?,
	Length: number?, -- decor length
	Size: Vector3?, -- override footprint (X width, Z depth)
}

local Fit = {}

local YAW = { S = 0, N = 180, W = 90, E = -90 }

local function overlaps(a: Rect, b: Rect): boolean
	return a.X0 < b.X1 and a.X1 > b.X0 and a.Z0 < b.Z1 and a.Z1 > b.Z0
end

function Fit.doorKeepout(door: Layout.Door, depth: number?): Rect
	local d = depth or 9
	local h = door.Width / 2 + 2
	if door.Wall == "NS" then
		return { X0 = door.X - d, X1 = door.X + d, Z0 = door.Z - h, Z1 = door.Z + h }
	end
	return { X0 = door.X - h, X1 = door.X + h, Z0 = door.Z - d, Z1 = door.Z + d }
end

function Fit.rect(x0: number, x1: number, z0: number, z1: number): Rect
	return { X0 = x0, X1 = x1, Z0 = z0, Z1 = z1 }
end

local function footprint(item: Item): Vector3
	if item.Size then
		return item.Size
	end
	if item.Type then
		return Equipment.Footprints[item.Type] or Vector3.new(6, 6, 6)
	end
	return Vector3.new(item.Length or 6, 4, 3)
end

--[[
	opts: Margin (wall gap, default 3), Gap (between items, 3), Aisle (between rows, 5),
	AreaId (station AreaId), MaxRows
]]
function Fit.pack(parent: Instance, rect: Rect, y: number, facing: string, items: { Item }, keepouts: { Rect }?, opts: { [string]: any }?): number
	local o: { [string]: any } = opts or {}
	local margin = o.Margin or 3
	local gap = o.Gap or 3
	local aisle = o.Aisle or 5
	local blocked: { Rect } = table.clone(keepouts or {})
	local yaw = YAW[facing] or 0

	-- local frame: u along the row, v away from the faced wall
	local uMin, uMax, vMin, vMax
	if facing == "S" or facing == "N" then
		uMin, uMax = rect.X0 + margin, rect.X1 - margin
		vMin, vMax = 0, (rect.Z1 - rect.Z0) - margin * 2
	else
		uMin, uMax = rect.Z0 + margin, rect.Z1 - margin
		vMin, vMax = 0, (rect.X1 - rect.X0) - margin * 2
	end

	local function toWorld(u: number, v: number): (number, number)
		if facing == "S" then
			return u, rect.Z0 + margin + v
		elseif facing == "N" then
			return u, rect.Z1 - margin - v
		elseif facing == "W" then
			return rect.X0 + margin + v, u
		else
			return rect.X1 - margin - v, u
		end
	end

	local flat: { Item } = {}
	for _, it in items do
		for _ = 1, it.Count or 1 do
			table.insert(flat, it)
		end
	end

	local placed = 0
	local u, v = uMin, vMin
	local rowDepth = 0
	local i = 1
	local guard = 0
	while i <= #flat and guard < 5000 do
		guard += 1
		local it = flat[i]
		local fp = footprint(it)
		local w, d = fp.X, fp.Z
		if u + w > uMax then
			-- next row
			u = uMin
			v += rowDepth + aisle
			rowDepth = 0
			if v + d > vMax then
				break
			end
		end
		local cx, cz = toWorld(u + w / 2, v + d / 2)
		local hw, hd = w / 2, d / 2
		local box: Rect
		if facing == "S" or facing == "N" then
			box = { X0 = cx - hw - 0.5, X1 = cx + hw + 0.5, Z0 = cz - hd - 0.5, Z1 = cz + hd + 0.5 }
		else
			box = { X0 = cx - hd - 0.5, X1 = cx + hd + 0.5, Z0 = cz - hw - 0.5, Z1 = cz + hw + 0.5 }
		end
		local hit = false
		for _, k in blocked do
			if overlaps(box, k) then
				hit = true
				break
			end
		end
		if hit then
			u += 2
		else
			local cf = Kit.place(cx, y, cz, yaw)
			if it.Type then
				Equipment.build(parent, it.Type, it.Tier, cf, { AreaId = o.AreaId })
			else
				-- decor racks run along the row, facing the trainees' wall side
				Equipment.decor(parent, it.Decor :: string, it.Tier, cf, { Length = it.Length })
			end
			table.insert(blocked, box)
			placed += 1
			rowDepth = math.max(rowDepth, d)
			u += w + gap
			i += 1
		end
	end
	if placed < #flat then
		print(`[fit] {parent.Name}: placed {placed}/{#flat} items (out of room)`)
	end
	return placed
end

function Fit.lights(parent: Instance, rect: Rect, ceilY: number, kind: string, step: number, keepouts: { Rect }?, opts: { [string]: any }?): number
	local n = 0
	local w, d = rect.X1 - rect.X0, rect.Z1 - rect.Z0
	local nx = math.max(1, math.floor(w / step + 0.5))
	local nz = math.max(1, math.floor(d / step + 0.5))
	for ix = 1, nx do
		for iz = 1, nz do
			local x = rect.X0 + w * (ix - 0.5) / nx
			local z = rect.Z0 + d * (iz - 0.5) / nz
			local skip = false
			for _, k in keepouts or {} do
				if x > k.X0 and x < k.X1 and z > k.Z0 and z < k.Z1 then
					skip = true
					break
				end
			end
			if not skip then
				Props.ceilingLight(parent, CFrame.new(x, ceilY, z), kind, opts or {})
				n += 1
			end
		end
	end
	return n
end

-- CFrame on the inner face of a wall of `rect`, looking into the room.
-- side: "N"|"S"|"E"|"W"; along: world X (N/S walls) or Z (E/W walls); inset: distance from the rect edge.
function Fit.wallCf(rect: Rect, side: string, along: number, y: number, inset: number?): CFrame
	local i = inset or 1.1
	if side == "N" then
		return Kit.place(along, y, rect.Z1 - i, 0) -- facing -Z (into room)
	elseif side == "S" then
		return Kit.place(along, y, rect.Z0 + i, 180)
	elseif side == "W" then
		return Kit.place(rect.X0 + i, y, along, -90)
	else
		return Kit.place(rect.X1 - i, y, along, 90)
	end
end

-- Floor-level CFrame for a prop standing against a wall, facing into the room.
function Fit.againstWall(rect: Rect, side: string, along: number, y: number, depth: number): CFrame
	return Fit.wallCf(rect, side, along, y, depth / 2 + 1.2)
end

-- Plants in the four corners of a rect.
function Fit.cornerPlants(parent: Instance, rect: Rect, y: number, kind: string?, inset: number?)
	local i = inset or 3.5
	for _, p in { { rect.X0 + i, rect.Z0 + i }, { rect.X1 - i, rect.Z0 + i }, { rect.X0 + i, rect.Z1 - i }, { rect.X1 - i, rect.Z1 - i } } do
		Props.plant(parent, CFrame.new(p[1], y, p[2]), kind or "Fiddle", 1.1)
	end
end

return Fit
