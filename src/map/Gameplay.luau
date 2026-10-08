--!strict
--[[
	Gameplay objects in the map: the contract between level design and runtime
	code. Runtime scripts find these by CollectionService tag + attributes, so
	keep names/attributes exactly as documented here and in docs/ARCHITECTURE.md.

	Tags (all created through the helpers below):
	  AreaZone          Part   AreaId, Ambience          (Map.Zones, always streamed)
	  AreaGate          Model  AreaId                     children: Door* (sliding leaves, attr SlideX), Barrier, SignPart
	  ElevatorStop      Part   Floor ("B1"|"G"|"L2"|"Roof") prompt "ElevatorPrompt"; child marker "Arrive"
	  EventSpot         Part   EventId, Role, Index
	  CourseCheckpoint  Part   CourseId ("Sprint"|"Obstacle"), Index (0 = start, last = finish)
	  LockerSlot        Part   Index (anchor for a player's locker decorations)
	  PhotoSpot         Part   prompt "PhotoPrompt"; child marker "CameraPoint"
	  LeaderboardBoard  Part   Board ("Power"|"Weekly"|"Trophies"|"Rebirths"|"Server"); front face shows the board
	  Scoreboard        Part   Board ("Arena"); front face shows live competition state
	  ShopCounter       Part   Shop ("JuiceBar"|"ProShop"|"Companions"|"Cosmetics"); prompt "ShopPrompt"
	  DuelTable         Model  TableId; children markers SeatA, SeatB (HRP targets), Grip (where hands meet)
	  NpcSpot           Part   ambient NPC idle/walk points (Role = "Idle"|"Spectate"|"Chat")
	  Station           Model  (see Equipment: StationType, Tier, StationId, AreaId)
]]

local Kit = require("./Kit")
local Layout = require("./Layout")

local Gameplay = {}

local BUILDER_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)

---------------------------------------------------------------------------
-- Area gates: sliding glass leaves in a slim frame + requirement sign.
---------------------------------------------------------------------------
function Gameplay.gate(parent: Instance, door: Layout.Door, floorY: number, areaId: string): Model
	-- door plane: for an "NS" wall the opening spans Z; the gate faces +X.
	local facing = if door.Wall == "NS" then CFrame.Angles(0, math.rad(90), 0) else CFrame.new()
	local base = CFrame.new(door.X, floorY, door.Z) * facing -- local X runs along the opening
	local w, h = door.Width, door.Height
	local model = Kit.model(parent, "Gate_" .. areaId, base)
	model:SetAttribute("AreaId", areaId)
	model:AddTag("AreaGate")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local frameF = "PowderGraphite"
	-- frame (posts + header) slightly inside the opening
	Kit.box(model, base * CFrame.new(-w / 2 + 0.25, h / 2, 0), Vector3.new(0.5, h, 1.4), frameF, { Collide = true })
	Kit.box(model, base * CFrame.new(w / 2 - 0.25, h / 2, 0), Vector3.new(0.5, h, 1.4), frameF, { Collide = true })
	local header = Kit.box(model, base * CFrame.new(0, h - 0.6, 0), Vector3.new(w, 1.2, 1.4), frameF, { Collide = true })
	header.Name = "Header"
	-- floor track
	Kit.box(model, base * CFrame.new(0, 0.04, 0), Vector3.new(w, 0.08, 1.2), "SteelBrushed", Kit.DETAIL)

	-- two glass leaves; client slides them (SlideX in local studs) when unlocked
	local leafW = (w - 1) / 2
	for i, side in { -1, 1 } do
		local leaf = Kit.box(
			model,
			base * CFrame.new(side * (leafW / 2), (h - 1.2) / 2, 0),
			Vector3.new(leafW, h - 1.3, 0.25),
			"GlassFrosted",
			{ Collide = true, Shadow = false }
		)
		leaf.Name = "Door" .. i
		leaf:SetAttribute("SlideX", side * (leafW - 0.3))
		-- brushed handle strip
		Kit.box(model, base * CFrame.new(side * 0.55, (h - 1.2) / 2, 0), Vector3.new(0.12, math.min(5, h - 3), 0.5), "SteelBrushed", Kit.DETAIL)
	end

	-- invisible barrier so you can't squeeze past while locked
	local barrier = Kit.marker(model, "Barrier", base * CFrame.new(0, h / 2, 0), Vector3.new(w, h, 1))
	barrier.CanCollide = true

	-- requirement sign on both sides of the header
	local sign = Kit.box(model, base * CFrame.new(0, h + 0.9, 0), Vector3.new(math.min(w, 12), 1.6, 0.3), "Ink", Kit.DETAIL)
	sign.Name = "SignPart"
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local sg = Kit.sign(sign, "LOCKED", {
			Face = face,
			Font = BUILDER_FONT,
			TextColor = Color3.fromRGB(242, 169, 59),
			PixelsPerStud = 50,
			LightInfluence = 0,
			Brightness = 1.4,
			Padding = 0.12,
		})
		sg.Name = "GateSign" .. face.Name
	end
	return model
end

function Gameplay.buildGates(parent: Instance)
	local folder = Kit.folder(parent, "Gates")
	for _, g in Layout.Gates do
		local door = Layout.door(g.Floor, g.Door)
		local y = (Layout.Y :: any)[g.Floor]
		Gameplay.gate(folder, door, y, g.Area)
	end
	-- Rooftop gate: the roof stair door on L2, and the Yard fence gate
	local rs = Layout.RoofStair
	Gameplay.gate(folder, { X = rs.DoorX, Z = rs.DoorZ, Width = 8, Height = 10, Wall = "EW" }, Layout.Y.L2, "Rooftop")
	local yg = Layout.Yard.Gate
	Gameplay.gate(folder, { X = yg.X, Z = yg.Z, Width = yg.Width, Height = 11, Wall = "NS" }, Layout.Y.G, "Yard")
end

---------------------------------------------------------------------------
-- Area zones (volumes)
---------------------------------------------------------------------------
local function zoneRect(parent: Instance, areaId: string, r: Layout.Rect, y0: number, y1: number)
	local cx, cz = (r.X0 + r.X1) / 2, (r.Z0 + r.Z1) / 2
	Kit.zone(parent, areaId, CFrame.new(cx, (y0 + y1) / 2, cz), Vector3.new(r.X1 - r.X0, y1 - y0, r.Z1 - r.Z0))
end

function Gameplay.buildZones(parent: Instance): Model
	local zones = Kit.model(parent, "Zones")
	zones.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local G, L2, B1 = Layout.G, Layout.L2, Layout.B1
	local yG, yL2, yB1, yR = Layout.Y.G, Layout.Y.L2, Layout.Y.B1, Layout.Y.ROOF
	zoneRect(zones, "Lobby", G.Lobby, yG - 1, yL2 - 1)
	zoneRect(zones, "Beginner", G.Beginner, yG - 1, yL2 - 2)
	zoneRect(zones, "Lobby", G.WestCorridor, yG - 1, yL2 - 2)
	zoneRect(zones, "FreeWeights", G.FreeWeights, yG - 1, yL2 - 2)
	zoneRect(zones, "Cables", G.Cables, yG - 1, yL2 - 2)
	zoneRect(zones, "MainHall", G.MainHall, yG - 1, yL2 - 2)
	zoneRect(zones, "Lounge", G.Lounge, yG - 1, yL2 - 2)
	zoneRect(zones, "Lockers", G.EastCorridor, yG - 1, yL2 - 2)
	zoneRect(zones, "Lockers", G.LockersA, yG - 1, yL2 - 2)
	zoneRect(zones, "Lockers", G.LockersB, yG - 1, yL2 - 2)
	zoneRect(zones, "Cardio", G.Cardio, yG - 1, yL2 - 2)
	zoneRect(zones, "Mezzanine", L2.Mezzanine, yL2 - 1, yR - 2)
	zoneRect(zones, "Mezzanine", L2.Hallway, yL2 - 1, yR - 2)
	zoneRect(zones, "ProFloor", L2.ProFloor, yL2 - 1, yR - 2)
	zoneRect(zones, "Foundry", L2.Foundry, yL2 - 1, yR - 2)
	zoneRect(zones, "Arena", L2.EastHall, yL2 - 1, yR - 2)
	zoneRect(zones, "VIP", L2.VIP, yL2 - 1, yR - 2)
	zoneRect(zones, "Arena", L2.Arena, yL2 - 1, yR - 2)
	zoneRect(zones, "Concourse", B1.Concourse, yB1 - 1, yG - 2)
	zoneRect(zones, "Boxing", B1.Boxing, yB1 - 1, yG - 2)
	zoneRect(zones, "Private", B1.Private, yB1 - 1, yG - 2)
	zoneRect(zones, "Recovery", B1.Recovery, yB1 - 1, yG - 2)
	zoneRect(zones, "Rooftop", Layout.Roof.Deck, yR - 1, yR + 40)
	zoneRect(zones, "Apex", Layout.Apex.Rect, Layout.Apex.Floor - 1, Layout.Apex.Ceiling)
	zoneRect(zones, "Apex", Layout.Skybridge, Layout.Y.L2 - 1, Layout.Y.L2 + 14)
	zoneRect(zones, "Yard", Layout.Yard.Bounds, yG - 4, yG + 60)
	return zones
end

---------------------------------------------------------------------------
-- Elevator stops, spawn
---------------------------------------------------------------------------
function Gameplay.buildElevatorStops(parent: Instance)
	local e = Layout.Elevator
	local folder = Kit.folder(parent, "Elevator")
	local floors: { { name: string, y: number } } = {
		{ name = "B1", y = Layout.Y.B1 },
		{ name = "G", y = Layout.Y.G },
		{ name = "L2", y = Layout.Y.L2 },
		{ name = "Roof", y = Layout.Y.ROOF },
	}
	for _, f in floors do
		local name, y = f.name, f.y
		-- call panel on the wall beside the doors (east face of the shaft)
		local panel = Kit.box(folder, CFrame.new(e.DoorX + 0.35, y + 4.2, e.DoorZ - e.DoorWidth / 2 - 1.4), Vector3.new(0.3, 2.2, 1.1), "SteelBrushed", Kit.DETAIL)
		panel.Name = "ElevatorStop_" .. name
		panel:SetAttribute("Floor", name)
		panel:AddTag("ElevatorStop")
		Kit.box(folder, CFrame.new(e.DoorX + 0.52, y + 4.6, e.DoorZ - e.DoorWidth / 2 - 1.4), Vector3.new(0.05, 0.36, 0.36), "LightAmber", Kit.DETAIL)
		Kit.prompt(panel, "Call Elevator", "Floor " .. name, { MaxDistance = 10 })
		local pp = panel:FindFirstChildOfClass("ProximityPrompt")
		if pp then
			pp.Name = "ElevatorPrompt"
		end
		-- where riders arrive (just outside the doors, facing east)
		local arrive = Kit.marker(panel, "Arrive", CFrame.new(e.DoorX + 4, y + 3, e.DoorZ) * CFrame.Angles(0, math.rad(-90), 0))
		arrive.Parent = panel
	end
end

function Gameplay.buildSpawn(parent: Instance)
	local s = Instance.new("SpawnLocation")
	s.Name = "LobbySpawn"
	s.Anchored = true
	s.Size = Vector3.new(10, 0.2, 10)
	s.CFrame = Layout.Spawn
	s.Transparency = 1
	s.CanCollide = false
	s.CanQuery = false
	s.CanTouch = true
	s.Neutral = true
	s.Duration = 0
	s.Parent = parent
end

---------------------------------------------------------------------------
-- Helpers for dressing modules
---------------------------------------------------------------------------
function Gameplay.eventSpot(parent: Instance, eventId: string, role: string, index: number, cf: CFrame, size: Vector3?): Part
	local p = Kit.marker(parent, `Event_{eventId}_{role}{index}`, cf, size or Vector3.new(4, 1, 4))
	Kit.attrs(p, { EventId = eventId, Role = role, Index = index })
	p:AddTag("EventSpot")
	return p
end

function Gameplay.checkpoint(parent: Instance, courseId: string, index: number, cf: CFrame, size: Vector3): Part
	local p = Kit.marker(parent, `Checkpoint_{courseId}_{index}`, cf, size)
	Kit.attrs(p, { CourseId = courseId, Index = index })
	p:AddTag("CourseCheckpoint")
	return p
end

function Gameplay.lockerSlot(parent: Instance, index: number, cf: CFrame): Part
	local p = Kit.marker(parent, "LockerSlot" .. index, cf, Vector3.new(2, 2, 1))
	p:SetAttribute("Index", index)
	p:AddTag("LockerSlot")
	return p
end

-- cf: where the player stands (facing the camera point). cameraCf: camera pose.
function Gameplay.photoSpot(parent: Instance, cf: CFrame, cameraCf: CFrame): Part
	local p = Kit.marker(parent, "PhotoSpot", cf, Vector3.new(6, 1, 6))
	p:AddTag("PhotoSpot")
	Kit.marker(p, "CameraPoint", cameraCf)
	local pp = Kit.prompt(p, "Photo Mode", "Selfie Wall", { MaxDistance = 10 })
	pp.Name = "PhotoPrompt"
	return p
end

-- A physical leaderboard: dark panel whose Front face is drawn by the runtime.
function Gameplay.board(parent: Instance, boardId: string, cf: CFrame, size: Vector3): Part
	local p = Kit.box(parent, cf, size, "Ink", { Collide = true })
	p.Name = "Board_" .. boardId
	p:SetAttribute("Board", boardId)
	p:AddTag("LeaderboardBoard")
	return p
end

function Gameplay.scoreboard(parent: Instance, boardId: string, cf: CFrame, size: Vector3): Part
	local p = Kit.box(parent, cf, size, "Ink", { Collide = false })
	p.Name = "Scoreboard_" .. boardId
	p:SetAttribute("Board", boardId)
	p:AddTag("Scoreboard")
	return p
end

function Gameplay.shopCounter(parent: Instance, shopId: string, part: BasePart, objectText: string): ProximityPrompt
	part:SetAttribute("Shop", shopId)
	part:AddTag("ShopCounter")
	local pp = Kit.prompt(part, "Browse", objectText, { MaxDistance = 10 })
	pp.Name = "ShopPrompt"
	local _ = parent
	return pp
end

function Gameplay.npcSpot(parent: Instance, role: string, cf: CFrame): Part
	local p = Kit.marker(parent, "NpcSpot", cf)
	p:SetAttribute("Role", role)
	p:AddTag("NpcSpot")
	return p
end

return Gameplay
