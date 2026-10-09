--!strict
--[[
	InventoryController: the "Inventory" window (rail label "Gear", icon "gear").

		InventoryController.open("Emotes")   -- Gear | Companions | Auras | Titles | Emotes | Decor

	Equip / unequip everything the player owns, with a per-stat bonus summary.
	Empty states jump to the matching Shop tab.
]]

local InventoryWindow = require(script.Parent.Parent.UI.Windows.InventoryWindow)

local DataController = require(script.Parent.DataController)
local ShopController = require(script.Parent.ShopController)
local UIController = require(script.Parent.UIController)

local InventoryController = {}

local api: InventoryWindow.Api? = nil
local pendingTab: string? = nil
local registered = false

function InventoryController.open(tab: string?)
	if not registered then
		return
	end
	if tab then
		pendingTab = tab
	end
	UIController.open("Inventory")
	local inv = api
	if inv and tab then
		inv.select(tab)
	end
end

function InventoryController.Start()
	DataController.ready()
	UIController.registerWindow("Inventory", {
		Title = "Inventory",
		Icon = "gear",
		Width = 860,
		Height = 600,
		Build = function(body: Frame)
			api = InventoryWindow.build(body, {
				openShop = function(tab: string)
					ShopController.open(tab)
				end,
			}, pendingTab)
		end,
	})
	registered = true
end

return InventoryController
