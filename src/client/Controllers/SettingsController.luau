--!strict
-- Settings window: audio mix, comfort and performance options.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Util.Net)

local UI = script.Parent.Parent.UI
local C = require(UI.Components)
local Theme = require(UI.Theme)

local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)

local SettingsController = {}

local function save(key: string, value: any)
	task.spawn(Net.request, "Settings.Set", { Key = key, Value = value })
end

local function row(parent: Instance, order: number, title: string, desc: string): Frame
	local card = C.card({ Parent = parent, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 62), Padding = 12 })
	C.label({ Parent = card, Text = title, Font = Theme.Font.Bold, Size = UDim2.new(0.55, 0, 0, 20) })
	C.label({ Parent = card, Text = desc, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextDim, Size = UDim2.new(0.55, 0, 0, 16), Position = UDim2.fromOffset(0, 20), Wrap = true })
	local right = C.frame({ Parent = card, Name = "Control", Size = UDim2.new(0.42, 0, 1, 0), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0) })
	return right
end

local function build(body: Frame)
	local list = C.scroll({ Parent = body, Gap = 8 })
	local s = DataController.data.Settings

	C.label({ Parent = list, LayoutOrder = 1, Text = "AUDIO", Font = Theme.Font.Heavy, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextMute })
	local sliders: { { key: string, title: string, desc: string } } = {
		{ key = "Music", title = "Music", desc = "Background tracks" },
		{ key = "Sfx", title = "Effects", desc = "Training, UI and world sounds" },
		{ key = "Ambience", title = "Ambience", desc = "Gym atmosphere per area" },
	}
	for i, d in sliders do
		local ctrl = row(list, 1 + i, d.title, d.desc)
		C.slider({
			Parent = ctrl,
			Size = UDim2.new(1, 0, 1, 0),
			Value = (s :: any)[d.key],
			OnRelease = function(v: number)
				save(d.key, v)
			end,
		})
	end

	C.label({ Parent = list, LayoutOrder = 10, Text = "COMFORT & PERFORMANCE", Font = Theme.Font.Heavy, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextMute })
	local toggles: { { key: string, title: string, desc: string } } = {
		{ key = "CameraShake", title = "Camera shake", desc = "Impact punch on heavy reps" },
		{ key = "ReducedEffects", title = "Reduced effects", desc = "Fewer particles and no blur (faster on mobile)" },
		{ key = "ShowCompanions", title = "Show companions", desc = "Display other players' companions" },
		{ key = "ShowNameplates", title = "Show nameplates", desc = "Names, ranks and titles above players" },
	}
	for i, d in toggles do
		local ctrl = row(list, 10 + i, d.title, d.desc)
		local t = C.toggle({
			Parent = ctrl,
			Value = (s :: any)[d.key],
			OnChange = function(v: boolean)
				save(d.key, v)
			end,
		})
		t.Frame.AnchorPoint = Vector2.new(1, 0.5)
		t.Frame.Position = UDim2.fromScale(1, 0.5)
	end
end

function SettingsController.Start()
	DataController.ready()
	UIController.registerWindow("Settings", { Title = "Settings", Icon = "settings", Width = 560, Height = 520, Build = build })
end

return SettingsController
