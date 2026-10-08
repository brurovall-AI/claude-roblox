--!strict
--[[
	Read-only replica of this player's data (see shared DataSchema).

		DataController.ready()                       -- yields until the first snapshot
		DataController.get({"Stats", "Strength"})    -- current value (or nil)
		DataController.data                          -- whole replica table (read only!)
		local stop = DataController.observe("Stats", function(value) end)
			-- fires now (if loaded) and whenever "Stats" or anything under it changes,
			-- or when a parent of it is replaced. Keys are dot paths: "Settings.Music".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DataSchema = require(Shared.DataSchema)
local Net = require(Shared.Util.Net)
local Signal = require(Shared.Util.Signal)
local TableUtil = require(Shared.Util.TableUtil)

local DataController = {}
DataController.Priority = 0

DataController.data = TableUtil.deepCopy(DataSchema.Default) :: DataSchema.PlayerData
DataController.loaded = false
DataController.Changed = Signal.new() :: Signal.Signal<string, any>

type Observer = { key: string, parts: { string }, fn: (any) -> () }
local observers: { Observer } = {}
local readyWaiters: { thread } = {}

local function split(key: string): { string }
	local parts = {}
	for p in string.gmatch(key, "[^%.]+") do
		table.insert(parts, p)
	end
	return parts
end

local function valueAt(parts: { string }): any
	local node: any = DataController.data
	for _, k in parts do
		if type(node) ~= "table" then
			return nil
		end
		local nextNode = node[k]
		if nextNode == nil then
			local n = tonumber(k)
			if n then
				nextNode = node[n]
			end
		end
		node = nextNode
	end
	return node
end

function DataController.get(path: { any }): any
	return TableUtil.getPath(DataController.data :: any, path)
end

function DataController.ready()
	if DataController.loaded then
		return
	end
	table.insert(readyWaiters, coroutine.running())
	coroutine.yield()
end

function DataController.observe(key: string, fn: (any) -> ()): () -> ()
	local obs: Observer = { key = key, parts = split(key), fn = fn }
	table.insert(observers, obs)
	if DataController.loaded then
		task.spawn(fn, valueAt(obs.parts))
	end
	return function()
		local i = table.find(observers, obs)
		if i then
			table.remove(observers, i)
		end
	end
end

local function related(a: { string }, b: { string }): boolean
	local n = math.min(#a, #b)
	for i = 1, n do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

local function notify(pathParts: { string })
	local key = table.concat(pathParts, ".")
	DataController.Changed:Fire(key, valueAt(pathParts))
	for _, obs in table.clone(observers) do
		if related(obs.parts, pathParts) then
			task.spawn(obs.fn, valueAt(obs.parts))
		end
	end
end

local function applySnapshot(snap: { [string]: any })
	local fresh = TableUtil.deepCopy(DataSchema.Default) :: any
	for k, v in snap do
		fresh[k] = v
	end
	DataController.data = fresh
	local first = not DataController.loaded
	DataController.loaded = true
	for _, obs in table.clone(observers) do
		task.spawn(obs.fn, valueAt(obs.parts))
	end
	DataController.Changed:Fire("", fresh)
	if first then
		local waiters = readyWaiters
		readyWaiters = {}
		for _, th in waiters do
			task.spawn(th)
		end
	end
end

function DataController.Init()
	Net.event("DataInit").OnClientEvent:Connect(function(snap: any)
		if type(snap) == "table" then
			applySnapshot(snap)
		end
	end)
	Net.event("DataPatch").OnClientEvent:Connect(function(patches: any)
		if not DataController.loaded or type(patches) ~= "table" then
			return
		end
		for _, patch in patches do
			local path = patch[1]
			if type(path) == "table" and #path > 0 then
				TableUtil.setPath(DataController.data :: any, path, patch[2])
				local parts = {}
				for _, p in path do
					table.insert(parts, tostring(p))
				end
				notify(parts)
			end
		end
	end)
end

function DataController.Start()
	-- in case DataInit fired before we connected
	while not DataController.loaded do
		local ok, snap = Net.request("Data.Get")
		if ok and type(snap) == "table" then
			if not DataController.loaded then
				applySnapshot(snap)
			end
			break
		end
		task.wait(1)
	end
end

return DataController
