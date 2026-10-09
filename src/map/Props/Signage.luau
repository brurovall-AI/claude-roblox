--!strict
--[[
	Walls, signage and screens: mirrors, wall signs (Brand / Area / Motto /
	Wayfinding / Neon), the Ironhaven logo mark, framed posters, TVs, clocks,
	speakers, acoustic panels, wood slat walls and the small safety set
	(first aid, fire extinguisher, exit sign).

	Every prop here is WALL MOUNTED: cf = the wall surface point at the prop's
	centre, LookVector pointing out of the wall. Local z (forward) is the
	distance from the wall. Note that seen from the room the prop's local +x
	is the viewer's LEFT, so asymmetric layouts (logo shield, clock numerals)
	use -x for the viewer's right.

	Typography: one SurfaceGui per prop (Kit.sign creates it; the headline is
	its label, restyled), compositions in scale units so they adapt to any
	size. Fonts: Michroma for the wordmark, Oswald for poster headlines,
	BuilderSans for UI-like text, Merriweather italic for mottos.
]]

local C = require("./Common")

type B = C.B

local L = C.L
local DETAIL = C.DETAIL
local FINE = C.FINE
local F = C.F
local Font = C.Font
local Brand = C.Brand

local RGB = Color3.fromRGB
local INVISIBLE = { Collide = false, Shadow = false, Transparency = 1 } :: C.Opts

---------------------------------------------------------------------------
-- GUI helpers
---------------------------------------------------------------------------
-- Clipping root that fills the SurfaceGui (backgrounds + compositions go here).
local function root(sg: SurfaceGui, color: Color3, transparency: number?): Frame
	local f = C.frame(sg, 0, 0, 1, 1, color, 0, transparency)
	f.Name = "Canvas"
	f.ClipsDescendants = true
	return f
end

-- Arrow inside a square container; dir: 0 right, 90 down, 180 left, -90 up (screen space).
local function arrow(parent: GuiObject, dir: number, color: Color3, z: number)
	local function piece(x: number, y: number, w: number, h: number, rot: number)
		local a = math.rad(dir)
		local dx, dy = x - 0.5, y - 0.5
		local rx = 0.5 + dx * math.cos(a) - dy * math.sin(a)
		local ry = 0.5 + dx * math.sin(a) + dy * math.cos(a)
		local f = C.frame(parent, rx, ry, w, h, color, z)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Rotation = rot + dir
		C.corner(f, 0.5)
	end
	piece(0.47, 0.5, 0.46, 0.1, 0)
	piece(0.62, 0.405, 0.3, 0.1, 45)
	piece(0.62, 0.595, 0.3, 0.1, -45)
end

-- Pulls a leading direction token ("> ", "< ", "^ ", "v ") off wayfinding text.
local function arrowToken(text: string): (number?, string)
	local tok, rest = string.match(text, "^%s*([<>%^v])%s+(.+)$")
	if tok and rest then
		local dirs: { [string]: number } = { [">"] = 0, ["<"] = 180, ["^"] = -90, ["v"] = 90 }
		return dirs[tok], rest
	end
	return nil, text
end

---------------------------------------------------------------------------
-- Wall signs
---------------------------------------------------------------------------
local SIGN_STYLES: { [string]: (b: B, text: string, X: number, Y: number) -> () } = {}

SIGN_STYLES.Brand = function(b: B, text: string, X: number, Y: number)
	-- graphite panel on a slightly larger brass back plate (reads as an edge reveal)
	b.box(0, 0, 0.115, X + 0.1, Y + 0.1, 0.23, F.Brass, DETAIL)
	local panel = b.box(0, 0, 0.32, X, Y, 0.18, C.tint("PowderBlack", Brand.Graphite), DETAIL)
	local title, sub = C.split(text)
	local sg, label = C.gui(panel, C.escape(string.upper(title)), Font.Brand, Brand.Cream, { PixelsPerStud = C.ppi(Y, 0.56, 48), LightInfluence = 0.5, Brightness = 1.2 })
	label.TextXAlignment = Enum.TextXAlignment.Center
	if sub then
		C.place(label, 0.08, 0.16, 0.84, 0.46)
		C.frame(sg, 0.46, 0.7, 0.08, 0.025, Brand.Amber, 3)
		C.text(sg, C.escape(C.track(string.upper(sub))), 0.15, 0.77, 0.7, 0.11, Font.Medium, Brand.Amber, 5)
	else
		C.place(label, 0.07, 0.22, 0.86, 0.56)
	end
end

SIGN_STYLES.Area = function(b: B, text: string, X: number, Y: number)
	local panel = b.box(0, 0, 0.08, X, Y, 0.16, C.tint("PowderBlack", RGB(28, 29, 32)), DETAIL)
	local title, kicker = C.split(text)
	local sg, label = C.gui(panel, C.escape(string.upper(title)), Font.Heavy, Brand.Cream, { PixelsPerStud = C.ppi(Y, 0.56, 48), LightInfluence = 0.6, Brightness = 1.1 })
	label.TextXAlignment = Enum.TextXAlignment.Left
	-- amber accent bar sized in studs so it stays slim on any panel
	local barW = math.min(0.12, Y * 0.06) / X
	local pad = math.min(0.35, Y * 0.18) / X
	C.frame(sg, pad, 0.2, barW, 0.6, Brand.Amber, 3)
	local tx = pad + barW + pad * 0.8
	if kicker then
		C.text(sg, C.escape(C.track(string.upper(kicker))), tx, 0.17, 1 - tx - pad, 0.16, Font.Bold, Brand.Amber, 5, Enum.TextXAlignment.Left)
		C.place(label, tx, 0.36, 1 - tx - pad, 0.46)
	else
		C.place(label, tx, 0.22, 1 - tx - pad, 0.56)
	end
end

SIGN_STYLES.Motto = function(b: B, text: string, X: number, Y: number)
	local panel = b.box(0, 0, 0.05, X, Y, 0.1, C.tint("PlasterCharcoal", RGB(40, 40, 42)), DETAIL)
	local sg, label = C.gui(panel, C.escape(text), Font.Serif, Brand.Cream, { PixelsPerStud = C.ppi(Y, 0.52, 48), LightInfluence = 0.7 })
	label.TextWrapped = true
	C.place(label, 0.08, 0.24, 0.84, 0.52)
	C.frame(sg, 0.47, 0.12, 0.06, 0.03, Brand.Amber, 3)
	C.frame(sg, 0.47, 0.85, 0.06, 0.03, Brand.Amber, 3)
end

SIGN_STYLES.Wayfinding = function(b: B, text: string, X: number, Y: number)
	local panel = b.box(0, 0, 0.06, X, Y, 0.12, C.tint("PowderBlack", RGB(30, 31, 34)), DETAIL)
	local dir, rest = arrowToken(text)
	local sg, label = C.gui(panel, C.escape(rest), Font.Bold, RGB(244, 242, 238), { PixelsPerStud = C.ppi(Y, 0.52, 56), LightInfluence = 0.5, Brightness = 1.2 })
	label.TextXAlignment = Enum.TextXAlignment.Left
	local h = 0.62 -- chip diameter as a fraction of the panel height
	local chipX = (Y * 0.5) / X
	local tx = (Y * 0.95) / X
	if dir then
		local chip = C.circle(sg, chipX, 0.5, h, Brand.Amber, 3)
		arrow(chip, dir, Brand.Ink, 4)
	else
		tx = (Y * 0.35) / X
	end
	C.place(label, tx, 0.24, 1 - tx - (Y * 0.3) / X, 0.52)
end

SIGN_STYLES.Neon = function(b: B, text: string, X: number, Y: number)
	-- small halo-lit sign: dark backer on standoffs, glowing script letters
	local panel = b.box(0, 0, 0.22, X, Y, 0.08, C.tint("PowderBlack", RGB(20, 20, 22)), DETAIL)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			b.cylZ(sx * (X / 2 - 0.2), sy * (Y / 2 - 0.2), 0.09, 0.18, 0.12, F.Brass, FINE) -- standoffs
		end
	end
	local glow = RGB(255, 214, 160)
	local _sg, label = C.gui(panel, C.escape(text), Font.Script, glow, { PixelsPerStud = C.ppi(Y, 0.76, 56), LightInfluence = 0, Brightness = 2.2 })
	C.place(label, 0.07, 0.12, 0.86, 0.76)
	C.stroke(label, RGB(255, 168, 70), 2, 0.55)
	C.light(panel, "Surface", nil, { Color = RGB(255, 190, 120), Brightness = 0.5, Range = 6, Angle = 150, Face = Enum.NormalId.Front })
end

---------------------------------------------------------------------------
-- Posters: framed prints with a composition per theme
---------------------------------------------------------------------------
type Theme = { bg: Color3, frame: C.Fin, draw: (canvas: Frame) -> () }

local function headline(canvas: Frame, text: string, y: number, h: number, color: Color3, font: Font?)
	C.text(canvas, text, 0.08, y, 0.84, h, font or Font.Condensed, color, 6, Enum.TextXAlignment.Left)
end

local function kicker(canvas: Frame, text: string, y: number, color: Color3, align: Enum.TextXAlignment?)
	C.text(canvas, C.track(text), 0.08, y, 0.84, 0.035, Font.Bold, color, 6, align or Enum.TextXAlignment.Left)
end

local function subline(canvas: Frame, text: string, y: number, color: Color3)
	C.text(canvas, text, 0.08, y, 0.84, 0.045, Font.Medium, color, 6, Enum.TextXAlignment.Left)
end

local THEMES: { [string]: Theme } = {
	Strength = {
		bg = RGB(26, 27, 30),
		frame = F.PowderBlack,
		draw = function(cv: Frame)
			-- a bumper plate bleeding off the top-right corner
			C.circle(cv, 0.86, 0.26, 0.62, Brand.Amber, 1)
			C.circle(cv, 0.86, 0.26, 0.4, RGB(26, 27, 30), 2)
			C.circle(cv, 0.86, 0.26, 0.09, Brand.Amber, 3)
			kicker(cv, "IRONHAVEN", 0.06, Brand.Amber)
			headline(cv, "STRENGTH", 0.6, 0.17, Brand.Cream)
			subline(cv, "Lift heavy. Rest well. Repeat.", 0.78, Brand.Dim)
			C.frame(cv, 0.08, 0.9, 0.18, 0.008, Brand.Amber, 4)
		end,
	},
	Speed = {
		bg = RGB(16, 28, 48),
		frame = F.PowderBlack,
		draw = function(cv: Frame)
			local lines = { { 0.18, 0.62, 0.02 }, { 0.25, 0.4, 0.012 }, { 0.31, 0.78, 0.03 }, { 0.39, 0.5, 0.012 }, { 0.45, 0.66, 0.02 } }
			for i, l in lines do
				local f = C.frame(cv, 1 - l[2], l[1], l[2] + 0.1, l[3], if i % 2 == 0 then RGB(110, 226, 236) else RGB(60, 168, 156), 2)
				f.Rotation = -8
			end
			kicker(cv, "IRONHAVEN  CARDIO", 0.06, RGB(110, 226, 236))
			headline(cv, "SPEED", 0.6, 0.17, Brand.Cream)
			subline(cv, "Every second counts.", 0.78, RGB(170, 190, 210))
			C.frame(cv, 0.08, 0.9, 0.18, 0.008, RGB(110, 226, 236), 4)
		end,
	},
	Endurance = {
		bg = RGB(234, 216, 186),
		frame = F.Oak,
		draw = function(cv: Frame)
			C.circle(cv, 0.5, 0.34, 0.34, RGB(222, 110, 72), 1)
			for i, w in { 0.84, 0.62, 0.4 } do
				C.frame(cv, (1 - w) / 2, 0.47 + i * 0.035, w, 0.012, RGB(40, 38, 36), 2)
			end
			kicker(cv, "IRONHAVEN", 0.06, RGB(150, 72, 44), Enum.TextXAlignment.Center)
			C.text(cv, "ENDURANCE", 0.08, 0.64, 0.84, 0.13, Font.Condensed, RGB(34, 32, 30), 6)
			C.text(cv, "Go the distance.", 0.08, 0.78, 0.84, 0.045, Font.Medium, RGB(96, 80, 64), 6)
		end,
	},
	Agility = {
		bg = RGB(222, 102, 74),
		frame = F.PowderBlack,
		draw = function(cv: Frame)
			-- zig-zag ladder drill
			for i = 0, 4 do
				local f = C.frame(cv, 0.1 + i * 0.17, 0.3, 0.22, 0.03, Brand.Cream, 2)
				f.AnchorPoint = Vector2.new(0, 0.5)
				f.Rotation = if i % 2 == 0 then -35 else 35
			end
			kicker(cv, "IRONHAVEN", 0.06, Brand.Cream)
			headline(cv, "AGILITY", 0.6, 0.17, Brand.Cream)
			subline(cv, "Quick feet. Sharp mind.", 0.78, RGB(255, 226, 210))
			C.frame(cv, 0.08, 0.9, 0.18, 0.008, Brand.Cream, 4)
		end,
	},
	Recovery = {
		bg = RGB(146, 166, 144),
		frame = F.Birch,
		draw = function(cv: Frame)
			C.circle(cv, 0.42, 0.32, 0.34, RGB(236, 232, 220), 1, 0.35)
			C.circle(cv, 0.6, 0.38, 0.26, RGB(236, 232, 220), 2, 0.55)
			C.circle(cv, 0.5, 0.26, 0.14, RGB(236, 232, 220), 3, 0.2)
			kicker(cv, "IRONHAVEN  RECOVERY", 0.06, RGB(44, 66, 54))
			headline(cv, "RECOVER", 0.6, 0.17, RGB(36, 56, 46))
			subline(cv, "Rest is part of the work.", 0.78, RGB(52, 76, 62))
			C.frame(cv, 0.08, 0.9, 0.18, 0.008, RGB(36, 56, 46), 4)
		end,
	},
	Boxing = {
		bg = RGB(238, 226, 200),
		frame = F.Walnut,
		draw = function(cv: Frame)
			local red = RGB(170, 36, 36)
			C.frame(cv, 0, 0, 1, 0.14, red, 1)
			C.text(cv, C.track("IRONHAVEN BOXING CLUB"), 0.06, 0.045, 0.88, 0.05, Font.Bold, Brand.Cream, 6)
			C.text(cv, "FIGHT", 0.06, 0.18, 0.88, 0.16, Font.Condensed, RGB(28, 26, 24), 6)
			C.text(cv, "NIGHT", 0.06, 0.34, 0.88, 0.16, Font.Condensed, red, 6)
			C.frame(cv, 0.3, 0.535, 0.4, 0.006, RGB(28, 26, 24), 2)
			C.text(cv, "MAIN EVENT", 0.06, 0.57, 0.88, 0.07, Font.Condensed, RGB(28, 26, 24), 6)
			C.text(cv, "Twelve rounds  ·  Championship belt", 0.06, 0.66, 0.88, 0.04, Font.Medium, RGB(90, 76, 60), 6)
			C.text(cv, "FRIDAY  ·  8 PM  ·  THE RING", 0.06, 0.76, 0.88, 0.05, Font.Bold, red, 6)
			C.frame(cv, 0, 0.9, 1, 0.1, red, 1)
		end,
	},
	Vintage = {
		bg = RGB(232, 220, 192),
		frame = F.WalnutPlanks,
		draw = function(cv: Frame)
			local ink, maroon = RGB(46, 36, 30), RGB(112, 36, 44)
			local border = C.frame(cv, 0.05, 0.04, 0.9, 0.92, RGB(232, 220, 192), 1)
			C.stroke(border, maroon, 2)
			C.circle(cv, 0.5, 0.3, 0.3, maroon, 2)
			C.circle(cv, 0.5, 0.3, 0.25, RGB(232, 220, 192), 3)
			C.text(cv, "IH", 0.3, 0.22, 0.4, 0.16, Font.SerifPlain, maroon, 6)
			C.text(cv, "IRON WILL", 0.08, 0.52, 0.84, 0.12, Font.SerifPlain, ink, 6)
			C.text(cv, C.track("OLD SCHOOL STRENGTH"), 0.1, 0.66, 0.8, 0.04, Font.Bold, maroon, 6)
			C.frame(cv, 0.35, 0.74, 0.3, 0.005, ink, 2)
			C.text(cv, "Ironhaven Athletic Club", 0.1, 0.78, 0.8, 0.05, Font.Serif, ink, 6)
		end,
	},
}

---------------------------------------------------------------------------
-- TV screen
---------------------------------------------------------------------------
local function tvScreen(screen: BasePart, content: string)
	local title, sub = C.split(content)
	if title == "" then
		title, sub = "TRAIN WITH PURPOSE", "Ironhaven Performance Club"
	end
	local sg, label = C.gui(screen, C.escape(title), Font.Heavy, Brand.Cream, { PixelsPerStud = C.ppi(screen.Size.Y, 0.24, 48), LightInfluence = 0, Brightness = 1.3, MaxDistance = 140 })
	local cv = root(sg, RGB(18, 19, 24))
	C.gradient(cv, RGB(18, 19, 24), RGB(40, 32, 24), 35)
	-- top bar: channel ident + LIVE pill
	C.text(cv, "IRONHAVEN TV", 0.05, 0.06, 0.4, 0.07, Font.Brand, RGB(200, 196, 188), 4, Enum.TextXAlignment.Left)
	local pill = C.frame(cv, 0.83, 0.06, 0.12, 0.08, RGB(214, 64, 56), 4)
	C.corner(pill, 0.5)
	C.text(pill, "LIVE", 0.1, 0.12, 0.8, 0.76, Font.Heavy, RGB(255, 255, 255), 5)
	-- headline block
	C.frame(cv, 0.05, 0.3, 0.06, 0.012, Brand.Amber, 4)
	C.place(label, 0.05, 0.34, 0.6, 0.24, 6)
	label.TextXAlignment = Enum.TextXAlignment.Left
	if sub then
		C.text(cv, C.escape(sub), 0.05, 0.6, 0.6, 0.08, Font.Medium, Brand.Dim, 6, Enum.TextXAlignment.Left)
	end
	-- stylised stats bars on the right
	for i, h in { 0.22, 0.34, 0.28, 0.42 } do
		local bar = C.frame(cv, 0.7 + (i - 1) * 0.065, 0.7 - h, 0.04, h, if i == 4 then Brand.Amber else RGB(80, 84, 92), 4)
		C.corner(bar, 0.3)
	end
	-- ticker
	C.frame(cv, 0, 0.82, 1, 0.18, RGB(10, 10, 12), 3, 0.15)
	local tag = C.frame(cv, 0.03, 0.86, 0.1, 0.1, Brand.Amber, 4)
	C.text(tag, "NEXT", 0.1, 0.15, 0.8, 0.7, Font.Heavy, Brand.Ink, 5)
	C.text(cv, "Hydrate  ·  Wipe down your station  ·  Re-rack your weights", 0.15, 0.865, 0.8, 0.09, Font.Medium, RGB(214, 210, 202), 4, Enum.TextXAlignment.Left)
end

---------------------------------------------------------------------------
-- Logo variants
---------------------------------------------------------------------------
type LogoStyle = { outer: C.Fin, inner: C.Fin, beam: C.Fin, text: Color3, light: number }
local LOGO: { [string]: LogoStyle } = {
	Light = { outer = C.tint("Plastic", Brand.Cream), inner = C.tint("PowderBlack", Brand.Graphite), beam = C.tint("Plastic", Brand.Cream), text = Brand.Cream, light = 0.7 },
	Dark = { outer = C.tint("PowderBlack", Brand.Ink), inner = C.tint("Plastic", Brand.Cream), beam = C.tint("PowderBlack", Brand.Ink), text = Brand.Ink, light = 1 },
	Brass = { outer = F.Brass, inner = C.tint("PowderBlack", RGB(26, 24, 22)), beam = F.Brass, text = RGB(206, 170, 100), light = 0.85 },
}

-- Shield silhouette (rectangle + 45-degree diamond for the point) centred at x.
local function shield(b: B, x: number, w: number, h: number, z: number, depth: number, f: C.Finish)
	b.box(x, w / 4, z, w, h - w / 2, depth, f, FINE)
	local s = w / math.sqrt(2)
	b.part(L(x, -h / 2 + w / 2, z, 0, 0, 45), Vector3.new(s, s, depth - 0.01), f, FINE)
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------
return function(Props: C.Registry)
	Props.register("mirror", function(parent: Instance, cf: CFrame, width: number, height: number, frame: C.Finish): Model
		local W, H = C.num(width, 8, 1, 120), C.num(height, 7, 1, 30)
		local b = C.begin(parent, "Mirror", cf)
		local fw, fd = 0.2, 0.22
		b.box(0, H / 2 - fw / 2, fd / 2, W, fw, fd, frame, DETAIL)
		b.box(0, -H / 2 + fw / 2, fd / 2, W, fw, fd, frame, DETAIL)
		b.box(W / 2 - fw / 2, 0, fd / 2, fw, H - 2 * fw, fd, frame, DETAIL)
		b.box(-W / 2 + fw / 2, 0, fd / 2, fw, H - 2 * fw, fd, frame, DETAIL)
		b.box(0, 0, 0.12, W - 2 * fw + 0.04, H - 2 * fw + 0.04, 0.06, F.Mirror, { Collide = true, Shadow = false })
		-- panel joints on wide mirror walls
		local panels = math.max(1, math.floor(W / 6 + 0.5))
		for i = 1, panels - 1 do
			b.box(-W / 2 + W * i / panels, 0, 0.155, 0.04, H - 2 * fw, 0.02, C.tint("SteelDark", RGB(60, 64, 68)), FINE)
		end
		return b.model
	end)

	Props.register("wallSign", function(parent: Instance, cf: CFrame, text: string, size: Vector2, style: string): Model
		local X, Y = C.num(size.X, 6, 0.5, 80), C.num(size.Y, 1.6, 0.3, 30)
		local key = if type(style) == "string" and SIGN_STYLES[style] then style else "Area"
		local b = C.begin(parent, "WallSign_" .. key, cf)
		SIGN_STYLES[key](b, if type(text) == "string" then text else "", X, Y)
		return b.model
	end)

	Props.register("logo", function(parent: Instance, cf: CFrame, width: number, variant: string): Model
		local W = C.num(width, 6, 1, 80)
		local st = LOGO[if type(variant) == "string" then variant else "Light"] or LOGO.Light
		local b = C.begin(parent, "Logo", cf)
		local H = W * 0.4
		local sw = H * 0.78
		local sx = W / 2 - sw / 2 -- viewer's left = local +x
		shield(b, sx, sw, H, 0.1, 0.2, st.outer)
		shield(b, sx, sw * 0.8, H * 0.8, 0.12, 0.2, st.inner)
		-- I-beam monogram
		local bw = sw * 0.46
		b.box(sx, H * 0.17, 0.23, bw, H * 0.08, 0.04, st.beam, FINE)
		b.box(sx, -H * 0.13, 0.23, bw, H * 0.08, 0.04, st.beam, FINE)
		b.box(sx, H * 0.02, 0.23, bw * 0.3, H * 0.3, 0.04, st.beam, FINE)
		-- wordmark to the viewer's right of the shield
		local tw = W - sw - H * 0.18
		local carrier = b.box(sx - sw / 2 - H * 0.18 - tw / 2, 0, 0.06, tw, H * 0.5, 0.02, F.Plastic, INVISIBLE)
		carrier.Name = "Wordmark"
		local _sg, label = C.gui(carrier, "IRONHAVEN", Font.Brand, st.text, { PixelsPerStud = C.ppi(H * 0.5, 1, 48), LightInfluence = st.light })
		label.TextXAlignment = Enum.TextXAlignment.Left
		return b.model
	end)

	Props.register("poster", function(parent: Instance, cf: CFrame, size: Vector2, theme: string): Model
		local X, Y = C.num(size.X, 4, 1, 30), C.num(size.Y, 5.5, 1, 30)
		local th = THEMES[if type(theme) == "string" then theme else "Strength"] or THEMES.Strength
		local b = C.begin(parent, "Poster", cf)
		local m = math.min(0.14, math.min(X, Y) * 0.04)
		b.box(0, 0, 0.06, X, Y, 0.12, th.frame, DETAIL)
		local art = b.box(0, 0, 0.125, X - m * 2, Y - m * 2, 0.02, C.tint("Plastic", th.bg), FINE)
		local sg, label = C.gui(art, "", Font.Bold, Brand.Cream, { PixelsPerStud = C.ppi(Y, 0.17, 64), LightInfluence = 1, MaxDistance = 90 })
		label.Visible = false
		th.draw(root(sg, th.bg))
		return b.model
	end)

	Props.register("tv", function(parent: Instance, cf: CFrame, width: number, content: string): Model
		local W = C.num(width, 6, 1.5, 40)
		local H = W * 0.58
		local b = C.begin(parent, "TV", cf)
		b.box(0, 0, 0.1, math.min(1.2, W * 0.2), math.min(0.9, H * 0.25), 0.2, F.PowderBlack, FINE) -- wall bracket
		b.box(0, 0, 0.3, W, H, 0.18, C.tint("PlasticBlack", RGB(18, 18, 20)), DETAIL)
		local screen = b.box(0, 0.02, 0.4, W - 0.14, H - 0.18, 0.02, F.Screen, FINE)
		screen.Name = "Screen"
		tvScreen(screen, if type(content) == "string" then content else "")
		return b.model
	end)

	Props.register("clock", function(parent: Instance, cf: CFrame, diameter: number): Model
		local D = C.num(diameter, 2, 0.8, 12)
		local b = C.begin(parent, "Clock", cf)
		b.cylZ(0, 0, 0.09, 0.18, D, F.PowderBlack, DETAIL)
		b.cylZ(0, 0, 0.185, 0.02, D - 0.16, C.tint("Plastic", RGB(244, 242, 236)), FINE)
		local ink = C.tint("PlasticBlack", RGB(24, 24, 26))
		local R = D / 2 - 0.2
		for i = 0, 11 do
			local th = math.rad(i * 30)
			local major = i % 3 == 0
			local len = if major then D * 0.11 else D * 0.05
			local rr = R - len / 2
			-- viewer-clockwise: viewer's right is local -x
			b.part(L(-math.sin(th) * rr, math.cos(th) * rr, 0.2, 0, 0, i * 30), Vector3.new(if major then D * 0.035 else D * 0.02, len, 0.01), ink, FINE)
		end
		local function hand(deg: number, len: number, w: number, f: C.Finish, z: number)
			local th = math.rad(deg)
			b.part(L(-math.sin(th) * len * 0.4, math.cos(th) * len * 0.4, z, 0, 0, deg), Vector3.new(w, len, 0.01), f, FINE)
		end
		hand(305, R * 0.6, D * 0.04, ink, 0.205) -- 10:10, the classic display time
		hand(60, R * 0.92, D * 0.025, ink, 0.215)
		hand(200, R * 0.95, D * 0.008, F.Amber, 0.225)
		b.cylZ(0, 0, 0.23, 0.02, D * 0.06, F.Amber, FINE)
		return b.model
	end)

	Props.register("speaker", function(parent: Instance, cf: CFrame): Model
		local b = C.begin(parent, "Speaker", cf)
		b.box(0, 0, 0.03, 0.4, 0.6, 0.06, F.PowderBlack, FINE)
		b.span(Vector3.new(0, 0, 0.05), Vector3.new(0, 0, 0.35), 0.14, F.PowderBlack, FINE)
		local body = L(0, 0, 0.8, -12, 0, 0)
		b.part(body, Vector3.new(1.0, 1.6, 0.9), C.tint("PlasticBlack", RGB(28, 28, 30)), DETAIL)
		b.part(body * CFrame.new(0, 0, -0.455), Vector3.new(0.9, 1.5, 0.02), C.tint("FabricGrey", RGB(44, 44, 46)), FINE)
		b.part(body * CFrame.new(0, -0.62, -0.47), Vector3.new(0.14, 0.05, 0.01), F.Amber, FINE)
		return b.model
	end)

	Props.register("acousticPanels", function(parent: Instance, cf: CFrame, width: number, height: number, finish: C.Finish): Model
		local W, H = C.num(width, 8, 1, 80), C.num(height, 5, 1, 30)
		local b = C.begin(parent, "AcousticPanels", cf)
		local cols = math.max(1, math.floor(W / 2.2 + 0.5))
		local rows = math.max(1, math.floor(H / 2.4 + 0.5))
		while cols * rows > 40 do
			if cols >= rows then
				cols -= 1
			else
				rows -= 1
			end
		end
		local c0 = C.colorOf(finish)
		local tones = { c0, c0:Lerp(Color3.new(0, 0, 0), 0.12), c0:Lerp(Color3.new(1, 1, 1), 0.08) }
		local pw, ph = W / cols, H / rows
		for i = 1, cols do
			for j = 1, rows do
				local f = C.retint(finish, tones[1 + (i * 2 + j) % 3])
				b.box(-W / 2 + pw * (i - 0.5), -H / 2 + ph * (j - 0.5), 0.18, pw - 0.16, ph - 0.16, 0.36, f, DETAIL)
			end
		end
		return b.model
	end)

	Props.register("woodSlats", function(parent: Instance, cf: CFrame, width: number, height: number, finish: C.Finish): Model
		local W, H = C.num(width, 8, 1, 80), C.num(height, 7, 1, 30)
		local b = C.begin(parent, "WoodSlats", cf)
		b.box(0, 0, 0.06, W, H, 0.12, C.tint("FabricGrey", RGB(30, 30, 32)), DETAIL)
		local pitch = math.max(0.55, W / 44)
		local n = math.max(1, math.floor(W / pitch))
		local span = (n - 1) * pitch
		for i = 0, n - 1 do
			b.box(-span / 2 + i * pitch, 0, 0.26, 0.3, H, 0.28, finish, DETAIL)
		end
		return b.model
	end)

	Props.register("firstAid", function(parent: Instance, cf: CFrame): Model
		local b = C.begin(parent, "FirstAid", cf)
		local green = C.tint("Plastic", RGB(32, 136, 82))
		local white = C.tint("Plastic", RGB(246, 246, 242))
		b.box(0, 0, 0.16, 1.4, 1.2, 0.32, green, DETAIL)
		b.box(0, 0, 0.325, 0.5, 0.15, 0.02, white, FINE)
		b.box(0, 0, 0.325, 0.15, 0.5, 0.02, white, FINE)
		b.box(-0.55, 0, 0.34, 0.06, 0.3, 0.04, white, FINE) -- latch (viewer's right)
		return b.model
	end)

	Props.register("fireExtinguisher", function(parent: Instance, cf: CFrame): Model
		local b = C.begin(parent, "FireExtinguisher", cf)
		local red = C.tint("PowderRed", RGB(186, 34, 32))
		b.box(0, 0.25, 0.025, 0.3, 0.5, 0.05, F.PowderBlack, FINE) -- wall bracket
		b.cylY(0, -0.2, 0.3, 1.2, 0.5, red, DETAIL)
		b.ball(0, 0.4, 0.3, 0.5, red, FINE)
		b.box(0, 0.72, 0.3, 0.16, 0.22, 0.16, F.PowderBlack, FINE)
		b.part(L(0, 0.86, 0.38, -18, 0, 0), Vector3.new(0.07, 0.04, 0.38), F.PowderBlack, FINE) -- lever
		b.span(Vector3.new(0.08, 0.72, 0.36), Vector3.new(0.3, -0.6, 0.42), 0.07, F.PowderBlack, FINE) -- hose
		b.cylZ(-0.1, 0.62, 0.42, 0.03, 0.1, C.tint("Plastic", RGB(240, 240, 236)), FINE) -- gauge
		return b.model
	end)

	Props.register("exitSign", function(parent: Instance, cf: CFrame): Model
		local b = C.begin(parent, "ExitSign", cf)
		b.box(0, 0, 0.1, 1.8, 0.7, 0.2, C.tint("Plastic", RGB(236, 236, 232)), FINE)
		local face = b.box(0, 0, 0.21, 1.66, 0.56, 0.02, C.tint("Plastic", RGB(24, 140, 76)), FINE)
		face.Name = "ExitFace"
		local sg, label = C.gui(face, "EXIT", Font.Heavy, RGB(255, 255, 255), { PixelsPerStud = 80, LightInfluence = 0, Brightness = 1.4, MaxDistance = 120 })
		local cv = root(sg, RGB(22, 150, 80))
		cv.ZIndex = 0
		C.place(label, 0.08, 0.14, 0.56, 0.72, 6)
		local chip = C.frame(cv, 0.7, 0.14, 0.26, 0.72, RGB(255, 255, 255), 2)
		C.corner(chip, 0.15)
		local box = C.frame(chip, 0.5, 0.5, 0.9, 0.9, RGB(255, 255, 255), 3)
		box.AnchorPoint = Vector2.new(0.5, 0.5)
		box.SizeConstraint = Enum.SizeConstraint.RelativeYY
		box.BackgroundTransparency = 1
		arrow(box, 0, RGB(22, 150, 80), 4)
		return b.model
	end)
end
