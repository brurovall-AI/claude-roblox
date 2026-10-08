--!strict
--[[
	Server-side gameplay event bus. Services fire semantic events; missions,
	achievements, analytics and competitions listen without coupling.

	Events.fire(player, "Rep:Strength", 1, { Quality = 3 })
	Events.on("DuelWin", function(player, amount, meta) ... end)
	Events.any(function(player, key, amount, meta) ... end)

	Standard keys:
	  Rep, Rep:<Stat>, PerfectRep, ComboReached (amount = combo), TrainCash (amount)
	  LevelUp (amount = levels gained), RankUp, Rebirth
	  BoostBought, BoostUsed, ItemBought, EventJoined, EventPodium, EventWin
	  DuelWin, DuelPlayed, TournamentWin, PartyRep, CourseFinish, NewStationToday
	  AreaVisited, EmoteUsed, DailyClaimed, DailyMissionDone
]]

local Events = {}

type Listener = (player: Player, amount: number, meta: { [string]: any }?) -> ()
type AnyListener = (player: Player, key: string, amount: number, meta: { [string]: any }?) -> ()

local byKey: { [string]: { Listener } } = {}
local anyListeners: { AnyListener } = {}

function Events.on(key: string, fn: Listener)
	local list = byKey[key]
	if not list then
		list = {}
		byKey[key] = list
	end
	table.insert(list, fn)
end

function Events.any(fn: AnyListener)
	table.insert(anyListeners, fn)
end

function Events.fire(player: Player, key: string, amount: number?, meta: { [string]: any }?)
	local n = amount or 1
	local list = byKey[key]
	if list then
		for _, fn in list do
			task.spawn(fn, player, n, meta)
		end
	end
	for _, fn in anyListeners do
		task.spawn(fn, player, key, n, meta)
	end
end

return Events
