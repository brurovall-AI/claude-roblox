--!strict
--[[
	TrainingService: the core loop. A player triggers a station's "TrainPrompt",
	the server validates and parks the character on the station (anchored at
	UserSpot), the client plays the minigame and reports graded reps, and the
	server re-checks cadence, owns the combo, spends energy and awards gains.

	World contract (ARCHITECTURE section 5): Models tagged "Station" with
	attributes StationType, Tier, StationId, AreaId; children UserSpot,
	PromptPart > ProximityPrompt "TrainPrompt". Attribute InUse = UserId while a
	player trains; InUse < 0 = held by an ambient NPC (counts as free).

	Character attributes published for every client's AnimationController:
	  TrainingPose (Config/Stations Pose id), TrainingStation (StationId),
	  RepCount (+1 per accepted rep), Cadence (0..1)
	Player attribute: Training = StationType while training.

	Remotes:
	  TrainingRep   (client -> server)  { Quality = 0..3 }
	  TrainingEvent (server -> client)  ("Started", payload) | ("Rep", result) | ("Stopped", summary)
	  Request "Training.Stop"           leave the station

	API (ARCHITECTURE section 8):
	  TrainingService.isTraining(player) -> boolean
	  TrainingService.stop(player, reason)
	  TrainingService.stationOf(player) -> Model?
	  TrainingService.Started / Stopped  Signal<Player, string>
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local Areas = require(Config.Areas)
local Formulas = require(Shared.Formulas)
local Minigames = require(Config.Minigames)
local Net = require(Shared.Util.Net)
local Progression = require(Config.Progression)
local Signal = require(Shared.Util.Signal)
local Stations = require(Config.Stations)
local Tiers = require(Config.Tiers)
local Trove = require(Shared.Util.Trove)

local CharacterService = require(script.Parent.CharacterService)
local DataService = require(script.Parent.DataService)
local EmoteService = require(script.Parent.EmoteService)
local MultiplierService = require(script.Parent.MultiplierService)
local ProgressionService = require(script.Parent.ProgressionService)
local Events = require(script.Parent.Parent.Core.Events)
local Notify = require(script.Parent.Parent.Core.Notify)
local HeldProps = require(script.Parent.Parent.Visuals.HeldProps)

local TrainingService = {}
TrainingService.Priority = 60

TrainingService.Started = Signal.new() :: Signal.Signal<Player, string>
TrainingService.Stopped = Signal.new() :: Signal.Signal<Player, string>

local MAX_START_DISTANCE = 12
local IDLE_TIMEOUT = 20
local DRIFT_LIMIT = 4
local MIN_INTERVAL_TOLERANCE = 0.8
local COMBO_MILESTONE = 5

-- Poses where the Humanoid must not try to balance (lying, reclined, hanging, seated).
local PLATFORM_POSES: { [string]: boolean } = {
	Bench = true,
	SeatedPress = true,
	LegPress = true,
	Pulldown = true,
	Hang = true,
	Row = true,
	Bike = true,
	Yoga = true,
	SitRelax = true,
}

-- Reasons where the character is gone or was moved elsewhere on purpose:
-- release it where it is instead of placing it in front of the station.
local NO_REPOSITION: { [string]: boolean } = {
	Died = true,
	Left = true,
	CharacterRemoved = true,
	Moved = true,
}

-- Cadence target per quality (continuous stations loop faster when you nail it).
local CADENCE_TARGET = { [0] = 0.35, [1] = 0.6, [2] = 0.85, [3] = 1.0 }

type Session = {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	station: Model,
	prompt: ProximityPrompt?,
	stationId: string,
	stationType: string,
	def: Stations.StationDef,
	tier: number,
	kind: Minigames.MinigameKind,
	minInterval: number,
	spot: CFrame,
	returnCFrame: CFrame,
	startedAt: number,
	lastRepAt: number,
	lastActivity: number,
	combo: number,
	reps: number,
	cadence: number,
	gainStat: number,
	gainXP: number,
	gainCash: number,
	stationUsed: boolean,
	stopping: boolean,
	trove: Trove.Trove,
}

local sessions: { [Player]: Session } = {}
local occupant: { [Model]: Player } = {}

local repRemote: RemoteEvent
local eventRemote: RemoteEvent

---------------------------------------------------------------------------
-- Optional World-slice services (looked up at runtime, never required at load
-- so missing modules or require cycles cannot break training).
---------------------------------------------------------------------------
local optionalCache: { [string]: any } = {}

local function optional(name: string): any
	local cached = optionalCache[name]
	if cached ~= nil then
		return if cached == false then nil else cached
	end
	local inst = (script.Parent :: Instance):FindFirstChild(name)
	if not inst or not inst:IsA("ModuleScript") then
		return nil -- not created yet; look again next time
	end
	local loader: (ModuleScript) -> any = require :: any
	local ok, mod = pcall(loader, inst :: ModuleScript)
	optionalCache[name] = if ok and type(mod) == "table" then mod else false
	return if ok and type(mod) == "table" then mod else nil
end

local function canAccessArea(player: Player, areaId: string): (boolean, string?)
	if areaId == "" then
		return true, nil
	end
	local AreaService = optional("AreaService")
	if not AreaService or type(AreaService.canAccess) ~= "function" then
		return true, nil
	end
	local fn: (Player, string) -> (boolean, string?) = AreaService.canAccess
	local ok, allowed, reason = pcall(fn, player, areaId)
	if not ok then
		return true, nil -- never block training on another slice's error
	end
	return allowed ~= false, reason
end

local function evictNpc(station: Model)
	local NPCService = optional("NPCService")
	if NPCService and type(NPCService.evict) == "function" then
		local fn: (Model) -> () = NPCService.evict
		local ok, err = pcall(fn, station)
		if not ok then
			warn("[TrainingService] NPCService.evict failed: " .. tostring(err))
		end
	end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function round(x: number, step: number): number
	return math.floor(x / step + 0.5) * step
end

local function stationFromPrompt(prompt: ProximityPrompt): Model?
	local node: Instance? = prompt.Parent
	for _ = 1, 4 do
		if not node then
			return nil
		end
		if node:IsA("Model") and CollectionService:HasTag(node, "Station") then
			return node :: Model
		end
		node = node.Parent
	end
	return nil
end

local function stationPrompt(station: Model): ProximityPrompt?
	local pp = station:FindFirstChild("PromptPart")
	local prompt = pp and pp:FindFirstChild("TrainPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		return prompt :: ProximityPrompt
	end
	return nil
end

local function aliveParts(player: Player): (Model?, Humanoid?, BasePart?)
	local char = player.Character
	if not char or not char.Parent then
		return nil, nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid?
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root or hum.Health <= 0 then
		return nil, nil, nil
	end
	return char, hum, root
end

local function inUseBy(station: Model): number?
	local v = station:GetAttribute("InUse")
	return if type(v) == "number" then v else nil
end

-- A station is free when nobody holds it, an NPC holds it (< 0), or the
-- recorded user no longer has a live session on it (stale attribute).
local function isFree(station: Model): boolean
	local id = inUseBy(station)
	if id == nil or id < 0 then
		return true
	end
	local p = occupant[station]
	return p == nil or sessions[p] == nil or p.UserId ~= id
end

local function energyCost(player: Player, def: Stations.StationDef, tier: number): number
	if def.Restores then
		return 0
	end
	local r = Formulas.rep(def.Id, tier, 2, 0, MultiplierService.forStat(player, def.Stat))
	return math.max(0, -r.EnergyDelta)
end

local function maxEnergy(data: any): number
	return Progression.maxEnergy(data.Stats.Energy)
end

-- Minigame params for this player: tier difficulty + Lucky Chalk window boost.
local function minigameParams(player: Player, kind: Minigames.MinigameKind, difficulty: number): { [string]: number }
	local p = Minigames.params(kind, difficulty)
	local mult = math.clamp(MultiplierService.windowMult(player), 1, 2)
	if mult > 1 then
		local soft = 1 + (mult - 1) * 0.5
		if p.Perfect then
			p.Perfect = math.min(p.Perfect * mult, 0.2)
		end
		if p.Good then
			p.Good = math.min(math.max(p.Good * mult, (p.Perfect or 0) + 0.02), 0.32)
		end
		if p.Ok then
			p.Ok = math.min(math.max(p.Ok * mult, (p.Good or 0) + 0.02), 0.45)
		end
		if p.BandSize then
			p.BandSize = math.min(p.BandSize * soft, 0.5)
		end
		if p.TimePerInput then
			p.TimePerInput *= soft
		end
		local minRate: number?, maxRate: number?, ideal: number? = p.MinRate, p.MaxRate, p.Ideal
		if minRate and maxRate and ideal then
			p.MinRate = ideal - (ideal - minRate) * soft
			p.MaxRate = ideal + (maxRate - ideal) * soft
		end
	end
	return p
end

local function exitCFrame(s: Session): CFrame
	local spot = s.spot.Position
	local back = s.returnCFrame.Position
	local flat = Vector3.new(back.X - spot.X, 0, back.Z - spot.Z)
	if flat.Magnitude > 1.5 and flat.Magnitude <= MAX_START_DISTANCE + 2 then
		return CFrame.lookAt(back, Vector3.new(spot.X, back.Y, spot.Z))
	end
	-- fallback: a few studs in front of the station's footprint, at standing height
	local pivot = s.station:GetPivot()
	local look = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local standHeight = s.humanoid.HipHeight + s.root.Size.Y / 2
	local pos = Vector3.new(spot.X, pivot.Position.Y + standHeight, spot.Z) - look * 3.5
	return CFrame.lookAt(pos, pos + look)
end

---------------------------------------------------------------------------
-- Stop
---------------------------------------------------------------------------
function TrainingService.isTraining(player: Player): boolean
	return sessions[player] ~= nil
end

function TrainingService.stationOf(player: Player): Model?
	local s = sessions[player]
	return if s then s.station else nil
end

function TrainingService.stop(player: Player, reason: string?)
	local s = sessions[player]
	if not s or s.stopping then
		return
	end
	local why = reason or "Request"
	s.stopping = true
	sessions[player] = nil
	if occupant[s.station] == player then
		occupant[s.station] = nil
	end
	s.trove:Clean()

	local char, hum, root = s.character, s.humanoid, s.root
	if char.Parent then
		char:SetAttribute("TrainingPose", nil)
		char:SetAttribute("TrainingStation", nil)
		char:SetAttribute("RepCount", nil)
		char:SetAttribute("Cadence", nil)
		HeldProps.detach(char)
	end
	player:SetAttribute("Training", nil)
	CharacterService.clearOverride(player, "Training")

	if hum.Parent and hum.Health > 0 then
		hum.PlatformStand = false
		hum.AutoRotate = true
	end
	if root.Parent then
		if not NO_REPOSITION[why] and root.Anchored then
			char:PivotTo(exitCFrame(s))
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = false
	end

	if inUseBy(s.station) == player.UserId then
		s.station:SetAttribute("InUse", nil)
	end
	if s.prompt and s.prompt.Parent then
		s.prompt.Enabled = true
	end

	if player.Parent then
		eventRemote:FireClient(player, "Stopped", {
			Reason = why,
			StationId = s.stationId,
			Reps = s.reps,
			Stat = s.def.Stat,
			StatGain = s.gainStat,
			XP = s.gainXP,
			Cash = s.gainCash,
			Seconds = os.clock() - s.startedAt,
		})
	end
	TrainingService.Stopped:Fire(player, why)
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------
local function refuse(player: Player, title: string, text: string?, kind: Notify.ToastKind?)
	Notify.toast(player, title, text, kind or "Warning")
end

local function begin(player: Player, station: Model)
	if not Net.allow(player, "TrainStart", 2, 3) then
		return
	end
	if sessions[player] then
		return -- already on a station (the client hides other prompts meanwhile)
	end
	local char, hum, root = aliveParts(player)
	if not char or not hum or not root then
		return
	end
	if player:GetAttribute("Busy") or char:GetAttribute("TrainingPose") ~= nil then
		refuse(player, "Not right now", "Finish what you're doing first.", "Info")
		return
	end
	local data = DataService.get(player)
	if not data then
		refuse(player, "One moment", "Your profile is still loading.", "Info")
		return
	end

	-- station contract
	local stationType = station:GetAttribute("StationType")
	local tierAttr = station:GetAttribute("Tier")
	local stationId = station:GetAttribute("StationId")
	local def = if type(stationType) == "string" then Stations.get(stationType) else nil
	local spot = station:FindFirstChild("UserSpot")
	if not def or type(tierAttr) ~= "number" or type(stationId) ~= "string" or not spot or not spot:IsA("BasePart") then
		warn(`[TrainingService] malformed station {station:GetFullName()}`)
		return
	end
	local spotPart = spot :: BasePart
	local tier = math.clamp(math.floor(tierAttr), 1, #Tiers.List)
	local tierDef = Tiers.get(tier)
	local areaAttr = station:GetAttribute("AreaId")
	local areaId = if type(areaAttr) == "string" then areaAttr else ""
	local area = Areas.get(areaId)

	-- distance (prompt range is ~9; allow lag + large avatars)
	local prompt = stationPrompt(station)
	local ref = if prompt and prompt.Parent and prompt.Parent:IsA("BasePart") then (prompt.Parent :: BasePart).Position else spotPart.Position
	if (root.Position - ref).Magnitude > MAX_START_DISTANCE and (root.Position - spotPart.Position).Magnitude > MAX_START_DISTANCE then
		return
	end

	-- requirements
	local levelReq = math.max(tierDef.LevelReq, if area then area.LevelReq else 1)
	local rebirthReq = math.max(tierDef.RebirthReq, if area then area.RebirthReq else 0)
	if data.Rebirths < rebirthReq then
		refuse(player, `{tierDef.Name} equipment`, `Requires {rebirthReq} rebirth{if rebirthReq == 1 then "" else "s"}.`, "Warning")
		return
	end
	if data.Level < levelReq then
		refuse(player, `{tierDef.Name} equipment`, `Reach level {levelReq} to train on this {def.Name}.`, "Warning")
		return
	end
	local allowed, why = canAccessArea(player, areaId)
	if not allowed then
		refuse(player, "Area locked", why or `You can't train in {if area then area.Name else "this area"} yet.`, "Warning")
		return
	end
	local cost = energyCost(player, def, tier)
	if cost > 0 and data.Energy < cost then
		refuse(player, "Out of energy", "Grab a drink at the Juice Bar in the Lounge, or recharge in the Recovery Studio.", "Warning")
		return
	end

	-- station availability (NPCs step aside for players)
	if not isFree(station) then
		refuse(player, "Station in use", "Someone is already training here.", "Info")
		return
	end
	local held = inUseBy(station)
	if held and held < 0 then
		evictNpc(station)
	end
	-- evict may yield: re-validate everything that could have changed
	if sessions[player] or not isFree(station) or player.Character ~= char or hum.Health <= 0 then
		return
	end
	EmoteService.stop(player)

	local now = os.clock()
	local kind = def.Minigame
	local s: Session = {
		player = player,
		character = char,
		humanoid = hum,
		root = root,
		station = station,
		prompt = prompt,
		stationId = stationId,
		stationType = def.Id,
		def = def,
		tier = tier,
		kind = kind,
		minInterval = Minigames.minRepInterval(kind, tierDef.Difficulty),
		spot = spotPart.CFrame,
		returnCFrame = root.CFrame,
		startedAt = now,
		lastRepAt = 0,
		lastActivity = now,
		combo = 0,
		reps = 0,
		cadence = if def.Continuous then 0.4 else 0,
		gainStat = 0,
		gainXP = 0,
		gainCash = 0,
		stationUsed = false,
		stopping = false,
		trove = Trove.new(),
	}
	sessions[player] = s
	occupant[station] = player
	station:SetAttribute("InUse", player.UserId)
	if prompt then
		prompt.Enabled = false
	end

	-- park the character (break a seat weld first so the seat doesn't come along)
	local seat = hum.SeatPart
	if seat then
		local weld = seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
	end
	hum.Sit = false
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	char:PivotTo(s.spot)
	CharacterService.setOverride(player, "Training", { WalkSpeed = 0, JumpHeight = 0 })
	hum.AutoRotate = false
	hum.PlatformStand = PLATFORM_POSES[def.Pose] == true

	char:SetAttribute("TrainingPose", def.Pose)
	char:SetAttribute("TrainingStation", stationId)
	char:SetAttribute("RepCount", 0)
	char:SetAttribute("Cadence", s.cadence)
	player:SetAttribute("Training", def.Id)
	if def.Held then
		local ok, err = pcall(HeldProps.attach, char, def.Held, tier)
		if not ok then
			warn("[TrainingService] held props failed: " .. tostring(err))
		end
	end

	-- lifetime hooks
	s.trove:Connect(hum.Died, function()
		TrainingService.stop(player, "Died")
	end)
	s.trove:Connect(char.AncestryChanged, function(_, parent)
		if not parent then
			TrainingService.stop(player, "CharacterRemoved")
		end
	end)
	s.trove:Connect(station.AncestryChanged, function()
		if not station:IsDescendantOf(Workspace) then
			TrainingService.stop(player, "StationRemoved")
		end
	end)
	s.trove:Connect(station:GetAttributeChangedSignal("InUse"), function()
		local id = inUseBy(station)
		if id ~= player.UserId then
			TrainingService.stop(player, "StationTaken")
		end
	end)
	s.trove:Connect(player:GetAttributeChangedSignal("Busy"), function()
		if player:GetAttribute("Busy") then
			TrainingService.stop(player, "Busy")
		end
	end)

	local energyMax = maxEnergy(data)
	eventRemote:FireClient(player, "Started", {
		StationId = stationId,
		StationType = def.Id,
		Name = def.Name,
		Verb = def.Verb,
		Tier = tier,
		TierName = tierDef.Name,
		Stat = def.Stat,
		Kind = kind,
		Params = minigameParams(player, kind, tierDef.Difficulty),
		MinInterval = s.minInterval,
		Pose = def.Pose,
		Continuous = def.Continuous,
		Restores = def.Restores,
		Sound = def.Sound,
		AreaId = areaId,
		Energy = data.Energy,
		MaxEnergy = energyMax,
		EnergyCost = cost,
	})
	TrainingService.Started:Fire(player, def.Id)
end

---------------------------------------------------------------------------
-- Reps
---------------------------------------------------------------------------
local function onRep(player: Player, payload: any)
	local s = sessions[player]
	if not s or s.stopping then
		return
	end
	if not Net.allow(player, "TrainRep", 8, 12) then
		return
	end
	if type(payload) ~= "table" then
		return
	end
	local q = payload.Quality
	if type(q) ~= "number" or q ~= q or q % 1 ~= 0 or q < 0 or q > 3 then
		return
	end
	local quality = q :: number
	local now = os.clock()
	if now - s.lastRepAt < s.minInterval * MIN_INTERVAL_TOLERANCE then
		return -- faster than any legit minigame allows: drop silently
	end
	local data = DataService.get(player)
	if not data then
		return
	end

	-- combo (server-owned): Good/Perfect continue, Ok/Miss break
	local combo = if quality > Minigames.ComboBreakQuality then s.combo + 1 else 0
	local mult = MultiplierService.forStat(player, s.def.Stat)
	local result = Formulas.rep(s.stationType, s.tier, quality, combo, mult)

	-- energy
	local energy = data.Energy
	local energyMax = maxEnergy(data)
	if result.EnergyDelta < 0 then
		local cost = -result.EnergyDelta
		if energy < cost then
			TrainingService.stop(player, "OutOfEnergy")
			return
		end
		energy -= cost
	else
		energy = math.min(energyMax, energy + result.EnergyDelta)
	end
	energy = round(math.max(0, energy), 0.01)
	if energy ~= data.Energy then
		DataService.set(player, { "Energy" }, energy)
	end

	s.combo = combo
	s.reps += 1
	s.lastRepAt = now
	s.lastActivity = now

	-- gains
	ProgressionService.addStat(player, result.Stat, result.StatGain)
	ProgressionService.addXP(player, result.XP)
	ProgressionService.addCash(player, result.Cash, "Train")
	s.gainStat += result.StatGain
	s.gainXP += result.XP
	s.gainCash += result.Cash

	-- counters
	ProgressionService.count(player, "Reps", 1)
	if quality == 3 then
		ProgressionService.count(player, "PerfectReps", 1)
	end
	if s.def.Restores then
		ProgressionService.count(player, "RecoveryReps", 1)
	end
	if combo > 0 then
		ProgressionService.best(player, "BestCombo", combo, false)
	end

	-- events
	local meta = { Quality = quality, StationType = s.stationType, Stat = result.Stat, Tier = s.tier }
	Events.fire(player, "Rep", 1, meta)
	Events.fire(player, "Rep:" .. result.Stat, 1, meta)
	if quality == 3 then
		Events.fire(player, "PerfectRep", 1, meta)
	end
	if combo > 0 and combo % COMBO_MILESTONE == 0 then
		Events.fire(player, "ComboReached", combo, meta)
	end
	if not s.stationUsed then
		s.stationUsed = true
		Events.fire(player, "StationUsed", 1, { StationType = s.stationType })
	end
	if MultiplierService.partyNearby(player) > 0 then
		Events.fire(player, "PartyRep", 1, meta)
	end

	-- animation attributes
	local char = s.character
	s.cadence = round(math.clamp(s.cadence + (CADENCE_TARGET[quality] - s.cadence) * 0.5, 0, 1), 0.05)
	char:SetAttribute("RepCount", s.reps)
	char:SetAttribute("Cadence", s.cadence)

	eventRemote:FireClient(player, "Rep", {
		Quality = quality,
		Stat = result.Stat,
		Gain = result.StatGain,
		XP = result.XP,
		Cash = result.Cash,
		Combo = combo,
		Energy = energy,
		MaxEnergy = energyMax,
		Reps = s.reps,
	})

	-- stop once the next rep can't be paid for (after delivering this one)
	if result.EnergyDelta < 0 and energy < -result.EnergyDelta then
		task.defer(TrainingService.stop, player, "OutOfEnergy")
	end
end

---------------------------------------------------------------------------
-- Loops
---------------------------------------------------------------------------
-- 4 Hz: idle timeout, drift / teleport detection, character + station health.
local function watchdog()
	local now = os.clock()
	for player, s in sessions do
		if s.stopping then
			continue
		end
		if player.Character ~= s.character or s.humanoid.Health <= 0 or not s.root.Parent then
			TrainingService.stop(player, if s.humanoid.Health <= 0 then "Died" else "CharacterRemoved")
		elseif not s.station:IsDescendantOf(Workspace) then
			TrainingService.stop(player, "StationRemoved")
		elseif not s.root.Anchored or (s.root.Position - s.spot.Position).Magnitude > DRIFT_LIMIT then
			TrainingService.stop(player, "Moved")
		elseif now - s.lastActivity > IDLE_TIMEOUT then
			TrainingService.stop(player, "Idle")
		elseif s.def.Continuous and s.reps > 0 and now - s.lastRepAt > 2.5 and s.cadence > 0.15 then
			-- stopped pedalling: let the loop wind down for everyone watching
			s.cadence = 0.15
			s.character:SetAttribute("Cadence", s.cadence)
		end
	end
end

-- 1 Hz: energy regeneration while not training (or while on a recovery station).
local function regen()
	for _, player in Players:GetPlayers() do
		local data = DataService.get(player)
		if not data then
			continue
		end
		local s = sessions[player]
		local energyMax = maxEnergy(data)
		local energy = data.Energy
		local nextEnergy = energy
		if not s or s.def.Restores then
			nextEnergy = energy + Progression.energyRegen(data.Stats.Energy) * MultiplierService.energyRegenMult(player)
		end
		nextEnergy = round(math.clamp(nextEnergy, 0, energyMax), 0.01)
		if nextEnergy ~= energy then
			DataService.set(player, { "Energy" }, nextEnergy)
		end
	end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function TrainingService.Init()
	repRemote = Net.event("TrainingRep")
	eventRemote = Net.event("TrainingEvent")
	repRemote.OnServerEvent:Connect(onRep)
	Net.handle("Training.Stop", function(player: Player, payload: any)
		if not sessions[player] then
			return true, nil
		end
		local reason = "Request"
		if type(payload) == "table" and payload.Reason == "Jump" then
			reason = "Jump"
		end
		TrainingService.stop(player, reason)
		return true, nil
	end)
end

function TrainingService.Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, player: Player)
		if prompt.Name ~= "TrainPrompt" then
			return
		end
		local station = stationFromPrompt(prompt)
		if station then
			begin(player, station)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		TrainingService.stop(player, "Left")
	end)
	local function onPlayer(player: Player)
		player.CharacterRemoving:Connect(function()
			TrainingService.stop(player, "CharacterRemoved")
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end

	-- stale InUse markers from a previous owner (e.g. hot-reloaded server scripts)
	for _, inst in CollectionService:GetTagged("Station") do
		local id = inst:GetAttribute("InUse")
		if type(id) == "number" and id > 0 then
			inst:SetAttribute("InUse", nil)
		end
	end

	task.spawn(function()
		while true do
			task.wait(0.25)
			watchdog()
		end
	end)
	while true do
		task.wait(1)
		regen()
	end
end

return TrainingService
