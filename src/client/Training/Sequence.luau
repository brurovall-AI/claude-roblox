--!strict
--[[
	Sequence: hit the shown direction prompts in order before the timer runs
	out. params: Length (prompts per rep), TimePerInput (s budget per prompt).
	Clean + fast = Perfect (>= 50% time left), Good (>= 25%), Ok (finished);
	a wrong direction or the timer running out = Miss.
]]

local UI = script.Parent.Parent.UI
local C = require(UI.Components)
local Icons = require(UI.Icons)
local New = require(UI.Create)
local Theme = require(UI.Theme)

local Kit = require(script.Parent.Kit)

local Sequence = {}
Sequence.Actions = { "Up", "Down", "Left", "Right" }

local CHIP = 46
local GAP = 10
local DIRS = { "Up", "Down", "Left", "Right" }
local ICON: { [string]: string } = { Up = "up", Down = "down", Left = "left", Right = "right" }

type Chip = { frame: Frame, icon: Frame, scale: UIScale, stroke: UIStroke }

function Sequence.build(api: Kit.Api): (number) -> ()
	local p = api.params
	local length = math.clamp(math.floor((p.Length or 3) + 0.5), 2, 7)
	local budget = math.max(0.3, p.TimePerInput or 0.8) * length

	local stage = api.stage
	local width = length * CHIP + (length - 1) * GAP
	local row = C.frame({
		Parent = stage,
		Name = "Chips",
		Size = UDim2.fromOffset(width, CHIP),
		Position = UDim2.new(0.5, 0, 0.5, -6),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	local chips: { Chip } = {}
	for i = 1, length do
		local f = Kit.box(row, {
			Color = Theme.Color.Surface1,
			Size = UDim2.fromOffset(CHIP, CHIP),
			Position = UDim2.fromOffset((i - 1) * (CHIP + GAP) + CHIP / 2, CHIP / 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Radius = Theme.Radius.Medium,
		})
		local stroke = C.stroke(f, 0.8)
		local scale = New("UIScale", { Parent = f })
		local icon = Icons.make("up", 22, Theme.Color.Text)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Parent = f
		table.insert(chips, { frame = f, icon = icon, scale = scale, stroke = stroke })
	end
	local timer = Kit.box(stage, {
		Color = Kit.Track,
		Size = UDim2.fromOffset(math.max(width, 220), 4),
		Position = UDim2.new(0.5, 0, 0.5, CHIP / 2 + 4),
		AnchorPoint = Vector2.new(0.5, 0),
	})
	local timerFill = Kit.box(timer, { Color = api.accent, Size = UDim2.fromScale(1, 1) })

	local seq: { string } = {}
	local idx = 1
	local state = "reveal" -- reveal | input | result
	local stateT = 0
	local timeLeft = budget

	local function setIcon(c: Chip, dir: string)
		c.icon:Destroy()
		local icon = Icons.make(ICON[dir], 22, Theme.Color.Text)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Parent = c.frame
		c.icon = icon
	end

	local function paintChip(i: number, mode: string)
		local c = chips[i]
		if mode == "done" then
			c.frame.BackgroundColor3 = Kit.Good:Lerp(Theme.Color.Surface1, 0.35)
			c.stroke.Transparency = 0.8
			Icons.recolor(c.icon, Color3.fromHex("#0C1E14"))
		elseif mode == "current" then
			c.frame.BackgroundColor3 = Theme.Color.Surface2
			c.stroke.Color = Theme.Color.Accent
			c.stroke.Transparency = 0.05
			Icons.recolor(c.icon, Theme.Color.Accent)
			Kit.tween(c.scale, 0.18, { Scale = 1.08 })
		elseif mode == "wrong" then
			c.frame.BackgroundColor3 = Kit.Miss
			c.stroke.Transparency = 0.8
			Icons.recolor(c.icon, Color3.new(1, 1, 1))
		else
			c.frame.BackgroundColor3 = Theme.Color.Surface1
			c.stroke.Color = Theme.Color.Stroke
			c.stroke.Transparency = 0.8
			Icons.recolor(c.icon, Theme.Color.TextDim)
			c.scale.Scale = 1
		end
	end

	local function newSequence()
		table.clear(seq)
		local prev, run = "", 0
		for i = 1, length do
			local d: string
			repeat
				d = DIRS[math.random(1, 4)]
			until d ~= prev or run < 1
			run = if d == prev then run + 1 else 0
			prev = d
			seq[i] = d
			setIcon(chips[i], d)
			paintChip(i, "idle")
			local c = chips[i]
			c.scale.Scale = 0.6
			c.frame.BackgroundTransparency = 1
			task.delay((i - 1) * 0.04, function()
				Kit.tween(c.scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
				Kit.tween(c.frame, 0.2, { BackgroundTransparency = 0 })
			end)
		end
		idx = 1
		timeLeft = budget
		state = "reveal"
		stateT = 0
		timerFill.Size = UDim2.fromScale(1, 1)
		timerFill.BackgroundColor3 = api.accent
	end

	local function finish(q: number)
		api.grade(q)
		state = "result"
		stateT = 0
		timerFill.BackgroundColor3 = Kit.qualityColor(q)
		if q == 0 then
			Kit.tween(row, 0.05, { Position = UDim2.new(0.5, 6, 0.5, -6) })
			task.delay(0.05, function()
				Kit.tween(row, 0.25, { Position = UDim2.new(0.5, 0, 0.5, -6) }, Enum.EasingStyle.Elastic)
			end)
		end
	end

	api.trove:Add(api.input.pressed:Connect(function(action: string)
		if state ~= "input" then
			return
		end
		if seq[idx] == action then
			paintChip(idx, "done")
			Kit.tween(chips[idx].scale, 0.2, { Scale = 1 })
			idx += 1
			if idx > length then
				local frac = timeLeft / budget
				finish(if frac >= 0.5 then 3 elseif frac >= 0.25 then 2 else 1)
			else
				paintChip(idx, "current")
			end
		else
			paintChip(idx, "wrong")
			finish(0)
		end
	end))

	-- touch D-pad to the right of the panel
	local pad = 54
	local offsets: { [string]: Vector2 } = { Up = Vector2.new(0, -pad), Down = Vector2.new(0, pad), Left = Vector2.new(-pad, 0), Right = Vector2.new(pad, 0) }
	for dir, offset in offsets do
		api.touch({ Position = UDim2.new(1, 96 + offset.X, 0.5, offset.Y), Icon = ICON[dir], Size = 52 }, function()
			api.input.press(dir, "touch")
		end, function()
			api.input.release(dir, "touch")
		end)
	end
	api.setHint({
		Keyboard = "Hit the arrows in order with <b>WASD</b> or the <b>arrow keys</b>",
		Gamepad = "Hit the arrows in order with the <b>D-pad</b>",
		Touch = "Tap the arrows in order on the pad",
	})

	newSequence()

	return function(dt: number)
		stateT += dt
		if state == "reveal" then
			if stateT >= 0.22 then
				state = "input"
				paintChip(1, "current")
			end
		elseif state == "input" then
			timeLeft -= dt
			timerFill.Size = UDim2.fromScale(math.clamp(timeLeft / budget, 0, 1), 1)
			if timeLeft <= budget * 0.25 then
				timerFill.BackgroundColor3 = Kit.Miss
			end
			if timeLeft <= 0 then
				finish(0)
			end
		elseif state == "result" then
			if stateT >= 0.4 and api.ready() then
				newSequence()
			end
		end
	end
end

return Sequence
