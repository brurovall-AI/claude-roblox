--!strict
--[[
	Rhythm: keep the marker inside a drifting target band. Holding pushes the
	marker right, releasing lets it drift back (momentum, soft edges).
	params: StrokeTime (s per graded stroke), BandSize (band width 0..1),
	Drift (how fast the band wanders). Every stroke is graded from the share
	of time spent inside the band; idle strokes (no input, never inside) are
	not graded so standing still doesn't spam misses.
]]

local UI = script.Parent.Parent.UI
local C = require(UI.Components)
local New = require(UI.Create)
local Theme = require(UI.Theme)

local Kit = require(script.Parent.Kit)

local Rhythm = {}
Rhythm.Actions = { "Primary" }

local WIDTH = 400
local HEIGHT = 30
local ACCEL = 2.8
local MAX_SPEED = 1.15
local HISTORY = 8

function Rhythm.build(api: Kit.Api): (number) -> ()
	local p = api.params
	local strokeTime = math.max(0.6, p.StrokeTime or 1.3)
	local bandSize = math.clamp(p.BandSize or 0.25, 0.08, 0.6)
	local drift = math.max(0.05, p.Drift or 0.5)
	local seed = math.random() * 1000

	local stage = api.stage
	local holder = C.frame({
		Parent = stage,
		Name = "Rhythm",
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Position = UDim2.new(0.5, 0, 0.5, -4),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	local track = Kit.box(holder, { Color = Kit.TrackDeep, Size = UDim2.fromScale(1, 1) })
	C.stroke(track, 0.82)
	track.ClipsDescendants = true

	local band = Kit.box(track, {
		Color = Kit.Good,
		Transparency = 0.55,
		Size = UDim2.new(bandSize, 0, 1, -6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Radius = UDim.new(0, 8),
		ZIndex = 2,
	})
	local bandStroke = New("UIStroke", { Color = Kit.Good, Thickness = 1.5, Transparency = 0.4, Parent = band })
	local bandCore = Kit.box(band, {
		Color = Kit.Perfect,
		Transparency = 0.35,
		Size = UDim2.new(0, 2, 1, -6),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 3,
	})

	local marker = Kit.box(holder, {
		Color = Theme.Color.Text,
		Size = UDim2.fromOffset(8, HEIGHT + 12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 5,
	})
	C.stroke(marker, 0.5, Theme.Color.Backdrop, 1.5)

	-- stroke timer + history dots
	local timer = Kit.box(stage, {
		Color = Kit.Track,
		Size = UDim2.fromOffset(WIDTH, 4),
		Position = UDim2.new(0.5, 0, 0.5, HEIGHT / 2 + 6),
		AnchorPoint = Vector2.new(0.5, 0),
	})
	local timerFill = Kit.box(timer, { Color = api.accent, Size = UDim2.fromScale(0, 1) })
	local dotsRow = C.frame({
		Parent = stage,
		Size = UDim2.fromOffset(HISTORY * 12, 10),
		Position = UDim2.new(0.5, WIDTH / 2, 0.5, -HEIGHT / 2 - 10),
		AnchorPoint = Vector2.new(1, 1),
	})
	C.list(dotsRow, "H", 4, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local dots: { Frame } = {}
	for i = 1, HISTORY do
		local d = Kit.box(dotsRow, { Color = Kit.Track, Size = UDim2.fromOffset(8, 8) })
		d.LayoutOrder = i
		table.insert(dots, d)
	end
	local history: { number } = {}
	local cap = Kit.keyCap(stage, "HOLD SPACE", { Position = UDim2.new(0.5, -WIDTH / 2, 0.5, -HEIGHT / 2 - 8), AnchorPoint = Vector2.new(0, 1) })

	local x, v = 0.3, 0
	local t = 0
	local strokeT, inside = 0, 0
	local active = false
	local center = 0.5

	local function bandCenter(time: number): number
		local n = math.clamp(math.noise(time * drift * 0.55, seed, 0.3) * 2.4, -1, 1)
		local room = 0.5 - bandSize / 2 - 0.02
		return 0.5 + room * n
	end

	local function pushHistory(q: number)
		table.insert(history, 1, q)
		if #history > HISTORY then
			table.remove(history)
		end
		for i, d in dots do
			local h = history[HISTORY - i + 1]
			d.BackgroundColor3 = if h then Kit.qualityColor(h) else Kit.Track
		end
	end

	api.trove:Add(api.input.pressed:Connect(function(action: string)
		if action == "Primary" then
			active = true
			Kit.blink(cap)
		end
	end))
	api.trove:Add(api.input.released:Connect(function(action: string)
		if action == "Primary" then
			active = true
		end
	end))

	api.touch({ Position = UDim2.new(1, 64, 0.5, 0), Text = "HOLD", Size = 92 }, function()
		api.input.press("Primary", "touch")
	end, function()
		api.input.release("Primary", "touch")
	end)
	api.setHint({
		Keyboard = "Hold <b>SPACE</b> to push, release to ease back. Stay in the <font color=\"#4CC38A\">band</font>",
		Gamepad = "Hold <b>A</b> to push, release to ease back. Stay in the <font color=\"#4CC38A\">band</font>",
		Touch = "Hold the button to push, release to ease back. Stay in the <font color=\"#4CC38A\">band</font>",
	})
	local function deviceCap(d: string)
		cap.Visible = d ~= "Touch"
		Kit.setKeyCap(cap, if d == "Gamepad" then "HOLD A" else "HOLD SPACE")
	end
	api.trove:Add(api.input.deviceChanged:Connect(deviceCap))
	deviceCap(api.device())

	return function(dt: number)
		t += dt
		-- marker physics
		local holding = api.input.isDown("Primary")
		v = math.clamp(v + (if holding then ACCEL else -ACCEL) * dt, -MAX_SPEED, MAX_SPEED)
		x += v * dt
		if x < 0 then
			x, v = 0, math.max(0, -v * 0.25)
		elseif x > 1 then
			x, v = 1, math.min(0, -v * 0.25)
		end
		center = bandCenter(t)
		local isIn = math.abs(x - center) <= bandSize / 2
		if isIn then
			inside += dt
		end

		band.Position = UDim2.fromScale(center, 0.5)
		marker.Position = UDim2.fromScale(x, 0.5)
		marker.BackgroundColor3 = if isIn then Theme.Color.Accent else Theme.Color.Text
		band.BackgroundTransparency = if isIn then 0.3 else 0.62
		bandStroke.Transparency = if isIn then 0.05 else 0.5
		bandCore.BackgroundTransparency = if isIn then 0 else 0.45

		strokeT += dt
		timerFill.Size = UDim2.fromScale(math.clamp(strokeT / strokeTime, 0, 1), 1)
		if strokeT >= strokeTime then
			local frac = inside / strokeT
			if (active or frac >= 0.3) and api.ready() then
				local q = if frac >= 0.85 then 3 elseif frac >= 0.6 then 2 elseif frac >= 0.3 then 1 else 0
				api.grade(q)
				pushHistory(q)
				timerFill.BackgroundColor3 = Kit.qualityColor(q)
				Kit.tween(timerFill, 0.5, { BackgroundColor3 = api.accent })
			end
			strokeT, inside, active = 0, 0, holding
		end
	end
end

return Rhythm
