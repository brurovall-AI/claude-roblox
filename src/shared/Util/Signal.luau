--!strict
--[[
	Lightweight typed signal (no BindableEvents, no thread reuse surprises).

	local changed = Signal.new() :: Signal.Signal<number>
	local conn = changed:Connect(function(v) print(v) end)
	changed:Fire(5)
	conn:Disconnect()
]]

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
}

type Handler = { fn: (...any) -> (), conn: any, once: boolean }

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local handlers: { Handler } = {}
	local self = {}

	function self.Connect(_: any, fn: (...any) -> ()): Connection
		local conn = { Connected = true }
		local entry: Handler = { fn = fn, conn = conn, once = false }
		function conn.Disconnect(c: any)
			if not c.Connected then
				return
			end
			c.Connected = false
			local i = table.find(handlers, entry)
			if i then
				table.remove(handlers, i)
			end
		end
		table.insert(handlers, entry)
		return conn :: any
	end

	function self.Once(s: any, fn: (...any) -> ()): Connection
		local conn: Connection
		conn = s:Connect(function(...)
			conn:Disconnect()
			fn(...)
		end)
		return conn
	end

	function self.Fire(_: any, ...: any)
		-- copy so handlers may disconnect during dispatch
		local snapshot = table.clone(handlers)
		for _, h in snapshot do
			if h.conn.Connected then
				task.spawn(h.fn, ...)
			end
		end
	end

	function self.Wait(s: any): ...any
		local thread = coroutine.running()
		s:Once(function(...)
			task.spawn(thread, ...)
		end)
		return coroutine.yield()
	end

	function self.DisconnectAll(_: any)
		for _, h in handlers do
			h.conn.Connected = false
		end
		table.clear(handlers)
	end

	return self :: any
end

return Signal
