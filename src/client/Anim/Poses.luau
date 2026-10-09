--!strict
--[[
	Training pose programs (one per Pose id in Config/Stations, plus "ArmWrestle").

	A program fills `c.out` (joint name -> Motor6D.Transform, see Anim/Rig) every
	frame from the context the engine prepares:

	  Discrete programs  one cycle per rep. `c.r` = cycle progress 0..1 (-1 when
	                     idle) and `c.lift` = eased displacement from Curves.lift
	                     with the program's Profile. Idle = the ready position.
	  Continuous         `c.phase` (radians) advances at the station cadence.

	Every pose is authored in HumanoidRootPart space (the HRP is anchored at the
	station's UserSpot, see src/map/Equipment/init.luau) with IK for hands on
	bars / handles and feet planted on floors, so it adapts to avatar
	proportions. Programs add breathing (`c.breath`), effort, counter-motion and
	impact settle (`c.settle`) so reps read as physical work.

	Engine-facing fields:
	  RepTime     base cycle seconds (discrete; shortened for fast players)
	  Loop        seconds per cycle at full cadence (continuous)
	  Profile     Curves.lift profile (`up` = outbound share of the cycle)
	  Heavy       0..1 settle strength when the load returns
	  UsesBar     wants `c.bar` = the station Mover centre in HRP space
	  MoverScale  fraction of MoverTravel shown (keeps the bar within reach)
	  Impacts     cycle points where a Swinger receives an impulse
	  SpinSync    continuous phase follows the station crank (bike pedals)
	  SpinDir     Spinner rotation direction (+1 / -1)
	  Probe       HRP-space point cast straight down once to find the floor
	              (`c.drop` = world distance from that point to the ground)
]]

local Curves = require(script.Parent.Curves)
local Rig = require(script.Parent.Rig)

export type Ctx = {
	rig: Rig.Rig,
	out: Rig.Out,
	t: number, -- seconds since the pose started
	dt: number,
	r: number, -- rep cycle progress 0..1, -1 when idle
	lift: number, -- eased rep displacement 0..1
	rep: number, -- rep index (alternate sides)
	quality: number, -- last rep quality 0..3
	phase: number, -- continuous phase (radians)
	speed: number, -- cadence speed factor (~0.5..1.2)
	cadence: number, -- 0..1
	breath: number, -- -1..1
	effort: number, -- 0..1 recent exertion
	settle: number, -- decaying oscillation after a heavy rep
	lean: number, -- DuelLean -1..1
	seed: number,
	bar: Vector3?, -- Mover centre in HRP space (UsesBar)
	drop: number?, -- floor probe result
	stationType: string,
	moving: boolean, -- emotes: the character is walking
	mover: number, -- OUT: fraction of MoverTravel to apply (defaults to lift)
}

export type Program = {
	Kind: string, -- "Discrete" | "Continuous" | "Emote"
	RepTime: number?,
	Loop: number?,
	Profile: Curves.Profile?,
	Heavy: number?,
	UsesBar: boolean?,
	MoverScale: number?,
	MoverScaleFor: { [string]: number }?,
	Impacts: { number }?,
	SpinSync: boolean?,
	SpinDir: number?,
	Probe: Vector3?,
	Duration: number?, -- emotes: one-shot length (nil = looping)
	update: (c: Ctx) -> (),
}

local A = Curves.A
local lerp, v3, smooth, ramp, bump = Curves.lerp, Curves.v3, Curves.smooth, Curves.ramp, Curves.bump
local sin, cos, pi, rad, abs = math.sin, math.cos, math.pi, math.rad, math.abs
local V = Vector3.new

local Poses = {}

---------------------------------------------------------------------------
-- Shared building blocks
---------------------------------------------------------------------------
-- Breathing on the spine and neck; effort makes it deeper.
local function breathe(c: Ctx, amount: number)
	local b = c.breath * amount * (1 + c.effort * 1.4)
	local o = c.out
	o.Waist = (o.Waist or CFrame.identity) * A(1.1 * b, 0, 0)
	o.Neck = (o.Neck or CFrame.identity) * A(-0.6 * b, 0, 0)
end

-- Standing trunk: forward `pitch` (deg) split between pelvis and spine, hips
-- pushed back to stay balanced, optional yaw / roll.
local function trunk(c: Ctx, drop: number, pitch: number, yaw: number?, roll: number?, back: number?)
	local pelvis = pitch * 0.6
	local hipsBack = back or c.rig.trunk * sin(rad(math.max(0, pitch))) * 0.55
	local y, z = yaw or 0, roll or 0
	c.out.Root = CFrame.new(0, -drop, hipsBack) * A(-pelvis, y * 0.4, z * 0.5)
	c.out.Waist = A(-(pitch - pelvis), y * 0.6, z * 0.5)
end

-- Both feet planted on the standing floor. `spread` widens, dzL/dzR stagger.
local function plantLegs(c: Ctx, spread: number, dzL: number?, dzR: number?, kneeOut: number?)
	local rig, o = c.rig, c.out
	local out = kneeOut or 0.2
	Rig.legIK(rig, o, "Left", Rig.plant(rig, "Left", -spread, dzL), V(-out, 0, -1))
	Rig.legIK(rig, o, "Right", Rig.plant(rig, "Right", spread, dzR), V(out, 0, -1))
end

-- Seated legs: feet on the floor `drop` below the HRP, `fz` in front.
local function seatedLegs(c: Ctx, defaultDrop: number, fz: number, spread: number?)
	local rig = c.rig
	local drop = math.clamp(c.drop or defaultDrop, 1.4, 3.6)
	local sx = spread or 0.62
	local floor = -drop
	Rig.legIK(rig, c.out, "Left", Rig.onFloor(rig, -sx, floor, fz), V(-0.2, 0.4, -1))
	Rig.legIK(rig, c.out, "Right", Rig.onFloor(rig, sx, floor, fz), V(0.2, 0.4, -1))
end

-- Mirrors a right-side HRP-space point to the left.
local function mirror(p: Vector3): Vector3
	return V(-p.X, p.Y, p.Z)
end

local function arms(c: Ctx, right: Vector3, left: Vector3, poleR: Vector3, poleL: Vector3?)
	Rig.armIK(c.rig, c.out, "Right", right, poleR)
	Rig.armIK(c.rig, c.out, "Left", left, poleL or mirror(poleR))
end

local function settleRoot(c: Ctx, amount: number)
	if c.settle ~= 0 then
		c.out.Root = (c.out.Root or CFrame.identity) * CFrame.new(0, -0.05 * c.settle * amount, 0) * A(-1.2 * c.settle * amount, 0, 0)
	end
end

local P: { [string]: Program } = {}

---------------------------------------------------------------------------
-- Strength
---------------------------------------------------------------------------
-- Alternating dumbbell curls; elbows pinned, slight counter-lean at the top.
P.StandCurl = {
	Kind = "Discrete",
	RepTime = 1.15,
	Heavy = 0.25,
	Profile = { up = 0.4, hold = 0.1, snap = 0.45 },
	update = function(c: Ctx)
		local o, L = c.out, c.lift
		local right = c.rep % 2 == 1
		local s = if right then 1 else -1
		local sway = Curves.noise(c.seed, c.t * 0.25)
		o.Root = CFrame.new(0, -0.06, 0) * A(-1, sway * 1.5, 0)
		o.Waist = A(2.5 * L, -s * 4 * L, s * 1.5 * L)
		o.Neck = A(-7 - 8 * L, -s * 7 * L, 0)
		local rA = if right then L else 0
		local lA = if right then 0 else L
		local idle = 0.06 * c.settle
		o.RightShoulder = A(4 + 9 * rA, 0, 7 - 3 * rA)
		o.RightElbow = A(12 + 126 * rA + idle * 10, 0, 0)
		o.RightWrist = A(-8 + 24 * rA, 0, 0)
		o.LeftShoulder = A(4 + 9 * lA, 0, -7 + 3 * lA)
		o.LeftElbow = A(12 + 126 * lA + idle * 10, 0, 0)
		o.LeftWrist = A(-8 + 24 * lA, 0, 0)
		breathe(c, 1)
		plantLegs(c, 0.08)
	end,
}

-- Overhead press from the front rack with a leg dip-and-drive.
P.StandPress = {
	Kind = "Discrete",
	RepTime = 1.5,
	Heavy = 0.8,
	UsesBar = true,
	MoverScale = 0.72,
	Profile = { up = 0.36, hold = 0.14, snap = 0.6 },
	update = function(c: Ctx)
		local o, L = c.out, c.lift
		local dip = if c.r >= 0 then bump(c.r, 0, 0.16) * 0.28 else 0
		o.Root = CFrame.new(0, -0.05 - dip, 0) * A(1.5 * L, 0, 0)
		o.Waist = A(4 * L, 0, 0)
		o.Neck = A(-3 + 7 * L, 0, 0)
		breathe(c, 1)
		local bar = c.bar or V(0, 1.35 + 2.3 * L, -0.7)
		local grip = 1.18
		local pole = V(0, -1, -0.45):Lerp(V(0, -0.2, 0.8), smooth(L))
		arms(c, bar + V(grip, 0, 0), bar - V(grip, 0, 0), pole + V(0.7, 0, 0), pole - V(0.7, 0, 0))
		settleRoot(c, 1)
		plantLegs(c, 0.14)
	end,
}

-- Flat bench: lying (HRP local Y = toward the head, -Z = world up).
P.Bench = {
	Kind = "Discrete",
	RepTime = 1.6,
	Heavy = 0.7,
	UsesBar = true,
	Probe = V(1.4, -1.25, 0),
	Profile = { up = 0.52, hold = 0.06, snap = 0.2 },
	update = function(c: Ctx)
		local o, rig, L = c.out, c.rig, c.lift
		o.Root = CFrame.identity
		o.Waist = A(-3 - 2 * L, 0, 0) -- slight arch, chest meets the bar
		o.Neck = A(4, 0, 0)
		breathe(c, 1.2)
		local bar = c.bar or V(0, 1.3, -2.45 + 1.9 * L)
		local grip = 1.12
		local pole = V(0, -0.7, 0.55)
		arms(c, bar + V(grip, 0, 0), bar - V(grip, 0, 0), pole + V(0.8, 0, 0), pole - V(0.8, 0, 0))
		-- feet flat on the floor either side of the bench (world down = local +Z)
		local down = math.clamp(c.drop or 2.05, 1.5, 2.8)
		local z = down - rig.ankleHeight
		local drive = 0.06 * bump(c.r, 0.55, 0.85)
		local footRot = A(-90, 0, 0)
		Rig.legIK(rig, o, "Left", V(-1.25, -1.3 + drive, z), V(-0.5, 0.2, -1), footRot)
		Rig.legIK(rig, o, "Right", V(1.25, -1.3 + drive, z), V(0.5, 0.2, -1), footRot)
	end,
}

-- Back squat: hips back and down, chest up, hands locked on the bar.
P.Squat = {
	Kind = "Discrete",
	RepTime = 1.8,
	Heavy = 0.9,
	UsesBar = true,
	Profile = { up = 0.5, hold = 0.06, snap = 0.25 },
	update = function(c: Ctx)
		local o, rig, L = c.out, c.rig, c.lift
		local pitch = 36 * smooth(L)
		local drop = math.max(0, 2.0 * L - rig.trunk * (1 - cos(rad(pitch))))
		trunk(c, drop + 0.03, pitch, 0, 0, rig.trunk * sin(rad(pitch)) * 0.9)
		o.Neck = A(pitch * 0.55 + 3, 0, 0)
		breathe(c, 1)
		local bar = c.bar or V(0, 1.6 - 2.0 * L, 0.38)
		local grip = 1.32
		arms(c, bar + V(grip, 0, 0), bar - V(grip, 0, 0), V(0.7, -1, 0.7), V(-0.7, -1, 0.7))
		settleRoot(c, 1)
		plantLegs(c, 0.24, 0, 0, 0.4)
	end,
}

-- Deadlift (also Atlas Stone): hinge at the hips, flat back, stand tall.
P.Deadlift = {
	Kind = "Discrete",
	RepTime = 1.9,
	Heavy = 1,
	UsesBar = true,
	MoverScale = 0.55,
	MoverScaleFor = { AtlasStone = 0.62 },
	Profile = { up = 0.4, hold = 0.1, snap = 0.4 },
	update = function(c: Ctx)
		local o, rig, L = c.out, c.rig, c.lift
		local e = smooth(L)
		local stone = c.stationType == "AtlasStone"
		local pitch = (if stone then 40 else 46) * (1 - e) - 4 * e
		local drop = (if stone then 0.55 else 0.32) * (1 - e)
		trunk(c, drop, pitch, 0, 0, rig.trunk * sin(rad(math.max(0, pitch))) * 0.55)
		o.Neck = A(pitch * 0.5, 0, 0)
		breathe(c, 1)
		local bar = c.bar or V(0, -1.75 + 0.72 * L, -0.6)
		local grip = if stone then 0.95 else 1.02
		local hold = if stone then V(0, -0.15, 0.15) else Vector3.zero
		local pole = if stone then V(1, -0.2, 0.3) else V(0.45, 0.2, 1)
		arms(c, bar + hold + V(grip, 0, 0), bar + hold - V(grip, 0, 0), pole, mirror(pole))
		settleRoot(c, 1.2)
		plantLegs(c, if stone then 0.2 else 0.04, 0, 0, if stone then 0.45 else 0.15)
	end,
}

-- Seated chest press: handles from the chest to near lockout.
P.SeatedPress = {
	Kind = "Discrete",
	RepTime = 1.35,
	Heavy = 0.35,
	Probe = V(0, 0, -1.3),
	Profile = { up = 0.4, hold = 0.08, snap = 0.5 },
	update = function(c: Ctx)
		local o, L = c.out, c.lift
		o.Root = CFrame.new(0, -0.32, 0.05)
		o.Waist = A(-3 * L, 0, 0)
		o.Neck = A(-2, 0, 0)
		breathe(c, 1)
		local e = smooth(L)
		local r = V(lerp(1.08, 0.92, e), lerp(1.12, 1.2, e), lerp(-0.85, -2.25, e))
		arms(c, r, mirror(r), V(1, -0.45, 0.55))
		seatedLegs(c, 2.95, -1.35)
	end,
}

-- Leg press on a 40 degree reclined seat (HRP tilted back with the pad).
P.LegPress = {
	Kind = "Discrete",
	RepTime = 1.6,
	Heavy = 0.6,
	Profile = { up = 0.42, hold = 0.06, snap = 0.45 },
	update = function(c: Ctx)
		local o, rig, L = c.out, c.rig, c.lift
		o.Root = CFrame.new(0, -0.3, 0.05)
		o.Waist = A(0, 0, 0)
		o.Neck = A(-14, 0, 0)
		breathe(c, 1.1)
		local e = smooth(L)
		local fz = lerp(-1.7, -2.75, e)
		local footRot = A(90, 0, 0)
		local knee = V(0, 0.77, -0.64) -- world up seen from the reclined trunk
		Rig.legIK(rig, o, "Left", V(-0.62, -0.6, fz), knee + V(-0.3, 0, 0), footRot)
		Rig.legIK(rig, o, "Right", V(0.62, -0.6, fz), knee + V(0.3, 0, 0), footRot)
		local grip = 0.12 * L -- squeeze the side handles under load
		arms(c, V(1.25, -0.55 - grip, 0.05), V(-1.25, -0.55 - grip, 0.05), V(1, -0.2, 1))
	end,
}

-- Cable crossover: a wide hug from high pulleys, staggered stance.
P.CableFly = {
	Kind = "Discrete",
	RepTime = 1.4,
	Heavy = 0.3,
	Profile = { up = 0.4, hold = 0.12, snap = 0.4 },
	update = function(c: Ctx)
		local o, L = c.out, c.lift
		trunk(c, 0.12, 9 + 5 * L, 0, 0, 0.12)
		o.Neck = A(9 + 3 * L, 0, 0)
		breathe(c, 1)
		local e = smooth(L)
		local arc = sin(pi * e)
		local r = v3(V(2.55, 2.0, 0.35), V(0.28, 0.6, -1.95), e) + V(0, 0.3 * arc, -0.55 * arc)
		arms(c, r, mirror(r), V(1, 0.35, 0.7))
		plantLegs(c, 0.1, -0.55, 0.4)
	end,
}

-- Seated lat pulldown: bar from overhead to the upper chest, lean back.
P.Pulldown = {
	Kind = "Discrete",
	RepTime = 1.4,
	Heavy = 0.35,
	Probe = V(0, 0, -1.2),
	Profile = { up = 0.4, hold = 0.1, snap = 0.5 },
	update = function(c: Ctx)
		local o, L = c.out, c.lift
		local e = smooth(L)
		o.Root = CFrame.new(0, -0.32, 0.04) * A(-2, 0, 0)
		o.Waist = A(7 * e, 0, 0)
		o.Neck = A(12 - 15 * e, 0, 0)
		breathe(c, 1)
		local r = V(lerp(1.55, 1.42, e), lerp(3.45, 1.55, e), lerp(-0.45, -0.6, e))
		arms(c, r, mirror(r), V(1, -0.8, 0.25))
		seatedLegs(c, 2.9, -0.95, 0.55)
	end,
}

-- Pull-up: hands fixed on the bar, the body rises (chin to the bar).
P.Hang = {
	Kind = "Discrete",
	RepTime = 1.7,
	Heavy = 0.5,
	Profile = { up = 0.42, hold = 0.1, snap = 0.4 },
	update = function(c: Ctx)
		local o, L = c.out, c.lift
		local e = smooth(L)
		local swing = Curves.noise(c.seed, c.t * 0.5) * 2 + c.settle * 3
		o.Root = CFrame.new(0, 1.95 * e, 0) * A(swing - 4 * e, 0, 0)
		o.Waist = A(3 * e, 0, 0)
		o.Neck = A(10 - 6 * e, 0, 0)
		breathe(c, 0.8)
		local h = 3.8
		arms(c, V(1.35, h, 0), V(-1.35, h, 0), V(1, -0.5, 0.6))
		o.RightHip = A(-6 + 12 * e, 0, 3)
		o.RightKnee = A(-72 + 18 * e, 0, 0)
		o.RightAnkle = A(-25, 0, 0)
		o.LeftHip = A(-12 + 12 * e, 0, -3)
		o.LeftKnee = A(-84 + 18 * e, 0, 0)
		o.LeftAnkle = A(-25, 0, 0)
	end,
}

-- Tire flip: squat and grip under the edge, drive up, push it over, reset.
P.TireFlip = {
	Kind = "Discrete",
	RepTime = 2.3,
	Heavy = 1,
	Profile = { up = 0.5, hold = 0.05, snap = 0.3 },
	update = function(c: Ctx)
		local o, r = c.out, c.r
		local grab, drive, push, reset = 0, 0, 0, 0
		if r >= 0 then
			grab = smooth(ramp(r, 0, 0.24))
			drive = smooth(ramp(r, 0.24, 0.55))
			push = smooth(ramp(r, 0.55, 0.78))
			reset = smooth(ramp(r, 0.82, 1))
		end
		local down = grab * (1 - drive)
		local pitch = 8 + 44 * down + 14 * drive * (1 - push) - 6 * push
		pitch = lerp(pitch, 8, reset)
		trunk(c, 0.15 + 1.05 * down, pitch, 0, 0, nil)
		o.Neck = A(pitch * 0.55, 0, 0)
		breathe(c, 1)
		local ready = V(0.75, -0.55, -0.75)
		local low = V(0.95, -2.25, -1.55)
		local high = V(0.95, -0.55, -1.75)
		local over = V(0.85, 1.25, -2.55)
		local h = v3(ready, low, grab)
		h = v3(h, high, drive)
		h = v3(h, over, push)
		h = v3(h, ready, reset)
		arms(c, h, mirror(h), V(1, -0.6, 0.6))
		plantLegs(c, 0.22, -0.1 * drive, 0.25 * drive, 0.4)
		c.mover = drive * (1 - reset)
		settleRoot(c, 1)
	end,
}

---------------------------------------------------------------------------
-- Endurance (continuous)
---------------------------------------------------------------------------
-- Rowing: legs, then back, then arms; recovery in reverse. The seat (Mover)
-- slides forward of its rest position at the catch.
P.Row = {
	Kind = "Continuous",
	Loop = 1.35,
	MoverScale = 0.75,
	SpinDir = 1,
	update = function(c: Ctx)
		local o, rig = c.out, c.rig
		local x = (c.phase / (2 * pi)) % 1
		local seat, armsIn, swing
		if x < 0.42 then
			local d = x / 0.42
			seat = smooth(math.min(1, d / 0.75))
			swing = lerp(-1, 1, smooth(ramp(d, 0.25, 0.85)))
			armsIn = smooth(ramp(d, 0.55, 1))
		else
			local d = (x - 0.42) / 0.58
			armsIn = 1 - smooth(ramp(d, 0, 0.35))
			swing = lerp(1, -1, smooth(ramp(d, 0.15, 0.6)))
			seat = 1 - smooth(ramp(d, 0.35, 1))
		end
		local slide = 1.65 * (1 - seat)
		local pitch = lerp(24, -14, (swing + 1) / 2)
		o.Root = CFrame.new(0, -0.3, -slide) * A(-pitch * 0.6, 0, 0)
		o.Waist = A(-pitch * 0.4, 0, 0)
		o.Neck = A(pitch * 0.4, 0, 0)
		breathe(c, 0.8)
		local ut = Rig.upperTorso(rig, o)
		local reach = ut * V(0.38, -1.25, -2.35)
		local ribs = ut * V(0.45, -0.35, -0.95)
		local r = v3(reach, ribs, armsIn)
		local l = v3(ut * V(-0.38, -1.25, -2.35), ut * V(-0.45, -0.35, -0.95), armsIn)
		arms(c, r, l, V(1, -0.3, 0.8))
		local footRot = A(35, 0, 0)
		Rig.legIK(rig, o, "Left", V(-0.45, -1.65, -1.78), V(-0.15, 1, -0.3), footRot)
		Rig.legIK(rig, o, "Right", V(0.45, -1.65, -1.78), V(0.15, 1, -0.3), footRot)
		c.mover = seat - 1
	end,
}

-- Spin bike: pedals locked to the crank Spinner, hands on the bars.
local BIKE_CRANK = V(0, -2.55, -1.05)
P.Bike = {
	Kind = "Continuous",
	Loop = 0.8,
	SpinSync = true,
	SpinDir = -1,
	update = function(c: Ctx)
		local o, rig = c.out, c.rig
		local th = c.phase
		o.Root = CFrame.new(0, -0.3 + 0.03 * cos(2 * th), 0) * A(-14, 0, 2 * sin(th))
		o.Waist = A(-14, 2.5 * sin(th), 0)
		o.Neck = A(22, -1.5 * sin(th), 0)
		breathe(c, 0.7)
		arms(c, V(0.85, -0.05, -2.1), V(-0.85, -0.05, -2.1), V(1, -0.6, 0.6))
		local R = 0.5
		for i, side in { "Right", "Left" } do
			local a = th + (i - 1) * pi
			local sx = if side == "Right" then 0.45 else -0.45
			local pedal = BIKE_CRANK + V(sx, R * cos(a), -R * sin(a))
			local ankle = pedal + V(0, rig.ankleHeight * 0.6, 0.15)
			Rig.legIK(rig, o, side :: Rig.Side, ankle, V(sx * 0.2, 0.4, -1), A(-8 + 14 * sin(a + 0.6), 0, 0))
		end
	end,
}

-- Battle ropes: athletic half squat, alternating waves.
P.Ropes = {
	Kind = "Continuous",
	Loop = 0.55,
	update = function(c: Ctx)
		local o = c.out
		local th = c.phase
		trunk(c, 0.5 - 0.05 * sin(2 * th), 22, 4 * sin(th), 0, 0.3)
		o.Neck = A(18, -3 * sin(th), 0)
		breathe(c, 0.6)
		local amp = 0.35 + 0.2 * c.speed
		local r = V(0.85, -0.2 + amp * sin(th), -1.7)
		local l = V(-0.85, -0.2 + amp * sin(th + pi), -1.7)
		arms(c, r, l, V(1, -0.8, 0.3))
		plantLegs(c, 0.42, -0.15, 0.15, 0.45)
	end,
}

---------------------------------------------------------------------------
-- Speed (continuous)
---------------------------------------------------------------------------
-- Treadmill run: stride grows with cadence; arms counter-swing.
P.Run = {
	Kind = "Continuous",
	Loop = 0.66,
	update = function(c: Ctx)
		local o = c.out
		local th = c.phase
		local amp = 0.7 + 0.35 * math.clamp(c.speed, 0.4, 1.2)
		o.Root = CFrame.new(0, 0.1 * cos(2 * th) - 0.06, 0) * A(-5 * amp, 6 * sin(th), 0)
		o.Waist = A(-3 * amp, -10 * amp * sin(th), 0)
		o.Neck = A(6, 4 * sin(th), 0)
		breathe(c, 0.5)
		for i, side in { "Right", "Left" } do
			local phi = th + (i - 1) * pi
			local swing = math.max(0, cos(phi))
			local sgn = if side == "Right" then 1 else -1
			o[side .. "Hip"] = A(34 * amp * sin(phi), 0, sgn * 2)
			o[side .. "Knee"] = A(-(14 + 82 * amp * swing ^ 1.3), 0, 0)
			o[side .. "Ankle"] = A(12 * sin(phi) - 14 * swing, 0, 0)
			o[side .. "Shoulder"] = A(-30 * amp * sin(phi), 0, sgn * 6)
			o[side .. "Elbow"] = A(86, 0, 0)
			o[side .. "Wrist"] = A(-6, 0, 0)
		end
	end,
}

-- Sled push: deep forward lean, arms locked on the poles, driving steps.
P.Push = {
	Kind = "Continuous",
	Loop = 0.9,
	update = function(c: Ctx)
		local o, rig = c.out, c.rig
		local th = c.phase
		o.Root = CFrame.new(0, -0.55 + 0.04 * cos(2 * th), 0.55) * A(-36, 3 * sin(th), 0)
		o.Waist = A(-14, -4 * sin(th), 0)
		o.Neck = A(34, 0, 0)
		breathe(c, 0.7)
		arms(c, V(0.85, 0.15, -2.35), V(-0.85, 0.15, -2.35), V(1, -0.5, 0.6))
		for i, side in { "Right", "Left" } do
			local phi = th + (i - 1) * pi
			local liftY = 0.38 * math.max(0, cos(phi))
			local sx = if side == "Right" then 0.12 else -0.12
			local target = Rig.plant(rig, side :: Rig.Side, sx, 0.35 - 0.6 * sin(phi), liftY)
			Rig.legIK(rig, o, side :: Rig.Side, target, V(sx, 0, -1), A(-10 * math.max(0, sin(phi)), 0, 0))
		end
		c.mover = 0.2 + 0.15 * sin(2 * th)
	end,
}

---------------------------------------------------------------------------
-- Agility (discrete)
---------------------------------------------------------------------------
-- Ladder drill: light bounce, then in-in-out-out steps on every rep.
P.Footwork = {
	Kind = "Discrete",
	RepTime = 1.0,
	Heavy = 0,
	update = function(c: Ctx)
		local o, rig, r = c.out, c.rig, c.r
		local active = r >= 0
		local bounce = 0.05 * abs(sin(c.t * (if active then 11 else 6)))
		trunk(c, 0.32 - bounce, 10, 0, 0, 0.1)
		o.Neck = A(14, 0, 0)
		breathe(c, 0.7)
		local pump = if active then sin(r * pi * 8) else 0.25 * sin(c.t * 6)
		o.RightShoulder = A(18 - 32 * pump, 0, 8)
		o.LeftShoulder = A(18 + 32 * pump, 0, -8)
		o.RightElbow = A(88, 0, 0)
		o.LeftElbow = A(88, 0, 0)
		local rz, lz, rl, ll = 0, 0, 0, 0
		if active then
			local step = math.floor(r * 4)
			local u = smooth((r * 4) % 1)
			local arc = sin(((r * 4) % 1) * pi) * 0.42
			if step == 0 then
				rz, rl = u, arc
			elseif step == 1 then
				rz, lz, ll = 1, u, arc
			elseif step == 2 then
				rz, lz, rl = 1 - u, 1, arc
			else
				lz, ll = 1 - u, arc
			end
		end
		Rig.legIK(rig, o, "Right", Rig.plant(rig, "Right", 0.12 - 0.2 * rz, -0.95 * rz, rl + bounce), V(0.2, 0, -1))
		Rig.legIK(rig, o, "Left", Rig.plant(rig, "Left", -0.12 + 0.2 * lz, -0.95 * lz, ll + bounce), V(-0.2, 0, -1))
	end,
}

-- Speed bag: hands up at head height rolling small fast circles.
P.BoxHigh = {
	Kind = "Discrete",
	RepTime = 0.9,
	Heavy = 0,
	Impacts = { 0.12, 0.3, 0.48, 0.66, 0.84 },
	update = function(c: Ctx)
		local o, r = c.out, c.r
		local act = if r >= 0 then math.sqrt(bump(r, 0, 1)) else 0
		trunk(c, 0.12 + 0.03 * sin(c.t * 6), 3, 0, 0, 0.05)
		o.Neck = A(10, 0, 0)
		breathe(c, 0.6)
		local w = c.t * 18
		local rad0 = 0.18 * act
		local guardR, guardL = V(0.42, 1.8, -0.85), V(-0.42, 1.8, -0.85)
		local rr = guardR + V(-0.05 * act, 0.15 * act + rad0 * sin(w), -0.25 * act + rad0 * cos(w))
		local ll = guardL + V(0.05 * act, 0.15 * act + rad0 * sin(w + pi), -0.25 * act + rad0 * cos(w + pi))
		arms(c, rr, ll, V(1, -0.6, 0.3))
		plantLegs(c, 0.12, -0.2, 0.2)
	end,
}

-- Heavy bag / reflex wall: orthodox stance, jab - cross - hook per rep.
P.Box = {
	Kind = "Discrete",
	RepTime = 1.15,
	Heavy = 0,
	Impacts = { 0.14, 0.42, 0.72 },
	update = function(c: Ctx)
		local o, r = c.out, c.r
		local jab = bump(r, 0.02, 0.28)
		local cross = bump(r, 0.28, 0.58)
		local hook = bump(r, 0.58, 0.88)
		local yaw = -18 + 24 * cross - 26 * hook
		local bob = 0.04 * sin(c.t * 5.5)
		o.Root = CFrame.new(0, -0.28 + bob, 0.05) * A(-6, yaw * 0.4, 0)
		o.Waist = A(-6, yaw * 0.6, 0)
		o.Neck = A(6, -yaw * 0.7, 0)
		breathe(c, 0.7)
		local turn = CFrame.Angles(0, rad(yaw * 0.7), 0)
		local guardR, guardL = turn * V(0.5, 1.75, -0.72), turn * V(-0.22, 1.8, -1.0)
		local right = guardR:Lerp(V(0.1, 1.6, -1.45), cross)
		local left = guardL:Lerp(V(-0.15, 1.65, -1.45), jab):Lerp(V(0.05, 1.7, -1.25), hook)
		local poleL = V(-1, -0.8, 0.4):Lerp(V(-1, 0.6, 0.2), hook)
		arms(c, right, left, V(1, -0.8, 0.4), poleL)
		local rig = c.rig
		Rig.legIK(rig, o, "Left", Rig.plant(rig, "Left", -0.05, -0.55), V(-0.25, 0, -1))
		Rig.legIK(rig, o, "Right", Rig.plant(rig, "Right", 0.12, 0.45, 0.06 * cross), V(0.3, 0, -1), A(14 * cross, -10, 0))
	end,
}

-- Plyo box: dip, jump onto the box, stand tall, step back down.
P.Jump = {
	Kind = "Discrete",
	RepTime = 1.7,
	Heavy = 0.5,
	Probe = V(0, 0, -1.45),
	Profile = { up = 0.4, hold = 0.2, snap = 0.5 },
	update = function(c: Ctx)
		local o, rig, r = c.out, c.rig, c.r
		local standH = -rig.floorY
		local boxH = math.clamp(standH - (c.drop or (standH - 1.8)), 0.6, 3.2)
		local fz = -1.45
		local y, z, tuck, armUp, crouch = 0, 0, 0, 0, 0
		local onBox = 0 -- 0 floor, 1 box (where the feet are planted)
		if r >= 0 then
			if r < 0.16 then
				crouch = smooth(r / 0.16)
				armUp = -crouch
			elseif r < 0.4 then
				local u = (r - 0.16) / 0.24
				z = fz * smooth(u)
				y = lerp(-0.5, boxH - 0.4, smooth(u)) + 0.9 * sin(u * pi)
				tuck = sin(u * pi)
				armUp = lerp(-1, 1, smooth(u * 1.6))
				onBox = if u > 0.5 then 1 else 0
			elseif r < 0.52 then
				local u = (r - 0.4) / 0.12
				z, onBox = fz, 1
				y = boxH - 0.4 * (1 - smooth(u)) - 0.15 * sin(u * pi)
				crouch = 1 - u
				armUp = 1 - u
			elseif r < 0.7 then
				z, y, onBox = fz, boxH, 1
			elseif r < 0.9 then
				local u = (r - 0.7) / 0.2
				z = fz * (1 - smooth(u))
				y = lerp(boxH, -0.3, smooth(u)) + 0.35 * sin(u * pi)
				tuck = 0.5 * sin(u * pi)
				onBox = if u < 0.5 then 1 else 0
			else
				local u = (r - 0.9) / 0.1
				y = -0.3 * (1 - smooth(u))
				crouch = 0.4 * (1 - u)
			end
		end
		local drop = 0.5 * crouch
		local pitch = 8 + 28 * crouch + 10 * tuck
		o.Root = CFrame.new(0, y - drop, z + 0.3 * crouch) * A(-pitch * 0.6, 0, 0)
		o.Waist = A(-pitch * 0.4, 0, 0)
		o.Neck = A(pitch * 0.4, 0, 0)
		breathe(c, 0.8)
		o.RightShoulder = A(10 + 110 * math.max(0, armUp) - 40 * math.max(0, -armUp), 0, 8)
		o.LeftShoulder = A(10 + 110 * math.max(0, armUp) - 40 * math.max(0, -armUp), 0, -8)
		o.RightElbow = A(25, 0, 0)
		o.LeftElbow = A(25, 0, 0)
		local baseY = onBox * boxH
		local baseZ = onBox * fz
		for _, side in { "Left", "Right" } do
			local s = side :: Rig.Side
			local planted = Rig.plant(rig, s, if s == "Right" then 0.1 else -0.1, baseZ, baseY)
			local hip = Rig.hipPos(rig, o, s)
			local tucked = hip + V(0, -1.35, -0.35)
			Rig.legIK(rig, o, s, planted:Lerp(tucked, tuck), V(if s == "Right" then 0.25 else -0.25, 0, -1))
		end
		settleRoot(c, 1)
	end,
}

---------------------------------------------------------------------------
-- Energy (recovery, discrete Breath reps)
---------------------------------------------------------------------------
-- Yoga: seated cross-legged; each breath sweeps the arms out and overhead.
P.Yoga = {
	Kind = "Discrete",
	RepTime = 2.8,
	Heavy = 0,
	Profile = { up = 0.45, hold = 0.15, snap = 0 },
	update = function(c: Ctx)
		local o, rig, L = c.out, c.rig, c.lift
		o.Root = CFrame.new(0, -0.38, 0)
		o.Waist = A(4 * L, 0, 0)
		o.Neck = A(-4 + 8 * L, 0, 0)
		breathe(c, 2)
		local e = smooth(L)
		local rest, side, top = V(1.12, -0.82, -0.78), V(2.35, 1.6, -0.25), V(0.32, 3.95, -0.2)
		local hand = v3(v3(rest, side, e), v3(side, top, e), e)
		arms(c, hand, mirror(hand), V(1, -0.5, 0.5))
		local floor = -1.3 -- the HRP sits 1.3 above the mat (Equipment contract)
		Rig.legIK(rig, o, "Right", V(-0.45, floor + rig.ankleHeight * 0.7, -0.95), V(1, 0.5, -0.4), A(-10, 60, 0))
		Rig.legIK(rig, o, "Left", V(0.45, floor + rig.ankleHeight * 0.7, -0.6), V(-1, 0.5, -0.4), A(-10, -60, 0))
	end,
}

-- Sauna / ice bath: leaning back, hands on thighs, slow deep breaths.
P.SitRelax = {
	Kind = "Discrete",
	RepTime = 3.0,
	Heavy = 0,
	Probe = V(0, 0, -1.4),
	Profile = { up = 0.45, hold = 0.2, snap = 0 },
	update = function(c: Ctx)
		local o, L = c.out, c.lift
		o.Root = CFrame.new(0, -0.32, 0.12) * A(7, 0, 0)
		o.Waist = A(4 + 4 * L, 0, 0)
		o.Neck = A(8 + 9 * L, Curves.noise(c.seed, c.t * 0.1) * 8, 0)
		breathe(c, 1.6)
		local r = V(0.72, -0.5 + 0.06 * L, -1.0)
		arms(c, r, mirror(r), V(1, -0.3, 0.7))
		seatedLegs(c, 3.0, -1.55, 0.7)
	end,
}

-- Cryo pod: weightless upright float, arms drifting open on each breath.
P.Float = {
	Kind = "Discrete",
	RepTime = 3.2,
	Heavy = 0,
	Profile = { up = 0.45, hold = 0.15, snap = 0 },
	update = function(c: Ctx)
		local o, L, t = c.out, c.lift, c.t
		local bob = 0.12 * sin(t * 1.4)
		o.Root = CFrame.new(0, 0.25 + bob, 0) * A(2 * sin(t * 0.9), 0, 1.5 * sin(t * 0.7))
		o.Waist = A(3 * L, 0, 0)
		o.Neck = A(4 - 6 * L, 0, 0)
		breathe(c, 1.5)
		local open = 18 + 28 * smooth(L) + 3 * sin(t * 1.1)
		o.RightShoulder = A(6, 0, open)
		o.LeftShoulder = A(6, 0, -open)
		o.RightElbow = A(16, 0, 0)
		o.LeftElbow = A(16, 0, 0)
		o.RightHip = A(4 + 2 * sin(t * 0.8), 0, 3)
		o.LeftHip = A(2 - 2 * sin(t * 0.8), 0, -3)
		o.RightKnee = A(-9, 0, 0)
		o.LeftKnee = A(-12, 0, 0)
		o.RightAnkle = A(-26, 0, 0)
		o.LeftAnkle = A(-26, 0, 0)
	end,
}

---------------------------------------------------------------------------
-- Arm-wrestling (duels): DuelLean +1 = this character is winning.
---------------------------------------------------------------------------
P.ArmWrestle = {
	Kind = "Continuous",
	Loop = 1,
	update = function(c: Ctx)
		local o = c.out
		local lean = math.clamp(c.lean, -1, 1)
		local strain = (1 - abs(lean)) * 0.6 + 0.4
		local shake = Curves.noise(c.seed, c.t * 9) * 0.045 * strain
		o.Root = CFrame.new(0, -0.35, 0.1) * A(-22 + 4 * lean, -10 + 6 * lean, 0)
		o.Waist = A(-16, -8 - 10 * lean, 4 * lean)
		o.Neck = A(26, 8 * lean, 0)
		breathe(c, 0.8)
		local elbow = V(0.3, 0.25, -1.75)
		local forearm = CFrame.Angles(0, 0, rad(70 * lean)) * V(-0.35, 0.72, -0.85)
		local hand = elbow + forearm + V(shake, shake * 0.5, 0)
		Rig.armIK(c.rig, o, "Right", hand, V(0.4, -1, 0.3))
		Rig.armIK(c.rig, o, "Left", V(-1.05, 0.25, -1.45), V(-1, -0.6, 0.3))
		plantLegs(c, 0.25, -0.4, 0.5, 0.35)
	end,
}

Poses.Programs = P

function Poses.get(id: string): Program?
	return P[id]
end

-- Fraction of MoverTravel a program shows for a given station type.
function Poses.moverScale(p: Program, stationType: string): number
	local byType = p.MoverScaleFor
	if byType and byType[stationType] then
		return byType[stationType]
	end
	return p.MoverScale or 1
end

return Poses
