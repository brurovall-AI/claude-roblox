--!strict
--[[
	Reusable UI components on top of Theme + Create. All builders accept a
	props table; common props: Parent, Name, LayoutOrder, Size, Position,
	AnchorPoint, Visible.

		local C = require(UI.Components)
		local card = C.card({ Parent = list, Size = UDim2.new(1, 0, 0, 64) })
		C.label({ Parent = card, Text = "Strength", Size = Theme.TextSize.Heading, Font = Theme.Font.Bold })
		local btn = C.button({ Parent = card, Text = "Buy", Style = "Primary", OnClick = function() end })
		local bar, setBar = C.progress({ Parent = card, Color = Theme.Color.XP })
		setBar(0.4, true)
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local New = require(script.Parent.Create)
local Icons = require(script.Parent.Icons)

local C = {}

-- Optional hooks installed by AudioController (keeps UI free of controller deps).
local clickSound: (() -> ())? = nil
local hoverSound: (() -> ())? = nil
function C.setSounds(click: () -> (), hover: () -> ())
	clickSound = click
	hoverSound = hover
end

local function common(inst: GuiObject, props: { [string]: any })
	if props.Name then
		inst.Name = props.Name
	end
	if props.LayoutOrder then
		inst.LayoutOrder = props.LayoutOrder
	end
	if props.Position then
		inst.Position = props.Position
	end
	if props.AnchorPoint then
		inst.AnchorPoint = props.AnchorPoint
	end
	if props.Visible ~= nil then
		inst.Visible = props.Visible
	end
	if props.ZIndex then
		inst.ZIndex = props.ZIndex
	end
end

function C.tween(inst: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local t = TweenService:Create(inst, info, goal)
	t:Play()
	return t
end

function C.corner(inst: Instance, radius: UDim?): UICorner
	return New("UICorner", { CornerRadius = radius or Theme.Radius.Medium, Parent = inst })
end

function C.stroke(inst: Instance, transparency: number?, color: Color3?, thickness: number?): UIStroke
	return New("UIStroke", {
		Color = color or Theme.Color.Stroke,
		Transparency = transparency or Theme.Transparency.Stroke,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

function C.padding(inst: Instance, top: number, right: number?, bottom: number?, left: number?): UIPadding
	local r = right or top
	return New("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or r),
		Parent = inst,
	})
end

function C.list(inst: Instance, direction: "V" | "H"?, gap: number?, hAlign: any?, vAlign: any?): UIListLayout
	return New("UIListLayout", {
		FillDirection = if direction == "H" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or Theme.Space.S),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		Parent = inst,
	})
end

function C.frame(props: { [string]: any }): Frame
	local f = New("Frame", {
		BackgroundColor3 = props.Color or Theme.Color.Surface1,
		BackgroundTransparency = props.Transparency or (if props.Color then 0 else 1),
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromScale(1, 1),
		AutomaticSize = props.AutoSize or Enum.AutomaticSize.None,
		ClipsDescendants = props.Clip or false,
	})
	common(f, props)
	if props.Radius then
		C.corner(f, props.Radius)
	end
	f.Parent = props.Parent
	return f
end

function C.label(props: { [string]: any }): TextLabel
	local l = New("TextLabel", {
		BackgroundTransparency = 1,
		Text = props.Text or "",
		RichText = props.Rich or false,
		FontFace = props.Font or Theme.Font.Medium,
		TextSize = props.TextSize or Theme.TextSize.Body,
		TextColor3 = props.Color or Theme.Color.Text,
		TextTransparency = props.TextTransparency or 0,
		TextXAlignment = props.XAlign or Enum.TextXAlignment.Left,
		TextYAlignment = props.YAlign or Enum.TextYAlignment.Center,
		TextWrapped = props.Wrap or false,
		TextTruncate = if props.Wrap then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
		Size = props.Size or UDim2.new(1, 0, 0, (props.TextSize or Theme.TextSize.Body) + 6),
		AutomaticSize = props.AutoSize or Enum.AutomaticSize.None,
	})
	common(l, props)
	l.Parent = props.Parent
	return l
end

function C.card(props: { [string]: any }): Frame
	local f = C.frame({
		Parent = props.Parent,
		Name = props.Name,
		LayoutOrder = props.LayoutOrder,
		Size = props.Size or UDim2.new(1, 0, 0, 64),
		AutoSize = props.AutoSize,
		Color = props.Color or Theme.Color.Surface1,
		Transparency = props.Transparency or 0,
		Radius = props.Radius or Theme.Radius.Medium,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Clip = props.Clip,
	})
	if props.Stroke ~= false then
		C.stroke(f, props.StrokeTransparency)
	end
	local pad = props.Padding or Theme.Space.M
	if pad > 0 then
		C.padding(f, pad)
	end
	return f
end

export type ButtonStyle = "Primary" | "Secondary" | "Ghost" | "Danger" | "Success"

local STYLE: { [string]: { bg: Color3, bgT: number, text: Color3, hover: Color3, stroke: boolean } } = {
	Primary = { bg = Theme.Color.Accent, bgT = 0, text = Theme.Color.AccentText, hover = Color3.fromHex("#FFC060"), stroke = false },
	Secondary = { bg = Theme.Color.Surface2, bgT = 0, text = Theme.Color.Text, hover = Theme.Color.Surface3, stroke = true },
	Ghost = { bg = Theme.Color.Surface2, bgT = 1, text = Theme.Color.TextDim, hover = Theme.Color.Surface2, stroke = false },
	Danger = { bg = Theme.Color.Danger, bgT = 0, text = Color3.new(1, 1, 1), hover = Color3.fromHex("#F06A62"), stroke = false },
	Success = { bg = Theme.Color.Success, bgT = 0, text = Color3.fromHex("#0C1E14"), hover = Color3.fromHex("#62D69C"), stroke = false },
}

export type ButtonApi = {
	Button: TextButton,
	setText: (text: string) -> (),
	setStyle: (style: ButtonStyle) -> (),
	setDisabled: (disabled: boolean) -> (),
}

function C.button(props: { [string]: any }): ButtonApi
	local styleName: string = props.Style or "Secondary"
	local disabled = props.Disabled == true
	local height = props.Height or 38
	local btn: TextButton = New("TextButton", {
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Size = props.Size or UDim2.new(0, 120, 0, height),
		AutomaticSize = props.AutoSize or Enum.AutomaticSize.None,
		Selectable = true,
	})
	common(btn, props)
	C.corner(btn, props.Radius or Theme.Radius.Medium)
	local stroke = C.stroke(btn, Theme.Transparency.StrokeStrong)
	local scale = New("UIScale", { Parent = btn })
	local row = C.frame({ Parent = btn, Size = UDim2.fromScale(1, 1) })
	C.list(row, "H", 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	if props.AutoSize then
		C.padding(row, 0, 14)
	end
	local icon: Frame? = nil
	if props.Icon then
		icon = Icons.make(props.Icon, props.IconSize or 16, Color3.new(1, 1, 1))
		;(icon :: Frame).LayoutOrder = 1
		;(icon :: Frame).Parent = row
	end
	local text = C.label({
		Parent = row,
		Text = props.Text or "",
		Font = props.Font or Theme.Font.Bold,
		TextSize = props.TextSize or Theme.TextSize.Body,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(0, 0, 1, 0),
		AutoSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
	})

	local hovering = false
	local function paint(animate: boolean)
		local s = STYLE[styleName] or STYLE.Secondary
		local bg = if hovering and not disabled then s.hover else s.bg
		local goal = {
			BackgroundColor3 = bg,
			BackgroundTransparency = if hovering and styleName == "Ghost" then 0.2 else s.bgT,
		}
		if animate then
			C.tween(btn, Theme.Tween.Fast, goal)
		else
			btn.BackgroundColor3 = goal.BackgroundColor3
			btn.BackgroundTransparency = goal.BackgroundTransparency
		end
		text.TextColor3 = s.text
		text.TextTransparency = if disabled then 0.55 else 0
		stroke.Enabled = s.stroke
		if icon then
			Icons.recolor(icon, s.text)
		end
		btn.Active = not disabled
	end
	paint(false)

	btn.MouseEnter:Connect(function()
		hovering = true
		paint(true)
		if hoverSound and not disabled then
			hoverSound()
		end
	end)
	btn.MouseLeave:Connect(function()
		hovering = false
		paint(true)
		C.tween(scale, Theme.Tween.Fast, { Scale = 1 })
	end)
	btn.MouseButton1Down:Connect(function()
		if not disabled then
			C.tween(scale, Theme.Tween.Fast, { Scale = 0.96 })
		end
	end)
	btn.MouseButton1Up:Connect(function()
		C.tween(scale, Theme.Tween.Spring, { Scale = 1 })
	end)
	btn.Activated:Connect(function()
		if disabled then
			return
		end
		if clickSound then
			clickSound()
		end
		if props.OnClick then
			(props.OnClick :: any)()
		end
	end)

	btn.Parent = props.Parent

	local api: ButtonApi = {
		Button = btn,
		setText = function(t: string)
			text.Text = t
		end,
		setStyle = function(st: ButtonStyle)
			styleName = st
			paint(true)
		end,
		setDisabled = function(d: boolean)
			disabled = d
			paint(true)
		end,
	}
	return api
end

function C.iconButton(props: { [string]: any }): TextButton
	local size = props.Size or 40
	local btn: TextButton = New("TextButton", {
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		BackgroundColor3 = props.Color or Theme.Color.Surface1,
		BackgroundTransparency = props.Transparency or Theme.Transparency.Hud,
		Size = UDim2.fromOffset(size, size),
	})
	common(btn, props)
	C.corner(btn, props.Radius or Theme.Radius.Medium)
	if props.Stroke ~= false then
		C.stroke(btn)
	end
	local scale = New("UIScale", { Parent = btn })
	local icon = Icons.make(props.Icon, math.floor(size * (props.IconScale or 0.5)), props.IconColor or Theme.Color.Text)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Parent = btn
	btn.MouseEnter:Connect(function()
		C.tween(btn, Theme.Tween.Fast, { BackgroundColor3 = Theme.Color.Surface2 })
		C.tween(scale, Theme.Tween.Fast, { Scale = 1.05 })
		if hoverSound then
			hoverSound()
		end
	end)
	btn.MouseLeave:Connect(function()
		C.tween(btn, Theme.Tween.Fast, { BackgroundColor3 = props.Color or Theme.Color.Surface1 })
		C.tween(scale, Theme.Tween.Fast, { Scale = 1 })
	end)
	btn.MouseButton1Down:Connect(function()
		C.tween(scale, Theme.Tween.Fast, { Scale = 0.94 })
	end)
	btn.Activated:Connect(function()
		C.tween(scale, Theme.Tween.Spring, { Scale = 1 })
		if clickSound then
			clickSound()
		end
		if props.OnClick then
			(props.OnClick :: any)()
		end
	end)
	btn.Parent = props.Parent
	return btn
end

-- Progress bar. Returns (frame, setValue(v0to1, animate?)).
function C.progress(props: { [string]: any }): (Frame, (number, boolean?) -> ())
	local height = props.Height or 8
	local track = C.frame({
		Parent = props.Parent,
		Name = props.Name or "Progress",
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Size = props.Size or UDim2.new(1, 0, 0, height),
		Color = props.Track or Color3.new(1, 1, 1),
		Transparency = props.TrackTransparency or 0.9,
		Radius = Theme.Radius.Pill,
		Clip = true,
	})
	local fill = C.frame({
		Parent = track,
		Name = "Fill",
		Size = UDim2.fromScale(math.clamp(props.Value or 0, 0, 1), 1),
		Color = props.Color or Theme.Color.Accent,
		Transparency = 0,
		Radius = Theme.Radius.Pill,
	})
	if props.Gradient ~= false then
		New("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215)),
			Rotation = 90,
			Parent = fill,
		})
	end
	local function set(v: number, animate: boolean?)
		local goal = UDim2.fromScale(math.clamp(v, 0, 1), 1)
		if animate then
			C.tween(fill, Theme.Tween.Slow, { Size = goal })
		else
			fill.Size = goal
		end
	end
	return track, set
end

function C.pill(props: { [string]: any }): Frame
	local color: Color3 = props.Color or Theme.Color.Accent
	local f = C.frame({
		Parent = props.Parent,
		Name = props.Name or "Pill",
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Size = UDim2.fromOffset(0, props.Height or 20),
		AutoSize = Enum.AutomaticSize.X,
		Color = color,
		Transparency = props.Transparency or 0.82,
		Radius = Theme.Radius.Pill,
	})
	C.padding(f, 0, 8)
	C.label({
		Parent = f,
		Text = props.Text or "",
		TextSize = props.TextSize or Theme.TextSize.Micro,
		Font = Theme.Font.Bold,
		Color = props.TextColor or color,
		Size = UDim2.new(0, 0, 1, 0),
		AutoSize = Enum.AutomaticSize.X,
		XAlign = Enum.TextXAlignment.Center,
	})
	return f
end

function C.divider(parent: Instance, order: number?): Frame
	return C.frame({
		Parent = parent,
		Name = "Divider",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 1),
		Color = Theme.Color.Stroke,
		Transparency = 0.92,
	})
end

-- Scrolling container with automatic canvas size. Layout "List" (default) or "Grid".
function C.scroll(props: { [string]: any }): ScrollingFrame
	local sf: ScrollingFrame = New("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Color.TextMute,
		ScrollBarImageTransparency = 0.3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		Selectable = false,
	})
	common(sf, props)
	if props.Layout == "Grid" then
		New("UIGridLayout", {
			CellSize = props.CellSize or UDim2.fromOffset(150, 170),
			CellPadding = UDim2.fromOffset(props.Gap or Theme.Space.S, props.Gap or Theme.Space.S),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = sf,
		})
	else
		C.list(sf, "V", props.Gap or Theme.Space.S)
	end
	C.padding(sf, 2, 8, 8, 2)
	sf.Parent = props.Parent
	return sf
end

export type TabsApi = { Frame: Frame, select: (id: string) -> (), current: () -> string }

-- Segmented pill tabs.
function C.tabs(props: { [string]: any }): TabsApi
	local bar = C.frame({
		Parent = props.Parent,
		Name = "Tabs",
		LayoutOrder = props.LayoutOrder,
		Size = props.Size or UDim2.new(1, 0, 0, 34),
		Position = props.Position,
	})
	C.list(bar, "H", 6)
	local buttons: { [string]: TextButton } = {}
	local current = ""
	local function paint()
		for id, b in buttons do
			local on = id == current
			C.tween(b, Theme.Tween.Fast, {
				BackgroundColor3 = if on then Theme.Color.Text else Theme.Color.Surface2,
				BackgroundTransparency = if on then 0 else 0.3,
			})
			local l = b:FindFirstChildOfClass("TextLabel") :: TextLabel?
			if l then
				l.TextColor3 = if on then Theme.Color.Surface0 else Theme.Color.TextDim
			end
		end
	end
	local api: TabsApi
	api = {
		Frame = bar,
		select = function(id: string)
			if current == id then
				return
			end
			current = id
			paint()
			if props.OnSelect then
				(props.OnSelect :: any)(id)
			end
		end,
		current = function()
			return current
		end,
	}
	for i, tab in props.Tabs do
		local b: TextButton = New("TextButton", {
			AutoButtonColor = false,
			Text = "",
			BorderSizePixel = 0,
			BackgroundColor3 = Theme.Color.Surface2,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = i,
			Parent = bar,
		})
		C.corner(b, Theme.Radius.Pill)
		C.padding(b, 0, 14)
		C.label({
			Parent = b,
			Text = tab.Label,
			Font = Theme.Font.Bold,
			TextSize = Theme.TextSize.Caption,
			Size = UDim2.new(0, 0, 1, 0),
			AutoSize = Enum.AutomaticSize.X,
			XAlign = Enum.TextXAlignment.Center,
			Color = Theme.Color.TextDim,
		})
		b.Activated:Connect(function()
			if clickSound then
				clickSound()
			end
			(api.select :: any)(tab.Id)
		end)
		buttons[tab.Id] = b
	end
	paint()
	if props.Initial then
		api.select(props.Initial)
	end
	return api
end

export type ToggleApi = { Frame: TextButton, set: (boolean) -> (), get: () -> boolean }

function C.toggle(props: { [string]: any }): ToggleApi
	local value = props.Value == true
	local b: TextButton = New("TextButton", {
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(46, 26),
		BackgroundColor3 = Theme.Color.Surface3,
	})
	common(b, props)
	C.corner(b, Theme.Radius.Pill)
	local knob = C.frame({ Parent = b, Size = UDim2.fromOffset(20, 20), Color = Theme.Color.Text, Transparency = 0, Radius = Theme.Radius.Pill })
	knob.AnchorPoint = Vector2.new(0, 0.5)
	local function paint(animate: boolean)
		local goalPos = if value then UDim2.new(1, -23, 0.5, 0) else UDim2.new(0, 3, 0.5, 0)
		local goalBg = if value then Theme.Color.Accent else Theme.Color.Surface3
		if animate then
			C.tween(knob, Theme.Tween.Base, { Position = goalPos })
			C.tween(b, Theme.Tween.Base, { BackgroundColor3 = goalBg })
		else
			knob.Position = goalPos
			b.BackgroundColor3 = goalBg
		end
	end
	paint(false)
	b.Activated:Connect(function()
		value = not value
		paint(true)
		if clickSound then
			clickSound()
		end
		if props.OnChange then
			(props.OnChange :: any)(value)
		end
	end)
	b.Parent = props.Parent
	return {
		Frame = b,
		set = function(v: boolean)
			value = v
			paint(true)
		end,
		get = function()
			return value
		end,
	}
end

export type SliderApi = { Frame: Frame, set: (number) -> () }

function C.slider(props: { [string]: any }): SliderApi
	local value = math.clamp(props.Value or 0.5, 0, 1)
	local holder = C.frame({ Parent = props.Parent, LayoutOrder = props.LayoutOrder, Size = props.Size or UDim2.new(1, 0, 0, 26) })
	local track, setFill = C.progress({ Parent = holder, Size = UDim2.new(1, -12, 0, 6), Position = UDim2.new(0, 6, 0.5, -3), Color = props.Color or Theme.Color.Accent, Value = value, Gradient = false })
	local knob = C.frame({ Parent = holder, Size = UDim2.fromOffset(18, 18), Color = Theme.Color.Text, Transparency = 0, Radius = Theme.Radius.Pill })
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	local function place()
		knob.Position = UDim2.new(0, 6 + (holder.AbsoluteSize.X - 12) * value, 0.5, 0)
		setFill(value, false)
	end
	holder:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()
	local dragging = false
	local function fromX(x: number)
		local rel = (x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X)
		value = math.clamp(rel, 0, 1)
		place()
		if props.OnChange then
			(props.OnChange :: any)(value)
		end
	end
	local hit: TextButton = New("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = holder })
	hit.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging and props.OnRelease then
				(props.OnRelease :: any)(value)
			end
			dragging = false
		end
	end)
	return {
		Frame = holder,
		set = function(v: number)
			value = math.clamp(v, 0, 1)
			place()
		end,
	}
end

-- Coloured circle with an icon inside (used for stat / currency badges).
function C.iconBadge(props: { [string]: any }): Frame
	local size = props.Size or 28
	local color: Color3 = props.Color or Theme.Color.Accent
	local f = C.frame({
		Parent = props.Parent,
		Name = props.Name or "Badge",
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Size = UDim2.fromOffset(size, size),
		Color = color,
		Transparency = props.Transparency or 0.8,
		Radius = Theme.Radius.Pill,
	})
	local icon = Icons.make(props.Icon, math.floor(size * 0.56), color)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Parent = f
	return f
end

function C.empty(parent: Instance, text: string): TextLabel
	return C.label({
		Parent = parent,
		Text = text,
		Color = Theme.Color.TextMute,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 60),
		Wrap = true,
	})
end

return C
