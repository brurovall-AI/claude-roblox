--!strict
--[[
	Material palette ("finishes") for the whole map. Always build with a finish
	name instead of raw Material/Color so areas stay coherent:

		Kit.box(parent, cf, size, "RubberFloor")
		Kit.box(parent, cf, size, Palette.tint("Plaster", Color3.fromRGB(...)))

	Visual direction: warm, realistic, premium. Neon is reserved for tiny
	accents (Apex Lab light lines, screens). Each area has an identity:
	  Lobby      travertine, walnut, brass, white plaster, plants
	  Beginner   light oak, soft white, coral accents
	  FreeWeights black rubber, oak platforms, forest-green walls
	  MainHall   exposed concrete, dark steel trusses, turf, amber safety
	  Cables     slate grey walls, graphite, brushed steel
	  Cardio     pale concrete, glass wall, teal accents
	  Lockers    white + terracotta tiles, oak lockers
	  Lounge     terrazzo, green velvet, walnut, brass
	  Boxing     red brick, worn timber, red ropes, tungsten light
	  Recovery   birch, sage, cedar sauna, stone
	  Private    charcoal, walnut, glass
	  Foundry    black steel, diamond plate, raw concrete, safety yellow
	  ProFloor   polished concrete, graphite, copper
	  Arena      burgundy seats, black stage, gold
	  VIP        marble, walnut, brass, emerald, black leather
	  Rooftop    terracotta track, turf, teak decking, glass rails
	  Yard       grass, red track, concrete, timber
	  Apex       white composite, titanium, smoked glass, cyan light lines
]]

export type Finish = {
	Material: Enum.Material,
	Color: Color3,
	Reflectance: number?,
	Transparency: number?,
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local F: { [string]: Finish } = {
	-- Structure
	Concrete = { Material = Enum.Material.Concrete, Color = rgb(168, 164, 158) },
	ConcreteDark = { Material = Enum.Material.Concrete, Color = rgb(96, 94, 92) },
	ConcretePolished = { Material = Enum.Material.SmoothPlastic, Color = rgb(150, 148, 144), Reflectance = 0.06 },
	ConcreteWarm = { Material = Enum.Material.Concrete, Color = rgb(184, 176, 164) },
	Plaster = { Material = Enum.Material.Plaster, Color = rgb(236, 233, 226) },
	PlasterWarm = { Material = Enum.Material.Plaster, Color = rgb(226, 214, 196) },
	PlasterGreen = { Material = Enum.Material.Plaster, Color = rgb(52, 78, 64) },
	PlasterSlate = { Material = Enum.Material.Plaster, Color = rgb(86, 96, 106) },
	PlasterGraphite = { Material = Enum.Material.Plaster, Color = rgb(58, 60, 64) },
	PlasterSage = { Material = Enum.Material.Plaster, Color = rgb(150, 168, 146) },
	PlasterBurgundy = { Material = Enum.Material.Plaster, Color = rgb(92, 31, 43) },
	PlasterCharcoal = { Material = Enum.Material.Plaster, Color = rgb(44, 45, 48) },
	Brick = { Material = Enum.Material.Brick, Color = rgb(138, 75, 58) },
	BrickDark = { Material = Enum.Material.Brick, Color = rgb(92, 56, 46) },
	BrickWhite = { Material = Enum.Material.Brick, Color = rgb(222, 218, 210) },
	Travertine = { Material = Enum.Material.Limestone, Color = rgb(214, 198, 172) },
	Terrazzo = { Material = Enum.Material.Granite, Color = rgb(214, 208, 198) },
	Marble = { Material = Enum.Material.Marble, Color = rgb(236, 234, 230) },
	MarbleDark = { Material = Enum.Material.Marble, Color = rgb(40, 40, 42) },
	Granite = { Material = Enum.Material.Granite, Color = rgb(120, 116, 112) },
	Slate = { Material = Enum.Material.Slate, Color = rgb(70, 72, 76) },
	TileWhite = { Material = Enum.Material.CeramicTiles, Color = rgb(236, 236, 232) },
	TileTerracotta = { Material = Enum.Material.CeramicTiles, Color = rgb(199, 98, 62) },
	TileGrey = { Material = Enum.Material.CeramicTiles, Color = rgb(130, 132, 134) },
	Asphalt = { Material = Enum.Material.Asphalt, Color = rgb(58, 58, 60) },
	Pavement = { Material = Enum.Material.Pavement, Color = rgb(150, 146, 140) },
	Cobblestone = { Material = Enum.Material.Cobblestone, Color = rgb(132, 126, 118) },

	-- Floors
	RubberFloor = { Material = Enum.Material.Rubber, Color = rgb(40, 41, 44) },
	RubberFleck = { Material = Enum.Material.Rubber, Color = rgb(56, 58, 62) },
	RubberTeal = { Material = Enum.Material.Rubber, Color = rgb(44, 112, 106) },
	RubberCoral = { Material = Enum.Material.Rubber, Color = rgb(206, 112, 82) },
	RubberRed = { Material = Enum.Material.Rubber, Color = rgb(168, 58, 48) },
	TrackRed = { Material = Enum.Material.Rubber, Color = rgb(176, 82, 60) },
	Turf = { Material = Enum.Material.Grass, Color = rgb(66, 118, 60) },
	TurfDark = { Material = Enum.Material.Grass, Color = rgb(48, 92, 46) },
	Grass = { Material = Enum.Material.Grass, Color = rgb(88, 132, 66) },
	Carpet = { Material = Enum.Material.Carpet, Color = rgb(70, 66, 64) },
	CarpetBurgundy = { Material = Enum.Material.Carpet, Color = rgb(96, 34, 44) },
	DiamondPlate = { Material = Enum.Material.DiamondPlate, Color = rgb(120, 122, 126) },

	-- Wood
	Oak = { Material = Enum.Material.WoodPlanks, Color = rgb(196, 160, 116) },
	OakSolid = { Material = Enum.Material.Wood, Color = rgb(186, 148, 104) },
	Birch = { Material = Enum.Material.WoodPlanks, Color = rgb(222, 200, 166) },
	Walnut = { Material = Enum.Material.Wood, Color = rgb(104, 70, 48) },
	WalnutPlanks = { Material = Enum.Material.WoodPlanks, Color = rgb(112, 76, 52) },
	Cedar = { Material = Enum.Material.WoodPlanks, Color = rgb(176, 122, 79) },
	Teak = { Material = Enum.Material.WoodPlanks, Color = rgb(150, 104, 66) },
	WornTimber = { Material = Enum.Material.WoodPlanks, Color = rgb(128, 96, 70) },
	Plywood = { Material = Enum.Material.Wood, Color = rgb(206, 176, 132) },

	-- Metal
	Steel = { Material = Enum.Material.Metal, Color = rgb(150, 154, 160) },
	SteelBrushed = { Material = Enum.Material.Metal, Color = rgb(176, 180, 186), Reflectance = 0.08 },
	SteelDark = { Material = Enum.Material.Metal, Color = rgb(52, 54, 58) },
	PowderBlack = { Material = Enum.Material.SmoothPlastic, Color = rgb(30, 31, 34) },
	PowderGraphite = { Material = Enum.Material.SmoothPlastic, Color = rgb(64, 66, 70) },
	PowderWhite = { Material = Enum.Material.SmoothPlastic, Color = rgb(236, 236, 234) },
	PowderYellow = { Material = Enum.Material.SmoothPlastic, Color = rgb(224, 165, 38) },
	PowderRed = { Material = Enum.Material.SmoothPlastic, Color = rgb(170, 40, 40) },
	Chrome = { Material = Enum.Material.Metal, Color = rgb(206, 210, 214), Reflectance = 0.35 },
	BlackChrome = { Material = Enum.Material.Metal, Color = rgb(36, 36, 40), Reflectance = 0.28 },
	Brass = { Material = Enum.Material.Metal, Color = rgb(196, 160, 90), Reflectance = 0.12 },
	Gold = { Material = Enum.Material.Metal, Color = rgb(214, 172, 72), Reflectance = 0.18 },
	Copper = { Material = Enum.Material.Metal, Color = rgb(184, 115, 51), Reflectance = 0.1 },
	Titanium = { Material = Enum.Material.Metal, Color = rgb(154, 160, 166), Reflectance = 0.1 },
	Iron = { Material = Enum.Material.Metal, Color = rgb(70, 72, 76) },
	CastIron = { Material = Enum.Material.Metal, Color = rgb(44, 45, 48) },
	Rust = { Material = Enum.Material.CorrodedMetal, Color = rgb(120, 80, 60) },

	-- Upholstery / soft
	VinylBlack = { Material = Enum.Material.Leather, Color = rgb(32, 32, 34) },
	VinylRed = { Material = Enum.Material.Leather, Color = rgb(150, 36, 38) },
	VinylCoral = { Material = Enum.Material.Leather, Color = rgb(226, 120, 88) },
	VinylTeal = { Material = Enum.Material.Leather, Color = rgb(52, 140, 132) },
	LeatherTan = { Material = Enum.Material.Leather, Color = rgb(176, 128, 82) },
	LeatherBlack = { Material = Enum.Material.Leather, Color = rgb(24, 24, 26) },
	LeatherCognac = { Material = Enum.Material.Leather, Color = rgb(140, 80, 44) },
	Velvet = { Material = Enum.Material.Fabric, Color = rgb(63, 95, 74) },
	FabricGrey = { Material = Enum.Material.Fabric, Color = rgb(120, 120, 122) },
	FabricCream = { Material = Enum.Material.Fabric, Color = rgb(226, 218, 200) },
	FabricWhite = { Material = Enum.Material.Fabric, Color = rgb(240, 240, 236) },
	FabricRed = { Material = Enum.Material.Fabric, Color = rgb(178, 58, 46) },
	FabricBlue = { Material = Enum.Material.Fabric, Color = rgb(60, 88, 130) },
	Rope = { Material = Enum.Material.Fabric, Color = rgb(196, 182, 150) },
	Rubber = { Material = Enum.Material.Rubber, Color = rgb(28, 28, 30) },
	RubberGrip = { Material = Enum.Material.Rubber, Color = rgb(46, 46, 48) },
	Foam = { Material = Enum.Material.SmoothPlastic, Color = rgb(70, 72, 76) },

	-- Plastic / composite
	Plastic = { Material = Enum.Material.SmoothPlastic, Color = rgb(220, 220, 218) },
	PlasticBlack = { Material = Enum.Material.SmoothPlastic, Color = rgb(26, 26, 28) },
	PlasticCoral = { Material = Enum.Material.SmoothPlastic, Color = rgb(242, 140, 90) },
	PlasticTeal = { Material = Enum.Material.SmoothPlastic, Color = rgb(60, 168, 156) },
	PlasticYellow = { Material = Enum.Material.SmoothPlastic, Color = rgb(242, 196, 78) },
	Composite = { Material = Enum.Material.SmoothPlastic, Color = rgb(236, 238, 240) },
	Carbon = { Material = Enum.Material.Slate, Color = rgb(36, 38, 42) },

	-- Glass / mirror / water
	Glass = { Material = Enum.Material.Glass, Color = rgb(196, 214, 220), Transparency = 0.72, Reflectance = 0.06 },
	GlassTint = { Material = Enum.Material.Glass, Color = rgb(120, 136, 144), Transparency = 0.6, Reflectance = 0.08 },
	GlassSmoked = { Material = Enum.Material.Glass, Color = rgb(40, 46, 52), Transparency = 0.45, Reflectance = 0.1 },
	GlassFrosted = { Material = Enum.Material.Glass, Color = rgb(226, 232, 234), Transparency = 0.35 },
	Mirror = { Material = Enum.Material.SmoothPlastic, Color = rgb(170, 178, 184), Reflectance = 0.82 },
	Water = { Material = Enum.Material.Glass, Color = rgb(120, 180, 196), Transparency = 0.45, Reflectance = 0.15 },
	Ice = { Material = Enum.Material.Ice, Color = rgb(200, 226, 236), Transparency = 0.2 },

	-- Light sources (keep small!)
	LightPanel = { Material = Enum.Material.Neon, Color = rgb(255, 244, 226) },
	LightWarm = { Material = Enum.Material.Neon, Color = rgb(255, 214, 160) },
	LightCool = { Material = Enum.Material.Neon, Color = rgb(226, 240, 255) },
	LightCyan = { Material = Enum.Material.Neon, Color = rgb(110, 226, 236) },
	LightAmber = { Material = Enum.Material.Neon, Color = rgb(255, 180, 70) },
	LightRed = { Material = Enum.Material.Neon, Color = rgb(255, 80, 70) },
	Screen = { Material = Enum.Material.Neon, Color = rgb(30, 34, 40) },
	ScreenLit = { Material = Enum.Material.Neon, Color = rgb(70, 110, 140) },

	-- Nature
	Leaf = { Material = Enum.Material.LeafyGrass, Color = rgb(70, 120, 62) },
	LeafDark = { Material = Enum.Material.Grass, Color = rgb(48, 90, 50) },
	Soil = { Material = Enum.Material.Ground, Color = rgb(84, 64, 48) },
	Bark = { Material = Enum.Material.Wood, Color = rgb(92, 70, 54) },
	Sand = { Material = Enum.Material.Sand, Color = rgb(206, 190, 150) },
	Stone = { Material = Enum.Material.Rock, Color = rgb(130, 126, 120) },
	Pebble = { Material = Enum.Material.Pebble, Color = rgb(150, 146, 140) },

	-- Brand
	Amber = { Material = Enum.Material.SmoothPlastic, Color = rgb(242, 169, 59) },
	Ink = { Material = Enum.Material.SmoothPlastic, Color = rgb(22, 22, 24) },
	Cream = { Material = Enum.Material.SmoothPlastic, Color = rgb(244, 238, 226) },
}

local Palette = {}
Palette.F = F

function Palette.get(name: string): Finish
	local f = F[name]
	if not f then
		warn("unknown finish " .. name)
		return F.Plastic
	end
	return f
end

-- A finish with a different colour (keeps material/reflectance).
function Palette.tint(name: string, color: Color3): Finish
	local base = Palette.get(name)
	return { Material = base.Material, Color = color, Reflectance = base.Reflectance, Transparency = base.Transparency }
end

-- Register a custom finish at build time.
function Palette.define(name: string, finish: Finish)
	F[name] = finish
end

return Palette
