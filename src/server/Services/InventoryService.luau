--!strict
--[[
	InventoryService: equipping what you own.

		Inventory.Equip   { Category, Id, Slot? }   -> (ok, message?)
		Inventory.Unequip { Category, Id?, Slot? }  -> (ok, message?)

	Categories and limits:
	  Gear       one per gear slot (Slot is implied by the item; Unequip takes Id or Slot name)
	  Companion  up to Companions.slots(rebirths); equipping when full replaces
	             Slot (1-based) if given, otherwise the longest-equipped companion
	  Aura       one ("" = none)          Title  one ("" = none)
	  Emote      up to Cosmetics.MaxEquippedEmotes (Slot replaces that wheel slot)
	  Decor      up to Cosmetics.MaxDecor (Slot replaces that locker slot)

	Ownership is always checked against data.Owned. Equipped lists are written as
	whole tables through DataService so the client replica stays in sync, and
	are sanitised on join (unowned / unknown / over-limit entries are dropped).
	CharacterService reacts to Equipped changes (attributes + GearVisuals).

	Events: ItemEquipped / ItemUnequipped (meta { Category, Id }).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local Companions = require(Config.Companions)
local Cosmetics = require(Config.Cosmetics)
local DataSchema = require(Shared.DataSchema)
local Gear = require(Config.Gear)
local Net = require(Shared.Util.Net)

local DataService = require(script.Parent.DataService)
local Events = require(script.Parent.Parent.Core.Events)

type PlayerData = DataSchema.PlayerData

local InventoryService = {}
InventoryService.Priority = 30

local CATEGORIES = { Gear = true, Companion = true, Aura = true, Title = true, Emote = true, Decor = true }

-- Category -> data.Owned key, for the list/single categories.
local OWNED_KEY = { Gear = "Gear", Companion = "Companions", Aura = "Auras", Title = "Titles", Emote = "Emotes", Decor = "Decor" }

local function exists(category: string, id: string): boolean
	if category == "Gear" then
		return Gear.get(id) ~= nil
	elseif category == "Companion" then
		return Companions.Defs[id] ~= nil
	elseif category == "Aura" then
		return Cosmetics.Auras[id] ~= nil
	elseif category == "Title" then
		return Cosmetics.Titles[id] ~= nil
	elseif category == "Emote" then
		return Cosmetics.Emotes[id] ~= nil
	elseif category == "Decor" then
		return Cosmetics.Decor[id] ~= nil
	end
	return false
end

local function owns(data: PlayerData, category: string, id: string): boolean
	local key = OWNED_KEY[category]
	local owned = key and (data.Owned :: any)[key]
	return type(owned) == "table" and owned[id] == true
end

-- Equipped list for the list categories, and its limit.
local function listInfo(data: PlayerData, category: string): ({ string }, number, string)
	if category == "Companion" then
		return data.Equipped.Companions, Companions.slots(data.Rebirths), "Companions"
	elseif category == "Emote" then
		return data.Equipped.Emotes, Cosmetics.MaxEquippedEmotes, "Emotes"
	end
	return data.Equipped.Decor, Cosmetics.MaxDecor, "Decor"
end

local function slotIndex(raw: any, max: number): number?
	if type(raw) == "number" and raw == raw and raw % 1 == 0 and raw >= 1 and raw <= max then
		return raw
	end
	return nil
end

local function validate(player: Player, payload: any, needId: boolean): (string?, string?, string?)
	if not Net.allow(player, "Inventory", 6, 12) then
		return nil, nil, "Slow down!"
	end
	if type(payload) ~= "table" then
		return nil, nil, "Bad request"
	end
	local category = payload.Category
	if type(category) ~= "string" or not CATEGORIES[category] then
		return nil, nil, "Bad request"
	end
	local id = payload.Id
	if id ~= nil and (type(id) ~= "string" or #id == 0 or #id > 40) then
		return nil, nil, "Bad request"
	end
	if needId and id == nil then
		return nil, nil, "Bad request"
	end
	return category, id, nil
end

---------------------------------------------------------------------------
-- Equip
---------------------------------------------------------------------------
local function equip(player: Player, payload: any): (boolean, string?)
	local category, id, err = validate(player, payload, true)
	if err or not category or not id then
		return false, err
	end
	local data = DataService.get(player)
	if not data then
		return false, "Your data is still loading."
	end
	if not exists(category, id) then
		return false, "That item doesn't exist."
	end
	if not owns(data, category, id) then
		return false, "You don't own that yet."
	end

	if category == "Gear" then
		local def = Gear.get(id) :: Gear.GearDef
		if data.Equipped.Gear[def.Slot] == id then
			return true, nil
		end
		DataService.set(player, { "Equipped", "Gear", def.Slot }, id)
	elseif category == "Aura" then
		DataService.set(player, { "Equipped", "Aura" }, id)
	elseif category == "Title" then
		DataService.set(player, { "Equipped", "Title" }, id)
	else
		local current, max, key = listInfo(data, category)
		if table.find(current, id) then
			return true, nil
		end
		local list = table.clone(current)
		while #list > max do
			table.remove(list, 1)
		end
		local slot = slotIndex(payload.Slot, max)
		if slot and list[slot] then
			list[slot] = id
		elseif #list < max then
			table.insert(list, id)
		elseif category == "Companion" then
			-- full: swap out the companion that has been equipped longest
			table.remove(list, 1)
			table.insert(list, id)
		else
			local what = if category == "Emote" then "Your emote wheel" else "Your locker"
			return false, `{what} is full ({max}/{max}). Unequip one first.`
		end
		DataService.set(player, { "Equipped", key }, list)
	end
	Events.fire(player, "ItemEquipped", 1, { Category = category, Id = id })
	return true, nil
end

---------------------------------------------------------------------------
-- Unequip
---------------------------------------------------------------------------
local function unequip(player: Player, payload: any): (boolean, string?)
	local category, id, err = validate(player, payload, false)
	if err or not category then
		return false, err
	end
	local data = DataService.get(player)
	if not data then
		return false, "Your data is still loading."
	end

	if category == "Gear" then
		local slot: string? = nil
		if id then
			local def = Gear.get(id)
			if def and data.Equipped.Gear[def.Slot] == id then
				slot = def.Slot
			end
		elseif type(payload.Slot) == "string" and Gear.BySlot[payload.Slot :: Gear.GearSlot] then
			slot = payload.Slot
		end
		if not slot or data.Equipped.Gear[slot] == nil then
			return true, nil
		end
		DataService.set(player, { "Equipped", "Gear", slot }, nil)
	elseif category == "Aura" then
		if id and data.Equipped.Aura ~= id then
			return true, nil
		end
		DataService.set(player, { "Equipped", "Aura" }, "")
	elseif category == "Title" then
		if id and data.Equipped.Title ~= id then
			return true, nil
		end
		DataService.set(player, { "Equipped", "Title" }, "")
	else
		local current, max, key = listInfo(data, category)
		local index: number? = nil
		if id then
			index = table.find(current, id)
		else
			index = slotIndex(payload.Slot, math.max(max, #current))
		end
		if not index or current[index] == nil then
			return true, nil
		end
		local list = table.clone(current)
		table.remove(list, index)
		DataService.set(player, { "Equipped", key }, list)
	end
	Events.fire(player, "ItemUnequipped", 1, { Category = category, Id = id })
	return true, nil
end

---------------------------------------------------------------------------
-- Join-time sanitising (config changes, rebirth resets, corrupted saves)
---------------------------------------------------------------------------
local function cleanList(data: PlayerData, category: string): ({ string }, boolean)
	local current, max = listInfo(data, category)
	local out: { string } = {}
	for _, id in current do
		if type(id) == "string" and #out < max and exists(category, id) and owns(data, category, id) and not table.find(out, id) then
			table.insert(out, id)
		end
	end
	return out, #out ~= #current
end

local function sanitize(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	for slot, id in data.Equipped.Gear do
		local def = Gear.get(id)
		if not def or def.Slot ~= slot or not data.Owned.Gear[id] then
			DataService.set(player, { "Equipped", "Gear", slot }, nil)
		end
	end
	for _, category in { "Companion", "Emote", "Decor" } do
		local list, changed = cleanList(data, category)
		if changed then
			local _, _, key = listInfo(data, category)
			DataService.set(player, { "Equipped", key }, list)
		end
	end
	local aura = data.Equipped.Aura
	if aura ~= "" and not (exists("Aura", aura) and owns(data, "Aura", aura)) then
		DataService.set(player, { "Equipped", "Aura" }, "")
	end
	local title = data.Equipped.Title
	if title ~= "" and not (exists("Title", title) and owns(data, "Title", title)) then
		DataService.set(player, { "Equipped", "Title" }, if data.Owned.Titles.Newcomer then "Newcomer" else "")
	end
end

function InventoryService.Init()
	Net.handle("Inventory.Equip", equip)
	Net.handle("Inventory.Unequip", unequip)
end

function InventoryService.Start()
	DataService.Loaded:Connect(sanitize)
	for _, player in Players:GetPlayers() do
		sanitize(player)
	end
end

return InventoryService
