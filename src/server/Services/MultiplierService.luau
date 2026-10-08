--!strict
--[[
	MultiplierService: computes every gain multiplier for a player in one place
	so training, competitions and UI previews agree.

		MultiplierService.forStat(player, "Strength") -> Formulas.Multipliers
		MultiplierService.setSocial(player, partyNearby, friendsNearby)  -- social slice
		MultiplierService.setFlag(player, "DoubleCash", true)            -- monetization slice
		MultiplierService.boostActive(player, "Chalk") -> boolean

	Sources: equipped gear (Config/Gear), equipped companions (Config/Companions),
	active boosts (data.Boosts expiry times, Config/Boosts), rebirths, social
	proximity, game-pass flags. A summary is mirrored to the player attribute
	"Multipliers" (JSON) for the Stats window.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local Boosts = require(Config.Boosts)
local Companions = require(Config.Companions)
local Formulas = require(Shared.Formulas)
local Gear = require(Config.Gear)
local Stats = require(Config.Stats)

local DataService = require(script.Parent.DataService)

local MultiplierService = {}
MultiplierService.Priority = 15

type Social = { party: number, friends: number }
local social: { [Player]: Social } = {}
local flags: { [Player]: { [string]: boolean } } = {}

function MultiplierService.setSocial(player: Player, partyNearby: number, friendsNearby: number)
	social[player] = { party = partyNearby, friends = friendsNearby }
end

-- Number of party members currently nearby (for "PartyRep" mission events).
function MultiplierService.partyNearby(player: Player): number
	local s = social[player]
	return if s then s.party else 0
end

function MultiplierService.setFlag(player: Player, flag: string, value: boolean)
	local f = flags[player]
	if not f then
		f = {}
		flags[player] = f
	end
	f[flag] = value
end

function MultiplierService.flag(player: Player, flag: string): boolean
	local f = flags[player]
	return f ~= nil and f[flag] == true
end

function MultiplierService.boostActive(player: Player, boostId: string): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	local expiry = data.Boosts[boostId]
	return expiry ~= nil and expiry > os.time()
end

local function gearMult(data: any, stat: string): number
	local mult = 1
	for _, id in data.Equipped.Gear do
		local def = Gear.get(id)
		if def and def.Stat == stat and data.Owned.Gear[id] then
			mult *= def.Mult
		end
	end
	return mult
end

local function companionMult(data: any, stat: string): number
	local bonus = 0
	for _, id in data.Equipped.Companions do
		local def = Companions.Defs[id]
		if def and data.Owned.Companions[id] and (def.Stat == "All" or def.Stat == stat) then
			bonus += def.Bonus
		end
	end
	return 1 + bonus
end

local function boostMult(player: Player, effect: string, stat: string?): number
	local data = DataService.get(player)
	if not data then
		return 1
	end
	local now = os.time()
	local mult = 1
	for id, expiry in data.Boosts do
		local def = Boosts.Defs[id]
		if def and expiry > now and def.Effect == effect then
			if effect ~= "StatGain" or def.Stat == "All" or def.Stat == stat then
				mult *= def.Mult
			end
		end
	end
	return mult
end

function MultiplierService.forStat(player: Player, stat: string): Formulas.Multipliers
	local m = Formulas.defaultMultipliers()
	local data = DataService.get(player)
	if not data then
		return m
	end
	m.Gear = gearMult(data, stat)
	m.Companion = companionMult(data, stat)
	m.Boost = boostMult(player, "StatGain", stat)
	m.XPBoost = boostMult(player, "XP")
	m.CashBoost = boostMult(player, "Cash")
	m.Rebirths = data.Rebirths
	local s = social[player]
	m.Party = if s then Formulas.socialMult(s.party, s.friends) else 1
	m.DoubleCash = MultiplierService.flag(player, "DoubleCash")
	m.Electrolytes = MultiplierService.boostActive(player, "Electrolytes")
	m.Endurance = data.Stats.Endurance
	return m
end

-- Perfect-window multiplier for minigames (Lucky Chalk boost).
function MultiplierService.windowMult(player: Player): number
	return boostMult(player, "Window")
end

-- Energy regen multiplier (Electrolyte boost).
function MultiplierService.energyRegenMult(player: Player): number
	return boostMult(player, "Energy")
end

local function publish(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local summary = {}
	for _, stat in Stats.Order do
		local m = MultiplierService.forStat(player, stat)
		summary[stat] = math.floor(m.Gear * m.Companion * m.Boost * (1 + 0.35 * m.Rebirths) * m.Party * 100 + 0.5) / 100
	end
	local ok, json = pcall(HttpService.JSONEncode, HttpService, summary)
	if ok then
		player:SetAttribute("Multipliers", json)
	end
end

function MultiplierService.Start()
	Players.PlayerRemoving:Connect(function(p)
		social[p] = nil
		flags[p] = nil
	end)
	task.spawn(function()
		while true do
			for _, p in Players:GetPlayers() do
				publish(p)
			end
			task.wait(3)
		end
	end)
end

return MultiplierService
