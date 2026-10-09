--!strict
--[[
	ShopController: the "Shop" window and every way into it.

		ShopController.open("JuiceBar")   -- Gear | Companions | JuiceBar | Cosmetics | VIP (nil = last tab)

	Shop counters in the world (tag "ShopCounter", ProximityPrompt "ShopPrompt",
	attribute Shop) open the matching tab:
	  JuiceBar -> Juice Bar · ProShop -> Gear · Companions -> Companions · Cosmetics -> Cosmetics
	Prompts are handled through ProximityPromptService.PromptTriggered, which only
	fires on this client for the local player's own triggers and needs no
	per-instance connections, so counters streaming in and out need no bookkeeping.

	Also celebrates "VIPUnlocked" (server Notify.event) with a banner.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Areas = require(Shared.Config.Areas)

local ShopWindow = require(script.Parent.Parent.UI.Windows.ShopWindow)

local GameEvents = require(script.Parent.Parent.Core.GameEvents)
local State = require(script.Parent.Parent.Core.State)
local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)
local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer

local ShopController = {}

local COUNTER_TAB: { [string]: string } = {
	JuiceBar = "JuiceBar",
	ProShop = "Gear",
	Companions = "Companions",
	Cosmetics = "Cosmetics",
}

local api: ShopWindow.Api? = nil
local pendingTab: string? = nil
local registered = false

function ShopController.open(tab: string?)
	if not registered then
		return
	end
	if tab then
		pendingTab = tab
	end
	UIController.open("Shop")
	local shop = api
	if shop and tab then
		shop.select(tab)
	end
end

local function onPrompt(prompt: ProximityPrompt, who: Player)
	if who ~= player or prompt.Name ~= "ShopPrompt" then
		return
	end
	local part = prompt.Parent
	if not part or not CollectionService:HasTag(part, "ShopCounter") then
		return
	end
	if State.get("Training") or State.get("Minigame") or State.get("Cinematic") then
		return
	end
	local shop = part:GetAttribute("Shop")
	local tab = if type(shop) == "string" then COUNTER_TAB[shop] else nil
	ShopController.open(tab or "Gear")
end

function ShopController.Init()
	ProximityPromptService.PromptTriggered:Connect(onPrompt)
	GameEvents.on("VIPUnlocked", function(payload)
		local area = Areas.get("VIP")
		NotificationController.banner({
			Kicker = "MEMBERS ONLY",
			Title = "VIP CLUB UNLOCKED",
			Subtitle = if payload.Source == "Pass" then "Welcome to VIP. The second-floor club is yours." else "Unlocked forever. Find it on the second floor.",
			Color = if area then area.Accent else nil,
			Sound = "Unlock",
		})
	end)
end

function ShopController.Start()
	DataController.ready()
	UIController.registerWindow("Shop", {
		Title = "Shop",
		Icon = "shop",
		Width = 900,
		Height = 600,
		Build = function(body: Frame)
			api = ShopWindow.build(body, pendingTab)
		end,
	})
	registered = true
end

return ShopController
