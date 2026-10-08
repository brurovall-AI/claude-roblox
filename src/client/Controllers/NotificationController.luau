--!strict
--[[
	NotificationController: toasts and celebration banners.

		NotificationController.toast("Not enough cash", "You need $2,000 more.", "Error")
		NotificationController.banner({ Title = "LEVEL 12", Subtitle = "...", Color = ..., Sound = "LevelUp" })

	Listens to the server "Toast" remote and GameEvents: LevelUp, RankUp,
	Reward, Rebirth, PlayerRankUp (others, small toast).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local Areas = require(Config.Areas)
local Net = require(Shared.Util.Net)
local Players = game:GetService("Players")
local Progression = require(Config.Progression)
local Ranks = require(Config.Ranks)
local Tiers = require(Config.Tiers)

local UI = script.Parent.Parent.UI
local C = require(UI.Components)
local New = require(UI.Create)
local Theme = require(UI.Theme)

local GameEvents = require(script.Parent.Parent.Core.GameEvents)
local AudioController = require(script.Parent.AudioController)
local UIController = require(script.Parent.UIController)

local NotificationController = {}
NotificationController.Priority = 8

local KIND_COLOR = {
	Info = Theme.Color.Info,
	Success = Theme.Color.Success,
	Warning = Theme.Color.Warning,
	Error = Theme.Color.Danger,
	Reward = Theme.Color.Accent,
}
local KIND_ICON = { Info = "info", Success = "check", Warning = "info", Error = "close", Reward = "star" }

local toastHolder: Frame
local bannerHolder: Frame
local bannerQueue: { { [string]: any } } = {}
local bannerBusy = false

function NotificationController.toast(title: string, text: string?, kind: string?)
	local k = kind or "Info"
	local color = KIND_COLOR[k] or Theme.Color.Info
	local card = C.frame({
		Parent = toastHolder,
		Name = "Toast",
		Size = UDim2.fromOffset(340, 0),
		AutoSize = Enum.AutomaticSize.Y,
		Color = Theme.Color.Surface0,
		Transparency = 0.06,
		Radius = Theme.Radius.Medium,
		LayoutOrder = -math.floor(os.clock() * 100),
	})
	C.stroke(card)
	C.padding(card, 10, 14, 10, 12)
	local scale = New("UIScale", { Scale = 0.9, Parent = card })
	C.iconBadge({ Parent = card, Icon = KIND_ICON[k] or "info", Color = color, Size = 28, Position = UDim2.fromOffset(0, 0) })
	local textCol = C.frame({ Parent = card, Size = UDim2.new(1, -40, 0, 0), Position = UDim2.fromOffset(40, 0), AutoSize = Enum.AutomaticSize.Y })
	C.list(textCol, "V", 2)
	C.label({ Parent = textCol, Text = title, Font = Theme.Font.Bold, TextSize = Theme.TextSize.Body, LayoutOrder = 1, Wrap = true, AutoSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 18) })
	if text and text ~= "" then
		C.label({ Parent = textCol, Text = text, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextDim, LayoutOrder = 2, Wrap = true, AutoSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 16) })
	end
	C.tween(scale, Theme.Tween.Spring, { Scale = 1 })
	if k == "Error" then
		AudioController.play("UIError")
	elseif k ~= "Reward" then
		AudioController.play("UINotify")
	end
	-- keep at most 3
	local toasts: { Frame } = {}
	for _, ch in toastHolder:GetChildren() do
		if ch:IsA("Frame") then
			table.insert(toasts, ch :: Frame)
		end
	end
	if #toasts > 3 then
		table.sort(toasts, function(a: Frame, b: Frame)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i = 4, #toasts do
			toasts[i]:Destroy()
		end
	end
	task.delay(if text and #text > 60 then 6 else 3.6, function()
		if card.Parent then
			C.tween(scale, Theme.Tween.Fast, { Scale = 0.85 })
			task.delay(0.12, function()
				card:Destroy()
			end)
		end
	end)
end

local function showBanner(b: { [string]: any })
	bannerBusy = true
	local color: Color3 = b.Color or Theme.Color.Accent
	local holder = C.frame({ Parent = bannerHolder, Size = UDim2.fromOffset(560, 150), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0) })
	local scale = New("UIScale", { Scale = 0.7, Parent = holder })
	-- glow line
	local line = C.frame({ Parent = holder, Size = UDim2.new(0, 0, 0, 2), Position = UDim2.new(0.5, 0, 0, 92), AnchorPoint = Vector2.new(0.5, 0), Color = color, Transparency = 0 })
	New("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = line,
	})
	local kicker = C.label({ Parent = holder, Text = b.Kicker or "", Font = Theme.Font.Bold, TextSize = Theme.TextSize.Caption, Color = color, XAlign = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 18), TextTransparency = 1 })
	local title = C.label({
		Parent = holder,
		Text = b.Title or "",
		Font = Theme.Font.Heavy,
		TextSize = Theme.TextSize.Display,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 48),
		Position = UDim2.fromOffset(0, 22),
		TextTransparency = 1,
	})
	New("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.6, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = title })
	local sub = C.label({
		Parent = holder,
		Text = b.Subtitle or "",
		Font = Theme.Font.SemiBold,
		TextSize = Theme.TextSize.Body,
		Color = Theme.Color.Text,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 100),
		Wrap = true,
		TextTransparency = 1,
	})
	New("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.7, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = sub })
	if b.Sound then
		AudioController.play(b.Sound)
	end
	C.tween(scale, Theme.Tween.Spring, { Scale = 1 })
	C.tween(kicker, Theme.Tween.Base, { TextTransparency = 0 })
	C.tween(title, Theme.Tween.Base, { TextTransparency = 0 })
	C.tween(sub, Theme.Tween.Slow, { TextTransparency = 0.05 })
	C.tween(line, Theme.Tween.Slow, { Size = UDim2.new(0.9, 0, 0, 2) })
	task.wait(b.Duration or 2.8)
	C.tween(scale, Theme.Tween.Base, { Scale = 0.92 })
	for _, l in { kicker, title, sub } do
		C.tween(l, Theme.Tween.Base, { TextTransparency = 1 })
	end
	C.tween(line, Theme.Tween.Base, { BackgroundTransparency = 1 })
	task.wait(0.25)
	holder:Destroy()
	bannerBusy = false
	local nextBanner = table.remove(bannerQueue, 1)
	if nextBanner then
		task.spawn(showBanner, nextBanner)
	end
end

function NotificationController.banner(b: { [string]: any })
	if bannerBusy then
		table.insert(bannerQueue, b)
		return
	end
	task.spawn(showBanner, b)
end

-- What becomes available at a given level (areas + equipment tiers).
local function unlocksAt(level: number): { string }
	local out = {}
	for _, a in Areas.sorted() do
		if a.Access == "Level" and a.LevelReq == level then
			table.insert(out, a.Name)
		end
	end
	for _, t in Tiers.List do
		if t.LevelReq == level and level > 1 then
			table.insert(out, t.Name .. " equipment")
		end
	end
	return out
end

function NotificationController.Init()
	local hudTop = UIController.hud.Top
	toastHolder = C.frame({ Parent = UIController.hud.Overlay, Name = "Toasts", Size = UDim2.fromOffset(340, 300), Position = UDim2.new(0.5, 0, 0, 110), AnchorPoint = Vector2.new(0.5, 0) })
	C.list(toastHolder, "V", 8, Enum.HorizontalAlignment.Center)
	bannerHolder = C.frame({ Parent = UIController.hud.Overlay, Name = "Banners", Size = UDim2.fromOffset(560, 160), Position = UDim2.new(0.5, 0, 0.16, 0), AnchorPoint = Vector2.new(0.5, 0) })
	local _ = hudTop

	Net.event("Toast").OnClientEvent:Connect(function(t: any)
		if type(t) == "table" then
			NotificationController.toast(tostring(t.Title or ""), tostring(t.Text or ""), t.Kind)
		end
	end)

	GameEvents.on("LevelUp", function(p)
		local level = tonumber(p.Level) or 1
		local unlocks = unlocksAt(level)
		NotificationController.banner({
			Kicker = "LEVEL UP",
			Title = "LEVEL " .. level,
			Subtitle = if #unlocks > 0 then "Unlocked: " .. table.concat(unlocks, " · ") else `Next level in {Progression.xpToNext(level)} XP`,
			Color = Theme.Color.Accent,
			Sound = "LevelUp",
		})
	end)
	GameEvents.on("RankUp", function(p)
		local rank = Ranks.List[tonumber(p.Rank) or 1]
		if rank then
			NotificationController.banner({
				Kicker = "NEW RANK",
				Title = string.upper(rank.Name),
				Subtitle = "Your rank now shows above your head.",
				Color = rank.Color,
				Sound = "RankUp",
				Duration = 3.2,
			})
		end
	end)
	GameEvents.on("Rebirth", function(p)
		NotificationController.banner({
			Kicker = "REBIRTH " .. tostring(p.Rebirths or 1),
			Title = "REBORN",
			Subtitle = string.format("Permanent gain multiplier: x%.2f", tonumber(p.Mult) or 1),
			Color = Theme.Color.Token,
			Sound = "RankUp",
			Duration = 3.5,
		})
	end)
	GameEvents.on("Reward", function(p)
		local items = p.Items
		if type(items) == "table" and #items > 0 then
			AudioController.play("Reward")
			NotificationController.toast(tostring(p.Source or "Reward"), table.concat(items, "  ·  "), "Reward")
		end
	end)
	GameEvents.on("PlayerRankUp", function(p)
		local who = Players:GetPlayerByUserId(tonumber(p.UserId) or 0)
		if who then
			NotificationController.toast(`{who.DisplayName} ranked up!`, `Now {p.Name}`, "Info")
		end
	end)
end

return NotificationController
