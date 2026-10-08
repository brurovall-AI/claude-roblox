--!strict
--[[
	Networking hub. All remotes live in ReplicatedStorage.Remotes and are created
	lazily by the server the first time a service declares them; clients wait.

	Fire-and-forget:   Net.event("TrainingInput")      -> RemoteEvent
	High-frequency:    Net.unreliable("DuelPush")      -> UnreliableRemoteEvent
	Request/response:  Net.handle("Shop.Buy", fn)      (server)
	                   Net.request("Shop.Buy", payload) (client) -> (ok, result)

	Request handlers receive (player, payload) and return (ok: boolean, result: any).
	The dispatcher pcalls handlers, rate-limits per player and never trusts payloads:
	every handler must validate its own payload types.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

local Net = {}

local folder: Folder
if IS_SERVER then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing and existing:IsA("Folder") then
		folder = existing :: Folder
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local function getOrCreate(className: string, name: string): Instance
	local found = folder:FindFirstChild(name)
	if found then
		assert(found.ClassName == className, `remote {name} exists as {found.ClassName}, wanted {className}`)
		return found
	end
	if IS_SERVER then
		local inst = Instance.new(className)
		inst.Name = name
		inst.Parent = folder
		return inst
	end
	return folder:WaitForChild(name)
end

function Net.event(name: string): RemoteEvent
	return getOrCreate("RemoteEvent", name) :: RemoteEvent
end

function Net.unreliable(name: string): UnreliableRemoteEvent
	return getOrCreate("UnreliableRemoteEvent", name) :: UnreliableRemoteEvent
end

---------------------------------------------------------------------------
-- Rate limiting (server)
---------------------------------------------------------------------------
type Bucket = { tokens: number, last: number }
local buckets: { [Player]: { [string]: Bucket } } = {}

-- Token bucket: allows `burst` calls instantly, refilling at `perSecond`.
function Net.allow(player: Player, key: string, perSecond: number, burst: number): boolean
	local byKey = buckets[player]
	if not byKey then
		byKey = {}
		buckets[player] = byKey
	end
	local now = os.clock()
	local b = byKey[key]
	if not b then
		b = { tokens = burst, last = now }
		byKey[key] = b
	end
	b.tokens = math.min(burst, b.tokens + (now - b.last) * perSecond)
	b.last = now
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

if IS_SERVER then
	Players.PlayerRemoving:Connect(function(p)
		buckets[p] = nil
	end)
end

---------------------------------------------------------------------------
-- Request / response
---------------------------------------------------------------------------
export type Handler = (player: Player, payload: any) -> (boolean, any)
local handlers: { [string]: Handler } = {}
local requestRemote: RemoteFunction? = nil

local function requestFunction(): RemoteFunction
	if not requestRemote then
		requestRemote = getOrCreate("RemoteFunction", "Request") :: RemoteFunction
	end
	return requestRemote :: RemoteFunction
end

function Net.handle(action: string, fn: Handler)
	assert(IS_SERVER, "Net.handle is server-only")
	assert(handlers[action] == nil, "duplicate handler " .. action)
	handlers[action] = fn
end

if IS_SERVER then
	requestFunction().OnServerInvoke = function(player: Player, action: any, payload: any)
		if type(action) ~= "string" then
			return false, "bad action"
		end
		if not Net.allow(player, "request", 12, 25) then
			return false, "Slow down!"
		end
		local fn = handlers[action]
		if not fn then
			return false, "unknown action " .. action
		end
		local ok, a, b = pcall(fn, player, payload)
		if not ok then
			warn(`[Net] handler {action} errored: {a}`)
			return false, "Something went wrong."
		end
		return a, b
	end
end

-- Client: returns (ok, result). Never throws.
function Net.request(action: string, payload: any?): (boolean, any)
	assert(not IS_SERVER, "Net.request is client-only")
	local ok, a, b = pcall(function()
		return requestFunction():InvokeServer(action, payload)
	end)
	if not ok then
		return false, "Connection problem."
	end
	return a == true, b
end

return Net
