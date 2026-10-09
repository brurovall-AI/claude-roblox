--!strict
--[[
	BoostController: active boost chips on the HUD + quick "Drink" popover.

	A second row under the currency pills (UIController.hud.TopRight):
	  [● Protein Shake 7:42] [● Focus Shot 2:05] [boost icon + bag count]
	Chips count down against the server clock (Workspace:GetServerTimeNow(),
	since expiries are server os.time values) and open the Juice Bar on click.
	With more than three active boosts the chips drop their names to stay compact.
	The bag button opens a small popover listing owned boosts with a Drink
	button each (Boost.Use). The popover lives in the Overlay layer so it draws
	above other HUD widgets; it closes on outside clicks, when a window opens or
	when the HUD is hidden.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosts = require(Shared.Config.Boosts)
local Format = require(Shared.Util.Format)
local Trove = require(Shared.Util.Trove)

local UI = script.Parent.Parent.UI
local C = require(UI.Components)
local Icons = require(UI.Icons)
local New = require(UI.Create)
local Theme = require(UI.Theme)
local Kit = require(UI.Windows.ShopKit)

local DataController = require(script.Parent.DataController)
local ShopController = require(script.Parent.ShopController)
local UIController = require(script.Parent.UIController)

local BoostController = {}

local ROW_Y = 44 -- below the 36px currency row
local COMPACT_AFTER = 3

type Chip = { frame: TextButton, name: TextLabel, timer: TextLabel, shown: string }

local row: Frame
local bagButton: TextButton
local bagCount: TextLabel
local bagBadge: Frame
local chips: { [string]: Chip } = {}
local popover: Frame? = nil
local popoverTrove = Trove.new()

local function now(): number
	return Workspace:GetServerTimeNow()
end

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

---------------------------------------------------------------------------
-- Chips
---------------------------------------------------------------------------
local function makeChip(def: Boosts.BoostDef): Chip
	local b: TextButton = New("TextButton", {
		Name = def.Id,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		BackgroundColor3 = Theme.Color.Surface0,
		BackgroundTransparency = Theme.Transparency.Hud,
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = def.Order,
	})
	C.corner(b, Theme.Radius.Pill)
	C.stroke(b)
	C.padding(b, 0, 10, 0, 9)
	C.list(b, "H", 6, nil, Enum.VerticalAlignment.Center)
	local dot = C.frame({ Parent = b, LayoutOrder = 1, Size = UDim2.fromOffset(9, 9), Color = def.Color, Transparency = 0, Radius = Theme.Radius.Pill })
	C.stroke(dot, 0.55, def.Color, 2.5)
	local name = C.label({ Parent = b, LayoutOrder = 2, Text = def.Name, Font = Theme.Font.SemiBold, TextSize = Theme.TextSize.Caption, Size = UDim2.new(0, 0, 1, 0), AutoSize = Enum.AutomaticSize.X })
	local timer = C.label({ Parent = b, LayoutOrder = 3, Text = "", Font = Theme.Font.Bold, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextDim, XAlign = Enum.TextXAlignment.Right, Size = UDim2.new(0, 34, 1, 0) })
	b.MouseEnter:Connect(function()
		C.tween(b, Theme.Tween.Fast, { BackgroundColor3 = Theme.Color.Surface2 })
	end)
	b.MouseLeave:Connect(function()
		C.tween(b, Theme.Tween.Fast, { BackgroundColor3 = Theme.Color.Surface0 })
	end)
	b.Activated:Connect(function()
		Kit.click()
		ShopController.open("JuiceBar")
	end)
	b.Parent = row
	return { frame = b, name = name, timer = timer, shown = "" }
end

local function tick()
	local t = now()
	local active = 0
	for id, chip in chips do
		local expiry = DataController.data.Boosts[id]
		local left = if expiry then expiry - t else 0
		if left > 0 then
			active += 1
			local text = Format.clock(left)
			if text ~= chip.shown then
				chip.shown = text
				chip.timer.Text = text
				-- last minute: warm the timer as a nudge
				chip.timer.TextColor3 = if left <= 60 then Theme.Color.Warning else Theme.Color.TextDim
			end
		end
		chip.frame.Visible = left > 0
	end
	local compact = active > COMPACT_AFTER
	for _, chip in chips do
		chip.name.Visible = not compact
	end
end

local function syncChips()
	local data = DataController.data
	local t = now()
	for id, chip in chips do
		local expiry = data.Boosts[id]
		if not expiry or expiry <= t then
			chip.frame:Destroy()
			chips[id] = nil
		end
	end
	for id, expiry in data.Boosts do
		local def = Boosts.Defs[id]
		if def and type(expiry) == "number" and expiry > t and not chips[id] then
			chips[id] = makeChip(def)
		end
	end
	tick()
end

---------------------------------------------------------------------------
-- Bag popover
---------------------------------------------------------------------------
local function closePopover()
	popoverTrove:Clean()
	popover = nil
end

local function bagTotal(): number
	local n = 0
	for id, count in DataController.data.BoostInventory do
		if Boosts.Defs[id] then
			n += count
		end
	end
	return n
end

local function fillPopover(panel: Frame)
	for _, child in panel:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	C.label({ Parent = panel, LayoutOrder = 0, Text = "YOUR BAG", Font = Theme.Font.Heavy, TextSize = Theme.TextSize.Micro, Color = Theme.Color.TextMute, Size = UDim2.new(1, 0, 0, 16) })
	local list = table.clone(Boosts.List)
	table.sort(list, function(a: Boosts.BoostDef, b: Boosts.BoostDef)
		return a.Order < b.Order
	end)
	local any = false
	for _, def in list do
		local have = DataController.data.BoostInventory[def.Id] or 0
		if have > 0 then
			any = true
			local r = C.frame({ Parent = panel, LayoutOrder = def.Order, Size = UDim2.new(1, 0, 0, 40) })
			C.frame({ Parent = r, Size = UDim2.fromOffset(9, 9), Position = UDim2.new(0, 2, 0.5, -4), Color = def.Color, Transparency = 0, Radius = Theme.Radius.Pill })
			C.label({ Parent = r, Text = def.Name, Font = Theme.Font.Bold, TextSize = Theme.TextSize.Caption, Size = UDim2.new(1, -110, 0, 18), Position = UDim2.fromOffset(18, 3) })
			C.label({ Parent = r, Text = `×{have} · {def.Description}`, TextSize = Theme.TextSize.Micro, Color = Theme.Color.TextDim, Size = UDim2.new(1, -110, 0, 16), Position = UDim2.fromOffset(18, 21) })
			local action = Kit.action({ Parent = r, Text = "Drink", Style = "Success", Size = UDim2.fromOffset(78, 34), Position = UDim2.new(1, 0, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5) })
			action.set({
				Text = "Drink",
				Style = "Success",
				Run = function()
					action.send("Boost.Use", { Id = def.Id }, { FailTitle = "Can't drink that yet" })
				end,
			})
		end
	end
	if not any then
		C.label({ Parent = panel, LayoutOrder = 99, Text = "Your bag is empty.", TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextDim, Size = UDim2.new(1, 0, 0, 22) })
	end
	C.button({ Parent = panel, LayoutOrder = 100, Text = "Juice Bar", Icon = "shop", IconSize = 14, Style = "Ghost", TextSize = Theme.TextSize.Caption, Size = UDim2.new(1, 0, 0, 34), OnClick = function()
		closePopover()
		ShopController.open("JuiceBar")
	end })
end

local function openPopover()
	closePopover()
	local overlay = UIController.hud.Overlay
	if not overlay then
		return
	end
	local scale = scaleOf(overlay)
	local abs = bagButton.AbsolutePosition + bagButton.AbsoluteSize - overlay.AbsolutePosition
	local panel = C.frame({
		Parent = overlay,
		Name = "BoostBag",
		Size = UDim2.fromOffset(268, 0),
		AutoSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(abs.X / scale, abs.Y / scale + 8),
		AnchorPoint = Vector2.new(1, 0),
		Color = Theme.Color.Surface0,
		Transparency = Theme.Transparency.Window,
		Radius = Theme.Radius.Large,
	})
	C.stroke(panel, 0.85)
	C.padding(panel, 10, 12, 10, 12)
	C.list(panel, "V", 4)
	local uiScale = New("UIScale", { Scale = 0.94, Parent = panel })
	C.tween(uiScale, Theme.Tween.Base, { Scale = 1 })
	popover = panel
	popoverTrove:Add(panel)
	fillPopover(panel)
	popoverTrove:Add(Kit.watch({ "BoostInventory" }, function()
		if popover == panel then
			fillPopover(panel)
		end
	end))
	popoverTrove:Connect(UserInputService.InputBegan, function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local p = Vector2.new(input.Position.X, input.Position.Y)
		local function inside(g: GuiObject): boolean
			local a, s = g.AbsolutePosition, g.AbsoluteSize
			return p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
		end
		-- InputObject.Position and AbsolutePosition share the inset-relative GUI space
		if not inside(panel) and not inside(bagButton) then
			closePopover()
		end
	end)
	popoverTrove:Add(UIController.WindowOpened:Connect(function()
		closePopover()
	end))
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function buildBag()
	bagButton = New("TextButton", {
		Name = "Bag",
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		BackgroundColor3 = Theme.Color.Surface0,
		BackgroundTransparency = Theme.Transparency.Hud,
		Size = UDim2.fromOffset(28, 28),
		LayoutOrder = 1000,
		Visible = false,
		Parent = row,
	})
	C.corner(bagButton, Theme.Radius.Pill)
	C.stroke(bagButton)
	local icon = Icons.make("boost", 15, Theme.Color.Accent)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Parent = bagButton
	bagBadge = C.frame({ Parent = bagButton, Name = "Count", Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -9, 0, -6), Color = Theme.Color.Accent, Transparency = 0, Radius = Theme.Radius.Pill })
	bagCount = C.label({ Parent = bagBadge, Text = "0", Font = Theme.Font.Heavy, TextSize = Theme.TextSize.Micro - 1, Color = Theme.Color.AccentText, XAlign = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
	local scale = New("UIScale", { Parent = bagButton })
	bagButton.MouseEnter:Connect(function()
		C.tween(bagButton, Theme.Tween.Fast, { BackgroundColor3 = Theme.Color.Surface2 })
		C.tween(scale, Theme.Tween.Fast, { Scale = 1.06 })
	end)
	bagButton.MouseLeave:Connect(function()
		C.tween(bagButton, Theme.Tween.Fast, { BackgroundColor3 = Theme.Color.Surface0 })
		C.tween(scale, Theme.Tween.Fast, { Scale = 1 })
	end)
	bagButton.Activated:Connect(function()
		Kit.click()
		if popover then
			closePopover()
		else
			openPopover()
		end
	end)
end

local function syncBag()
	local n = bagTotal()
	bagButton.Visible = n > 0
	bagCount.Text = if n > 9 then "9+" else tostring(n)
	bagBadge.Size = UDim2.fromOffset(if n > 9 then 20 else 16, 16)
	if n == 0 and popover then
		closePopover()
	end
end

function BoostController.Start()
	DataController.ready()
	local topRight = UIController.hud.TopRight
	if not topRight then
		return
	end
	row = C.frame({ Parent = topRight, Name = "Boosts", Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, ROW_Y) })
	C.list(row, "H", 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	buildBag()

	DataController.observe("Boosts", syncChips)
	DataController.observe("BoostInventory", syncBag)

	-- HUD hidden (photo mode / cinematics): drop the popover with it
	local root = topRight.Parent
	if root and root:IsA("GuiObject") then
		(root :: GuiObject):GetPropertyChangedSignal("Visible"):Connect(function()
			if not (root :: GuiObject).Visible then
				closePopover()
			end
		end)
	end

	while true do
		task.wait(0.5)
		tick()
	end
end

return BoostController
