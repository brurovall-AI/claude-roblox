--[[
	Props showroom: lays out every Props facade function (and every kind /
	style variant) in labelled bays and writes

	  build/props/dump.json   renderable dump (tools/render)
	  build/props/cams.json   one close-up camera per prop + one per bay

	Bays face +Z (towards the default sun) with a back wall at -Z for
	wall-mounted props; the "Ceiling" bay has a slab overhead for ceiling
	fixtures, ducts, trusses and hanging plants. Part counts per prop are
	printed and checked against the Props budgets.

	Usage: lune run tools/bake/propsroom.luau [--only <bay>] [--out <dir>]
	Then:  tools/render/target/release/ironhaven-render build/props/dump.json \
	           build/props/cams.json build/props [camera]
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local loader = require("./loader")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local Vector2 = roblox.Vector2
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

local args = process.args
local OUT = "build/props"
local ONLY: string? = nil
do
	local i = 1
	while i <= #args do
		if args[i] == "--out" then
			OUT = args[i + 1]
			i += 1
		elseif args[i] == "--only" then
			ONLY = args[i + 1]
			i += 1
		end
		i += 1
	end
end

local Kit = loader.load("src/map/Kit")
local Props = loader.load("src/map/Props")

local root = Instance.new("Model")
root.Name = "PropsRoom"
local cams = {}
local issues = 0

local function cam(name: string, pos: any, look: any, fov: number?, w: number?, h: number?)
	table.insert(cams, { name = name, mode = "persp", pos = { pos.X, pos.Y, pos.Z }, look = { look.X, look.Y, look.Z }, fov = fov or 45, w = w or 900, h = h or 640 })
end

local function countParts(model: any): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			n += 1
		end
	end
	return n
end

local function countClass(model: any, base: string): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA(base) then
			n += 1
		end
	end
	return n
end

-- facing +Z (towards the camera side and the sun)
local FACE = CFrame.Angles(0, math.pi, 0)

type Entry = {
	name: string,
	w: number, -- stall width
	h: number, -- framing height for the close-up camera
	mount: string?, -- "floor" (default) | "wall" | "ceiling"
	y: number?, -- wall mount height (centre) / unused for floor
	budget: number?, -- max parts
	build: (parent: any, cf: any) -> any,
}

type Bay = { name: string, depth: number, ceiling: number?, entries: { Entry } }

local function E(name: string, w: number, h: number, budget: number?, build: (parent: any, cf: any) -> any, mount: string?, y: number?): Entry
	return { name = name, w = w, h = h, budget = budget, build = build, mount = mount, y = y }
end

local V3 = Vector3.new
local V2 = Vector2.new
local RGB = Color3.fromRGB

local bays: { Bay } = {
	{
		name = "Nature",
		depth = 16,
		entries = {
			E("plant_Fiddle", 4, 6, 24, function(p, cf) return Props.plant(p, cf, "Fiddle") end),
			E("plant_Snake", 4, 4, 24, function(p, cf) return Props.plant(p, cf, "Snake") end),
			E("plant_Olive", 4, 6, 24, function(p, cf) return Props.plant(p, cf, "Olive") end),
			E("plant_Palm", 6, 6, 24, function(p, cf) return Props.plant(p, cf, "Palm") end),
			E("plant_Bush", 4, 3.5, 24, function(p, cf) return Props.plant(p, cf, "Bush") end),
			E("plant_Fern", 4, 3.5, 24, function(p, cf) return Props.plant(p, cf, "Fern") end),
			E("plant_Monstera", 5, 5, 24, function(p, cf) return Props.plant(p, cf, "Monstera") end),
			E("planter_Bush", 10, 4, 40, function(p, cf) return Props.planter(p, cf, V3(8, 1.8, 4), "ConcreteDark", "Bush") end),
			E("planter_Grass", 8, 4, 40, function(p, cf) return Props.planter(p, cf, V3(6, 1.6, 3), "Walnut", "Grass") end),
			E("planter_Palm", 10, 6, 40, function(p, cf) return Props.planter(p, cf, V3(8, 2, 3), "Travertine", "Palm") end),
			E("tree_Oak", 14, 18, 30, function(p, cf) return Props.tree(p, cf, "Oak") end),
			E("tree_Birch", 10, 16, 30, function(p, cf) return Props.tree(p, cf, "Birch") end),
			E("tree_Pine", 11, 14, 30, function(p, cf) return Props.tree(p, cf, "Pine") end),
			E("tree_Street", 10, 13, 30, function(p, cf) return Props.tree(p, cf, "Street") end),
		},
	},
	{
		name = "Seating",
		depth = 14,
		entries = {
			E("bench", 8, 2.5, 30, function(p, cf) return Props.bench(p, cf, 6, "Oak") end),
			E("sofa_Velvet3", 11, 3.5, 30, function(p, cf) return Props.sofa(p, cf, 3, "Velvet") end),
			E("sofa_Leather2", 8, 3.5, 30, function(p, cf) return Props.sofa(p, cf, 2, "Leather") end),
			E("sofa_Fabric4", 14, 3.5, 30, function(p, cf) return Props.sofa(p, cf, 4, "Fabric") end),
			E("sofa_Velvet1", 5, 3.5, 30, function(p, cf) return Props.sofa(p, cf, 1, "Velvet") end),
			E("armchair_Leather", 5, 3.5, 30, function(p, cf) return Props.armchair(p, cf, "Leather") end),
			E("armchair_Velvet", 5, 3.5, 30, function(p, cf) return Props.armchair(p, cf, "Velvet") end),
			E("stool", 3, 3.5, 30, function(p, cf) return Props.stool(p, cf) end),
			E("coffeeTable", 6, 2, 30, function(p, cf) return Props.coffeeTable(p, cf) end),
			E("table", 6, 3, 30, function(p, cf) return Props.table(p, cf) end),
			E("table_cafe", 4, 3, 30, function(p, cf) return Props.table(p, cf, V3(2.6, 2.6, 2.6), "Marble") end),
			E("umbrellaTable", 10, 9, 32, function(p, cf) return Props.umbrellaTable(p, cf) end),
			E("rug", 9, 1, 30, function(p, cf) return Props.rug(p, cf, V2(8, 5)) end),
			E("massageTable", 6, 3, 30, function(p, cf) return Props.massageTable(p, cf) end),
		},
	},
	{
		name = "Fixtures",
		depth = 14,
		entries = {
			E("counter", 14, 4, 40, function(p, cf) return Props.counter(p, cf, 12, 3) end),
			E("shelf_Supplements", 8, 7, 50, function(p, cf) return Props.shelf(p, cf, 6, 6.5, "Supplements") end),
			E("shelf_Towels", 8, 7, 50, function(p, cf) return Props.shelf(p, cf, 6, 6.5, "Towels") end),
			E("shelf_Merch", 8, 7, 50, function(p, cf) return Props.shelf(p, cf, 6, 6.5, "Merch") end),
			E("shelf_Shakers", 8, 7, 50, function(p, cf) return Props.shelf(p, cf, 6, 6.5, "Shakers") end),
			E("shelf_Trophies", 8, 7, 50, function(p, cf) return Props.shelf(p, cf, 6, 6.5, "Trophies") end),
			E("shelf_Books", 8, 7, 50, function(p, cf) return Props.shelf(p, cf, 6, 6.5, "Books") end),
			E("lockers", 14, 7, 60, function(p, cf) return Props.lockers(p, cf, 6, 2) end),
			E("trophyCase", 10, 7.5, 45, function(p, cf) return Props.trophyCase(p, cf, 8) end),
			E("vending_Drinks", 5, 7.5, 36, function(p, cf) return Props.vending(p, cf, "Drinks") end),
			E("vending_Snacks", 5, 7.5, 36, function(p, cf) return Props.vending(p, cf, "Snacks") end),
			E("fridge", 5, 7.5, 36, function(p, cf) return Props.fridge(p, cf) end),
			E("bleachers", 22, 10, 120, function(p, cf) return Props.bleachers(p, cf, 20, 5) end),
		},
	},
	{
		name = "Clutter",
		depth = 10,
		entries = {
			E("towel", 2.4, 1, 10, function(p, cf) return Props.towel(p, cf) end),
			E("towelStack", 2.4, 1.6, 10, function(p, cf) return Props.towelStack(p, cf, 5) end),
			E("towelRack", 5, 5.5, 30, function(p, cf) return Props.towelRack(p, cf) end),
			E("waterBottle", 1.6, 1.2, 10, function(p, cf) return Props.waterBottle(p, cf) end),
			E("shaker", 1.6, 1.2, 10, function(p, cf) return Props.shaker(p, cf) end),
			E("gymBag", 3.4, 1.6, 10, function(p, cf) return Props.gymBag(p, cf) end),
			E("cleaningStation", 4, 5, 30, function(p, cf) return Props.cleaningStation(p, cf) end),
			E("trashBin", 2.4, 2.8, 10, function(p, cf) return Props.trashBin(p, cf) end),
			E("chalkBowl", 3, 4, 12, function(p, cf) return Props.chalkBowl(p, cf) end),
			E("foamRollers", 4.4, 3.4, 20, function(p, cf) return Props.foamRollers(p, cf) end),
			E("medBalls", 6.4, 4.4, 30, function(p, cf) return Props.medBalls(p, cf) end),
			E("kettlebells", 7.4, 2.2, 30, function(p, cf) return Props.kettlebells(p, cf, 6) end),
			E("plateStack", 3.6, 1.6, 12, function(p, cf) return Props.plateStack(p, cf) end),
			E("stanchions", 12, 3.5, 30, function(p, cf)
				local a = (cf * CFrame.new(-5, 0, 0)).Position
				local b = (cf * CFrame.new(5, 0, 0)).Position
				return Props.stanchions(p, a, b)
			end),
		},
	},
	{
		name = "Walls",
		depth = 8,
		entries = {
			E("mirror", 12, 8, 12, function(p, cf) return Props.mirror(p, cf, 10, 7) end, "wall", 4.5),
			E("wallSign_Brand", 12, 4, 10, function(p, cf) return Props.wallSign(p, cf, "IRONHAVEN", V2(10, 2.4), "Brand") end, "wall", 7),
			E("wallSign_Area", 10, 4, 10, function(p, cf) return Props.wallSign(p, cf, "FREE WEIGHTS|Strength Floor", V2(8, 2.2), "Area") end, "wall", 7),
			E("wallSign_Motto", 12, 4, 10, function(p, cf) return Props.wallSign(p, cf, "Strength is earned, every single day.", V2(10, 2.2), "Motto") end, "wall", 7),
			E("wallSign_Way", 8, 3, 10, function(p, cf) return Props.wallSign(p, cf, "> Locker Rooms", V2(5, 1.2), "Wayfinding") end, "wall", 7),
			E("wallSign_Neon", 8, 3, 10, function(p, cf) return Props.wallSign(p, cf, "Stay Strong", V2(5, 1.6), "Neon") end, "wall", 7),
			E("logo_Light", 10, 4, 12, function(p, cf) return Props.logo(p, cf, 8, "Light") end, "wall", 6),
			E("logo_Dark", 10, 4, 12, function(p, cf) return Props.logo(p, cf, 8, "Dark") end, "wall", 6),
			E("logo_Brass", 10, 4, 12, function(p, cf) return Props.logo(p, cf, 8, "Brass") end, "wall", 6),
			E("poster_Strength", 5, 6, 8, function(p, cf) return Props.poster(p, cf, V2(4, 5.5), "Strength") end, "wall", 6),
			E("poster_Speed", 5, 6, 8, function(p, cf) return Props.poster(p, cf, V2(4, 5.5), "Speed") end, "wall", 6),
			E("poster_Endurance", 5, 6, 8, function(p, cf) return Props.poster(p, cf, V2(4, 5.5), "Endurance") end, "wall", 6),
			E("poster_Agility", 5, 6, 8, function(p, cf) return Props.poster(p, cf, V2(4, 5.5), "Agility") end, "wall", 6),
			E("poster_Recovery", 5, 6, 8, function(p, cf) return Props.poster(p, cf, V2(4, 5.5), "Recovery") end, "wall", 6),
			E("poster_Boxing", 5, 6, 8, function(p, cf) return Props.poster(p, cf, V2(4, 5.5), "Boxing") end, "wall", 6),
			E("poster_Vintage", 5, 6, 8, function(p, cf) return Props.poster(p, cf, V2(4, 5.5), "Vintage") end, "wall", 6),
			E("tv", 8, 5, 10, function(p, cf) return Props.tv(p, cf, 6, "SPIN CLASS|Today 18:00 - Studio 2") end, "wall", 6.5),
			E("clock", 3, 3, 20, function(p, cf) return Props.clock(p, cf, 2) end, "wall", 8),
			E("speaker", 3, 3, 8, function(p, cf) return Props.speaker(p, cf) end, "wall", 9),
			E("acousticPanels", 10, 6, 30, function(p, cf) return Props.acousticPanels(p, cf, 8, 5) end, "wall", 6),
			E("woodSlats", 10, 7, 45, function(p, cf) return Props.woodSlats(p, cf, 8, 7) end, "wall", 4),
			E("firstAid", 2.6, 2, 8, function(p, cf) return Props.firstAid(p, cf) end, "wall", 5),
			E("fireExtinguisher", 2.4, 3, 10, function(p, cf) return Props.fireExtinguisher(p, cf) end, "wall", 3),
			E("exitSign", 3, 1.6, 6, function(p, cf) return Props.exitSign(p, cf) end, "wall", 9),
			E("waterFountain", 3.4, 4.5, 12, function(p, cf) return Props.waterFountain(p, cf) end, "wall", 3),
			E("wallLight_Sconce", 3, 3, 8, function(p, cf) return Props.wallLight(p, cf, "Sconce") end, "wall", 6),
			E("wallLight_Strip", 5, 2, 8, function(p, cf) return Props.wallLight(p, cf, "Strip") end, "wall", 6),
			E("wallLight_Wash", 3, 3, 8, function(p, cf) return Props.wallLight(p, cf, "Wash") end, "wall", 6),
			E("fan_Wall", 4, 4, 14, function(p, cf) return Props.fan(p, cf, "Wall") end, "wall", 8),
		},
	},
	{
		name = "Ceiling",
		depth = 14,
		ceiling = 13,
		entries = {
			E("light_Panel", 6, 3, 8, function(p, cf) return Props.ceilingLight(p, cf, "Panel") end, "ceiling"),
			E("light_Linear", 10, 4, 8, function(p, cf) return Props.ceilingLight(p, cf, "Linear", { Length = 8 }) end, "ceiling"),
			E("light_Pendant", 5, 5, 8, function(p, cf) return Props.ceilingLight(p, cf, "Pendant") end, "ceiling"),
			E("light_Industrial", 6, 6, 10, function(p, cf) return Props.ceilingLight(p, cf, "Industrial") end, "ceiling"),
			E("light_Spot", 5, 3, 8, function(p, cf) return Props.ceilingLight(p, cf, "Spot", { Tilt = 20 }) end, "ceiling"),
			E("light_Globe", 5, 5, 8, function(p, cf) return Props.ceilingLight(p, cf, "Globe") end, "ceiling"),
			E("light_Downlight", 4, 2, 6, function(p, cf) return Props.ceilingLight(p, cf, "Downlight") end, "ceiling"),
			E("fan_Ceiling", 10, 4, 14, function(p, cf) return Props.fan(p, cf, "Ceiling") end, "ceiling"),
			E("hangingPlant", 4, 5, 24, function(p, cf) return Props.hangingPlant(p, cf) end, "ceiling"),
			E("duct", 16, 4, 30, function(p, cf)
				return Props.duct(p, (cf * CFrame.new(-7, -2.2, 0)).Position, (cf * CFrame.new(7, -2.2, 0)).Position, 2.4)
			end, "ceiling"),
			E("pipe", 14, 3, 20, function(p, cf)
				return Props.pipe(p, (cf * CFrame.new(-6, -1.2, -1)).Position, (cf * CFrame.new(6, -1.2, -1)).Position, 0.5)
			end, "ceiling"),
			E("cableTray", 14, 3, 30, function(p, cf)
				return Props.cableTray(p, (cf * CFrame.new(-6, -1.4, 1)).Position, (cf * CFrame.new(6, -1.4, 1)).Position)
			end, "ceiling"),
			E("truss", 22, 5, 40, function(p, cf)
				return Props.truss(p, (cf * CFrame.new(-10, 0, 0)).Position, (cf * CFrame.new(10, 0, 0)).Position, 3)
			end, "ceiling"),
		},
	},
	{
		name = "Structure",
		depth = 12,
		entries = {
			E("column_Concrete", 5, 12, 12, function(p, cf) return Props.column(p, cf, 12, "Concrete") end),
			E("column_Steel", 5, 12, 14, function(p, cf) return Props.column(p, cf, 12, "Steel") end),
			E("column_Clad", 5, 12, 12, function(p, cf) return Props.column(p, cf, 12, "Clad") end),
			E("column_Round", 5, 12, 12, function(p, cf) return Props.column(p, cf, 12, "Round") end),
			E("fan_Standing", 4, 5, 14, function(p, cf) return Props.fan(p, cf, "Standing") end),
			E("ringLight", 4, 6.5, 20, function(p, cf) return Props.ringLight(p, cf) end),
		},
	},
	{
		name = "Outdoor",
		depth = 20,
		entries = {
			E("lampPost_Street", 10, 18, 12, function(p, cf) return Props.lampPost(p, cf, "Street") end),
			E("lampPost_Park", 6, 13, 12, function(p, cf) return Props.lampPost(p, cf, "Park") end),
			E("lampPost_Flood", 10, 22, 14, function(p, cf) return Props.lampPost(p, cf, "Flood") end),
			E("fence_Chainlink", 14, 7, 30, function(p, cf)
				return Props.fence(p, (cf * CFrame.new(-6, 0, 0)).Position, (cf * CFrame.new(6, 0, 0)).Position, 6, "Chainlink")
			end),
			E("fence_Rail", 14, 5, 30, function(p, cf)
				return Props.fence(p, (cf * CFrame.new(-6, 0, 0)).Position, (cf * CFrame.new(6, 0, 0)).Position, 3.6, "Rail")
			end),
			E("fence_Glass", 14, 5, 30, function(p, cf)
				return Props.fence(p, (cf * CFrame.new(-6, 0, 0)).Position, (cf * CFrame.new(6, 0, 0)).Position, 3.6, "Glass")
			end),
			E("fence_Timber", 14, 7, 30, function(p, cf)
				return Props.fence(p, (cf * CFrame.new(-6, 0, 0)).Position, (cf * CFrame.new(6, 0, 0)).Position, 6, "Timber")
			end),
			E("parkBench", 7, 3, 16, function(p, cf) return Props.parkBench(p, cf) end),
			E("car", 10, 5, 30, function(p, cf) return Props.car(p, cf, RGB(150, 34, 38)) end),
			E("car_grey", 10, 5, 30, function(p, cf) return Props.car(p, cf) end),
			E("bikeRack", 8, 3, 14, function(p, cf) return Props.bikeRack(p, cf) end),
			E("bollard", 2.4, 3, 6, function(p, cf) return Props.bollard(p, cf) end),
			E("flag", 7, 21, 10, function(p, cf) return Props.flag(p, cf) end),
		},
	},
}

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local WALL = { Material = Enum.Material.Plaster, Color = RGB(214, 208, 198) }
local FLOOR_A = { Material = Enum.Material.SmoothPlastic, Color = RGB(160, 156, 150) }
local FLOOR_B = { Material = Enum.Material.SmoothPlastic, Color = RGB(146, 142, 137) }

local z = 0
local maxX = 0
local report = {}
for bi, bay in bays do
	if ONLY and ONLY ~= bay.name then
		continue
	end
	local depth = bay.depth
	local wallZ = z - depth / 2 -- back wall plane (props face +Z)
	local x = 0
	for ei, e in bay.entries do
		local cx = x + e.w / 2
		local cf
		if e.mount == "wall" then
			cf = CFrame.new(cx, e.y or 5, wallZ) * FACE
		elseif e.mount == "ceiling" then
			cf = CFrame.new(cx, bay.ceiling or 13, z) * FACE
		else
			cf = CFrame.new(cx, 0, z) * FACE
		end
		local ok, model = pcall(e.build, root, cf)
		if not ok then
			issues += 1
			print(`  !! {e.name} FAILED: {model}`)
			x += e.w
			continue
		end
		local parts = countParts(model)
		local lights = countClass(model, "Light")
		local guis = countClass(model, "SurfaceGui")
		local flag = ""
		if e.budget and parts > e.budget then
			flag = `  !! over budget ({e.budget})`
			issues += 1
		end
		table.insert(report, string.format("%-10s %-20s %3d parts %d lights %d guis%s", bay.name, e.name, parts, lights, guis, flag))
		-- stall tile (alternating tone) + label strip for Studio previews
		Kit.box(root, CFrame.new(cx, -0.05, z + 1), Vector3.new(e.w - 0.1, 0.1, depth - 2), if ei % 2 == 0 then FLOOR_A else FLOOR_B, Kit.DETAIL)
		local label = Kit.box(root, CFrame.new(cx, 0.02, z + depth / 2 - 0.8), Vector3.new(e.w - 0.4, 0.04, 1), "PlasticBlack", { Collide = false, Transparency = 1 })
		Kit.sign(label, e.name, { Face = Enum.NormalId.Top, PixelsPerStud = 24 })
		-- close-up camera from the front-right, slightly above
		local h = e.h
		local focusY = if e.mount == "wall" then (e.y or 5) elseif e.mount == "ceiling" then (bay.ceiling or 13) - h * 0.5 else h * 0.45
		local D = math.max(e.w * 0.95, h * 1.25) + 2.5
		local camY = if e.mount == "ceiling" then focusY - D * 0.25 else focusY + D * 0.3
		cam(e.name, Vector3.new(cx + D * 0.35, camY, (if e.mount == "wall" then wallZ else z) + D), Vector3.new(cx, focusY, if e.mount == "wall" then wallZ + 0.6 else z), 45)
		x += e.w
	end
	-- back wall (and ceiling slab for the ceiling bay)
	Kit.box(root, CFrame.new(x / 2, 7, wallZ - 0.5), Vector3.new(x + 2, 14, 1), WALL, Kit.SOLID)
	if bay.ceiling then
		Kit.box(root, CFrame.new(x / 2, bay.ceiling + 0.5, z), Vector3.new(x + 2, 1, depth), WALL, Kit.SOLID)
		-- low fill so the fixtures' own lights dominate
		local fill = Kit.marker(root, "Fill", CFrame.new(x / 2, 3, z + depth))
		Kit.light(fill, "Point", { Brightness = 0.3, Range = 40, Color = RGB(255, 244, 230) })
	end
	-- bay overview camera
	local span = math.min(x, 44)
	for part = 0, math.floor(x / 44) do
		local cx = math.min(span / 2 + part * 44, x - span / 2)
		local camY = if bay.ceiling then 4 else 12
		cam(`bay_{bay.name}_{part}`, Vector3.new(cx, camY, z + depth / 2 + 18), Vector3.new(cx, if bay.ceiling then 8 else 3, z - 2), 70, 1280, 640)
	end
	maxX = math.max(maxX, x)
	z += depth + 26 -- room for close-up cameras in front of each bay
end

local floor = Kit.box(root, CFrame.new(maxX / 2, -0.6, z / 2 - 10), Vector3.new(maxX + 40, 1, z + 40), "ConcretePolished", Kit.SOLID)
floor.Name = "Floor"

for _, line in report do
	print(line)
end

---------------------------------------------------------------------------
-- SurfaceGui layout dump (build/props/guis.json): absolute rects of every
-- GuiObject so the compositions can be previewed outside Roblox.
---------------------------------------------------------------------------
local function faceSize(part: any, face: any): (number, number)
	local s = part.Size
	local n = face.Name
	if n == "Front" or n == "Back" then
		return s.X, s.Y
	elseif n == "Top" or n == "Bottom" then
		return s.X, s.Z
	end
	return s.Z, s.Y
end

local function c3(c: any)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

local function guiNode(inst: any, px: number, py: number, pw: number, ph: number): any
	local size, pos, anchor = inst.Size, inst.Position, inst.AnchorPoint
	local w = size.X.Scale * pw + size.X.Offset
	local h = size.Y.Scale * ph + size.Y.Offset
	local sc = inst.SizeConstraint.Name
	if sc == "RelativeYY" then
		w = size.X.Scale * ph + size.X.Offset
	elseif sc == "RelativeXX" then
		h = size.Y.Scale * pw + size.Y.Offset
	end
	local x = px + pos.X.Scale * pw + pos.X.Offset - anchor.X * w
	local y = py + pos.Y.Scale * ph + pos.Y.Offset - anchor.Y * h
	local node: { [string]: any } = {
		class = inst.ClassName, x = x, y = y, w = w, h = h, rot = inst.Rotation, z = inst.ZIndex,
		bg = c3(inst.BackgroundColor3), bgt = inst.BackgroundTransparency, visible = inst.Visible,
		clip = inst.ClipsDescendants, children = {},
	}
	if inst:IsA("TextLabel") then
		node.text = inst.Text
		node.color = c3(inst.TextColor3)
		node.family = inst.FontFace.Family
		node.weight = inst.FontFace.Weight.Name
		node.style = inst.FontFace.Style.Name
		node.xalign = inst.TextXAlignment.Name
	end
	for _, ch in inst:GetChildren() do
		if ch:IsA("UICorner") then
			node.corner = ch.CornerRadius.Scale * math.min(w, h) + ch.CornerRadius.Offset
		elseif ch:IsA("UIStroke") then
			node.stroke = { color = c3(ch.Color), thickness = ch.Thickness, t = ch.Transparency }
		elseif ch:IsA("UIGradient") then
			local kp = ch.Color.Keypoints
			node.gradient = { c0 = c3(kp[1].Value), c1 = c3(kp[#kp].Value), rot = ch.Rotation }
		elseif ch:IsA("GuiObject") then
			table.insert(node.children, guiNode(ch, x, y, w, h))
		end
	end
	return node
end

local guis = {}
for _, sg in root:GetDescendants() do
	if sg:IsA("SurfaceGui") and sg.Parent and sg.Parent:IsA("BasePart") and sg.Face.Name ~= "Top" then
		local model = sg.Parent:FindFirstAncestorOfClass("Model")
		local fw, fh = faceSize(sg.Parent, sg.Face)
		local W, H = fw * sg.PixelsPerStud, fh * sg.PixelsPerStud
		local kids = {}
		for _, ch in sg:GetChildren() do
			if ch:IsA("GuiObject") then
				table.insert(kids, guiNode(ch, 0, 0, W, H))
			end
		end
		table.insert(guis, { name = if model then model.Name else sg.Parent.Name, w = W, h = H, lightInfluence = sg.LightInfluence, children = kids })
	end
end
fs.writeDir(OUT)
fs.writeFile(`{OUT}/guis.json`, serde.encode("json", guis))
print(`[propsroom] {#guis} SurfaceGuis -> {OUT}/guis.json`)
print(`[propsroom] {#report} props, {issues} issue(s)`)
loader.dump(root, `{OUT}/dump.json`)
fs.writeDir(OUT)
fs.writeFile(`{OUT}/cams.json`, serde.encode("json", cams, true))
print(`[propsroom] {#cams} cameras -> {OUT}/cams.json`)
