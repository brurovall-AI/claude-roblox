--!strict
--[[
	Shared building blocks for the equipment builders.

	Every helper takes a Ctx (model, tier, style, station frame) so finishes,
	shapes and detail density follow the tier language in Equipment/Style.luau
	automatically: round friendly tubes on Beginner, square powder-coat on
	Amateur..Legendary, slim composite on Ultimate; plain vinyl -> piping ->
	stitching -> quilting on pads; plain rubber -> banded cast iron -> brass ->
	gold -> lit composite on plates, and so on.

	Local frames: builders work in the station's local space with
	  x = right (across the trainee), y = up, z = FORWARD (cf.LookVector).
	`c.at(x, y, z)` returns a CFrame with the station's rotation, `c.pt` a point.
	Note z is FORWARD here (Roblox local -Z), which keeps builder code readable.

	Collision: frames, pads, bases and big housings use Kit.SOLID; small details,
	cables and everything inside a Mover/Spinner/Swinger use Kit.DETAIL (animated
	parts must never shove players around).
]]

local Kit = require("../../Kit")
local Palette = require("../../Palette")
local Style = require("../Style")

export type TierStyle = Style.TierStyle
export type Finish = Palette.Finish
export type DecorOpts = { Length: number?, Name: string? }
export type Builder = (model: Model, tier: number, cf: CFrame, style: TierStyle) -> ()
export type DecorBuilder = (model: Model, tier: number, cf: CFrame, style: TierStyle, opts: DecorOpts) -> ()

-- The subset of the Equipment library the builders use (passed in by Equipment/init).
export type Lib = {
	register: (stationType: string, builder: Builder) -> (),
	registerDecor: (kind: string, builder: DecorBuilder) -> (),
	userSpot: (model: Model, hrpCf: CFrame) -> Part,
	standingSpot: (model: Model, floorCf: CFrame) -> Part,
	benchSpot: (model: Model, padTop: Vector3, headDir: Vector3) -> Part,
	mover: (model: Model, travel: Vector3) -> Model,
	spinner: (model: Model, pivot: CFrame, rate: number) -> Model,
	swinger: (model: Model, pivot: CFrame) -> Model,
	placard: (parent: Instance, cf: CFrame, width: number, style: TierStyle, name: string?) -> Part,
}

-- Per-tier shape language (complements the finishes in Style).
export type Traits = {
	round: boolean, -- round tubes + ball caps (Beginner)
	tube: number, -- main tube size
	bolts: boolean, -- visible hardware
	piping: Finish?, -- pad edge piping
	stitch: Finish?, -- pad top stitch lines
	quilt: boolean, -- quilted channels (Legendary)
	band: Finish?, -- trim bands at joints (Legendary gold, Elite brass)
	float: boolean, -- floating elements + light lines (Ultimate)
}

export type Ctx = {
	E: Lib,
	model: Model,
	tier: number,
	st: TierStyle,
	tr: Traits,
	cf: CFrame,
	at: (x: number, y: number, z: number) -> CFrame,
	pt: (x: number, y: number, z: number) -> Vector3,
}

export type PlateSpec = { d: number, t: number }

local F = Palette.F
local DETAIL = Kit.DETAIL
local SOLID = Kit.SOLID

local S = {}

S.F = F
S.DETAIL = DETAIL
S.SOLID = SOLID
S.CABLE = F.PlasticBlack
S.RUBBER = F.Rubber
S.SCREEN = F.Screen
-- Mid-grey stitch thread for dark leathers.
S.THREAD = Palette.tint("FabricGrey", Color3.fromRGB(92, 92, 96))

local TRAITS: { Traits } = {
	{ round = true, tube = 0.4, bolts = false, piping = nil, stitch = nil, quilt = false, band = nil, float = false },
	{ round = false, tube = 0.36, bolts = true, piping = nil, stitch = nil, quilt = false, band = nil, float = false },
	{ round = false, tube = 0.36, bolts = true, piping = F.PlasticBlack, stitch = nil, quilt = false, band = nil, float = false },
	{ round = false, tube = 0.38, bolts = true, piping = nil, stitch = F.FabricCream, quilt = false, band = F.Brass, float = false },
	{ round = false, tube = 0.4, bolts = true, piping = F.Gold, stitch = nil, quilt = true, band = F.Gold, float = false },
	{ round = false, tube = 0.3, bolts = false, piping = nil, stitch = nil, quilt = false, band = nil, float = true },
}

---------------------------------------------------------------------------
-- Context / registration
---------------------------------------------------------------------------
function S.ctx(E: Lib, model: Model, tier: number, st: TierStyle, cf: CFrame): Ctx
	local t = math.clamp(math.floor(tier), 1, 6)
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, -z)
	end
	local function pt(x: number, y: number, z: number): Vector3
		return (cf * CFrame.new(x, y, -z)).Position
	end
	return { E = E, model = model, tier = t, st = st, tr = TRAITS[t], cf = cf, at = at, pt = pt }
end

-- Registers a station builder that receives a Ctx. Failures are reported and
-- contained so one broken machine never takes down a whole area's dressing.
function S.station(E: Lib, stationType: string, fn: (c: Ctx) -> ())
	E.register(stationType, function(model: Model, tier: number, cf: CFrame, style: TierStyle)
		local ok, err = pcall(fn, S.ctx(E, model, tier, style, cf))
		if not ok then
			print(`[equipment] {stationType} T{tier} FAILED: {err}`)
		end
	end)
end

function S.decor(E: Lib, kind: string, fn: (c: Ctx, opts: DecorOpts) -> ())
	E.registerDecor(kind, function(model: Model, tier: number, cf: CFrame, style: TierStyle, opts: DecorOpts)
		local ok, err = pcall(fn, S.ctx(E, model, tier, style, cf), opts)
		if not ok then
			print(`[equipment] decor {kind} T{tier} FAILED: {err}`)
		end
	end)
end

---------------------------------------------------------------------------
-- Geometry primitives (station-aligned)
---------------------------------------------------------------------------
-- CFrame for a member from a to b whose cross-section stays aligned with the
-- station frame (Kit.span aligns vertical members to world axes instead).
function S.spanCF(c: Ctx, a: Vector3, b: Vector3): (CFrame, number)
	local d = b - a
	local len = d.Magnitude
	if len < 1e-4 then
		return CFrame.new(a) * c.cf.Rotation, 0
	end
	local x = d.Unit
	local ref = c.cf.UpVector
	if math.abs(x:Dot(ref)) > 0.9 then
		ref = c.cf.LookVector
	end
	local z = x:Cross(ref).Unit
	local y = z:Cross(x).Unit
	return CFrame.fromMatrix((a + b) / 2, x, y, z), len
end

-- Square bar (box) between two points.
function S.bar(c: Ctx, parent: Instance, a: Vector3, b: Vector3, w: number, h: number?, f: Kit.FinishArg, opts: Kit.Opts?): Part
	local cf, len = S.spanCF(c, a, b)
	return Kit.box(parent, cf, Vector3.new(math.max(len, 0.02), h or w, w), f, opts)
end

-- Round rod between two points.
function S.rod(_c: Ctx, parent: Instance, a: Vector3, b: Vector3, d: number, f: Kit.FinishArg, opts: Kit.Opts?): Part
	return Kit.span(parent, a, b, d, f, opts)
end

-- Structural tube in the tier's shape language (round T1, slim T6, square otherwise).
function S.tube(c: Ctx, parent: Instance, a: Vector3, b: Vector3, t: number?, f: Kit.FinishArg?, collide: boolean?): Part
	local th = t or c.tr.tube
	local fin = f or c.st.Frame
	local opts = if collide == false then DETAIL else SOLID
	if c.tr.round then
		return Kit.span(parent, a, b, th * 1.12, fin, opts)
	end
	return S.bar(c, parent, a, b, th, th, fin, opts)
end

-- Rounded joint cap (Beginner friendly ball caps; trim caps on Elite and up).
function S.cap(c: Ctx, parent: Instance, p: Vector3, size: number?)
	local s = size or c.tr.tube
	if c.tier == 2 or c.tier == 3 then
		return
	elseif c.tr.round then
		Kit.ball(parent, p, s * 1.25, c.st.FrameAccent, DETAIL)
	elseif c.tier == 5 then
		Kit.box(parent, CFrame.new(p) * c.cf.Rotation, Vector3.new(s + 0.06, 0.08, s + 0.06), F.Gold, DETAIL)
	elseif c.tier == 6 then
		Kit.box(parent, CFrame.new(p) * c.cf.Rotation, Vector3.new(s + 0.02, 0.06, s + 0.02), F.Titanium, DETAIL)
	else
		Kit.box(parent, CFrame.new(p) * c.cf.Rotation, Vector3.new(s + 0.04, 0.06, s + 0.04), F.PlasticBlack, DETAIL)
	end
end

-- Trim band around a vertical tube at point p (Elite brass / Legendary gold).
function S.band(c: Ctx, parent: Instance, p: Vector3, size: number?)
	local b = c.tr.band
	if not b then
		return
	end
	local s = (size or c.tr.tube) + 0.05
	Kit.box(parent, CFrame.new(p) * c.cf.Rotation, Vector3.new(s, 0.1, s), b, DETAIL)
end

-- Visible bolt head on a face. cf.LookVector = face normal.
function S.bolt(c: Ctx, parent: Instance, cf: CFrame)
	if not c.tr.bolts then
		return
	end
	local f = if c.tier == 5 then F.Gold elseif c.tier == 4 then F.Brass else F.SteelBrushed
	Kit.cylZ(parent, cf, 0.06, 0.12, f, DETAIL)
end

-- Thin emissive line (Ultimate only). Square cross-section.
function S.glow(c: Ctx, parent: Instance, a: Vector3, b: Vector3, t: number?)
	local l = c.st.Light
	if not l then
		return
	end
	S.bar(c, parent, a, b, t or 0.05, t or 0.05, l, DETAIL)
end

-- Pop-pin / adjustment knob, axis along cf.LookVector (the knob sits at cf).
function S.knob(c: Ctx, parent: Instance, cf: CFrame)
	local t = c.tier
	if t == 1 then
		Kit.ball(parent, cf, 0.32, F.PlasticCoral, DETAIL)
	elseif t == 6 then
		Kit.cylZ(parent, cf, 0.14, 0.26, F.Titanium, DETAIL)
		Kit.cylZ(parent, cf * CFrame.new(0, 0, -0.08), 0.03, 0.2, F.LightCyan, DETAIL)
	else
		local f = if t == 2 then F.PlasticBlack elseif t == 3 then F.PowderRed elseif t == 4 then F.Brass else F.Gold
		Kit.cylZ(parent, cf, 0.08, 0.1, F.SteelBrushed, DETAIL)
		Kit.cylZ(parent, cf * CFrame.new(0, 0, -0.1), 0.14, 0.24, f, DETAIL)
	end
end

-- Cable (thin dark line) between two points.
function S.cable(parent: Instance, a: Vector3, b: Vector3, d: number?)
	Kit.span(parent, a, b, d or 0.08, S.CABLE, DETAIL)
end

-- Pulley wheel in a housing; cf = wheel centre, wheel axis along cf.RightVector.
function S.pulley(c: Ctx, parent: Instance, cf: CFrame, d: number?)
	local dd = d or 0.55
	local wheel = if c.tier == 1 then F.PlasticTeal elseif c.tier >= 5 then c.st.Metal else F.SteelDark
	Kit.cyl(parent, cf, 0.14, dd, wheel, DETAIL)
	local cheek = if c.tier == 6 then F.Composite else c.st.Frame
	Kit.box(parent, cf * CFrame.new(0.11, 0, 0), Vector3.new(0.06, dd * 0.9, dd * 0.9), cheek, DETAIL)
	if c.tier >= 4 then
		Kit.box(parent, cf * CFrame.new(-0.11, 0, 0), Vector3.new(0.06, dd * 0.9, dd * 0.9), cheek, DETAIL)
	end
end

-- Floor foot under a post (cf = floor point under the post, station rotation).
function S.foot(c: Ctx, parent: Instance, cf: CFrame, w: number?, d: number?)
	local ww, dd = w or 0.7, d or 0.7
	local t = c.tier
	if t == 1 then
		Kit.cylY(parent, cf * CFrame.new(0, 0.09, 0), 0.18, math.max(ww, dd), F.RubberCoral, DETAIL)
	elseif t == 2 or t == 3 then
		Kit.box(parent, cf * CFrame.new(0, 0.06, 0), Vector3.new(ww, 0.12, dd), F.Rubber, DETAIL)
	elseif t == 4 then
		Kit.box(parent, cf * CFrame.new(0, 0.07, 0), Vector3.new(ww, 0.14, dd), F.Rubber, DETAIL)
		Kit.box(parent, cf * CFrame.new(0, 0.16, 0), Vector3.new(ww + 0.04, 0.05, dd + 0.04), F.Brass, DETAIL)
	elseif t == 5 then
		Kit.box(parent, cf * CFrame.new(0, 0.06, 0), Vector3.new(ww + 0.06, 0.12, dd + 0.06), F.Gold, DETAIL)
	end
end

--[[
	Floor base under a machine. Returns the walking/standing height of its top.
	T1-3: thin rubber mat (only when `always`); T4: oak platform with brass edge;
	T5: dark marble plinth with a gold reveal; T6: floating carbon slab with a
	recessed shadow gap and a cyan light line.
]]
function S.plinth(c: Ctx, parent: Instance, cf: CFrame, w: number, d: number, always: boolean?): number
	local t = c.tier
	if t == 4 then
		local b = 0.38
		Kit.box(parent, cf * CFrame.new(0, 0.12, 0), Vector3.new(w - b * 2, 0.24, d - b * 2), F.RubberFleck, SOLID)
		for _, sx in { -1, 1 } do
			Kit.box(parent, cf * CFrame.new(sx * (w / 2 - b / 2), 0.13, 0), Vector3.new(b, 0.26, d), F.OakSolid, SOLID)
		end
		for _, sz in { -1, 1 } do
			Kit.box(parent, cf * CFrame.new(0, 0.13, sz * (d / 2 - b / 2)), Vector3.new(w - b * 2, 0.26, b), F.OakSolid, SOLID)
		end
		return 0.26
	elseif t == 5 then
		Kit.box(parent, cf * CFrame.new(0, 0.05, 0), Vector3.new(w - 0.2, 0.1, d - 0.2), F.PlasticBlack, DETAIL)
		Kit.box(parent, cf * CFrame.new(0, 0.11, 0), Vector3.new(w + 0.04, 0.03, d + 0.04), F.Gold, DETAIL)
		Kit.box(parent, cf * CFrame.new(0, 0.235, 0), Vector3.new(w, 0.23, d), F.MarbleDark, SOLID)
		return 0.35
	elseif t == 6 then
		Kit.box(parent, cf * CFrame.new(0, 0.06, 0), Vector3.new(w - 0.6, 0.12, d - 0.6), F.PlasticBlack, DETAIL)
		Kit.box(parent, cf * CFrame.new(0, 0.1, 0), Vector3.new(w - 0.5, 0.04, d - 0.5), F.LightCyan, DETAIL)
		Kit.box(parent, cf * CFrame.new(0, 0.24, 0), Vector3.new(w, 0.2, d), F.Carbon, SOLID)
		Kit.box(parent, cf * CFrame.new(0, 0.345, 0), Vector3.new(w - 0.1, 0.01, d - 0.1), F.Composite, DETAIL)
		return 0.35
	elseif always then
		Kit.box(parent, cf * CFrame.new(0, 0.05, 0), Vector3.new(w, 0.1, d), c.st.Base, SOLID)
		return 0.1
	end
	return 0
end

---------------------------------------------------------------------------
-- Upholstery
---------------------------------------------------------------------------
--[[
	Upholstered pad. cf = cushion centre (cf orientation defines the pad axes);
	size = (width X, thickness Y, length Z). A support board sits under the
	cushion (its own 0.1). Returns the cushion part.
	  T1 rounded ends | T2 plain | T3 contrast piping | T4 contrast stitching
	  T5 quilted channels + gold piping | T6 floats above a carbon board with
	  a light line in the gap.
]]
function S.pad(c: Ctx, parent: Instance, cf: CFrame, size: Vector3, noBoard: boolean?): Part
	local st, tr = c.st, c.tr
	local w, h, l = size.X, size.Y, size.Z
	local cushion: Part
	if c.tier == 1 and l > h * 1.6 then
		cushion = Kit.box(parent, cf, Vector3.new(w, h, l - h), st.Upholstery, SOLID)
		Kit.cyl(parent, cf * CFrame.new(0, 0, (l - h) / 2), w, h, st.Upholstery, DETAIL)
		Kit.cyl(parent, cf * CFrame.new(0, 0, -(l - h) / 2), w, h, st.Upholstery, DETAIL)
	else
		cushion = Kit.box(parent, cf, size, st.Upholstery, SOLID)
	end
	if not noBoard then
		local board = if c.tier == 4 then F.OakSolid elseif c.tier == 5 then F.Walnut elseif c.tier == 6 then F.Carbon elseif c.tier == 1 then st.Frame else F.PlasticBlack
		local gap = if tr.float then 0.12 else 0
		Kit.box(parent, cf * CFrame.new(0, -h / 2 - 0.05 - gap, 0), Vector3.new(w - 0.06, 0.1, l - 0.06), board, DETAIL)
		if tr.float then
			Kit.box(parent, cf * CFrame.new(0, -h / 2 - 0.06, 0), Vector3.new(w - 0.3, 0.03, l - 0.3), c.st.Light or F.LightCyan, DETAIL)
		end
	end
	if tr.piping then
		for _, sx in { -1, 1 } do
			Kit.box(parent, cf * CFrame.new(sx * (w / 2), h / 2 - 0.02, 0), Vector3.new(0.06, 0.06, l + 0.02), tr.piping, DETAIL)
		end
	end
	if tr.stitch then
		for _, sx in { -1, 1 } do
			Kit.box(parent, cf * CFrame.new(sx * (w / 2 - 0.14), h / 2, 0), Vector3.new(0.03, 0.02, l - 0.28), tr.stitch, DETAIL)
		end
	end
	if tr.quilt then
		local n = math.max(2, math.floor(l / 0.75))
		for i = 1, n - 1 do
			local z = -l / 2 + l * i / n
			Kit.box(parent, cf * CFrame.new(0, h / 2, z), Vector3.new(w - 0.12, 0.025, 0.04), S.THREAD, DETAIL)
		end
	end
	return cushion
end

---------------------------------------------------------------------------
-- Iron
---------------------------------------------------------------------------
local T1_PLATES = { F.PlasticTeal, F.PlasticCoral, F.PlasticYellow }

-- Weight plate, axis along cf.RightVector. idx varies Beginner colours.
function S.plate(c: Ctx, parent: Instance, cf: CFrame, d: number, t: number, idx: number?)
	local st = c.st
	local f: Finish = st.Plate
	if c.tier == 1 then
		f = T1_PLATES[((idx or 1) - 1) % #T1_PLATES + 1]
	end
	Kit.cyl(parent, cf, t, d, f, DETAIL)
	if c.tier >= 3 and d > 1 then
		local band = if c.tier == 6 then (st.Light or F.LightCyan) else st.PlateAccent
		Kit.cyl(parent, cf, t * 0.4, d + 0.04, band, DETAIL)
	end
	local hub = if c.tier == 1 then F.SteelBrushed elseif c.tier == 2 then F.Steel elseif c.tier == 3 then F.Chrome else st.PlateAccent
	Kit.cyl(parent, cf, t + 0.05, math.max(0.34, d * 0.26), hub, DETAIL)
end

local function barFinishes(c: Ctx): (Finish, Finish, Finish)
	local t = c.tier
	if t == 1 then
		return F.SteelBrushed, F.SteelBrushed, F.PlasticCoral
	elseif t == 2 then
		return F.Steel, F.Steel, F.SteelDark
	elseif t == 3 then
		return F.Chrome, F.Chrome, F.PowderRed
	elseif t == 4 then
		return F.SteelBrushed, F.SteelBrushed, F.Brass
	elseif t == 5 then
		return F.BlackChrome, F.Gold, F.Gold
	end
	return F.Titanium, F.Titanium, (c.st.Light or F.LightCyan)
end

--[[
	Barbell along cf.RightVector, centred at cf. plates = per-side list from the
	inside out. len defaults to 7.2 (Olympic). All parts are DETAIL.
]]
function S.barbell(c: Ctx, parent: Instance, cf: CFrame, plates: { PlateSpec }, len: number?)
	local L = len or 7.2
	local sleeve = math.min(1.4, L * 0.19)
	local inner = L / 2 - sleeve
	local shaft, sleeveF, collarF = barFinishes(c)
	Kit.cyl(parent, cf, inner * 2, 0.17, shaft, DETAIL)
	if c.tier >= 4 then
		-- knurled grip zones
		for _, sx in { -1, 1 } do
			Kit.cyl(parent, cf * CFrame.new(sx * inner * 0.45, 0, 0), inner * 0.6, 0.18, c.st.Grip, DETAIL)
		end
	end
	for _, sx in { -1, 1 } do
		Kit.cyl(parent, cf * CFrame.new(sx * (inner + 0.05), 0, 0), 0.1, 0.44, collarF, DETAIL)
		Kit.cyl(parent, cf * CFrame.new(sx * (inner + 0.1 + (sleeve - 0.1) / 2), 0, 0), sleeve - 0.1, 0.27, sleeveF, DETAIL)
		local x = inner + 0.12
		for i, p in plates do
			S.plate(c, parent, cf * CFrame.new(sx * (x + p.t / 2), 0, 0), p.d, p.t, i)
			x += p.t + 0.01
		end
		if #plates > 0 and c.tier >= 2 then
			-- clamp collar
			Kit.cyl(parent, cf * CFrame.new(sx * (x + 0.08), 0, 0), 0.16, 0.36, collarF, DETAIL)
		end
	end
end

-- Dumbbell along cf.RightVector. s = 0..1 weight class; lite = 3-part version for racks.
function S.dumbbell(c: Ctx, parent: Instance, cf: CFrame, s: number, lite: boolean?)
	local t = c.tier
	local hd = 0.46 + 0.34 * s
	local hl = 0.26 + 0.3 * s
	local grip = 0.8
	local handleF = if t == 5 then F.Gold elseif t == 6 then F.Titanium elseif t == 4 then F.Steel else F.SteelBrushed
	Kit.cyl(parent, cf, grip + hl * 2 - 0.02, 0.16, handleF, DETAIL)
	for _, sx in { -1, 1 } do
		local hcf = cf * CFrame.new(sx * (grip / 2 + hl / 2), 0, 0)
		if t == 1 then
			local f = T1_PLATES[math.floor(s * 2.99) + 1]
			Kit.box(parent, hcf, Vector3.new(hl, hd * 0.86, hd * 0.86), f, DETAIL)
		elseif t == 2 then
			Kit.box(parent, hcf * CFrame.Angles(math.rad(45), 0, 0), Vector3.new(hl, hd * 0.8, hd * 0.8), F.Rubber, DETAIL)
			if not lite then
				Kit.box(parent, hcf, Vector3.new(hl, hd * 0.8, hd * 0.8), F.Rubber, DETAIL)
			end
		else
			local headF = if t == 3 then F.CastIron elseif t == 4 then F.Iron elseif t == 5 then F.BlackChrome else F.Composite
			Kit.cyl(parent, hcf, hl, hd, headF, DETAIL)
			if not lite then
				local capF = if t == 3 then F.Chrome elseif t == 4 then F.Brass elseif t == 5 then F.Gold else (c.st.Light or F.LightCyan)
				local w = if t == 6 then 0.03 else 0.06
				Kit.cyl(parent, cf * CFrame.new(sx * (grip / 2 + hl + w / 2), 0, 0), w, hd * (if t == 6 then 0.9 else 0.62), capF, DETAIL)
			end
		end
	end
end

--[[
	Selectorized weight stack standing on floor-level `base` (base.LookVector =
	the side the pin and the trainee are on). The top `moving` plates, the pin
	and the cap go into `mover` (travel (0, 2.5, 0) in the machine contract).
	Returns the cable anchor (top of the cap) and the top of the guide rods.
]]
function S.stack(c: Ctx, parent: Instance, mover: Model, base: CFrame, n: number, shroud: boolean?, lite: boolean?): (Vector3, number)
	local st, t = c.st, c.tier
	local w, d, pt = 1.5, 0.95, 0.26
	local y0 = 0.36
	local plateF = if t == 1 then F.PowderWhite elseif t == 2 then F.PowderBlack elseif t == 3 then F.PowderBlack elseif t == 4 then F.CastIron elseif t == 5 then F.BlackChrome else F.Composite
	local topF = if t == 1 then F.PlasticCoral elseif t == 3 then F.PowderRed elseif t == 4 then F.Brass elseif t == 5 then F.Gold elseif t == 6 then F.Titanium else F.PowderGraphite
	-- bumper block + base
	Kit.box(parent, base * CFrame.new(0, y0 / 2, 0), Vector3.new(w + 0.5, y0, d + 0.3), if t == 6 then F.Carbon else st.Frame, SOLID)
	local isLite = lite == true
	local stackTop = y0 + n * pt
	local rodTop = stackTop + 3.2
	local rodF = if t == 1 then F.SteelBrushed elseif t >= 5 then st.Metal else F.Chrome
	for _, sx in { -1, 1 } do
		Kit.cylY(parent, base * CFrame.new(sx * (w / 2 + 0.1), (y0 + rodTop) / 2, 0), rodTop - y0, 0.14, rodF, DETAIL)
	end
	for i = 1, n do
		local y = y0 + (i - 0.5) * pt
		local moving = i > n - 3
		local f = if i == n then topF else plateF
		Kit.box(if moving then mover else parent, base * CFrame.new(0, y, 0), Vector3.new(w, pt - 0.03, d), f, if moving then DETAIL else SOLID)
	end
	-- selector pin (in the third plate from the top) + top cap
	local pinY = y0 + (n - 2.5) * pt
	Kit.cylZ(mover, base * CFrame.new(0.25, pinY, -(d / 2 + 0.2)), 0.42, 0.08, F.SteelBrushed, DETAIL)
	if isLite then
		Kit.ball(mover, base * CFrame.new(0.25, pinY, -(d / 2 + 0.44)), 0.2, topF, DETAIL)
	else
		S.knob(c, mover, base * CFrame.new(0.25, pinY, -(d / 2 + 0.42)))
	end
	Kit.box(mover, base * CFrame.new(0, stackTop + 0.12, 0), Vector3.new(0.8, 0.24, 0.6), st.Frame, DETAIL)
	-- rod head (static)
	if not isLite then
		Kit.box(parent, base * CFrame.new(0, rodTop + 0.12, 0), Vector3.new(w + 0.5, 0.24, 0.5), st.Frame, SOLID)
	end
	if shroud and t >= 3 then
		local sh = rodTop + 0.24 - 0.2
		local shF = if t == 4 then F.OakSolid elseif t == 5 then F.BlackChrome elseif t == 6 then F.Composite else st.Frame
		for _, sx in { -1, 1 } do
			Kit.box(parent, base * CFrame.new(sx * (w / 2 + 0.36), 0.2 + sh / 2, 0), Vector3.new(0.1, sh, d + 0.5), shF, SOLID)
			if t == 5 then
				Kit.box(parent, base * CFrame.new(sx * (w / 2 + 0.42), 0.2 + sh / 2, -(d / 2 + 0.2)), Vector3.new(0.03, sh - 0.3, 0.06), F.Gold, DETAIL)
			elseif t == 6 then
				S.glow(c, parent, (base * CFrame.new(sx * (w / 2 + 0.42), 0.5, -(d / 2 + 0.22))).Position, (base * CFrame.new(sx * (w / 2 + 0.42), sh, -(d / 2 + 0.22))).Position, 0.04)
			end
		end
		if t == 6 then
			-- smoked glass front window
			Kit.box(parent, base * CFrame.new(0, 0.2 + sh / 2, -(d / 2 + 0.24)), Vector3.new(w + 0.62, sh, 0.06), F.GlassSmoked, SOLID)
		end
	end
	return (base * CFrame.new(0, stackTop + 0.24, 0)).Position, rodTop
end

-- Small tier placard; cf.LookVector points at the reader.
function S.placard(c: Ctx, parent: Instance, cf: CFrame, width: number, name: string?): Part
	return c.E.placard(parent, cf, width, c.st, name)
end

-- Station names shown on placards.
S.NAMES = {
	DumbbellCurl = "CURL STATION",
	BenchPress = "BENCH PRESS",
	SquatRack = "POWER RACK",
	Deadlift = "DEADLIFT",
	ChestPress = "CHEST PRESS",
	LegPress = "LEG PRESS",
	CableCrossover = "CROSSOVER",
	LatPulldown = "LAT PULLDOWN",
	PullUpBar = "PULL-UP",
	TireFlip = "TIRE FLIP",
	LogPress = "LOG PRESS",
	AtlasStone = "ATLAS STONE",
	GravPress = "GRAV-PRESS",
	Rower = "ROWER",
	Bike = "SPIN",
	BattleRopes = "BATTLE ROPES",
	HydroRower = "HYDRO-ROWER",
	Treadmill = "TREADMILL",
	SledPush = "SLED",
	HyperTreadmill = "HYPER-RUN",
	AgilityLadder = "AGILITY",
	SpeedBag = "SPEED BAG",
	HeavyBag = "HEAVY BAG",
	PlyoBox = "PLYO",
	ReflexWall = "REFLEX",
	YogaMat = "FLOW",
	Sauna = "SAUNA",
	IceBath = "ICE BATH",
	CryoPod = "CRYO",
} :: { [string]: string }

return S
