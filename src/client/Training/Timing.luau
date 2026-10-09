--!strict
--[[
	Timing: a needle sweeps a curved meter; tap when it crosses the lit window.
	params: Period (s per full back-and-forth), Perfect / Good / Ok (half-widths
	of the window in meter units 0..1). One grade per tap; a fresh window lights
	up after each rep (never under the needle).
]]

local UI = script.Parent.Parent.UI
local C = require(UI.Components)
local New = require(UI.Create)
local Theme = require(UI.Theme)

local Kit = require(script.Parent.Kit)

local Timing = {}
Timing.Actions = { "Primary" }

local SEGMENTS = 41
local SPAN = 132 -- degrees of arc
local RADIUS = 92
local SEG_LEN = 15

function Timing.build(api: Kit.Api): (number) -> ()
	local p = api.params
	local period = math.max(0.4, p.Period or 1.4)
	local perfect, good, ok = p.Perfect or 0.07, p.Good or 0.16, p.Ok or 0.27

	-- arc centre sits at the bottom of the stage so only the top of the dial shows;
	-- non-rotated pieces live in a clipping frame, rotated ones in `dial`
	local stage = api.stage
	local CENTER = UDim2.new(0.5, 0, 1, 6)
	local clip = C.frame({ Parent = stage, Name = "Clip", Size = UDim2.fromScale(1, 1), Clip = true })
	local flat = C.frame({ Parent = clip, Name = "Flat", Size = UDim2.fromOffset(0, 0), Position = CENTER })
	local dial = C.frame({ Parent = stage, Name = "Dial", Size = UDim2.fromOffset(0, 0), Position = CENTER })
	local function holder(angle: number, w: number, zindex: number): Frame
		return New("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(w, RADIUS * 2),
			Rotation = angle,
			ZIndex = zindex,
			Parent = dial,
		})
	end

	-- dial face: soft backing disc (clipped to a cap)
	local face = Kit.box(flat, {
		Color = Theme.Color.Surface0,
		Transparency = 0.3,
		Size = UDim2.fromOffset((RADIUS + 16) * 2, (RADIUS + 16) * 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	C.stroke(face, 0.86)

	type Seg = { bar: Frame, pos: number }
	local segs: { Seg } = {}
	for i = 0, SEGMENTS - 1 do
		local pos = i / (SEGMENTS - 1)
		local h = holder(-SPAN / 2 + SPAN * pos, 6, 2)
		local bar = Kit.box(h, {
			Color = Kit.Track,
			Size = UDim2.fromOffset(4, SEG_LEN),
			Position = UDim2.fromOffset(1, 2),
			Radius = UDim.new(0, 2),
			ZIndex = 2,
		})
		table.insert(segs, { bar = bar, pos = pos })
	end

	-- needle: a transparent full-diameter holder rotated about the centre
	local needleHolder = holder(0, 10, 4)
	local needle = Kit.box(needleHolder, {
		Color = Theme.Color.Text,
		Size = UDim2.fromOffset(4, 44),
		Position = UDim2.fromOffset(3, -6),
		Radius = UDim.new(0, 2),
		ZIndex = 4,
	})
	local tip = Kit.box(needleHolder, {
		Color = Theme.Color.Text,
		Size = UDim2.fromOffset(12, 12),
		Position = UDim2.fromOffset(-1, -12),
		ZIndex = 5,
	})
	local tipGlow = Kit.glow(tip, Theme.Color.Accent, 3)
	local hub = Kit.box(flat, {
		Color = Theme.Color.Surface3,
		Size = UDim2.fromOffset(26, 26),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 5,
	})
	C.stroke(hub, 0.7)

	-- key cap to the right of the dial
	local cap = Kit.keyCap(stage, "SPACE", { Position = UDim2.new(0.5, RADIUS + 34, 1, -16), AnchorPoint = Vector2.new(0, 1) })

	local target = 0.5
	local shown = 0 -- 0..1 window reveal
	local t = math.random() * period
	local flashUntil = 0
	local flashColor = Theme.Color.Text

	local function paint()
		for _, s in segs do
			local d = math.abs(s.pos - target)
			local col, tr, len = Kit.Track, 0, SEG_LEN
			if d <= perfect then
				col, len = Kit.Perfect, SEG_LEN + 6
			elseif d <= good then
				col, len = Kit.Good, SEG_LEN + 3
			elseif d <= ok then
				col, tr = Kit.Ok, 0.15
			end
			s.bar.BackgroundColor3 = Kit.Track:Lerp(col, shown)
			s.bar.BackgroundTransparency = tr * shown
			s.bar.Size = UDim2.fromOffset(4, math.floor(SEG_LEN + (len - SEG_LEN) * shown))
		end
	end

	local function needlePos(time: number): number
		local x = (time / period * 2) % 2
		return if x <= 1 then x else 2 - x
	end

	local function newTarget()
		local cur = needlePos(t)
		for _ = 1, 8 do
			target = 0.2 + math.random() * 0.6
			if math.abs(target - cur) > 0.28 then
				break
			end
		end
		shown = 0
	end
	newTarget()
	paint()

	api.trove:Add(api.input.pressed:Connect(function(action: string)
		if action ~= "Primary" then
			return
		end
		Kit.blink(cap)
		if not api.ready() or shown < 0.6 then
			return
		end
		local d = math.abs(needlePos(t) - target)
		local q = if d <= perfect then 3 elseif d <= good then 2 elseif d <= ok then 1 else 0
		api.grade(q)
		flashColor = Kit.qualityColor(q)
		flashUntil = os.clock() + 0.3
		Kit.pulseStroke(tipGlow, flashColor, 0)
		newTarget()
		paint()
	end))

	api.touch({ Position = UDim2.new(1, 64, 0.5, 0), Text = "TAP", Size = 92 }, function()
		api.input.press("Primary", "touch")
	end, function()
		api.input.release("Primary", "touch")
	end)

	api.setHint({
		Keyboard = "Press <b>SPACE</b> or click as the needle crosses the <font color=\"#F2A93B\">gold</font>",
		Gamepad = "Press <b>A</b> as the needle crosses the <font color=\"#F2A93B\">gold</font>",
		Touch = "Tap as the needle crosses the <font color=\"#F2A93B\">gold</font>",
	})
	api.trove:Add(api.input.deviceChanged:Connect(function(d: string)
		Kit.setKeyCap(cap, if d == "Gamepad" then "A" else "SPACE")
		cap.Visible = d ~= "Touch"
	end))
	cap.Visible = api.device() ~= "Touch"
	if api.device() == "Gamepad" then
		Kit.setKeyCap(cap, "A")
	end

	return function(dt: number)
		t += dt
		if shown < 1 and api.ready() then
			shown = math.min(1, shown + dt / 0.18)
			paint()
		end
		local x = needlePos(t)
		needleHolder.Rotation = -SPAN / 2 + SPAN * x
		local hot = math.abs(x - target) <= good and shown >= 1
		local col = if os.clock() < flashUntil then flashColor elseif hot then Theme.Color.Accent else Theme.Color.Text
		needle.BackgroundColor3 = col
		tip.BackgroundColor3 = col
	end
end

return Timing
