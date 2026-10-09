--!strict
--[[
	Breath: hold to inhale as the ring expands, release at the top (on the
	guide ring), then exhale slowly while the ring settles. params: Inhale
	(s to fill), Perfect / Good / Ok (half-widths around the guide, ring units
	0..1). Holding past full is a miss. Calm palette: this is recovery.
]]

local UI = script.Parent.Parent.UI
local C = require(UI.Components)
local New = require(UI.Create)
local Theme = require(UI.Theme)

local Kit = require(script.Parent.Kit)

local Breath = {}
Breath.Actions = { "Primary" }

local MAX = 96 -- ring diameter at full breath (px)
local MIN = 26
local CALM = Theme.Color.Energy

function Breath.build(api: Kit.Api): (number) -> ()
	local p = api.params
	local inhale = math.max(0.8, p.Inhale or 2)
	local perfect, good, ok = p.Perfect or 0.07, p.Good or 0.14, p.Ok or 0.23
	local exhaleTime = inhale * 0.95

	local stage = api.stage
	local holder = C.frame({
		Parent = stage,
		Name = "Breath",
		Size = UDim2.fromOffset(MAX + 20, MAX + 20),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	local function ring(size: number, color: Color3, thickness: number, transparency: number, z: number): (Frame, UIStroke)
		local f = Kit.box(holder, {
			Color = color,
			Transparency = 1,
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = z,
		})
		local s = New("UIStroke", { Color = color, Thickness = thickness, Transparency = transparency, Parent = f })
		return f, s
	end

	-- window band: two faint rings marking the Good range, a bright guide ring
	local target = 0.85
	local function px(v: number): number
		return MIN + (MAX - MIN) * v
	end
	local outer, _ = ring(px(target + good), Kit.Good, 1, 0.65, 2)
	local inner, _ = ring(px(target - good), Kit.Good, 1, 0.65, 2)
	local guide, guideStroke = ring(px(target), Kit.Perfect, 2.5, 0.1, 3)

	-- the breath itself: soft disc + rim
	local disc = Kit.box(holder, {
		Color = CALM,
		Transparency = 0.7,
		Size = UDim2.fromOffset(MIN, MIN),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 4,
	})
	New("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 200, 230)),
		Rotation = 90,
		Parent = disc,
	})
	local rim = New("UIStroke", { Color = CALM, Thickness = 2, Transparency = 0.1, Parent = disc })
	local word = C.label({
		Parent = stage,
		Text = "HOLD TO INHALE",
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Micro,
		Color = Theme.Color.TextDim,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(160, 16),
		Position = UDim2.new(0.5, MAX / 2 + 96, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	local cap = Kit.keyCap(stage, "HOLD SPACE", { Position = UDim2.new(0.5, -MAX / 2 - 96, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5) })

	local value = 0
	local state = "idle" -- idle | inhale | exhale
	local holdT = 0
	local wanted = false

	local function placeTarget()
		outer.Size = UDim2.fromOffset(px(target + good), px(target + good))
		inner.Size = UDim2.fromOffset(px(math.max(0, target - good)), px(math.max(0, target - good)))
		guide.Size = UDim2.fromOffset(px(target), px(target))
	end
	local function newTarget()
		target = 0.74 + math.random() * (math.max(0.75, 0.97 - ok) - 0.74)
		placeTarget()
	end
	newTarget()

	local function release(q: number, text: string?)
		api.grade(q)
		local col = Kit.qualityColor(q)
		guideStroke.Color = col
		Kit.tween(guideStroke, 0.5, { Color = Kit.Perfect })
		if text then
			Kit.popWord(stage, text, col, UDim2.new(0.5, 0, 0.5, -MAX / 2 - 4))
		end
		state = "exhale"
		word.Text = "EXHALE..."
	end

	local function startInhale()
		state = "inhale"
		holdT = 0
		wanted = false
		word.Text = "INHALE"
	end

	api.trove:Add(api.input.pressed:Connect(function(action: string)
		if action ~= "Primary" then
			return
		end
		Kit.blink(cap, CALM)
		if state == "idle" and api.ready() then
			startInhale()
		else
			wanted = true
		end
	end))
	api.trove:Add(api.input.released:Connect(function(action: string)
		if action ~= "Primary" then
			return
		end
		wanted = false
		if state == "inhale" then
			local d = math.abs(value - target)
			local q = if d <= perfect then 3 elseif d <= good then 2 elseif d <= ok then 1 else 0
			release(q, if q == 0 and value < target then "TOO SHALLOW" else nil)
		end
	end))

	api.touch({ Position = UDim2.new(1, 64, 0.5, 0), Text = "HOLD", Size = 92, Color = CALM }, function()
		api.input.press("Primary", "touch")
	end, function()
		api.input.release("Primary", "touch")
	end)
	api.setHint({
		Keyboard = "Hold <b>SPACE</b> to inhale, let go on the <font color=\"#F2A93B\">ring</font>, then exhale",
		Gamepad = "Hold <b>A</b> to inhale, let go on the <font color=\"#F2A93B\">ring</font>, then exhale",
		Touch = "Hold to inhale, let go on the <font color=\"#F2A93B\">ring</font>, then exhale",
	})
	local function deviceCap(d: string)
		cap.Visible = d ~= "Touch"
		Kit.setKeyCap(cap, if d == "Gamepad" then "HOLD A" else "HOLD SPACE")
	end
	api.trove:Add(api.input.deviceChanged:Connect(deviceCap))
	deviceCap(api.device())

	local t = 0
	return function(dt: number)
		t += dt
		if state == "inhale" then
			holdT += dt
			-- slows as the lungs fill (ease-out), so the top is readable
			local u = holdT / inhale
			value = 1 - (1 - math.min(u, 1)) ^ 1.6 + math.max(0, u - 1) * 0.6
			if value >= 1 + ok * 0.5 then
				release(0, "HELD TOO LONG")
			end
		elseif state == "exhale" then
			value = math.max(0, value - dt / exhaleTime)
			if value <= 0 and api.ready() then
				state = "idle"
				word.Text = "HOLD TO INHALE"
				newTarget()
			end
		elseif state == "idle" and wanted and api.ready() and api.input.isDown("Primary") then
			startInhale()
		end
		-- idle: a slow resting pulse so the widget feels alive
		local rest = if state == "idle" then 0.04 + 0.03 * math.sin(t * 1.6) else 0
		local s = px(math.clamp(value + rest, 0, 1.15))
		disc.Size = UDim2.fromOffset(s, s)
		local near = state == "inhale" and math.abs(value - target) <= good
		rim.Color = if near then Kit.Perfect else CALM
		disc.BackgroundTransparency = if near then 0.45 else 0.7
	end
end

return Breath
