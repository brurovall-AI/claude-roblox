--!strict
--[[
	AudioController: one place to play every sound (Config/Audio keys).

		AudioController.play("UIClick")                         -- 2D
		AudioController.play("Barbell", { At = part })          -- 3D at a part/attachment
		AudioController.play("Drop", { Position = Vector3.new(...) })
		AudioController.play("RepPerfect", { Pitch = 1.1, Volume = 0.5 })  -- multipliers

	Sounds are routed to SoundGroups (Music / Sfx / Ambience / UI) whose volumes
	follow the player's settings. Zone ambience + music live in AmbienceController.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared.Config.Audio)

local DataController = require(script.Parent.DataController)
local C = require(script.Parent.Parent.UI.Components)

local AudioController = {}
AudioController.Priority = 2

export type PlayOpts = {
	At: Instance?, -- BasePart or Attachment for 3D sound
	Position: Vector3?,
	Volume: number?, -- multiplier
	Pitch: number?, -- multiplier
	Group: string?, -- override SoundGroup ("Sfx" default, UI keys use "UI")
	Looped: boolean?,
}

AudioController.groups = {} :: { [string]: SoundGroup }

local active = 0
local MAX_ONESHOTS = 28
local anchorFolder: Folder

local function group(name: string): SoundGroup
	local g = AudioController.groups[name]
	if g then
		return g
	end
	local sg = Instance.new("SoundGroup")
	sg.Name = "Ironhaven" .. name
	sg.Volume = 0.6
	sg.Parent = SoundService
	AudioController.groups[name] = sg
	return sg
end

function AudioController.play(key: string, opts: PlayOpts?): Sound?
	local def = Audio.Sfx[key]
	if not def or #def.Ids == 0 then
		return nil
	end
	local o: PlayOpts = opts or {}
	if active >= MAX_ONESHOTS and not o.Looped then
		return nil
	end
	local id = def.Ids[math.random(1, #def.Ids)]
	if id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = key
	s.SoundId = id
	local jitter = 1 + (math.random() * 2 - 1) * def.Jitter
	s.PlaybackSpeed = def.Pitch * jitter * (o.Pitch or 1)
	s.Volume = def.Volume * (o.Volume or 1)
	s.Looped = o.Looped == true
	local isUI = string.sub(key, 1, 2) == "UI"
	s.SoundGroup = group(o.Group or (if isUI then "UI" else "Sfx"))

	local parent: Instance
	if o.At then
		parent = o.At
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 6
		s.RollOffMaxDistance = def.Rolloff or 60
	elseif o.Position then
		local att = Instance.new("Attachment")
		att.Parent = Workspace.Terrain
		att.WorldPosition = o.Position
		parent = att
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 6
		s.RollOffMaxDistance = def.Rolloff or 60
		s.Ended:Once(function()
			att:Destroy()
		end)
	else
		parent = anchorFolder
	end
	s.Parent = parent
	if not s.Looped then
		active += 1
		local done = false
		local function finish()
			if done then
				return
			end
			done = true
			active -= 1
			s:Destroy()
		end
		s.Ended:Once(finish)
		-- sounds that fail to load never fire Ended
		task.delay(12, finish)
	end
	s:Play()
	return s
end

local function applyVolumes(settings: any)
	if type(settings) ~= "table" then
		return
	end
	group("Music").Volume = (settings.Music or 0.45) * 0.8
	group("Ambience").Volume = (settings.Ambience or 0.6) * 0.9
	group("Sfx").Volume = (settings.Sfx or 0.8)
	group("UI").Volume = (settings.Sfx or 0.8) * 0.9
end

function AudioController.Init()
	anchorFolder = Instance.new("Folder")
	anchorFolder.Name = "IronhavenSounds2D"
	anchorFolder.Parent = SoundService
	for _, name in { "Music", "Ambience", "Sfx", "UI" } do
		group(name)
	end
	local lastHover = 0
	C.setSounds(function()
		AudioController.play("UIClick")
	end, function()
		local now = os.clock()
		if now - lastHover > 0.06 then
			lastHover = now
			AudioController.play("UIHover")
		end
	end)
end

function AudioController.Start()
	DataController.observe("Settings", applyVolumes)
end

return AudioController
