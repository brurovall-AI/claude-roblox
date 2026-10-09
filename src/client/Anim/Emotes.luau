--!strict
--[[
	Emote programs (one per Pose key in Config/Cosmetics.EmoteList). Same
	contract as Anim/Poses (Ctx -> c.out), Kind = "Emote":
	  Duration   one-shot length; the final pose is held (with life) until the
	             server clears the Emote attribute (~3.4 s). nil = looping.
	`c.t` restarts on every EmoteStamp change. While the character is walking
	the engine masks the lower body so emotes ride on top of locomotion.
]]

local Curves = require(script.Parent.Curves)
local Poses = require(script.Parent.Poses)
local Rig = require(script.Parent.Rig)

type Ctx = Poses.Ctx
type Program = Poses.Program

local A = Curves.A
local smooth, ramp = Curves.smooth, Curves.ramp
local sin, cos, pi, abs = math.sin, math.cos, math.pi, math.abs
local V = Vector3.new

local Emotes = {}

local function stance(c: Ctx, spread: number?, drop: number?)
	local rig = c.rig
	local s = spread or 0.08
	if drop then
		c.out.Root = (c.out.Root or CFrame.identity) * CFrame.new(0, -drop, 0)
	end
	Rig.legIK(rig, c.out, "Left", Rig.plant(rig, "Left", -s), V(-0.25, 0, -1))
	Rig.legIK(rig, c.out, "Right", Rig.plant(rig, "Right", s), V(0.25, 0, -1))
end

local function breathe(c: Ctx, amount: number)
	local b = c.breath * amount
	c.out.Waist = (c.out.Waist or CFrame.identity) * A(1.1 * b, 0, 0)
	c.out.Neck = (c.out.Neck or CFrame.identity) * A(-0.5 * b, 0, 0)
end

-- Upper arm twisted then abducted (so elbow flexion lifts the forearm UP).
local function bicepArm(side: number, abduct: number, twist: number): CFrame
	return CFrame.Angles(0, 0, math.rad(side * abduct)) * CFrame.Angles(0, math.rad(-side * twist), 0)
end

-- Pulse 0..1 every `period` seconds (flex squeezes, beats).
local function pulse(t: number, period: number): number
	return 0.5 - 0.5 * cos((t / period) * 2 * pi)
end

local E: { [string]: Program } = {}

E.Wave = {
	Kind = "Emote",
	Duration = 3.0,
	update = function(c: Ctx)
		local o, t = c.out, c.t
		local up = smooth(ramp(t, 0, 0.35))
		o.Root = A(0, -4 * up, 0)
		o.Waist = A(2, -4 * up, 3 * up)
		o.Neck = A(4, -8 * up, -4 * up)
		breathe(c, 1)
		local wave = sin(t * 9) * up
		o.RightShoulder = A(8 * up, 0, 150 * up + 10 * wave)
		o.RightElbow = A(28 * up + 18 * wave, 0, 0)
		o.RightWrist = A(0, 0, 12 * wave)
		o.LeftShoulder = A(2, 0, -6)
		o.LeftElbow = A(12, 0, 0)
		stance(c)
	end,
}

E.DoubleBicep = {
	Kind = "Emote",
	Duration = 3.0,
	update = function(c: Ctx)
		local o, t = c.out, c.t
		local up = smooth(ramp(t, 0, 0.4))
		local squeeze = up * pulse(math.max(0, t - 0.4), 0.9)
		o.Root = CFrame.new(0, -0.06 * up, 0)
		o.Waist = A(6 * up + 2 * squeeze, 0, 0)
		o.Neck = A(-2 + 6 * up, 0, 0)
		breathe(c, 0.6)
		o.RightShoulder = bicepArm(1, 95 * up, 90 * up)
		o.LeftShoulder = bicepArm(-1, 95 * up, 90 * up)
		o.RightElbow = A(10 + 108 * up + 10 * squeeze, 0, 0)
		o.LeftElbow = A(10 + 108 * up + 10 * squeeze, 0, 0)
		o.RightWrist = A(15 * up, 0, 0)
		o.LeftWrist = A(15 * up, 0, 0)
		stance(c, 0.22, 0.04 * up)
	end,
}

E.Clap = {
	Kind = "Emote",
	update = function(c: Ctx)
		local o, t = c.out, c.t
		local open = abs(sin(t * pi / 0.42)) ^ 0.6
		local bounce = 0.04 * open
		o.Root = CFrame.new(0, -bounce, 0)
		o.Waist = A(2, 0, 0)
		o.Neck = A(4 + 3 * open, 0, 0)
		breathe(c, 0.6)
		local r = V(0.08 + 0.45 * open, 1.05, -1.15)
		Rig.armIK(c.rig, o, "Right", r, V(1, -0.6, 0.4))
		Rig.armIK(c.rig, o, "Left", V(-r.X, r.Y, r.Z), V(-1, -0.6, 0.4))
		stance(c)
	end,
}

E.SideChest = {
	Kind = "Emote",
	Duration = 3.0,
	update = function(c: Ctx)
		local o, t, rig = c.out, c.t, c.rig
		local up = smooth(ramp(t, 0, 0.45))
		local squeeze = up * pulse(math.max(0, t - 0.45), 1.0)
		o.Root = CFrame.new(0, -0.08 * up, 0) * A(0, -14 * up, 0)
		o.Waist = A(4 * up, -16 * up - 3 * squeeze, 0)
		o.Neck = A(2, 26 * up, 0)
		breathe(c, 0.5)
		local r = V(0.35, 0.35 + 0.05 * squeeze, -0.95):Lerp(V(1.1, -0.6, 0), 1 - up)
		local l = V(0.12, 0.42 + 0.05 * squeeze, -1.05):Lerp(V(-1.1, -0.6, 0), 1 - up)
		Rig.armIK(rig, o, "Right", r, V(1, -0.4, 0.7))
		Rig.armIK(rig, o, "Left", l, V(-0.4, -0.3, -1))
		Rig.legIK(rig, o, "Left", Rig.plant(rig, "Left", 0.15 * up, -0.45 * up, 0.08 * up), V(0.3, 0, -1), A(18 * up, 0, 0))
		Rig.legIK(rig, o, "Right", Rig.plant(rig, "Right", 0.1), V(0.3, 0, -1))
	end,
}

E.MostMuscular = {
	Kind = "Emote",
	Duration = 3.0,
	update = function(c: Ctx)
		local o, t = c.out, c.t
		local up = smooth(ramp(t, 0, 0.4))
		local shake = Curves.noise(c.seed, t * 14) * up
		local squeeze = up * pulse(math.max(0, t - 0.4), 0.8)
		o.Root = CFrame.new(0, -0.2 * up, 0.05 * up) * A(-5 * up, 0, 0)
		o.Waist = A(-12 * up - 3 * squeeze + 0.6 * shake, 0, 0)
		o.Neck = A(16 * up, 0, 0)
		local r = V(0.25 + 0.02 * shake, 0.15 - 0.05 * squeeze, -1.05):Lerp(V(1.1, -0.6, 0), 1 - up)
		Rig.armIK(c.rig, o, "Right", r, V(1, 0.4, 0.2))
		Rig.armIK(c.rig, o, "Left", V(-r.X, r.Y, r.Z), V(-1, 0.4, 0.2))
		stance(c, 0.3)
	end,
}

E.LatSpread = {
	Kind = "Emote",
	Duration = 3.0,
	update = function(c: Ctx)
		local o, t = c.out, c.t
		local up = smooth(ramp(t, 0, 0.45))
		local spread = up * pulse(math.max(0, t - 0.45), 1.1)
		o.Root = CFrame.new(0, -0.04 * up, 0)
		o.Waist = A(7 * up + 2 * spread, 0, 0)
		o.Neck = A(-4 * up, 0, 0)
		breathe(c, 0.5)
		local r = V(1.15, 0.0, -0.2):Lerp(V(1.1, -0.6, 0), 1 - up)
		local pole = V(1, 0.1 + 0.2 * spread, -0.4 - 0.4 * spread)
		Rig.armIK(c.rig, o, "Right", r, pole)
		Rig.armIK(c.rig, o, "Left", V(-r.X, r.Y, r.Z), V(-pole.X, pole.Y, pole.Z))
		stance(c, 0.24)
	end,
}

E.PushUps = {
	Kind = "Emote",
	update = function(c: Ctx)
		local o, rig, t = c.out, c.rig, c.t
		local into = smooth(ramp(t, 0, 0.5))
		local p = if t < 0.5 then 0 else 0.5 - 0.5 * cos((t - 0.5) * 2 * pi / 1.3)
		local floor = rig.floorY
		local incline = 36 - 22 * p
		local pitch = -(90 - incline) * into
		local lower = (-floor - 1.55 + 0.9 * p) * into
		o.Root = CFrame.new(0, -lower, 0.6 * into) * A(pitch, 0, 0)
		o.Waist = A(0, 0, 0)
		o.Neck = A(40 * into, 0, 0)
		breathe(c, 0.5)
		local hz = 0.6 - 1.29
		local hand = V(1.35, floor + 0.15, hz):Lerp(V(1.1, -0.6, 0), 1 - into)
		Rig.armIK(rig, o, "Right", hand, V(0.5, 0, 1))
		Rig.armIK(rig, o, "Left", V(-hand.X, hand.Y, hand.Z), V(-0.5, 0, 1))
		o.RightHip = A(0, 0, 3)
		o.LeftHip = A(0, 0, -3)
		o.RightKnee = A(-4, 0, 0)
		o.LeftKnee = A(-4, 0, 0)
		o.RightAnkle = A(8 * into, 0, 0)
		o.LeftAnkle = A(8 * into, 0, 0)
	end,
}

E.Victory = {
	Kind = "Emote",
	Duration = 3.0,
	update = function(c: Ctx)
		local o, t = c.out, c.t
		local up = Curves.outBack(ramp(t, 0, 0.35), 1.6)
		local hop = if t < 1.3 then abs(sin(t * pi * 2.4)) * 0.28 * (1 - t / 1.3) else 0
		o.Root = CFrame.new(0, hop, 0)
		o.Waist = A(5 * up, 0, 0)
		o.Neck = A(14 * up, 0, 0)
		breathe(c, 0.8)
		local shake = sin(t * 11) * 4 * up
		o.RightShoulder = A(10 * up, 0, 148 * up + shake)
		o.LeftShoulder = A(10 * up, 0, -148 * up - shake)
		o.RightElbow = A(12, 0, 0)
		o.LeftElbow = A(12, 0, 0)
		stance(c, 0.18)
	end,
}

E.Stretch = {
	Kind = "Emote",
	update = function(c: Ctx)
		local o, t = c.out, c.t
		local up = smooth(ramp(t, 0, 0.6))
		local bend = sin(t * 2 * pi / 4.2) * up
		o.Root = A(0, 0, 4 * bend)
		o.Waist = A(2, 0, 16 * bend)
		o.Neck = A(-4, 0, 6 * bend)
		breathe(c, 1.2)
		o.RightShoulder = A(6 * up, 0, 166 * up)
		o.LeftShoulder = A(6 * up, 0, -166 * up)
		o.RightElbow = A(8, 0, 0)
		o.LeftElbow = A(8, 0, 0)
		stance(c, 0.38)
	end,
}

E.Dance = {
	Kind = "Emote",
	update = function(c: Ctx)
		local o, t = c.out, c.t
		local beat = t / 0.5
		local hit = abs(sin(beat * pi))
		local sway = sin(beat * pi * 0.5)
		o.Root = CFrame.new(0.15 * sway, -0.14 * hit, 0) * A(-3, 8 * sway, -6 * sway)
		o.Waist = A(-2 + 3 * hit, -14 * sway, 4 * sway)
		o.Neck = A(-6 * hit + 4, 10 * sway, 0)
		local pump = sin(beat * pi)
		o.RightShoulder = A(30 + 40 * pump, 0, 18)
		o.LeftShoulder = A(30 - 40 * pump, 0, -18)
		o.RightElbow = A(95 - 15 * pump, 0, 0)
		o.LeftElbow = A(95 + 15 * pump, 0, 0)
		local rig = c.rig
		Rig.legIK(rig, o, "Left", Rig.plant(rig, "Left", -0.18 + 0.12 * sway, 0, 0.12 * math.max(0, -sway)), V(-0.3, 0, -1))
		Rig.legIK(rig, o, "Right", Rig.plant(rig, "Right", 0.18 + 0.12 * sway, 0, 0.12 * math.max(0, sway)), V(0.3, 0, -1))
	end,
}

E.Salute = {
	Kind = "Emote",
	Duration = 3.0,
	update = function(c: Ctx)
		local o, t = c.out, c.t
		local up = Curves.outBack(ramp(t, 0.05, 0.4), 1.2)
		o.Root = CFrame.identity
		o.Waist = A(3 * up, 0, 0)
		o.Neck = A(3 * up, 0, 0)
		breathe(c, 0.4)
		local r = V(1.1, -0.6, 0):Lerp(V(0.55, 2.05, -0.55), up)
		Rig.armIK(c.rig, o, "Right", r, V(1, 0, 0.3), A(0, 0, 0))
		o.LeftShoulder = A(0, 0, -3)
		o.LeftElbow = A(4, 0, 0)
		stance(c, 0.02)
	end,
}

E.Meditate = {
	Kind = "Emote",
	update = function(c: Ctx)
		local o, rig, t = c.out, c.rig, c.t
		local down = smooth(ramp(t, 0, 0.8))
		local floor = rig.floorY
		local seatY = floor + 0.55 - rig.restHip.Right.Y
		local hover = 0.05 * sin(t * 1.2) * down
		o.Root = CFrame.new(0, seatY * down + hover, 0)
		o.Waist = A(2, 0, 0)
		o.Neck = A(-6 * down, 0, 0)
		breathe(c, 1.8)
		local hand = V(1.1, -0.6, 0):Lerp(V(1.05, floor + 0.9, -0.8), down)
		Rig.armIK(rig, o, "Right", hand, V(1, -0.5, 0.5))
		Rig.armIK(rig, o, "Left", V(-hand.X, hand.Y, hand.Z), V(-1, -0.5, 0.5))
		local ankleY = floor + rig.ankleHeight * 0.7
		local stand = Rig.plant(rig, "Right")
		Rig.legIK(rig, o, "Right", stand:Lerp(V(-0.45, ankleY, -0.95), down), V(1, 0.5, -0.4), A(-10, 60 * down, 0))
		Rig.legIK(rig, o, "Left", Rig.plant(rig, "Left"):Lerp(V(0.45, ankleY, -0.6), down), V(-1, 0.5, -0.4), A(-10, -60 * down, 0))
	end,
}

Emotes.Programs = E

function Emotes.get(pose: string): Program?
	return E[pose]
end

return Emotes
