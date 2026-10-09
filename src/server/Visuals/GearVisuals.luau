--!strict
--[[
	GearVisuals: part-built training gear welded to an R15 character.

		GearVisuals.apply(character, equipped)   -- equipped: slot -> gear id (Config/Gear)

	Slots and where they sit:
	  Gloves    both hands        shell + palm pad + padded back + wrist strap
	  Shoes     both feet         sole, upper, rounded toe cap, laces, side stripe, heel collar
	  Belt      LowerTorso        band, tall lumbar panel, front buckle, belt keeper
	  Wraps     both lower arms   layered wraps at the wrist + closure tab
	  Headband  Head              band at forehead height, front logo, knot + tails

	Everything is sized from the body part it is welded to, so scaled avatars,
	Rthro proportions and Strength muscle scaling (BodyWidth/DepthScale) all fit.
	When a watched body part resizes or is replaced the gear rebuilds itself
	(debounced), so muscle growth never leaves gear floating or clipping.

	Tier language (Config/Gear Primary / Secondary / Material) with more detail
	per tier: T1-2 plain, T3 stitching + logo patches, T4 brass hardware,
	T5 gold trim, T6 white composite with a thin cyan light line.

	All parts live in the Folder "IronhavenGear" under the character, are
	Massless and non-colliding / non-queryable / non-touchable, and use Weld
	with a fixed C0 so they follow the client-side Motor6D animation exactly.
	apply() is idempotent and works for any R15 model (players and NPCs).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gear = require(Shared.Config.Gear)

local GearVisuals = {}

local FOLDER = "IronhavenGear"
local REBUILD_DELAY = 0.25

type Finish = { Material: Enum.Material, Color: Color3, Reflectance: number }
type Style = {
	Tier: number,
	Main: Finish, -- Primary colour + config material
	Panel: Finish, -- slightly deeper Main for padded panels
	Accent: Finish, -- Secondary colour (straps, stripes, laces)
	Sole: Finish,
	Hardware: Finish, -- buckles, eyelets, logo plates
	Trim: Finish?, -- T5 gold trim
	Line: Finish?, -- T6 thin cyan neon line
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function finish(material: Enum.Material, color: Color3, reflectance: number?): Finish
	return { Material = material, Color = color, Reflectance = reflectance or 0 }
end

-- Per-tier non-config finishes (soles and hardware read as one product line).
local SOLES: { Finish } = {
	finish(Enum.Material.SmoothPlastic, rgb(246, 244, 238)),
	finish(Enum.Material.Rubber, rgb(36, 36, 39)),
	finish(Enum.Material.Rubber, rgb(26, 26, 28)),
	finish(Enum.Material.Rubber, rgb(150, 104, 62)), -- gum sole
	finish(Enum.Material.Rubber, rgb(20, 20, 22)),
	finish(Enum.Material.SmoothPlastic, rgb(244, 246, 248)),
}
local HARDWARE: { Finish } = {
	finish(Enum.Material.SmoothPlastic, rgb(245, 245, 240)),
	finish(Enum.Material.Metal, rgb(120, 124, 130), 0.06),
	finish(Enum.Material.Metal, rgb(206, 210, 214), 0.3), -- chrome
	finish(Enum.Material.Metal, rgb(196, 160, 90), 0.12), -- brass
	finish(Enum.Material.Metal, rgb(214, 172, 72), 0.18), -- gold
	finish(Enum.Material.Metal, rgb(154, 160, 166), 0.1), -- titanium
}
local GOLD = finish(Enum.Material.Metal, rgb(214, 172, 72), 0.2)
local CYAN = finish(Enum.Material.Neon, rgb(110, 226, 236))

local styleCache: { [string]: Style } = {}

local function styleFor(def: Gear.GearDef): Style
	local cached = styleCache[def.Id]
	if cached then
		return cached
	end
	local mat = Enum.Material:FromName(def.Material) or Enum.Material.SmoothPlastic
	local tier = math.clamp(def.Tier, 1, 6)
	local st: Style = {
		Tier = tier,
		Main = finish(mat, def.Primary),
		Panel = finish(mat, def.Primary:Lerp(Color3.new(0, 0, 0), 0.14)),
		Accent = finish(if tier >= 4 then Enum.Material.Leather else Enum.Material.Fabric, def.Secondary),
		Sole = SOLES[tier],
		Hardware = HARDWARE[tier],
		Trim = if tier == 5 then GOLD else nil,
		Line = if tier == 6 then CYAN else nil,
	}
	if tier == 6 then
		-- composite tier: accents are painted panels, not fabric
		st.Accent = finish(Enum.Material.SmoothPlastic, rgb(200, 206, 212))
	elseif tier == 5 then
		st.Accent = GOLD
	end
	styleCache[def.Id] = st
	return st
end

---------------------------------------------------------------------------
-- Part helpers
---------------------------------------------------------------------------
-- Creates a gear part welded to `body` at `offset` (in the body part's space).
local function piece(folder: Folder, body: BasePart, name: string, f: Finish, size: Vector3, offset: CFrame, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = Vector3.new(math.max(size.X, 0.01), math.max(size.Y, 0.01), math.max(size.Z, 0.01))
	p.Material = f.Material
	p.Color = f.Color
	p.Reflectance = f.Reflectance
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = body.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = body
	w.Part1 = p
	w.C0 = offset
	w.Parent = p
	p.Parent = folder
	return p
end

-- A box "ring" hugging a limb: `size` is the outer box, centred at `offset`.
local function band(folder: Folder, body: BasePart, name: string, f: Finish, size: Vector3, offset: CFrame): Part
	return piece(folder, body, name, f, size, offset)
end

-- Thin horizontal ring just proud of a band (stitching, trim, light line).
local function edge(folder: Folder, body: BasePart, name: string, f: Finish, outer: Vector3, height: number, y: number, grow: number)
	band(folder, body, name, f, Vector3.new(outer.X + grow, height, outer.Z + grow), CFrame.new(0, y, 0))
end

local function bodyPart(character: Model, name: string): BasePart?
	local p = character:FindFirstChild(name)
	if p and p:IsA("BasePart") then
		return p :: BasePart
	end
	return nil
end

-- +1 for the character's right side (local +X is outward), -1 for the left.
local function sideOf(name: string): number
	return if string.sub(name, 1, 5) == "Right" then 1 else -1
end

---------------------------------------------------------------------------
-- Gloves: shell over the upper hand, palm pad, padded back, wrist strap.
---------------------------------------------------------------------------
local function glove(folder: Folder, hand: BasePart, st: Style)
	local s = hand.Size
	local side = sideOf(hand.Name)
	local t = math.clamp(math.min(s.X, s.Z) * 0.07, 0.025, 0.08)
	local shellH = s.Y * 0.82
	local shellY = s.Y * 0.09
	local shell = Vector3.new(s.X + t * 2, shellH, s.Z + t * 2)
	band(folder, hand, "GloveShell", st.Main, shell, CFrame.new(0, shellY, 0))

	-- palm pad (inner face) and padded back (outer face)
	piece(folder, hand, "GlovePalm", st.Accent, Vector3.new(t, shellH * 0.72, s.Z * 0.8), CFrame.new(-side * (shell.X / 2 + t * 0.4), shellY - shellH * 0.04, 0))
	local back = Vector3.new(t * 1.8, shellH * 0.66, s.Z * 0.74)
	local backX = side * (shell.X / 2 + back.X * 0.4)
	piece(folder, hand, "GloveBack", st.Panel, back, CFrame.new(backX, shellY, 0))

	-- wrist strap straddling the wrist joint
	local strapH = math.clamp(s.Y * 0.34, 0.08, 0.24)
	local strap = Vector3.new(s.X + t * 4, strapH, s.Z + t * 4)
	local strapY = s.Y / 2 + strapH * 0.18
	band(folder, hand, "GloveStrap", st.Accent, strap, CFrame.new(0, strapY, 0))

	if st.Tier >= 2 then
		-- hook-and-loop tab on the outside of the strap
		piece(folder, hand, "GloveTab", st.Panel, Vector3.new(t * 1.2, strapH * 0.86, s.Z * 0.42), CFrame.new(side * (strap.X / 2 + t * 0.5), strapY, -s.Z * 0.12))
	end
	if st.Tier >= 3 then
		-- logo patch on the padded back
		local logo = math.min(back.Y, back.Z) * 0.34
		piece(folder, hand, "GloveLogo", st.Hardware, Vector3.new(t * 0.6, logo, logo), CFrame.new(backX + side * (back.X / 2 + t * 0.2), shellY, 0))
	end
	local trim = st.Trim
	if trim then
		edge(folder, hand, "GloveTrimTop", trim, strap, 0.022, strapY + strapH / 2 - 0.011, 0.012)
		edge(folder, hand, "GloveTrimLow", trim, strap, 0.022, strapY - strapH / 2 + 0.011, 0.012)
	end
	local line = st.Line
	if line then
		edge(folder, hand, "GloveLine", line, strap, 0.02, strapY, 0.014)
	end
end

---------------------------------------------------------------------------
-- Trainers: sole, upper, rounded toe + cap, laces, stripe, heel collar.
-- Foot front is local -Z; the sole sits flush with the foot bottom so the
-- avatar never sinks into the floor.
---------------------------------------------------------------------------
local CYL_X = CFrame.new() -- cylinders run along local X already

local function trainer(folder: Folder, foot: BasePart, st: Style)
	local s = foot.Size
	local side = sideOf(foot.Name)
	local soleH = math.clamp(s.Y * 0.3, 0.06, 0.16)
	local length = s.Z * 1.1 + 0.05
	local width = s.X * 1.04 + 0.04
	local zc = -s.Z * 0.04 -- shoe extends slightly past the toes
	local bottom = -s.Y / 2 + 0.004
	piece(folder, foot, "Sole", st.Sole, Vector3.new(width + 0.02, soleH, length + 0.02), CFrame.new(0, bottom + soleH / 2, zc))

	-- upper: box from the heel to the toe-cylinder centre, rounded front
	local upperH = math.max(0.08, s.Y - soleH + math.clamp(s.Y * 0.3, 0.04, 0.2))
	local upperY = bottom + soleH + upperH / 2 - 0.004
	local front = zc - length / 2
	local toeZ = front + upperH / 2
	local back = zc + length / 2
	local boxLen = back - toeZ
	piece(folder, foot, "Upper", st.Main, Vector3.new(width, upperH, boxLen), CFrame.new(0, upperY, toeZ + boxLen / 2))
	piece(folder, foot, "Toe", st.Main, Vector3.new(width, upperH, upperH), CFrame.new(0, upperY, toeZ) * CYL_X, Enum.PartType.Cylinder)
	-- toe cap: slightly proud, lower half of the toe in sole colour
	local capD = upperH * 0.78 + 0.02
	piece(folder, foot, "ToeCap", if st.Tier == 6 then st.Accent else st.Sole, Vector3.new(width + 0.012, capD, capD), CFrame.new(0, bottom + soleH + capD / 2 - 0.02, toeZ - (upperH - capD) / 2 + 0.004), Enum.PartType.Cylinder)

	-- heel collar rising onto the ankle
	local collarH = upperH * 0.42
	piece(folder, foot, "Collar", st.Panel, Vector3.new(width * 0.96, collarH, boxLen * 0.34), CFrame.new(0, upperY + upperH / 2 + collarH / 2 - 0.01, back - boxLen * 0.17))

	-- side stripe on the outer face (gold on T5, light line on T6)
	local stripeF = st.Trim or st.Line or st.Accent
	local stripeH = if st.Line then 0.024 else math.max(0.03, upperH * 0.22)
	piece(folder, foot, "Stripe", stripeF, Vector3.new(0.02, stripeH, boxLen * 0.62), CFrame.new(side * (width / 2 + 0.008), bottom + soleH + upperH * 0.42, toeZ + boxLen * 0.42) * CFrame.Angles(math.rad(-10), 0, 0))
	if st.Line then
		piece(folder, foot, "StripeIn", st.Line :: Finish, Vector3.new(0.02, stripeH, boxLen * 0.62), CFrame.new(-side * (width / 2 + 0.008), bottom + soleH + upperH * 0.42, toeZ + boxLen * 0.42) * CFrame.Angles(math.rad(-10), 0, 0))
	end

	-- laces (sleek strapless composite on T6)
	if st.Tier < 6 then
		local top = upperY + upperH / 2
		for i = 0, 2 do
			piece(folder, foot, "Lace", st.Accent, Vector3.new(width * 0.46, 0.022, 0.034), CFrame.new(0, top + 0.008, toeZ + boxLen * (0.08 + 0.13 * i)))
		end
	else
		piece(folder, foot, "Tongue", st.Accent, Vector3.new(width * 0.5, 0.02, boxLen * 0.42), CFrame.new(0, upperY + upperH / 2 + 0.008, toeZ + boxLen * 0.26))
	end
	if st.Tier >= 3 then
		-- heel tab / pull loop
		piece(folder, foot, "HeelTab", st.Hardware, Vector3.new(width * 0.22, collarH * 0.9, 0.03), CFrame.new(0, upperY + upperH / 2 + collarH * 0.4, back + 0.012))
	end
end

---------------------------------------------------------------------------
-- Lifting belt around the LowerTorso: band, lumbar panel, buckle, keeper.
---------------------------------------------------------------------------
local function belt(folder: Folder, torso: BasePart, st: Style)
	local s = torso.Size
	local t = math.clamp(s.X * 0.03, 0.04, 0.09)
	local h = math.clamp(s.Y * 0.95, 0.22, 0.62)
	local y = s.Y * 0.06
	local outer = Vector3.new(s.X + t * 2, h, s.Z + t * 2)
	band(folder, torso, "BeltBand", st.Main, outer, CFrame.new(0, y, 0))

	-- tall lumbar panel at the back (+Z)
	piece(folder, torso, "BeltLumbar", st.Panel, Vector3.new(s.X * 0.56, h * 1.42, t), CFrame.new(0, y + h * 0.05, outer.Z / 2 + t * 0.4))

	-- buckle at the front (-Z): metal frame with a strap-coloured window
	local bw, bh = s.X * 0.2, h * 0.86
	local bz = -(outer.Z / 2 + t * 0.45)
	piece(folder, torso, "Buckle", st.Hardware, Vector3.new(bw, bh, t * 0.9), CFrame.new(0, y, bz))
	if st.Tier < 4 then
		piece(folder, torso, "BuckleWindow", st.Panel, Vector3.new(bw * 0.58, bh * 0.56, t * 0.4), CFrame.new(0, y, bz - t * 0.42))
		piece(folder, torso, "BucklePin", st.Hardware, Vector3.new(bw * 0.12, bh * 0.56, t * 0.5), CFrame.new(0, y, bz - t * 0.5))
	else
		-- lever buckle: solid plate with an engraved centre line
		piece(folder, torso, "BuckleLever", st.Hardware, Vector3.new(bw * 0.86, bh * 0.3, t * 0.5), CFrame.new(0, y + bh * 0.12, bz - t * 0.5))
	end
	if st.Tier >= 2 then
		-- keeper loop beside the buckle
		piece(folder, torso, "Keeper", st.Accent, Vector3.new(bw * 0.3, h * 1.02, t * 0.7), CFrame.new(-bw * 1.05, y, bz + t * 0.1))
	end
	if st.Tier >= 3 then
		local stitch = if st.Trim then st.Trim :: Finish else st.Accent
		local th = if st.Trim then 0.03 else 0.016
		edge(folder, torso, "BeltEdgeTop", stitch, outer, th, y + h / 2 - 0.045, 0.012)
		edge(folder, torso, "BeltEdgeLow", stitch, outer, th, y - h / 2 + 0.045, 0.012)
	end
	local line = st.Line
	if line then
		edge(folder, torso, "BeltLine", line, outer, 0.022, y, 0.014)
	end
end

---------------------------------------------------------------------------
-- Wrist wraps near the wrist end (-Y) of each lower arm.
---------------------------------------------------------------------------
local function wrap(folder: Folder, arm: BasePart, st: Style)
	local s = arm.Size
	local side = sideOf(arm.Name)
	local t = math.clamp(math.min(s.X, s.Z) * 0.06, 0.025, 0.07)
	local h = math.clamp(s.Y * 0.3, 0.16, 0.42)
	local y = -s.Y / 2 + h / 2 + 0.01
	local outer = Vector3.new(s.X + t * 2, h, s.Z + t * 2)
	band(folder, arm, "Wrap", st.Main, outer, CFrame.new(0, y, 0))

	-- two tilted turns read as layered wrapping
	local turnF = if st.Tier >= 2 then st.Accent else st.Panel
	for i, k in { -0.24, 0.22 } do
		band(folder, arm, "WrapTurn" .. i, turnF, Vector3.new(outer.X + 0.012, h * 0.22, outer.Z + 0.012), CFrame.new(0, y + h * k, 0) * CFrame.Angles(0, 0, math.rad(if i == 1 then 7 else -7)))
	end
	-- closure tab on the outside
	piece(folder, arm, "WrapTab", st.Panel, Vector3.new(t * 1.3, h * 0.56, s.Z * 0.46), CFrame.new(side * (outer.X / 2 + t * 0.55), y, 0))
	if st.Tier >= 3 then
		local logo = math.min(h * 0.32, s.Z * 0.2)
		piece(folder, arm, "WrapLogo", st.Hardware, Vector3.new(t * 0.6, logo, logo), CFrame.new(side * (outer.X / 2 + t * 1.3), y, 0))
	end
	local trim = st.Trim
	if trim then
		edge(folder, arm, "WrapTrim", trim, outer, 0.024, y + h / 2 - 0.012, 0.014)
	end
	local line = st.Line
	if line then
		edge(folder, arm, "WrapLine", line, outer, 0.02, y, 0.016)
	end
end

---------------------------------------------------------------------------
-- Headband at forehead height (cylinder band, axis vertical).
---------------------------------------------------------------------------
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

-- Visual head size. Classic heads are a 2x1x1 part drawn by a scaled head mesh.
local function headSize(head: BasePart): (number, number)
	local s = head.Size
	local mesh = head:FindFirstChildOfClass("SpecialMesh") :: SpecialMesh?
	if mesh and mesh.MeshType == Enum.MeshType.Head then
		local d = math.min(s.Y, s.Z) * mesh.Scale.Y
		return d, d
	end
	-- mesh heads: bounding box (clamp very wide heads, e.g. accessories baked in)
	return math.min(math.max(s.X, s.Z), s.Y * 1.3), s.Y
end

local function headband(folder: Folder, head: BasePart, st: Style)
	local d, hgt = headSize(head)
	local dia = d * 1.03 + 0.05
	local bh = math.clamp(hgt * 0.17, 0.12, 0.32)
	local y = hgt * 0.16
	piece(folder, head, "Headband", st.Main, Vector3.new(bh, dia, dia), CFrame.new(0, y, 0) * UPRIGHT, Enum.PartType.Cylinder)

	if st.Tier >= 2 then
		-- front logo plate (-Z)
		piece(folder, head, "HeadbandLogo", if st.Tier >= 3 then st.Hardware else st.Accent, Vector3.new(dia * 0.2, bh * 0.56, 0.03), CFrame.new(0, y, -dia / 2 - 0.006))
	end
	if st.Tier >= 3 then
		-- knot and two tails at the back (+Z)
		piece(folder, head, "Knot", st.Panel, Vector3.new(dia * 0.13, bh * 1.15, 0.09), CFrame.new(0, y, dia / 2 + 0.02))
		local tailLen = hgt * 0.36
		for _, k in { -1, 1 } do
			piece(folder, head, "Tail", st.Main, Vector3.new(dia * 0.085, tailLen, 0.03), CFrame.new(k * dia * 0.05, y - tailLen * 0.42, dia / 2 + 0.07) * CFrame.Angles(math.rad(18), 0, math.rad(k * 9)))
		end
	end
	local trim = st.Trim
	if trim then
		for _, k in { -1, 1 } do
			piece(folder, head, "HeadbandTrim", trim, Vector3.new(0.022, dia + 0.012, dia + 0.012), CFrame.new(0, y + k * (bh / 2 - 0.011), 0) * UPRIGHT, Enum.PartType.Cylinder)
		end
	end
	local line = st.Line
	if line then
		piece(folder, head, "HeadbandLine", line, Vector3.new(0.024, dia + 0.014, dia + 0.014), CFrame.new(0, y, 0) * UPRIGHT, Enum.PartType.Cylinder)
	end
end

---------------------------------------------------------------------------
-- Build + watch
---------------------------------------------------------------------------
type Builder = (folder: Folder, body: BasePart, st: Style) -> ()
local SLOT_PARTS: { [string]: { parts: { string }, build: Builder } } = {
	Gloves = { parts = { "LeftHand", "RightHand" }, build = glove },
	Shoes = { parts = { "LeftFoot", "RightFoot" }, build = trainer },
	Belt = { parts = { "LowerTorso" }, build = belt },
	Wraps = { parts = { "LeftLowerArm", "RightLowerArm" }, build = wrap },
	Headband = { parts = { "Head" }, build = headband },
}

type Watch = { equipped: { [string]: string }, conns: { RBXScriptConnection }, queued: boolean }
local watches: { [Model]: Watch } = {}

local function unwatch(character: Model)
	local w = watches[character]
	if w then
		watches[character] = nil
		for _, c in w.conns do
			c:Disconnect()
		end
	end
end

local function build(character: Model, equipped: { [string]: string }): { BasePart }
	local old = character:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local used: { BasePart } = {}
	local folder: Folder? = nil
	for slot, id in equipped do
		local def = Gear.get(id)
		local spec = SLOT_PARTS[slot]
		if def and spec and def.Slot == slot then
			local st = styleFor(def)
			for _, name in spec.parts do
				local body = bodyPart(character, name)
				if body then
					if not folder then
						local f = Instance.new("Folder")
						f.Name = FOLDER
						folder = f
					end
					spec.build(folder :: Folder, body, st)
					table.insert(used, body)
				end
			end
		end
	end
	if folder then
		folder.Parent = character
	end
	return used
end

-- Rebuild after body parts resize (muscle scaling) or get replaced (avatar load).
local function watch(character: Model, equipped: { [string]: string }, used: { BasePart })
	unwatch(character)
	if next(equipped) == nil then
		return
	end
	local w: Watch = { equipped = table.clone(equipped), conns = {}, queued = false }
	watches[character] = w
	local function schedule()
		if w.queued or watches[character] ~= w then
			return
		end
		w.queued = true
		task.delay(REBUILD_DELAY, function()
			if watches[character] == w and character.Parent then
				GearVisuals.apply(character, w.equipped)
			end
		end)
	end
	local names: { [string]: boolean } = {}
	for slot in equipped do
		local spec = SLOT_PARTS[slot]
		if spec then
			for _, n in spec.parts do
				names[n] = true
			end
		end
	end
	for _, body in used do
		table.insert(w.conns, body:GetPropertyChangedSignal("Size"):Connect(schedule))
	end
	table.insert(
		w.conns,
		character.ChildAdded:Connect(function(child: Instance)
			if names[child.Name] and child:IsA("BasePart") then
				schedule()
			end
		end)
	)
	table.insert(
		w.conns,
		character.AncestryChanged:Connect(function()
			if not character:IsDescendantOf(game) then
				unwatch(character)
			end
		end)
	)
	table.insert(w.conns, character.Destroying:Connect(function()
		unwatch(character)
	end))
end

function GearVisuals.apply(character: Model, equipped: { [string]: string })
	local list = if type(equipped) == "table" then equipped else {}
	local used = build(character, list)
	watch(character, list, used)
end

return GearVisuals
