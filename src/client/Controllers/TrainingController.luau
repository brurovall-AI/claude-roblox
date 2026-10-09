--!strict
--[[
	TrainingController: the local training session (client side of
	TrainingService).

	  Server "TrainingEvent" ("Started" | "Rep" | "Stopped", payload) drives a
	  session panel in UIController.hud.BottomStack:
	    header   station name + tier chip, Leave hint (hold Space / Backspace / B / tap)
	    body     the minigame (Training/Minigame.run)
	    footer   combo (scale punch), session gains, reps, stat multiplier chip
	  Each graded rep: instant PERFECT / GOOD / OK / MISS word, rep sounds + the
	  station's SFX in 3D, the local rep animation (AnimationController), chalk
	  puff on strength Perfects (unless ReducedEffects), a small FOV punch on heavy
	  Perfects (if CameraShake). Each server result: rising gain / XP / cash
	  floaters next to the character and the authoritative combo.

	The camera is eased once to a side view of the station (rotation only, the
	player keeps full control; any camera input cancels the ease).
	State flags: Training, Minigame. The mission tracker (hud.Right) is hidden
	while training; currencies stay.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local Format = require(Shared.Util.Format)
local Boosts = require(Config.Boosts)
local Formulas = require(Shared.Formulas)
local Minigames = require(Config.Minigames)
local Net = require(Shared.Util.Net)
local Stations = require(Config.Stations)
local Stats = require(Config.Stats)
local Tiers = require(Config.Tiers)
local Trove = require(Shared.Util.Trove)

local UI = script.Parent.Parent.UI
local C = require(UI.Components)
local New = require(UI.Create)
local Theme = require(UI.Theme)

local State = require(script.Parent.Parent.Core.State)
local Minigame = require(script.Parent.Parent.Training.Minigame)
local TrainingInput = require(script.Parent.Parent.Training.Input)
local StationAnim = require(script.Parent.Parent.Anim.Stations)
local AnimationController = require(script.Parent.AnimationController)
local AudioController = require(script.Parent.AudioController)
local DataController = require(script.Parent.DataController)
local NotificationController = require(script.Parent.NotificationController)
local UIController = require(script.Parent.UIController)

local TrainingController = {}
TrainingController.Priority = 40

local player = Players.LocalPlayer

local PANEL_W, PANEL_H = 540, 228
local GAME_H = 132
local LEAVE_HOLD = 0.7
local HOLD_KINDS: { [string]: boolean } = { Charge = true, Rhythm = true, Breath = true }
local HEAVY_SOUNDS: { [string]: boolean } = { Barbell = true, Drop = true, Thud = true }
local CADENCE_TARGET = { [0] = 0.35, [1] = 0.6, [2] = 0.85, [3] = 1.0 }
local QUALITY_WORD = { [0] = "MISS", [1] = "OK", [2] = "GOOD", [3] = "PERFECT" }
local CHALK_TEXTURE = "rbxasset://textures/particles/smoke_main.dds" -- built-in engine texture

type Session = {
	payload: { [string]: any },
	stationId: string,
	stat: string,
	statColor: Color3,
	kind: string,
	continuous: boolean,
	heavy: boolean,
	trove: Trove.Trove,
	minigame: Minigame.Handle?,
	combo: number,
	reps: number,
	gainStat: number,
	gainXP: number,
	gainCash: number,
	cadence: number,
	leaving: boolean,
	-- ui
	holder: Frame,
	panel: CanvasGroup,
	back: Frame,
	backStroke: UIStroke,
	word: TextLabel,
	wordScale: UIScale,
	comboValue: TextLabel,
	comboBonus: TextLabel,
	comboScale: UIScale,
	statGain: TextLabel,
	xpGain: TextLabel,
	cashGain: TextLabel,
	repsLabel: TextLabel,
	chips: Frame,
	chipKey: string,
	leaveCap: TextLabel,
	leaveFill: Frame,
	chalk: { ParticleEmitter },
}

local session: Session? = nil
local eventRemote: RemoteEvent
local repRemote: RemoteEvent
local floaterParent: Instance
local floaterPool: { BillboardGui } = {}
local fovTween: Tween? = nil
local fovBase: number? = nil

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function setting(key: string): any
	return DataController.get({ "Settings", key })
end

local function shortGain(n: number): string
	if n < 10 then
		return string.format("%.1f", n)
	end
	return Format.short(n)
end

local function statShort(stat: string): string
	local def = (Stats.Defs :: any)[stat]
	return if def then def.Short else string.upper(string.sub(stat, 1, 3))
end

local function statColor(stat: string): Color3
	local def = (Stats.Defs :: any)[stat]
	return if def then def.Color else Theme.Color.Accent
end

local function character(): (Model?, BasePart?)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return char, root
end

---------------------------------------------------------------------------
-- Floaters (+12.4 STR rising next to the character)
---------------------------------------------------------------------------
local function floater(text: string, color: Color3, size: number, offset: Vector3, delay: number?)
	local _, root = character()
	if not root then
		return
	end
	local gui = table.remove(floaterPool)
	local label: TextLabel
	if gui then
		label = gui:FindFirstChild("Text") :: TextLabel
	else
		gui = New("BillboardGui", {
			Name = "TrainingFloater",
			AlwaysOnTop = true,
			LightInfluence = 0,
			ResetOnSpawn = false,
			Size = UDim2.fromOffset(240, 40),
			MaxDistance = 120,
		})
		label = C.label({
			Parent = gui,
			Name = "Text",
			Font = Theme.Font.Heavy,
			XAlign = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
		})
		New("UIStroke", {
			Color = Theme.Color.Backdrop,
			Thickness = 1.6,
			Transparency = 0.3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Parent = label,
		})
	end
	local g = gui :: BillboardGui
	local stroke = label:FindFirstChildOfClass("UIStroke") :: UIStroke?
	label.Text = text
	label.TextColor3 = color
	label.TextSize = size
	label.TextTransparency = 0
	if stroke then
		stroke.Transparency = 0.3
	end
	g.Adornee = root
	g.StudsOffsetWorldSpace = offset
	g.Enabled = false
	g.Parent = floaterParent
	task.delay(delay or 0, function()
		g.Enabled = true
		local info = TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(g, info, { StudsOffsetWorldSpace = offset + Vector3.new(0, 1.7, 0) }):Play()
		local fade = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.55)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		if stroke then
			TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		end
		task.delay(1.0, function()
			g.Enabled = false
			g.Adornee = nil :: any
			if #floaterPool < 12 then
				table.insert(floaterPool, g)
			else
				g:Destroy()
			end
		end)
	end)
end

---------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------
local function fovPunch()
	local cam = Workspace.CurrentCamera
	if not cam or fovTween then
		return
	end
	local base = fovBase or cam.FieldOfView
	fovBase = base
	local out = TweenService:Create(cam, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base + 2.6 })
	fovTween = out
	out:Play()
	out.Completed:Once(function()
		local back = TweenService:Create(cam, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { FieldOfView = base })
		fovTween = back
		back:Play()
		back.Completed:Once(function()
			fovTween = nil
			fovBase = nil
		end)
	end)
end

local function makeChalk(s: Session)
	local char = player.Character
	if not char then
		return
	end
	for _, name in { "RightHand", "LeftHand" } do
		local hand = char:FindFirstChild(name)
		if hand and hand:IsA("BasePart") then
			local att = s.trove:Add(New("Attachment", { Name = "ChalkPuff", Parent = hand }))
			local pe: ParticleEmitter = New("ParticleEmitter", {
				Texture = CHALK_TEXTURE,
				Color = ColorSequence.new(Color3.fromRGB(244, 242, 236)),
				LightEmission = 0,
				LightInfluence = 1,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.95) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(0.5, 0.85),
				Speed = NumberRange.new(0.8, 2.2),
				SpreadAngle = Vector2.new(180, 180),
				Drag = 4,
				Acceleration = Vector3.new(0, 0.6, 0),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-40, 40),
				Rate = 0,
				Enabled = false,
				Parent = att,
			})
			table.insert(s.chalk, pe)
		end
	end
end

---------------------------------------------------------------------------
-- Camera framing (rotation only; the player keeps control)
---------------------------------------------------------------------------
local CAMERA_STEP = "IronhavenTrainingCamera"

local function frameCamera(s: Session, station: Model?)
	local cam = Workspace.CurrentCamera
	local _, root = character()
	if not cam or not root or not station or cam.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local pivot = station:GetPivot()
	local right = Vector3.new(pivot.RightVector.X, 0, pivot.RightVector.Z)
	local look = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
	if right.Magnitude < 0.01 or look.Magnitude < 0.01 then
		return
	end
	right, look = right.Unit, look.Unit
	local focus0 = cam.Focus.Position
	if (cam.CFrame.Position - focus0):Dot(right) < 0 then
		right = -right
	end
	local dir = (right * 0.86 + look * 0.42 + Vector3.new(0, 0.42, 0)).Unit
	local started = os.clock()
	local aborted = false
	local function stop()
		pcall(function()
			RunService:UnbindFromRenderStep(CAMERA_STEP)
		end)
	end
	s.trove:Add(stop)
	s.trove:Connect(UserInputService.InputChanged, function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseWheel or t == Enum.UserInputType.Touch then
			aborted = true
		elseif t == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			aborted = true
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 and input.Position.Magnitude > 0.25 then
			aborted = true
		end
	end)
	RunService:BindToRenderStep(CAMERA_STEP, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local elapsed = os.clock() - started
		if aborted or elapsed > 1.1 or cam.CameraType ~= Enum.CameraType.Custom then
			stop()
			return
		end
		local focus = cam.Focus.Position
		local offset = cam.CFrame.Position - focus
		local dist = offset.Magnitude
		if dist < 0.5 then
			return
		end
		local k = 1 - math.exp(-5 * dt)
		local cur = offset.Unit
		local nextDir = cur:Lerp(dir, k)
		if nextDir.Magnitude < 1e-3 then
			return
		end
		cam.CFrame = CFrame.lookAt(focus + nextDir.Unit * dist, focus)
	end)
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local function buildPanel(s: Session, p: { [string]: any })
	local stack = UIController.hud.BottomStack
	local holder = C.frame({ Parent = stack, Name = "TrainingSession", Size = UDim2.fromOffset(PANEL_W, PANEL_H), LayoutOrder = 50 })
	s.trove:Add(holder)
	s.holder = holder

	-- backdrop (plain frame so the border stroke is never clipped) + a
	-- CanvasGroup for the content fade; the group's corner clips the wash
	local back = C.frame({ Parent = holder, Name = "Back", Color = Theme.Color.Surface0, Transparency = 1, Radius = Theme.Radius.Large })
	local backStroke = C.stroke(back, 1)
	local panel: CanvasGroup = New("CanvasGroup", {
		Name = "Panel",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		GroupTransparency = 1,
		Parent = holder,
	})
	C.corner(panel, Theme.Radius.Large)
	s.panel = panel
	s.back = back
	s.backStroke = backStroke
	-- faint stat-coloured wash along the top edge
	local wash = C.frame({ Parent = panel, Size = UDim2.new(1, 0, 0, 46), Color = s.statColor, Transparency = 0.86 })
	New("UIGradient", { Transparency = NumberSequence.new(0.2, 1), Rotation = 90, Parent = wash })

	-- header
	local header = C.frame({ Parent = panel, Name = "Header", Size = UDim2.new(1, -28, 0, 30), Position = UDim2.fromOffset(14, 10) })
	local left = C.frame({ Parent = header, Size = UDim2.new(1, -150, 1, 0) })
	C.list(left, "H", 8, nil, Enum.VerticalAlignment.Center)
	local dot = C.frame({ Parent = left, Size = UDim2.fromOffset(10, 10), Color = s.statColor, Transparency = 0, Radius = Theme.Radius.Pill, LayoutOrder = 1 })
	C.stroke(dot, 0.5, s.statColor, 3)
	C.label({
		Parent = left,
		Text = tostring(p.Name or "Training"),
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Heading,
		Size = UDim2.new(0, 0, 1, 0),
		AutoSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
	})
	local tierIndex = if type(p.Tier) == "number" then p.Tier else 1
	local tier = Tiers.get(tierIndex)
	C.pill({ Parent = left, Text = string.upper(tier.Name), Color = tier.Color, Height = 18, LayoutOrder = 3 })
	if p.Restores then
		C.pill({ Parent = left, Text = "RECOVERY", Color = Theme.Color.Energy, Height = 18, LayoutOrder = 4 })
	end

	-- leave chip (button: hold Space / Backspace / B / tap) + hold progress line
	local leaveWrap = C.frame({
		Parent = header,
		Name = "LeaveWrap",
		Size = UDim2.fromOffset(0, 28),
		AutoSize = Enum.AutomaticSize.X,
		Position = UDim2.fromScale(1, 0.5),
		AnchorPoint = Vector2.new(1, 0.5),
	})
	local leave: TextButton = New("TextButton", {
		Name = "Leave",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Color.Surface2,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = leaveWrap,
	})
	C.corner(leave, Theme.Radius.Pill)
	C.stroke(leave, 0.85)
	C.padding(leave, 0, 10, 0, 6)
	C.list(leave, "H", 6, nil, Enum.VerticalAlignment.Center)
	local capFrame = C.frame({ Parent = leave, Size = UDim2.fromOffset(0, 20), AutoSize = Enum.AutomaticSize.X, Color = Theme.Color.Surface3, Transparency = 0, Radius = Theme.Radius.Small, LayoutOrder = 1 })
	C.padding(capFrame, 0, 6)
	s.leaveCap = C.label({
		Parent = capFrame,
		Text = "",
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Micro,
		Size = UDim2.new(0, 0, 1, 0),
		AutoSize = Enum.AutomaticSize.X,
		XAlign = Enum.TextXAlignment.Center,
	})
	C.label({
		Parent = leave,
		Text = "Leave",
		Font = Theme.Font.SemiBold,
		TextSize = Theme.TextSize.Caption,
		Color = Theme.Color.TextDim,
		Size = UDim2.new(0, 0, 1, 0),
		AutoSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
	})
	local leaveTrack = C.frame({ Parent = leaveWrap, Size = UDim2.new(1, -20, 0, 2), Position = UDim2.new(0, 10, 1, 1), Clip = true })
	s.leaveFill = C.frame({ Parent = leaveTrack, Size = UDim2.fromScale(0, 1), Color = Theme.Color.Accent, Transparency = 0, Radius = Theme.Radius.Pill })
	s.trove:Connect(leave.Activated, function()
		TrainingController.leave("Request")
	end)

	-- footer
	local footer = C.frame({ Parent = panel, Name = "Footer", Size = UDim2.new(1, -28, 0, 40), Position = UDim2.new(0, 14, 1, -48) })
	C.divider(footer).Position = UDim2.fromOffset(0, -6)
	local combo = C.frame({ Parent = footer, Size = UDim2.new(0, 150, 1, 0) })
	local comboRow = C.frame({ Parent = combo, Size = UDim2.fromScale(1, 1) })
	C.list(comboRow, "H", 6, nil, Enum.VerticalAlignment.Center)
	local valueHolder = C.frame({ Parent = comboRow, Size = UDim2.fromOffset(56, 36), LayoutOrder = 1 })
	s.comboScale = New("UIScale", { Parent = valueHolder })
	s.comboValue = C.label({
		Parent = valueHolder,
		Text = "x0",
		Font = Theme.Font.Heavy,
		TextSize = 28,
		Color = Theme.Color.TextMute,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
	})
	local comboText = C.frame({ Parent = comboRow, Size = UDim2.fromOffset(80, 34), LayoutOrder = 2 })
	C.label({ Parent = comboText, Text = "COMBO", Font = Theme.Font.Bold, TextSize = Theme.TextSize.Micro, Color = Theme.Color.TextDim, Size = UDim2.new(1, 0, 0, 14) })
	s.comboBonus = C.label({
		Parent = comboText,
		Text = "Hit Good+ to build",
		TextSize = Theme.TextSize.Micro,
		Color = Theme.Color.TextMute,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 16),
	})

	local gains = C.frame({ Parent = footer, Size = UDim2.new(0, 190, 1, 0), Position = UDim2.fromOffset(148, 0) })
	C.list(gains, "H", 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local function gain(order: number, color: Color3, text: string): TextLabel
		return C.label({
			Parent = gains,
			Text = text,
			Rich = true,
			Font = Theme.Font.Bold,
			TextSize = Theme.TextSize.Body,
			Color = color,
			Size = UDim2.new(0, 0, 1, 0),
			AutoSize = Enum.AutomaticSize.X,
			LayoutOrder = order,
		})
	end
	s.statGain = gain(1, s.statColor, `+0 <font size="11">{statShort(s.stat)}</font>`)
	s.xpGain = gain(2, Theme.Color.XP, `+0 <font size="11">XP</font>`)
	s.cashGain = gain(3, Theme.Color.Cash, "$0")

	local right = C.frame({ Parent = footer, Size = UDim2.new(0, 170, 1, 0), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0) })
	s.repsLabel = C.label({
		Parent = right,
		Text = "0 reps",
		TextSize = Theme.TextSize.Caption,
		Color = Theme.Color.TextDim,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 2),
	})
	s.chips = C.frame({ Parent = right, Name = "Chips", Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 21) })
	C.list(s.chips, "H", 4, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

	-- quality word floating above the panel (outside the CanvasGroup)
	local wordHolder = C.frame({ Parent = holder, Size = UDim2.fromOffset(300, 40), Position = UDim2.new(0.5, 0, 0, -8), AnchorPoint = Vector2.new(0.5, 1), ZIndex = 3 })
	s.wordScale = New("UIScale", { Parent = wordHolder })
	s.word = C.label({
		Parent = wordHolder,
		Text = "",
		Font = Theme.Font.Heavy,
		TextSize = 30,
		XAlign = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		TextTransparency = 1,
	})
	New("UIStroke", { Color = Theme.Color.Backdrop, Thickness = 2, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = s.word })

	-- scale + fade in
	local scale = New("UIScale", { Scale = 0.96, Parent = holder })
	C.tween(panel, Theme.Tween.Slow, { GroupTransparency = 0 })
	C.tween(back, Theme.Tween.Slow, { BackgroundTransparency = Theme.Transparency.Hud })
	C.tween(backStroke, Theme.Tween.Slow, { Transparency = 0.86 })
	C.tween(scale, Theme.Tween.Spring, { Scale = 1 })
end

local function updateLeaveHint(s: Session, device: string)
	if device == "Gamepad" then
		s.leaveCap.Text = "B"
	elseif device == "Touch" then
		s.leaveCap.Text = "TAP"
	else
		s.leaveCap.Text = if HOLD_KINDS[s.kind] then "BACKSPACE" else "HOLD SPACE"
	end
end

-- Multiplier chips: stat multiplier, combo bonus and the most relevant boost.
local function updateMultiplier(s: Session)
	if session ~= s or not s.chips.Parent then
		return
	end
	local json = player:GetAttribute("Multipliers")
	local mult = 1
	if type(json) == "string" then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(json)
		end)
		if ok and type(decoded) == "table" and type(decoded[s.stat]) == "number" then
			mult = decoded[s.stat]
		end
	end
	type Chip = { text: string, color: Color3 }
	local chips: { Chip } = {}
	if mult > 1.001 then
		table.insert(chips, { text = string.format("x%.2f", mult), color = s.statColor })
	end
	local bonus = Formulas.comboBonus(s.combo)
	if bonus > 0 then
		table.insert(chips, { text = "COMBO " .. Format.percentBonus(1 + bonus), color = Theme.Color.Accent })
	end
	local active = DataController.get({ "Boosts" })
	if type(active) == "table" then
		local now = os.time()
		for _, def in Boosts.List do
			local expiry = active[def.Id]
			local relevant = def.Effect == "Window" or def.Effect == "Energy" or (def.Effect == "StatGain" and (def.Stat == "All" or def.Stat == s.stat))
			if relevant and type(expiry) == "number" and expiry > now then
				table.insert(chips, { text = string.upper(def.Name), color = def.Color })
				break
			end
		end
	end
	local parts = {}
	for _, c in chips do
		table.insert(parts, c.text)
	end
	local key = table.concat(parts, "|")
	if key == s.chipKey then
		return
	end
	s.chipKey = key
	for _, child in s.chips:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, c in chips do
		C.pill({ Parent = s.chips, Text = c.text, Color = c.color, Height = 18, LayoutOrder = i })
	end
end

local function showWord(s: Session, q: number)
	s.word.Text = QUALITY_WORD[q] or ""
	s.word.TextColor3 = Minigames.QualityColor[q]
	if q == 3 then
		s.word.TextColor3 = Theme.Color.Accent
	elseif q == 0 then
		s.word.TextColor3 = Color3.fromRGB(226, 120, 110)
	end
	s.word.TextTransparency = 0
	s.word.Position = UDim2.new()
	s.wordScale.Scale = if q == 3 then 1.35 else 1.15
	C.tween(s.wordScale, Theme.Tween.Spring, { Scale = 1 })
	C.tween(s.word, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.35), { TextTransparency = 1, Position = UDim2.fromOffset(0, -10) })
end

---------------------------------------------------------------------------
-- Rep flow
---------------------------------------------------------------------------
local function onLocalGrade(s: Session, q: number)
	if s.leaving then
		return
	end
	repRemote:FireServer({ Quality = q })
	showWord(s, q)
	AudioController.play(if q == 3 then "RepPerfect" elseif q >= 1 then "RepGood" else "RepMiss", if q == 1 then { Volume = 0.6 } else nil)
	local e = StationAnim.get(s.stationId)
	local sound = s.payload.Sound
	if e and e.soundAt and type(sound) == "string" then
		AudioController.play(sound, { At = e.soundAt, Volume = if q == 0 then 0.6 else 1 })
	end
	if s.continuous then
		s.cadence = s.cadence + (CADENCE_TARGET[q] - s.cadence) * 0.5
		AnimationController.setLocalCadence(s.cadence)
	end
	AnimationController.localRep(q)
	if q == 3 then
		if s.heavy and setting("CameraShake") ~= false then
			fovPunch()
		end
		if s.stat == "Strength" and setting("ReducedEffects") ~= true then
			for _, pe in s.chalk do
				if pe.Parent then
					pe:Emit(4)
				end
			end
		end
	end
end

local function onResult(s: Session, r: { [string]: any })
	local gainAmount = if type(r.Gain) == "number" then r.Gain else 0
	local xp = if type(r.XP) == "number" then r.XP else 0
	local cash = if type(r.Cash) == "number" then r.Cash else 0
	local combo = if type(r.Combo) == "number" then r.Combo else 0
	local stat = if type(r.Stat) == "string" then r.Stat else s.stat
	s.reps = if type(r.Reps) == "number" then r.Reps else s.reps + 1
	s.gainStat += gainAmount
	s.gainXP += xp
	s.gainCash += cash

	-- combo
	local prev = s.combo
	s.combo = combo
	if combo > prev then
		s.comboValue.Text = "x" .. combo
		s.comboValue.TextColor3 = if combo >= 10 then Theme.Color.Accent else Theme.Color.Text
		s.comboScale.Scale = if combo % 5 == 0 then 1.45 else 1.22
		C.tween(s.comboScale, Theme.Tween.Spring, { Scale = 1 })
	elseif combo == 0 and prev > 0 then
		s.comboValue.Text = "x0"
		s.comboValue.TextColor3 = Theme.Color.TextMute
		if prev >= 3 then
			AudioController.play("ComboBreak")
			s.comboScale.Scale = 0.85
			C.tween(s.comboScale, Theme.Tween.Spring, { Scale = 1 })
		end
	end
	local bonus = Formulas.comboBonus(combo)
	s.comboBonus.Text = if combo > 0 then `{Format.percentBonus(1 + bonus)} gains` else "Hit Good+ to build"
	s.comboBonus.TextColor3 = if combo > 0 then Theme.Color.Accent else Theme.Color.TextMute

	-- totals
	s.statGain.Text = `+{shortGain(s.gainStat)} <font size="11">{statShort(s.stat)}</font>`
	s.xpGain.Text = `+{Format.short(s.gainXP)} <font size="11">XP</font>`
	s.cashGain.Text = "$" .. Format.short(s.gainCash)
	s.repsLabel.Text = `{s.reps} rep{if s.reps == 1 then "" else "s"}`
	updateMultiplier(s)

	-- floaters
	local side = if s.reps % 2 == 0 then 1 else -1
	floater(`+{shortGain(gainAmount)} {statShort(stat)}`, statColor(stat), 24, Vector3.new(side * 1.6, 2.6, 0))
	if xp > 0 then
		floater(`+{Format.short(xp)} XP`, Theme.Color.XP, 17, Vector3.new(side * 1.9, 2.0, 0), 0.08)
	end
	if cash > 0 then
		floater("+$" .. Format.short(cash), Theme.Color.Cash, 17, Vector3.new(side * 1.3, 1.6, 0), 0.16)
	end
end

---------------------------------------------------------------------------
-- Session lifecycle
---------------------------------------------------------------------------
local function endSession(reason: string, summary: { [string]: any }?)
	local s = session
	if not s then
		return
	end
	session = nil
	s.leaving = true
	if s.minigame then
		s.minigame.stop()
		s.minigame = nil
	end
	AnimationController.setLocalDriven(false)
	State.set("Minigame", false)
	State.set("Training", false)
	local right = UIController.hud.Right
	if right and right:GetAttribute("TrainingHidden") then
		right:SetAttribute("TrainingHidden", nil)
		right.Visible = true
	end

	-- fade the panel out, then clean up
	C.tween(s.panel, Theme.Tween.Base, { GroupTransparency = 1 })
	C.tween(s.back, Theme.Tween.Base, { BackgroundTransparency = 1 })
	C.tween(s.backStroke, Theme.Tween.Base, { Transparency = 1 })
	task.delay(0.25, function()
		s.trove:Clean()
	end)

	if reason == "OutOfEnergy" then
		NotificationController.toast("Out of energy", "Grab a drink at the Juice Bar in the Lounge, or recharge in the Recovery Studio downstairs.", "Warning")
	elseif reason == "Idle" then
		NotificationController.toast("Set ended", "You were idle for a while, so we freed the station.", "Info")
	elseif reason == "StationRemoved" or reason == "StationTaken" then
		NotificationController.toast("Set ended", "This station is no longer available.", "Info")
	end
	local voluntary = reason == "Request" or reason == "Jump"
	if voluntary and summary and type(summary.Reps) == "number" and summary.Reps >= 3 then
		local stat = if type(summary.Stat) == "string" then summary.Stat else s.stat
		local gainText = shortGain(if type(summary.StatGain) == "number" then summary.StatGain else s.gainStat)
		NotificationController.toast("Set complete", `{summary.Reps} reps · +{gainText} {stat} · +{Format.short(s.gainXP)} XP`, "Success")
	end
end

function TrainingController.leave(reason: string?)
	local s = session
	if not s or s.leaving then
		return
	end
	s.leaving = true
	s.leaveFill.Size = UDim2.fromScale(1, 1)
	task.spawn(function()
		local ok = Net.request("Training.Stop", { Reason = reason or "Request" })
		if not ok and session == s then
			s.leaving = false -- server refused / connection hiccup: stay in the set
			s.leaveFill.Size = UDim2.fromScale(0, 1)
		end
	end)
end

function TrainingController.isTraining(): boolean
	return session ~= nil
end

local function bindLeaveInputs(s: Session)
	local holdStart: number? = nil
	s.trove:Connect(UserInputService.InputBegan, function(input: InputObject)
		if UserInputService:GetFocusedTextBox() or State.get("Window") then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.ButtonB or key == Enum.KeyCode.Backspace then
			TrainingController.leave("Request")
		elseif key == Enum.KeyCode.Space and not HOLD_KINDS[s.kind] then
			holdStart = os.clock()
		end
	end)
	s.trove:Connect(UserInputService.InputEnded, function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Space then
			holdStart = nil
			if not s.leaving then
				s.leaveFill.Size = UDim2.fromScale(0, 1)
			end
		end
	end)
	s.trove:Connect(RunService.PreRender, function()
		local start = holdStart
		if start and not s.leaving then
			local k = (os.clock() - start) / LEAVE_HOLD
			s.leaveFill.Size = UDim2.fromScale(math.clamp(k, 0, 1), 1)
			if k >= 1 then
				holdStart = nil
				TrainingController.leave("Jump")
			end
		end
	end)
end

local function startSession(p: { [string]: any })
	if session then
		endSession("Replaced", nil)
	end
	local kind = if type(p.Kind) == "string" then p.Kind else "Timing"
	local stat = if type(p.Stat) == "string" then p.Stat else "Strength"
	local stationType = if type(p.StationType) == "string" then p.StationType else ""
	local def = Stations.get(stationType)
	local params: { [string]: number } = {}
	if type(p.Params) == "table" then
		for k, v in p.Params do
			if type(k) == "string" and type(v) == "number" then
				params[k] = v
			end
		end
	end
	local s: Session = {
		payload = p,
		stationId = if type(p.StationId) == "string" then p.StationId else "",
		stat = stat,
		statColor = statColor(stat),
		kind = kind,
		continuous = p.Continuous == true,
		heavy = def ~= nil and HEAVY_SOUNDS[def.Sound] == true,
		trove = Trove.new(),
		minigame = nil,
		combo = 0,
		reps = 0,
		gainStat = 0,
		gainXP = 0,
		gainCash = 0,
		cadence = 0.5,
		leaving = false,
		chalk = {},
		chipKey = "",
	} :: any
	session = s
	State.set("Training", true)
	State.set("Minigame", true)
	AnimationController.setLocalDriven(true)
	if s.continuous then
		AnimationController.setLocalCadence(s.cadence)
	end

	buildPanel(s, p)
	updateMultiplier(s)
	s.trove:Connect(player:GetAttributeChangedSignal("Multipliers"), function()
		updateMultiplier(s)
	end)
	s.trove:Add(DataController.observe("Boosts", function()
		updateMultiplier(s)
	end))

	-- the minigame lives over the panel body (outside the CanvasGroup so touch
	-- buttons beside the panel are not clipped)
	local area = C.frame({ Parent = s.holder, Name = "GameArea", Size = UDim2.new(1, -28, 0, GAME_H), Position = UDim2.fromOffset(14, 44), ZIndex = 2 })
	task.delay(0.12, function()
		if session ~= s or s.leaving then
			return
		end
		local ok, handle = pcall(Minigame.run, kind, params, area, function(q: number)
			if session == s then
				onLocalGrade(s, q)
			end
		end, { Accent = s.statColor } :: Minigame.Options)
		if ok then
			s.minigame = handle
		else
			warn("[TrainingController] minigame failed: " .. tostring(handle))
		end
	end)

	-- leave hint follows the active device
	updateLeaveHint(s, TrainingInput.currentDevice())
	s.trove:Connect(UserInputService.LastInputTypeChanged, function()
		updateLeaveHint(s, TrainingInput.currentDevice())
	end)
	bindLeaveInputs(s)

	-- no other station prompts while on a station (local only, restored on leave)
	if ProximityPromptService.Enabled then
		ProximityPromptService.Enabled = false
		s.trove:Add(function()
			ProximityPromptService.Enabled = true
		end)
	end

	-- quiet the HUD a little (mission tracker); currencies stay
	local right = UIController.hud.Right
	if right and right.Visible then
		right:SetAttribute("TrainingHidden", true)
		right.Visible = false
	end

	if s.stat == "Strength" then
		makeChalk(s)
	end
	local e = StationAnim.get(s.stationId)
	frameCamera(s, if e then e.model else nil)

	-- our own character died / respawned: the server ends the set too, but
	-- never leave the UI hanging if that message is lost
	local char = player.Character
	if char then
		s.trove:Connect(char.AncestryChanged, function(_, parent: Instance?)
			if not parent and session == s then
				endSession("CharacterRemoved", nil)
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------
function TrainingController.Init()
	eventRemote = Net.event("TrainingEvent")
	repRemote = Net.event("TrainingRep")
	-- BillboardGuis directly under PlayerGui (ResetOnSpawn off) render via Adornee
	floaterParent = player:WaitForChild("PlayerGui")

	eventRemote.OnClientEvent:Connect(function(kind: any, payload: any)
		if type(kind) ~= "string" or type(payload) ~= "table" then
			return
		end
		if kind == "Started" then
			startSession(payload)
		elseif kind == "Rep" then
			local s = session
			if s then
				onResult(s, payload)
			end
		elseif kind == "Stopped" then
			endSession(if type(payload.Reason) == "string" then payload.Reason else "Request", payload)
		end
	end)
end

return TrainingController
