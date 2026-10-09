--!strict
--[[
	Motion curves for the procedural animation engine. Everything here is pure
	math so programs stay readable:

		local v = Curves.lift(r, profile)      -- rep displacement 0..1 (concentric / hold / eccentric)
		local s = Curves.settle(t, freq)       -- decaying oscillation after an impact
		local A = Curves.A                     -- CFrame from degrees
]]

local Curves = {}

local rad = math.rad
local clamp = math.clamp
local sin, cos, pi = math.sin, math.cos, math.pi

export type Profile = {
	up: number, -- fraction of the cycle spent moving away from rest
	hold: number, -- fraction held at the far end
	snap: number?, -- 0..1: how explosive the outbound phase is
}

Curves.DEFAULT = { up = 0.38, hold = 0.1, snap = 0.5 } :: Profile

function Curves.A(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end

function Curves.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Curves.v3(a: Vector3, b: Vector3, t: number): Vector3
	return a + (b - a) * t
end

function Curves.smooth(x: number): number
	x = clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

function Curves.smoother(x: number): number
	x = clamp(x, 0, 1)
	return x * x * x * (x * (x * 6 - 15) + 10)
end

function Curves.outCubic(x: number): number
	x = clamp(x, 0, 1)
	local k = 1 - x
	return 1 - k * k * k
end

function Curves.inOutSine(x: number): number
	x = clamp(x, 0, 1)
	return -(cos(pi * x) - 1) / 2
end

function Curves.outBack(x: number, s: number?): number
	x = clamp(x, 0, 1)
	local c1 = s or 1.4
	local c3 = c1 + 1
	local k = x - 1
	return 1 + c3 * k * k * k + c1 * k * k
end

-- 0 -> 1 -> 0 bump over [a, b] (smooth both ends).
function Curves.bump(x: number, a: number, b: number): number
	if x <= a or x >= b then
		return 0
	end
	return sin((x - a) / (b - a) * pi)
end

-- 0..1 ramp across [a, b].
function Curves.ramp(x: number, a: number, b: number): number
	return clamp((x - a) / (b - a), 0, 1)
end

-- Rep displacement for cycle progress r (0..1). The outbound phase accelerates
-- off the start and decelerates into the far end (`snap` makes it punchier),
-- holds briefly with a tiny wobble, then returns under control.
function Curves.lift(r: number, profile: Profile?): number
	local p = profile or Curves.DEFAULT
	if r <= 0 or r >= 1 then
		return 0
	end
	local up, hold = p.up, p.hold
	if r < up then
		local x = r / up
		local s = Curves.smoother(x)
		local snap = p.snap or 0.5
		return Curves.lerp(s, Curves.outCubic(x), snap * 0.6)
	elseif r < up + hold then
		local x = (r - up) / hold
		return 1 - 0.025 * sin(x * pi)
	end
	local x = (r - up - hold) / (1 - up - hold)
	return 1 - Curves.inOutSine(x)
end

-- Damped oscillation, starts at 0, amplitude 1 at its first peak, fades in ~0.6 s.
function Curves.settle(t: number, freq: number?): number
	if t < 0 or t > 1.2 then
		return 0
	end
	local f = freq or 7
	return math.exp(-t * 6) * sin(t * f * 2 * pi) * 1.6
end

-- Breathing wave (-1..1) for a period in seconds; inhale is slightly faster.
function Curves.breath(t: number, period: number): number
	local x = (t / period) % 1
	if x < 0.42 then
		return -cos(x / 0.42 * pi)
	end
	return cos((x - 0.42) / 0.58 * pi)
end

-- Smooth value noise in [-1, 1].
function Curves.noise(seed: number, t: number): number
	return clamp(math.noise(seed * 13.37, t, 0.5) * 2, -1, 1)
end

-- Frame-rate independent exponential approach.
function Curves.approach(current: number, target: number, rate: number, dt: number): number
	return target + (current - target) * math.exp(-rate * dt)
end

return Curves
