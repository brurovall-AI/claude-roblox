--!strict
--[[
	Client-side dispatcher for server "GameEvent" messages (Notify.event) plus
	purely local events. Any controller can listen:

		GameEvents.on("LevelUp", function(payload) ... end)
		GameEvents.emit("LocalThing", { ... })   -- local only
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Util.Net)

local GameEvents = {}

type Listener = (payload: { [string]: any }) -> ()
local listeners: { [string]: { Listener } } = {}

function GameEvents.on(name: string, fn: Listener): () -> ()
	local list = listeners[name]
	if not list then
		list = {}
		listeners[name] = list
	end
	table.insert(list, fn)
	return function()
		local i = table.find(list :: { Listener }, fn)
		if i then
			table.remove(list :: { Listener }, i)
		end
	end
end

function GameEvents.emit(name: string, payload: { [string]: any }?)
	local list = listeners[name]
	if not list then
		return
	end
	for _, fn in table.clone(list) do
		task.spawn(fn, payload or {})
	end
end

Net.event("GameEvent").OnClientEvent:Connect(function(name: any, payload: any)
	if type(name) == "string" then
		GameEvents.emit(name, if type(payload) == "table" then payload else {})
	end
end)

return GameEvents
