--!strict
--[[
	Shared visual pieces for the minigames (built on UI/Theme + UI/Create so the
	meters match the rest of the HUD): key caps, big touch buttons, pills,
	glow strokes and small tween helpers.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Minigames = require(Shared.Config.Minigames)
local Trove = require(Shared.Util.Trove)

local Input = require(script.Parent.Input)

local UI = script.Parent.Parent.UI
local C = require(UI.Components)
local Icons = require(UI.Icons)
local New = require(UI.Create)
local Theme = require(UI.Theme)

local Kit = {}

export type TouchButton = { Button: TextButton, setText: (string) -> (), setVisible: (boolean) -> () }

-- What every minigame kind receives from Minigame.run (see Minigame.luau).
export type Api = {
	kind: string,
	root: Frame, -- fills the parent; touch buttons may sit outside it
	stage: Frame, -- the meter area (above the hint line)
	params: { [string]: number },
	input: Input.Hub,
	trove: Trove.Trove,
	accent: Color3,
	minInterval: number,
	ready: () -> boolean, -- true once the minimum rep interval has passed
	grade: (quality: number) -> (), -- report a graded rep (0..3)
	setHint: (hints: { [string]: string }) -> (), -- per device: Keyboard / Gamepad / Touch
	touch: (props: { [string]: any }, onDown: () -> (), onUp: () -> ()) -> TouchButton,
	device: () -> string,
}

Kit.Track = Theme.Color.Surface2
Kit.TrackDeep = Color3.fromHex("#18191C")
Kit.Ok = Color3.fromHex("#8E8B86")
Kit.Good = Theme.Color.Success
Kit.Perfect = Theme.Color.Accent
Kit.Miss = Theme.Color.Danger

function Kit.qualityColor(q: number): Color3
	if q >= 3 then
		return Kit.Perfect
	elseif q == 2 then
		return Kit.Good
	elseif q == 1 then
		return Minigames.QualityColor[1]
	end
	return Kit.Miss
end

function Kit.tween(inst: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

-- Rounded rectangle helper.
function Kit.box(parent: Instance, props: { [string]: any }): Frame
	local f = New("Frame", {
		Name = props.Name or "Box",
		BackgroundColor3 = props.Color or Kit.Track,
		BackgroundTransparency = props.Transparency or 0,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = props.ZIndex or 1,
		Rotation = props.Rotation or 0,
		Parent = parent,
	})
	if props.Radius ~= false then
		C.corner(f, props.Radius or Theme.Radius.Pill)
	end
	return f
end

-- Keyboard / gamepad key cap ("SPACE", "A", "D", ...).
function Kit.keyCap(parent: Instance, text: string, props: { [string]: any }?): Frame
	local p: { [string]: any } = props or {}
	local cap = C.frame({
		Parent = parent,
		Name = "KeyCap",
		Size = UDim2.fromOffset(0, p.Height or 22),
		AutoSize = Enum.AutomaticSize.X,
		Color = Theme.Color.Surface3,
		Transparency = 0,
		Radius = Theme.Radius.Small,
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		LayoutOrder = p.LayoutOrder,
	})
	C.stroke(cap, 0.75)
	C.padding(cap, 0, 7)
	-- bottom lip makes it read as a physical key
	New("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 196, 196)),
		Rotation = 90,
		Parent = cap,
	})
	C.label({
		Parent = cap,
		Name = "Text",
		Text = text,
		Font = Theme.Font.Bold,
		TextSize = p.TextSize or Theme.TextSize.Micro,
		Color = Theme.Color.Text,
		Size = UDim2.new(0, 0, 1, 0),
		AutoSize = Enum.AutomaticSize.X,
		XAlign = Enum.TextXAlignment.Center,
	})
	return cap
end

function Kit.setKeyCap(cap: Frame, text: string)
	local l = cap:FindFirstChild("Text") :: TextLabel?
	if l then
		l.Text = text
	end
end

-- Lights a key cap briefly (input feedback).
function Kit.blink(cap: Frame, color: Color3?)
	cap.BackgroundColor3 = color or Theme.Color.Accent
	Kit.tween(cap, 0.25, { BackgroundColor3 = Theme.Color.Surface3 })
end

-- Large round on-screen button for touch play. Fires onDown / onUp (hold aware).
function Kit.touchButton(parent: Instance, props: { [string]: any }, onDown: () -> (), onUp: () -> ()): TouchButton
	local size = props.Size or 84
	local btn: TextButton = New("TextButton", {
		Name = props.Name or "TouchButton",
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		BackgroundColor3 = Theme.Color.Surface0,
		BackgroundTransparency = 0.12,
		Size = UDim2.fromOffset(size, size),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		Selectable = false,
		ZIndex = 5,
		Parent = parent,
	})
	C.corner(btn, Theme.Radius.Pill)
	local ring = C.stroke(btn, 0.55, props.Color or Theme.Color.Accent, 2)
	local scale = New("UIScale", { Parent = btn })
	local label: TextLabel? = nil
	if props.Icon then
		local icon = Icons.make(props.Icon, math.floor(size * 0.42), Theme.Color.Text)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.ZIndex = 6
		icon.Parent = btn
	else
		label = C.label({
			Parent = btn,
			Text = props.Text or "",
			Font = Theme.Font.Heavy,
			TextSize = props.TextSize or Theme.TextSize.Heading,
			XAlign = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 6,
		})
	end
	local down = false
	btn.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if not down and (t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1) then
			down = true
			ring.Transparency = 0.1
			Kit.tween(scale, 0.08, { Scale = 0.92 })
			onDown()
		end
	end)
	btn.InputEnded:Connect(function(input: InputObject)
		local t = input.UserInputType
		if down and (t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1) then
			down = false
			ring.Transparency = 0.55
			Kit.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			onUp()
		end
	end)
	return {
		Button = btn,
		setText = function(s: string)
			if label then
				label.Text = s
			end
		end,
		setVisible = function(v: boolean)
			btn.Visible = v
			if not v and down then
				down = false
				ring.Transparency = 0.55
				scale.Scale = 1
				onUp()
			end
		end,
	}
end

-- Soft outer glow (a stroke whose transparency we animate).
function Kit.glow(inst: GuiObject, color: Color3, thickness: number?): UIStroke
	local s = New("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		Transparency = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
	return s
end

function Kit.pulseStroke(s: UIStroke, color: Color3, from: number?)
	s.Color = color
	s.Transparency = from or 0
	Kit.tween(s, 0.45, { Transparency = 1 })
end

function Kit.punch(scale: UIScale, amount: number?)
	scale.Scale = 1 + (amount or 0.12)
	Kit.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Short floating word inside a minigame ("PERFECT", "TOO LONG", ...).
function Kit.popWord(parent: Instance, text: string, color: Color3, position: UDim2)
	local l = C.label({
		Parent = parent,
		Name = "Pop",
		Text = text,
		Font = Theme.Font.Heavy,
		TextSize = Theme.TextSize.Caption,
		Color = color,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(120, 18),
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 8,
	})
	Kit.tween(l, 0.6, { Position = position - UDim2.fromOffset(0, 14), TextTransparency = 1 })
	task.delay(0.65, function()
		l:Destroy()
	end)
end

return Kit
