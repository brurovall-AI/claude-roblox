--!strict
--[[
	Server -> client feedback.
	  Notify.toast(player, "Purchased", "Pro Lifting Gloves", "Success")
	  Notify.event(player, "LevelUp", { Level = 12 })      -- big moments, handled by client controllers
	  Notify.all("EventStarting", { ... })
	Toast kinds: "Info" | "Success" | "Warning" | "Error" | "Reward"
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Util.Net)

local toastRemote = Net.event("Toast")
local eventRemote = Net.event("GameEvent")

local Notify = {}

export type ToastKind = "Info" | "Success" | "Warning" | "Error" | "Reward"

function Notify.toast(player: Player, title: string, text: string?, kind: ToastKind?)
	toastRemote:FireClient(player, { Title = title, Text = text or "", Kind = kind or "Info" })
end

function Notify.toastAll(title: string, text: string?, kind: ToastKind?)
	toastRemote:FireAllClients({ Title = title, Text = text or "", Kind = kind or "Info" })
end

function Notify.event(player: Player, name: string, payload: { [string]: any }?)
	eventRemote:FireClient(player, name, payload or {})
end

function Notify.all(name: string, payload: { [string]: any }?)
	eventRemote:FireAllClients(name, payload or {})
end

function Notify.others(except: Player, name: string, payload: { [string]: any }?)
	for _, p in Players:GetPlayers() do
		if p ~= except then
			eventRemote:FireClient(p, name, payload or {})
		end
	end
end

return Notify
