--[[
	Loads Roblox-style ModuleScripts from src/shared under Lune by emulating
	`script` / `script.Parent.X` instance paths over the filesystem. Only for
	pure modules (configs, formulas, utils) — no services.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local ROOT = process.cwd
if string.sub(ROOT, -1) == "/" then
	ROOT = string.sub(ROOT, 1, -2)
end

local cache: { [string]: any } = {}

local makeProxy: (path: string) -> any

local function resolveFile(path: string): string?
	if fs.isFile(path .. ".luau") then
		return path .. ".luau"
	elseif fs.isDir(path) and fs.isFile(path .. "/init.luau") then
		return path .. "/init.luau"
	end
	return nil
end

makeProxy = function(path: string)
	return setmetatable({ __path = path }, {
		__index = function(_, key)
			if key == "Parent" then
				return makeProxy((string.match(path, "^(.*)/[^/]*$")) or path)
			elseif key == "Name" then
				return string.match(path, "([^/]*)$")
			elseif key == "WaitForChild" or key == "FindFirstChild" then
				return function(_self, name)
					return makeProxy(path .. "/" .. name)
				end
			end
			return makeProxy(path .. "/" .. key)
		end,
	})
end

local function load(path: string): any
	if cache[path] ~= nil then
		return cache[path]
	end
	local file = resolveFile(path)
	assert(file, "no module at " .. path)
	-- the module's own instance path: folder modules (init) are the folder
	local selfPath = if string.sub(file, -10) == "/init.luau" then path else path
	local env: { [string]: any } = {}
	for _, name in { "Vector3", "Vector2", "CFrame", "Color3", "Enum", "UDim", "UDim2", "Font", "NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "NumberRange", "TweenInfo" } do
		env[name] = (roblox :: any)[name]
	end
	env.script = makeProxy(selfPath)
	env.require = function(target: any)
		if type(target) == "table" and target.__path then
			return load(target.__path)
		end
		return require(target)
	end
	env.warn = function(...)
		print("[warn]", ...)
	end
	local chunk = luau.load(luau.compile(fs.readFile(file)), { debugName = file, environment = env })
	local result = chunk()
	cache[path] = result
	return result
end

local shim = {}
function shim.shared(rel: string): any
	return load(ROOT .. "/src/shared/" .. rel)
end
return shim
