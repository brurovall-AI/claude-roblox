--!strict
--[[
	CharacterService: makes progression visible on the character.
	  - walk speed / jump height from Speed / Agility (with temporary overrides)
	  - muscle size from Strength (BodyWidth/DepthScale on R15 rigs)
	  - player attributes read by every client for nameplates and social UI:
	      Level, Rank, RankName, Power, Rebirths, Title, Aura, Companions (csv)
	  - gear visuals (GearVisuals.apply) whenever equipment changes
	  - players don't collide with each other (crowded gyms, no machine blocking)

	Overrides: other services temporarily lock movement, e.g. while training:
	  CharacterService.setOverride(player, "Training", { WalkSpeed = 0, JumpHeight = 0 })
	  CharacterService.clearOverride(player, "Training")
	The most recently set override wins per property.
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local Cosmetics = require(Config.Cosmetics)
local Progression = require(Config.Progression)

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local GearVisuals = require(script.Parent.Parent.Visuals.GearVisuals)

local CharacterService = {}
CharacterService.Priority = 20

export type Override = { WalkSpeed: number?, JumpHeight: number? }

local overrides: { [Player]: { { key: string, value: Override } } } = {}
local PLAYER_GROUP = "Players"

local function humanoidOf(player: Player): Humanoid?
	local char = player.Character
	if not char then
		return nil
	end
	return char:FindFirstChildOfClass("Humanoid") :: Humanoid?
end

local function resolved(player: Player, prop: string, base: number): number
	local list = overrides[player]
	if list then
		for i = #list, 1, -1 do
			local v = (list[i].value :: any)[prop]
			if v ~= nil then
				return v
			end
		end
	end
	return base
end

local function applyMovement(player: Player)
	local data = DataService.get(player)
	local hum = humanoidOf(player)
	if not data or not hum then
		return
	end
	hum.UseJumpPower = false
	hum.WalkSpeed = resolved(player, "WalkSpeed", Progression.walkSpeed(data.Stats.Speed))
	hum.JumpHeight = resolved(player, "JumpHeight", Progression.jumpHeight(data.Stats.Agility))
end

local function applyMuscle(player: Player)
	local data = DataService.get(player)
	local hum = humanoidOf(player)
	if not data or not hum or hum.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	local mult = math.floor(Progression.muscleScale(data.Stats.Strength) * 100 + 0.5) / 100
	if hum:GetAttribute("MuscleMult") == mult then
		return
	end
	hum:SetAttribute("MuscleMult", mult)
	for _, name in { "BodyWidthScale", "BodyDepthScale" } do
		local v = hum:FindFirstChild(name)
		if v and v:IsA("NumberValue") then
			local nv = v :: NumberValue
			local baseKey = "Base" .. name
			local base = hum:GetAttribute(baseKey)
			if type(base) ~= "number" then
				base = nv.Value
				hum:SetAttribute(baseKey, base)
			end
			nv.Value = (base :: number) * mult
		end
	end
end

local function applyAttributes(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local rank = ProgressionService.rank(player)
	player:SetAttribute("Level", data.Level)
	player:SetAttribute("Rank", rank.Index)
	player:SetAttribute("RankName", rank.Name)
	player:SetAttribute("Power", math.floor(ProgressionService.power(player)))
	player:SetAttribute("Rebirths", data.Rebirths)
	local title = Cosmetics.Titles[data.Equipped.Title]
	player:SetAttribute("Title", if title then data.Equipped.Title else "")
	player:SetAttribute("Aura", data.Equipped.Aura)
	player:SetAttribute("Companions", table.concat(data.Equipped.Companions, ","))
end

local function applyGear(player: Player)
	local data = DataService.get(player)
	local char = player.Character
	if not data or not char then
		return
	end
	local ok, err = pcall(GearVisuals.apply, char, data.Equipped.Gear)
	if not ok then
		warn("[CharacterService] gear visuals failed: " .. tostring(err))
	end
end

function CharacterService.refresh(player: Player)
	applyMovement(player)
	applyMuscle(player)
	applyAttributes(player)
end

function CharacterService.setOverride(player: Player, key: string, value: Override)
	local list = overrides[player]
	if not list then
		list = {}
		overrides[player] = list
	end
	for i = #list, 1, -1 do
		if list[i].key == key then
			table.remove(list, i)
		end
	end
	table.insert(list, { key = key, value = value })
	applyMovement(player)
end

function CharacterService.clearOverride(player: Player, key: string)
	local list = overrides[player]
	if not list then
		return
	end
	for i = #list, 1, -1 do
		if list[i].key == key then
			table.remove(list, i)
		end
	end
	applyMovement(player)
end

local function setCollisionGroup(char: Model)
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") then
			(d :: BasePart).CollisionGroup = PLAYER_GROUP
		end
	end
	char.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			(d :: BasePart).CollisionGroup = PLAYER_GROUP
		end
	end)
end

local function onCharacter(player: Player, char: Model)
	setCollisionGroup(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then
		return
	end
	if not DataService.waitFor(player, 30) then
		return
	end
	if player.Character ~= char then
		return
	end
	-- give R15 scale values a moment to be created by the avatar loader
	task.wait(0.5)
	CharacterService.refresh(player)
	applyGear(player)
end

function CharacterService.Init()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(PLAYER_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, PLAYER_GROUP, false)
end

function CharacterService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		overrides[p] = nil
	end)

	DataService.Loaded:Connect(function(player)
		applyAttributes(player)
	end)
	ProgressionService.StatsChanged:Connect(CharacterService.refresh)
	ProgressionService.LevelChanged:Connect(function(player)
		applyAttributes(player)
	end)

	-- equipment / cosmetic changes
	local queued: { [Player]: boolean } = {}
	DataService.Changed:Connect(function(player, path)
		if path[1] ~= "Equipped" or queued[player] then
			return
		end
		queued[player] = true
		task.defer(function()
			queued[player] = nil
			applyAttributes(player)
			if path[2] == nil or path[2] == "Gear" then
				applyGear(player)
			end
		end)
	end)
end

return CharacterService
