--!strict
--[[
	Cadence: alternate two inputs (left / right) to hold your turnover inside
	the band. params: StrokeTime (s per graded stroke), MinRate / MaxRate (band,
	alternating taps per second), Ideal (gold mark). Same-side double taps don't
	count (stumbles). Each stroke is graded on its average rate; strokes with no
	taps are skipped.
]]

local UI = script.Parent.Parent.UI
local C = require(UI.Components)
local Theme = require(UI.Theme)

local Kit = require(script.Parent.Kit)

local Cadence = {}
Cadence.Actions = { "Left", "Right" }

local WIDTH = 360
local HEIGHT = 22

function Cadence.build(api: Kit.Api): (number) -> ()
	local p = api.params
	local strokeTime = math.max(0.5, p.StrokeTime or 1.1)
	local minRate, maxRate = p.MinRate or 3.5, p.MaxRate or 7.5
	local ideal = p.Ideal or (minRate + maxRate) / 2
	local scaleMax = maxRate * 1.35
	local perfectBand = (maxRate - minRate) * 0.16

	local stage = api.stage
	local holder = C.frame({
		Parent = stage,
		Name = "Cadence",
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		Position = UDim2.new(0.5, 0, 0.5, 4),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	local track = Kit.box(holder, { Color = Kit.TrackDeep, Size = UDim2.fromScale(1, 1) })
	track.ClipsDescendants = true
	C.stroke(track, 0.82)
	local function at(rate: number): number
		return math.clamp(rate / scaleMax, 0, 1)
	end
	Kit.box(track, {
		Color = Kit.Good,
		Transparency = 0.6,
		Size = UDim2.new(at(maxRate) - at(minRate), 0, 1, 0),
		Position = UDim2.fromScale(at(minRate), 0),
		Radius = UDim.new(0, 4),
		ZIndex = 2,
	})
	Kit.box(track, {
		Color = Kit.Perfect,
		Transparency = 0.15,
		Size = UDim2.new(at(ideal + perfectBand) - at(ideal - perfectBand), 0, 1, 0),
		Position = UDim2.fromScale(at(ideal - perfectBand), 0),
		Radius = UDim.new(0, 4),
		ZIndex = 3,
	})
	local fill = Kit.box(track, { Color = api.accent, Transparency = 0.35, Size = UDim2.fromScale(0, 1), ZIndex = 4 })
	local needle = Kit.box(holder, {
		Color = Theme.Color.Text,
		Size = UDim2.fromOffset(4, HEIGHT + 12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		ZIndex = 6,
	})
	local rateLabel = C.label({
		Parent = stage,
		Text = "0.0 / s",
		Font = Theme.Font.Heavy,
		TextSize = Theme.TextSize.Caption,
		Color = Theme.Color.TextDim,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(100, 16),
		Position = UDim2.new(0.5, WIDTH / 2, 0.5, -HEIGHT / 2 - 4),
		AnchorPoint = Vector2.new(1, 1),
	})
	C.label({
		Parent = stage,
		Text = "PACE",
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Micro,
		Color = Theme.Color.TextMute,
		Size = UDim2.fromOffset(100, 16),
		Position = UDim2.new(0.5, -WIDTH / 2, 0.5, -HEIGHT / 2 - 4),
		AnchorPoint = Vector2.new(0, 1),
	})

	-- left / right key caps either side of the meter
	local capL = Kit.keyCap(stage, "A", { Position = UDim2.new(0.5, -WIDTH / 2 - 14, 0.5, 4), AnchorPoint = Vector2.new(1, 0.5), Height = 30, TextSize = Theme.TextSize.Body })
	local capR = Kit.keyCap(stage, "D", { Position = UDim2.new(0.5, WIDTH / 2 + 14, 0.5, 4), AnchorPoint = Vector2.new(0, 0.5), Height = 30, TextSize = Theme.TextSize.Body })

	local lastSide = ""
	local lastTap = 0
	local rate = 0
	local shown = 0
	local strokeT, strokeTaps = 0, 0

	local function tap(side: string)
		local cap = if side == "Left" then capL else capR
		local now = os.clock()
		if side == lastSide then
			Kit.blink(cap, Kit.Miss) -- stumble: same foot twice
			return
		end
		Kit.blink(cap, Theme.Color.Accent)
		if lastTap > 0 then
			local gap = math.max(0.04, now - lastTap)
			rate = rate * 0.6 + (1 / gap) * 0.4
		end
		lastSide = side
		lastTap = now
		strokeTaps += 1
	end

	api.trove:Add(api.input.pressed:Connect(function(action: string)
		if action == "Left" or action == "Right" then
			tap(action)
		end
	end))

	api.touch({ Position = UDim2.new(0, -64, 0.5, 0), Text = "L", Size = 96 }, function()
		api.input.press("Left", "touch")
	end, function()
		api.input.release("Left", "touch")
	end)
	api.touch({ Position = UDim2.new(1, 64, 0.5, 0), Text = "R", Size = 96 }, function()
		api.input.press("Right", "touch")
	end, function()
		api.input.release("Right", "touch")
	end)
	api.setHint({
		Keyboard = "Alternate <b>A</b> and <b>D</b> (or <b>← →</b>) to keep your pace in the <font color=\"#4CC38A\">green</font>",
		Gamepad = "Alternate <b>LB</b> and <b>RB</b> (or the D-pad) to keep your pace in the <font color=\"#4CC38A\">green</font>",
		Touch = "Tap <b>L</b> and <b>R</b> in turn to keep your pace in the <font color=\"#4CC38A\">green</font>",
	})
	local function deviceCaps(d: string)
		capL.Visible = d ~= "Touch"
		capR.Visible = d ~= "Touch"
		Kit.setKeyCap(capL, if d == "Gamepad" then "LB" else "A")
		Kit.setKeyCap(capR, if d == "Gamepad" then "RB" else "D")
	end
	api.trove:Add(api.input.deviceChanged:Connect(deviceCaps))
	deviceCaps(api.device())

	return function(dt: number)
		-- pace decays when the taps stop coming
		local since = os.clock() - lastTap
		if lastTap > 0 and rate > 0 and since > 1 / math.max(rate, 0.5) then
			rate = math.min(rate, 1 / since)
			if since > 1.5 then
				rate = 0
			end
		end
		shown += (rate - shown) * math.min(1, dt * 12)
		local x = at(shown)
		needle.Position = UDim2.fromScale(x, 0.5)
		fill.Size = UDim2.fromScale(x, 1)
		local inBand = shown >= minRate and shown <= maxRate
		local perfect = math.abs(shown - ideal) <= perfectBand
		needle.BackgroundColor3 = if perfect then Kit.Perfect elseif inBand then Kit.Good else Theme.Color.Text
		rateLabel.Text = string.format("%.1f / s", shown)

		strokeT += dt
		if strokeT >= strokeTime then
			if strokeTaps > 0 and api.ready() then
				local avg = strokeTaps / strokeT
				local q: number
				if math.abs(avg - ideal) <= perfectBand then
					q = 3
				elseif avg >= minRate and avg <= maxRate then
					q = 2
				elseif avg >= minRate * 0.75 and avg <= maxRate * 1.15 then
					q = 1
				else
					q = 0
				end
				api.grade(q)
				if q == 3 or q == 0 then
					Kit.popWord(stage, if q == 3 then "PERFECT PACE" else "OFF PACE", Kit.qualityColor(q), UDim2.new(0.5, (x - 0.5) * WIDTH, 0.5, -HEIGHT))
				end
			end
			strokeT, strokeTaps = 0, 0
		end
	end
end

return Cadence
