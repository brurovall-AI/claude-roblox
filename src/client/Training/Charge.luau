--!strict
--[[
	Charge: hold to build power, release while the gauge is inside the window.
	params: FillTime (s to fill), Perfect / Good / Ok (half-widths of the window
	in gauge units 0..1). The fill accelerates slightly (tension); holding past
	full is a miss. After each rep the gauge drains and a new window appears.
]]

local UI = script.Parent.Parent.UI
local C = require(UI.Components)
local New = require(UI.Create)
local Theme = require(UI.Theme)

local Kit = require(script.Parent.Kit)

local Charge = {}
Charge.Actions = { "Primary" }

local WIDTH = 380
local HEIGHT = 26
local OVERFILL = 0.08

function Charge.build(api: Kit.Api): (number) -> ()
	local p = api.params
	local fillTime = math.max(0.4, p.FillTime or 1.2)
	local perfect, good, ok = p.Perfect or 0.06, p.Good or 0.13, p.Ok or 0.22

	local stage = api.stage
	local holder = C.frame({
		Parent = stage,
		Name = "Gauge",
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Position = UDim2.new(0.5, 0, 0.56, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	local track = Kit.box(holder, { Color = Kit.TrackDeep, Size = UDim2.fromScale(1, 1) })
	track.ClipsDescendants = true
	C.stroke(track, 0.82)

	local function zone(halfWidth: number, color: Color3, transparency: number, z: number): Frame
		return Kit.box(track, {
			Color = color,
			Transparency = transparency,
			Size = UDim2.new(halfWidth * 2, 0, 1, 0),
			AnchorPoint = Vector2.new(0.5, 0),
			Radius = UDim.new(0, 4),
			ZIndex = z,
		})
	end
	local okZone = zone(ok, Kit.Ok, 0.72, 2)
	local goodZone = zone(good, Kit.Good, 0.45, 3)
	local perfectZone = zone(perfect, Kit.Perfect, 0.05, 4)

	local fill = Kit.box(track, {
		Color = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0, 1),
		ZIndex = 5,
		Transparency = 0.05,
	})
	New("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, api.accent:Lerp(Theme.Color.Surface3, 0.35)),
			ColorSequenceKeypoint.new(0.7, api.accent),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 236, 200)),
		}),
		Transparency = NumberSequence.new(0.35, 0),
		Parent = fill,
	})
	local head = Kit.box(track, {
		Color = Theme.Color.Text,
		Size = UDim2.new(0, 3, 1, 4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Radius = UDim.new(0, 2),
		ZIndex = 6,
	})
	-- ticks every 10%
	for i = 1, 9 do
		Kit.box(track, {
			Color = Theme.Color.Stroke,
			Transparency = 0.85,
			Size = UDim2.new(0, 1, 0.38, 0),
			Position = UDim2.new(i / 10, 0, 1, 0),
			AnchorPoint = Vector2.new(0.5, 1),
			Radius = false,
			ZIndex = 7,
		})
	end
	local glow = Kit.glow(track, Theme.Color.Accent, 2)

	local cap = Kit.keyCap(stage, "HOLD SPACE", { Position = UDim2.new(0.5, -WIDTH / 2, 0.56, -HEIGHT / 2 - 8), AnchorPoint = Vector2.new(0, 1) })
	local power = C.label({
		Parent = stage,
		Text = "",
		Font = Theme.Font.Heavy,
		TextSize = Theme.TextSize.Caption,
		Color = Theme.Color.TextDim,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(120, 18),
		Position = UDim2.new(0.5, WIDTH / 2, 0.56, -HEIGHT / 2 - 8),
		AnchorPoint = Vector2.new(1, 1),
	})

	local target = 0.75
	local value = 0
	local state = "idle" -- idle | charging | drain
	local holdT = 0
	local wanted = false

	local function placeZones()
		for _, z in { okZone, goodZone, perfectZone } do
			z.Position = UDim2.fromScale(target, 0)
		end
	end
	local function newTarget()
		local hi = math.max(0.62, 0.97 - ok)
		target = 0.58 + math.random() * (hi - 0.58)
		placeZones()
		for z, tr in { [okZone] = 0.72, [goodZone] = 0.45, [perfectZone] = 0.05 } do
			z.BackgroundTransparency = 1
			Kit.tween(z, 0.25, { BackgroundTransparency = tr })
		end
	end
	placeZones()

	local function finish(q: number, word: string?)
		api.grade(q)
		local col = Kit.qualityColor(q)
		Kit.pulseStroke(glow, col, 0)
		if word then
			Kit.popWord(stage, word, col, UDim2.new(0.5, (value - 0.5) * WIDTH, 0.56, -HEIGHT))
		end
		state = "drain"
	end

	local function startCharge()
		state = "charging"
		holdT = 0
		wanted = false
	end

	api.trove:Add(api.input.pressed:Connect(function(action: string)
		if action ~= "Primary" then
			return
		end
		Kit.blink(cap)
		if state == "idle" and api.ready() then
			startCharge()
		else
			wanted = true
		end
	end))
	api.trove:Add(api.input.released:Connect(function(action: string)
		if action ~= "Primary" then
			return
		end
		wanted = false
		if state == "charging" then
			local d = math.abs(value - target)
			local q = if d <= perfect then 3 elseif d <= good then 2 elseif d <= ok then 1 else 0
			finish(q, if q == 0 and value < target then "TOO EARLY" else nil)
		end
	end))

	api.touch({ Position = UDim2.new(1, 64, 0.5, 0), Text = "HOLD", Size = 92 }, function()
		api.input.press("Primary", "touch")
	end, function()
		api.input.release("Primary", "touch")
	end)
	api.setHint({
		Keyboard = "Hold <b>SPACE</b> (or the mouse) to power up, release in the <font color=\"#F2A93B\">gold</font>",
		Gamepad = "Hold <b>A</b> to power up, release in the <font color=\"#F2A93B\">gold</font>",
		Touch = "Hold the button to power up, release in the <font color=\"#F2A93B\">gold</font>",
	})
	local function deviceCap(d: string)
		cap.Visible = d ~= "Touch"
		Kit.setKeyCap(cap, if d == "Gamepad" then "HOLD A" else "HOLD SPACE")
	end
	api.trove:Add(api.input.deviceChanged:Connect(deviceCap))
	deviceCap(api.device())

	return function(dt: number)
		if state == "charging" then
			holdT += dt
			local u = holdT / fillTime
			value = u ^ 1.2
			if value >= 1 + OVERFILL then
				value = 1
				finish(0, "TOO LONG")
			end
		elseif state == "drain" then
			value = math.max(0, value - dt / 0.32)
			if value <= 0 then
				state = "idle"
				newTarget()
			end
		elseif state == "idle" and wanted and api.ready() and api.input.isDown("Primary") then
			startCharge()
		end
		local shown = math.min(1, value)
		fill.Size = UDim2.fromScale(shown, 1)
		head.Position = UDim2.fromScale(shown, 0.5)
		local inside = state == "charging" and math.abs(value - target) <= good
		head.BackgroundColor3 = if inside then Theme.Color.Accent else Theme.Color.Text
		local strain = if state == "charging" then math.clamp((value - 0.8) / 0.25, 0, 1) else 0
		holder.Position = UDim2.new(0.5, (math.random() - 0.5) * 3 * strain, 0.56, (math.random() - 0.5) * 2 * strain)
		power.Text = if state == "charging" then `{math.floor(shown * 100 + 0.5)}%` else ""
	end
end

return Charge
