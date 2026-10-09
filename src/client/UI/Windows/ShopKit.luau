--!strict
--[[
	ShopKit: building blocks shared by the Shop and Inventory windows.

		Kit.grid(parent, { MinWidth, Height, Scroll? })   responsive card grid
		Kit.chips(parent, items, onSelect)                 compact filter chips (sub-tabs)
		Kit.card(parent, { Accent, Order })                item card: accent bar + wash, hover, badge
		Kit.action({ Parent, Text, Style, Icon? })         button with busy / spec state
		Kit.priceTag(parent)                               currency icon + amount (or lock + note)
		Kit.request(action, payload, opts)                 Net.request + sound + error toast
		Kit.watch(keys, fn)                                debounced DataController change hook
		Kit.gearGlyph / bottleGlyph / auraGlyph / disc / titlePlate   vector item art

	Everything is built from UI/Components and Theme tokens (no image assets).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)
local Net = require(Shared.Util.Net)

local UI = script.Parent.Parent
local C = require(UI.Components)
local Icons = require(UI.Icons)
local New = require(UI.Create)
local Theme = require(UI.Theme)

local Controllers = UI.Parent.Controllers
local AudioController = require(Controllers.AudioController)
local DataController = require(Controllers.DataController)
local NotificationController = require(Controllers.NotificationController)

local Kit = {}

Kit.CurrencyIcon = { Cash = "cash", Trophies = "trophy", RebirthTokens = "token" } :: { [string]: string }
Kit.CurrencyColor = { Cash = Theme.Color.Cash, Trophies = Theme.Color.Trophy, RebirthTokens = Theme.Color.Token } :: { [string]: Color3 }

-- Friendly "how to get it" text for items that are earned rather than sold.
Kit.SourceText = {
	Tournament = "Win a tournament",
	Rank = "Reach Olympian",
	Achievement = "Achievement",
	Daily = "Daily reward",
	Rebirth = "Rebirth reward",
	VIP = "VIP members",
	Default = "Starter item",
	Shop = "Shop",
} :: { [string]: string }

local HOVER_BG = Color3.fromHex("#23242A")

function Kit.amount(currency: string, amount: number): string
	local n = if amount >= 1e6 then Format.short(amount) else Format.commas(amount)
	return if currency == "Cash" then "$" .. n else n
end

function Kit.click()
	AudioController.play("UIClick")
end

function Kit.balance(currency: string): number
	local v = (DataController.data :: any)[currency]
	return if type(v) == "number" then v else 0
end

---------------------------------------------------------------------------
-- Requests
---------------------------------------------------------------------------
export type RequestOpts = { Sound: string?, FailTitle: string? }

-- Yields. Success plays `Sound` (default UIPurchase, "" for none); failures
-- toast the server's message. Success toasts come from the server.
function Kit.request(action: string, payload: any, opts: RequestOpts?): (boolean, any)
	local ok, result = Net.request(action, payload)
	local o: RequestOpts = opts or {}
	if ok then
		local sound = o.Sound or "UIPurchase"
		if sound ~= "" then
			AudioController.play(sound)
		end
	else
		AudioController.play("UIError")
		NotificationController.toast(o.FailTitle or "Couldn't complete that", if type(result) == "string" then result else "Please try again.", "Error")
	end
	return ok, result
end

-- Calls `fn` once per frame at most when any of the top-level data `keys` change.
function Kit.watch(keys: { string }, fn: () -> ()): () -> ()
	local set: { [string]: boolean } = { [""] = true }
	for _, k in keys do
		set[k] = true
	end
	local queued = false
	local conn = DataController.Changed:Connect(function(key: string)
		local top = string.match(key, "^[^%.]+") or ""
		if set[top] and not queued then
			queued = true
			task.defer(function()
				queued = false
				fn()
			end)
		end
	end)
	return function()
		conn:Disconnect()
	end
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
local function scaleOf(inst: Instance): number
	local s = 1
	local node: Instance? = inst
	while node do
		local sc = node:FindFirstChildOfClass("UIScale") :: UIScale?
		if sc then
			s *= sc.Scale
		end
		node = node.Parent
	end
	return s
end

-- Responsive grid: as many MinWidth columns as fit, stretched to fill the row.
-- Scroll = false gives a plain auto-height Frame (for grids inside a scroll page).
function Kit.grid(parent: Instance, props: { [string]: any }): GuiObject
	local minW: number = props.MinWidth or 180
	local h: number = props.Height or 220
	local gap: number = props.Gap or 10
	local container: GuiObject
	local layout: UIGridLayout
	local inset: number
	if props.Scroll == false then
		local f = C.frame({ Parent = parent, Name = props.Name or "Grid", LayoutOrder = props.LayoutOrder, Size = props.Size or UDim2.new(1, 0, 0, 0), AutoSize = Enum.AutomaticSize.Y })
		layout = New("UIGridLayout", { CellPadding = UDim2.fromOffset(gap, gap), SortOrder = Enum.SortOrder.LayoutOrder, Parent = f })
		container = f
		inset = 0
	else
		local sf = C.scroll({ Parent = parent, Name = props.Name or "Grid", Layout = "Grid", Gap = gap, Size = props.Size, Position = props.Position, LayoutOrder = props.LayoutOrder })
		layout = sf:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
		container = sf
		inset = 16 -- scroll padding (2 + 8) + scrollbar
	end
	local lastW = -1
	local function fit()
		local scale = scaleOf(container)
		if scale <= 0 or container.AbsoluteSize.X <= 0 then
			return
		end
		local w = math.floor(container.AbsoluteSize.X / scale) - inset
		if w == lastW then
			return
		end
		lastW = w
		local cols = math.max(1, math.floor((w + gap) / (minW + gap)))
		if props.MaxColumns then
			cols = math.min(cols, props.MaxColumns)
		end
		local cw = math.floor((w - gap * (cols - 1)) / cols)
		layout.CellSize = UDim2.fromOffset(cw, h)
	end
	layout.CellSize = UDim2.fromOffset(minW, h)
	container:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.defer(fit)
	return container
end

-- Total absolute width of a row's visible children (absolute pixel space).
function Kit.contentWidth(row: Instance, gap: number): number
	local w = 0
	for _, child in row:GetChildren() do
		if child:IsA("GuiObject") and (child :: GuiObject).Visible then
			w += (child :: GuiObject).AbsoluteSize.X + gap
		end
	end
	return w
end

-- Hides `extra` (a right-aligned hint) whenever it would overlap the content of
-- the list row `row` (chips / tabs). Both share a parent; returns the fit function.
function Kit.autoHide(extra: GuiObject, row: GuiObject): () -> ()
	local parent = row.Parent :: GuiObject
	local function fit()
		extra.Visible = Kit.contentWidth(row, 6) + extra.AbsoluteSize.X + 16 <= parent.AbsoluteSize.X
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	row.ChildAdded:Connect(function()
		task.defer(fit)
	end)
	task.defer(fit)
	return fit
end

-- Section label in the Settings style (small caps, muted).
function Kit.section(parent: Instance, text: string, order: number?): TextLabel
	return C.label({
		Parent = parent,
		LayoutOrder = order,
		Text = string.upper(text),
		Font = Theme.Font.Heavy,
		TextSize = Theme.TextSize.Caption,
		Color = Theme.Color.TextMute,
		Size = UDim2.new(1, 0, 0, 20),
	})
end

-- Friendly empty state with an optional call to action.
function Kit.emptyState(parent: Instance, props: { [string]: any }): Frame
	local f = C.frame({ Parent = parent, Name = "Empty", LayoutOrder = props.LayoutOrder, Size = props.Size or UDim2.fromScale(1, 1) })
	local col = C.frame({ Parent = f, Size = UDim2.fromOffset(340, 0), AutoSize = Enum.AutomaticSize.Y, Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5) })
	C.list(col, "V", 8, Enum.HorizontalAlignment.Center)
	C.iconBadge({ Parent = col, Icon = props.Icon or "info", Color = props.Color or Theme.Color.TextDim, Size = 52, LayoutOrder = 1, Transparency = 0.86 })
	C.label({ Parent = col, LayoutOrder = 2, Text = props.Title or "Nothing here yet", Font = Theme.Font.Bold, TextSize = Theme.TextSize.Heading, XAlign = Enum.TextXAlignment.Center })
	if props.Text then
		C.label({ Parent = col, LayoutOrder = 3, Text = props.Text, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextDim, XAlign = Enum.TextXAlignment.Center, Wrap = true, Size = UDim2.new(1, 0, 0, 0), AutoSize = Enum.AutomaticSize.Y })
	end
	if props.Action and props.OnAction then
		C.frame({ Parent = col, LayoutOrder = 4, Size = UDim2.fromOffset(1, 4) })
		C.button({ Parent = col, LayoutOrder = 5, Text = props.Action, Style = "Primary", AutoSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 40), OnClick = props.OnAction })
	end
	return f
end

---------------------------------------------------------------------------
-- Chips (sub-tabs / filters)
---------------------------------------------------------------------------
export type ChipItem = { Id: string, Label: string, Color: Color3? }
export type Chips = { Frame: Frame, select: (id: string) -> (), current: () -> string }

function Kit.chips(parent: Instance, items: { ChipItem }, onSelect: (id: string) -> (), props: { [string]: any }?): Chips
	local p: { [string]: any } = props or {}
	local bar = C.frame({ Parent = parent, Name = "Chips", LayoutOrder = p.LayoutOrder, Size = p.Size or UDim2.new(1, 0, 0, 34), Position = p.Position })
	C.list(bar, "H", 6, nil, Enum.VerticalAlignment.Center)
	type Chip = { button: TextButton, label: TextLabel, stroke: UIStroke }
	local chips: { [string]: Chip } = {}
	local current = ""
	local hovered: string? = nil
	local function paint()
		for id, chip in chips do
			local on = id == current
			C.tween(chip.button, Theme.Tween.Fast, {
				BackgroundColor3 = if on then Theme.Color.Surface3 elseif hovered == id then Theme.Color.Surface2 else Theme.Color.Surface1,
			})
			chip.stroke.Color = if on then Theme.Color.Accent else Theme.Color.Stroke
			chip.stroke.Transparency = if on then 0.35 else 0.88
			chip.label.TextColor3 = if on then Theme.Color.Text else Theme.Color.TextDim
		end
	end
	local api: Chips
	api = {
		Frame = bar,
		select = function(id: string)
			if id == current or not chips[id] then
				return
			end
			current = id
			paint()
			onSelect(id)
		end,
		current = function()
			return current
		end,
	}
	for i, item in items do
		local b: TextButton = New("TextButton", {
			Name = item.Id,
			AutoButtonColor = false,
			Text = "",
			BorderSizePixel = 0,
			BackgroundColor3 = Theme.Color.Surface1,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = i,
			Parent = bar,
		})
		C.corner(b, Theme.Radius.Pill)
		local stroke = C.stroke(b, 0.88)
		C.padding(b, 0, 14, 0, if item.Color then 10 else 14)
		C.list(b, "H", 7, nil, Enum.VerticalAlignment.Center)
		if item.Color then
			C.frame({ Parent = b, Size = UDim2.fromOffset(8, 8), Color = item.Color, Transparency = 0, Radius = Theme.Radius.Pill, LayoutOrder = 1 })
		end
		local label = C.label({
			Parent = b,
			Text = item.Label,
			Font = Theme.Font.Bold,
			TextSize = Theme.TextSize.Caption,
			Color = Theme.Color.TextDim,
			Size = UDim2.new(0, 0, 1, 0),
			AutoSize = Enum.AutomaticSize.X,
			LayoutOrder = 2,
		})
		chips[item.Id] = { button = b, label = label, stroke = stroke }
		b.MouseEnter:Connect(function()
			hovered = item.Id
			paint()
		end)
		b.MouseLeave:Connect(function()
			if hovered == item.Id then
				hovered = nil
			end
			paint()
		end)
		b.Activated:Connect(function()
			AudioController.play("UIClick")
			api.select(item.Id)
		end)
	end
	paint()
	return api
end

---------------------------------------------------------------------------
-- Card
---------------------------------------------------------------------------
export type Card = {
	Frame: Frame,
	Body: Frame, -- vertical list area (padding applied)
	Footer: Frame, -- 36px row pinned to the bottom
	setHighlight: (on: boolean) -> (),
	setBadge: (text: string?, color: Color3?) -> (),
	setDimmed: (on: boolean) -> (),
}

function Kit.card(parent: Instance, props: { [string]: any }): Card
	local accent: Color3 = props.Accent or Theme.Color.Accent
	local footerH: number = props.FooterHeight or 36
	local f = C.frame({ Parent = parent, Name = props.Name or "Card", LayoutOrder = props.Order, Size = props.Size or UDim2.fromScale(1, 1), Color = Theme.Color.Surface1, Transparency = 0, Radius = Theme.Radius.Large })
	local stroke = C.stroke(f, 0.9)

	-- accent wash fading down from the top edge + a short accent bar
	local wash = C.frame({ Parent = f, Name = "Wash", Size = UDim2.fromScale(1, 0.62), Color = accent, Transparency = 0, Radius = Theme.Radius.Large })
	New("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(0.55, 0.94), NumberSequenceKeypoint.new(1, 1) }),
		Parent = wash,
	})
	C.frame({ Parent = f, Name = "Bar", Size = UDim2.new(0.4, 0, 0, 3), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0), Color = accent, Transparency = 0, Radius = Theme.Radius.Pill })

	local body = C.frame({ Parent = f, Name = "Body", Size = UDim2.new(1, 0, 1, -(footerH + 12)) })
	C.padding(body, 12, 12, 0, 12)
	C.list(body, "V", 4, Enum.HorizontalAlignment.Center)
	local footer = C.frame({ Parent = f, Name = "Footer", Size = UDim2.new(1, -24, 0, footerH), Position = UDim2.new(0, 12, 1, -12), AnchorPoint = Vector2.new(0, 1) })

	local badgeHolder = C.frame({ Parent = f, Name = "BadgeHolder", Size = UDim2.fromOffset(0, 20), AutoSize = Enum.AutomaticSize.X, Position = UDim2.new(1, -10, 0, 10), AnchorPoint = Vector2.new(1, 0), ZIndex = 3 })

	local highlighted = false
	local hovering = false
	local dimmed = false
	local function paint()
		C.tween(f, Theme.Tween.Fast, { BackgroundColor3 = if hovering then HOVER_BG else Theme.Color.Surface1 })
		stroke.Color = if highlighted then Theme.Color.Success else Theme.Color.Stroke
		stroke.Thickness = if highlighted then 1.5 else 1
		C.tween(stroke, Theme.Tween.Fast, { Transparency = if highlighted then 0.35 elseif hovering then 0.72 else 0.9 })
		wash.BackgroundTransparency = if dimmed then 0.5 else 0
	end
	f.MouseEnter:Connect(function()
		hovering = true
		paint()
	end)
	f.MouseLeave:Connect(function()
		hovering = false
		paint()
	end)
	local badgeText: string? = nil
	return {
		Frame = f,
		Body = body,
		Footer = footer,
		setHighlight = function(on: boolean)
			if on ~= highlighted then
				highlighted = on
				paint()
			end
		end,
		setBadge = function(text: string?, color: Color3?)
			if text == badgeText then
				return
			end
			badgeText = text
			badgeHolder:ClearAllChildren()
			if text then
				C.pill({ Parent = badgeHolder, Text = text, Color = color or Theme.Color.TextDim, Height = 20 })
			end
		end,
		setDimmed = function(on: boolean)
			if on ~= dimmed then
				dimmed = on
				paint()
			end
		end,
	}
end

-- A fixed-height row inside a card body.
function Kit.row(parent: Instance, height: number, order: number, name: string?): Frame
	return C.frame({ Parent = parent, Name = name or "Row", LayoutOrder = order, Size = UDim2.new(1, 0, 0, height) })
end

---------------------------------------------------------------------------
-- Action button (busy-safe)
---------------------------------------------------------------------------
export type ActionSpec = { Text: string, Style: string?, Disabled: boolean?, Run: (() -> ())? }
export type Action = {
	Button: TextButton,
	set: (spec: ActionSpec) -> (),
	send: (action: string, payload: any, opts: RequestOpts?) -> (),
}

function Kit.action(props: { [string]: any }): Action
	local spec: ActionSpec = { Text = props.Text or "", Style = props.Style or "Secondary" }
	local busy = false
	local holdUntil = 0
	local shown = { text = "", style = "", disabled = false }
	local api: C.ButtonApi
	local function paint()
		local style = spec.Style or "Secondary"
		local disabled = busy or spec.Disabled == true or os.clock() < holdUntil
		if shown.text ~= spec.Text then
			shown.text = spec.Text
			api.setText(spec.Text)
		end
		if shown.style ~= style then
			shown.style = style
			api.setStyle(style :: any)
		end
		if shown.disabled ~= disabled then
			shown.disabled = disabled
			api.setDisabled(disabled)
		end
	end
	api = C.button({
		Parent = props.Parent,
		Name = props.Name,
		LayoutOrder = props.LayoutOrder,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Text = spec.Text,
		Style = spec.Style,
		Icon = props.Icon,
		IconSize = props.IconSize,
		TextSize = props.TextSize or Theme.TextSize.Caption + 1,
		OnClick = function()
			if busy or os.clock() < holdUntil or spec.Disabled then
				return
			end
			local run = spec.Run
			if run then
				run()
			end
		end,
	})
	shown.text = spec.Text
	shown.style = spec.Style or "Secondary"
	local self: Action
	self = {
		Button = api.Button,
		set = function(s: ActionSpec)
			spec = s
			paint()
		end,
		send = function(action: string, payload: any, opts: RequestOpts?)
			if busy then
				return
			end
			busy = true
			paint()
			task.spawn(function()
				local ok = Kit.request(action, payload, opts)
				busy = false
				if ok then
					-- hold briefly so the data patch can land before re-enabling
					holdUntil = os.clock() + 0.8
					task.delay(0.85, paint)
				end
				paint()
			end)
		end,
	}
	return self
end

---------------------------------------------------------------------------
-- Price tag: currency icon + amount, or lock + requirement note.
---------------------------------------------------------------------------
export type PriceTag = {
	Frame: Frame,
	setPrice: (currency: string, amount: number, affordable: boolean) -> (),
	setNote: (text: string, icon: string?, color: Color3?) -> (),
}

function Kit.priceTag(parent: Instance, props: { [string]: any }?): PriceTag
	local p: { [string]: any } = props or {}
	local f = C.frame({ Parent = parent, Name = "Price", Size = p.Size or UDim2.new(1, -100, 1, 0), Position = p.Position, LayoutOrder = p.LayoutOrder })
	C.list(f, "H", 6, nil, Enum.VerticalAlignment.Center)
	local iconHolder = C.frame({ Parent = f, Size = UDim2.fromOffset(18, 18), LayoutOrder = 1 })
	local label = C.label({ Parent = f, Font = Theme.Font.Bold, TextSize = Theme.TextSize.Body, Size = UDim2.new(1, -24, 1, 0), LayoutOrder = 2 })
	local shownIcon = ""
	local shownColor: Color3? = nil
	local function icon(name: string, color: Color3)
		if shownIcon ~= name or shownColor ~= color then
			shownIcon = name
			shownColor = color
			iconHolder:ClearAllChildren()
			local i = Icons.make(name, 18, color)
			i.Parent = iconHolder
		end
	end
	return {
		Frame = f,
		setPrice = function(currency: string, amount: number, affordable: boolean)
			icon(Kit.CurrencyIcon[currency] or "cash", Kit.CurrencyColor[currency] or Theme.Color.Text)
			label.Text = Kit.amount(currency, amount)
			label.FontFace = Theme.Font.Bold
			label.TextSize = Theme.TextSize.Body
			label.TextColor3 = if affordable then Theme.Color.Text else Theme.Color.Danger
		end,
		setNote = function(text: string, iconName: string?, color: Color3?)
			icon(iconName or "lock", color or Theme.Color.TextMute)
			label.Text = text
			label.FontFace = Theme.Font.SemiBold
			label.TextSize = Theme.TextSize.Caption
			label.TextColor3 = color or Theme.Color.TextMute
		end,
	}
end

---------------------------------------------------------------------------
-- Glyphs (vector art from Frames)
---------------------------------------------------------------------------
type ShapeOpts = { r: number?, rot: number?, alpha: number?, stroke: number? }

local function shape(parent: Instance, cx: number, cy: number, w: number, h: number, color: Color3, o: ShapeOpts?): Frame
	local opts: ShapeOpts = o or {}
	local f = New("Frame", {
		Name = "Shape",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(cx, cy),
		Size = UDim2.fromScale(w, h),
		BorderSizePixel = 0,
		Rotation = opts.rot or 0,
		BackgroundColor3 = color,
		BackgroundTransparency = if opts.stroke then 1 else (opts.alpha or 0),
		Parent = parent,
	})
	if opts.r then
		C.corner(f, UDim.new(opts.r, 0))
	end
	if opts.stroke then
		New("UIStroke", { Color = color, Thickness = opts.stroke, Transparency = opts.alpha or 0, Parent = f })
	end
	return f
end

local function canvas(size: number): Frame
	return New("Frame", { Name = "Glyph", BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size) })
end

local DARK = Color3.fromHex("#141518")

-- Slot-specific gear illustration in the item's colours.
function Kit.gearGlyph(slot: string, primary: Color3, secondary: Color3, tier: number, size: number): Frame
	local g = canvas(size)
	local deep = primary:Lerp(Color3.new(0, 0, 0), 0.22)
	if slot == "Gloves" then
		for i = 0, 3 do
			shape(g, 0.33 + i * 0.113, 0.2 + (if i == 0 or i == 3 then 0.04 else 0), 0.09, 0.2, deep, { r = 0.5 })
		end
		shape(g, 0.5, 0.45, 0.56, 0.42, primary, { r = 0.32 })
		shape(g, 0.5, 0.44, 0.32, 0.2, secondary, { r = 0.4, alpha = 0.35 })
		shape(g, 0.2, 0.5, 0.14, 0.26, primary, { r = 0.5, rot = -28 })
		shape(g, 0.5, 0.71, 0.62, 0.14, secondary, { r = 0.3 })
		shape(g, 0.5, 0.83, 0.5, 0.11, deep, { r = 0.3 })
	elseif slot == "Shoes" then
		shape(g, 0.5, 0.72, 0.84, 0.11, secondary, { r = 0.5 })
		shape(g, 0.44, 0.56, 0.6, 0.26, primary, { r = 0.45 })
		shape(g, 0.7, 0.6, 0.3, 0.2, primary, { r = 0.5 })
		shape(g, 0.27, 0.42, 0.24, 0.24, primary, { r = 0.35 })
		shape(g, 0.79, 0.65, 0.14, 0.1, secondary, { r = 0.5, alpha = 0.2 })
		for i = 0, 2 do
			shape(g, 0.44 + i * 0.08, 0.45 + i * 0.025, 0.035, 0.1, secondary, { r = 0.5, rot = 24 })
		end
		shape(g, 0.47, 0.6, 0.32, 0.045, secondary, { r = 0.5, rot = -10 })
	elseif slot == "Belt" then
		shape(g, 0.5, 0.5, 0.9, 0.28, primary, { r = 0.25 })
		shape(g, 0.5, 0.39, 0.84, 0.02, secondary, { alpha = 0.45 })
		shape(g, 0.5, 0.61, 0.84, 0.02, secondary, { alpha = 0.45 })
		shape(g, 0.5, 0.5, 0.24, 0.38, secondary, { r = 0.18 })
		shape(g, 0.5, 0.5, 0.12, 0.2, deep, { r = 0.15 })
		shape(g, 0.33, 0.5, 0.06, 0.32, deep, { r = 0.3 })
	elseif slot == "Wraps" then
		shape(g, 0.5, 0.5, 0.46, 0.62, primary, { r = 0.2 })
		for i = 0, 2 do
			shape(g, 0.5, 0.33 + i * 0.17, 0.56, 0.08, if i == 1 then secondary else deep, { r = 0.4, rot = -14 })
		end
		shape(g, 0.79, 0.62, 0.16, 0.12, secondary, { r = 0.3 })
	else -- Headband
		shape(g, 0.5, 0.5, 0.78, 0.4, primary, { r = 0.5, stroke = math.max(2, size * 0.1) })
		shape(g, 0.5, 0.69, 0.18, 0.12, secondary, { r = 0.25 })
		shape(g, 0.82, 0.38, 0.08, 0.3, deep, { r = 0.5, rot = 24 })
		shape(g, 0.9, 0.42, 0.08, 0.26, deep, { r = 0.5, rot = 40 })
	end
	if tier >= 5 then
		-- premium tiers: a fine trim line in the accent colour (gold / light)
		shape(g, 0.5, 0.95, 0.4, 0.03, secondary, { r = 0.5 })
	end
	return g
end

-- Shaker bottle in the boost colour.
function Kit.bottleGlyph(color: Color3, size: number): Frame
	local g = canvas(size)
	shape(g, 0.5, 0.17, 0.16, 0.08, Theme.Color.Surface3, { r = 0.3 })
	shape(g, 0.5, 0.27, 0.46, 0.13, Color3.fromHex("#3B3C44"), { r = 0.3 })
	shape(g, 0.5, 0.61, 0.42, 0.56, color, { r = 0.22 })
	shape(g, 0.5, 0.62, 0.42, 0.13, Color3.new(1, 1, 1), { alpha = 0.78 })
	shape(g, 0.38, 0.6, 0.06, 0.38, Color3.new(1, 1, 1), { r = 0.5, alpha = 0.6 })
	return g
end

local AURA_COLOR: { [string]: Color3 } = {
	Chalk = Color3.fromRGB(236, 234, 228),
	Steam = Color3.fromRGB(196, 204, 212),
	Embers = Color3.fromRGB(240, 132, 60),
	Frost = Color3.fromRGB(150, 210, 245),
	Glint = Color3.fromRGB(240, 196, 90),
	Storm = Color3.fromRGB(176, 140, 255),
	Halo = Color3.fromRGB(255, 240, 200),
}
Kit.AuraColor = AURA_COLOR

-- Soft concentric glow with a few particles.
function Kit.auraGlyph(effect: string, size: number): Frame
	local g = canvas(size)
	local c = AURA_COLOR[effect] or Theme.Color.Accent
	shape(g, 0.5, 0.5, 0.92, 0.92, c, { r = 0.5, alpha = 0.9 })
	shape(g, 0.5, 0.5, 0.66, 0.66, c, { r = 0.5, alpha = 0.78 })
	shape(g, 0.5, 0.5, 0.38, 0.38, c, { r = 0.5, alpha = 0.35 })
	if effect == "Halo" then
		shape(g, 0.5, 0.2, 0.5, 0.14, c, { r = 0.5, stroke = math.max(1.5, size * 0.04) })
	end
	local dots = { { 0.18, 0.32, 0.07 }, { 0.82, 0.26, 0.06 }, { 0.86, 0.7, 0.08 }, { 0.22, 0.78, 0.05 }, { 0.62, 0.1, 0.05 } }
	for _, d in dots do
		shape(g, d[1], d[2], d[3], d[3], c, { r = 0.5, alpha = 0.15 })
	end
	return g
end

-- Coloured disc with an icon (companions, emotes, decor, products).
function Kit.disc(icon: string, color: Color3, size: number): Frame
	local g = canvas(size)
	local outer = shape(g, 0.5, 0.5, 1, 1, color, { r = 0.5, alpha = 0.84 })
	New("UIGradient", { Rotation = 120, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)), Parent = outer })
	shape(g, 0.5, 0.5, 0.74, 0.74, color, { r = 0.5, alpha = 0.72 })
	local i = Icons.make(icon, math.floor(size * 0.42), color:Lerp(Color3.new(1, 1, 1), 0.25))
	i.AnchorPoint = Vector2.new(0.5, 0.5)
	i.Position = UDim2.fromScale(0.5, 0.5)
	i.Parent = g
	return g
end

-- Nameplate-style preview of a title (player name + coloured title).
function Kit.titlePlate(text: string, color: Color3, width: number): Frame
	local plate = C.frame({ Size = UDim2.fromOffset(width, 56), Color = DARK, Transparency = 0.15, Radius = Theme.Radius.Medium })
	C.stroke(plate, 0.9)
	C.label({ Parent = plate, Text = Players.LocalPlayer.DisplayName, Font = Theme.Font.SemiBold, TextSize = Theme.TextSize.Micro, Color = Theme.Color.TextDim, XAlign = Enum.TextXAlignment.Center, Size = UDim2.new(1, -12, 0, 16), Position = UDim2.fromOffset(6, 8) })
	C.label({ Parent = plate, Text = text, Font = Theme.Font.Heavy, TextSize = Theme.TextSize.Heading + 1, Color = color, XAlign = Enum.TextXAlignment.Center, Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 24) })
	return plate
end

-- Centres a glyph inside a fixed-height card row.
function Kit.art(parent: Instance, glyph: GuiObject, height: number, order: number): Frame
	local row = Kit.row(parent, height, order, "Art")
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Parent = row
	return row
end

return Kit
