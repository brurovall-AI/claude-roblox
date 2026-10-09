--!strict
--[[
	EmoteController: radial emote wheel + local emote housekeeping.

	  Open: G, gamepad D-pad Up, or the round emote button bottom-right.
	  Pick: hover / flick the mouse, thumbstick + A, number keys 1-8, or tap.
	  Close: G / D-pad Up again, B, or click outside.
	Plays through Net.request("Emote.Play", { Id }); the server publishes
	Emote + EmoteStamp on the character and AnimationController animates it for
	everyone. Looping emotes stop automatically ("Emote.Stop") as soon as the
	local player walks or jumps. The wheel is unavailable while training.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared.Config.Cosmetics)
local Net = require(Shared.Util.Net)
local Trove = require(Shared.Util.Trove)

local UI = script.Parent.Parent.UI
local C = require(UI.Components)
local Icons = require(UI.Icons)
local New = require(UI.Create)
local Theme = require(UI.Theme)

local State = require(script.Parent.Parent.Core.State)
local AudioController = require(script.Parent.AudioController)
local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)
local UIController = require(script.Parent.UIController)

local EmoteController = {}
EmoteController.Priority = 45

local player = Players.LocalPlayer

local WHEEL = 380
local RING_R = 132
local SLOT = 78
local NUMBER_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
}

type Slot = { id: string, frame: TextButton, stroke: UIStroke, scale: UIScale, angle: number }

local wheelTrove: Trove.Trove? = nil
local slots: { Slot } = {}
local selected = 0
local centerName: TextLabel? = nil
local centerSub: TextLabel? = nil
local hudButton: TextButton? = nil
local lastPlay = 0

---------------------------------------------------------------------------
-- Availability
---------------------------------------------------------------------------
local function blocked(): boolean
	return State.get("Training") == true or State.get("Minigame") == true or State.get("Cinematic") == true
end

local function equipped(): { string }
	local list: { string } = {}
	local eq = DataController.data.Equipped.Emotes
	local owned = DataController.data.Owned.Emotes
	for _, id in eq do
		if Cosmetics.Emotes[id] and owned[id] and #list < Cosmetics.MaxEquippedEmotes then
			table.insert(list, id)
		end
	end
	return list
end

---------------------------------------------------------------------------
-- Playing
---------------------------------------------------------------------------
local function play(id: string)
	local now = os.clock()
	if now - lastPlay < 0.4 then
		return
	end
	lastPlay = now
	task.spawn(function()
		local ok, result = Net.request("Emote.Play", { Id = id })
		if not ok then
			NotificationController.toast("Can't emote", if type(result) == "string" then result else "Try again in a moment.", "Info")
		end
	end)
end

local function stopEmote()
	task.spawn(function()
		Net.request("Emote.Stop")
	end)
end

---------------------------------------------------------------------------
-- Wheel
---------------------------------------------------------------------------
local function paintSelection()
	for i, s in slots do
		local on = i == selected
		C.tween(s.frame, Theme.Tween.Fast, {
			BackgroundColor3 = if on then Theme.Color.Surface3 else Theme.Color.Surface1,
		})
		s.stroke.Color = if on then Theme.Color.Accent else Theme.Color.Stroke
		s.stroke.Transparency = if on then 0.05 else 0.85
		C.tween(s.scale, Theme.Tween.Fast, { Scale = if on then 1.1 else 1 })
	end
	local slot = slots[selected]
	if centerName and centerSub then
		if slot then
			local def = Cosmetics.Emotes[slot.id]
			centerName.Text = if def then def.Name else slot.id
			centerSub.Text = if def and def.Loop then "Loops until you move" else "One-shot"
		else
			centerName.Text = "Emotes"
			centerSub.Text = if #slots > 0 then "Pick one" else ""
		end
	end
end

local function select(i: number)
	if i ~= selected then
		selected = i
		if i > 0 then
			AudioController.play("UIHover")
		end
		paintSelection()
	end
end

-- Slot nearest to a direction (screen space, y down).
local function slotAt(dir: Vector2): number
	if #slots == 0 or dir.Magnitude < 1e-3 then
		return 0
	end
	local angle = math.deg(math.atan2(dir.Y, dir.X)) + 90
	local step = 360 / #slots
	return (math.floor(((angle % 360) + step / 2) / step) % #slots) + 1
end

local function closeWheel()
	local t = wheelTrove
	if not t then
		return
	end
	wheelTrove = nil
	slots = {}
	selected = 0
	centerName, centerSub = nil, nil
	AudioController.play("UIClose")
	t:Clean()
end

local function confirm()
	local s = slots[selected]
	if s then
		local id = s.id
		closeWheel()
		play(id)
	end
end

local function openWheel()
	if wheelTrove or blocked() then
		return
	end
	local overlay = UIController.hud.Overlay
	if not overlay then
		return
	end
	local trove = Trove.new()
	wheelTrove = trove
	AudioController.play("UIOpen")

	local dim: TextButton = trove:Add(New("TextButton", {
		Name = "EmoteWheelDim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Color.Backdrop,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = overlay,
	}))
	C.tween(dim, Theme.Tween.Base, { BackgroundTransparency = 0.55 })
	dim.Activated:Connect(closeWheel)

	local wheel: CanvasGroup = New("CanvasGroup", {
		Name = "EmoteWheel",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(WHEEL, WHEEL),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		GroupTransparency = 1,
		ZIndex = 2,
		Parent = overlay,
	})
	trove:Add(wheel)
	local wheelScale = New("UIScale", { Scale = 0.9, Parent = wheel })
	C.tween(wheel, Theme.Tween.Base, { GroupTransparency = 0 })
	C.tween(wheelScale, Theme.Tween.Spring, { Scale = 1 })

	-- ring + centre
	local ring = C.frame({ Parent = wheel, Size = UDim2.fromOffset(WHEEL - 8, WHEEL - 8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = Theme.Color.Surface0, Transparency = 0.12, Radius = Theme.Radius.Pill })
	C.stroke(ring, 0.84)
	local track = C.frame({ Parent = wheel, Size = UDim2.fromOffset(RING_R * 2, RING_R * 2), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Radius = Theme.Radius.Pill })
	C.stroke(track, 0.9)
	local center = C.frame({ Parent = wheel, Size = UDim2.fromOffset(150, 150), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = Theme.Color.Surface1, Transparency = 0, Radius = Theme.Radius.Pill })
	C.stroke(center, 0.8)
	local icon = Icons.make("emote", 22, Theme.Color.Accent)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 30)
	icon.Parent = center
	centerName = C.label({ Parent = center, Text = "Emotes", Font = Theme.Font.Bold, TextSize = Theme.TextSize.Heading, XAlign = Enum.TextXAlignment.Center, Size = UDim2.new(1, -16, 0, 22), Position = UDim2.new(0, 8, 0, 60) })
	centerSub = C.label({ Parent = center, Text = "", TextSize = Theme.TextSize.Micro, Color = Theme.Color.TextDim, XAlign = Enum.TextXAlignment.Center, Size = UDim2.new(1, -16, 0, 16), Position = UDim2.new(0, 8, 0, 84) })

	local list = equipped()
	if #list == 0 then
		C.label({
			Parent = wheel,
			Text = "No emotes equipped yet.\nPick some in the Inventory.",
			Color = Theme.Color.TextDim,
			TextSize = Theme.TextSize.Caption,
			Wrap = true,
			XAlign = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(220, 40),
			Position = UDim2.new(0.5, 0, 0.5, 112),
			AnchorPoint = Vector2.new(0.5, 0.5),
		})
	end
	for i, id in list do
		local def = Cosmetics.Emotes[id]
		local angle = math.rad(-90 + (i - 1) * 360 / #list)
		local btn: TextButton = New("TextButton", {
			Name = "Slot_" .. id,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.Color.Surface1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(SLOT, SLOT),
			Position = UDim2.new(0.5, math.cos(angle) * RING_R, 0.5, math.sin(angle) * RING_R),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 3,
			Parent = wheel,
		})
		C.corner(btn, Theme.Radius.Pill)
		local stroke = C.stroke(btn, 0.85)
		local scale = New("UIScale", { Parent = btn })
		local glyph = Icons.make("emote", 18, if def and def.Loop then Theme.Color.Info else Theme.Color.Accent)
		glyph.AnchorPoint = Vector2.new(0.5, 0)
		glyph.Position = UDim2.new(0.5, 0, 0, 14)
		glyph.ZIndex = 4
		glyph.Parent = btn
		C.label({
			Parent = btn,
			Text = if def then def.Name else id,
			Font = Theme.Font.Bold,
			TextSize = Theme.TextSize.Micro,
			Wrap = true,
			XAlign = Enum.TextXAlignment.Center,
			YAlign = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -10, 0, 28),
			Position = UDim2.new(0, 5, 0, 36),
			ZIndex = 4,
		})
		if not UIController.isTouch then
			C.label({
				Parent = btn,
				Text = tostring(i),
				Font = Theme.Font.Heavy,
				TextSize = 10,
				Color = Theme.Color.TextMute,
				XAlign = Enum.TextXAlignment.Center,
				Size = UDim2.fromOffset(16, 12),
				Position = UDim2.new(0.5, 0, 1, -14),
				AnchorPoint = Vector2.new(0.5, 0),
				ZIndex = 4,
			})
		end
		btn.MouseEnter:Connect(function()
			select(i)
		end)
		btn.Activated:Connect(function()
			select(i)
			confirm()
		end)
		table.insert(slots, { id = id, frame = btn, stroke = stroke, scale = scale, angle = angle })
	end
	paintSelection()

	-- mouse flick: direction from the wheel centre picks a slot
	trove:Connect(UserInputService.InputChanged, function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		-- InputObject.Position shares GuiObject.AbsolutePosition's space (inset excluded)
		local centre = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
		local d = Vector2.new(input.Position.X, input.Position.Y) - centre
		if d.Magnitude > 60 then
			select(slotAt(d))
		end
	end)

	-- gamepad / keyboard navigation while open (sinks so nothing else reacts)
	local navName = "IronhavenEmoteWheelNav"
	ContextActionService:BindActionAtPriority(navName, function(_, state: Enum.UserInputState, input: InputObject)
		local key = input.KeyCode
		if key == Enum.KeyCode.Thumbstick1 or key == Enum.KeyCode.Thumbstick2 then
			local v = Vector2.new(input.Position.X, -input.Position.Y)
			if v.Magnitude > 0.5 then
				select(slotAt(v))
			end
			return Enum.ContextActionResult.Sink
		end
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Sink
		end
		if key == Enum.KeyCode.ButtonA or key == Enum.KeyCode.Return then
			confirm()
		elseif key == Enum.KeyCode.ButtonB then
			closeWheel()
		else
			local n = table.find(NUMBER_KEYS, key)
			if n and slots[n] then
				select(n)
				confirm()
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 20, Enum.KeyCode.Thumbstick1, Enum.KeyCode.Thumbstick2, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.Return, table.unpack(NUMBER_KEYS))
	trove:Add(function()
		ContextActionService:UnbindAction(navName)
	end)

	-- training starts / other modal moments close the wheel
	trove:Add(State.changed("Training", function(v: any)
		if v then
			closeWheel()
		end
	end))
	trove:Add(State.changed("Window", function(v: any)
		if v then
			closeWheel()
		end
	end))
end

function EmoteController.toggle()
	if wheelTrove then
		closeWheel()
	else
		openWheel()
	end
end

---------------------------------------------------------------------------
-- HUD button (bottom-right)
---------------------------------------------------------------------------
local function buildButton()
	local bottom = UIController.hud.Bottom
	local root = bottom and bottom.Parent
	if not root or not root:IsA("GuiObject") then
		return
	end
	local touch = UIController.isTouch
	local btn = C.iconButton({
		Parent = root,
		Name = "EmoteButton",
		Icon = "emote",
		Size = if touch then 52 else 46,
		Radius = Theme.Radius.Pill,
		AnchorPoint = Vector2.new(1, 1),
		-- on touch, sit above the thumb-stick jump zone
		Position = if touch then UDim2.new(1, -6, 1, -196) else UDim2.new(1, 0, 1, 0),
		OnClick = EmoteController.toggle,
	})
	if not touch then
		local cap = C.frame({ Parent = btn, Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(-4, -4), Color = Theme.Color.Surface3, Transparency = 0, Radius = Theme.Radius.Small })
		C.stroke(cap, 0.75)
		C.label({ Parent = cap, Text = "G", Font = Theme.Font.Bold, TextSize = 10, XAlign = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
	end
	hudButton = btn
	local function refresh()
		btn.Visible = not blocked()
	end
	State.changed("Training", refresh)
	State.changed("Minigame", refresh)
	State.changed("Cinematic", refresh)
	refresh()
end

---------------------------------------------------------------------------
-- Auto-stop looping emotes when the player moves or jumps
---------------------------------------------------------------------------
local moveConn: RBXScriptConnection? = nil
local stopSent = false

local function watchCharacter(char: Model)
	local function update()
		if moveConn then
			moveConn:Disconnect()
			moveConn = nil
		end
		stopSent = false
		local id = char:GetAttribute("Emote")
		local def = if type(id) == "string" then Cosmetics.Emotes[id] else nil
		if not def or not def.Loop then
			return
		end
		local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid?
		if not hum then
			return
		end
		local h = hum :: Humanoid
		local started = os.clock()
		moveConn = RunService.Heartbeat:Connect(function()
			if stopSent or os.clock() - started < 0.25 then
				return
			end
			local state = h:GetState()
			if h.MoveDirection.Magnitude > 0.1 or h.Jump or state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
				stopSent = true
				stopEmote()
			end
		end)
	end
	char:GetAttributeChangedSignal("Emote"):Connect(update)
	char.AncestryChanged:Connect(function(_, parent: Instance?)
		if not parent and moveConn then
			moveConn:Disconnect()
			moveConn = nil
		end
	end)
	update()
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function EmoteController.Init()
	ContextActionService:BindAction("IronhavenEmoteWheel", function(_, state: Enum.UserInputState)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if blocked() and not wheelTrove then
			return Enum.ContextActionResult.Pass
		end
		EmoteController.toggle()
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.G, Enum.KeyCode.DPadUp)
end

function EmoteController.Start()
	buildButton()
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
	local _ = hudButton
end

return EmoteController
