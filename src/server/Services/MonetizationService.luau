--!strict
--[[
	MonetizationService: Robux game passes and developer products.

		Shop.PromptPass    { Pass }      -> (ok, message?)   key of Monetization.GamePasses
		Shop.PromptProduct { Product }   -> (ok, message?)   key of Monetization.Products
		MonetizationService.owns(player, "VIP") -> boolean

	Config/Monetization ids of 0 are disabled ("coming soon") and never prompted.

	Game passes are checked on join (pcall UserOwnsGamePassAsync, with retries)
	and granted live from PromptGamePassPurchaseFinished:
	  VIP         player attribute VIP = true, Title "VIP" (ProgressionService.award)
	  DoubleCash  MultiplierService flag "DoubleCash", player attribute DoubleCash = true

	Developer products go through ProcessReceipt with idempotency:
	  * receipts already in data.Purchases are acknowledged without granting again
	  * grant + receipt record happen in the same synchronous step, then a save is
	    requested, so they always persist together
	  * a receipt is left pending (NotProcessedYet) while the player is offline,
	    still loading, or on a temporary (non-saving) profile outside Studio, so
	    Roblox retries it later instead of the purchase being lost
	  * concurrent callbacks for the same receipt are ignored
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local Boosts = require(Config.Boosts)
local Format = require(Shared.Util.Format)
local Monetization = require(Config.Monetization)
local Net = require(Shared.Util.Net)

local DataService = require(script.Parent.DataService)
local MultiplierService = require(script.Parent.MultiplierService)
local ProgressionService = require(script.Parent.ProgressionService)
local Events = require(script.Parent.Parent.Core.Events)
local Notify = require(script.Parent.Parent.Core.Notify)

local MonetizationService = {}
MonetizationService.Priority = 50

type PassDef = { Id: number, Name: string, Description: string }
type ProductDef = { Id: number, Name: string, Kind: string, Amount: number?, Boosts: { [string]: number }? }

local PASSES = Monetization.GamePasses :: { [string]: PassDef }
local PRODUCTS = Monetization.Products :: { [string]: any }

local passById: { [number]: string } = {}
local productById: { [number]: string } = {}
for key, pass in PASSES do
	if pass.Id ~= 0 then
		passById[pass.Id] = key
	end
end
for key, product in PRODUCTS do
	if type(product.Id) == "number" and product.Id ~= 0 then
		productById[product.Id] = key
	end
end

local ownedPasses: { [Player]: { [string]: boolean } } = {}
local processing: { [string]: boolean } = {}

function MonetizationService.owns(player: Player, pass: string): boolean
	local owned = ownedPasses[player]
	return owned ~= nil and owned[pass] == true
end

---------------------------------------------------------------------------
-- Game passes
---------------------------------------------------------------------------
local function grantPass(player: Player, key: string, fresh: boolean)
	local owned = ownedPasses[player]
	if not owned then
		owned = {}
		ownedPasses[player] = owned
	end
	if owned[key] then
		return
	end
	owned[key] = true
	if key == "VIP" then
		player:SetAttribute("VIP", true)
		if DataService.waitFor(player, 30) and player.Parent then
			-- quiet on later joins (already owned => nothing to announce anyway)
			ProgressionService.award(player, { Title = "VIP" }, "VIP", not fresh)
		end
		if fresh then
			Notify.event(player, "VIPUnlocked", { Source = "Pass" })
		end
	elseif key == "DoubleCash" then
		MultiplierService.setFlag(player, "DoubleCash", true)
		player:SetAttribute("DoubleCash", true)
		if fresh then
			Notify.toast(player, "2x Cash active", "Every rep now pays double. Thanks for supporting Ironhaven!", "Reward")
		end
	end
	if fresh then
		Events.fire(player, "ItemBought", 1, { Category = "GamePass", Id = key })
	end
end

local function checkPasses(player: Player)
	for key, pass in PASSES do
		if pass.Id ~= 0 then
			local owns = false
			for attempt = 1, 3 do
				local ok, result = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
				end)
				if ok then
					owns = result == true
					break
				end
				if not player.Parent then
					return
				end
				task.wait(attempt * 2)
			end
			if owns and player.Parent then
				task.spawn(grantPass, player, key, false)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Developer products
---------------------------------------------------------------------------
local function grantProduct(player: Player, key: string)
	local product = PRODUCTS[key] :: ProductDef
	if product.Kind == "Cash" and product.Amount then
		-- bought cash is not "earned" cash: skip ProgressionService.addCash counters
		DataService.increment(player, { "Cash" }, product.Amount)
		Notify.event(player, "Reward", { Source = "Purchase", Items = { "$" .. Format.short(product.Amount) } })
	elseif product.Kind == "Boosts" and product.Boosts then
		local bundle: { [string]: number } = {}
		for id, count in product.Boosts do
			if Boosts.Defs[id] and count > 0 then
				bundle[id] = count
			end
		end
		ProgressionService.award(player, { Boosts = bundle }, "Purchase")
	else
		error(`product {key} has unknown kind {product.Kind}`)
	end
end

local function processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local receiptId = tostring(info.PurchaseId)
	local productKey = productById[tonumber(info.ProductId) or 0]
	local player = Players:GetPlayerByUserId(tonumber(info.PlayerId) or 0)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = DataService.waitFor(player, 20)
	if not data or not player.Parent then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if data.Purchases[receiptId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if not DataService.isPersistent(player) and not RunService:IsStudio() then
		-- temporary profile: granting now would be lost on leave; retry next session
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not productKey then
		warn(`[Monetization] receipt {receiptId} for unknown product {info.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if processing[receiptId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	processing[receiptId] = true
	local ok, err = pcall(grantProduct, player, productKey)
	if ok then
		DataService.set(player, { "Purchases", receiptId }, true)
		DataService.save(player)
	end
	processing[receiptId] = nil
	if not ok then
		warn(`[Monetization] failed to grant {productKey} to {player.Name}: {err}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	ProgressionService.count(player, "RobuxPurchases", 1)
	Events.fire(player, "ItemBought", 1, { Category = "Product", Id = productKey })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

---------------------------------------------------------------------------
-- Requests
---------------------------------------------------------------------------
local function promptPass(player: Player, payload: any): (boolean, string?)
	if not Net.allow(player, "Shop.Prompt", 1, 3) then
		return false, "Slow down!"
	end
	local key = if type(payload) == "table" then payload.Pass else nil
	local pass = if type(key) == "string" then PASSES[key] else nil
	if not pass then
		return false, "Bad request"
	end
	if pass.Id == 0 then
		return false, "Coming soon!"
	end
	if MonetizationService.owns(player, key) then
		return false, "You already own this."
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.Id)
	return true, nil
end

local function promptProduct(player: Player, payload: any): (boolean, string?)
	if not Net.allow(player, "Shop.Prompt", 1, 3) then
		return false, "Slow down!"
	end
	local key = if type(payload) == "table" then payload.Product else nil
	local product = if type(key) == "string" then PRODUCTS[key] else nil
	if type(product) ~= "table" or type(product.Id) ~= "number" then
		return false, "Bad request"
	end
	if product.Id == 0 then
		return false, "Coming soon!"
	end
	MarketplaceService:PromptProductPurchase(player, product.Id)
	return true, nil
end

function MonetizationService.Init()
	Net.handle("Shop.PromptPass", promptPass)
	Net.handle("Shop.PromptProduct", promptProduct)
	MarketplaceService.ProcessReceipt = processReceipt
end

function MonetizationService.Start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local key = passById[passId]
		if purchased and key and player.Parent then
			grantPass(player, key, true)
		end
	end)
	Players.PlayerAdded:Connect(checkPasses)
	for _, player in Players:GetPlayers() do
		task.spawn(checkPasses, player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		ownedPasses[player] = nil
	end)
end

return MonetizationService
