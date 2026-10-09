--!strict
--[[
	BoostService: drinking boosts from the bag and keeping timers tidy.

		Boost.Use { Id }                         (request)  -> (ok, message?)
		BoostService.use(player, id)             -> (ok, message?)   consumes one from BoostInventory
		BoostService.canUse(player, id)          -> (ok, message?)   stack-cap check only (no inventory)
		BoostService.remaining(player, id)       -> seconds left on an active boost

	Data: data.BoostInventory[id] = unused count, data.Boosts[id] = expiry (os.time).
	Using a boost extends its timer by Duration, capped at Boosts.MaxStack from now.
	Expired entries are removed periodically (and on join) so the replica stays small;
	MultiplierService already ignores expired entries, so cleanup is cosmetic.

	Events: BoostUsed (meta { Id }). Notify.event "BoostUsed" { Id, Expiry } for client effects.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosts = require(Shared.Config.Boosts)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Util.Net)

local DataService = require(script.Parent.DataService)
local Events = require(script.Parent.Parent.Core.Events)
local Notify = require(script.Parent.Parent.Core.Notify)

local BoostService = {}
BoostService.Priority = 30

local CLEANUP_INTERVAL = 5
-- A boost can't be drunk once less than this much stack room is left.
local MIN_ROOM = 60

function BoostService.remaining(player: Player, id: string): number
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local expiry = data.Boosts[id]
	return if expiry then math.max(0, expiry - os.time()) else 0
end

function BoostService.canUse(player: Player, id: string): (boolean, string?)
	local def = Boosts.Defs[id]
	if not def then
		return false, "That boost doesn't exist."
	end
	if BoostService.remaining(player, id) > Boosts.MaxStack - MIN_ROOM then
		return false, `{def.Name} is already stacked to the {Format.clock(Boosts.MaxStack)} max.`
	end
	return true, nil
end

function BoostService.use(player: Player, id: string): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "Your data is still loading."
	end
	local def = Boosts.Defs[id]
	if not def then
		return false, "That boost doesn't exist."
	end
	local have = data.BoostInventory[id] or 0
	if have < 1 then
		return false, `You don't have any {def.Name}.`
	end
	local ok, err = BoostService.canUse(player, id)
	if not ok then
		return false, err
	end

	local now = os.time()
	local current = data.Boosts[id]
	local base = if current and current > now then current else now
	local expiry = math.min(now + Boosts.MaxStack, base + def.Duration)

	DataService.set(player, { "BoostInventory", id }, if have - 1 > 0 then have - 1 else nil)
	DataService.set(player, { "Boosts", id }, expiry)
	Events.fire(player, "BoostUsed", 1, { Id = id })
	Notify.event(player, "BoostUsed", { Id = id, Expiry = expiry })
	Notify.toast(player, def.Name, `{def.Description} · {Format.clock(expiry - now)}`, "Success")
	return true, nil
end

-- Removes expired (or no longer configured) boosts. Toasts only for boosts that
-- ran out during this session, not ones that expired while offline.
local function cleanup(player: Player, announce: boolean)
	local data = DataService.get(player)
	if not data then
		return
	end
	local now = os.time()
	local expired: { string } = {}
	for id, expiry in data.Boosts do
		if type(expiry) ~= "number" or expiry <= now or Boosts.Defs[id] == nil then
			table.insert(expired, id)
		end
	end
	for _, id in expired do
		local expiry = data.Boosts[id]
		DataService.set(player, { "Boosts", id }, nil)
		local def = Boosts.Defs[id]
		if announce and def and type(expiry) == "number" and now - expiry <= CLEANUP_INTERVAL * 3 then
			Notify.toast(player, `{def.Name} wore off`, "Grab another at the Juice Bar.", "Info")
		end
	end
end

function BoostService.Init()
	Net.handle("Boost.Use", function(player: Player, payload: any)
		if not Net.allow(player, "Boost.Use", 2, 4) then
			return false, "Slow down!"
		end
		if type(payload) ~= "table" then
			return false, "Bad request"
		end
		local id = payload.Id
		if type(id) ~= "string" or #id == 0 or #id > 32 then
			return false, "Bad request"
		end
		return BoostService.use(player, id)
	end)
end

function BoostService.Start()
	DataService.Loaded:Connect(function(player: Player)
		cleanup(player, false)
	end)
	for _, player in Players:GetPlayers() do
		cleanup(player, false)
	end
	task.spawn(function()
		while true do
			task.wait(CLEANUP_INTERVAL)
			for _, player in Players:GetPlayers() do
				cleanup(player, true)
			end
		end
	end)
end

return BoostService
