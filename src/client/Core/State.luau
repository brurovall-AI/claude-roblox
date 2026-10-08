--!strict
--[[
	Tiny shared client state with change notifications, e.g.
		State.set("Training", true)
		State.get("Training")
		State.changed("Training", function(value) end)
	Known keys: Training (bool), Window (string? open window id), Zone (string area id),
	PhotoMode (bool), Minigame (bool), Cinematic (bool), Emoting (bool)
]]

local State = {}

local values: { [string]: any } = {}
local listeners: { [string]: { (any) -> () } } = {}

function State.get(key: string): any
	return values[key]
end

function State.set(key: string, value: any)
	if values[key] == value then
		return
	end
	values[key] = value
	local list = listeners[key]
	if list then
		for _, fn in table.clone(list) do
			task.spawn(fn, value)
		end
	end
end

function State.changed(key: string, fn: (any) -> ()): () -> ()
	local list = listeners[key]
	if not list then
		list = {}
		listeners[key] = list
	end
	table.insert(list, fn)
	return function()
		local i = table.find(list :: { (any) -> () }, fn)
		if i then
			table.remove(list :: { (any) -> () }, i)
		end
	end
end

return State
