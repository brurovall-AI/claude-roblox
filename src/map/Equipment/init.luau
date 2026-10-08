--!strict
--[[
	Training equipment library: one builder per StationType, every tier.

		local Equipment = require("../Equipment")
		Equipment.build(parent, "BenchPress", 3, CFrame.new(x, floorY, z) * Kit.rotY(90), { AreaId = "FreeWeights" })

	`cf` is a FLOOR-LEVEL CFrame at the centre of the station's footprint.
	cf.LookVector is the direction the trainee FACES while training.
	Footprints (width X across the trainee, depth Z along LookVector) are in
	Equipment.Footprints — use them for spacing (leave >= 3 studs aisles).

	============================ STATION CONTRACT ============================
	Equipment.build(...) returns a Model with:
	  tag "Station"; attributes StationType, Tier, StationId, AreaId
	  ModelStreamingMode = Atomic
	  "UserSpot"   invisible marker Part = the trainee's HumanoidRootPart CFrame
	  "PromptPart" invisible Part holding ProximityPrompt "TrainPrompt"
	Optional animated parts (the client animates them locally while in use):
	  "Mover"      Model moved by attribute MoverTravel (Vector3, WORLD space,
	               offset at the top/bottom of a rep) — bars, weight-stack plates,
	               rower seats, sleds, stones
	  "Spinner"    Model(s) rotated about their WorldPivot's local X axis at
	               attribute SpinRate (rad/s at full cadence) — flywheels, cranks,
	               treadmill rollers
	  "Swinger"    Model swinging like a pendulum about its WorldPivot's local X
	               axis on each hit — heavy bags, speed bags

	==================== USERSPOT POSES (R15, scale 1) =======================
	All positions are HumanoidRootPart CENTRES. Standing HRP centre is 3.0
	above the floor; shoulders are ~1.4 above the HRP centre; arms ~2.5 long.
	  Standing poses (StandCurl, StandPress, Squat, Deadlift, CableFly, Run,
	    Push, Footwork, BoxHigh, Box, Jump, Ropes, TireFlip):
	      floor + 3.0, facing cf.LookVector (on a treadmill: deck top + 3.0)
	  Bench (lying on the back): pad top P -> HRP at P + 0.55. HRP UpVector
	      points toward the head end of the bench (horizontal), LookVector = world UP:
	      CFrame.fromMatrix(pos, headDir:Cross(Vector3.new(0,-1,0)), headDir, Vector3.new(0,-1,0))
	      Bar rests at P + 3.0 directly above the shoulders (HRP + 1.3 * headDir);
	      MoverTravel = (0, -1.9, 0)
	  Seated (SeatedPress, Pulldown, Bike, Row, SitRelax): seat top S -> HRP at
	      S + 1.3, facing forward
	  LegPress: hip on the reclined seat; UserSpot = upright seated CFrame rotated
	      back 40 degrees about its RightVector (CFrame.Angles(math.rad(40), 0, 0))
	  Hang (pull-up): bar height H -> HRP at H - 3.8, under the bar, facing the bar side
	  Yoga (mat): floor + 1.3 (seated cross-legged), facing cf.LookVector
	  Float (cryo pod): pod floor + 3.2, standing upright facing out of the pod

	Mover conventions:
	  BenchPress  bar + plates, travel (0, -1.9, 0)
	  SquatRack   bar on the back at standing shoulder height (floor + 4.6), travel (0, -2.0, 0)
	  Deadlift    bar centre at plate radius (floor + 1.25), travel (0, 1.3, 0)
	  Machines (ChestPress, LegPress, CableCrossover, LatPulldown): top 3-4 stack
	              plates + pin + top cap, travel (0, 2.5, 0)
	  Rower/HydroRower  seat, travel = -LookVector * 2.2
	  LogPress    the log (resting at shoulder height on blocks), travel (0, 3.2, 0)
	  AtlasStone  stone, travel (0, 3.5, 0) onto its platform
	  TireFlip    tire, travel (0, 1.4, 0)
	  GravPress   floating bar, travel (0, 3.0, 0)
	  SledPush    sled, travel = LookVector * 1.2
]]

local Kit = require("../Kit")
local Style = require("./Style")

export type BuildOpts = { AreaId: string?, Id: string? }
export type Builder = (model: Model, tier: number, cf: CFrame, style: Style.TierStyle) -> ()

local Equipment = {}

Equipment.Style = Style

-- Approximate footprints: X = width, Y = height, Z = depth (along LookVector).
Equipment.Footprints = {
	DumbbellCurl = Vector3.new(6, 7, 6),
	BenchPress = Vector3.new(8, 8, 12),
	SquatRack = Vector3.new(10, 10, 10),
	Deadlift = Vector3.new(11, 3, 8),
	ChestPress = Vector3.new(6, 8, 9),
	LegPress = Vector3.new(7, 7, 12),
	CableCrossover = Vector3.new(14, 10, 7),
	LatPulldown = Vector3.new(6, 9, 8),
	PullUpBar = Vector3.new(8, 10, 5),
	TireFlip = Vector3.new(8, 3, 10),
	LogPress = Vector3.new(9, 6, 7),
	AtlasStone = Vector3.new(8, 5, 8),
	GravPress = Vector3.new(9, 10, 9),
	Rower = Vector3.new(4, 4, 12),
	Bike = Vector3.new(3, 5, 5),
	BattleRopes = Vector3.new(6, 4, 20),
	HydroRower = Vector3.new(5, 5, 12),
	Treadmill = Vector3.new(4, 6, 8),
	SledPush = Vector3.new(5, 4, 30),
	HyperTreadmill = Vector3.new(6, 8, 10),
	AgilityLadder = Vector3.new(4, 1, 16),
	SpeedBag = Vector3.new(5, 9, 5),
	HeavyBag = Vector3.new(6, 10, 6),
	PlyoBox = Vector3.new(5, 4, 6),
	ReflexWall = Vector3.new(10, 9, 6),
	YogaMat = Vector3.new(3, 1, 7),
	Sauna = Vector3.new(4, 4, 3),
	IceBath = Vector3.new(6, 4, 8),
	CryoPod = Vector3.new(6, 9, 6),
} :: { [string]: Vector3 }

local REGISTRY: { [string]: Builder } = {}

function Equipment.register(stationType: string, builder: Builder)
	REGISTRY[stationType] = builder
end

local counter = 0

---------------------------------------------------------------------------
-- Decor equipment (NOT trainable stations): storage racks, loose benches,
-- functional rigs, duel tables. Same builder signature, no Station tag.
-- Kinds: "DumbbellRack" (cf at floor, rack runs along cf.RightVector, length via opts.Length),
--        "PlateTree", "BarbellRack", "KettlebellRack", "MedBallRack", "BenchFlat",
--        "Rig" (functional training rig frame, opts.Length), "PlyoBoxSet", "DuelTable"
---------------------------------------------------------------------------
export type DecorOpts = { Length: number?, Name: string? }
export type DecorBuilder = (model: Model, tier: number, cf: CFrame, style: Style.TierStyle, opts: DecorOpts) -> ()

local DECOR_REG: { [string]: DecorBuilder } = {}

function Equipment.registerDecor(kind: string, builder: DecorBuilder)
	DECOR_REG[kind] = builder
end

function Equipment.decor(parent: Instance, kind: string, tier: number, cf: CFrame, opts: DecorOpts?): Model
	local o: DecorOpts = opts or {}
	local model = Kit.model(parent, o.Name or `{kind}_T{tier}`, cf)
	local builder = DECOR_REG[kind]
	local style = Style.get(tier)
	if builder then
		builder(model, tier, cf, style, o)
	else
		local len = o.Length or 6
		Kit.box(model, cf * CFrame.new(0, 1.5, 0), Vector3.new(len, 3, 2), style.Frame, Kit.SOLID)
	end
	return model
end

--[[
	Arm-wrestling table (DuelTable contract). cf: floor centre, the table's long
	axis along cf.LookVector; players stand at either end facing each other.
	Visuals come from the "DuelTable" decor builder; markers are added here.
]]
function Equipment.duelTable(parent: Instance, cf: CFrame, tableId: string, tier: number?): Model
	local model = Equipment.decor(parent, "DuelTable", tier or 4, cf, { Name = "DuelTable_" .. tableId })
	model:SetAttribute("TableId", tableId)
	model:AddTag("DuelTable")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	-- table top ~3.2 high; competitors stand 2.6 from centre facing each other
	Kit.marker(model, "SeatA", cf * CFrame.new(0, 3, -2.6) * CFrame.Angles(0, math.rad(180), 0))
	Kit.marker(model, "SeatB", cf * CFrame.new(0, 3, 2.6))
	Kit.marker(model, "Grip", cf * CFrame.new(0, 3.9, 0))
	return model
end

---------------------------------------------------------------------------
-- Contract helpers for builders
---------------------------------------------------------------------------
-- Marks where the trainee's HumanoidRootPart goes while training.
function Equipment.userSpot(model: Model, hrpCf: CFrame): Part
	local old = model:FindFirstChild("UserSpot")
	if old then
		old:Destroy()
	end
	return Kit.marker(model, "UserSpot", hrpCf, Vector3.new(2, 2, 1))
end

-- Standing UserSpot helper: floor-level cf -> HRP 3 studs up, same facing.
function Equipment.standingSpot(model: Model, floorCf: CFrame): Part
	return Equipment.userSpot(model, floorCf * CFrame.new(0, 3, 0))
end

-- Bench helper: pad top centre point, head direction (horizontal unit vector).
function Equipment.benchSpot(model: Model, padTop: Vector3, headDir: Vector3): Part
	local down = Vector3.new(0, -1, 0)
	local pos = padTop + Vector3.new(0, 0.55, 0)
	return Equipment.userSpot(model, CFrame.fromMatrix(pos, headDir:Cross(down), headDir, down))
end

function Equipment.mover(model: Model, travel: Vector3): Model
	local m = model:FindFirstChild("Mover") :: Model?
	if not m then
		m = Kit.model(model, "Mover")
	end
	model:SetAttribute("MoverTravel", travel)
	return m :: Model
end

function Equipment.spinner(model: Model, pivot: CFrame, rate: number): Model
	local s = Kit.model(model, "Spinner", pivot)
	s:SetAttribute("SpinRate", rate)
	return s
end

function Equipment.swinger(model: Model, pivot: CFrame): Model
	return Kit.model(model, "Swinger", pivot)
end

-- Small tier placard (brand + tier label) for the machine's shroud/upright.
function Equipment.placard(parent: Instance, cf: CFrame, width: number, style: Style.TierStyle, name: string?)
	local plate = Kit.box(parent, cf, Vector3.new(width, width * 0.32, 0.06), style.FrameAccent, Kit.DETAIL)
	Kit.sign(plate, `<b>IRONHAVEN</b>  <font transparency="0.35">{name or style.Label}</font>`, {
		PixelsPerStud = 60,
		TextColor = Color3.fromRGB(240, 236, 228),
		Padding = 0.14,
		LightInfluence = 1,
	})
	return plate
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function fallback(model: Model, tier: number, cf: CFrame, style: Style.TierStyle)
	local fp = Equipment.Footprints[model:GetAttribute("StationType") :: string] or Vector3.new(5, 5, 5)
	Kit.box(model, cf * CFrame.new(0, 0.1, 0), Vector3.new(fp.X, 0.2, fp.Z), style.Base, Kit.SOLID)
	Kit.box(model, cf * CFrame.new(0, fp.Y / 2, fp.Z / 2 - 0.5), Vector3.new(fp.X * 0.8, fp.Y, 1), style.Frame, Kit.SOLID)
	Equipment.standingSpot(model, cf * CFrame.new(0, 0, -fp.Z / 4))
	local _ = tier
end

function Equipment.build(parent: Instance, stationType: string, tier: number, cf: CFrame, opts: BuildOpts?): Model
	local o: BuildOpts = opts or {}
	counter += 1
	local model = Kit.model(parent, `{stationType}_T{tier}`, cf)
	model:SetAttribute("StationType", stationType)
	model:SetAttribute("Tier", tier)
	model:SetAttribute("StationId", o.Id or string.format("%s_%d", stationType, counter))
	model:SetAttribute("AreaId", o.AreaId or "")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local style = Style.get(tier)
	local builder = REGISTRY[stationType] or fallback
	builder(model, tier, cf, style)

	-- contract checks / defaults
	local spot = model:FindFirstChild("UserSpot") :: BasePart?
	if not spot then
		spot = Equipment.standingSpot(model, cf)
	end
	local promptPart = model:FindFirstChild("PromptPart") :: BasePart?
	if not promptPart then
		local sp = spot :: BasePart
		promptPart = Kit.marker(model, "PromptPart", sp.CFrame, Vector3.new(2, 2, 2))
	end
	local pp = Kit.prompt(promptPart :: BasePart, "Train", stationType, { MaxDistance = 9 })
	pp.Name = "TrainPrompt"
	model:AddTag("Station")
	return model
end

-- Load builder modules (each calls Equipment.register for its types).
local function loadBuilders()
	local list = require("./Builders")
	for _, mod in list do
		mod(Equipment)
	end
end
loadBuilders()

return Equipment
