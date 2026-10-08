--!strict
--[[
	ProgressionService: the single entry point for everything that makes a
	player stronger or richer. Other services call these instead of editing
	data directly so level-ups, rank-ups, counters and feedback stay consistent.

	  ProgressionService.award(player, reward, source)   -- Rewards.Reward bundle
	  ProgressionService.addStat(player, "Strength", 12.5)
	  ProgressionService.addXP(player, 120)
	  ProgressionService.addCash(player, 500, "Train")
	  ProgressionService.spend(player, { Currency = "Cash", Amount = 2000 }) -> boolean
	  ProgressionService.count(player, "DuelWins", 1)
	  ProgressionService.best(player, "SprintBest", 8.71, true)  -- lower is better
	  ProgressionService.power(player), .rank(player)
	  ProgressionService.rebirth(player) -> (ok, err)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local Boosts = require(Config.Boosts)
local Companions = require(Config.Companions)
local Cosmetics = require(Config.Cosmetics)
local Currency = require(Config.Currency)
local DataSchema = require(Shared.DataSchema)
local Progression = require(Config.Progression)
local Ranks = require(Config.Ranks)
local Rewards = require(Config.Rewards)
local Signal = require(Shared.Util.Signal)
local Stats = require(Config.Stats)
local Net = require(Shared.Util.Net)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local Events = require(script.Parent.Parent.Core.Events)
local Notify = require(script.Parent.Parent.Core.Notify)

local ProgressionService = {}
ProgressionService.Priority = 10

-- Fired after any stat changes (CharacterService refreshes speed/scale/nameplate).
ProgressionService.StatsChanged = Signal.new() :: Signal.Signal<Player>
ProgressionService.LevelChanged = Signal.new() :: Signal.Signal<Player, number>
ProgressionService.RankChanged = Signal.new() :: Signal.Signal<Player, Ranks.RankDef>

local lastRank: { [Player]: number } = {}

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------
function ProgressionService.power(player: Player): number
	local data = DataService.get(player)
	return if data then Progression.power(data.Stats :: any) else 0
end

function ProgressionService.rank(player: Player): Ranks.RankDef
	return Ranks.forPower(ProgressionService.power(player))
end

function ProgressionService.balance(player: Player, currency: Currency.CurrencyId): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	return (data :: any)[currency] or 0
end

function ProgressionService.canAfford(player: Player, cost: Currency.Cost): boolean
	return ProgressionService.balance(player, cost.Currency) >= cost.Amount
end

---------------------------------------------------------------------------
-- Mutations
---------------------------------------------------------------------------
function ProgressionService.spend(player: Player, cost: Currency.Cost): boolean
	if cost.Amount <= 0 then
		return true
	end
	if not ProgressionService.canAfford(player, cost) then
		return false
	end
	DataService.increment(player, { cost.Currency }, -cost.Amount)
	return true
end

function ProgressionService.count(player: Player, key: string, delta: number): number
	return DataService.increment(player, { "Counters", key }, delta)
end

-- Records a personal best. Returns true if it was a new best.
function ProgressionService.best(player: Player, key: string, value: number, lowerIsBetter: boolean): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	local old = data.Counters[key]
	local better = old == nil or old == 0 or (if lowerIsBetter then value < old else value > old)
	if better then
		DataService.set(player, { "Counters", key }, value)
	end
	return better
end

local function checkRank(player: Player)
	local rank = ProgressionService.rank(player)
	local prev = lastRank[player]
	lastRank[player] = rank.Index
	if prev and rank.Index > prev then
		Notify.event(player, "RankUp", { Rank = rank.Index, Name = rank.Name })
		Notify.others(player, "PlayerRankUp", { UserId = player.UserId, Rank = rank.Index, Name = rank.Name })
		Events.fire(player, "RankUp", rank.Index)
		ProgressionService.RankChanged:Fire(player, rank)
		if rank.Name == "Olympian" then
			ProgressionService.award(player, { Title = "Olympian", Aura = "Halo" }, "Rank")
		end
	end
end

function ProgressionService.addStat(player: Player, stat: string, amount: number)
	if not Stats.isStat(stat) or amount <= 0 then
		return
	end
	DataService.increment(player, { "Stats", stat }, amount)
	ProgressionService.StatsChanged:Fire(player)
	checkRank(player)
end

function ProgressionService.addXP(player: Player, amount: number)
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return
	end
	local xp = data.XP + math.floor(amount)
	local level = data.Level
	local gained = 0
	while level < Progression.MaxLevel and xp >= Progression.xpToNext(level) do
		xp -= Progression.xpToNext(level)
		level += 1
		gained += 1
	end
	if level >= Progression.MaxLevel then
		xp = math.min(xp, Progression.xpToNext(level))
	end
	DataService.set(player, { "XP" }, xp)

	-- weekly leaderboard accumulator
	local week = DataSchema.weekNumber()
	if data.Weekly.Week ~= week then
		DataService.set(player, { "Weekly" }, { Week = week, XP = 0 })
	end
	DataService.increment(player, { "Weekly", "XP" }, math.floor(amount))

	if gained > 0 then
		DataService.set(player, { "Level" }, level)
		Notify.event(player, "LevelUp", { Level = level, Gained = gained })
		Events.fire(player, "LevelUp", gained, { Level = level })
		ProgressionService.LevelChanged:Fire(player, level)
	end
end

function ProgressionService.addCash(player: Player, amount: number, source: string?)
	if amount <= 0 then
		return
	end
	local n = math.floor(amount)
	DataService.increment(player, { "Cash" }, n)
	ProgressionService.count(player, "CashEarned", n)
	if source == "Train" then
		Events.fire(player, "TrainCash", n)
	end
end

local function grantOwned(player: Player, category: string, id: string): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	local owned = (data.Owned :: any)[category]
	if owned[id] then
		return false
	end
	DataService.set(player, { "Owned", category, id }, true)
	return true
end

-- Grants a reward bundle. Shows a single summary toast unless `quiet`.
function ProgressionService.award(player: Player, reward: Rewards.Reward, source: string, quiet: boolean?)
	local parts = {}
	if reward.Cash and reward.Cash > 0 then
		ProgressionService.addCash(player, reward.Cash, source)
		table.insert(parts, "$" .. Format.short(reward.Cash))
	end
	if reward.XP and reward.XP > 0 then
		ProgressionService.addXP(player, reward.XP)
		table.insert(parts, Format.short(reward.XP) .. " XP")
	end
	if reward.Trophies and reward.Trophies > 0 then
		DataService.increment(player, { "Trophies" }, reward.Trophies)
		table.insert(parts, Format.short(reward.Trophies) .. " Trophies")
	end
	if reward.RebirthTokens and reward.RebirthTokens > 0 then
		DataService.increment(player, { "RebirthTokens" }, reward.RebirthTokens)
		table.insert(parts, reward.RebirthTokens .. " Rebirth Token" .. (if reward.RebirthTokens > 1 then "s" else ""))
	end
	if reward.Boosts then
		for id, count in reward.Boosts do
			local def = Boosts.Defs[id]
			if def and count > 0 then
				DataService.increment(player, { "BoostInventory", id }, count)
				table.insert(parts, `{def.Name} x{count}`)
			end
		end
	end
	if reward.Title and Cosmetics.Titles[reward.Title] and grantOwned(player, "Titles", reward.Title) then
		table.insert(parts, `Title "{Cosmetics.Titles[reward.Title].Text}"`)
	end
	if reward.Emote and Cosmetics.Emotes[reward.Emote] and grantOwned(player, "Emotes", reward.Emote) then
		table.insert(parts, `Emote "{Cosmetics.Emotes[reward.Emote].Name}"`)
	end
	if reward.Aura and Cosmetics.Auras[reward.Aura] and grantOwned(player, "Auras", reward.Aura) then
		table.insert(parts, `Aura "{Cosmetics.Auras[reward.Aura].Name}"`)
	end
	if reward.Decor and Cosmetics.Decor[reward.Decor] and grantOwned(player, "Decor", reward.Decor) then
		table.insert(parts, `Decor "{Cosmetics.Decor[reward.Decor].Name}"`)
	end
	if reward.Companion and Companions.Defs[reward.Companion] and grantOwned(player, "Companions", reward.Companion) then
		table.insert(parts, `Companion "{Companions.Defs[reward.Companion].Name}"`)
	end
	if not quiet and #parts > 0 then
		Notify.event(player, "Reward", { Source = source, Items = parts })
	end
end

---------------------------------------------------------------------------
-- Rebirth
---------------------------------------------------------------------------
function ProgressionService.rebirth(player: Player): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "Data not loaded"
	end
	local req = Progression.rebirthLevelReq(data.Rebirths)
	if data.Level < req then
		return false, `Reach level {req} to rebirth`
	end
	local rebirths = data.Rebirths + 1
	DataService.set(player, { "Rebirths" }, rebirths)
	DataService.set(player, { "Level" }, 1)
	DataService.set(player, { "XP" }, 0)
	DataService.set(player, { "Cash" }, 0)
	DataService.set(player, { "Stats" }, { Strength = 0, Endurance = 0, Speed = 0, Agility = 0, Energy = 0 })
	DataService.set(player, { "Boosts" }, {})
	DataService.set(player, { "Energy" }, Progression.maxEnergy(0))
	lastRank[player] = 1
	ProgressionService.award(player, { RebirthTokens = Progression.Rebirth.TokensPerRebirth, Title = "Reborn" }, "Rebirth", true)
	Events.fire(player, "Rebirth", rebirths)
	Notify.event(player, "Rebirth", { Rebirths = rebirths, Mult = Progression.rebirthMult(rebirths) })
	Notify.others(player, "PlayerRebirth", { UserId = player.UserId, Rebirths = rebirths })
	ProgressionService.StatsChanged:Fire(player)
	ProgressionService.LevelChanged:Fire(player, 1)
	return true, nil
end

function ProgressionService.Init()
	Net.handle("Progression.Rebirth", function(player)
		return ProgressionService.rebirth(player)
	end)
end

function ProgressionService.Start()
	DataService.Loaded:Connect(function(player)
		lastRank[player] = ProgressionService.rank(player).Index
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRank[player] = nil
	end)
end

return ProgressionService
