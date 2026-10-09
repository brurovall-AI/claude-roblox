--!strict
--[[
	Minigame: the shared training minigame API (ARCHITECTURE section 8).

		local handle = Minigame.run(kind, params, parent, function(quality)
			-- 0 Miss, 1 Ok, 2 Good, 3 Perfect; once per graded rep / stroke
		end, { Accent = statColour })   -- optional opts
		...
		handle.stop()

	`params` come from Config/Minigames.params(kind, difficulty) (the training
	server already widens windows for Lucky Chalk). The minigame renders inside
	`parent` (it fills it; ~520 x 130 px reads best), binds its own inputs for
	keyboard / mouse, gamepad and touch (big on-screen buttons appear only while
	the player is on touch), animates at frame rate and never calls onRep
	faster than Minigames.minRepInterval allows, so the server's cadence check
	never drops a legit rep.

	Kinds (one module each in this folder): Timing, Charge, Rhythm, Cadence,
	Sequence, Breath. Every module exports build(api: Kit.Api) -> update(dt).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Trove = require(Shared.Util.Trove)

local UI = script.Parent.Parent.UI
local C = require(UI.Components)
local Theme = require(UI.Theme)

local Input = require(script.Parent.Input)
local Kit = require(script.Parent.Kit)

local Minigame = {}

export type Handle = { stop: () -> () }
export type Options = { Accent: Color3?, ShowHint: boolean? }

type KindModule = { build: (api: Kit.Api) -> (number) -> (), Actions: { string } }

local KINDS: { [string]: KindModule } = {
	Timing = require(script.Parent.Timing) :: any,
	Charge = require(script.Parent.Charge) :: any,
	Rhythm = require(script.Parent.Rhythm) :: any,
	Cadence = require(script.Parent.Cadence) :: any,
	Sequence = require(script.Parent.Sequence) :: any,
	Breath = require(script.Parent.Breath) :: any,
}

Minigame.Kinds = { "Timing", "Charge", "Rhythm", "Cadence", "Sequence", "Breath" }

-- Shortest gap between two graded reps (mirrors Minigames.minRepInterval).
function Minigame.minInterval(kind: string, p: { [string]: number }): number
	if kind == "Timing" then
		return (p.Period or 1.2) * 0.5
	elseif kind == "Charge" then
		return (p.FillTime or 1) * 0.6
	elseif kind == "Rhythm" or kind == "Cadence" then
		return p.StrokeTime or 1.2
	elseif kind == "Sequence" then
		return (p.Length or 3) * 0.18
	end
	return p.Inhale or 2
end

function Minigame.run(kind: string, params: { [string]: number }, parent: GuiObject, onRep: (quality: number) -> (), opts: Options?): Handle
	local o: Options = opts or {}
	local mod = KINDS[kind]
	assert(mod, "unknown minigame kind " .. tostring(kind))
	local trove = Trove.new()
	local stopped = false

	local root = trove:Add(C.frame({ Parent = parent, Name = "Minigame_" .. kind, Size = UDim2.fromScale(1, 1) }))
	local showHint = o.ShowHint ~= false
	local stage = C.frame({ Parent = root, Name = "Stage", Size = UDim2.new(1, 0, 1, if showHint then -20 else 0) })
	local hint = C.label({
		Parent = root,
		Name = "Hint",
		Text = "",
		Rich = true,
		TextSize = Theme.TextSize.Caption,
		Color = Theme.Color.TextDim,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		Visible = showHint,
	})

	local input = Input.new(mod.Actions, trove)
	local interval = Minigame.minInterval(kind, params)
	local lastGrade = -math.huge
	local pending: number? = nil
	local hints: { [string]: string } = {}
	local touchButtons: { Kit.TouchButton } = {}

	local function refreshDevice()
		local d = input.device()
		hint.Text = hints[d] or hints.Keyboard or ""
		for _, b in touchButtons do
			b.setVisible(d == "Touch")
		end
	end
	trove:Add(input.deviceChanged:Connect(refreshDevice))

	local function emit(q: number)
		lastGrade = os.clock()
		task.spawn(onRep, q)
	end

	local api: Kit.Api = {
		kind = kind,
		root = root,
		stage = stage,
		params = params,
		input = input,
		trove = trove,
		accent = o.Accent or Theme.Color.Accent,
		minInterval = interval,
		ready = function(): boolean
			return pending == nil and os.clock() - lastGrade >= interval
		end,
		grade = function(quality: number)
			if stopped then
				return
			end
			local q = math.clamp(math.floor(quality + 0.5), 0, 3)
			local wait = lastGrade + interval - os.clock()
			if wait <= 0 and pending == nil then
				emit(q)
				return
			end
			-- too soon (should be rare): deliver once the interval has passed
			local first = pending == nil
			pending = q
			if first then
				task.delay(math.max(0, wait), function()
					local p = pending
					pending = nil
					if p and not stopped then
						emit(p)
					end
				end)
			end
		end,
		setHint = function(h: { [string]: string })
			hints = h
			refreshDevice()
		end,
		touch = function(props: { [string]: any }, onDown: () -> (), onUp: () -> ()): Kit.TouchButton
			local b = Kit.touchButton(root, props, onDown, onUp)
			b.setVisible(input.device() == "Touch")
			table.insert(touchButtons, b)
			return b
		end,
		device = function(): string
			return input.device()
		end,
	}

	local update = mod.build(api)
	refreshDevice()
	trove:Connect(RunService.PreRender, function(dt: number)
		if not stopped then
			update(math.min(dt, 0.1))
		end
	end)

	return {
		stop = function()
			if stopped then
				return
			end
			stopped = true
			pending = nil
			trove:Clean()
		end,
	}
end

return Minigame
