--!strict
-- Persists player settings (validated per key).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Util.Net)
local DataService = require(script.Parent.DataService)

local SettingsService = {}

local NUMBER_KEYS = { Music = true, Sfx = true, Ambience = true }
local BOOL_KEYS = { CameraShake = true, ReducedEffects = true, ShowCompanions = true, ShowNameplates = true }

function SettingsService.Init()
	Net.handle("Settings.Set", function(player, payload)
		if type(payload) ~= "table" or type(payload.Key) ~= "string" then
			return false, "bad payload"
		end
		local key, value = payload.Key, payload.Value
		if NUMBER_KEYS[key] and type(value) == "number" and value == value then
			DataService.set(player, { "Settings", key }, math.clamp(value, 0, 1))
			return true, nil
		elseif BOOL_KEYS[key] and type(value) == "boolean" then
			DataService.set(player, { "Settings", key }, value)
			return true, nil
		end
		return false, "unknown setting"
	end)
end

return SettingsService
