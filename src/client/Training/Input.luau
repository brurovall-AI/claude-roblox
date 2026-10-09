--!strict
--[[
	Minigame input hub: one place that turns keyboard, mouse, gamepad and touch
	into five logical actions and tracks the active device for hints.

		local hub = Input.new({ "Primary" }, trove)
		hub.pressed:Connect(function(action) end)    -- "Primary" | "Left" | "Right" | "Up" | "Down"
		hub.released:Connect(function(action) end)
		hub.isDown("Primary"), hub.device()           -- "Keyboard" | "Gamepad" | "Touch"
		hub.press("Left", "touchL") / hub.release("Left", "touchL")  -- on-screen buttons

	Bindings (ContextActionService, high priority + Sink so Space doesn't jump
	and arrows / WASD don't walk while a minigame runs):
	  Primary  Space, E, gamepad A / R2 (+ mouse clicks in the world)
	  Left     A, Left, D-pad Left, L1      Right  D, Right, D-pad Right, R1
	  Up       W, Up, D-pad Up              Down   S, Down, D-pad Down
	A press fires once per action even if several sources hold it.
]]

local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local Trove = require(Shared.Util.Trove)

local Input = {}

export type Action = "Primary" | "Left" | "Right" | "Up" | "Down"
export type Device = "Keyboard" | "Gamepad" | "Touch"

export type Hub = {
	pressed: Signal.Signal<string>,
	released: Signal.Signal<string>,
	deviceChanged: Signal.Signal<string>,
	isDown: (action: string) -> boolean,
	device: () -> Device,
	press: (action: string, source: string) -> (),
	release: (action: string, source: string) -> (),
	lastPress: (action: string) -> number,
}

local KEYS: { [string]: { any } } = {
	Primary = { Enum.KeyCode.Space, Enum.KeyCode.E, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2 },
	Left = { Enum.KeyCode.A, Enum.KeyCode.Left, Enum.KeyCode.DPadLeft, Enum.KeyCode.ButtonL1 },
	Right = { Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.DPadRight, Enum.KeyCode.ButtonR1 },
	Up = { Enum.KeyCode.W, Enum.KeyCode.Up, Enum.KeyCode.DPadUp },
	Down = { Enum.KeyCode.S, Enum.KeyCode.Down, Enum.KeyCode.DPadDown },
}

local PRIORITY = Enum.ContextActionPriority.High.Value + 50

local function deviceFor(t: Enum.UserInputType): Device?
	if t == Enum.UserInputType.Touch then
		return "Touch"
	elseif t.Name:sub(1, 7) == "Gamepad" then
		return "Gamepad"
	elseif t == Enum.UserInputType.Keyboard or t.Name:sub(1, 5) == "Mouse" then
		return "Keyboard"
	end
	return nil
end

function Input.currentDevice(): Device
	local d = deviceFor(UserInputService:GetLastInputType())
	if d then
		return d
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	return if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then "Gamepad" else "Keyboard"
end

-- Short label for the primary input on a device ("SPACE", "A", "TAP").
function Input.primaryLabel(device: Device): string
	if device == "Gamepad" then
		return "A"
	elseif device == "Touch" then
		return "TAP"
	end
	return "SPACE"
end

function Input.new(actions: { string }, trove: Trove.Trove): Hub
	local pressed = Signal.new() :: Signal.Signal<string>
	local released = Signal.new() :: Signal.Signal<string>
	local deviceChanged = Signal.new() :: Signal.Signal<string>
	local holders: { [string]: { [string]: boolean } } = {}
	local last: { [string]: number } = {}
	local device: Device = Input.currentDevice()
	local enabled: { [string]: boolean } = {}
	for _, a in actions do
		enabled[a] = true
		holders[a] = {}
	end

	local function count(action: string): number
		local n = 0
		for _ in holders[action] do
			n += 1
		end
		return n
	end

	local function press(action: string, source: string)
		local h = holders[action]
		if not h or h[source] then
			return
		end
		local was = count(action)
		h[source] = true
		if was == 0 then
			last[action] = os.clock()
			pressed:Fire(action)
		end
	end

	local function release(action: string, source: string)
		local h = holders[action]
		if not h or not h[source] then
			return
		end
		h[source] = nil
		if count(action) == 0 then
			released:Fire(action)
		end
	end

	local function setDevice(d: Device?)
		if d and d ~= device then
			device = d
			deviceChanged:Fire(d)
		end
	end

	-- keyboard / gamepad through ContextActionService
	local id = HttpService:GenerateGUID(false):sub(1, 8)
	for _, action in actions do
		local keys = KEYS[action]
		if not keys then
			continue
		end
		local name = `IronhavenMinigame_{id}_{action}`
		ContextActionService:BindActionAtPriority(name, function(_, state: Enum.UserInputState, input: InputObject)
			local source = input.KeyCode.Name
			if state == Enum.UserInputState.Begin then
				setDevice(deviceFor(input.UserInputType))
				press(action, source)
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				release(action, source)
			end
			return Enum.ContextActionResult.Sink
		end, false, PRIORITY, table.unpack(keys))
		trove:Add(function()
			ContextActionService:UnbindAction(name)
		end)
	end

	-- mouse clicks in the world count as Primary (GUI clicks are handled by buttons)
	if enabled.Primary then
		trove:Connect(UserInputService.InputBegan, function(input: InputObject, processed: boolean)
			if processed then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				setDevice("Keyboard")
				press("Primary", "mouse")
			end
		end)
		trove:Connect(UserInputService.InputEnded, function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				release("Primary", "mouse")
			end
		end)
	end

	trove:Connect(UserInputService.LastInputTypeChanged, function(t: Enum.UserInputType)
		setDevice(deviceFor(t))
	end)

	-- release everything on teardown so nothing stays "held"
	trove:Add(function()
		for action, h in holders do
			if next(h) then
				table.clear(h)
				released:Fire(action)
			end
		end
		pressed:DisconnectAll()
		released:DisconnectAll()
		deviceChanged:DisconnectAll()
	end)

	return {
		pressed = pressed,
		released = released,
		deviceChanged = deviceChanged,
		isDown = function(action: string): boolean
			local h = holders[action]
			return h ~= nil and next(h) ~= nil
		end,
		device = function(): Device
			return device
		end,
		press = press,
		release = release,
		lastPress = function(action: string): number
			return last[action] or 0
		end,
	}
end

return Input
