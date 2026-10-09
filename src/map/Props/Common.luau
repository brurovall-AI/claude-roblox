--!strict
--[[
	Shared building blocks for the Props implementation modules.

	Local frames: every prop is built in its own space through a builder `B`
	created by `C.begin(parent, name, cf)`:
	  x = right (cf.RightVector), y = up, z = FORWARD (cf.LookVector, i.e.
	  Roblox local -Z). `b.box(x, y, z, sx, sy, sz, finish)` centres a box at
	  that local point; `b.at(x, y, z)` / `b.pt(x, y, z)` convert to world space.
	  `C.L(x, y, z, rx, ry, rz)` builds a rotated local CFrame (degrees) for
	  `b.part` / `b.wedge` using the same z-forward convention.
	Wedges keep Kit semantics: tall at local back, sloping DOWN toward local
	FORWARD, so an unrotated `b.wedge` slopes down toward cf.LookVector.

	Also here: light colour temperatures, fonts, a deterministic RNG (bakes
	must be reproducible) and small SurfaceGui helpers in scale units so sign
	and screen compositions adapt to any panel size.
]]

local Kit = require("../Kit")
local Palette = require("../Palette")

export type Finish = Kit.FinishArg
export type Fin = Palette.Finish -- a resolved finish table (Palette.tint results)
export type Opts = Kit.Opts
export type Registry = { register: (name: string, fn: (...any) -> Model) -> () }

local C = {}

C.F = Palette.F
C.DETAIL = Kit.DETAIL
C.SOLID = Kit.SOLID
-- tiny parts that should neither collide nor cast shadows (cables, ticks, lenses)
C.FINE = { Collide = false, Shadow = false } :: Opts

---------------------------------------------------------------------------
-- Finishes / colours
---------------------------------------------------------------------------
function C.tint(name: string, color: Color3): Palette.Finish
	return Palette.tint(name, color)
end

-- Base colour of any finish argument.
function C.colorOf(f: Finish): Color3
	if type(f) == "string" then
		return Palette.get(f).Color
	end
	return f.Color
end

-- Same material/reflectance as `f`, different colour.
function C.retint(f: Finish, color: Color3): Palette.Finish
	local base = if type(f) == "string" then Palette.get(f) else f
	return { Material = base.Material, Color = color, Reflectance = base.Reflectance, Transparency = base.Transparency }
end

function C.rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Light colour temperatures (tuned for Roblox Future lighting, not raw blackbody).
C.WARM = Color3.fromRGB(255, 206, 156) -- ~3000K hospitality
C.WARMNEUTRAL = Color3.fromRGB(255, 220, 182) -- ~3500K accents / downlights
C.NEUTRAL = Color3.fromRGB(255, 234, 210) -- ~4000K training floors
C.COOL = Color3.fromRGB(236, 242, 255) -- ~5000K+ (Apex / outdoor LED)

C.Brand = {
	Amber = Color3.fromRGB(242, 169, 59),
	AmberDeep = Color3.fromRGB(199, 131, 42),
	Ink = Color3.fromRGB(22, 22, 24),
	Graphite = Color3.fromRGB(29, 30, 34),
	Cream = Color3.fromRGB(244, 238, 226),
	Dim = Color3.fromRGB(171, 168, 162),
}

---------------------------------------------------------------------------
-- Fonts
---------------------------------------------------------------------------
local function fam(name: string): string
	return `rbxasset://fonts/families/{name}.json`
end

C.Font = {
	Brand = Font.new(fam("Michroma"), Enum.FontWeight.Regular),
	Heavy = Font.new(fam("BuilderSans"), Enum.FontWeight.ExtraBold),
	Bold = Font.new(fam("BuilderSans"), Enum.FontWeight.Bold),
	Medium = Font.new(fam("BuilderSans"), Enum.FontWeight.Medium),
	Condensed = Font.new(fam("Oswald"), Enum.FontWeight.Bold),
	CondensedLight = Font.new(fam("Oswald"), Enum.FontWeight.Regular),
	Serif = Font.new(fam("Merriweather"), Enum.FontWeight.Bold, Enum.FontStyle.Italic),
	SerifPlain = Font.new(fam("Merriweather"), Enum.FontWeight.Bold),
	Mono = Font.new(fam("RobotoMono"), Enum.FontWeight.Medium),
	Script = Font.new(fam("Kalam"), Enum.FontWeight.Bold),
}

---------------------------------------------------------------------------
-- Deterministic RNG seeded from a CFrame (same prop, same place -> same look)
---------------------------------------------------------------------------
export type Rng = {
	next: () -> number, -- [0, 1)
	range: (lo: number, hi: number) -> number,
	int: (lo: number, hi: number) -> number,
	pick: <T>(list: { T }) -> T,
}

function C.rng(cf: CFrame, salt: number?): Rng
	local p = cf.Position
	local seed = math.floor(math.abs(p.X * 73.13 + p.Y * 19.71 + p.Z * 37.93 + (salt or 0) * 101.3) * 1000) % 2147483646 + 1
	local state = seed
	local function nxt(): number
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
	-- warm up so nearby seeds diverge
	for _ = 1, 3 do
		nxt()
	end
	local r = {} :: Rng
	r.next = nxt
	r.range = function(lo: number, hi: number): number
		return lo + (hi - lo) * nxt()
	end
	r.int = function(lo: number, hi: number): number
		return math.min(hi, lo + math.floor((hi - lo + 1) * nxt()))
	end
	r.pick = function<T>(list: { T }): T
		return list[math.min(#list, 1 + math.floor(#list * nxt()))]
	end
	return r
end

---------------------------------------------------------------------------
-- Local-space builder
---------------------------------------------------------------------------
-- Local CFrame in the z-forward convention, optional rotation in degrees.
function C.L(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, -z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

export type B = {
	model: Model,
	cf: CFrame,
	at: (x: number, y: number, z: number) -> CFrame,
	pt: (x: number, y: number, z: number) -> Vector3,
	box: (x: number, y: number, z: number, sx: number, sy: number, sz: number, f: Finish, o: Opts?) -> Part,
	part: (lcf: CFrame, size: Vector3, f: Finish, o: Opts?) -> Part,
	wedge: (lcf: CFrame, size: Vector3, f: Finish, o: Opts?) -> WedgePart,
	cyl: (lcf: CFrame, len: number, dia: number, f: Finish, o: Opts?) -> Part, -- axis = lcf X
	cylX: (x: number, y: number, z: number, len: number, dia: number, f: Finish, o: Opts?) -> Part,
	cylY: (x: number, y: number, z: number, h: number, dia: number, f: Finish, o: Opts?) -> Part,
	cylZ: (x: number, y: number, z: number, len: number, dia: number, f: Finish, o: Opts?) -> Part,
	ball: (x: number, y: number, z: number, d: number, f: Finish, o: Opts?) -> Part,
	span: (p0: Vector3, p1: Vector3, t: number, f: Finish, o: Opts?, square: boolean?) -> Part,
}

-- `run` = a long linear prop (duct, fence ...) that keeps default streaming;
-- everything else streams atomically so props never pop in half-built.
function C.begin(parent: Instance, name: string, cf: CFrame, run: boolean?): B
	local m = Kit.model(parent, name, cf)
	if not run then
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end
	local b = {} :: B
	b.model = m
	b.cf = cf
	b.at = function(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, -z)
	end
	b.pt = function(x: number, y: number, z: number): Vector3
		return (cf * CFrame.new(x, y, -z)).Position
	end
	b.box = function(x: number, y: number, z: number, sx: number, sy: number, sz: number, f: Finish, o: Opts?): Part
		return Kit.box(m, cf * CFrame.new(x, y, -z), Vector3.new(sx, sy, sz), f, o)
	end
	b.part = function(lcf: CFrame, size: Vector3, f: Finish, o: Opts?): Part
		return Kit.box(m, cf * lcf, size, f, o)
	end
	b.wedge = function(lcf: CFrame, size: Vector3, f: Finish, o: Opts?): WedgePart
		return Kit.wedge(m, cf * lcf, size, f, o)
	end
	b.cyl = function(lcf: CFrame, len: number, dia: number, f: Finish, o: Opts?): Part
		return Kit.cyl(m, cf * lcf, len, dia, f, o)
	end
	b.cylX = function(x: number, y: number, z: number, len: number, dia: number, f: Finish, o: Opts?): Part
		return Kit.cyl(m, cf * CFrame.new(x, y, -z), len, dia, f, o)
	end
	b.cylY = function(x: number, y: number, z: number, h: number, dia: number, f: Finish, o: Opts?): Part
		return Kit.cylY(m, cf * CFrame.new(x, y, -z), h, dia, f, o)
	end
	b.cylZ = function(x: number, y: number, z: number, len: number, dia: number, f: Finish, o: Opts?): Part
		return Kit.cylZ(m, cf * CFrame.new(x, y, -z), len, dia, f, o)
	end
	b.ball = function(x: number, y: number, z: number, d: number, f: Finish, o: Opts?): Part
		return Kit.ball(m, cf * CFrame.new(x, y, -z), d, f, o)
	end
	b.span = function(p0: Vector3, p1: Vector3, t: number, f: Finish, o: Opts?, square: boolean?): Part
		local w0 = (cf * CFrame.new(p0.X, p0.Y, -p0.Z)).Position
		local w1 = (cf * CFrame.new(p1.X, p1.Y, -p1.Z)).Position
		return Kit.span(m, w0, w1, t, f, o, square)
	end
	return b
end

-- Frame whose X axis runs from a to b (horizontal-ish runs), Y up, Z = X x Y.
-- Returns the frame at `a` and the run length.
function C.runFrame(a: Vector3, b: Vector3): (CFrame, number)
	local d = b - a
	local len = d.Magnitude
	if len < 1e-3 then
		return CFrame.new(a), 0
	end
	local x = d.Unit
	local up = if math.abs(x.Y) > 0.95 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	local z = x:Cross(up).Unit
	local y = z:Cross(x).Unit
	return CFrame.fromMatrix(a, x, y, z), len
end

-- Like runFrame but flattened to the ground plane (Y stays world up): for fences,
-- stanchions and anything that stands upright along a floor line.
function C.floorFrame(a: Vector3, b: Vector3): (CFrame, number)
	local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = d.Magnitude
	if len < 1e-3 then
		return CFrame.new(a), 0
	end
	local x = d.Unit
	local y = Vector3.new(0, 1, 0)
	local z = x:Cross(y).Unit
	return CFrame.fromMatrix(a, x, y, z), len
end

---------------------------------------------------------------------------
-- Lights
---------------------------------------------------------------------------
-- Reads caller opts ({ Color, Brightness, Range, Shadows, Angle }) with type
-- checks and falls back to the prop's defaults.
function C.light(part: BasePart, kind: "Point" | "Spot" | "Surface", opts: { [string]: any }?, def: Kit.LightOpts): Light
	local o: { [string]: any } = opts or {}
	local color = if typeof(o.Color) == "Color3" then o.Color :: Color3 else def.Color
	local brightness = if type(o.Brightness) == "number" then math.clamp(o.Brightness :: number, 0, 10) else def.Brightness
	local range = if type(o.Range) == "number" then math.clamp(o.Range :: number, 2, 60) else def.Range
	local angle = if type(o.Angle) == "number" then math.clamp(o.Angle :: number, 5, 180) else def.Angle
	return Kit.light(part, kind, {
		Color = color,
		Brightness = brightness,
		Range = range,
		Angle = angle,
		Face = def.Face,
		Shadows = o.Shadows == true,
	})
end

function C.num(v: any, default: number, lo: number, hi: number): number
	if type(v) == "number" and v == v then
		return math.clamp(v, lo, hi)
	end
	return default
end

---------------------------------------------------------------------------
-- SurfaceGui helpers (scale units, ZIndex explicit, Sibling layering)
---------------------------------------------------------------------------
export type GuiOpts = {
	Face: Enum.NormalId?,
	PixelsPerStud: number?,
	LightInfluence: number?,
	Brightness: number?,
	MaxDistance: number?,
}

-- Creates the SurfaceGui through Kit.sign and returns it with its headline
-- label (callers reposition/restyle the label; it starts full-size).
function C.gui(part: BasePart, text: string, font: Font, color: Color3, o: GuiOpts?): (SurfaceGui, TextLabel)
	local opts: GuiOpts = o or {}
	local sg = Kit.sign(part, text, {
		Face = opts.Face,
		Font = font,
		TextColor = color,
		PixelsPerStud = opts.PixelsPerStud or 50,
		LightInfluence = opts.LightInfluence,
		Brightness = opts.Brightness,
		MaxDistance = opts.MaxDistance or 160,
	})
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local label = sg:FindFirstChild("Text") :: TextLabel
	label.ZIndex = 5
	return sg, label
end

function C.frame(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, z: number?, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.Name = "Shape"
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.ZIndex = z or 1
	f.Parent = parent
	return f
end

-- Circle of diameter `d` (fraction of the parent's HEIGHT) centred at (cx, cy).
function C.circle(parent: Instance, cx: number, cy: number, d: number, color: Color3, z: number?, transparency: number?): Frame
	local f = C.frame(parent, cx, cy, d, d, color, z, transparency)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.SizeConstraint = Enum.SizeConstraint.RelativeYY
	C.corner(f, 0.5)
	return f
end

function C.corner(gui: GuiObject, scale: number?, px: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale or 0, px or 0)
	c.Parent = gui
	return c
end

function C.stroke(gui: GuiObject, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.Parent = gui
	return s
end

function C.gradient(gui: GuiObject, c0: Color3, c1: Color3, rotation: number?, t0: number?, t1: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c0, c1)
	g.Rotation = rotation or 90
	if t0 or t1 then
		g.Transparency = NumberSequence.new(t0 or 0, t1 or 0)
	end
	g.Parent = gui
	return g
end

function C.text(parent: Instance, text: string, x: number, y: number, w: number, h: number, font: Font, color: Color3, z: number?, align: Enum.TextXAlignment?): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.BorderSizePixel = 0
	t.Position = UDim2.fromScale(x, y)
	t.Size = UDim2.fromScale(w, h)
	t.FontFace = font
	t.Text = text
	t.TextColor3 = color
	t.TextScaled = true
	t.RichText = true
	t.TextXAlignment = align or Enum.TextXAlignment.Center
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.ZIndex = z or 5
	t.Parent = parent
	return t
end

-- PixelsPerStud that keeps the tallest text box (fraction `frac` of a face
-- `studs` tall) under TextScaled's 100px cap while staying crisp.
function C.ppi(studs: number, frac: number, maxPpi: number?): number
	return math.clamp(92 / math.max(0.05, studs * frac), 10, maxPpi or 64)
end

-- Positions an existing label (e.g. the Kit.sign headline) in scale units.
function C.place(gui: GuiObject, x: number, y: number, w: number, h: number, z: number?)
	gui.Position = UDim2.fromScale(x, y)
	gui.Size = UDim2.fromScale(w, h)
	if z then
		gui.ZIndex = z
	end
end

-- Wide letter-spacing for short uppercase kickers ("I R O N H A V E N").
function C.track(s: string): string
	local out = {}
	for _, cp in utf8.codes(s) do
		local ch = utf8.char(cp)
		table.insert(out, if ch == " " then "  " else ch)
	end
	return table.concat(out, " ")
end

-- Escapes caller text for RichText labels (Kit.sign enables RichText).
function C.escape(s: string): string
	return (string.gsub(string.gsub(string.gsub(s, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

-- "Title|Subtitle" or "Title\nSubtitle" -> title, subtitle?
function C.split(s: string): (string, string?)
	local a, b = string.match(s, "^(.-)%s*[|\n]%s*(.+)$")
	if a and b and a ~= "" then
		return a, b
	end
	return s, nil
end

return C
