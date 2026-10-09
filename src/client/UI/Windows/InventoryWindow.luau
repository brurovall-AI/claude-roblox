--!strict
--[[
	InventoryWindow: body of the "Inventory" window (rail label "Gear"),
	registered by InventoryController.

		local inv = InventoryWindow.build(body, { openShop = function(tab) end })
		inv.select("Companions")   -- Gear | Companions | Auras | Titles | Emotes | Decor

	Top: "Your bonuses" strip, total gain multiplier per stat from the player
	attribute "Multipliers" (JSON published by MultiplierService every ~3 s).
	Gear tab: five slot tiles (equipped item per slot) + the owned items for the
	selected slot. Other tabs: owned items with Equip / Unequip and the slot
	limits (companion slots, emote wheel, locker). Empty states link to the Shop.

	Owned grids rebuild only when the owned set changes; otherwise cards repaint.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local Companions = require(Config.Companions)
local Cosmetics = require(Config.Cosmetics)
local Format = require(Shared.Util.Format)
local Gear = require(Config.Gear)
local Stats = require(Config.Stats)
local Tiers = require(Config.Tiers)

local UI = script.Parent.Parent
local C = require(UI.Components)
local Icons = require(UI.Icons)
local Theme = require(UI.Theme)
local Kit = require(script.Parent.ShopKit)

local DataController = require(UI.Parent.Controllers.DataController)

local player = Players.LocalPlayer

local InventoryWindow = {}

export type Api = { select: (tab: string) -> (), current: () -> string }
export type Options = { openShop: (tab: string) -> () }

type Refresher = () -> ()

local TABS = {
	{ Id = "Gear", Label = "Gear" },
	{ Id = "Companions", Label = "Companions" },
	{ Id = "Auras", Label = "Auras" },
	{ Id = "Titles", Label = "Titles" },
	{ Id = "Emotes", Label = "Emotes" },
	{ Id = "Decor", Label = "Decor" },
}

local SLOT_LABEL: { [string]: string } = { Gloves = "Gloves", Shoes = "Trainers", Belt = "Belt", Wraps = "Wraps", Headband = "Headband" }
local EMOTE_COLOR = Color3.fromRGB(240, 146, 60)
local DECOR_COLOR = Color3.fromRGB(196, 160, 90)
local CARD_W = 180

-- One owned item as shown in a grid.
type Entry = {
	Id: string,
	Category: string, -- Inventory.Equip category
	Order: number,
	Accent: Color3,
	Fill: (card: Kit.Card) -> (), -- card body content
}

local function centred(parent: Instance, order: number, text: string, props: { [string]: any }?): TextLabel
	local p: { [string]: any } = props or {}
	return C.label({
		Parent = parent,
		LayoutOrder = order,
		Text = text,
		Font = p.Font or Theme.Font.Bold,
		TextSize = p.TextSize or Theme.TextSize.Body,
		Color = p.Color or Theme.Color.Text,
		XAlign = Enum.TextXAlignment.Center,
		YAlign = p.YAlign,
		Wrap = p.Wrap,
		Size = UDim2.new(1, 0, 0, p.Height or ((p.TextSize or Theme.TextSize.Body) + 5)),
	})
end

local function caption(parent: Instance, order: number, text: string, color: Color3?)
	centred(parent, order, text, { Font = Theme.Font.SemiBold, TextSize = Theme.TextSize.Caption, Color = color or Theme.Color.TextDim })
end

local function isEquipped(category: string, id: string): boolean
	local eq = DataController.data.Equipped
	if category == "Gear" then
		local def = Gear.get(id)
		return def ~= nil and eq.Gear[def.Slot] == id
	elseif category == "Companion" then
		return table.find(eq.Companions, id) ~= nil
	elseif category == "Aura" then
		return eq.Aura == id
	elseif category == "Title" then
		return eq.Title == id
	elseif category == "Emote" then
		return table.find(eq.Emotes, id) ~= nil
	end
	return table.find(eq.Decor, id) ~= nil
end

---------------------------------------------------------------------------
-- Entries per category (owned items only)
---------------------------------------------------------------------------
local function gearEntry(def: Gear.GearDef): Entry
	local tier = Tiers.get(def.Tier)
	return {
		Id = def.Id,
		Category = "Gear",
		Order = def.Tier,
		Accent = tier.Color,
		Fill = function(card: Kit.Card)
			local kick = Kit.row(card.Body, 20, 1)
			C.pill({ Parent = kick, Text = `T{def.Tier} · {string.upper(tier.Name)}`, Color = tier.Color, Height = 20 })
			Kit.art(card.Body, Kit.gearGlyph(def.Slot, def.Primary, def.Secondary, def.Tier, 64), 74, 2)
			centred(card.Body, 3, def.Name)
			local stat = Stats.Defs[def.Stat :: Stats.StatId]
			caption(card.Body, 4, `{Format.percentBonus(def.Mult)} {def.Stat}`, if stat then stat.Color else nil)
		end,
	}
end

local function ownedEntries(tab: string, slot: string?): { Entry }
	local data = DataController.data
	local out: { Entry } = {}
	if tab == "Gear" then
		for _, def in Gear.BySlot[(slot or "Gloves") :: Gear.GearSlot] do
			if data.Owned.Gear[def.Id] then
				table.insert(out, gearEntry(def))
			end
		end
	elseif tab == "Companions" then
		for _, def in Companions.List do
			if data.Owned.Companions[def.Id] then
				local color = (Companions.RarityColor :: any)[def.Rarity] :: Color3
				table.insert(out, {
					Id = def.Id,
					Category = "Companion",
					Order = def.Order,
					Accent = color,
					Fill = function(card: Kit.Card)
						local kick = Kit.row(card.Body, 20, 1)
						C.pill({ Parent = kick, Text = string.upper(def.Rarity), Color = color, Height = 20 })
						Kit.art(card.Body, Kit.disc("companion", color, 58), 68, 2)
						centred(card.Body, 3, def.Name)
						local stat = Stats.Defs[def.Stat :: Stats.StatId]
						caption(card.Body, 4, `{Format.percentBonus(1 + def.Bonus)} {if def.Stat == "All" then "all stats" else def.Stat}`, if stat then stat.Color else Theme.Color.Accent)
					end,
				})
			end
		end
	elseif tab == "Auras" then
		for _, d in Cosmetics.AuraList do
			if data.Owned.Auras[d.Id] then
				table.insert(out, {
					Id = d.Id,
					Category = "Aura",
					Order = d.Order,
					Accent = Kit.AuraColor[d.Effect] or Theme.Color.Accent,
					Fill = function(card: Kit.Card)
						Kit.art(card.Body, Kit.auraGlyph(d.Effect, 66), 90, 1)
						centred(card.Body, 2, d.Name)
						centred(card.Body, 3, d.Description, { Font = Theme.Font.Regular, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextDim, Wrap = true, Height = 32, YAlign = Enum.TextYAlignment.Top })
					end,
				})
			end
		end
	elseif tab == "Titles" then
		for _, d in Cosmetics.TitleList do
			if data.Owned.Titles[d.Id] then
				table.insert(out, {
					Id = d.Id,
					Category = "Title",
					Order = d.Order,
					Accent = d.Color,
					Fill = function(card: Kit.Card)
						Kit.art(card.Body, Kit.titlePlate(d.Text, d.Color, 146), 90, 1)
						centred(card.Body, 2, d.Text)
						caption(card.Body, 3, Kit.SourceText[d.Source] or "Title")
					end,
				})
			end
		end
	elseif tab == "Emotes" then
		for _, d in Cosmetics.EmoteList do
			if data.Owned.Emotes[d.Id] then
				table.insert(out, {
					Id = d.Id,
					Category = "Emote",
					Order = d.Order,
					Accent = EMOTE_COLOR,
					Fill = function(card: Kit.Card)
						Kit.art(card.Body, Kit.disc("emote", EMOTE_COLOR, 58), 90, 1)
						centred(card.Body, 2, d.Name)
						caption(card.Body, 3, if d.Loop then "Looping emote" else "Pose")
					end,
				})
			end
		end
	else
		for _, d in Cosmetics.DecorList do
			if data.Owned.Decor[d.Id] then
				local icon = if d.Visual == "Cup" or d.Visual == "Medals" then "trophy" else "star"
				table.insert(out, {
					Id = d.Id,
					Category = "Decor",
					Order = d.Order,
					Accent = DECOR_COLOR,
					Fill = function(card: Kit.Card)
						Kit.art(card.Body, Kit.disc(icon, DECOR_COLOR, 58), 90, 1)
						centred(card.Body, 2, d.Name)
						caption(card.Body, 3, "Locker decoration")
					end,
				})
			end
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Owned grid with Equip / Unequip, rebuilt when the owned set changes
---------------------------------------------------------------------------
type OwnedGrid = { refresh: () -> () }
type GridSpec = {
	Parent: Frame,
	Tab: string,
	Slot: (() -> string)?,
	Empty: { Title: string, Text: string, Icon: string, Action: string, ShopTab: string },
	Options: Options,
}

local function ownedGrid(spec: GridSpec): OwnedGrid
	local holder = spec.Parent
	local grid = Kit.grid(holder, { MinWidth = CARD_W, Height = 216 })
	local empty: Frame? = nil
	local signature = "?"
	local cardRefreshers: { Refresher } = {}

	local function rebuild(entries: { Entry })
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(cardRefreshers)
		for _, e in entries do
			local card = Kit.card(grid, { Accent = e.Accent, Order = e.Order, Name = e.Id })
			e.Fill(card)
			local action = Kit.action({ Parent = card.Footer, Text = "Equip", Style = "Primary" })
			table.insert(cardRefreshers, function()
				local on = isEquipped(e.Category, e.Id)
				card.setHighlight(on)
				card.setBadge(if on then "EQUIPPED" else nil, Theme.Color.Success)
				if on then
					action.set({
						Text = "Unequip",
						Style = "Secondary",
						Run = function()
							action.send("Inventory.Unequip", { Category = e.Category, Id = e.Id }, { Sound = "UIClick", FailTitle = "Can't unequip that" })
						end,
					})
				else
					action.set({
						Text = "Equip",
						Style = "Primary",
						Run = function()
							action.send("Inventory.Equip", { Category = e.Category, Id = e.Id }, { Sound = "UIClick", FailTitle = "Can't equip that" })
						end,
					})
				end
			end)
		end
		if empty then
			empty:Destroy()
			empty = nil
		end
		grid.Visible = #entries > 0
		if #entries == 0 then
			local es = spec.Empty
			empty = Kit.emptyState(holder, {
				Title = es.Title,
				Text = es.Text,
				Icon = es.Icon,
				Color = Theme.Color.Accent,
				Action = es.Action,
				OnAction = function()
					spec.Options.openShop(es.ShopTab)
				end,
			})
		end
	end

	return {
		refresh = function()
			local slot = if spec.Slot then (spec.Slot :: () -> string)() else nil
			local entries = ownedEntries(spec.Tab, slot)
			table.sort(entries, function(a: Entry, b: Entry)
				return a.Order < b.Order
			end)
			local ids = {}
			for _, e in entries do
				table.insert(ids, e.Id)
			end
			local sig = (slot or "") .. "|" .. table.concat(ids, ",")
			if sig ~= signature then
				signature = sig
				rebuild(entries)
			end
			for _, fn in cardRefreshers do
				fn()
			end
		end,
	}
end

---------------------------------------------------------------------------
-- Bonus summary strip
---------------------------------------------------------------------------
local function summary(parent: Instance): Frame
	local strip = C.frame({ Parent = parent, Name = "Bonuses", Size = UDim2.new(1, 0, 0, 56), Color = Theme.Color.Surface1, Transparency = 0, Radius = Theme.Radius.Large })
	C.stroke(strip, 0.9)
	C.padding(strip, 8, 12, 8, 14)
	local head = C.frame({ Parent = strip, Size = UDim2.new(0, 104, 1, 0) })
	C.label({ Parent = head, Text = "YOUR BONUSES", Font = Theme.Font.Heavy, TextSize = Theme.TextSize.Micro, Color = Theme.Color.TextMute, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 4) })
	C.label({ Parent = head, Text = "All sources", TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextDim, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 20) })
	local cells = C.frame({ Parent = strip, Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(110, 0) })
	C.list(cells, "H", 6, nil, Enum.VerticalAlignment.Center)
	local values: { [string]: TextLabel } = {}
	for i, id in Stats.Order do
		local def = Stats.Defs[id]
		local cell = C.frame({ Parent = cells, LayoutOrder = i, Size = UDim2.new(0.2, -5, 1, 0), Color = Theme.Color.Surface2, Transparency = 0.4, Radius = Theme.Radius.Medium })
		C.frame({ Parent = cell, Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 10, 0.5, -4), Color = def.Color, Transparency = 0, Radius = Theme.Radius.Pill })
		C.label({ Parent = cell, Text = def.Short, Font = Theme.Font.Bold, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextDim, Size = UDim2.new(0, 34, 1, 0), Position = UDim2.fromOffset(24, 0) })
		values[id] = C.label({
			Parent = cell,
			Text = "×1.00",
			Font = Theme.Font.Heavy,
			TextSize = Theme.TextSize.Body,
			XAlign = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, -60, 1, 0),
			Position = UDim2.new(1, -10, 0, 0),
			AnchorPoint = Vector2.new(1, 0),
		})
	end
	local function refresh()
		local raw = player:GetAttribute("Multipliers")
		local parsed: { [string]: any } = {}
		if type(raw) == "string" then
			local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
			if ok and type(decoded) == "table" then
				parsed = decoded
			end
		end
		for id, label in values do
			local v = parsed[id]
			local m = if type(v) == "number" then v else 1
			label.Text = string.format("×%.2f", m)
			label.TextColor3 = if m > 1.0001 then Theme.Color.Text else Theme.Color.TextMute
		end
	end
	player:GetAttributeChangedSignal("Multipliers"):Connect(refresh)
	refresh()
	return strip
end

---------------------------------------------------------------------------
-- Gear tab: slot tiles + owned list
---------------------------------------------------------------------------
local function slotTile(parent: Instance, slot: string, order: number, onClick: () -> ()): (TextButton, (selected: boolean) -> ())
	local tile: TextButton = Instance.new("TextButton")
	tile.Name = slot
	tile.AutoButtonColor = false
	tile.Text = ""
	tile.BorderSizePixel = 0
	tile.BackgroundColor3 = Theme.Color.Surface1
	tile.Size = UDim2.new(0.2, -7, 1, 0)
	tile.LayoutOrder = order
	C.corner(tile, Theme.Radius.Large)
	local stroke = C.stroke(tile, 0.9)
	C.label({ Parent = tile, Text = string.upper(SLOT_LABEL[slot] or slot), Font = Theme.Font.Heavy, TextSize = Theme.TextSize.Micro, Color = Theme.Color.TextMute, XAlign = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 8) })
	local art = C.frame({ Parent = tile, Name = "Art", Size = UDim2.fromOffset(48, 48), Position = UDim2.new(0.5, 0, 0, 26), AnchorPoint = Vector2.new(0.5, 0) })
	local name = C.label({ Parent = tile, Text = "Empty", Font = Theme.Font.Bold, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextMute, XAlign = Enum.TextXAlignment.Center, Size = UDim2.new(1, -8, 0, 16), Position = UDim2.new(0, 4, 1, -22) })
	local bar = C.frame({ Parent = tile, Name = "Bar", Size = UDim2.new(0.4, 0, 0, 3), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0), Color = Theme.Color.Surface3, Transparency = 0, Radius = Theme.Radius.Pill })
	tile.Parent = parent

	local selected = false
	local hovering = false
	local shownId: string? = "?"
	local function paint()
		C.tween(tile, Theme.Tween.Fast, { BackgroundColor3 = if selected then Theme.Color.Surface2 elseif hovering then Color3.fromHex("#23242A") else Theme.Color.Surface1 })
		stroke.Color = if selected then Theme.Color.Accent else Theme.Color.Stroke
		stroke.Transparency = if selected then 0.3 elseif hovering then 0.75 else 0.9
		local id = DataController.data.Equipped.Gear[slot]
		local def = if id then Gear.get(id) else nil
		local current = if def then def.Id else nil
		if current ~= shownId then
			shownId = current
			art:ClearAllChildren()
			if def then
				local g = Kit.gearGlyph(slot, def.Primary, def.Secondary, def.Tier, 48)
				g.Parent = art
				local tier = Tiers.get(def.Tier)
				name.Text = `T{def.Tier} {tier.Name}`
				name.TextColor3 = tier.Color
				bar.BackgroundColor3 = tier.Color
			else
				local plus = C.frame({ Parent = art, Size = UDim2.fromScale(1, 1), Color = Theme.Color.Surface2, Transparency = 0.3, Radius = Theme.Radius.Pill })
				local icon = Icons.make("plus", 20, Theme.Color.TextMute)
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Position = UDim2.fromScale(0.5, 0.5)
				icon.Parent = plus
				name.Text = "Empty"
				name.TextColor3 = Theme.Color.TextMute
				bar.BackgroundColor3 = Theme.Color.Surface3
			end
		end
	end
	tile.MouseEnter:Connect(function()
		hovering = true
		paint()
	end)
	tile.MouseLeave:Connect(function()
		hovering = false
		paint()
	end)
	tile.Activated:Connect(function()
		Kit.click()
		onClick()
	end)
	return tile, function(sel: boolean)
		selected = sel
		paint()
	end
end

local function buildGear(page: Frame, refreshers: { Refresher }, options: Options)
	local tiles = C.frame({ Parent = page, Name = "Slots", Size = UDim2.new(1, 0, 0, 100) })
	C.list(tiles, "H", 8)
	local headRow = C.frame({ Parent = page, Name = "Head", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 110) })
	local headLabel = C.label({ Parent = headRow, Font = Theme.Font.Heavy, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextMute, Size = UDim2.new(1, -150, 1, 0) })
	C.button({
		Parent = headRow,
		Text = "Pro Shop",
		Style = "Ghost",
		Icon = "shop",
		IconSize = 14,
		TextSize = Theme.TextSize.Caption,
		Size = UDim2.fromOffset(120, 30),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		OnClick = function()
			options.openShop("Gear")
		end,
	})
	local area = C.frame({ Parent = page, Name = "Area", Size = UDim2.new(1, 0, 1, -146), Position = UDim2.fromOffset(0, 146) })

	local selectedSlot = "Gloves"
	local setters: { [string]: (boolean) -> () } = {}
	local grid: OwnedGrid
	local function paintTiles()
		for slot, set in setters do
			set(slot == selectedSlot)
		end
		local info = (Gear.SlotInfo :: any)[selectedSlot]
		headLabel.Text = `OWNED {string.upper(info.Name)} · {string.upper(info.Stat)}`
	end
	for i, slot in Gear.Slots do
		local _, set = slotTile(tiles, slot, i, function()
			if selectedSlot ~= slot then
				selectedSlot = slot
				paintTiles()
				grid.refresh()
			end
		end)
		setters[slot] = set
	end
	grid = ownedGrid({
		Parent = area,
		Tab = "Gear",
		Slot = function()
			return selectedSlot
		end,
		Empty = { Title = "Nothing for this slot yet", Text = "Gear multiplies your gains. Pick some up at the Pro Shop.", Icon = "gear", Action = "Visit the Pro Shop", ShopTab = "Gear" },
		Options = options,
	})
	table.insert(refreshers, function()
		paintTiles()
		grid.refresh()
	end)
end

---------------------------------------------------------------------------
-- List tabs (companions + cosmetics)
---------------------------------------------------------------------------
type ListTab = { info: () -> string, empty: { Title: string, Text: string, Icon: string, Action: string, ShopTab: string } }

local LIST_TABS: { [string]: ListTab } = {
	Companions = {
		info = function()
			local data = DataController.data
			local max = Companions.slots(data.Rebirths)
			local extra = if max < 2 then " · second slot at Rebirth 2" else " · bonuses stack"
			return `EQUIPPED {#data.Equipped.Companions}/{max}{string.upper(extra)}`
		end,
		empty = { Title = "No companions yet", Text = "Companions follow you around and boost your gains.", Icon = "companion", Action = "Browse companions", ShopTab = "Companions" },
	},
	Auras = {
		info = function()
			return "ONE AURA AT A TIME · PURE STYLE"
		end,
		empty = { Title = "No auras yet", Text = "Auras are subtle effects around your character.", Icon = "star", Action = "Browse cosmetics", ShopTab = "Cosmetics" },
	},
	Titles = {
		info = function()
			return "SHOWN UNDER YOUR NAME"
		end,
		empty = { Title = "No titles yet", Text = "Earn titles from achievements, events and the shop.", Icon = "star", Action = "Browse cosmetics", ShopTab = "Cosmetics" },
	},
	Emotes = {
		info = function()
			return `EMOTE WHEEL {#DataController.data.Equipped.Emotes}/{Cosmetics.MaxEquippedEmotes}`
		end,
		empty = { Title = "No emotes yet", Text = "Show off between sets.", Icon = "emote", Action = "Browse cosmetics", ShopTab = "Cosmetics" },
	},
	Decor = {
		info = function()
			return `LOCKER {#DataController.data.Equipped.Decor}/{Cosmetics.MaxDecor}`
		end,
		empty = { Title = "No decorations yet", Text = "Decorate your locker in the Locker Rooms.", Icon = "star", Action = "Browse cosmetics", ShopTab = "Cosmetics" },
	},
}

local function buildList(page: Frame, tab: string, refreshers: { Refresher }, options: Options)
	local spec = LIST_TABS[tab]
	local info = C.label({ Parent = page, Font = Theme.Font.Heavy, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextMute, Size = UDim2.new(1, 0, 0, 24) })
	local area = C.frame({ Parent = page, Name = "Area", Size = UDim2.new(1, 0, 1, -32), Position = UDim2.fromOffset(0, 32) })
	local grid = ownedGrid({ Parent = area, Tab = tab, Empty = spec.empty, Options = options })
	table.insert(refreshers, function()
		info.Text = spec.info()
		grid.refresh()
	end)
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
function InventoryWindow.build(body: Frame, options: Options, initial: string?): Api
	summary(body)
	local pagesFrame = C.frame({ Parent = body, Name = "Pages", Size = UDim2.new(1, 0, 1, -114), Position = UDim2.fromOffset(0, 114) })
	local pages: { [string]: Frame } = {}
	local refreshersByTab: { [string]: { Refresher } } = {}
	local currentTab = ""

	local function show(id: string)
		local known = id == "Gear" or LIST_TABS[id] ~= nil
		if not known then
			return
		end
		currentTab = id
		if not pages[id] then
			local page = C.frame({ Parent = pagesFrame, Name = id, Size = UDim2.fromScale(1, 1) })
			local list: { Refresher } = {}
			pages[id] = page
			refreshersByTab[id] = list
			local ok, err = pcall(function()
				if id == "Gear" then
					buildGear(page, list, options)
				else
					buildList(page, id, list, options)
				end
			end)
			if not ok then
				warn(`[Inventory] tab {id} failed: {err}`)
				C.empty(page, "This section failed to load.")
			end
		end
		for pid, page in pages do
			page.Visible = pid == id
		end
		for _, fn in refreshersByTab[id] or {} do
			fn()
		end
	end

	local tabs = C.tabs({ Parent = body, Tabs = TABS, Position = UDim2.fromOffset(0, 68), OnSelect = show })

	-- repaint the visible tab on data changes; hidden tabs repaint when shown
	Kit.watch({ "Owned", "Equipped", "Rebirths" }, function()
		for _, fn in refreshersByTab[currentTab] or {} do
			fn()
		end
	end)

	tabs.select(if initial and (initial == "Gear" or LIST_TABS[initial]) then initial else "Gear")

	return {
		select = function(id: string)
			if id == "Gear" or LIST_TABS[id] then
				tabs.select(id)
			end
		end,
		current = function()
			return currentTab
		end,
	}
end

return InventoryWindow
