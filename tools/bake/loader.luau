--[[
	Module loader for running src/map code under Lune with Roblox datatypes
	injected as globals (Instance, CFrame, Vector3, Color3, Enum, ...).

		local loader = require("./loader")
		local Equipment = loader.load("src/map/Equipment")
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.cwd
if string.sub(ROOT, -1) == "/" then
	ROOT = string.sub(ROOT, 1, -2)
end

local GLOBALS = {
	"Instance", "Vector3", "Vector2", "CFrame", "Color3", "Enum", "UDim", "UDim2", "Font",
	"NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint",
	"NumberRange", "BrickColor", "PhysicalProperties", "Rect", "Faces", "Axes",
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

local loader = {}
loader.ROOT = ROOT

-- path relative to the repo root, e.g. "src/map/Equipment"
function loader.load(path: string): any
	return loadModule(normalize(ROOT .. "/" .. path))
end

--[[
	Writes a preview dump (parts + lights) for tools/render from any Instance.
	sun: optional override table.
]]
function loader.dump(root: any, outFile: string)
	local serde = require("@lune/serde")
	local SHAPE = { Block = 0, Wedge = 1, Cylinder = 2, Ball = 3, CornerWedge = 4 }
	local parts, lights = {}, {}
	local function c3(c: any)
		return { c.R, c.G, c.B }
	end
	local function faceVector(cf: any, face: any): any
		local n = face.Name
		if n == "Front" then return cf.LookVector
		elseif n == "Back" then return -cf.LookVector
		elseif n == "Top" then return cf.UpVector
		elseif n == "Bottom" then return -cf.UpVector
		elseif n == "Right" then return cf.RightVector
		else return -cf.RightVector end
	end
	for _, inst in root:GetDescendants() do
		if inst:IsA("BasePart") and inst.Transparency < 0.98 then
			local shape = 0
			if inst:IsA("WedgePart") then
				shape = 1
			elseif inst:IsA("CornerWedgePart") then
				shape = 4
			elseif inst:IsA("Part") then
				shape = SHAPE[inst.Shape.Name] or 0
			end
			table.insert(parts, {
				s = shape, cf = { inst.CFrame:GetComponents() },
				sz = { inst.Size.X, inst.Size.Y, inst.Size.Z }, c = c3(inst.Color),
				t = inst.Transparency, m = inst.Material.Name, rf = inst.Reflectance,
			})
		elseif inst:IsA("Light") and inst.Enabled then
			local p = inst.Parent
			local cf = nil
			if p and p:IsA("Attachment") and p.Parent and p.Parent:IsA("BasePart") then
				cf = p.Parent.CFrame * p.CFrame
			elseif p and p:IsA("BasePart") then
				cf = p.CFrame
			end
			if cf then
				local e: { [string]: any } = { p = { cf.Position.X, cf.Position.Y, cf.Position.Z }, c = c3(inst.Color), b = inst.Brightness, r = inst.Range, k = inst.ClassName }
				if inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
					local d = faceVector(cf, inst.Face)
					e.d = { d.X, d.Y, d.Z }
					e.a = inst.Angle
				end
				table.insert(lights, e)
			end
		end
	end
	if #lights == 0 then
		table.insert(lights, { p = { 0, -10000, 0 }, c = { 0, 0, 0 }, b = 0, r = 0.1, k = "PointLight" })
	end
	if #parts == 0 then
		table.insert(parts, { s = 0, cf = { 0, -10000, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }, sz = { 1, 1, 1 }, c = { 0, 0, 0 }, t = 0, m = "Plastic", rf = 0 })
	end
	local dir = string.match(outFile, "^(.*)/[^/]*$")
	if dir then
		fs.writeDir(dir)
	end
	fs.writeFile(outFile, serde.encode("json", {
		parts = parts, lights = lights,
		sun = { dir = { -0.42, 0.68, 0.6 }, color = { 2.7, 2.5, 2.2 }, ambient = { 0.15, 0.15, 0.17 }, outdoor = { 0.62, 0.66, 0.74 }, sky = { 0.6, 0.72, 0.9 } },
	}))
	print(string.format("[dump] %d parts, %d lights -> %s", #parts, #lights, outFile))
end

return loader
