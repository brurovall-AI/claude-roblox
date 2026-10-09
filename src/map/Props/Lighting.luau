--!strict
--[[
	Light fixtures. Every fixture is a real luminaire (housing + diffuser /
	lens) carrying its actual Light instance:

	  Panel / Linear      SurfaceLight, neutral 4000K
	  Industrial          SpotLight (high-bay), neutral 4000K
	  Spot / Downlight    SpotLight, 3500K
	  Pendant / Globe     PointLight, warm 3000K
	  Sconce              PointLight, warm 3000K   Strip  SurfaceLight   Wash  SpotLight (up)
	  Ring light          SpotLight forward, cool

	Ceiling fixtures: cf = ceiling point (underside of the slab), the fixture
	hangs DOWN from it. Wall fixtures: cf = wall surface point, LookVector out
	of the wall. Light parts never collide or cast shadows themselves.

	opts (all optional, type-checked): Color, Brightness, Range, Shadows,
	Angle, Length (Panel/Linear/Spot track/Strip length along cf.RightVector),
	Drop (suspension length for Linear/Pendant/Industrial/Globe),
	Tilt (Spot: degrees toward cf.LookVector).
	Shadows are only enabled when opts.Shadows == true (area budget: <= 4).
]]

local C = require("./Common")

type B = C.B
type Opts = { [string]: any }

local L = C.L
local FINE = C.FINE
local F = C.F

local GLOW_NEUTRAL = C.tint("LightPanel", C.rgb(255, 246, 232))
local GLOW_WARM = C.tint("LightWarm", C.rgb(255, 222, 178))
local GLOW_OPAL = C.tint("LightWarm", C.rgb(255, 232, 200))
local WHITE = F.PowderWhite
local BLACK = F.PowderBlack

local function cord(b: B, drop: number)
	b.cylY(0, -0.05, 0, 0.1, 0.5, BLACK, FINE) -- ceiling canopy
	b.span(Vector3.new(0, -0.1, 0), Vector3.new(0, -drop, 0), 0.05, BLACK, FINE)
end

local CEILING: { [string]: (b: B, o: Opts) -> () } = {}

CEILING.Panel = function(b: B, o: Opts)
	local len = C.num(o.Length, 4, 1, 12)
	local w = math.min(2, len)
	-- recessed trim frame + flush diffuser
	b.box(0, -0.04, w / 2 + 0.05, len + 0.2, 0.08, 0.1, WHITE, FINE)
	b.box(0, -0.04, -w / 2 - 0.05, len + 0.2, 0.08, 0.1, WHITE, FINE)
	b.box(len / 2 + 0.05, -0.04, 0, 0.1, 0.08, w, WHITE, FINE)
	b.box(-len / 2 - 0.05, -0.04, 0, 0.1, 0.08, w, WHITE, FINE)
	local d = b.box(0, -0.035, 0, len, 0.05, w, GLOW_NEUTRAL, FINE)
	d.Name = "Diffuser"
	C.light(d, "Surface", o, { Color = C.NEUTRAL, Brightness = 1.2, Range = 20, Angle = 120, Face = Enum.NormalId.Bottom })
end

CEILING.Linear = function(b: B, o: Opts)
	local len = C.num(o.Length, 8, 2, 30)
	local drop = C.num(o.Drop, 2, 0.3, 20)
	for _, sx in { -1, 1 } do
		local x = sx * (len / 2 - 0.6)
		b.cylY(x, -0.04, 0, 0.08, 0.35, BLACK, FINE)
		b.span(Vector3.new(x, -0.08, 0), Vector3.new(x, -drop, 0), 0.03, F.SteelBrushed, FINE)
	end
	b.box(0, -drop - 0.13, 0, len, 0.26, 0.36, BLACK, FINE)
	local d = b.box(0, -drop - 0.275, 0, len - 0.1, 0.04, 0.24, GLOW_NEUTRAL, FINE)
	d.Name = "Diffuser"
	C.light(d, "Surface", o, { Color = C.NEUTRAL, Brightness = 1.1, Range = 22, Angle = 120, Face = Enum.NormalId.Bottom })
end

CEILING.Pendant = function(b: B, o: Opts)
	local drop = C.num(o.Drop, 3, 0.5, 20)
	cord(b, drop)
	b.cylY(0, -drop - 0.1, 0, 0.2, 0.4, F.Brass, FINE)
	b.cylY(0, -drop - 0.6, 0, 0.8, 1.5, BLACK, FINE)
	b.cylY(0, -drop - 0.98, 0, 0.08, 1.54, F.Brass, FINE)
	local g = b.cylY(0, -drop - 1.02, 0, 0.02, 1.3, GLOW_WARM, FINE)
	g.Name = "Glow"
	C.light(g, "Point", o, { Color = C.WARM, Brightness = 1.0, Range = 16 })
end

CEILING.Industrial = function(b: B, o: Opts)
	local drop = C.num(o.Drop, 3, 0.5, 30)
	cord(b, drop)
	local y = -drop
	b.cylY(0, y - 0.3, 0, 0.6, 0.9, F.SteelDark, FINE) -- driver
	b.cylY(0, y - 0.22, 0, 0.08, 1.02, F.SteelDark, FINE) -- cooling fin
	b.cylY(0, y - 0.85, 0, 0.5, 2.2, F.SteelBrushed, FINE) -- reflector bell
	b.cylY(0, y - 1.1, 0, 0.06, 2.3, F.SteelDark, FINE)
	local lens = b.cylY(0, y - 1.115, 0, 0.02, 1.95, GLOW_NEUTRAL, FINE)
	lens.Name = "Lens"
	C.light(lens, "Spot", o, { Color = C.NEUTRAL, Brightness = 1.4, Range = 36, Angle = 100, Face = Enum.NormalId.Bottom })
end

CEILING.Spot = function(b: B, o: Opts)
	local len = C.num(o.Length, 3, 0.6, 20)
	local tilt = math.rad(C.num(o.Tilt, 0, -80, 80))
	b.box(0, -0.09, 0, len, 0.18, 0.18, BLACK, FINE) -- track
	b.box(0, -0.24, 0, 0.3, 0.14, 0.2, BLACK, FINE) -- adapter
	b.span(Vector3.new(0, -0.3, 0), Vector3.new(0, -0.62, 0), 0.08, BLACK, FINE)
	-- head: cylinder whose +X axis is the beam direction (down, tilted forward)
	local pivot = Vector3.new(0, -0.7, 0)
	local dir = Vector3.new(0, -math.cos(tilt), -math.sin(tilt)) -- Roblox local (forward = -Z)
	local up = Vector3.new(0, math.sin(tilt), -math.cos(tilt))
	local headCf = CFrame.fromMatrix(Vector3.new(pivot.X, pivot.Y, -pivot.Z) + dir * 0.3, dir, up)
	b.cyl(headCf, 0.8, 0.46, BLACK, FINE)
	local lens = b.cyl(headCf * CFrame.new(0.41, 0, 0), 0.02, 0.36, GLOW_WARM, FINE)
	lens.Name = "Lens"
	C.light(lens, "Spot", o, { Color = C.WARMNEUTRAL, Brightness = 1.6, Range = 24, Angle = 40, Face = Enum.NormalId.Right })
end

CEILING.Globe = function(b: B, o: Opts)
	local drop = C.num(o.Drop, 3, 0.5, 20)
	cord(b, drop)
	b.cylY(0, -drop - 0.1, 0, 0.2, 0.42, F.Brass, FINE)
	local g = b.ball(0, -drop - 0.8, 0, 1.3, GLOW_OPAL, FINE)
	g.Name = "Globe"
	C.light(g, "Point", o, { Color = C.WARM, Brightness = 0.9, Range = 16 })
end

CEILING.Downlight = function(b: B, o: Opts)
	b.cylY(0, -0.015, 0, 0.03, 0.9, WHITE, FINE)
	local lens = b.cylY(0, -0.035, 0, 0.02, 0.62, GLOW_WARM, FINE)
	lens.Name = "Lens"
	C.light(lens, "Spot", o, { Color = C.WARMNEUTRAL, Brightness = 1.2, Range = 18, Angle = 70, Face = Enum.NormalId.Bottom })
end

local WALL: { [string]: (b: B, o: Opts) -> () } = {}

WALL.Sconce = function(b: B, o: Opts)
	b.cylZ(0, 0, 0.03, 0.06, 0.5, F.Brass, FINE)
	b.span(Vector3.new(0, 0, 0.05), Vector3.new(0, 0, 0.45), 0.08, F.Brass, FINE)
	local shade = b.cylY(0, 0, 0.62, 0.8, 0.62, C.tint("FabricCream", C.rgb(236, 226, 206)), FINE)
	shade.Name = "Shade"
	b.cylY(0, 0.405, 0.62, 0.01, 0.52, GLOW_WARM, FINE)
	b.cylY(0, -0.405, 0.62, 0.01, 0.52, GLOW_WARM, FINE)
	C.light(shade, "Point", o, { Color = C.WARM, Brightness = 0.8, Range = 12 })
end

WALL.Strip = function(b: B, o: Opts)
	local len = C.num(o.Length, 4, 0.5, 30)
	b.box(0, 0, 0.1, len, 0.22, 0.2, F.SteelBrushed, FINE)
	local d = b.box(0, 0, 0.205, len - 0.1, 0.12, 0.02, GLOW_NEUTRAL, FINE)
	d.Name = "Diffuser"
	C.light(d, "Surface", o, { Color = C.WARMNEUTRAL, Brightness = 0.8, Range = 12, Angle = 120, Face = Enum.NormalId.Front })
end

WALL.Wash = function(b: B, o: Opts)
	b.box(0, 0, 0.06, 0.3, 0.3, 0.12, BLACK, FINE)
	b.cylY(0, 0, 0.32, 0.7, 0.42, BLACK, FINE)
	b.cylY(0, -0.355, 0.32, 0.01, 0.32, GLOW_WARM, FINE)
	local lens = b.cylY(0, 0.355, 0.32, 0.01, 0.32, GLOW_WARM, FINE)
	lens.Name = "Lens"
	C.light(lens, "Spot", o, { Color = C.WARM, Brightness = 1.2, Range = 14, Angle = 50, Face = Enum.NormalId.Top })
end

return function(Props: C.Registry)
	Props.register("ceilingLight", function(parent: Instance, cf: CFrame, kind: string, opts: Opts): Model
		local k = if type(kind) == "string" and CEILING[kind] then kind else "Panel"
		local b = C.begin(parent, "CeilingLight_" .. k, cf)
		CEILING[k](b, if type(opts) == "table" then opts else {})
		return b.model
	end)

	Props.register("wallLight", function(parent: Instance, cf: CFrame, kind: string, opts: Opts): Model
		local k = if type(kind) == "string" and WALL[kind] then kind else "Sconce"
		local b = C.begin(parent, "WallLight_" .. k, cf)
		WALL[k](b, if type(opts) == "table" then opts else {})
		return b.model
	end)

	Props.register("ringLight", function(parent: Instance, cf: CFrame): Model
		local b = C.begin(parent, "RingLight", cf)
		-- tripod + column
		local hub = 1.7
		for i = 0, 2 do
			local a = math.rad(i * 120 + 90)
			b.span(Vector3.new(math.cos(a) * 0.95, 0.02, math.sin(a) * 0.95), Vector3.new(0, hub, 0), 0.08, BLACK, FINE)
		end
		b.cylY(0, (hub + 5.0) / 2, 0, 5.0 - hub + 0.2, 0.12, BLACK, FINE)
		-- ring of LED segments facing forward
		local cy, R = 5.6, 0.85
		local n = 10
		local seg = 2 * R * math.tan(math.pi / n) + 0.02
		for i = 0, n - 1 do
			local a = 2 * math.pi * i / n
			b.part(L(math.cos(a) * R, cy + math.sin(a) * R, 0.05, 0, 0, math.deg(a) + 90), Vector3.new(seg, 0.18, 0.1), C.tint("LightCool", C.rgb(240, 246, 255)), FINE)
		end
		b.box(0, cy - R + 0.05, 0, 0.1, 0.5, 0.1, BLACK, FINE) -- ring mount
		local phone = b.box(0, cy, 0.04, 0.3, 0.56, 0.05, C.tint("PlasticBlack", C.rgb(20, 20, 22)), FINE)
		phone.Name = "Phone"
		C.light(phone, "Spot", nil, { Color = C.COOL, Brightness = 0.8, Range = 12, Angle = 90, Face = Enum.NormalId.Front })
		return b.model
	end)
end
