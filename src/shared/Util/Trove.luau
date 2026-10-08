--!strict
--[[
	Trove: collects cleanup work (connections, instances, functions, threads)
	and runs it all on :Clean(). Use one per object lifetime to avoid leaks.
]]

export type Trove = {
	Add: <T>(self: Trove, item: T) -> T,
	Connect: (self: Trove, signal: RBXScriptSignal, fn: (...any) -> ()) -> RBXScriptConnection,
	Clean: (self: Trove) -> (),
	Extend: (self: Trove) -> Trove,
}

local Trove = {}

local function cleanup(value: any)
	local item: any = value
	local t = typeof(value)
	if t == "RBXScriptConnection" then
		item:Disconnect()
	elseif t == "Instance" then
		item:Destroy()
	elseif t == "function" then
		item()
	elseif t == "thread" then
		pcall(task.cancel, item)
	elseif t == "table" then
		local destroy, disconnect, clean = item.Destroy, item.Disconnect, item.Clean
		if type(destroy) == "function" then
			(destroy :: any)(item)
		elseif type(disconnect) == "function" then
			(disconnect :: any)(item)
		elseif type(clean) == "function" then
			(clean :: any)(item)
		end
	end
end

function Trove.new(): Trove
	local items: { any } = {}
	local self = {}

	function self.Add(_: any, item: any): any
		table.insert(items, item)
		return item
	end

	function self.Connect(_: any, signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
		local c = signal:Connect(fn)
		table.insert(items, c)
		return c
	end

	function self.Clean(_: any)
		local list = items
		items = {}
		for i = #list, 1, -1 do
			cleanup(list[i])
		end
	end

	function self.Extend(_: any): Trove
		local child = Trove.new()
		table.insert(items, child)
		return child
	end

	return self :: any
end

return Trove
