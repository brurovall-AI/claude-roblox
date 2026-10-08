--[[
	Bakes the Ironhaven map.

	Runs the Roblox-style map builder in src/map (with Roblox datatypes injected
	from @lune/roblox) and writes:
	  assets/Map.rbxm            the Map model, referenced by default.project.json
	  build/preview/dump.json    part + light dump for tools/render (preview images)

	Usage: lune run tools/bake/bake.luau [--no-dump] [--no-rbxm] [--out <dir>]
	  --out <dir>   write the preview dump to <dir>/dump.json (default build/preview)
	  --no-rbxm     don't write assets/Map.rbxm (use while iterating in parallel)
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local ROOT = process.cwd
if string.sub(ROOT, -1) == "/" then
	ROOT = string.sub(ROOT, 1, -2)
end

local GLOBALS = {
	"Instance",
	"Vector3",
	"Vector2",
	"CFrame",
	"Color3",
	"Enum",
	"UDim",
	"UDim2",
	"Font",
	"NumberSequence",
	"NumberSequenceKeypoint",
	"ColorSequence",
	"ColorSequenceKeypoint",
	"NumberRange",
	"BrickColor",
	"PhysicalProperties",
	"Rect",
	"Faces",
	"Axes",
}

local moduleCache: { [string]: any } = {}
local loading: { [string]: boolean } = {}

local function normalize(path: string): string
	local parts = {}
	for seg in string.gmatch(path, "[^/]+") do
		if seg == ".." then
			table.remove(parts)
		elseif seg ~= "." then
			table.insert(parts, seg)
		end
	end
	return "/" .. table.concat(parts, "/")
end

local makeEnv: (dir: string) -> { [string]: any }

local function loadModule(full: string): any
	if moduleCache[full] ~= nil then
		return moduleCache[full]
	end
	if loading[full] then
		error("circular require: " .. full)
	end
	loading[full] = true
	local file = full .. ".luau"
	if not fs.isFile(file) and fs.isDir(full) then
		file = full .. "/init.luau"
	end
	local src = fs.readFile(file)
	local dir = string.match(file, "^(.*)/[^/]*$") :: string
	local chunk = luau.load(luau.compile(src), {
		debugName = string.gsub(file, "^" .. ROOT .. "/", ""),
		environment = makeEnv(dir),
	})
	local result = chunk()
	moduleCache[full] = if result == nil then true else result
	loading[full] = nil
	return result
end

makeEnv = function(dir: string)
	local env: { [string]: any } = {}
	for _, name in GLOBALS do
		env[name] = (roblox :: any)[name]
	end
	env.require = function(path: string)
		if string.sub(path, 1, 1) == "@" then
			return require(path)
		end
		return loadModule(normalize(dir .. "/" .. path))
	end
	env.warn = function(...)
		print("[warn]", ...)
	end
	return env
end

local t0 = os.clock()
local build = loadModule(ROOT .. "/src/map/init")
local map = build()
assert(typeof(map) == "Instance" and map:IsA("Model"), "src/map/init must return a builder returning the Map Model")
map.Name = "Map"

-- Validation + stats --------------------------------------------------------
local partCount, lightCount, unanchored = 0, 0, 0
local classCounts: { [string]: number } = {}
local dumpParts = {}
local dumpLights = {}

local SHAPE = { Block = 0, Wedge = 1, Cylinder = 2, Ball = 3, CornerWedge = 4 }

local function c3(c: any)
	return { c.R, c.G, c.B }
end

local function faceVector(cf: any, face: any): any
	local n = face.Name
	if n == "Front" then
		return cf.LookVector
	elseif n == "Back" then
		return -cf.LookVector
	elseif n == "Top" then
		return cf.UpVector
	elseif n == "Bottom" then
		return -cf.UpVector
	elseif n == "Right" then
		return cf.RightVector
	else
		return -cf.RightVector
	end
end

local function partOf(inst: any): any
	local p = inst.Parent
	if p and p:IsA("Attachment") then
		local part = p.Parent
		if part and part:IsA("BasePart") then
			return part, part.CFrame * p.CFrame
		end
		return nil, nil
	elseif p and p:IsA("BasePart") then
		return p, p.CFrame
	end
	return nil, nil
end

for _, inst in map:GetDescendants() do
	classCounts[inst.ClassName] = (classCounts[inst.ClassName] or 0) + 1
	if inst:IsA("BasePart") then
		partCount += 1
		if not inst.Anchored then
			unanchored += 1
		end
		if inst.Transparency < 0.98 then
			local shape = 0
			if inst:IsA("WedgePart") then
				shape = 1
			elseif inst:IsA("CornerWedgePart") then
				shape = 4
			elseif inst:IsA("Part") then
				shape = SHAPE[inst.Shape.Name] or 0
			end
			table.insert(dumpParts, {
				s = shape,
				cf = { inst.CFrame:GetComponents() },
				sz = { inst.Size.X, inst.Size.Y, inst.Size.Z },
				c = c3(inst.Color),
				t = inst.Transparency,
				m = inst.Material.Name,
				rf = inst.Reflectance,
			})
		end
	elseif inst:IsA("Light") and inst.Enabled then
		lightCount += 1
		local part, cf = partOf(inst)
		if part then
			local entry: { [string]: any } = {
				p = { cf.Position.X, cf.Position.Y, cf.Position.Z },
				c = c3(inst.Color),
				b = inst.Brightness,
				r = inst.Range,
				k = inst.ClassName,
			}
			if inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
				local dir = faceVector(cf, inst.Face)
				entry.d = { dir.X, dir.Y, dir.Z }
				entry.a = inst.Angle
				if inst:IsA("SurfaceLight") then
					local off = dir * 0.0
					local pos = cf.Position + off
					entry.p = { pos.X, pos.Y, pos.Z }
				end
			end
			table.insert(dumpLights, entry)
		end
	end
end

print(string.format("[bake] built map in %.2fs: %d parts, %d lights", os.clock() - t0, partCount, lightCount))
local sorted = {}
for k, v in classCounts do
	table.insert(sorted, { k, v })
end
table.sort(sorted, function(a, b)
	return a[2] > b[2]
end)
for i = 1, math.min(14, #sorted) do
	print(string.format("        %-22s %d", sorted[i][1], sorted[i][2]))
end
if unanchored > 0 then
	print(string.format("[bake] WARNING: %d unanchored parts", unanchored))
end

if not table.find(process.args, "--no-rbxm") then
	fs.writeDir(ROOT .. "/assets")
	fs.writeFile(ROOT .. "/assets/Map.rbxm", roblox.serializeModel({ map }))
	print("[bake] wrote assets/Map.rbxm (" .. math.floor(#fs.readFile(ROOT .. "/assets/Map.rbxm") / 1024) .. " KB)")
end

local outDir = ROOT .. "/build/preview"
local outIdx = table.find(process.args, "--out")
if outIdx and process.args[outIdx + 1] then
	local o = process.args[outIdx + 1]
	outDir = if string.sub(o, 1, 1) == "/" then o else ROOT .. "/" .. o
end

if not table.find(process.args, "--no-dump") then
	-- empty Lua tables encode as JSON objects; keep both lists as arrays
	if #dumpLights == 0 then
		table.insert(dumpLights, { p = { 0, -10000, 0 }, c = { 0, 0, 0 }, b = 0, r = 0.1, k = "PointLight" })
	end
	if #dumpParts == 0 then
		table.insert(dumpParts, { s = 0, cf = { 0, -10000, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, sz = { 1, 1, 1 }, c = { 0, 0, 0 }, t = 0, m = "Plastic", rf = 0 })
	end
	fs.writeDir(outDir)
	fs.writeFile(
		outDir .. "/dump.json",
		serde.encode("json", {
			parts = dumpParts,
			lights = dumpLights,
			sun = {
				dir = { -0.42, 0.68, 0.6 },
				color = { 2.7, 2.5, 2.2 },
				ambient = { 0.15, 0.15, 0.17 },
				outdoor = { 0.62, 0.66, 0.74 },
				sky = { 0.6, 0.72, 0.9 },
			},
		})
	)
	print("[bake] wrote " .. outDir .. "/dump.json")
end
