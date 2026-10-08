--!strict
--[[
	DataService: session-locked player data with autosave, retries and replication.

	Storage: DataStore "PlayerData_v1", key "u_<UserId>", value { Data, Lock }.
	The lock ({ JobId, Time }) prevents two servers editing the same save. A lock
	older than LOCK_STALE seconds is considered abandoned and is taken over.

	Mutate data ONLY through this API so the client replica stays in sync:
	  DataService.get(player)                    -> PlayerData? (nil until loaded)
	  DataService.waitFor(player, timeout?)      -> PlayerData?
	  DataService.set(player, {"Cash"}, 100)
	  DataService.increment(player, {"Stats", "Strength"}, 12.5) -> new value
	  DataService.update(player, {"Owned", "Gear"}, function(old) ... return new end)
	  DataService.replicate(player, {"Missions"}) -- after mutating a nested table in place

	If the DataStore is unavailable (Studio without API access, outage), the
	player gets a temporary profile that is never saved, and is told so.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DataSchema = require(Shared.DataSchema)
local Net = require(Shared.Util.Net)
local Signal = require(Shared.Util.Signal)
local TableUtil = require(Shared.Util.TableUtil)

type PlayerData = DataSchema.PlayerData
type Path = { any }

local STORE_NAME = "PlayerData_v1"
local LOCK_STALE = 30 * 60
local AUTOSAVE_INTERVAL = 90
local LOAD_ATTEMPTS = if RunService:IsStudio() then 2 else 5
local NON_REPLICATED = { Purchases = true }

type Profile = {
	Data: PlayerData,
	Key: string,
	Persist: boolean, -- false => never saved (temporary profile)
	Saving: boolean,
	Released: boolean,
	JoinClock: number,
}

local DataService = {}
DataService.Priority = 0

DataService.Loaded = Signal.new() :: Signal.Signal<Player, PlayerData>
DataService.Releasing = Signal.new() :: Signal.Signal<Player, PlayerData>
DataService.Changed = Signal.new() :: Signal.Signal<Player, Path, any>

local profiles: { [Player]: Profile } = {}
local pending: { [Player]: { { any } } } = {}
local store: DataStore? = nil

local initRemote: RemoteEvent
local patchRemote: RemoteEvent

---------------------------------------------------------------------------
-- Snapshot / replication
---------------------------------------------------------------------------
local function snapshot(data: PlayerData): { [string]: any }
	local out = {}
	for k, v in data :: any do
		if not NON_REPLICATED[k] then
			out[k] = TableUtil.deepCopy(v)
		end
	end
	return out
end

local function queuePatch(player: Player, path: Path, value: any)
	if NON_REPLICATED[path[1]] then
		return
	end
	local q = pending[player]
	if not q then
		q = {}
		pending[player] = q
	end
	-- drop earlier patches that this one fully overwrites
	for i = #q, 1, -1 do
		local old = q[i][1] :: Path
		if #old >= #path then
			local covered = true
			for j = 1, #path do
				if old[j] ~= path[j] then
					covered = false
					break
				end
			end
			if covered then
				table.remove(q, i)
			end
		end
	end
	table.insert(q, { table.clone(path), TableUtil.deepCopy(value) })
end

local lastFlush = 0
local function flush()
	local now = os.clock()
	if now - lastFlush < 0.1 then
		return
	end
	lastFlush = now
	for player, q in pending do
		if #q > 0 and player.Parent then
			patchRemote:FireClient(player, q)
		end
	end
	table.clear(pending)
end

---------------------------------------------------------------------------
-- DataStore plumbing
---------------------------------------------------------------------------
local function migrate(data: { [string]: any }): { [string]: any }
	-- Version 1 is the first schema. Future migrations go here, e.g.
	-- if data.Version < 2 then ... data.Version = 2 end
	data.Version = DataSchema.Version
	return data
end

local function loadFromStore(key: string): (boolean, { [string]: any }?)
	local ds = store
	if not ds then
		return false, nil
	end
	for attempt = 1, LOAD_ATTEMPTS do
		local lockedBy: { [string]: any }? = nil
		local loaded: { [string]: any }? = nil
		local steal = attempt >= 3
		local ok, err = pcall(function()
			ds:UpdateAsync(key, function(old: any)
				local record = if type(old) == "table" then old else {}
				local lock = record.Lock
				if
					not steal
					and type(lock) == "table"
					and lock.JobId ~= game.JobId
					and os.time() - (tonumber(lock.Time) or 0) < LOCK_STALE
				then
					lockedBy = lock
					return nil -- cancel the write, try again later
				end
				record.Lock = { JobId = game.JobId, Time = os.time() }
				loaded = if type(record.Data) == "table" then record.Data else nil
				return record
			end)
		end)
		if ok and not lockedBy then
			return true, loaded
		end
		if not ok then
			warn(`[DataService] load attempt {attempt} failed for {key}: {err}`)
			local msg = tostring(err)
			if string.find(msg, "403") or string.find(msg, "API") or string.find(msg, "Studio") then
				return false, nil -- API access disabled; don't spin
			end
		end
		task.wait(if lockedBy then 4 else math.min(2 ^ attempt, 10))
	end
	return false, nil
end

local function saveProfile(player: Player, profile: Profile, release: boolean): boolean
	local ds = store
	if not profile.Persist or not ds then
		return true
	end
	if profile.Saving then
		-- let the in-flight save finish, then save again with the final state
		local t0 = os.clock()
		while profile.Saving and os.clock() - t0 < 15 do
			task.wait(0.2)
		end
	end
	profile.Saving = true
	local data = profile.Data
	data.PlaySeconds += math.floor(os.clock() - profile.JoinClock)
	profile.JoinClock = os.clock()
	local stolen = false
	local ok, err = false, nil
	for attempt = 1, 3 do
		ok, err = pcall(function()
			ds:UpdateAsync(profile.Key, function(old: any)
				local record = if type(old) == "table" then old else {}
				local lock = record.Lock
				if type(lock) == "table" and lock.JobId ~= game.JobId then
					stolen = true
					return nil
				end
				record.Data = data
				record.Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
				return record
			end)
		end)
		if ok then
			break
		end
		task.wait(attempt * 1.5)
	end
	profile.Saving = false
	if stolen then
		warn(`[DataService] lock for {player.Name} was taken by another server; no longer saving here`)
		profile.Persist = false
		return false
	end
	if not ok then
		warn(`[DataService] save failed for {player.Name}: {err}`)
	end
	return ok
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------
function DataService.get(player: Player): PlayerData?
	local p = profiles[player]
	return if p then p.Data else nil
end

function DataService.waitFor(player: Player, timeout: number?): PlayerData?
	local t0 = os.clock()
	local limit = timeout or 30
	while player.Parent and os.clock() - t0 < limit do
		local p = profiles[player]
		if p then
			return p.Data
		end
		task.wait(0.1)
	end
	return nil
end

function DataService.isPersistent(player: Player): boolean
	local p = profiles[player]
	return p ~= nil and p.Persist
end

function DataService.set(player: Player, path: Path, value: any)
	local p = profiles[player]
	if not p then
		return
	end
	TableUtil.setPath(p.Data :: any, path, value)
	queuePatch(player, path, value)
	DataService.Changed:Fire(player, path, value)
end

function DataService.increment(player: Player, path: Path, delta: number): number
	local p = profiles[player]
	if not p then
		return 0
	end
	local current = TableUtil.getPath(p.Data :: any, path)
	local new = (if type(current) == "number" then current else 0) + delta
	DataService.set(player, path, new)
	return new
end

function DataService.update(player: Player, path: Path, fn: (any) -> any)
	local p = profiles[player]
	if not p then
		return
	end
	local old = TableUtil.getPath(p.Data :: any, path)
	DataService.set(player, path, fn(old))
end

-- Call after mutating a nested table in place.
function DataService.replicate(player: Player, path: Path)
	local p = profiles[player]
	if not p then
		return
	end
	local value = TableUtil.getPath(p.Data :: any, path)
	queuePatch(player, path, value)
	DataService.Changed:Fire(player, path, value)
end

function DataService.save(player: Player)
	local p = profiles[player]
	if p then
		task.spawn(saveProfile, player, p, false)
	end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	local key = "u_" .. player.UserId
	local ok, raw = loadFromStore(key)
	if not player.Parent then
		-- left while loading: release the lock we may have taken
		if ok and store then
			pcall(function()
				(store :: DataStore):UpdateAsync(key, function(old: any)
					if type(old) == "table" and type(old.Lock) == "table" and old.Lock.JobId == game.JobId then
						old.Lock = nil
						return old
					end
					return nil
				end)
			end)
		end
		return
	end

	local data: { [string]: any }
	if ok and raw then
		data = migrate(raw)
	else
		data = TableUtil.deepCopy(DataSchema.Default) :: any
	end
	TableUtil.reconcile(data, DataSchema.Default :: any)
	local now = os.time()
	if data.FirstJoin == 0 then
		data.FirstJoin = now
	end
	data.LastJoin = now

	local profile: Profile = {
		Data = data :: any,
		Key = key,
		Persist = ok,
		Saving = false,
		Released = false,
		JoinClock = os.clock(),
	}
	profiles[player] = profile
	initRemote:FireClient(player, snapshot(profile.Data))
	DataService.Loaded:Fire(player, profile.Data)

	if not ok then
		task.delay(4, function()
			if player.Parent then
				local Notify = require(script.Parent.Parent.Core.Notify)
				Notify.toast(
					player,
					"Progress not saving",
					"Roblox data services are unavailable right now. You can play, but progress this session won't be saved.",
					"Warning"
				)
			end
		end)
	end
end

local function release(player: Player)
	local p = profiles[player]
	if not p or p.Released then
		return
	end
	p.Released = true
	DataService.Releasing:Fire(player, p.Data)
	task.wait() -- let Releasing listeners write final values
	saveProfile(player, p, true)
	profiles[player] = nil
	pending[player] = nil
end

function DataService.Init()
	initRemote = Net.event("DataInit")
	patchRemote = Net.event("DataPatch")

	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable: " .. tostring(result))
	end

	Net.handle("Data.Get", function(player)
		local p = profiles[player]
		if not p then
			return false, "loading"
		end
		return true, snapshot(p.Data)
	end)
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(release)

	RunService.Heartbeat:Connect(flush)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			local list = {}
			for player, profile in profiles do
				table.insert(list, { player, profile })
			end
			for _, entry in list do
				if entry[1].Parent and not entry[2].Released then
					task.spawn(saveProfile, entry[1], entry[2], false)
					task.wait(AUTOSAVE_INTERVAL / math.max(#list, 1) * 0.5)
				end
			end
		end
	end)

	game:BindToClose(function()
		local remaining = 0
		for player in profiles do
			remaining += 1
			task.spawn(function()
				release(player)
				remaining -= 1
			end)
		end
		local t0 = os.clock()
		while remaining > 0 and os.clock() - t0 < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
