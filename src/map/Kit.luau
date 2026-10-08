--!strict
--[[
	Map building kit. Runs both under Lune (bake) and inside Roblox, using only
	Instance/CFrame/Vector3/Color3/Enum/UDim2/Font — never game/workspace/task.

	Conventions
	  * Units are studs. 1 stud = 0.28 m. A standing R15 character is ~5.3 studs.
	  * Every part is Anchored. Structural parts collide; small details don't
	    (pass Kit.DETAIL or opts) so physics stays cheap.
	  * Positions are given as CFrames; build objects in local space with
	    Kit.at(origin, x, y, z) so whole assemblies can be rotated/moved.
	  * Part.Shape Cylinder runs along the part's local X axis (RightVector).
	  * WedgeParts are tall at their back (+Z local) and slope down to the front (-Z).

	Finish argument: a Palette finish name ("Oak") or a Palette.Finish table.
]]

local Palette = require("./Palette")

export type FinishArg = string | Palette.Finish
export type Opts = {
	Name: string?,
	Collide: boolean?, -- default true unless Detail
	Shadow: boolean?, -- default: true when the part is bigger than ~1.5 studs
	Query: boolean?, -- CanQuery (default = Collide)
	Touch: boolean?, -- CanTouch (default false)
	Transparency: number?,
	Color: Color3?,
	Material: Enum.Material?,
	Reflectance: number?,
}

local Kit = {}

Kit.DETAIL = { Collide = false } :: Opts
Kit.SOLID = { Collide = true } :: Opts

local function resolveFinish(f: FinishArg): Palette.Finish
	if type(f) == "string" then
		return Palette.get(f)
	end
	return f
end

local function applyFinish(p: BasePart, finish: FinishArg, opts: Opts?)
	local f = resolveFinish(finish)
	p.Material = if opts and opts.Material then opts.Material else f.Material
	p.Color = if opts and opts.Color then opts.Color else f.Color
	p.Reflectance = (if opts and opts.Reflectance then opts.Reflectance else f.Reflectance) or 0
	p.Transparency = (if opts and opts.Transparency then opts.Transparency else f.Transparency) or 0
end

local function setup(p: BasePart, parent: Instance, cf: CFrame, size: Vector3, finish: FinishArg, opts: Opts?)
	local o: Opts = opts or {}
	p.Name = o.Name or p.Name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	applyFinish(p, finish, opts)
	local collide = if o.Collide == nil then true else o.Collide
	p.CanCollide = collide
	p.CanQuery = if o.Query == nil then collide else o.Query
	p.CanTouch = o.Touch == true
	local biggest = math.max(size.X, size.Y, size.Z)
	p.CastShadow = if o.Shadow == nil then biggest >= 1.5 else o.Shadow
	p.Parent = parent
end

---------------------------------------------------------------------------
-- Containers
---------------------------------------------------------------------------
function Kit.model(parent: Instance, name: string, pivot: CFrame?): Model
	local m = Instance.new("Model")
	m.Name = name
	if pivot then
		m.WorldPivot = pivot
	end
	m.Parent = parent
	return m
end

function Kit.folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

---------------------------------------------------------------------------
-- Primitives
---------------------------------------------------------------------------
function Kit.box(parent: Instance, cf: CFrame, size: Vector3, finish: FinishArg, opts: Opts?): Part
	local p = Instance.new("Part")
	p.Name = "Part"
	setup(p, parent, cf, size, finish, opts)
	return p
end

-- Cylinder along cf.RightVector (local X): `length` along the axis.
function Kit.cyl(parent: Instance, cf: CFrame, length: number, diameter: number, finish: FinishArg, opts: Opts?): Part
	local p = Instance.new("Part")
	p.Name = "Cylinder"
	p.Shape = Enum.PartType.Cylinder
	setup(p, parent, cf, Vector3.new(length, diameter, diameter), finish, opts)
	return p
end

-- Vertical cylinder standing on `cf` (cf is the centre of the cylinder).
function Kit.cylY(parent: Instance, cf: CFrame, height: number, diameter: number, finish: FinishArg, opts: Opts?): Part
	return Kit.cyl(parent, cf * CFrame.Angles(0, 0, math.rad(90)), height, diameter, finish, opts)
end

-- Cylinder along cf.LookVector (local Z), e.g. a plate facing sideways.
function Kit.cylZ(parent: Instance, cf: CFrame, length: number, diameter: number, finish: FinishArg, opts: Opts?): Part
	return Kit.cyl(parent, cf * CFrame.Angles(0, math.rad(90), 0), length, diameter, finish, opts)
end

function Kit.ball(parent: Instance, pos: Vector3 | CFrame, diameter: number, finish: FinishArg, opts: Opts?): Part
	local p = Instance.new("Part")
	p.Name = "Ball"
	p.Shape = Enum.PartType.Ball
	local cf = if typeof(pos) == "CFrame" then pos :: CFrame else CFrame.new(pos :: Vector3)
	setup(p, parent, cf, Vector3.new(diameter, diameter, diameter), finish, opts)
	return p
end

-- Wedge: tall at local +Z (back), sloping down toward local -Z (front).
function Kit.wedge(parent: Instance, cf: CFrame, size: Vector3, finish: FinishArg, opts: Opts?): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = "Wedge"
	setup(p, parent, cf, size, finish, opts)
	return p
end

-- Bar between two points. Round (cylinder) by default, square if square=true.
function Kit.span(parent: Instance, p0: Vector3, p1: Vector3, thickness: number, finish: FinishArg, opts: Opts?, square: boolean?): Part
	local mid = (p0 + p1) / 2
	local dir = p1 - p0
	local len = dir.Magnitude
	if len < 1e-4 then
		return Kit.box(parent, CFrame.new(mid), Vector3.new(thickness, thickness, thickness), finish, opts)
	end
	-- build a frame whose X axis follows the bar
	local x = dir.Unit
	local up = if math.abs(x.Y) > 0.95 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	local z = x:Cross(up).Unit
	local y = z:Cross(x).Unit
	local cf = CFrame.fromMatrix(mid, x, y, z)
	if square then
		return Kit.box(parent, cf, Vector3.new(len, thickness, thickness), finish, opts)
	end
	return Kit.cyl(parent, cf, len, thickness, finish, opts)
end

-- Invisible, non-colliding marker part (anchors for gameplay: spots, spawns, camera points).
function Kit.marker(parent: Instance, name: string, cf: CFrame, size: Vector3?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size or Vector3.new(1, 1, 1)
	p.CFrame = cf
	p.Parent = parent
	return p
end

---------------------------------------------------------------------------
-- Transforms / helpers
---------------------------------------------------------------------------
function Kit.at(cf: CFrame, x: number, y: number, z: number): CFrame
	return cf * CFrame.new(x, y, z)
end

function Kit.rotY(deg: number): CFrame
	return CFrame.Angles(0, math.rad(deg), 0)
end

-- CFrame at (x, y, z) facing yaw degrees (0 = facing -Z, 90 = facing -X, 180 = +Z, -90 = +X).
function Kit.place(x: number, y: number, z: number, yawDeg: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(yawDeg or 0), 0)
end

-- Calls fn for every cell of an nx * nz grid laid out in `origin`'s local XZ.
function Kit.grid(origin: CFrame, nx: number, nz: number, dx: number, dz: number, fn: (cf: CFrame, ix: number, iz: number) -> ())
	for ix = 1, nx do
		for iz = 1, nz do
			local ox = (ix - (nx + 1) / 2) * dx
			local oz = (iz - (nz + 1) / 2) * dz
			fn(origin * CFrame.new(ox, 0, oz), ix, iz)
		end
	end
end

function Kit.tag(inst: Instance, tag: string)
	inst:AddTag(tag)
end

function Kit.attrs(inst: Instance, attrs: { [string]: any })
	for k, v in attrs do
		inst:SetAttribute(k, v)
	end
end

---------------------------------------------------------------------------
-- Architecture helpers
---------------------------------------------------------------------------
export type Opening = { At: number, Width: number, Height: number, Sill: number? }

--[[
	Straight wall from `a` to `b` (floor points, Y = floor level) with openings.
	Openings: At = distance from `a` to the opening centre, Width, Height, Sill
	(bottom height; 0 for doors). Returns the wall parts.
	The wall's thickness is centred on the a->b line.
]]
function Kit.wall(parent: Instance, a: Vector3, b: Vector3, height: number, thickness: number, finish: FinishArg, openings: { Opening }?, opts: Opts?): { Part }
	local dir = b - a
	local len = dir.Magnitude
	local x = dir.Unit
	local z = x:Cross(Vector3.new(0, 1, 0)).Unit
	local base = CFrame.fromMatrix(a, x, Vector3.new(0, 1, 0), z)
	local parts: { Part } = {}
	local function seg(x0: number, x1: number, y0: number, y1: number)
		if x1 - x0 < 0.05 or y1 - y0 < 0.05 then
			return
		end
		local cf = base * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0)
		table.insert(parts, Kit.box(parent, cf, Vector3.new(x1 - x0, y1 - y0, thickness), finish, opts))
	end
	local list = table.clone(openings or {})
	table.sort(list, function(p: Opening, q: Opening)
		return p.At < q.At
	end)
	local cursor = 0
	for _, o in list do
		local x0 = math.max(cursor, o.At - o.Width / 2)
		local x1 = math.min(len, o.At + o.Width / 2)
		seg(cursor, x0, 0, height)
		local sill = o.Sill or 0
		seg(x0, x1, 0, sill)
		seg(x0, x1, math.min(height, sill + o.Height), height)
		cursor = x1
	end
	seg(cursor, len, 0, height)
	return parts
end

--[[
	Straight stair. `base` is the CFrame at the centre of the bottom step's
	front edge, facing up-stair (LookVector = climbing direction).
	A smooth invisible ramp handles collision; visible steps don't collide.
	Returns the top landing point (world Vector3).
]]
function Kit.stairs(parent: Instance, base: CFrame, width: number, rise: number, steps: number, run: number, finish: FinishArg, nosing: FinishArg?): Vector3
	local stepH = rise / steps
	local model = Kit.model(parent, "Stair", base)
	for i = 1, steps do
		local h = stepH * i
		-- each step is a solid block from the floor up to its tread (looks right from the side)
		local cf = base * CFrame.new(0, h / 2, -(i - 0.5) * run)
		Kit.box(model, cf, Vector3.new(width, h, run), finish, { Collide = false, Shadow = true })
		if nosing then
			Kit.box(model, base * CFrame.new(0, h - 0.06, -(i - 1) * run - 0.15), Vector3.new(width - 0.2, 0.12, 0.3), nosing, Kit.DETAIL)
		end
	end
	-- collision ramp
	local total = run * steps
	local slopeLen = math.sqrt(total * total + rise * rise)
	local angle = math.atan2(rise, total)
	local mid = base * CFrame.new(0, rise / 2, -total / 2)
	local ramp = Kit.box(model, mid * CFrame.Angles(angle, 0, 0), Vector3.new(width, 0.4, slopeLen), "Concrete", { Collide = true, Shadow = false })
	ramp.Transparency = 1
	ramp.Name = "Ramp"
	return (base * CFrame.new(0, rise, -total)).Position
end

-- Glass balustrade between two floor points: posts + glass + handrail.
function Kit.railing(parent: Instance, a: Vector3, b: Vector3, height: number?, glass: FinishArg?, rail: FinishArg?)
	local h = height or 3.6
	local dir = b - a
	local len = dir.Magnitude
	local x = dir.Unit
	local z = x:Cross(Vector3.new(0, 1, 0)).Unit
	local base = CFrame.fromMatrix(a, x, Vector3.new(0, 1, 0), z)
	local m = Kit.model(parent, "Railing", base)
	Kit.box(m, base * CFrame.new(len / 2, h / 2, 0), Vector3.new(len, h, 0.2), glass or "Glass", { Collide = true, Shadow = false })
	Kit.box(m, base * CFrame.new(len / 2, h + 0.1, 0), Vector3.new(len, 0.2, 0.36), rail or "SteelBrushed", Kit.DETAIL)
	local posts = math.max(1, math.floor(len / 6))
	for i = 0, posts do
		local px = len * i / posts
		Kit.box(m, base * CFrame.new(px, h / 2, 0), Vector3.new(0.18, h, 0.3), rail or "SteelBrushed", Kit.DETAIL)
	end
	Kit.box(m, base * CFrame.new(len / 2, 0.08, 0), Vector3.new(len, 0.16, 0.34), rail or "SteelBrushed", Kit.DETAIL)
end

-- A window/glazing panel with frame and mullions, filling an opening.
-- cf: centre of the opening, facing outward (LookVector = outward normal).
function Kit.glazing(parent: Instance, cf: CFrame, width: number, height: number, frame: FinishArg?, divisions: number?, glass: FinishArg?)
	local m = Kit.model(parent, "Glazing", cf)
	local fr = frame or "PowderBlack"
	Kit.box(m, cf, Vector3.new(width, height, 0.15), glass or "Glass", { Collide = true, Shadow = false })
	local t = 0.3
	Kit.box(m, cf * CFrame.new(0, height / 2 - t / 2, 0), Vector3.new(width, t, 0.4), fr, Kit.DETAIL)
	Kit.box(m, cf * CFrame.new(0, -height / 2 + t / 2, 0), Vector3.new(width, t, 0.4), fr, Kit.DETAIL)
	Kit.box(m, cf * CFrame.new(-width / 2 + t / 2, 0, 0), Vector3.new(t, height, 0.4), fr, Kit.DETAIL)
	Kit.box(m, cf * CFrame.new(width / 2 - t / 2, 0, 0), Vector3.new(t, height, 0.4), fr, Kit.DETAIL)
	local n = divisions or math.max(1, math.floor(width / 8))
	for i = 1, n - 1 do
		Kit.box(m, cf * CFrame.new(-width / 2 + width * i / n, 0, 0), Vector3.new(0.2, height, 0.35), fr, Kit.DETAIL)
	end
	if height > 14 then
		Kit.box(m, cf * CFrame.new(0, -height / 2 + height * 0.33, 0), Vector3.new(width, 0.2, 0.35), fr, Kit.DETAIL)
	end
end

---------------------------------------------------------------------------
-- Lights, signs, prompts
---------------------------------------------------------------------------
export type LightOpts = {
	Color: Color3?,
	Brightness: number?,
	Range: number?,
	Angle: number?,
	Face: Enum.NormalId?,
	Shadows: boolean?,
}

function Kit.light(part: BasePart, kind: "Point" | "Spot" | "Surface", o: LightOpts?): Light
	local opts: LightOpts = o or {}
	local l: Light
	if kind == "Spot" then
		local s = Instance.new("SpotLight")
		s.Angle = opts.Angle or 70
		s.Face = opts.Face or Enum.NormalId.Bottom
		l = s
	elseif kind == "Surface" then
		local s = Instance.new("SurfaceLight")
		s.Angle = opts.Angle or 80
		s.Face = opts.Face or Enum.NormalId.Bottom
		l = s
	else
		l = Instance.new("PointLight")
	end
	l.Color = opts.Color or Color3.fromRGB(255, 240, 220)
	l.Brightness = opts.Brightness or 1.2
	;(l :: any).Range = opts.Range or 24
	l.Shadows = opts.Shadows == true
	l.Parent = part
	return l
end

export type SignOpts = {
	Font: Font?,
	TextColor: Color3?,
	Background: Color3?,
	BackgroundTransparency: number?,
	PixelsPerStud: number?,
	Face: Enum.NormalId?,
	XAlign: Enum.TextXAlignment?,
	LightInfluence: number?,
	Brightness: number?,
	MaxDistance: number?,
	Padding: number?,
}

-- Puts text on a part face. Use for branding, wayfinding, rules, labels.
function Kit.sign(part: BasePart, text: string, o: SignOpts?): SurfaceGui
	local opts: SignOpts = o or {}
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Sign"
	sg.Face = opts.Face or Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = opts.PixelsPerStud or 40
	sg.LightInfluence = opts.LightInfluence or 1
	sg.Brightness = opts.Brightness or 1
	sg.MaxDistance = opts.MaxDistance or 220
	sg.ZOffset = 0.05
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = opts.Background or Color3.new(0, 0, 0)
	label.BackgroundTransparency = opts.BackgroundTransparency or 1
	label.BorderSizePixel = 0
	label.FontFace = opts.Font or Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = opts.TextColor or Color3.fromRGB(244, 238, 226)
	label.TextXAlignment = opts.XAlign or Enum.TextXAlignment.Center
	label.RichText = true
	label.Parent = sg
	if opts.Padding then
		local pad = Instance.new("UIPadding")
		local p = UDim.new(opts.Padding, 0)
		pad.PaddingTop = p
		pad.PaddingBottom = p
		pad.PaddingLeft = p
		pad.PaddingRight = p
		pad.Parent = label
	end
	sg.Parent = part
	return sg
end

export type PromptOpts = {
	HoldDuration: number?,
	MaxDistance: number?,
	Key: Enum.KeyCode?,
	RequiresLineOfSight: boolean?,
	Offset: Vector2?,
	Exclusivity: Enum.ProximityPromptExclusivity?,
}

function Kit.prompt(part: BasePart, action: string, object: string, o: PromptOpts?): ProximityPrompt
	local opts: PromptOpts = o or {}
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = opts.HoldDuration or 0
	pp.MaxActivationDistance = opts.MaxDistance or 8
	pp.KeyboardKeyCode = opts.Key or Enum.KeyCode.E
	pp.GamepadKeyCode = Enum.KeyCode.ButtonX
	pp.RequiresLineOfSight = opts.RequiresLineOfSight == true
	pp.Style = Enum.ProximityPromptStyle.Custom
	pp.Exclusivity = opts.Exclusivity or Enum.ProximityPromptExclusivity.OneGlobally
	pp.UIOffset = opts.Offset or Vector2.new(0, 0)
	pp.Parent = part
	return pp
end

---------------------------------------------------------------------------
-- Gameplay volumes
---------------------------------------------------------------------------
-- Area volume used for zone detection (ambience, area names, access checks).
function Kit.zone(parent: Instance, areaId: string, cf: CFrame, size: Vector3, ambience: string?): Part
	local p = Kit.marker(parent, "Zone_" .. areaId, cf, size)
	p:SetAttribute("AreaId", areaId)
	if ambience then
		p:SetAttribute("Ambience", ambience)
	end
	p:AddTag("AreaZone")
	return p
end

return Kit
