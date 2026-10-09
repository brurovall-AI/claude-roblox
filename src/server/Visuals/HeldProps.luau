--!strict
--[[
	HeldProps: part-built props welded to a character's hands while training.

		HeldProps.attach(character, "Dumbbells", tier)  -- one dumbbell per hand
		HeldProps.attach(character, "Gloves", tier)     -- boxing gloves
		HeldProps.detach(character)

	Everything lives in a Folder "IronhavenHeld" under the character so attach is
	idempotent and detach is a single Destroy. Parts are Massless, non-colliding
	and non-queryable, welded with Weld (fixed C0) so they follow the procedural
	animation on every client without touching physics.

	Tier language (matches the station builders):
	  Dumbbells  T1 coloured vinyl hex · T2 black rubber hex · T3 chrome round
	             T4 graphite + brass collars · T5 black chrome + gold · T6 composite + cyan line
	  Gloves     T1-2 red vinyl · T3 red leather, white cuff · T4 tan leather, cream cuff
	             T5 black leather, gold trim · T6 white composite, cyan seam
]]

local HeldProps = {}

local FOLDER = "IronhavenHeld"

type Finish = { Material: Enum.Material, Color: Color3, Reflectance: number? }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local F: { [string]: Finish } = {
	VinylCoral = { Material = Enum.Material.SmoothPlastic, Color = rgb(232, 124, 92) },
	VinylTeal = { Material = Enum.Material.SmoothPlastic, Color = rgb(60, 168, 156) },
	Rubber = { Material = Enum.Material.Rubber, Color = rgb(30, 30, 33) },
	RubberGrip = { Material = Enum.Material.Rubber, Color = rgb(48, 48, 51) },
	Steel = { Material = Enum.Material.Metal, Color = rgb(150, 154, 160), Reflectance = 0.08 },
	Knurl = { Material = Enum.Material.DiamondPlate, Color = rgb(120, 124, 130) },
	Chrome = { Material = Enum.Material.Metal, Color = rgb(206, 210, 214), Reflectance = 0.35 },
	Graphite = { Material = Enum.Material.Metal, Color = rgb(58, 60, 64), Reflectance = 0.05 },
	Brass = { Material = Enum.Material.Metal, Color = rgb(196, 160, 90), Reflectance = 0.12 },
	BlackChrome = { Material = Enum.Material.Metal, Color = rgb(36, 36, 40), Reflectance = 0.28 },
	Gold = { Material = Enum.Material.Metal, Color = rgb(214, 172, 72), Reflectance = 0.18 },
	Composite = { Material = Enum.Material.SmoothPlastic, Color = rgb(236, 238, 240) },
	Titanium = { Material = Enum.Material.Metal, Color = rgb(154, 160, 166), Reflectance = 0.1 },
	Cyan = { Material = Enum.Material.Neon, Color = rgb(110, 226, 236) },
	LeatherRed = { Material = Enum.Material.Leather, Color = rgb(170, 38, 36) },
	VinylRed = { Material = Enum.Material.SmoothPlastic, Color = rgb(196, 46, 42) },
	LeatherTan = { Material = Enum.Material.Leather, Color = rgb(176, 124, 78) },
	LeatherBlack = { Material = Enum.Material.Leather, Color = rgb(28, 28, 30) },
	FabricWhite = { Material = Enum.Material.Fabric, Color = rgb(236, 234, 228) },
	FabricCream = { Material = Enum.Material.Fabric, Color = rgb(226, 214, 190) },
}

---------------------------------------------------------------------------
-- Part helpers
---------------------------------------------------------------------------
local function base(p: BasePart, finish: Finish, size: Vector3)
	p.Size = size
	p.Material = finish.Material
	p.Color = finish.Color
	p.Reflectance = finish.Reflectance or 0
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = size.Magnitude > 0.5
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

-- Welds `part` to `hand` at `offset` (in the hand's space) and parents it.
local function weld(folder: Folder, hand: BasePart, part: BasePart, offset: CFrame)
	part.CFrame = hand.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = hand
	w.Part1 = part
	w.C0 = offset
	w.Parent = part
	part.Parent = folder
end

local function box(folder: Folder, hand: BasePart, offset: CFrame, size: Vector3, finish: Finish): Part
	local p = Instance.new("Part")
	p.Name = "Prop"
	base(p, finish, size)
	weld(folder, hand, p, offset)
	return p
end

-- Cylinder along the offset's local X axis.
local function cyl(folder: Folder, hand: BasePart, offset: CFrame, length: number, diameter: number, finish: Finish): Part
	local p = Instance.new("Part")
	p.Name = "Prop"
	p.Shape = Enum.PartType.Cylinder
	base(p, finish, Vector3.new(length, diameter, diameter))
	weld(folder, hand, p, offset)
	return p
end

-- Ellipsoid (sphere SpecialMesh scaled to the part size; no asset ids needed).
local function ellipsoid(folder: Folder, hand: BasePart, offset: CFrame, size: Vector3, finish: Finish): Part
	local p = Instance.new("Part")
	p.Name = "Prop"
	base(p, finish, size)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	weld(folder, hand, p, offset)
	return p
end

-- Hexagonal prism along the offset's local X axis (three rotated blocks).
local function hex(folder: Folder, hand: BasePart, offset: CFrame, length: number, flats: number, finish: Finish)
	local side = flats / math.sqrt(3)
	for i = 0, 2 do
		box(folder, hand, offset * CFrame.Angles(math.rad(60 * i), 0, 0), Vector3.new(length, flats, side), finish)
	end
end

---------------------------------------------------------------------------
-- Dumbbells
---------------------------------------------------------------------------
-- Neutral (hammer) grip: the handle runs front-to-back through the fist (the
-- frame below is rotated so its local X is the hand's Z), keeping the heads
-- clear of the thighs while the arms hang. Grip centre sits slightly below
-- the hand centre so the fist wraps the bar.
local GRIP = CFrame.new(0, -0.12, 0) * CFrame.Angles(0, math.rad(90), 0)

local function dumbbell(folder: Folder, hand: BasePart, tier: number, colour: Finish)
	local handleLen, headGap = 0.92, 0.5
	local t = math.clamp(tier, 1, 6)
	-- handle
	local handleF = if t == 1 then F.Steel elseif t == 6 then F.Titanium else F.Knurl
	cyl(folder, hand, GRIP, handleLen + 0.5, 0.2, handleF)
	for _, sx in { -1, 1 } do
		local at = GRIP * CFrame.new(sx * headGap, 0, 0)
		local out = GRIP * CFrame.new(sx * (headGap + 0.17), 0, 0)
		if t == 1 then
			hex(folder, hand, out, 0.34, 0.62, colour)
		elseif t == 2 then
			hex(folder, hand, out, 0.36, 0.66, F.Rubber)
			cyl(folder, hand, at, 0.04, 0.3, F.Steel)
		elseif t == 3 then
			cyl(folder, hand, out, 0.34, 0.66, F.Chrome)
			cyl(folder, hand, GRIP * CFrame.new(sx * (headGap + 0.36), 0, 0), 0.04, 0.5, F.Chrome)
		elseif t == 4 then
			cyl(folder, hand, out, 0.34, 0.68, F.Graphite)
			cyl(folder, hand, at, 0.07, 0.36, F.Brass)
			cyl(folder, hand, GRIP * CFrame.new(sx * (headGap + 0.35), 0, 0), 0.03, 0.56, F.Brass)
		elseif t == 5 then
			cyl(folder, hand, out, 0.34, 0.7, F.BlackChrome)
			cyl(folder, hand, at, 0.06, 0.34, F.Gold)
			cyl(folder, hand, out, 0.06, 0.72, F.Gold)
		else
			cyl(folder, hand, out, 0.34, 0.64, F.Composite)
			cyl(folder, hand, out, 0.05, 0.66, F.Cyan)
			cyl(folder, hand, at, 0.05, 0.3, F.Titanium)
		end
	end
end

---------------------------------------------------------------------------
-- Boxing gloves
---------------------------------------------------------------------------
type GloveStyle = { shell: Finish, cuff: Finish, trim: Finish? }

local function gloveStyle(tier: number): GloveStyle
	if tier >= 6 then
		return { shell = F.Composite, cuff = F.Titanium, trim = F.Cyan }
	elseif tier == 5 then
		return { shell = F.LeatherBlack, cuff = F.LeatherBlack, trim = F.Gold }
	elseif tier == 4 then
		return { shell = F.LeatherTan, cuff = F.FabricCream, trim = F.Brass }
	elseif tier == 3 then
		return { shell = F.LeatherRed, cuff = F.FabricWhite, trim = nil }
	end
	return { shell = F.VinylRed, cuff = F.FabricWhite, trim = nil }
end

local function glove(folder: Folder, hand: BasePart, side: number, tier: number)
	local s = gloveStyle(tier)
	-- main padded mitt engulfing the fist (elongated along the hand's length)
	ellipsoid(folder, hand, CFrame.new(0, -0.22, 0), Vector3.new(0.96, 1.14, 1.02), s.shell)
	-- thumb along the inner side
	ellipsoid(folder, hand, CFrame.new(-side * 0.42, -0.1, -0.14) * CFrame.Angles(0, 0, math.rad(side * 12)), Vector3.new(0.32, 0.62, 0.36), s.shell)
	-- cuff around the wrist (cylinder along the hand's Y)
	local cuffAxis = CFrame.Angles(0, 0, math.rad(90))
	cyl(folder, hand, CFrame.new(0, 0.3, 0) * cuffAxis, 0.42, 0.8, s.cuff)
	if s.trim then
		cyl(folder, hand, CFrame.new(0, 0.11, 0) * cuffAxis, 0.05, 0.84, s.trim :: Finish)
	else
		-- brand strip on the outer side of the cuff
		box(folder, hand, CFrame.new(side * 0.41, 0.3, 0), Vector3.new(0.04, 0.34, 0.46), F.FabricWhite)
	end
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------
local function hands(character: Model): (BasePart?, BasePart?)
	local r = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local l = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	local rp = if r and r:IsA("BasePart") then r :: BasePart else nil
	local lp = if l and l:IsA("BasePart") then l :: BasePart else nil
	return rp, lp
end

function HeldProps.detach(character: Model)
	local old = character:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
end

function HeldProps.attach(character: Model, heldType: string, tier: number): Folder?
	HeldProps.detach(character)
	local right, left = hands(character)
	if not right or not left then
		return nil
	end
	local t = math.clamp(math.floor(tier), 1, 6)
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	if heldType == "Dumbbells" then
		-- Beginner pairs come in two friendly colours
		dumbbell(folder, right, t, F.VinylCoral)
		dumbbell(folder, left, t, F.VinylTeal)
	elseif heldType == "Gloves" then
		glove(folder, right, 1, t)
		glove(folder, left, -1, t)
	else
		folder:Destroy()
		return nil
	end
	folder.Parent = character
	return folder
end

return HeldProps
