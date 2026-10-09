--!strict
--[[
	ShopWindow: body of the "Shop" window (registered by ShopController).

		local shop = ShopWindow.build(body, "Gear")
		shop.select("JuiceBar")      -- Gear | Companions | JuiceBar | Cosmetics | VIP

	Tabs
	  Gear        slot chips; six tier cards per slot (tier bar, bonus, price, level lock)
	  Companions  rarity cards with bonus, cost in its currency and description
	  Juice Bar   boosts priced by level: Buy / Buy & Drink (or Drink from the bag)
	  Cosmetics   Auras / Titles (nameplate preview) / Emotes / Decor
	  VIP         VIP Club trophy unlock, VIP pass, Robux extras ("Coming soon" when id = 0)

	Pages and grids are built lazily on first visit and only repainted afterwards
	(data replica / VIP attributes), so scroll position and hover survive purchases.
	Purchases go through ShopKit actions: button disabled while in flight, server
	toast on success + UIPurchase sound, error toast with the server's reason.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local Areas = require(Config.Areas)
local Boosts = require(Config.Boosts)
local Companions = require(Config.Companions)
local Cosmetics = require(Config.Cosmetics)
local Currency = require(Config.Currency)
local Format = require(Shared.Util.Format)
local Gear = require(Config.Gear)
local Monetization = require(Config.Monetization)
local Stats = require(Config.Stats)
local Tiers = require(Config.Tiers)

local UI = script.Parent.Parent
local C = require(UI.Components)
local Icons = require(UI.Icons)
local Theme = require(UI.Theme)
local Kit = require(script.Parent.ShopKit)

local DataController = require(UI.Parent.Controllers.DataController)

local player = Players.LocalPlayer

local ShopWindow = {}

export type Api = { select: (tab: string) -> (), current: () -> string }

type Refresher = () -> ()
type PageCtx = { refreshers: { Refresher }, tickers: { Refresher } }

local TABS = {
	{ Id = "Gear", Label = "Gear" },
	{ Id = "Companions", Label = "Companions" },
	{ Id = "JuiceBar", Label = "Juice Bar" },
	{ Id = "Cosmetics", Label = "Cosmetics" },
	{ Id = "VIP", Label = "VIP" },
}

local SLOT_LABEL: { [string]: string } = { Gloves = "Gloves", Shoes = "Trainers", Belt = "Belt", Wraps = "Wraps", Headband = "Headband" }
local VIP_GREEN = Color3.fromRGB(46, 160, 110)
local EMOTE_COLOR = Color3.fromRGB(240, 146, 60)
local DECOR_COLOR = Color3.fromRGB(196, 160, 90)

local DATA_KEYS = { "Cash", "Trophies", "RebirthTokens", "Level", "Rebirths", "Owned", "Equipped", "BoostInventory", "Boosts", "Unlocks" }

local CARD_W = 184 -- minimum card width (grids stretch to fill)

---------------------------------------------------------------------------
-- Shared card pieces
---------------------------------------------------------------------------
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

-- Standard footer: price tag on the left, action button on the right. When
-- `full` the button spans the footer (owned / equipped states).
type Footer = { price: Kit.PriceTag, action: Kit.Action, layout: (full: boolean) -> () }

local function footer(card: Kit.Card, buttonText: string): Footer
	local price = Kit.priceTag(card.Footer)
	local action = Kit.action({ Parent = card.Footer, Size = UDim2.new(0, 90, 1, 0), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), Text = buttonText, Style = "Primary" })
	local isFull: boolean? = nil
	return {
		price = price,
		action = action,
		layout = function(full: boolean)
			if isFull == full then
				return
			end
			isFull = full
			price.Frame.Visible = not full
			action.Button.Size = if full then UDim2.fromScale(1, 1) else UDim2.new(0, 90, 1, 0)
		end,
	}
end

-- Paints the shared owned / equipped / locked / for-sale states of a card.
type ItemState = {
	Owned: boolean,
	Equipped: boolean,
	LockText: string?, -- requirement not met (level / rebirth)
	Cost: Currency.Cost?, -- nil = not for sale
	Source: string?, -- where unsold items come from
	Buy: () -> (),
	Equip: () -> (),
}

local function paintItem(card: Kit.Card, f: Footer, s: ItemState)
	card.setHighlight(s.Equipped)
	card.setDimmed(not s.Owned and s.LockText ~= nil)
	if s.Equipped then
		card.setBadge("EQUIPPED", Theme.Color.Success)
		f.layout(true)
		f.action.set({ Text = "Equipped", Style = "Ghost", Disabled = true })
	elseif s.Owned then
		card.setBadge("OWNED", Theme.Color.TextDim)
		f.layout(true)
		f.action.set({ Text = "Equip", Style = "Secondary", Run = s.Equip })
	elseif s.LockText then
		card.setBadge(nil)
		f.layout(false)
		f.price.setNote(s.LockText, "lock")
		f.action.set({ Text = "Locked", Style = "Ghost", Disabled = true })
	elseif s.Cost then
		card.setBadge(nil)
		f.layout(false)
		local cost = s.Cost :: Currency.Cost
		local affordable = Kit.balance(cost.Currency) >= cost.Amount
		f.price.setPrice(cost.Currency, cost.Amount, affordable)
		-- unaffordable stays clickable: the server explains how much is missing
		f.action.set({ Text = "Buy", Style = if affordable then "Primary" else "Secondary", Run = s.Buy })
	else
		card.setBadge("EARNED", Theme.Color.Accent)
		f.layout(false)
		f.price.setNote(Kit.SourceText[s.Source or ""] or "Earned in game", "star", Theme.Color.Accent)
		f.action.set({ Text = "Locked", Style = "Ghost", Disabled = true })
	end
end

local function buyOpts(): Kit.RequestOpts
	return { FailTitle = "Can't buy that yet" }
end
local function equipOpts(): Kit.RequestOpts
	return { Sound = "UIClick", FailTitle = "Can't equip that" }
end

---------------------------------------------------------------------------
-- Gear
---------------------------------------------------------------------------
local function gearCard(grid: Instance, def: Gear.GearDef, ctx: PageCtx)
	local tier = Tiers.get(def.Tier)
	local stat = Stats.Defs[def.Stat :: Stats.StatId]
	local card = Kit.card(grid, { Accent = tier.Color, Order = def.Tier })
	local kick = Kit.row(card.Body, 20, 1)
	C.pill({ Parent = kick, Text = `T{def.Tier} · {string.upper(tier.Name)}`, Color = tier.Color, Height = 20 })
	Kit.art(card.Body, Kit.gearGlyph(def.Slot, def.Primary, def.Secondary, def.Tier, 68), 80, 2)
	centred(card.Body, 3, def.Name)
	centred(card.Body, 4, `{Format.percentBonus(def.Mult)} {def.Stat}`, { Font = Theme.Font.SemiBold, TextSize = Theme.TextSize.Caption, Color = if stat then stat.Color else Theme.Color.TextDim })
	local f = footer(card, "Buy")
	local function refresh()
		local data = DataController.data
		local owned = data.Owned.Gear[def.Id] == true
		paintItem(card, f, {
			Owned = owned,
			Equipped = owned and data.Equipped.Gear[def.Slot] == def.Id,
			LockText = if data.Level < def.LevelReq then `Level {def.LevelReq}` else nil,
			Cost = { Currency = "Cash", Amount = def.Price },
			Buy = function()
				f.action.send("Shop.Buy", { Category = "Gear", Id = def.Id }, buyOpts())
			end,
			Equip = function()
				f.action.send("Inventory.Equip", { Category = "Gear", Id = def.Id }, equipOpts())
			end,
		})
	end
	table.insert(ctx.refreshers, refresh)
	refresh()
end

local function buildGear(page: Frame, ctx: PageCtx)
	local top = C.frame({ Parent = page, Name = "Top", Size = UDim2.new(1, 0, 0, 34) })
	local hint = C.label({
		Parent = top,
		TextSize = Theme.TextSize.Caption,
		Color = Theme.Color.TextDim,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 230, 1, 0),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
	})
	local area = C.frame({ Parent = page, Name = "Area", Size = UDim2.new(1, 0, 1, -46), Position = UDim2.fromOffset(0, 46) })
	local grids: { [string]: GuiObject } = {}
	local items: { Kit.ChipItem } = {}
	for _, slot in Gear.Slots do
		local info = (Gear.SlotInfo :: any)[slot]
		local stat = Stats.Defs[info.Stat :: Stats.StatId]
		table.insert(items, { Id = slot, Label = SLOT_LABEL[slot] or slot, Color = if stat then stat.Color else nil })
	end
	local chips = Kit.chips(top, items, function(slot: string)
		if not grids[slot] then
			local grid = Kit.grid(area, { Name = slot, MinWidth = CARD_W, Height = 236 })
			grids[slot] = grid
			for _, def in Gear.BySlot[slot :: Gear.GearSlot] do
				gearCard(grid, def, ctx)
			end
		end
		for s, g in grids do
			g.Visible = s == slot
		end
		local info = (Gear.SlotInfo :: any)[slot]
		hint.Text = `{info.Name} boost {info.Stat} gains`
	end)
	Kit.autoHide(hint, chips.Frame)
	chips.select("Gloves")
end

---------------------------------------------------------------------------
-- Companions
---------------------------------------------------------------------------
local function companionCard(grid: Instance, def: Companions.CompanionDef, ctx: PageCtx)
	local color = (Companions.RarityColor :: any)[def.Rarity] :: Color3
	local card = Kit.card(grid, { Accent = color, Order = def.Order })
	local kick = Kit.row(card.Body, 20, 1)
	C.pill({ Parent = kick, Text = string.upper(def.Rarity), Color = color, Height = 20 })
	Kit.art(card.Body, Kit.disc("companion", color, 62), 70, 2)
	centred(card.Body, 3, def.Name)
	local statDef = Stats.Defs[def.Stat :: Stats.StatId]
	local bonusText = `{Format.percentBonus(1 + def.Bonus)} {if def.Stat == "All" then "all stats" else def.Stat}`
	centred(card.Body, 4, bonusText, { Font = Theme.Font.SemiBold, TextSize = Theme.TextSize.Caption, Color = if statDef then statDef.Color else Theme.Color.Accent })
	centred(card.Body, 5, def.Description, { Font = Theme.Font.Regular, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextDim, Wrap = true, Height = 34, YAlign = Enum.TextYAlignment.Top })
	local f = footer(card, "Buy")
	local function refresh()
		local data = DataController.data
		local owned = data.Owned.Companions[def.Id] == true
		local lock: string? = nil
		if data.Rebirths < def.RebirthReq then
			lock = `Rebirth {def.RebirthReq}`
		elseif data.Level < def.LevelReq then
			lock = `Level {def.LevelReq}`
		end
		paintItem(card, f, {
			Owned = owned,
			Equipped = owned and table.find(data.Equipped.Companions, def.Id) ~= nil,
			LockText = lock,
			Cost = def.Cost,
			Buy = function()
				f.action.send("Shop.Buy", { Category = "Companion", Id = def.Id }, buyOpts())
			end,
			Equip = function()
				f.action.send("Inventory.Equip", { Category = "Companion", Id = def.Id }, equipOpts())
			end,
		})
	end
	table.insert(ctx.refreshers, refresh)
	refresh()
end

local function buildCompanions(page: Frame, ctx: PageCtx)
	local top = C.frame({ Parent = page, Name = "Top", Size = UDim2.new(1, 0, 0, 34) })
	C.list(top, "H", 10, nil, Enum.VerticalAlignment.Center)
	local slotsHolder = C.frame({ Parent = top, Size = UDim2.fromOffset(0, 14), AutoSize = Enum.AutomaticSize.X, LayoutOrder = 1 })
	C.list(slotsHolder, "H", 5, nil, Enum.VerticalAlignment.Center)
	local info = C.label({ Parent = top, LayoutOrder = 2, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextDim, Size = UDim2.new(1, -80, 1, 0) })
	local grid = Kit.grid(page, { MinWidth = CARD_W + 10, Height = 270, Size = UDim2.new(1, 0, 1, -46), Position = UDim2.fromOffset(0, 46) })
	local list = table.clone(Companions.List)
	table.sort(list, function(a: Companions.CompanionDef, b: Companions.CompanionDef)
		return a.Order < b.Order
	end)
	for _, def in list do
		companionCard(grid, def, ctx)
	end
	local function refresh()
		local data = DataController.data
		local max = Companions.slots(data.Rebirths)
		local used = #data.Equipped.Companions
		slotsHolder:ClearAllChildren()
		C.list(slotsHolder, "H", 5, nil, Enum.VerticalAlignment.Center)
		for i = 1, 2 do
			local on = i <= used
			local available = i <= max
			local dot = C.frame({ Parent = slotsHolder, LayoutOrder = i, Size = UDim2.fromOffset(12, 12), Color = if on then Theme.Color.Success else Theme.Color.Surface3, Transparency = if available then 0 else 0.6, Radius = Theme.Radius.Pill })
			if not available then
				C.stroke(dot, 0.7)
			end
		end
		info.Text = if max >= 2 then `Companions equipped {used}/{max} · bonuses stack` else `Companion equipped {used}/{max} · a second slot unlocks at Rebirth 2`
	end
	table.insert(ctx.refreshers, refresh)
	refresh()
end

---------------------------------------------------------------------------
-- Juice Bar
---------------------------------------------------------------------------
local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function boostCard(grid: Instance, def: Boosts.BoostDef, ctx: PageCtx)
	local card = Kit.card(grid, { Accent = def.Color, Order = def.Order })
	local head = Kit.row(card.Body, 54, 1)
	local bottle = Kit.bottleGlyph(def.Color, 50)
	bottle.Position = UDim2.fromOffset(-4, 2)
	bottle.Parent = head
	C.label({ Parent = head, Text = def.Name, Font = Theme.Font.Bold, TextSize = Theme.TextSize.Heading, Size = UDim2.new(1, -54, 0, 22), Position = UDim2.fromOffset(52, 6) })
	C.label({ Parent = head, Text = def.Description, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextDim, Size = UDim2.new(1, -54, 0, 18), Position = UDim2.fromOffset(52, 28) })

	local meta = Kit.row(card.Body, 22, 2)
	C.list(meta, "H", 6, nil, Enum.VerticalAlignment.Center)
	C.pill({ Parent = meta, LayoutOrder = 1, Text = string.upper(Format.duration(def.Duration)), Color = Theme.Color.TextDim, Height = 20 })
	local bagHolder = C.frame({ Parent = meta, LayoutOrder = 2, Size = UDim2.fromOffset(0, 20), AutoSize = Enum.AutomaticSize.X })
	local activeHolder = C.frame({ Parent = meta, LayoutOrder = 3, Size = UDim2.fromOffset(0, 20), AutoSize = Enum.AutomaticSize.X })

	local buy = Kit.action({ Parent = card.Footer, Size = UDim2.new(0.5, -4, 1, 0), Text = "", Style = "Secondary", Icon = "cash", IconSize = 14 })
	local drink = Kit.action({ Parent = card.Footer, Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), Text = "Buy & Drink", Style = "Primary" })

	local shownBag = -1
	local shownActive = ""
	local function tick()
		local expiry = DataController.data.Boosts[def.Id]
		local left = if expiry then expiry - serverNow() else 0
		local text = if left > 0 then "ACTIVE " .. Format.clock(left) else ""
		if text ~= shownActive then
			shownActive = text
			activeHolder:ClearAllChildren()
			if text ~= "" then
				C.pill({ Parent = activeHolder, Text = text, Color = def.Color, Height = 20 })
			end
		end
		card.setHighlight(left > 0)
	end
	local function refresh()
		local data = DataController.data
		local price = Boosts.price(def, data.Level)
		local have = data.BoostInventory[def.Id] or 0
		if have ~= shownBag then
			shownBag = have
			bagHolder:ClearAllChildren()
			if have > 0 then
				C.pill({ Parent = bagHolder, Text = `IN BAG ×{have}`, Color = Theme.Color.Accent, Height = 20 })
			end
		end
		buy.set({
			Text = Kit.amount("Cash", price),
			Style = "Secondary",
			Run = function()
				buy.send("Shop.Buy", { Category = "Boost", Id = def.Id, Count = 1 }, buyOpts())
			end,
		})
		if have > 0 then
			drink.set({
				Text = "Drink",
				Style = "Success",
				Run = function()
					drink.send("Boost.Use", { Id = def.Id }, { FailTitle = "Can't drink that yet" })
				end,
			})
		else
			drink.set({
				Text = "Buy & Drink",
				Style = if data.Cash >= price then "Primary" else "Secondary",
				Run = function()
					drink.send("Shop.Buy", { Category = "Boost", Id = def.Id, Use = true }, buyOpts())
				end,
			})
		end
		tick()
	end
	table.insert(ctx.refreshers, refresh)
	table.insert(ctx.tickers, tick)
	refresh()
end

local function buildJuiceBar(page: Frame, ctx: PageCtx)
	local top = C.frame({ Parent = page, Name = "Top", Size = UDim2.new(1, 0, 0, 34) })
	C.label({
		Parent = top,
		Text = `Prices scale with your level · timers stack up to {Format.clock(Boosts.MaxStack)}`,
		TextSize = Theme.TextSize.Caption,
		Color = Theme.Color.TextDim,
		Size = UDim2.new(1, -150, 1, 0),
	})
	local bag = C.label({
		Parent = top,
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Caption,
		Color = Theme.Color.Accent,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 150, 1, 0),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
	})
	local grid = Kit.grid(page, { MinWidth = 252, Height = 172, Size = UDim2.new(1, 0, 1, -46), Position = UDim2.fromOffset(0, 46) })
	local list = table.clone(Boosts.List)
	table.sort(list, function(a: Boosts.BoostDef, b: Boosts.BoostDef)
		return a.Order < b.Order
	end)
	for _, def in list do
		boostCard(grid, def, ctx)
	end
	table.insert(ctx.refreshers, function()
		local n = 0
		for _, count in DataController.data.BoostInventory do
			n += count
		end
		bag.Text = if n > 0 then `{n} drink{if n == 1 then "" else "s"} in your bag` else ""
	end)
end

---------------------------------------------------------------------------
-- Cosmetics
---------------------------------------------------------------------------
type Cosmetic = {
	Category: string, -- Shop.Buy / Inventory category
	OwnedKey: string,
	Id: string,
	Name: string,
	Sub: string,
	Cost: Currency.Cost?,
	Source: string,
	Order: number,
	Accent: Color3,
	Art: () -> GuiObject,
	ArtHeight: number,
}

local function isEquipped(category: string, id: string): boolean
	local eq = DataController.data.Equipped
	if category == "Aura" then
		return eq.Aura == id
	elseif category == "Title" then
		return eq.Title == id
	elseif category == "Emote" then
		return table.find(eq.Emotes, id) ~= nil
	end
	return table.find(eq.Decor, id) ~= nil
end

local function cosmeticCard(grid: Instance, item: Cosmetic, ctx: PageCtx)
	local card = Kit.card(grid, { Accent = item.Accent, Order = item.Order })
	Kit.art(card.Body, item.Art(), item.ArtHeight, 1)
	centred(card.Body, 2, item.Name)
	centred(card.Body, 3, item.Sub, { Font = Theme.Font.Regular, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextDim, Wrap = true, Height = 34, YAlign = Enum.TextYAlignment.Top })
	local f = footer(card, "Buy")
	local function refresh()
		local owned = ((DataController.data.Owned :: any)[item.OwnedKey] or {})[item.Id] == true
		paintItem(card, f, {
			Owned = owned,
			Equipped = owned and isEquipped(item.Category, item.Id),
			Cost = item.Cost,
			Source = item.Source,
			Buy = function()
				f.action.send("Shop.Buy", { Category = item.Category, Id = item.Id }, buyOpts())
			end,
			Equip = function()
				f.action.send("Inventory.Equip", { Category = item.Category, Id = item.Id }, equipOpts())
			end,
		})
	end
	table.insert(ctx.refreshers, refresh)
	refresh()
end

local function cosmeticsFor(sub: string): { Cosmetic }
	local out: { Cosmetic } = {}
	if sub == "Auras" then
		for _, d in Cosmetics.AuraList do
			table.insert(out, { Category = "Aura", OwnedKey = "Auras", Id = d.Id, Name = d.Name, Sub = d.Description, Cost = d.Cost, Source = d.Source, Order = d.Order, Accent = Kit.AuraColor[d.Effect] or Theme.Color.Accent, ArtHeight = 78, Art = function()
				return Kit.auraGlyph(d.Effect, 70)
			end })
		end
	elseif sub == "Titles" then
		for _, d in Cosmetics.TitleList do
			table.insert(out, { Category = "Title", OwnedKey = "Titles", Id = d.Id, Name = d.Text, Sub = "Shown under your name", Cost = d.Cost, Source = d.Source, Order = d.Order, Accent = d.Color, ArtHeight = 78, Art = function()
				return Kit.titlePlate(d.Text, d.Color, 150)
			end })
		end
	elseif sub == "Emotes" then
		for _, d in Cosmetics.EmoteList do
			table.insert(out, { Category = "Emote", OwnedKey = "Emotes", Id = d.Id, Name = d.Name, Sub = if d.Loop then "Looping emote" else "Pose", Cost = d.Cost, Source = d.Source, Order = d.Order, Accent = EMOTE_COLOR, ArtHeight = 78, Art = function()
				return Kit.disc("emote", EMOTE_COLOR, 62)
			end })
		end
	else
		for _, d in Cosmetics.DecorList do
			local icon = if d.Visual == "Cup" or d.Visual == "Medals" then "trophy" else "star"
			table.insert(out, { Category = "Decor", OwnedKey = "Decor", Id = d.Id, Name = d.Name, Sub = "Displayed on your locker", Cost = d.Cost, Source = d.Source, Order = d.Order, Accent = DECOR_COLOR, ArtHeight = 78, Art = function()
				return Kit.disc(icon, DECOR_COLOR, 62)
			end })
		end
	end
	return out
end

local function buildCosmetics(page: Frame, ctx: PageCtx)
	local top = C.frame({ Parent = page, Name = "Top", Size = UDim2.new(1, 0, 0, 34) })
	local hint = C.label({
		Parent = top,
		TextSize = Theme.TextSize.Caption,
		Color = Theme.Color.TextDim,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 220, 1, 0),
		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
	})
	local area = C.frame({ Parent = page, Name = "Area", Size = UDim2.new(1, 0, 1, -46), Position = UDim2.fromOffset(0, 46) })
	local grids: { [string]: GuiObject } = {}
	local hints: { [string]: string } = {
		Auras = "Pure style · no stat effects",
		Titles = "Shown on your nameplate",
		Emotes = `Up to {Cosmetics.MaxEquippedEmotes} on your emote wheel`,
		Decor = `Up to {Cosmetics.MaxDecor} on your locker`,
	}
	local chips = Kit.chips(top, {
		{ Id = "Auras", Label = "Auras" },
		{ Id = "Titles", Label = "Titles" },
		{ Id = "Emotes", Label = "Emotes" },
		{ Id = "Decor", Label = "Decor" },
	}, function(sub: string)
		if not grids[sub] then
			local grid = Kit.grid(area, { Name = sub, MinWidth = CARD_W, Height = 226 })
			grids[sub] = grid
			for _, item in cosmeticsFor(sub) do
				cosmeticCard(grid, item, ctx)
			end
		end
		for s, g in grids do
			g.Visible = s == sub
		end
		hint.Text = hints[sub] or ""
	end)
	Kit.autoHide(hint, chips.Frame)
	chips.select("Auras")
end

---------------------------------------------------------------------------
-- VIP
---------------------------------------------------------------------------
local robuxPrice: { [number]: number } = {}

local function fetchPrice(id: number, infoType: Enum.InfoType, onDone: () -> ())
	if id == 0 or robuxPrice[id] then
		return
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(id, infoType)
		end)
		if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
			robuxPrice[id] = info.PriceInRobux
			onDone()
		end
	end)
end

local function robuxText(id: number, verb: string): string
	local p = robuxPrice[id]
	return if p then `{verb} · R$ {Format.commas(p)}` else verb
end

local function heroText(card: Kit.Card, kicker: string, title: string, color: Color3)
	C.label({ Parent = card.Body, LayoutOrder = 1, Text = kicker, Font = Theme.Font.Heavy, TextSize = Theme.TextSize.Micro, Color = color, Size = UDim2.new(1, 0, 0, 16) })
	C.label({ Parent = card.Body, LayoutOrder = 2, Text = title, Font = Theme.Font.Heavy, TextSize = Theme.TextSize.Title, Size = UDim2.new(1, 0, 0, 28) })
end

local function capitalise(s: string): string
	local t = string.gsub(s, "%.$", "")
	return string.upper(string.sub(t, 1, 1)) .. string.sub(t, 2)
end

local function buildVIP(page: Frame, ctx: PageCtx)
	local scroll = C.scroll({ Parent = page, Gap = 12 })
	local vipArea = Areas.get("VIP")
	local clubColor = if vipArea then vipArea.Accent:Lerp(VIP_GREEN, 0.5) else VIP_GREEN
	local trophyCost = if vipArea and vipArea.TrophyCost then vipArea.TrophyCost else 0
	local passes = Monetization.GamePasses :: { [string]: { Id: number, Name: string, Description: string } }
	local products = Monetization.Products :: { [string]: any }
	local function refreshAll()
		for _, fn in ctx.refreshers do
			fn()
		end
	end

	local hero = Kit.grid(scroll, { Scroll = false, MinWidth = 300, Height = 258, MaxColumns = 2, Gap = 12, LayoutOrder = 1 })

	-- VIP Club (trophy unlock)
	do
		local card = Kit.card(hero, { Accent = clubColor, Order = 1, FooterHeight = 40 })
		heroText(card, "SECOND FLOOR · MEMBERS ONLY", "VIP Club", clubColor)
		C.label({
			Parent = card.Body,
			LayoutOrder = 3,
			Text = "A calm members' floor with premium equipment and the best views in the gym. Unlock it forever with trophies, or get it with VIP.",
			TextSize = Theme.TextSize.Caption,
			Color = Theme.Color.TextDim,
			Wrap = true,
			YAlign = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 52),
		})
		local progRow = Kit.row(card.Body, 34, 4)
		local progText = C.label({ Parent = progRow, TextSize = Theme.TextSize.Caption, Font = Theme.Font.SemiBold, Color = Theme.Color.TextDim, Size = UDim2.new(1, 0, 0, 18) })
		local _, setProg = C.progress({ Parent = progRow, Size = UDim2.new(1, 0, 0, 6), Position = UDim2.fromOffset(0, 24), Color = Theme.Color.Trophy })
		local action = Kit.action({ Parent = card.Footer, Text = "Unlock", Style = "Primary", Icon = "trophy", IconSize = 16 })
		table.insert(ctx.refreshers, function()
			local data = DataController.data
			local trophies = data.Trophies
			local vip = player:GetAttribute("VIP") == true
			local unlocked = data.Unlocks.VIPTrophy == true
			progRow.Visible = not (vip or unlocked)
			progText.Text = `{Format.commas(math.min(trophies, trophyCost))} / {Format.commas(trophyCost)} trophies`
			setProg(if trophyCost > 0 then trophies / trophyCost else 1, true)
			card.setHighlight(vip or unlocked)
			if vip then
				card.setBadge("INCLUDED", Theme.Color.Success)
				action.set({ Text = "Included with VIP", Style = "Ghost", Disabled = true })
			elseif unlocked then
				card.setBadge("UNLOCKED", Theme.Color.Success)
				action.set({ Text = "Unlocked forever", Style = "Ghost", Disabled = true })
			elseif trophyCost <= 0 then
				card.setBadge(nil)
				action.set({ Text = "Unavailable", Style = "Ghost", Disabled = true })
			elseif trophies >= trophyCost then
				card.setBadge(nil)
				action.set({
					Text = `Unlock for {Format.commas(trophyCost)}`,
					Style = "Primary",
					Run = function()
						action.send("Shop.UnlockVIP", nil, { Sound = "", FailTitle = "Can't unlock yet" })
					end,
				})
			else
				card.setBadge(nil)
				action.set({ Text = `Need {Format.commas(trophyCost - trophies)} more`, Style = "Secondary", Disabled = true })
			end
		end)
	end

	-- VIP Membership (game pass)
	do
		local pass = passes.VIP
		local card = Kit.card(hero, { Accent = Theme.Color.Accent, Order = 2, FooterHeight = 40 })
		heroText(card, "GAME PASS", pass.Name, Theme.Color.Accent)
		local perks = C.frame({ Parent = card.Body, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutoSize = Enum.AutomaticSize.Y })
		C.list(perks, "V", 4)
		for i, perk in string.split(pass.Description, ", ") do
			local row = C.frame({ Parent = perks, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 18) })
			local check = Icons.make("check", 14, Theme.Color.Success)
			check.Position = UDim2.fromOffset(0, 2)
			check.Parent = row
			C.label({ Parent = row, Text = capitalise(perk), TextSize = Theme.TextSize.Caption, Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(22, 0) })
		end
		local action = Kit.action({ Parent = card.Footer, Text = "Get VIP", Style = "Primary" })
		fetchPrice(pass.Id, Enum.InfoType.GamePass, refreshAll)
		table.insert(ctx.refreshers, function()
			local owned = player:GetAttribute("VIP") == true
			card.setHighlight(owned)
			if owned then
				card.setBadge("ACTIVE", Theme.Color.Success)
				action.set({ Text = "You're a VIP", Style = "Ghost", Disabled = true })
			elseif pass.Id == 0 then
				card.setBadge("SOON", Theme.Color.TextDim)
				action.set({ Text = "Coming soon", Style = "Ghost", Disabled = true })
			else
				card.setBadge(nil)
				action.set({
					Text = robuxText(pass.Id, "Get VIP"),
					Style = "Primary",
					Run = function()
						action.send("Shop.PromptPass", { Pass = "VIP" }, { Sound = "", FailTitle = "Store unavailable" })
					end,
				})
			end
		end)
	end

	-- Extras: 2x Cash pass + developer products
	Kit.section(scroll, "Extras", 2)
	local extras = Kit.grid(scroll, { Scroll = false, MinWidth = CARD_W + 10, Height = 214, Gap = 10, LayoutOrder = 3 })
	type Extra = { Key: string, IsPass: boolean, Id: number, Name: string, Sub: string, Icon: string, Color: Color3, Kicker: string }
	local entries: { Extra } = {}
	local dc = passes.DoubleCash
	table.insert(entries, { Key = "DoubleCash", IsPass = true, Id = dc.Id, Name = dc.Name, Sub = dc.Description, Icon = "cash", Color = Theme.Color.Trophy, Kicker = "GAME PASS" })
	for _, key in { "CashSmall", "CashLarge", "BoostPack" } do
		local p = products[key]
		if type(p) == "table" then
			local sub: string
			if p.Kind == "Cash" then
				sub = `+${Format.short(p.Amount or 0)} Cash, delivered instantly`
			else
				local parts: { string } = {}
				for _, b in Boosts.List do
					local n = p.Boosts and p.Boosts[b.Id]
					if n then
						table.insert(parts, `{n}× {b.Name}`)
					end
				end
				sub = table.concat(parts, " · ")
			end
			table.insert(entries, { Key = key, IsPass = false, Id = p.Id, Name = p.Name, Sub = sub, Icon = if p.Kind == "Cash" then "cash" else "boost", Color = if p.Kind == "Cash" then Theme.Color.Cash else Theme.Color.Accent, Kicker = "ROBUX PACK" })
		end
	end
	for i, e in entries do
		local card = Kit.card(extras, { Accent = e.Color, Order = i })
		local kick = Kit.row(card.Body, 20, 1)
		C.pill({ Parent = kick, Text = e.Kicker, Color = e.Color, Height = 20 })
		local disc = Kit.disc(e.Icon, e.Color, 56)
		if e.Key == "DoubleCash" then
			C.label({ Parent = disc, Text = "2×", Font = Theme.Font.Heavy, TextSize = Theme.TextSize.Caption, Color = Theme.Color.Text, XAlign = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(26, 18), Position = UDim2.new(1, -18, 1, -16) })
		end
		Kit.art(card.Body, disc, 62, 2)
		centred(card.Body, 3, e.Name)
		centred(card.Body, 4, e.Sub, { Font = Theme.Font.Regular, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextDim, Wrap = true, Height = 32, YAlign = Enum.TextYAlignment.Top })
		local action = Kit.action({ Parent = card.Footer, Text = "Buy", Style = "Primary" })
		fetchPrice(e.Id, if e.IsPass then Enum.InfoType.GamePass else Enum.InfoType.Product, refreshAll)
		table.insert(ctx.refreshers, function()
			local owned = e.IsPass and player:GetAttribute(e.Key) == true
			card.setHighlight(owned)
			if owned then
				card.setBadge("ACTIVE", Theme.Color.Success)
				action.set({ Text = "Owned", Style = "Ghost", Disabled = true })
			elseif e.Id == 0 then
				card.setBadge("SOON", Theme.Color.TextDim)
				action.set({ Text = "Coming soon", Style = "Ghost", Disabled = true })
			else
				card.setBadge(nil)
				action.set({
					Text = robuxText(e.Id, "Buy"),
					Style = "Primary",
					Run = function()
						if e.IsPass then
							action.send("Shop.PromptPass", { Pass = e.Key }, { Sound = "", FailTitle = "Store unavailable" })
						else
							action.send("Shop.PromptProduct", { Product = e.Key }, { Sound = "", FailTitle = "Store unavailable" })
						end
					end,
				})
			end
		end)
	end

	C.label({
		Parent = scroll,
		LayoutOrder = 4,
		Text = "Everything in Ironhaven can be earned by training. Purchases are optional and never required to progress.",
		TextSize = Theme.TextSize.Caption,
		Color = Theme.Color.TextMute,
		XAlign = Enum.TextXAlignment.Center,
		Wrap = true,
		Size = UDim2.new(1, 0, 0, 36),
	})
	refreshAll()
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local BUILDERS: { [string]: (Frame, PageCtx) -> () } = {
	Gear = buildGear,
	Companions = buildCompanions,
	JuiceBar = buildJuiceBar,
	Cosmetics = buildCosmetics,
	VIP = buildVIP,
}

-- Compact balance readout in the header.
local function wallet(parent: Frame): (Frame, () -> ())
	local row = C.frame({ Parent = parent, Name = "Wallet", Size = UDim2.new(0, 300, 1, 0), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0), ZIndex = 2 })
	C.list(row, "H", 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local labels: { [string]: TextLabel } = {}
	local chips: { [string]: Frame } = {}
	for i, key in { "RebirthTokens", "Trophies", "Cash" } do
		local chip = C.frame({ Parent = row, LayoutOrder = i, Size = UDim2.fromOffset(0, 30), AutoSize = Enum.AutomaticSize.X, Color = Theme.Color.Surface1, Transparency = 0, Radius = Theme.Radius.Pill })
		C.stroke(chip, 0.9)
		C.padding(chip, 0, 12, 0, 8)
		C.list(chip, "H", 6, nil, Enum.VerticalAlignment.Center)
		Icons.make(Kit.CurrencyIcon[key], 16, Kit.CurrencyColor[key]).Parent = chip
		labels[key] = C.label({ Parent = chip, Font = Theme.Font.Bold, TextSize = Theme.TextSize.Caption + 1, Size = UDim2.new(0, 0, 1, 0), AutoSize = Enum.AutomaticSize.X, LayoutOrder = 2 })
		chips[key] = chip
	end
	return row, function()
		for key, label in labels do
			local v = Kit.balance(key)
			label.Text = if key == "Cash" then "$" .. Format.short(v) else Format.short(v)
			chips[key].Visible = key ~= "RebirthTokens" or v > 0
		end
	end
end


function ShopWindow.build(body: Frame, initial: string?): Api
	local header = C.frame({ Parent = body, Name = "Header", Size = UDim2.new(1, 0, 0, 34) })
	local pagesFrame = C.frame({ Parent = body, Name = "Pages", Size = UDim2.new(1, 0, 1, -48), Position = UDim2.fromOffset(0, 48) })
	local walletRow, paintWallet = wallet(header)

	local pages: { [string]: Frame } = {}
	local ctxs: { [string]: PageCtx } = {}
	local currentTab = ""

	local function show(id: string)
		if not BUILDERS[id] then
			return
		end
		currentTab = id
		if not pages[id] then
			local page = C.frame({ Parent = pagesFrame, Name = id, Size = UDim2.fromScale(1, 1) })
			local ctx: PageCtx = { refreshers = {}, tickers = {} }
			pages[id] = page
			ctxs[id] = ctx
			local ok, err = pcall(BUILDERS[id], page, ctx)
			if not ok then
				warn(`[Shop] page {id} failed: {err}`)
				C.empty(page, "This section failed to load.")
			end
		end
		for pid, page in pages do
			page.Visible = pid == id
		end
	end

	local tabs = C.tabs({ Parent = header, Tabs = TABS, Size = UDim2.fromScale(1, 1), OnSelect = show })

	-- narrow windows: the tabs win, the wallet hides (balances stay on the HUD)
	local function fitHeader()
		local need = Kit.contentWidth(tabs.Frame, 6) + Kit.contentWidth(walletRow, 6) + 16
		walletRow.Visible = need <= header.AbsoluteSize.X
	end
	header:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitHeader)

	local function refreshAll()
		paintWallet()
		task.defer(fitHeader)
		for _, ctx in ctxs do
			for _, fn in ctx.refreshers do
				fn()
			end
		end
	end
	Kit.watch(DATA_KEYS, refreshAll)
	player:GetAttributeChangedSignal("VIP"):Connect(refreshAll)
	player:GetAttributeChangedSignal("DoubleCash"):Connect(refreshAll)
	paintWallet()

	-- 1 Hz timers (active boost countdowns) while the window is visible
	local window = body.Parent :: GuiObject
	task.spawn(function()
		while body.Parent do
			task.wait(1)
			local ctx = ctxs[currentTab]
			if ctx and window.Visible then
				for _, fn in ctx.tickers do
					fn()
				end
			end
		end
	end)

	tabs.select(if initial and BUILDERS[initial] then initial else "Gear")

	return {
		select = function(id: string)
			if BUILDERS[id] then
				tabs.select(id)
			end
		end,
		current = function()
			return currentTab
		end,
	}
end

return ShopWindow
