--!strict
--[[
	EmoteService: server-authoritative emotes. The client asks, the server
	validates and publishes character attributes that every client animates
	(src/client/Controllers/AnimationController):

	  Emote       emote id (Config/Cosmetics.Emotes)
	  EmoteStamp  server time of the play; changes on every play so the same
	              emote can be replayed back-to-back

	Requests:
	  "Emote.Play" { Id }  owned + equipped + alive + not training/busy
	  "Emote.Stop"
	One-shot emotes clear themselves after ONESHOT_SECONDS; looping emotes run
	until stopped, the character moves away, trains, dies or respawns.

	API: EmoteService.isEmoting(player), EmoteService.stop(player)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared.Config.Cosmetics)
local Net = require(Shared.Util.Net)

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local Events = require(script.Parent.Parent.Core.Events)

local EmoteService = {}
EmoteService.Priority = 55

local ONESHOT_SECONDS = 3.4 -- matches the client one-shot programs (~3.2 s)
local MOVE_STOP_SPEED = 7 -- studs/s of horizontal speed that ends a looping emote
local MOVE_STOP_TICKS = 2 -- consecutive 0.5 s checks above that speed

local moving: { [Player]: number } = {}

local function aliveCharacter(player: Player): (Model?, Humanoid?)
	local char = player.Character
	if not char or not char.Parent then
		return nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if not hum or hum.Health <= 0 then
		return nil, nil
	end
	return char, hum
end

function EmoteService.isEmoting(player: Player): boolean
	local char = player.Character
	return char ~= nil and char:GetAttribute("Emote") ~= nil
end

function EmoteService.stop(player: Player)
	local char = player.Character
	if char and char:GetAttribute("Emote") ~= nil then
		char:SetAttribute("Emote", nil)
		char:SetAttribute("EmoteStamp", nil)
	end
	moving[player] = nil
end

local function play(player: Player, payload: any): (boolean, any)
	if not Net.allow(player, "Emote", 1.5, 3) then
		return false, "Slow down!"
	end
	if type(payload) ~= "table" or type(payload.Id) ~= "string" or #payload.Id > 40 then
		return false, "bad payload"
	end
	local id: string = payload.Id
	local def = Cosmetics.Emotes[id]
	if not def then
		return false, "Unknown emote"
	end
	local data = DataService.get(player)
	if not data then
		return false, "Still loading"
	end
	if not data.Owned.Emotes[id] or not table.find(data.Equipped.Emotes, id) then
		return false, "Equip this emote first"
	end
	local char = aliveCharacter(player)
	if not char then
		return false, "Not now"
	end
	if player:GetAttribute("Training") ~= nil or char:GetAttribute("TrainingPose") ~= nil then
		return false, "Finish your set first"
	end
	if player:GetAttribute("Busy") then
		return false, "Not right now"
	end

	local stamp = Workspace:GetServerTimeNow()
	char:SetAttribute("Emote", id)
	char:SetAttribute("EmoteStamp", stamp)
	moving[player] = 0
	ProgressionService.count(player, "EmotesUsed", 1)
	Events.fire(player, "EmoteUsed", 1, { Id = id })

	if not def.Loop then
		task.delay(ONESHOT_SECONDS, function()
			-- only clear if this exact play is still running
			if char.Parent and char:GetAttribute("EmoteStamp") == stamp then
				char:SetAttribute("Emote", nil)
				char:SetAttribute("EmoteStamp", nil)
			end
		end)
	end
	return true, { Id = id, Stamp = stamp }
end

function EmoteService.Init()
	Net.handle("Emote.Play", play)
	Net.handle("Emote.Stop", function(player: Player)
		if not Net.allow(player, "EmoteStop", 4, 6) then
			return false, "Slow down!"
		end
		EmoteService.stop(player)
		return true, nil
	end)
end

function EmoteService.Start()
	local function onCharacter(player: Player, char: Model)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum and hum:IsA("Humanoid") then
			(hum :: Humanoid).Died:Connect(function()
				if player.Character == char then
					EmoteService.stop(player)
				end
			end)
		end
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(char)
			moving[player] = nil
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
		moving[p] = nil
	end)

	-- Backup for the client's auto-stop: looping emotes end once the character
	-- clearly walks away (a slow drift or a shove does not count).
	while true do
		task.wait(0.5)
		for player, ticks in moving do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not char or not root or char:GetAttribute("Emote") == nil then
				moving[player] = nil
				continue
			end
			local def = Cosmetics.Emotes[char:GetAttribute("Emote") :: string]
			if not def or not def.Loop then
				continue
			end
			local v = root.AssemblyLinearVelocity
			if Vector3.new(v.X, 0, v.Z).Magnitude > MOVE_STOP_SPEED then
				ticks += 1
				if ticks >= MOVE_STOP_TICKS then
					EmoteService.stop(player)
					continue
				end
			else
				ticks = 0
			end
			moving[player] = ticks
		end
	end
end

return EmoteService
