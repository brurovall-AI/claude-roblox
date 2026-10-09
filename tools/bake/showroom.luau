--[[
	Equipment showroom: lays out every station type x tier (from
	src/shared/Config/Stations.luau) and every decor kind x tier on a large
	floor in labelled rows, adds grey R15-scale mannequins at each UserSpot,
	validates the station contract and writes:

	  build/equipment/dump.json        renderable dump (tools/render)
	  build/equipment/dump_moved.json  same scene with every Mover at MoverTravel
	  build/equipment/cams.json        close-up + row cameras (one per station)

	Usage: lune run tools/bake/showroom.luau [--only <StationType|DecorKind|Decor>] [--no-dummies] [--out <dir>]
	  --only        bake a single row (clean tier line-up with no neighbouring rows)
	  --no-dummies  omit the grey validation mannequins
	Every station is checked for UserSpot / PromptPart+TrainPrompt / Mover+MoverTravel /
	Spinner+SpinRate and its part budget (25-60 for tiers 1-3, 45-100 for tiers 4-6);
	problems print as "!! <Type> T<n>: ...".
	Then:  tools/render/target/release/ironhaven-render build/equipment/dump.json \
	           build/equipment/cams.json build/equipment [camera]
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local loader = require("./loader")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

local args = process.args
local OUT = "build/equipment"
local ONLY: string? = nil
local DUMMIES = true
do
	local i = 1
	while i <= #args do
		local a = args[i]
		if a == "--out" then
			OUT = args[i + 1]
			i += 1
		elseif a == "--only" then
			ONLY = args[i + 1]
			i += 1
		elseif a == "--no-dummies" then
			DUMMIES = false
		end
		i += 1
	end
end

local Kit = loader.load("src/map/Kit")
local Equipment = loader.load("src/map/Equipment")

---------------------------------------------------------------------------
-- Station catalogue (parsed from Config/Stations so the showroom never drifts)
---------------------------------------------------------------------------
type Entry = { id: string, pose: string, tiers: { number } }
local stations: { Entry } = {}
do
	local src = fs.readFile("src/shared/Config/Stations.luau")
	for line in string.gmatch(src, "[^\n]+") do
		local id = string.match(line, '^def%(%{ Id = "(%w+)"')
		if id then
			local pose = string.match(line, 'Pose = "(%w+)"') or "StandCurl"
			local tl = string.match(line, "Tiers = %{([%d,%s]+)%}") or "1"
			local tiers = {}
			for n in string.gmatch(tl, "%d+") do
				table.insert(tiers, tonumber(n))
			end
			table.insert(stations, { id = id, pose = pose, tiers = tiers })
		end
	end
end

local DECOR = { "DumbbellRack", "PlateTree", "BarbellRack", "KettlebellRack", "MedBallRack", "BenchFlat", "Rig", "PlyoBoxSet", "DuelTable" }
local DECOR_FP = {
	DumbbellRack = Vector3.new(9, 4, 3),
	PlateTree = Vector3.new(4, 6, 4),
	BarbellRack = Vector3.new(4, 8, 4),
	KettlebellRack = Vector3.new(7, 4, 3),
	MedBallRack = Vector3.new(5, 7, 3),
	BenchFlat = Vector3.new(3, 2, 6),
	Rig = Vector3.new(13, 10, 6),
	PlyoBoxSet = Vector3.new(7, 4, 6),
	DuelTable = Vector3.new(4, 5, 7),
}

---------------------------------------------------------------------------
-- Scene
---------------------------------------------------------------------------
local root = Instance.new("Model")
root.Name = "Showroom"
local cams = {}

local function cam(name: string, pos: any, look: any, fov: number?)
	table.insert(cams, { name = name, mode = "persp", pos = { pos.X, pos.Y, pos.Z }, look = { look.X, look.Y, look.Z }, fov = fov or 50, w = 960, h = 640 })
end

-- grey mannequin in the pose's HRP frame (validation only, never shipped)
local DUMMY = { Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(150, 156, 166) }
local function dummy(parent: any, spot: any, pose: string)
	if not DUMMIES then
		return
	end
	local m = Kit.model(parent, "Dummy")
	local function box(cf: any, size: any)
		Kit.box(m, spot * cf, size, DUMMY, Kit.DETAIL)
	end
	box(CFrame.new(0, 0.2, 0), Vector3.new(2, 1.6, 1)) -- torso
	box(CFrame.new(0, 1.65, 0), Vector3.new(1.15, 1.2, 1.15)) -- head
	local seated = pose == "SeatedPress" or pose == "Pulldown" or pose == "Bike" or pose == "Row" or pose == "SitRelax" or pose == "LegPress"
	local armsUp = pose == "Hang" or pose == "Pulldown"
	for _, sx in { -1, 1 } do
		if armsUp then
			box(CFrame.new(sx * 1.5, 2.1, 0), Vector3.new(0.9, 2.2, 0.9))
		elseif pose == "Bench" then
			box(CFrame.new(sx * 1.5, 0.3, 0), Vector3.new(0.9, 1.9, 0.9))
		else
			box(CFrame.new(sx * 1.5, 0, 0), Vector3.new(0.9, 2.0, 0.9))
		end
		if seated then
			box(CFrame.new(sx * 0.5, -0.95, -0.9), Vector3.new(0.95, 0.9, 1.9)) -- thigh forward
			box(CFrame.new(sx * 0.5, -1.85, -1.75), Vector3.new(0.9, 1.6, 0.9)) -- shin down
		elseif pose == "Yoga" then
			box(CFrame.new(sx * 0.6, -1.05, -0.5), Vector3.new(1.6, 0.6, 1.2))
		elseif pose == "Bench" then
			box(CFrame.new(sx * 0.5, -1.7, 0), Vector3.new(0.95, 1.8, 0.95))
		else
			box(CFrame.new(sx * 0.5, -2.0, 0), Vector3.new(0.95, 2.0, 0.95))
		end
	end
end

local issues = 0
local function check(model: any, entry: Entry, tier: number, parts: number)
	local function bad(msg: string)
		issues += 1
		print(`  !! {entry.id} T{tier}: {msg}`)
	end
	if not model:FindFirstChild("UserSpot") then
		bad("missing UserSpot")
	end
	local pp = model:FindFirstChild("PromptPart")
	if not pp or not pp:FindFirstChild("TrainPrompt") then
		bad("missing PromptPart/TrainPrompt")
	end
	local travel = model:GetAttribute("MoverTravel")
	local mover = model:FindFirstChild("Mover")
	if travel and (not mover or #mover:GetDescendants() == 0) then
		bad("MoverTravel set but Mover is empty")
	end
	if mover and not travel then
		bad("Mover without MoverTravel")
	end
	for _, ch in model:GetChildren() do
		if ch.Name == "Spinner" and ch:GetAttribute("SpinRate") == nil then
			bad("Spinner without SpinRate")
		end
	end
	local lo, hi = 25, 60
	if tier >= 4 then
		lo, hi = 45, 100
	end
	if parts < lo or parts > hi then
		bad(`part count {parts} outside budget {lo}-{hi}`)
	end
end

local function countParts(model: any): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and d.Parent and d.Parent.Name ~= "Dummy" then
			n += 1
		end
	end
	return n
end

local FLOOR_Y = 0
local z = 0
local rowsInfo = {}
local totalStations = 0
local movers = {}

local function rowCam(name: string, xMax: number, zRow: number, depth: number, height: number)
	local cx = -xMax / 2
	-- steep three-quarter view so the neighbouring rows occlude as little as possible
	-- (for a perfectly clean tier line-up bake with --only <Type>)
	local dist = math.max(xMax * 0.5, 14) + depth * 0.25
	cam(name, Vector3.new(cx + 3, height * 0.6 + dist * 0.8, zRow - depth / 2 - dist * 0.6), Vector3.new(cx, height * 0.3, zRow), 55)
end

for _, entry in stations do
	if ONLY and entry.id ~= ONLY then
		continue
	end
	local fp = Equipment.Footprints[entry.id] or Vector3.new(6, 6, 6)
	local pitchX = fp.X + 7
	local rowZ = z + fp.Z / 2
	local x = 0
	for _, tier in entry.tiers do
		local cx = -(x + fp.X / 2)
		local cf = CFrame.new(cx, FLOOR_Y, rowZ)
		local model = Equipment.build(root, entry.id, tier, cf, { AreaId = "Showroom", Id = `{entry.id}_{tier}` })
		local parts = countParts(model)
		print(string.format("%-15s T%d  %3d parts", entry.id, tier, parts))
		check(model, entry, tier, parts)
		local spot = model:FindFirstChild("UserSpot")
		if spot then
			dummy(root, spot.CFrame, entry.pose)
		end
		local travel = model:GetAttribute("MoverTravel")
		local mover = model:FindFirstChild("Mover")
		if travel and mover then
			table.insert(movers, { mover = mover, travel = travel })
		end
		-- label strip on the floor (SurfaceGui for Studio previews)
		local label = Kit.box(root, cf * CFrame.new(0, 0.02, fp.Z / 2 + 1.6), Vector3.new(fp.X, 0.04, 1.2), "PlasticBlack", { Collide = false, Transparency = 1 })
		Kit.sign(label, `{entry.id}  T{tier}`, { Face = Enum.NormalId.Top, PixelsPerStud = 30 })
		-- close-up camera: front-left three-quarter view, slightly elevated
		local D = math.max(fp.X, fp.Z * 0.8, fp.Y) * 0.95 + 5
		local look = Vector3.new(cx, fp.Y * 0.38, rowZ)
		cam(`{entry.id}_T{tier}`, Vector3.new(cx - D * 0.62, fp.Y * 0.5 + D * 0.42, rowZ - D * 0.9), look, 50)
		cam(`{entry.id}_T{tier}_b`, Vector3.new(cx + D * 0.7, fp.Y * 0.55 + D * 0.38, rowZ + D * 0.75), look, 50)
		totalStations += 1
		x += pitchX
	end
	rowCam(`row_{entry.id}`, x - 7, rowZ, fp.Z, fp.Y)
	table.insert(rowsInfo, { id = entry.id, z = rowZ })
	z += fp.Z + 9
end

-- Decor rows
if not ONLY or ONLY == "Decor" or table.find(DECOR, ONLY) then
	for _, kind in DECOR do
		if ONLY and ONLY ~= "Decor" and ONLY ~= kind then
			continue
		end
		local fp = DECOR_FP[kind]
		local rowZ = z + fp.Z / 2
		local x = 0
		for tier = 1, 6 do
			local cx = -(x + fp.X / 2)
			local cf = CFrame.new(cx, FLOOR_Y, rowZ)
			local model
			if kind == "DuelTable" then
				model = Equipment.duelTable(root, cf, `Show{tier}`, tier)
				dummy(root, model:FindFirstChild("SeatA").CFrame, "StandCurl")
				dummy(root, model:FindFirstChild("SeatB").CFrame, "StandCurl")
			else
				local len = if kind == "Rig" then 12 elseif kind == "DumbbellRack" then 8 elseif kind == "KettlebellRack" then 6 else nil
				model = Equipment.decor(root, kind, tier, cf, { Length = len })
			end
			print(string.format("%-15s T%d  %3d parts (decor)", kind, tier, countParts(model)))
			local D = math.max(fp.X, fp.Z, fp.Y) * 0.95 + 5
			local look = Vector3.new(cx, fp.Y * 0.4, rowZ)
			cam(`{kind}_T{tier}`, Vector3.new(cx - D * 0.55, fp.Y * 0.5 + D * 0.42, rowZ - D * 0.9), look, 50)
			x += fp.X + 6
		end
		rowCam(`row_{kind}`, x - 6, rowZ, fp.Z, fp.Y)
		z += fp.Z + 8
	end
end

-- Floor + a few soft fill lights so shapes read in the preview.
local floorLen = z + 20
local floor = Kit.box(root, CFrame.new(-60, -0.5, floorLen / 2 - 10), Vector3.new(220, 1, floorLen), "ConcretePolished", Kit.SOLID)
floor.Name = "ShowroomFloor"
for i = 0, math.floor(floorLen / 60) do
	local p = Kit.marker(root, "Fill", CFrame.new(-60, 24, i * 60))
	Kit.light(p, "Point", { Brightness = 0.6, Range = 60, Color = Color3.fromRGB(255, 244, 230) })
end

print(`[showroom] {totalStations} stations, {issues} contract/budget issue(s)`)
loader.dump(root, `{OUT}/dump.json`)

-- moved state: every Mover offset by its MoverTravel (top of rep) for clip checks
for _, m in movers do
	for _, d in m.mover:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = d.CFrame + m.travel
		end
	end
end
loader.dump(root, `{OUT}/dump_moved.json`)

fs.writeDir(OUT)
fs.writeFile(`{OUT}/cams.json`, serde.encode("json", cams, true))
print(`[showroom] {#cams} cameras -> {OUT}/cams.json`)
