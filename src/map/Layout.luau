--!strict
--[[
	Master floor plan for the Ironhaven complex. EVERY map module builds against
	these numbers so architecture, dressing and gameplay volumes line up.

	Axes: +X east, +Z north, +Y up. The main entrance faces south (-Z).
	Rect = { X0, X1, Z0, Z1 } in studs (X0 < X1, Z0 < Z1).

	Vertical levels (top surface of each floor slab):
	  B1   = -22  (lower level; ceiling underside at -2)
	  G    =   0  (ground; ceiling underside at 26)
	  L2   =  28  (second floor; ceiling underside at 52)
	  ROOF =  54  (roof deck)
	Slabs are 2 studs thick (G slab spans -2..0, L2 slab 26..28, roof 52..54).

	Main building footprint: X -150..150, Z -100..100 (B1 only to Z = 60).
	Exterior walls are 2 thick, centred on the footprint edge.
	Interior partition walls are 1 thick, centred on the rect edges below.
]]

export type Rect = { X0: number, X1: number, Z0: number, Z1: number }
-- Door: centre point on the wall line. Wall "NS" = the wall runs north-south
-- (constant X, door faces east/west); "EW" = the wall runs east-west (constant Z).
export type Door = { X: number, Z: number, Width: number, Height: number, Wall: string }

local function R(x0: number, x1: number, z0: number, z1: number): Rect
	return { X0 = x0, X1 = x1, Z0 = z0, Z1 = z1 }
end

local Layout = {}

Layout.Y = { B1 = -22, G = 0, L2 = 28, ROOF = 54 }
Layout.CEIL = { B1 = -2, G = 26, L2 = 52 }
Layout.SLAB = 2
Layout.EXT_WALL = 2
Layout.INT_WALL = 1

Layout.Building = R(-150, 150, -100, 100)
Layout.BasementFootprint = R(-150, 150, -100, 60)

---------------------------------------------------------------------------
-- Ground floor (Y = 0, 26 high)
---------------------------------------------------------------------------
Layout.G = {
	Lobby = R(-60, 60, -100, -10), -- reception + atrium (area "Lobby")
	Beginner = R(-150, -72, -100, -40),
	WestCorridor = R(-72, -60, -100, -40), -- part of area "FreeWeights" access path (open)
	FreeWeights = R(-150, -60, -40, 36),
	Cables = R(-150, -60, 36, 100),
	MainHall = R(-60, 60, -10, 100),
	Lounge = R(60, 150, -100, -40),
	EastCorridor = R(60, 72, -40, 26),
	LockersA = R(72, 150, -40, -7),
	LockersB = R(72, 150, -7, 26),
	Cardio = R(60, 150, 26, 100),
}

-- Atrium: void through the L2 slab above the lobby, glass skylight in the roof.
Layout.AtriumVoid = R(-30, 30, -62, -10)

-- Grand stair G -> L2 inside the atrium, climbing north.
Layout.GrandStair = {
	X0 = -9,
	X1 = 9,
	StartZ = -58, -- bottom step front edge at Y = 0
	Steps = 14, -- per flight (two flights of 14 x 1 stud)
	Run = 1.5,
	LandingZ0 = -37, -- landing at Y = 14 spans Z -37..-31
	LandingZ1 = -31,
	EndZ = -10, -- top of flight 2 arrives at Y = 28, Z = -10
}

-- Stair G -> B1 in the lobby's east side, descending south.
Layout.BasementStair = {
	Opening = R(36, 48, -56, -16), -- hole in the ground slab (railings around it)
	TopZ = -16, -- top step at Y = 0, Z = -16
	Steps = 11, -- per flight (two flights of 11 x 1 stud)
	Run = 1.5,
	LandingZ0 = -32.5, -- landing at Y = -11 spans Z -32.5..-38.5
	LandingZ1 = -38.5,
	BottomZ = -55, -- arrives at Y = -22
}

-- Elevator shaft (all levels). Doors face +X (east).
Layout.Elevator = { Shaft = R(-52, -42, -52, -40), DoorX = -42, DoorZ = -46, DoorWidth = 6 }

-- Doors / openings on the ground floor (centre positions; widths in studs).
Layout.GDoors = {
	MainEntrance = { X = 0, Z = -100, Width = 24, Height = 14, Wall = "EW" }, -- south facade (glass doors)
	LobbyToWestCorridor = { X = -60, Z = -78, Width = 12, Height = 12, Wall = "NS" },
	WestCorridorToBeginner = { X = -72, Z = -64, Width = 12, Height = 12, Wall = "NS" },
	WestCorridorToFreeWeights = { X = -66, Z = -40, Width = 12, Height = 14, Wall = "EW" }, -- gate L6
	MainHallToFreeWeights = { X = -60, Z = 10, Width = 16, Height = 14, Wall = "NS" },
	FreeWeightsToCables = { X = -105, Z = 36, Width = 14, Height = 14, Wall = "EW" }, -- gate L15
	MainHallToCables = { X = -60, Z = 68, Width = 14, Height = 14, Wall = "NS" }, -- gate L15
	FreeWeightsToYard = { X = -150, Z = -2, Width = 12, Height = 12, Wall = "NS" }, -- exterior door -> Yard path
	LobbyToMainHallWest = { X = -20, Z = -10, Width = 16, Height = 16, Wall = "EW" }, -- gate L9
	LobbyToMainHallEast = { X = 20, Z = -10, Width = 16, Height = 16, Wall = "EW" }, -- gate L9
	LobbyToLounge = { X = 60, Z = -74, Width = 36, Height = 16, Wall = "NS" }, -- wide opening
	LoungeToEastCorridor = { X = 66, Z = -40, Width = 12, Height = 12, Wall = "EW" },
	EastCorridorToLockersA = { X = 72, Z = -24, Width = 8, Height = 10, Wall = "NS" },
	EastCorridorToLockersB = { X = 72, Z = 10, Width = 8, Height = 10, Wall = "NS" },
	EastCorridorToCardio = { X = 66, Z = 26, Width = 12, Height = 12, Wall = "EW" }, -- gate L4
	MainHallToCardio = { X = 60, Z = 64, Width = 40, Height = 16, Wall = "NS" }, -- gate L4 (wide glass)
	BasementStairTop = { X = 42, Z = -16, Width = 12, Height = 10, Wall = "EW" }, -- gate L18 at the stair head
} :: { [string]: Door }

---------------------------------------------------------------------------
-- Second floor (Y = 28, 24 high)
---------------------------------------------------------------------------
Layout.L2 = {
	Mezzanine = R(-60, 60, -100, -10), -- Hall of Fame balcony around the atrium void
	Hallway = R(-60, 60, -10, 10),
	ProFloor = R(-60, 60, 10, 100),
	Foundry = R(-150, -60, -100, 100),
	EastHall = R(60, 150, -8, 8),
	VIP = R(60, 150, -100, -8),
	Arena = R(60, 150, 8, 100),
}

Layout.L2Doors = {
	HallwayToProFloor = { X = 0, Z = 10, Width = 24, Height = 14, Wall = "EW" }, -- gate L24
	HallwayToFoundry = { X = -60, Z = 0, Width = 14, Height = 14, Wall = "NS" }, -- gate L30
	HallwayToEastHall = { X = 60, Z = 0, Width = 14, Height = 14, Wall = "NS" },
	EastHallToArena = { X = 105, Z = 8, Width = 18, Height = 14, Wall = "EW" },
	EastHallToVIP = { X = 105, Z = -8, Width = 12, Height = 12, Wall = "EW" }, -- VIP gate
	EastHallToSkybridge = { X = 150, Z = 0, Width = 10, Height = 12, Wall = "NS" }, -- gate L50 R1
} :: { [string]: Door }

-- Gated doorways: door name -> area that the gate protects. A gate always
-- enforces the stricter side of the doorway. Gameplay.buildGates places gate
-- models (sliding glass doors + requirement sign) in these openings, so the
-- shell must leave them EMPTY (no door leaves, no glass).
Layout.Gates = {
	{ Floor = "G", Door = "WestCorridorToFreeWeights", Area = "FreeWeights" },
	{ Floor = "G", Door = "MainHallToFreeWeights", Area = "MainHall" },
	{ Floor = "G", Door = "FreeWeightsToCables", Area = "Cables" },
	{ Floor = "G", Door = "MainHallToCables", Area = "Cables" },
	{ Floor = "G", Door = "LobbyToMainHallWest", Area = "MainHall" },
	{ Floor = "G", Door = "LobbyToMainHallEast", Area = "MainHall" },
	{ Floor = "G", Door = "EastCorridorToCardio", Area = "Cardio" },
	{ Floor = "G", Door = "MainHallToCardio", Area = "MainHall" },
	{ Floor = "G", Door = "BasementStairTop", Area = "Concourse" },
	{ Floor = "L2", Door = "HallwayToProFloor", Area = "ProFloor" },
	{ Floor = "L2", Door = "HallwayToFoundry", Area = "Foundry" },
	{ Floor = "L2", Door = "EastHallToVIP", Area = "VIP" },
	{ Floor = "L2", Door = "EastHallToSkybridge", Area = "Apex" },
	{ Floor = "B1", Door = "ConcourseToPrivate", Area = "Private" },
}

-- Roof stair (L2 -> roof) in the Pro Floor's north-east corner, switchback.
Layout.RoofStair = { Shaft = R(40, 56, 52, 80), DoorX = 48, DoorZ = 52 } -- door on the shaft's south side (gate L38)

---------------------------------------------------------------------------
-- Lower level (Y = -22, 20 high)
---------------------------------------------------------------------------
Layout.B1 = {
	Concourse = R(-60, 60, -100, -10),
	Boxing = R(-150, -60, -100, 60),
	Private = R(-60, 60, -10, 60),
	Recovery = R(60, 150, -100, 60),
}

Layout.B1Doors = {
	ConcourseToBoxing = { X = -60, Z = -52, Width = 14, Height = 12, Wall = "NS" },
	ConcourseToRecovery = { X = 60, Z = -52, Width = 14, Height = 12, Wall = "NS" },
	ConcourseToPrivate = { X = 0, Z = -10, Width = 16, Height = 12, Wall = "EW" }, -- gate L21
} :: { [string]: Door }

---------------------------------------------------------------------------
-- Rooftop (Y = 54)
---------------------------------------------------------------------------
Layout.Roof = {
	Deck = R(-150, 150, -100, 100),
	-- 3-lane running track: rounded rectangle centred at (0, 0)
	TrackOuterHalf = Vector3.new(138, 0, 88), -- half extents (X, -, Z) of the outer edge
	TrackLaneWidth = 4,
	TrackLanes = 3,
	TrackCornerRadius = 36, -- outer corner radius
	Skylight = R(-30, 30, -62, -10), -- glass roof over the atrium (raised frame)
	ElevatorHouse = R(-54, -40, -54, -38),
	StairHouse = R(38, 58, 50, 82),
	EventStage = R(-36, 30, 44, 72),
}

---------------------------------------------------------------------------
-- Outdoor Yard (west of the building, Y = 0)
---------------------------------------------------------------------------
Layout.Yard = {
	Bounds = R(-440, -165, -140, 140),
	Gate = { X = -165, Z = -2, Width = 14 }, -- entrance gate (L12) on the Yard's east fence
	Path = R(-165, -150, -8, 4), -- concrete path from the building door to the gate
	TrackCenter = Vector3.new(-305, 0, 0),
	TrackStraight = 120, -- straight length along Z
	TrackInnerRadius = 44,
	TrackLanes = 3,
	TrackLaneWidth = 4,
	SprintLanes = R(-240, -216, -80, 64), -- 4 lanes x 6 wide, running north
	SprintStartZ = -70,
	SprintFinishZ = 30, -- 100 studs
	Obstacle = R(-340, -270, -50, 50), -- inside the track infield; start south, finish north
	Strongman = R(-430, -372, -70, 70),
}

---------------------------------------------------------------------------
-- Apex Lab annex (east, elevated at L2 level) and skybridge
---------------------------------------------------------------------------
Layout.Skybridge = R(150, 175, -6, 6) -- at Y = 28
Layout.Apex = { Rect = R(175, 265, -55, 55), Floor = 28, Ceiling = 54 }

---------------------------------------------------------------------------
-- Surroundings
---------------------------------------------------------------------------
Layout.Plaza = R(-150, 150, -150, -100) -- entrance plaza
Layout.Street = R(-700, 700, -200, -150)
Layout.CityBounds = R(-800, 760, -620, 560)

-- Spawn: inside the lobby facing north toward reception and the atrium.
Layout.Spawn = CFrame.new(0, 0.5, -90)

function Layout.door(floor: string, name: string): Door
	local t = if floor == "G" then Layout.GDoors elseif floor == "L2" then Layout.L2Doors else Layout.B1Doors
	local d = t[name]
	assert(d, "unknown door " .. floor .. "/" .. name)
	return d
end

function Layout.center(r: Rect, y: number): Vector3
	return Vector3.new((r.X0 + r.X1) / 2, y, (r.Z0 + r.Z1) / 2)
end

function Layout.size(r: Rect): (number, number)
	return r.X1 - r.X0, r.Z1 - r.Z0
end

function Layout.contains(r: Rect, x: number, z: number): boolean
	return x >= r.X0 and x <= r.X1 and z >= r.Z0 and z <= r.Z1
end

return Layout
