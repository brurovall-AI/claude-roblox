--!strict
--[[
	UIController: HUD shell + window manager.

	HUD slots (Frames under UIController.hud) for other controllers to fill:
	  TopLeft   profile chip (built here)
	  TopRight  currency pills (built here)
	  Top       centre-top slot (event banner); toasts stack beneath it
	  Left      menu rail (built here)
	  Right     right-side slot (mission tracker)
	  Bottom    energy bar (built here) — put training UI in BottomStack
	  BottomStack  vertical stack above the energy bar (minigame panel etc.)
	  Overlay   full-screen layer above windows (banners, cinematics)

	Windows:
	  UIController.registerWindow("Shop", {
	      Title = "Shop", Icon = "shop",
	      Build = function(body: Frame, ctx) ... end,  -- called lazily on first open
	      OnOpen = function() end, OnClose = function() end,
	  })
	  UIController.open("Shop") / close() / toggle("Shop") / isOpen("Shop")
	  UIController.setBadge("Missions", 2)    -- red counter on the rail button
	  UIController.hide("PhotoMode") / unhide("PhotoMode")  -- stacked HUD hiding

	Rail order is fixed (see RAIL); a rail button appears once its window is registered.
]]

local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local Format = require(Shared.Util.Format)
local Progression = require(Config.Progression)
local Ranks = require(Config.Ranks)
local Signal = require(Shared.Util.Signal)

local UI = script.Parent.Parent.UI
local C = require(UI.Components)
local New = require(UI.Create)
local Theme = require(UI.Theme)

local State = require(script.Parent.Parent.Core.State)
local DataController = require(script.Parent.DataController)

local player = Players.LocalPlayer

local UIController = {}
UIController.Priority = 5

export type WindowDef = {
	Title: string,
	Icon: string?,
	Build: (body: Frame, ctx: { close: () -> (), window: CanvasGroup }) -> (),
	OnOpen: (() -> ())?,
	OnClose: (() -> ())?,
	Width: number?,
	Height: number?,
}

type WindowRecord = { def: WindowDef, frame: CanvasGroup?, built: boolean }

UIController.WindowOpened = Signal.new() :: Signal.Signal<string>
UIController.WindowClosed = Signal.new() :: Signal.Signal<string>

UIController.hud = {} :: { [string]: Frame }
UIController.screenGui = nil :: ScreenGui?
UIController.isTouch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local RAIL = {
	{ Id = "Stats", Icon = "stats", Label = "Stats" },
	{ Id = "Inventory", Icon = "gear", Label = "Gear" },
	{ Id = "Shop", Icon = "shop", Label = "Shop" },
	{ Id = "Missions", Icon = "missions", Label = "Missions" },
	{ Id = "Daily", Icon = "daily", Label = "Daily" },
	{ Id = "Leaderboards", Icon = "ranks", Label = "Ranks" },
	{ Id = "Social", Icon = "social", Label = "Social" },
	{ Id = "Settings", Icon = "settings", Label = "Settings" },
}

local windows: { [string]: WindowRecord } = {}
local railButtons: { [string]: TextButton } = {}
local badges: { [string]: Frame } = {}
local openId: string? = nil
local hideKeys: { [string]: boolean } = {}

local gui: ScreenGui
local root: Frame
local uiScale: UIScale
local dim: TextButton
local windowLayer: Frame
local blur: BlurEffect

---------------------------------------------------------------------------
-- Layout scaling
---------------------------------------------------------------------------
local function updateScale()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local vp = cam.ViewportSize
	local s = math.min(vp.X / 1366, vp.Y / 768)
	if UIController.isTouch then
		s = math.clamp(s * 1.12, 0.62, 1.05)
	else
		s = math.clamp(s, 0.72, 1.3)
	end
	uiScale.Scale = s
end

---------------------------------------------------------------------------
-- HUD pieces
---------------------------------------------------------------------------
local function slot(name: string, props: { [string]: any }): Frame
	local f = C.frame({
		Parent = props.Parent or root,
		Name = name,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
	})
	UIController.hud[name] = f
	return f
end

local function buildProfile(parent: Frame)
	local chip = C.frame({
		Parent = parent,
		Name = "Profile",
		Size = UDim2.fromOffset(268, 64),
		Color = Theme.Color.Surface0,
		Transparency = Theme.Transparency.Hud,
		Radius = Theme.Radius.Large,
	})
	C.stroke(chip)
	C.padding(chip, 8, 12, 8, 8)

	local avatar = New("ImageLabel", {
		Name = "Avatar",
		BackgroundColor3 = Theme.Color.Surface2,
		Size = UDim2.fromOffset(48, 48),
		Image = "",
		Parent = chip,
	})
	C.corner(avatar, Theme.Radius.Pill)
	local ring = C.stroke(avatar, 0.2, Theme.Color.Accent, 2)
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok then
			avatar.Image = img
		end
	end)

	local info = C.frame({ Parent = chip, Name = "Info", Size = UDim2.new(1, -58, 1, 0), Position = UDim2.fromOffset(58, 0) })
	local nameRow = C.frame({ Parent = info, Size = UDim2.new(1, 0, 0, 20) })
	C.list(nameRow, "H", 6, nil, Enum.VerticalAlignment.Center)
	C.label({
		Parent = nameRow,
		Text = player.DisplayName,
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Body,
		Size = UDim2.new(0, 0, 1, 0),
		AutoSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
	})
	local rankHolder = C.frame({ Parent = nameRow, Size = UDim2.new(0, 0, 1, 0), AutoSize = Enum.AutomaticSize.X, LayoutOrder = 2 })

	local levelRow = C.frame({ Parent = info, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 22) })
	local levelText = C.label({ Parent = levelRow, Text = "LV 1", Font = Theme.Font.Heavy, TextSize = Theme.TextSize.Caption, Color = Theme.Color.Accent, Size = UDim2.new(0, 44, 1, 0) })
	local xpText = C.label({
		Parent = levelRow,
		Text = "0 / 50 XP",
		TextSize = Theme.TextSize.Micro,
		Color = Theme.Color.TextDim,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, -44, 1, 0),
		Position = UDim2.fromOffset(44, 0),
	})
	local _, setXP = C.progress({ Parent = info, Size = UDim2.new(1, 0, 0, 5), Position = UDim2.fromOffset(0, 42), Color = Theme.Color.XP })

	local lastRank = 0
	local function refresh()
		local data = DataController.data
		local need = Progression.xpToNext(data.Level)
		levelText.Text = "LV " .. data.Level
		xpText.Text = `{Format.short(data.XP)} / {Format.short(need)} XP`
		setXP(data.XP / need, true)
		local rank = Ranks.forPower(Progression.power(data.Stats :: any))
		if rank.Index ~= lastRank then
			lastRank = rank.Index
			rankHolder:ClearAllChildren()
			C.pill({ Parent = rankHolder, Text = string.upper(rank.Name), Color = rank.Color, Height = 18 })
			ring.Color = rank.Color
		end
	end
	DataController.observe("Level", refresh)
	DataController.observe("XP", refresh)
	DataController.observe("Stats", refresh)
end

local function currencyPill(parent: Frame, order: number, icon: string, color: Color3, key: string)
	local pill = C.frame({
		Parent = parent,
		Name = key,
		LayoutOrder = order,
		Size = UDim2.fromOffset(0, 36),
		AutoSize = Enum.AutomaticSize.X,
		Color = Theme.Color.Surface0,
		Transparency = Theme.Transparency.Hud,
		Radius = Theme.Radius.Pill,
	})
	C.stroke(pill)
	C.padding(pill, 0, 14, 0, 5)
	C.list(pill, "H", 8, nil, Enum.VerticalAlignment.Center)
	C.iconBadge({ Parent = pill, Icon = icon, Color = color, Size = 26, LayoutOrder = 1 })
	local text = C.label({
		Parent = pill,
		Text = "0",
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Body,
		Size = UDim2.new(0, 0, 1, 0),
		AutoSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
	})
	local shown = 0
	local counter = New("NumberValue", { Parent = pill })
	counter.Changed:Connect(function(v: number)
		text.Text = Format.short(v)
	end)
	DataController.observe(key, function(value: any)
		local v = if type(value) == "number" then value else 0
		if key == "RebirthTokens" then
			pill.Visible = v > 0
		end
		local delta = v - shown
		shown = v
		if delta > 0 and DataController.loaded and text.Text ~= "0" then
			-- floating "+X"
			local float = C.label({
				Parent = pill,
				Text = "+" .. Format.short(delta),
				Font = Theme.Font.Bold,
				TextSize = Theme.TextSize.Caption,
				Color = color,
				Size = UDim2.fromOffset(80, 16),
				XAlign = Enum.TextXAlignment.Right,
			})
			float.Parent = parent.Parent -- out of the list layout
			float.AnchorPoint = Vector2.new(1, 0)
			float.Position = UDim2.new(0, pill.AbsolutePosition.X - (parent.Parent :: Frame).AbsolutePosition.X + pill.AbsoluteSize.X - 14, 0, 40)
			C.tween(float, TweenInfo.new(0.9, Enum.EasingStyle.Quint), { Position = float.Position + UDim2.fromOffset(0, 18), TextTransparency = 1 })
			task.delay(1, function()
				float:Destroy()
			end)
		end
		C.tween(counter, TweenInfo.new(0.6, Enum.EasingStyle.Quint), { Value = v })
	end)
end

local function buildCurrencies(parent: Frame)
	local row = C.frame({ Parent = parent, Name = "Currencies", Size = UDim2.new(1, 0, 0, 36) })
	C.list(row, "H", 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	currencyPill(row, 1, "token", Theme.Color.Token, "RebirthTokens")
	currencyPill(row, 2, "trophy", Theme.Color.Trophy, "Trophies")
	currencyPill(row, 3, "cash", Theme.Color.Cash, "Cash")
end

local function buildEnergy(parent: Frame)
	local holder = C.frame({
		Parent = parent,
		Name = "Energy",
		Size = UDim2.fromOffset(300, 30),
		Color = Theme.Color.Surface0,
		Transparency = Theme.Transparency.Hud,
		Radius = Theme.Radius.Pill,
	})
	C.stroke(holder)
	C.padding(holder, 0, 12, 0, 6)
	C.iconBadge({ Parent = holder, Icon = "energy", Color = Theme.Color.Energy, Size = 22, Position = UDim2.new(0, 0, 0.5, -11) })
	local track, setFill = C.progress({
		Parent = holder,
		Size = UDim2.new(1, -96, 0, 8),
		Position = UDim2.new(0, 30, 0.5, -4),
		Color = Theme.Color.Energy,
	})
	local text = C.label({
		Parent = holder,
		Text = "100",
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Caption,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 60, 1, 0),
		Position = UDim2.new(1, -60, 0, 0),
	})
	local fill = track:FindFirstChild("Fill") :: Frame
	local function refresh()
		local data = DataController.data
		local max = Progression.maxEnergy(data.Stats.Energy)
		local e = math.clamp(data.Energy, 0, max)
		setFill(e / max, true)
		text.Text = `{math.floor(e)}/{max}`
		local low = e / max < 0.2
		fill.BackgroundColor3 = if low then Theme.Color.Danger else Theme.Color.Energy
	end
	DataController.observe("Energy", refresh)
	DataController.observe("Stats.Energy", refresh)
end

local function buildRail(parent: Frame)
	local rail = C.frame({ Parent = parent, Name = "Rail", Size = UDim2.new(1, 0, 1, 0) })
	C.list(rail, "V", 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	for i, item in RAIL do
		local holder = C.frame({ Parent = rail, Name = item.Id, Size = UDim2.fromOffset(56, 62), LayoutOrder = i, Visible = false })
		local btn = C.iconButton({
			Parent = holder,
			Icon = item.Icon,
			Size = 48,
			Position = UDim2.fromOffset(4, 0),
			Transparency = Theme.Transparency.Hud,
			Color = Theme.Color.Surface0,
			IconScale = 0.48,
			OnClick = function()
				UIController.toggle(item.Id)
			end,
		})
		C.label({
			Parent = holder,
			Text = item.Label,
			TextSize = Theme.TextSize.Micro,
			Font = Theme.Font.SemiBold,
			Color = Theme.Color.TextDim,
			XAlign = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 12),
			Position = UDim2.fromOffset(0, 50),
		})
		local badge = C.frame({
			Parent = btn,
			Name = "Badge",
			Size = UDim2.fromOffset(18, 18),
			Position = UDim2.new(1, -12, 0, -6),
			Color = Theme.Color.Danger,
			Transparency = 0,
			Radius = Theme.Radius.Pill,
			Visible = false,
		})
		C.label({ Parent = badge, Name = "Count", Text = "1", Font = Theme.Font.Heavy, TextSize = Theme.TextSize.Micro, XAlign = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
		railButtons[item.Id] = btn
		badges[item.Id] = badge
	end
end

---------------------------------------------------------------------------
-- Windows
---------------------------------------------------------------------------
local function windowSize(def: WindowDef): (number, number)
	local w, h = def.Width or 760, def.Height or 500
	local cam = Workspace.CurrentCamera
	if cam then
		local s = uiScale.Scale
		local vp = cam.ViewportSize / s
		w = math.min(w, vp.X * (if UIController.isTouch then 0.96 else 0.9) - 140)
		h = math.min(h, vp.Y * 0.84)
	end
	return math.max(320, w), math.max(260, h)
end

local function buildWindow(id: string, rec: WindowRecord): CanvasGroup
	local def = rec.def
	local w, h = windowSize(def)
	-- CanvasGroup so the whole window can fade as one layer
	local win: CanvasGroup = New("CanvasGroup", {
		Name = id,
		Size = UDim2.fromOffset(w, h),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Color.Surface0,
		BackgroundTransparency = Theme.Transparency.Window,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
		Parent = windowLayer,
	})
	C.corner(win, Theme.Radius.Large)
	C.stroke(win, 0.85)
	New("UIScale", { Name = "OpenScale", Parent = win })
	New("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)),
		Parent = win,
	})

	-- header
	local header = C.frame({ Parent = win, Name = "Header", Size = UDim2.new(1, 0, 0, 58) })
	C.padding(header, 0, 16, 0, 18)
	if def.Icon then
		C.iconBadge({ Parent = header, Icon = def.Icon, Color = Theme.Color.Accent, Size = 32, Position = UDim2.new(0, 0, 0.5, -16) })
	end
	C.label({
		Parent = header,
		Text = def.Title,
		Font = Theme.Font.Heavy,
		TextSize = Theme.TextSize.Title,
		Size = UDim2.new(1, -100, 1, 0),
		Position = UDim2.fromOffset(if def.Icon then 42 else 0, 0),
	})
	C.iconButton({
		Parent = header,
		Icon = "close",
		Size = 34,
		IconScale = 0.4,
		Position = UDim2.new(1, -34, 0.5, -17),
		Color = Theme.Color.Surface2,
		Transparency = 0.2,
		Stroke = false,
		OnClick = function()
			UIController.close()
		end,
	})
	C.divider(win).Position = UDim2.fromOffset(0, 58)

	local body = C.frame({ Parent = win, Name = "Body", Size = UDim2.new(1, 0, 1, -59), Position = UDim2.fromOffset(0, 59), Clip = true })
	C.padding(body, 14, 18, 16, 18)
	local ok, err = pcall(def.Build, body, {
		close = function()
			UIController.close()
		end,
		window = win,
	})
	if not ok then
		warn(`[UI] window {id} failed to build: {err}`)
		C.empty(body, "This screen failed to load.")
	end
	rec.built = true
	rec.frame = win
	return win
end

function UIController.registerWindow(id: string, def: WindowDef)
	windows[id] = { def = def, frame = nil, built = false }
	local btn = railButtons[id]
	if btn and btn.Parent then
		(btn.Parent :: Frame).Visible = true
	end
end

function UIController.isOpen(id: string): boolean
	return openId == id
end

function UIController.close()
	local id = openId
	if not id then
		return
	end
	openId = nil
	local rec = windows[id]
	local win = rec and rec.frame
	if win then
		local sc = win:FindFirstChild("OpenScale") :: UIScale?
		if sc then
			C.tween(sc, Theme.Tween.Fast, { Scale = 0.95 })
		end
		C.tween(win, Theme.Tween.Fast, { GroupTransparency = 1 })
		task.delay(0.12, function()
			if openId ~= id then
				win.Visible = false
			end
		end)
	end
	C.tween(dim, Theme.Tween.Base, { BackgroundTransparency = 1 })
	C.tween(blur, Theme.Tween.Base, { Size = 0 })
	task.delay(0.2, function()
		if not openId then
			dim.Visible = false
		end
	end)
	State.set("Window", nil)
	if rec and rec.def.OnClose then
		task.spawn(rec.def.OnClose)
	end
	UIController.WindowClosed:Fire(id)
end

function UIController.open(id: string)
	local rec = windows[id]
	if not rec then
		return
	end
	if openId == id then
		return
	end
	if openId then
		UIController.close()
	end
	local win = rec.frame or buildWindow(id, rec)
	openId = id
	win.Visible = true
	win.GroupTransparency = 1
	C.tween(win, Theme.Tween.Base, { GroupTransparency = 0 })
	local sc = win:FindFirstChild("OpenScale") :: UIScale?
	if sc then
		sc.Scale = 0.94
		C.tween(sc, Theme.Tween.Base, { Scale = 1 })
	end
	dim.Visible = true
	C.tween(dim, Theme.Tween.Base, { BackgroundTransparency = Theme.Transparency.Dim })
	local data = DataController.data
	if not data.Settings.ReducedEffects then
		C.tween(blur, Theme.Tween.Base, { Size = 10 })
	end
	State.set("Window", id)
	if rec.def.OnOpen then
		task.spawn(rec.def.OnOpen)
	end
	UIController.WindowOpened:Fire(id)
end

function UIController.toggle(id: string)
	if openId == id then
		UIController.close()
	else
		UIController.open(id)
	end
end

function UIController.setBadge(id: string, count: number)
	local b = badges[id]
	if not b then
		return
	end
	b.Visible = count > 0
	local label = b:FindFirstChild("Count") :: TextLabel?
	if label then
		label.Text = if count > 9 then "9+" else tostring(count)
	end
end

-- Stacked HUD hiding (photo mode, cinematics, minigame focus).
function UIController.hide(key: string)
	hideKeys[key] = true
	root.Visible = false
end

function UIController.unhide(key: string)
	hideKeys[key] = nil
	root.Visible = next(hideKeys) == nil
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function UIController.Init()
	gui = New("ScreenGui", {
		Name = "Ironhaven",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = 5,
	})
	UIController.screenGui = gui

	root = C.frame({ Parent = gui, Name = "Root", Size = UDim2.fromScale(1, 1) })
	uiScale = New("UIScale", { Parent = gui })
	C.padding(root, 12, 14, 12, 14)

	blur = New("BlurEffect", { Name = "IronhavenUIBlur", Size = 0, Parent = Lighting })

	-- HUD slots (sizes are in pre-scale pixels)
	local topLeft = slot("TopLeft", { Size = UDim2.fromOffset(300, 70) })
	local topRight = slot("TopRight", { Size = UDim2.fromOffset(460, 40), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0) })
	slot("Top", { Size = UDim2.fromOffset(420, 90), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0) })
	local left = slot("Left", { Size = UDim2.fromOffset(60, 560), Position = UDim2.fromScale(0, 0.52), AnchorPoint = Vector2.new(0, 0.5) })
	slot("Right", { Size = UDim2.fromOffset(280, 360), Position = UDim2.new(1, 0, 0, 56), AnchorPoint = Vector2.new(1, 0) })
	local bottom = slot("Bottom", { Size = UDim2.fromOffset(300, 30), Position = UDim2.fromScale(0.5, 1), AnchorPoint = Vector2.new(0.5, 1) })
	local stack = slot("BottomStack", { Size = UDim2.fromOffset(560, 320), Position = UDim2.new(0.5, 0, 1, -40), AnchorPoint = Vector2.new(0.5, 1) })
	C.list(stack, "V", 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)

	buildProfile(topLeft)
	buildCurrencies(topRight)
	buildRail(left)
	buildEnergy(bottom)

	-- window layer + dim (tap outside to close)
	dim = New("TextButton", {
		Name = "Dim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Color.Backdrop,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 80),
		Position = UDim2.fromOffset(0, -60),
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	dim.Activated:Connect(function()
		UIController.close()
	end)
	windowLayer = C.frame({ Parent = gui, Name = "Windows", Size = UDim2.fromScale(1, 1), ZIndex = 21 })

	local overlay = C.frame({ Parent = gui, Name = "Overlay", Size = UDim2.fromScale(1, 1), ZIndex = 40 })
	UIController.hud.Overlay = overlay

	gui.Parent = player:WaitForChild("PlayerGui")

	local cam = Workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local c = Workspace.CurrentCamera
		if c then
			c:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
			updateScale()
		end
	end)
	updateScale()

	-- keyboard: Escape-like close on B (gamepad) / Backspace
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if openId and (input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Backspace) then
			UIController.close()
		end
	end)
	GuiService.AutoSelectGuiEnabled = true
end

return UIController
