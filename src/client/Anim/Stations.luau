--!strict
--[[
	Client-side station registry + local animation of station parts.

	Stations are Models tagged "Station" (src/map/Equipment/init.luau). Under
	StreamingEnabled they come and go, so entries are created from
	CollectionService signals and dropped when streamed out.

	Animated children (all animated locally, never replicated):
	  Mover    PivotTo(rest + MoverTravel * frac * scale)   (bars, stacks, seats)
	  Spinner  rotate about the pivot's local X at SpinRate x speed (or phase-
	           locked to a pedalling rider)
	  Swinger  damped pendulum about the pivot's local X, kicked per hit
	When nobody drives a station it eases back to its rest CFrames and sleeps.

		Stations.start()
		local e = Stations.get(stationId)
		Stations.drive(e, frac, scale, spinSpeed, spinDir, now)
		Stations.sync(e, phase)        -- phase-locked spinners (bike crank)
		Stations.impulse(e, strength)  -- punch the bag
		Stations.step(dt, now)         -- once per frame (AnimationController)
]]

local CollectionService = game:GetService("CollectionService")

export type Spinner = { model: Model, rest: CFrame, rate: number, angle: number }

export type Entry = {
	model: Model,
	id: string,
	stationType: string,
	soundAt: BasePart?,
	mover: Model?,
	moverRest: CFrame,
	moverCenter: Vector3,
	travel: Vector3,
	spinners: { Spinner },
	minRate: number,
	swinger: Model?,
	swingRest: CFrame,
	swingAngle: number,
	swingVel: number,
	swingK: number,
	swingDamp: number,
	swingMax: number,
	swingKick: number,
	-- live state
	frac: number,
	applied: number,
	scale: number,
	spinSpeed: number,
	spinDir: number,
	synced: boolean,
	syncPhase: number,
	drivenAt: number,
	awake: boolean,
	resolvedAt: number,
}

local Stations = {}

Stations.byId = {} :: { [string]: Entry }
local byModel: { [Model]: Entry } = {}
local awake: { Entry } = {}

local TWO_PI = 2 * math.pi

local function part(model: Model, name: string): BasePart?
	local p = model:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p :: BasePart else nil
end

-- (Re)reads the animated children. Safe to call again if a child streamed late.
local function resolve(e: Entry)
	local model = e.model
	e.resolvedAt = os.clock()
	e.soundAt = part(model, "PromptPart") or part(model, "UserSpot")
	local mover = model:FindFirstChild("Mover")
	if mover and mover:IsA("Model") and e.mover ~= mover then
		local m = mover :: Model
		e.mover = m
		e.moverRest = m:GetPivot()
		local box = m:GetBoundingBox()
		e.moverCenter = box.Position
	end
	local travel = model:GetAttribute("MoverTravel")
	e.travel = if typeof(travel) == "Vector3" then travel :: Vector3 else Vector3.zero
	if #e.spinners == 0 then
		local minRate = math.huge
		for _, child in model:GetChildren() do
			if child.Name == "Spinner" and child:IsA("Model") then
				local m = child :: Model
				local rate = m:GetAttribute("SpinRate")
				local r = if type(rate) == "number" and rate > 0 then rate else 8
				table.insert(e.spinners, { model = m, rest = m:GetPivot(), rate = r, angle = 0 })
				minRate = math.min(minRate, r)
			end
		end
		e.minRate = if minRate < math.huge then minRate else 8
	end
	local swinger = model:FindFirstChild("Swinger")
	if swinger and swinger:IsA("Model") and e.swinger ~= swinger then
		e.swinger = swinger :: Model
		e.swingRest = (swinger :: Model):GetPivot()
	end
end

local function register(inst: Instance)
	if not inst:IsA("Model") or byModel[inst :: Model] then
		return
	end
	local model = inst :: Model
	local id = model:GetAttribute("StationId")
	local stationType = model:GetAttribute("StationType")
	if type(id) ~= "string" or type(stationType) ~= "string" then
		return
	end
	local speedBag = stationType == "SpeedBag"
	local period = if speedBag then 0.34 else 1.7
	local e: Entry = {
		model = model,
		id = id,
		stationType = stationType,
		soundAt = nil,
		mover = nil,
		moverRest = CFrame.identity,
		moverCenter = Vector3.zero,
		travel = Vector3.zero,
		spinners = {},
		minRate = 8,
		swinger = nil,
		swingRest = CFrame.identity,
		swingAngle = 0,
		swingVel = 0,
		swingK = (2 * math.pi / period) ^ 2,
		swingDamp = if speedBag then 7 else 1.5,
		swingMax = if speedBag then 1.1 else 0.32,
		swingKick = if speedBag then 6.5 else 0.85,
		frac = 0,
		applied = 0,
		scale = 1,
		spinSpeed = 0,
		spinDir = 1,
		synced = false,
		syncPhase = 0,
		drivenAt = 0,
		awake = false,
		resolvedAt = 0,
	}
	resolve(e)
	byModel[model] = e
	Stations.byId[id] = e
end

local function unregister(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	local e = byModel[inst :: Model]
	if not e then
		return
	end
	byModel[inst :: Model] = nil
	if Stations.byId[e.id] == e then
		Stations.byId[e.id] = nil
	end
	local i = table.find(awake, e)
	if i then
		table.remove(awake, i)
	end
end

function Stations.start()
	CollectionService:GetInstanceAddedSignal("Station"):Connect(register)
	CollectionService:GetInstanceRemovedSignal("Station"):Connect(unregister)
	for _, inst in CollectionService:GetTagged("Station") do
		register(inst)
	end
end

function Stations.get(id: string?): Entry?
	if not id then
		return nil
	end
	local e = Stations.byId[id]
	if not e then
		return nil
	end
	if not e.model.Parent then
		unregister(e.model)
		return nil
	end
	-- a child may have streamed in after the model (non-atomic edge cases)
	if (not e.mover or not e.soundAt) and os.clock() - e.resolvedAt > 1 then
		resolve(e)
	end
	return e
end

local function wake(e: Entry)
	if not e.awake then
		e.awake = true
		table.insert(awake, e)
	end
end

-- Called every frame by the actor using the station.
function Stations.drive(e: Entry, frac: number, scale: number, spinSpeed: number, spinDir: number, now: number)
	e.frac = frac
	e.scale = scale
	e.spinSpeed = spinSpeed
	e.spinDir = spinDir
	e.synced = false
	e.drivenAt = now
	wake(e)
end

function Stations.sync(e: Entry, phase: number)
	e.synced = true
	e.syncPhase = phase
end

function Stations.impulse(e: Entry, strength: number)
	if not e.swinger then
		return
	end
	e.swingVel += e.swingKick * strength
	wake(e)
end

-- Current Mover centre (world) for a given fraction of travel.
function Stations.barWorld(e: Entry, frac: number, scale: number): Vector3?
	if not e.mover then
		return nil
	end
	return e.moverCenter + e.travel * frac * scale
end

local function pivot(m: Model, cf: CFrame)
	if m.Parent then
		m:PivotTo(cf)
	end
end

function Stations.step(dt: number, now: number)
	for i = #awake, 1, -1 do
		local e = awake[i]
		if not e.model.Parent then
			table.remove(awake, i)
			e.awake = false
			continue
		end
		local driven = now - e.drivenAt < 0.15
		if not driven then
			e.frac = e.frac * math.exp(-6 * dt)
			if math.abs(e.frac) < 0.002 then
				e.frac = 0
			end
			e.spinSpeed *= math.exp(-1.6 * dt)
			e.synced = false
		end

		-- mover
		local mover = e.mover
		if mover and math.abs(e.frac * e.scale - e.applied) > 1e-4 then
			e.applied = e.frac * e.scale
			pivot(mover, e.moverRest + e.travel * e.applied)
		end

		-- spinners
		local spinning = false
		for _, s in e.spinners do
			if e.synced then
				s.angle = e.syncPhase * (s.rate / e.minRate)
				spinning = true
			elseif e.spinSpeed > 0.2 then
				s.angle = (s.angle + s.rate * e.spinSpeed * dt) % (TWO_PI * 64)
				spinning = true
			elseif s.angle ~= 0 then
				-- wind down forward to the next full turn, then rest exactly
				local goal = math.ceil(s.angle / TWO_PI - 1e-6) * TWO_PI
				s.angle = math.min(goal, s.angle + math.max(1.2, s.rate * e.spinSpeed) * dt)
				if goal - s.angle < 1e-3 then
					s.angle = 0
					pivot(s.model, s.rest)
					continue
				end
				spinning = true
			else
				continue
			end
			pivot(s.model, s.rest * CFrame.Angles(e.spinDir * s.angle, 0, 0))
		end

		-- swinger (semi-implicit Euler, sub-stepped for the fast speed bag)
		local swinger = e.swinger
		local swinging = false
		if swinger and (e.swingAngle ~= 0 or e.swingVel ~= 0) then
			local steps = math.clamp(math.ceil(dt / 0.008), 1, 6)
			local h = dt / steps
			for _ = 1, steps do
				local acc = -e.swingK * e.swingAngle - e.swingDamp * e.swingVel
				e.swingVel += acc * h
				e.swingAngle = math.clamp(e.swingAngle + e.swingVel * h, -e.swingMax, e.swingMax)
			end
			if math.abs(e.swingAngle) < 5e-4 and math.abs(e.swingVel) < 5e-3 then
				e.swingAngle, e.swingVel = 0, 0
				pivot(swinger, e.swingRest)
			else
				swinging = true
				pivot(swinger, e.swingRest * CFrame.Angles(e.swingAngle, 0, 0))
			end
		end

		if not driven and e.frac == 0 and e.applied == 0 and not spinning and not swinging then
			e.awake = false
			table.remove(awake, i)
		end
	end
end

return Stations
