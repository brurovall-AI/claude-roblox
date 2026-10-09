--!strict
--[[
	R15 rig access + inverse kinematics for the procedural animation engine.

		local rig = Rig.get(character)            -- nil for R6 / incomplete rigs
		Rig.measure(rig)                          -- re-read joint offsets (avatar rescaled)
		out.Root = CFrame.new(0, -0.4, 0)         -- FK: joint name -> Motor6D.Transform
		Rig.armIK(rig, out, "Right", target, pole)   -- hand centre to `target`
		Rig.legIK(rig, out, "Left", ankle, pole, footRot)

	Conventions (standard R15: joint attachments are axis aligned):
	  * every target / pole is in HumanoidRootPart space (X right, Y up, Z back)
	  * Transform rotations are in the parent part's axes:
	      shoulder X+ raises the arm forward, Z+ abducts the RIGHT arm (Z- the left)
	      elbow X+ flexes, hip X+ flexes the thigh forward, knee X- flexes
	      waist X- bends forward, Y+ turns left; neck X- looks down; ankle X+ toes up
	  * Root is the LowerTorso joint: rotating / translating it moves the whole body
	    while the HumanoidRootPart (anchored on the station) stays put.
	IK reads out.Root / out.Waist, so programs set the trunk first, then limbs.
	Limb geometry is measured from the real joints (R15 shoulders sit on the
	torso edge, so the upper-arm "bone" is not straight down) and the solver
	keeps elbows / knees as true hinges.
]]

local Rig = {}

export type Side = "Left" | "Right"
export type Out = { [string]: CFrame }

-- A two-segment limb in its own rest axes: `a` = root joint -> hinge joint
-- (in the upper segment's space), `g` = hinge joint -> end point (in the lower
-- segment's space).
export type Bone = { a: Vector3, g: Vector3 }

export type Rig = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	motors: { [string]: Motor6D },
	c0: { [string]: CFrame },
	c1: { [string]: CFrame },
	written: { [string]: CFrame }, -- last Transform written per joint (animator detection)
	bones: { [string]: Bone }, -- "LeftArm" / "RightArm" / "LeftLeg" / "RightLeg"
	restAnkle: { [string]: Vector3 }, -- planted standing ankles (HRP space)
	restShoulder: { [string]: Vector3 },
	restHip: { [string]: Vector3 },
	floorY: number, -- standing floor height in HRP space (negative)
	ankleHeight: number, -- ankle joint above the sole
	trunk: number, -- root pivot -> shoulder line height
	measuredAt: number,
}

Rig.JOINTS = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	LeftWrist = "LeftHand",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftHip = "LeftUpperLeg",
	LeftKnee = "LeftLowerLeg",
	LeftAnkle = "LeftFoot",
	RightHip = "RightUpperLeg",
	RightKnee = "RightLowerLeg",
	RightAnkle = "RightFoot",
} :: { [string]: string }

-- Joint names in parent-before-child order (used when applying / restoring).
Rig.ORDER = {
	"Root",
	"Waist",
	"Neck",
	"LeftShoulder",
	"LeftElbow",
	"LeftWrist",
	"RightShoulder",
	"RightElbow",
	"RightWrist",
	"LeftHip",
	"LeftKnee",
	"LeftAnkle",
	"RightHip",
	"RightKnee",
	"RightAnkle",
}

Rig.LOWER = { Root = true, LeftHip = true, LeftKnee = true, LeftAnkle = true, RightHip = true, RightKnee = true, RightAnkle = true } :: { [string]: boolean }

local IDENTITY = CFrame.identity
local DOWN = Vector3.new(0, -1, 0)

function Rig.measure(rig: Rig)
	local c0, c1 = rig.c0, rig.c1
	for name, motor in rig.motors do
		c0[name] = motor.C0
		c1[name] = motor.C1
	end
	for _, side in { "Left", "Right" } do
		rig.bones[side .. "Arm"] = {
			a = c0[side .. "Elbow"].Position - c1[side .. "Shoulder"].Position,
			-- hinge -> hand centre (the hand hangs straight below the wrist joint)
			g = c0[side .. "Wrist"].Position - c1[side .. "Elbow"].Position - c1[side .. "Wrist"].Position,
		}
		rig.bones[side .. "Leg"] = {
			a = c0[side .. "Knee"].Position - c1[side .. "Hip"].Position,
			g = c0[side .. "Ankle"].Position - c1[side .. "Knee"].Position,
		}
	end

	local lt = c0.Root * c1.Root:Inverse()
	local ut = lt * c0.Waist * c1.Waist:Inverse()
	for _, side in { "Left", "Right" } do
		rig.restShoulder[side] = (ut * c0[side .. "Shoulder"]).Position
		local hip = lt * c0[side .. "Hip"]
		rig.restHip[side] = hip.Position
		local knee = hip * c1[side .. "Hip"]:Inverse() * c0[side .. "Knee"]
		rig.restAnkle[side] = (knee * c1[side .. "Knee"]:Inverse() * c0[side .. "Ankle"]).Position
	end
	rig.floorY = -(rig.humanoid.HipHeight + rig.root.Size.Y * 0.5)
	rig.ankleHeight = math.max(0.1, rig.restAnkle.Right.Y - rig.floorY)
	rig.trunk = math.max(0.5, rig.restShoulder.Right.Y - c0.Root.Position.Y)
	rig.measuredAt = os.clock()
end

-- Returns a rig for R15 characters (players or NPC models), nil otherwise.
function Rig.get(model: Model): Rig?
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid?
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root or hum.RigType ~= Enum.HumanoidRigType.R15 then
		return nil
	end
	local motors: { [string]: Motor6D } = {}
	for joint, partName in Rig.JOINTS do
		local part = model:FindFirstChild(partName)
		local m = part and part:FindFirstChild(joint)
		if not m or not m:IsA("Motor6D") then
			return nil
		end
		motors[joint] = m :: Motor6D
	end
	local rig: Rig = {
		model = model,
		humanoid = hum,
		root = root,
		motors = motors,
		c0 = {},
		c1 = {},
		written = {},
		bones = {},
		restAnkle = {},
		restShoulder = {},
		restHip = {},
		floorY = -3,
		ankleHeight = 0.3,
		trunk = 1.4,
		measuredAt = 0,
	}
	Rig.measure(rig)
	return rig
end

-- True while every cached joint is still parented (characters can be rebuilt).
function Rig.valid(rig: Rig): boolean
	if not rig.root.Parent or not rig.humanoid.Parent then
		return false
	end
	for _, m in rig.motors do
		if not m.Parent then
			return false
		end
	end
	return true
end

---------------------------------------------------------------------------
-- Forward kinematics (HRP space)
---------------------------------------------------------------------------
function Rig.lowerTorso(rig: Rig, out: Out): CFrame
	return rig.c0.Root * (out.Root or IDENTITY) * rig.c1.Root:Inverse()
end

function Rig.upperTorso(rig: Rig, out: Out): CFrame
	return Rig.lowerTorso(rig, out) * rig.c0.Waist * (out.Waist or IDENTITY) * rig.c1.Waist:Inverse()
end

function Rig.shoulderPos(rig: Rig, out: Out, side: Side): Vector3
	return (Rig.upperTorso(rig, out) * rig.c0[side .. "Shoulder"]).Position
end

function Rig.hipPos(rig: Rig, out: Out, side: Side): Vector3
	return (Rig.lowerTorso(rig, out) * rig.c0[side .. "Hip"]).Position
end

-- Planted ankle target for a standing pose, offset in HRP space.
function Rig.plant(rig: Rig, side: Side, dx: number?, dz: number?, dy: number?): Vector3
	local a = rig.restAnkle[side]
	return Vector3.new(a.X + (dx or 0), a.Y + (dy or 0), a.Z + (dz or 0))
end

-- Ankle target for a foot standing on a surface `floor` (HRP-space height).
function Rig.onFloor(rig: Rig, x: number, floor: number, z: number): Vector3
	return Vector3.new(x, floor + rig.ankleHeight, z)
end

---------------------------------------------------------------------------
-- Two-bone IK with hinge-correct elbows / knees
---------------------------------------------------------------------------
local function perp(v: Vector3, axis: Vector3): Vector3
	return v - axis * v:Dot(axis)
end

-- Solves a hinged limb in its root joint frame. p = target, pole = where the
-- middle joint should point. `sign` = +1 for elbows (flex about +X), -1 for
-- knees (flex about -X). Returns (root rotation, hinge rotation).
local function solve(p: Vector3, pole: Vector3, bone: Bone, sign: number): (CFrame, CFrame)
	local a, g = bone.a, bone.g
	local la, lg = a.Magnitude, g.Magnitude
	-- |a + Rx(t) g|^2 = la^2 + lg^2 + 2 (a.x g.x + A cos t + B sin t)
	local A = a.Y * g.Y + a.Z * g.Z
	local B = a.Z * g.Y - a.Y * g.Z
	local R0 = math.sqrt(A * A + B * B)
	local base = la * la + lg * lg + 2 * a.X * g.X
	local dMin = math.sqrt(math.max(0, base - 2 * R0)) + 1e-3
	local dMax = math.sqrt(math.max(0, base + 2 * R0)) - 1e-3
	local dist = p.Magnitude
	local h1 = if dist > 1e-4 then p / dist else DOWN
	local d = math.clamp(dist, math.min(dMin, dMax), dMax)

	-- hinge angle (anatomical branch)
	local theta = 0
	if R0 > 1e-5 then
		local k = ((d * d - base) / 2) / R0
		theta = math.atan2(B, A) + sign * math.acos(math.clamp(k, -1, 1))
	end
	local hinge = CFrame.Angles(theta, 0, 0)
	local v = a + hinge * g

	-- where the middle joint goes (pole side of the target line)
	local aa = (la * la - lg * lg + d * d) / (2 * d)
	local hh = math.sqrt(math.max(0, la * la - aa * aa))
	local pp = perp(pole, h1)
	if pp.Magnitude < 1e-3 then
		pp = perp(if math.abs(h1.Z) < 0.9 then Vector3.new(0, 0, 1) else Vector3.new(1, 0, 0), h1)
	end
	local mid = h1 * aa + pp.Unit * hh

	-- rotate the limb triangle (0, a, v) onto (0, mid, target line)
	local f1 = v.Unit
	local f2 = perp(a, f1)
	if f2.Magnitude < 0.05 * la then
		f2 = perp(Vector3.new(0, 0, sign), f1) -- straight limb: bend side faces the pole
	end
	f2 = f2.Unit
	local h2 = perp(mid, h1)
	if h2.Magnitude < 1e-4 then
		h2 = pp
	end
	h2 = h2.Unit
	local F = CFrame.fromMatrix(Vector3.zero, f1, f2, f1:Cross(f2))
	local H = CFrame.fromMatrix(Vector3.zero, h1, h2, h1:Cross(h2))
	return H * F:Inverse(), hinge
end

-- Hand centre to `target` (HRP space). `pole` = where the elbow should point.
-- `handRot` (optional) = desired hand orientation in HRP space.
function Rig.armIK(rig: Rig, out: Out, side: Side, target: Vector3, pole: Vector3, handRot: CFrame?)
	local sName = side .. "Shoulder"
	local joint = Rig.upperTorso(rig, out) * rig.c0[sName]
	local rot, elbow = solve(joint:PointToObjectSpace(target), joint:VectorToObjectSpace(pole), rig.bones[side .. "Arm"], 1)
	out[sName] = rot
	out[side .. "Elbow"] = elbow
	if handRot then
		out[side .. "Wrist"] = (joint.Rotation * rot * elbow):Inverse() * handRot.Rotation
	elseif not out[side .. "Wrist"] then
		out[side .. "Wrist"] = IDENTITY
	end
end

-- Ankle joint to `target` (HRP space). `pole` = where the knee should point.
-- `footRot` (optional, default level with the HRP) = desired foot orientation.
function Rig.legIK(rig: Rig, out: Out, side: Side, target: Vector3, pole: Vector3, footRot: CFrame?)
	local hName = side .. "Hip"
	local joint = Rig.lowerTorso(rig, out) * rig.c0[hName]
	local rot, knee = solve(joint:PointToObjectSpace(target), joint:VectorToObjectSpace(pole), rig.bones[side .. "Leg"], -1)
	out[hName] = rot
	out[side .. "Knee"] = knee
	out[side .. "Ankle"] = (joint.Rotation * rot * knee):Inverse() * (if footRot then footRot.Rotation else IDENTITY)
end

return Rig
