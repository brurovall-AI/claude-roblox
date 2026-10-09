--!strict
--[[
	ShopService: every soft-currency purchase.

		Shop.Buy { Category, Id, Count?, Use? }   -> (ok, message)
		Shop.UnlockVIP                            -> (ok, message)

	Categories: Gear | Companion | Aura | Title | Emote | Decor | Boost.
	  * The item must exist in config and be for sale (Gear Price / Cost present;
	    a nil Cost means "earned, not sold" and the reply says where to earn it).
	  * Level / rebirth requirements, not already owned.
	  * Boosts stack into BoostInventory: Count 1..10 at Boosts.price(def, level)
	    Cash each; Use = true (Count 1) drinks it right away ("Buy & Drink").
	  * Payment through ProgressionService.spend, grants through DataService.

	Auto-equip after buying: gear when its slot is empty or the new tier is
	higher; companions / emotes / decor when a slot is free; auras when none is
	worn; titles when the default title is worn.

	Shop.UnlockVIP spends Areas.VIP.TrophyCost trophies once and sets
	data.Unlocks.VIPTrophy (VIP pass holders already have access).

	Events: ItemBought (meta { Category, Id, Currency, Amount }), BoostBought
	(amount = count, meta { Id }). Success toasts come from here; failures are
	returned as the message for the client to show.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local Areas = require(Config.Areas)
local Boosts = require(Config.Boosts)
local Companions = require(Config.Companions)
local Cosmetics = require(Config.Cosmetics)
local Currency = require(Config.Currency)
local DataSchema = require(Shared.DataSchema)
local Format = require(Shared.Util.Format)
local Gear = require(Config.Gear)
local Net = require(Shared.Util.Net)

local BoostService = require(script.Parent.BoostService)
local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local Events = require(script.Parent.Parent.Core.Events)
local Notify = require(script.Parent.Parent.Core.Notify)

type PlayerData = DataSchema.PlayerData

local ShopService = {}
ShopService.Priority = 40

local MAX_BOOST_COUNT = 10

type Item = {
	Category: string,
	Id: string,
	Name: string,
	OwnedKey: string,
	Cost: Currency.Cost?,
	Source: string?,
	LevelReq: number,
	RebirthReq: number,
}

-- Where items that aren't for sale come from (shown in the refusal message).
local SOURCE_HINT: { [string]: string } = {
	Tournament = "Win a gym tournament to earn it.",
	Rank = "Reach Olympian rank to earn it.",
	Achievement = "It's an achievement reward.",
	Daily = "It's a daily reward.",
	Rebirth = "It's a rebirth reward.",
	VIP = "It comes with VIP membership.",
	Default = "Everyone starts with it.",
}

local function resolve(category: string, id: string): Item?
	if category == "Gear" then
		local d = Gear.get(id)
		if d then
			return { Category = category, Id = id, Name = d.Name, OwnedKey = "Gear", Cost = { Currency = "Cash", Amount = d.Price }, LevelReq = d.LevelReq, RebirthReq = 0 }
		end
	elseif category == "Companion" then
		local d = Companions.Defs[id]
		if d then
			return { Category = category, Id = id, Name = d.Name, OwnedKey = "Companions", Cost = d.Cost, LevelReq = d.LevelReq, RebirthReq = d.RebirthReq }
		end
	elseif category == "Aura" then
		local d = Cosmetics.Auras[id]
		if d then
			return { Category = category, Id = id, Name = d.Name, OwnedKey = "Auras", Cost = d.Cost, Source = d.Source, LevelReq = 1, RebirthReq = 0 }
		end
	elseif category == "Title" then
		local d = Cosmetics.Titles[id]
		if d then
			return { Category = category, Id = id, Name = `Title "{d.Text}"`, OwnedKey = "Titles", Cost = d.Cost, Source = d.Source, LevelReq = 1, RebirthReq = 0 }
		end
	elseif category == "Emote" then
		local d = Cosmetics.Emotes[id]
		if d then
			return { Category = category, Id = id, Name = `Emote "{d.Name}"`, OwnedKey = "Emotes", Cost = d.Cost, Source = d.Source, LevelReq = 1, RebirthReq = 0 }
		end
	elseif category == "Decor" then
		local d = Cosmetics.Decor[id]
		if d then
			return { Category = category, Id = id, Name = d.Name, OwnedKey = "Decor", Cost = d.Cost, Source = d.Source, LevelReq = 1, RebirthReq = 0 }
		end
	end
	return nil
end

local function amountText(currency: string, amount: number): string
	if currency == "Cash" then
		return "$" .. Format.commas(amount)
	end
	local def = (Currency.Defs :: any)[currency]
	return `{Format.commas(amount)} {if def then def.Name else currency}`
end

local function shortfall(player: Player, cost: Currency.Cost): string
	local need = cost.Amount - ProgressionService.balance(player, cost.Currency)
	return `You need {amountText(cost.Currency, math.max(1, math.ceil(need)))} more.`
end

---------------------------------------------------------------------------
-- Auto-equip
---------------------------------------------------------------------------
local function appendIfRoom(player: Player, key: string, list: { string }, max: number, id: string)
	if #list < max and not table.find(list, id) then
		local copy = table.clone(list)
		table.insert(copy, id)
		DataService.set(player, { "Equipped", key }, copy)
	end
end

local function autoEquip(player: Player, data: PlayerData, item: Item)
	local eq = data.Equipped
	if item.Category == "Gear" then
		local def = Gear.get(item.Id) :: Gear.GearDef
		local current = eq.Gear[def.Slot]
		local curDef = if current then Gear.get(current) else nil
		if not curDef or not data.Owned.Gear[current :: string] or def.Tier > curDef.Tier then
			DataService.set(player, { "Equipped", "Gear", def.Slot }, item.Id)
		end
	elseif item.Category == "Companion" then
		appendIfRoom(player, "Companions", eq.Companions, Companions.slots(data.Rebirths), item.Id)
	elseif item.Category == "Emote" then
		appendIfRoom(player, "Emotes", eq.Emotes, Cosmetics.MaxEquippedEmotes, item.Id)
	elseif item.Category == "Decor" then
		appendIfRoom(player, "Decor", eq.Decor, Cosmetics.MaxDecor, item.Id)
	elseif item.Category == "Aura" then
		if eq.Aura == "" then
			DataService.set(player, { "Equipped", "Aura" }, item.Id)
		end
	elseif item.Category == "Title" then
		if eq.Title == "" or eq.Title == "Newcomer" then
			DataService.set(player, { "Equipped", "Title" }, item.Id)
		end
	end
end

---------------------------------------------------------------------------
-- Purchases
---------------------------------------------------------------------------
local function buyBoost(player: Player, data: PlayerData, id: string, rawCount: any, use: boolean): (boolean, string)
	local def = Boosts.Defs[id]
	if not def then
		return false, "That boost doesn't exist."
	end
	local count = 1
	if rawCount ~= nil then
		if type(rawCount) ~= "number" or rawCount ~= rawCount or rawCount % 1 ~= 0 or rawCount < 1 or rawCount > MAX_BOOST_COUNT then
			return false, "Bad amount"
		end
		count = rawCount
	end
	if use then
		if count ~= 1 then
			return false, "Bad amount"
		end
		-- refuse before charging if the timer is already at the stack cap
		local ok, err = BoostService.canUse(player, id)
		if not ok then
			return false, err or "Can't drink that right now."
		end
	end
	local cost: Currency.Cost = { Currency = "Cash", Amount = Boosts.price(def, data.Level) * count }
	if not ProgressionService.spend(player, cost) then
		return false, shortfall(player, cost)
	end
	DataService.increment(player, { "BoostInventory", id }, count)
	Events.fire(player, "BoostBought", count, { Id = id, Currency = cost.Currency, Amount = cost.Amount })
	if use then
		local ok, err = BoostService.use(player, id)
		if not ok then
			-- still in the bag; tell the player why it wasn't drunk
			Notify.toast(player, `{def.Name} added to your bag`, err, "Info")
		end
	else
		Notify.toast(player, "Added to your bag", `{def.Name} x{count}`, "Success")
	end
	return true, def.Name
end

local function buy(player: Player, payload: any): (boolean, string)
	if not Net.allow(player, "Shop.Buy", 3, 6) then
		return false, "Slow down!"
	end
	if type(payload) ~= "table" then
		return false, "Bad request"
	end
	local category, id = payload.Category, payload.Id
	if type(category) ~= "string" or type(id) ~= "string" or #id == 0 or #id > 40 then
		return false, "Bad request"
	end
	local data = DataService.get(player)
	if not data then
		return false, "Your data is still loading."
	end
	if category == "Boost" then
		return buyBoost(player, data, id, payload.Count, payload.Use == true)
	end

	local item = resolve(category, id)
	if not item then
		return false, "That item doesn't exist."
	end
	local owned = (data.Owned :: any)[item.OwnedKey]
	if type(owned) == "table" and owned[id] then
		return false, "You already own this."
	end
	local cost = item.Cost
	if not cost then
		local hint = if item.Source then SOURCE_HINT[item.Source] else nil
		return false, "This isn't sold in the shop. " .. (hint or "")
	end
	if data.Level < item.LevelReq then
		return false, `Reach level {item.LevelReq} to unlock this.`
	end
	if data.Rebirths < item.RebirthReq then
		return false, `Requires Rebirth {item.RebirthReq}.`
	end
	if not ProgressionService.spend(player, cost) then
		return false, shortfall(player, cost)
	end

	DataService.set(player, { "Owned", item.OwnedKey, id }, true)
	autoEquip(player, data, item)
	ProgressionService.count(player, "ItemsBought", 1)
	Events.fire(player, "ItemBought", 1, { Category = category, Id = id, Currency = cost.Currency, Amount = cost.Amount })
	Notify.toast(player, "Purchased", item.Name, "Success")
	return true, item.Name
end

local function unlockVIP(player: Player): (boolean, string)
	if not Net.allow(player, "Shop.UnlockVIP", 1, 3) then
		return false, "Slow down!"
	end
	local data = DataService.get(player)
	if not data then
		return false, "Your data is still loading."
	end
	if data.Unlocks.VIPTrophy then
		return false, "The VIP Club is already unlocked."
	end
	if player:GetAttribute("VIP") == true then
		return false, "Your VIP membership already includes the VIP Club."
	end
	local area = Areas.get("VIP")
	local price = area and area.TrophyCost
	if not price then
		return false, "The VIP Club can't be unlocked with trophies."
	end
	local cost: Currency.Cost = { Currency = "Trophies", Amount = price }
	if not ProgressionService.spend(player, cost) then
		return false, shortfall(player, cost)
	end
	DataService.set(player, { "Unlocks", "VIPTrophy" }, true)
	Events.fire(player, "ItemBought", 1, { Category = "VIPClub", Id = "VIP", Currency = cost.Currency, Amount = cost.Amount })
	Notify.event(player, "VIPUnlocked", { Source = "Trophies" })
	return true, "VIP Club"
end

function ShopService.Init()
	Net.handle("Shop.Buy", buy)
	Net.handle("Shop.UnlockVIP", function(player: Player)
		return unlockVIP(player)
	end)
end

return ShopService
