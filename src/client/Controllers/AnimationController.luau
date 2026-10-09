--!strict
--[[
	AnimationController: procedural R15 animation for EVERY character near the
	camera (players and NPC models) driven by replicated attributes
	(ARCHITECTURE section 8):

	  TrainingPose     Pose id (Config/Stations) or "ArmWrestle"
	  TrainingStation  StationId -> station parts animated locally (Anim/Stations)
	  RepCount         +1 per rep -> plays one rep cycle (discrete poses)
	  Cadence          0..1 -> loop speed (continuous poses)
	  DuelLean         -1..1 (ArmWrestle)
	  Emote + EmoteStamp   emote programs (Anim/Emotes)

	Motor6D.Transform is written in RunService.PreSimulation, i.e. after the
	Animator has stepped, so procedural poses override (and blend with) the
	default animations. Blends in/out over ~0.25 s, cross-fades between
	programs, restores joints when done, skips R6 rigs and anything farther
	than RANGE studs from the camera.

	The local player's discrete reps are driven by the minigame
	(TrainingController calls localRep on every graded rep) so the motion
	answers the input instantly; everyone else plays a cycle when RepCount
	increments.

	API:
	  AnimationController.localRep(quality)
	  AnimationController.setLocalDriven(on)      -- ignore own RepCount while on
	  AnimationController.setLocalCadence(c?)     -- nil = use the attribute
	  AnimationController.RepPlayed  Signal<Model, string?>  (character, stationId)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared.Config.Cosmetics)
local StationDefs = require(Shared.Config.Stations)
local Signal = require(Shared.Util.Signal)

local Anim = script.Parent.Parent.Anim
local Curves = require(Anim.Curves)
local Emotes = require(Anim.Emotes)
local Poses = require(Anim.Poses)
local Rig = require(Anim.Rig)
local StationAnim = require(Anim.Stations)

local AudioController = require(script.Parent.AudioController)

local AnimationController = {}
AnimationController.Priority = 20

AnimationController.RepPlayed = Signal.new() :: Signal.Signal<Model, string?>

local RANGE = 150
local BLEND = 0.25
local XFADE = 0.25
local REMOTE_SOUND_RANGE = 45
local REMEASURE = 1.5

local player = Players.LocalPlayer

type Actor = {
	model: Model,
	rig: Rig.Rig,
	program: Poses.Program,
	programId: string,
	mode: string, -- "Training" | "Emote"
	weight: number,
	active: boolean,
	t: number,
	repStart: number?,
	repDur: number,
	repIndex: number,
	carry: number,
	lastRepAt: number,
	interval: number,
	quality: number,
	impactIndex: number,
	settleAt: number,
	settleAmp: number,
	effort: number,
	phase: number,
	speed: number,
	cadence: number,
	lean: number,
	repCount: number,
	stationId: string?,
	station: StationAnim.Entry?,
	seed: number,
	isLocal: boolean,
	isNpc: boolean,
	lastSound: number,
	drop: number?,
	probed: boolean,
	emoteStamp: any,
	out: Rig.Out,
	from: Rig.Out?,
	xfade: number,
	ctx: Poses.Ctx,
}

local watched: { [Model]: { RBXScriptConnection } } = {}
local actors: { [Model]: Actor } = {}

local localDriven = false
local localCadence: number? = nil

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

---------------------------------------------------------------------------
-- Joint application
---------------------------------------------------------------------------
-- Writes `out` with weight `w`. When the Animator did not touch a joint this
-- frame (Transform still equals our last write) the base is the rest pose,
-- otherwise we blend from the Animator's output.
local function apply(a: Actor, w: number, mask: { [string]: boolean }?)
	local rig = a.rig
	local written = rig.written
	local from = a.from
	local x = if from then Curves.smooth(a.xfade) else 1
	for _, name in Rig.ORDER do
		local motor = rig.motors[name]
		local target = a.out[name]
		if target and not (mask and mask[name]) then
			if from and x < 1 then
				target = (from[name] or CFrame.identity):Lerp(target, x)
			end
			local cur = motor.Transform
			local last = written[name]
			local base = if last ~= nil and cur == last then CFrame.identity else cur
			local v = if w >= 0.999 then target else base:Lerp(target, w)
			motor.Transform = v
			written[name] = v
		elseif written[name] then
			if motor.Transform == written[name] then
				motor.Transform = CFrame.identity
			end
			written[name] = nil
		end
	end
end

-- Gives every joint we touched back to the Animator / rest pose.
local function release(a: Actor)
	local rig = a.rig
	for name, v in rig.written do
		local motor = rig.motors[name]
		if motor and motor.Parent and motor.Transform == v then
			motor.Transform = CFrame.identity
		end
	end
	table.clear(rig.written)
end

---------------------------------------------------------------------------
-- Actor lifecycle
---------------------------------------------------------------------------
local function newCtx(rig: Rig.Rig, out: Rig.Out, seed: number): Poses.Ctx
	return {
		rig = rig,
		out = out,
		t = 0,
		dt = 0,
		r = -1,
		lift = 0,
		rep = 0,
		quality = 2,
		phase = 0,
		speed = 0.8,
		cadence = 0.5,
		breath = 0,
		effort = 0,
		settle = 0,
		lean = 0,
		seed = seed,
		bar = nil,
		drop = nil,
		stationType = "",
		moving = false,
		mover = 0,
	}
end

local function numberAttr(model: Model, name: string, default: number): number
	local v = model:GetAttribute(name)
	return if type(v) == "number" and v == v then v else default
end

-- Desired program for a model from its attributes.
local function desired(model: Model): (Poses.Program?, string, string)
	local pose = model:GetAttribute("TrainingPose")
	if type(pose) == "string" then
		local p = Poses.get(pose)
		if p then
			return p, pose, "Training"
		end
	end
	local emote = model:GetAttribute("Emote")
	if type(emote) == "string" then
		local def = Cosmetics.Emotes[emote]
		local p = if def then Emotes.get(def.Pose) else nil
		if p then
			return p, emote, "Emote"
		end
	end
	return nil, "", ""
end

local function resetCycle(a: Actor)
	a.t = 0
	a.repStart = nil
	a.carry = 0
	a.lastRepAt = 0
	a.interval = 0
	a.impactIndex = 1
	a.settleAt = -10
	a.drop = nil
	a.probed = false
end

local function evaluate(model: Model)
	local program, id, mode = desired(model)
	local a = actors[model]
	if not program then
		if a then
			a.active = false
		end
		return
	end
	local stationAttr = model:GetAttribute("TrainingStation")
	local stationId = if mode == "Training" and type(stationAttr) == "string" then stationAttr else nil
	if a then
		if a.programId ~= id or a.mode ~= mode then
			-- cross-fade from what is on screen now
			a.from = if a.weight > 0 then table.clone(a.out) else nil
			a.xfade = 0
			a.program = program
			a.programId = id
			a.mode = mode
			resetCycle(a)
		end
		a.active = true
		if a.stationId ~= stationId then
			a.stationId = stationId
			a.station = nil
		end
		return
	end
	local rig = Rig.get(model)
	if not rig then
		return -- R6 or incomplete rig
	end
	local out: Rig.Out = {}
	local seed = math.random() * 100
	local actor: Actor = {
		model = model,
		rig = rig,
		program = program,
		programId = id,
		mode = mode,
		weight = 0,
		active = true,
		t = 0,
		repStart = nil,
		repDur = 1,
		repIndex = 0,
		carry = 0,
		lastRepAt = 0,
		interval = 0,
		quality = 2,
		impactIndex = 1,
		settleAt = -10,
		settleAmp = 0,
		effort = 0,
		phase = math.random() * math.pi * 2,
		speed = 0.8,
		cadence = numberAttr(model, "Cadence", 0.5),
		lean = numberAttr(model, "DuelLean", 0),
		repCount = numberAttr(model, "RepCount", 0),
		stationId = stationId,
		station = nil,
		seed = seed,
		isLocal = model == player.Character,
		isNpc = Players:GetPlayerFromCharacter(model) == nil,
		lastSound = 0,
		drop = nil,
		probed = false,
		emoteStamp = model:GetAttribute("EmoteStamp"),
		out = out,
		from = nil,
		xfade = 1,
		ctx = newCtx(rig, out, seed),
	}
	actors[model] = actor
end

local function currentLift(a: Actor, now: number): number
	local start = a.repStart
	if not start then
		return 0
	end
	local r = (now - start) / a.repDur
	local carry = a.carry * (1 - Curves.smooth(r / 0.25))
	return math.clamp(Curves.lift(r, a.program.Profile) + carry, 0, 1)
end

local function triggerRep(a: Actor, quality: number, now: number)
	local p = a.program
	a.quality = quality
	a.effort = math.min(1, a.effort + 0.08 + 0.04 * quality)
	if p.Kind ~= "Discrete" then
		return
	end
	if a.lastRepAt > 0 then
		local gap = now - a.lastRepAt
		a.interval = if a.interval > 0 then a.interval * 0.6 + gap * 0.4 else gap
	end
	a.lastRepAt = now
	local base = p.RepTime or 1.2
	a.carry = currentLift(a, now)
	a.repStart = now
	a.repDur = if a.interval > 0 then math.clamp(a.interval * 0.92, base * 0.5, base) else base
	a.repIndex += 1
	a.impactIndex = 1
end

local function remoteRepSound(a: Actor)
	local e = a.station
	local now = os.clock()
	if not e or not e.soundAt or now - a.lastSound < 0.8 then
		return
	end
	a.lastSound = now
	local cam = Workspace.CurrentCamera
	if cam and (e.soundAt.Position - cam.CFrame.Position).Magnitude > REMOTE_SOUND_RANGE then
		return
	end
	local def = StationDefs.get(e.stationType)
	if def then
		-- ambient NPCs sit a little further back in the mix than real players
		AudioController.play(def.Sound, { At = e.soundAt, Volume = if a.isNpc then 0.35 else 0.55 })
	end
end

local function onAttribute(model: Model, attr: string)
	if attr == "TrainingPose" or attr == "Emote" or attr == "TrainingStation" then
		evaluate(model)
		return
	end
	local a = actors[model]
	if not a then
		return
	end
	if attr == "EmoteStamp" then
		local stamp = model:GetAttribute("EmoteStamp")
		if a.mode == "Emote" and stamp ~= nil and stamp ~= a.emoteStamp then
			a.from = if a.weight > 0 then table.clone(a.out) else nil
			a.xfade = 0
			resetCycle(a)
		end
		a.emoteStamp = stamp
	elseif attr == "RepCount" then
		local n = numberAttr(model, "RepCount", 0)
		local prev = a.repCount
		a.repCount = n
		if n > prev and a.mode == "Training" and not (a.isLocal and localDriven) then
			triggerRep(a, 2, os.clock())
			AnimationController.RepPlayed:Fire(model, a.stationId)
			if a.active and a.weight > 0 then
				remoteRepSound(a)
			end
		end
	elseif attr == "Cadence" then
		a.cadence = math.clamp(numberAttr(model, "Cadence", 0.5), 0, 1)
	elseif attr == "DuelLean" then
		a.lean = math.clamp(numberAttr(model, "DuelLean", 0), -1, 1)
	end
end

local function unwatch(model: Model)
	local conns = watched[model]
	if conns then
		for _, c in conns do
			c:Disconnect()
		end
		watched[model] = nil
	end
	local a = actors[model]
	if a then
		release(a)
		actors[model] = nil
	end
end

local function watch(model: Model)
	if watched[model] then
		return
	end
	watched[model] = {
		model.AttributeChanged:Connect(function(attr: string)
			onAttribute(model, attr)
		end),
		model.AncestryChanged:Connect(function(_, parent: Instance?)
			if not parent then
				unwatch(model)
			end
		end),
	}
	evaluate(model)
end

local function onDescendant(inst: Instance)
	if inst:IsA("Humanoid") then
		local parent = inst.Parent
		if parent and parent:IsA("Model") then
			watch(parent :: Model)
		end
	end
end

---------------------------------------------------------------------------
-- Frame step
---------------------------------------------------------------------------
local function probe(a: Actor)
	a.probed = true
	local p = a.program.Probe
	if not p then
		return
	end
	local origin = a.rig.root.CFrame:PointToWorldSpace(p)
	rayParams.FilterDescendantsInstances = { a.model }
	local hit = Workspace:Raycast(origin, Vector3.new(0, -8, 0), rayParams)
	a.drop = if hit then origin.Y - hit.Position.Y else nil
end

local function stepActor(a: Actor, dt: number, now: number, camPos: Vector3)
	local rig = a.rig
	if not Rig.valid(rig) then
		local fresh = Rig.get(a.model)
		if not fresh then
			actors[a.model] = nil
			return
		end
		a.rig = fresh
		a.ctx.rig = fresh
		rig = fresh
	end
	local root = rig.root
	local inRange = (root.Position - camPos).Magnitude <= RANGE
	local goal = if a.active and inRange then 1 else 0
	if goal == 0 and a.weight <= 0 then
		if not a.active then
			release(a)
			actors[a.model] = nil
		elseif next(rig.written) then
			release(a)
		end
		return
	end
	a.weight = math.clamp(a.weight + (if goal > a.weight then dt else -dt) / BLEND, 0, 1)
	if a.from then
		a.xfade = math.min(1, a.xfade + dt / XFADE)
		if a.xfade >= 1 then
			a.from = nil
		end
	end
	if now - rig.measuredAt > REMEASURE then
		Rig.measure(rig)
	end

	local p = a.program
	local c = a.ctx
	a.t += dt
	a.effort = Curves.approach(a.effort, 0, 0.22, dt)
	if not a.probed then
		probe(a)
	end

	-- station (lazy: it may stream in after the attribute)
	local e = a.station
	if a.stationId and (not e or not e.model.Parent) then
		e = StationAnim.get(a.stationId)
		a.station = e
	end

	-- cadence / phase
	local cadence = if a.isLocal and localDriven and localCadence then localCadence else a.cadence
	local speedGoal = Curves.lerp(0.45, 1.15, cadence)
	a.speed = Curves.approach(a.speed, speedGoal, 3, dt)
	if p.Kind ~= "Discrete" then
		local loop = p.Loop or 1
		if p.SpinSync and e and #e.spinners > 0 then
			loop = 2 * math.pi / e.minRate
		end
		local rate = if p.Kind == "Emote" then 1 else a.speed
		a.phase = (a.phase + dt * rate * 2 * math.pi / loop) % (2 * math.pi * 64)
	end

	-- discrete rep cycle
	local r, lift = -1, 0
	local start = a.repStart
	if p.Kind == "Discrete" and start then
		r = (now - start) / a.repDur
		if r >= 1 then
			a.repStart = nil
			a.carry = 0
			if (p.Heavy or 0) > 0 then
				a.settleAt = now
				a.settleAmp = (p.Heavy or 0) * (0.6 + 0.15 * a.quality)
			end
			r = -1
		else
			lift = currentLift(a, now)
			local impacts = p.Impacts
			if impacts and e then
				local nextAt = impacts[a.impactIndex]
				if nextAt and r >= nextAt then
					a.impactIndex += 1
					StationAnim.impulse(e, 0.6 + 0.15 * a.quality)
				end
			end
		end
	end

	local stationType = if e then e.stationType else ""
	local scale = Poses.moverScale(p, stationType)
	c.t = a.t
	c.dt = dt
	c.r = r
	c.lift = lift
	c.rep = a.repIndex
	c.quality = a.quality
	c.phase = a.phase
	c.speed = a.speed
	c.cadence = cadence
	c.breath = Curves.breath(a.t + a.seed, Curves.lerp(3.8, 1.7, a.effort))
	c.effort = a.effort
	c.settle = Curves.settle(now - a.settleAt) * a.settleAmp
	c.lean = a.lean
	c.stationType = stationType
	c.drop = a.drop
	c.mover = if p.Kind == "Discrete" then lift else 0
	c.bar = nil
	if p.UsesBar and e then
		local world = StationAnim.barWorld(e, lift, scale)
		if world then
			c.bar = root.CFrame:PointToObjectSpace(world)
		end
	end
	local v = root.AssemblyLinearVelocity
	c.moving = a.mode == "Emote" and Vector3.new(v.X, 0, v.Z).Magnitude > 1.5

	table.clear(a.out)
	local ok, err = pcall(p.update, c)
	if not ok then
		warn(`[AnimationController] {a.programId} failed: {err}`)
		a.active = false
		return
	end
	apply(a, a.weight, if c.moving then Rig.LOWER else nil)

	-- drive the station's parts while we are visibly on it
	if e and a.mode == "Training" and a.active then
		local spin = if p.Kind == "Discrete" then 0 else a.speed
		StationAnim.drive(e, c.mover, scale, spin, p.SpinDir or 1, now)
		if p.SpinSync then
			StationAnim.sync(e, a.phase)
		end
	end
end

local function step(dt: number)
	local now = os.clock()
	local cam = Workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	for _, a in actors do
		stepActor(a, dt, now, camPos)
	end
	StationAnim.step(dt, now)
end

---------------------------------------------------------------------------
-- Public API (local player)
---------------------------------------------------------------------------
function AnimationController.localRep(quality: number)
	local char = player.Character
	local a = if char then actors[char] else nil
	if a and a.mode == "Training" then
		triggerRep(a, quality, os.clock())
		AnimationController.RepPlayed:Fire(a.model, a.stationId)
	end
end

function AnimationController.setLocalDriven(on: boolean)
	localDriven = on
	if not on then
		localCadence = nil
	end
end

function AnimationController.setLocalCadence(c: number?)
	localCadence = if c then math.clamp(c, 0, 1) else nil
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function AnimationController.Init()
	StationAnim.start()
	RunService.PreSimulation:Connect(step)
end

function AnimationController.Start()
	Workspace.DescendantAdded:Connect(onDescendant)
	for _, d in Workspace:GetDescendants() do
		if d:IsA("Humanoid") then
			onDescendant(d)
		end
	end
	-- the local character re-evaluates "isLocal" on respawn
	player.CharacterAdded:Connect(function(char)
		local a = actors[char]
		if a then
			a.isLocal = true
		end
	end)
end

return AnimationController
