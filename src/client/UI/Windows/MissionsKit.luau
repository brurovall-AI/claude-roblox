--!strict
--[[
	MissionsKit: helpers shared by the goal / progression screens
	(Missions, Daily, Stats windows, HUD tracker, tutorial card).

		Kit.now() / Kit.today() / Kit.untilDayReset() / Kit.untilWeekReset()
			server-synced clock (Workspace:GetServerTimeNow) + UTC reset maths
		Kit.request(action, payload, opts?)   Net.request + sound + error toast (yields)
		Kit.section(parent, text, order?)     small-caps muted section label
		Kit.rewardItems(reward)               reward bundle -> { Icon, Color, Text }
		Kit.rewardChips(parent, reward, props?)  row of icon chips for a reward
		Kit.rewardText(reward)                "$1.2K · 340 XP"
		Kit.grid(parent, props)               responsive auto-height grid
		Kit.missionVisual(template)           icon + colour for a mission's event
		Kit.achievementProgress(def, data)    (current, target, done) — mirrors AchievementService
		Kit.dailyPreview(data, today) / Kit.dailyReward(day, cycle, level, vip)
			mirrors DailyRewardService (streak / cycle / reward maths)
		Kit.watch(roots, fn)                  deferred DataController hook for top-level roots
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local Achievements = require(Config.Achievements)
local Boosts = require(Config.Boosts)
local Companions = require(Config.Companions)
local Cosmetics = require(Config.Cosmetics)
local DailyRewards = require(Config.DailyRewards)
local DataSchema = require(Shared.DataSchema)
local Format = require(Shared.Util.Format)
local Missions = require(Config.Missions)
local Net = require(Shared.Util.Net)
local Progression = require(Config.Progression)
local Rewards = require(Config.Rewards)
local Stats = require(Config.Stats)

local UI = script.Parent.Parent
local C = require(UI.Components)
local Icons = require(UI.Icons)
local New = require(UI.Create)
local Theme = require(UI.Theme)

local Controllers = UI.Parent.Controllers
local AudioController = require(Controllers.AudioController)
local DataController = require(Controllers.DataController)
local NotificationController = require(Controllers.NotificationController)

local Kit = {}

export type RewardItem = { Icon: string, Color: Color3, Text: string }

Kit.CategoryIcon = {
	Training = "flame",
	Progress = "up",
	Compete = "trophy",
	Social = "social",
} :: { [string]: string }

---------------------------------------------------------------------------
-- Time (server-synced so countdowns match the server's UTC resets)
---------------------------------------------------------------------------
function Kit.now(): number
	return Workspace:GetServerTimeNow()
end

function Kit.today(): number
	return DataSchema.dayNumber(Kit.now())
end

function Kit.untilDayReset(): number
	local t = Kit.now()
	return (DataSchema.dayNumber(t) + 1) * 86400 - t
end

-- Weeks start Monday 00:00 UTC (see DataSchema.weekNumber).
function Kit.untilWeekReset(): number
	local t = Kit.now()
	return ((DataSchema.weekNumber(t) + 1) * 7 - 3) * 86400 - t
end

---------------------------------------------------------------------------
-- Requests
---------------------------------------------------------------------------
export type RequestOpts = { Sound: string?, FailTitle: string? }

-- Yields. Success plays `Sound` (default none: the server's Reward toast has
-- its own); failures toast the server's message.
function Kit.request(action: string, payload: any?, opts: RequestOpts?): (boolean, any)
	local ok, result = Net.request(action, payload)
	local o: RequestOpts = opts or {}
	if ok then
		local sound = o.Sound or ""
		if sound ~= "" then
			AudioController.play(sound)
		end
	else
		-- Error toasts play UIError themselves
		NotificationController.toast(o.FailTitle or "Couldn't claim that", if type(result) == "string" then result else "Please try again.", "Error")
	end
	return ok, result
end

-- Calls `fn` (deferred, at most once per frame) when any top-level data root in
-- `roots` changes or the whole replica is replaced. Returns a disconnect fn.
function Kit.watch(roots: { string }, fn: () -> ()): () -> ()
	local set: { [string]: boolean } = { [""] = true }
	for _, k in roots do
		set[k] = true
	end
	local queued = false
	local conn = DataController.Changed:Connect(function(key: string)
		local top = string.match(key, "^[^%.]+") or ""
		if set[top] and not queued then
			queued = true
			task.defer(function()
				queued = false
				fn()
			end)
		end
	end)
	return function()
		conn:Disconnect()
	end
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
function Kit.section(parent: Instance, text: string, order: number?): TextLabel
	return C.label({
		Parent = parent,
		LayoutOrder = order,
		Text = string.upper(text),
		Font = Theme.Font.Heavy,
		TextSize = Theme.TextSize.Caption,
		Color = Theme.Color.TextMute,
		Size = UDim2.new(1, 0, 0, 20),
	})
end

local function scaleOf(inst: Instance): number
	local s = 1
	local node: Instance? = inst
	while node do
		local sc = node:FindFirstChildOfClass("UIScale") :: UIScale?
		if sc then
			s *= sc.Scale
		end
		node = node.Parent
	end
	return s
end

-- Auto-height grid: as many MinWidth columns as fit (capped by MaxColumns),
-- stretched to fill the row. Props: MinWidth, Height, Gap, MaxColumns, LayoutOrder.
function Kit.grid(parent: Instance, props: { [string]: any }): Frame
	local minW: number = props.MinWidth or 160
	local h: number = props.Height or 120
	local gap: number = props.Gap or 10
	local f = C.frame({ Parent = parent, Name = props.Name or "Grid", LayoutOrder = props.LayoutOrder, Size = UDim2.new(1, 0, 0, 0), AutoSize = Enum.AutomaticSize.Y })
	local layout: UIGridLayout = New("UIGridLayout", {
		CellPadding = UDim2.fromOffset(gap, gap),
		CellSize = UDim2.fromOffset(minW, h),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = f,
	})
	local lastW = -1
	local function fit()
		local scale = scaleOf(f)
		if scale <= 0 or f.AbsoluteSize.X <= 0 then
			return
		end
		local w = math.floor(f.AbsoluteSize.X / scale)
		if w == lastW then
			return
		end
		lastW = w
		local cols = math.max(1, math.floor((w + gap) / (minW + gap)))
		if props.MaxColumns then
			cols = math.min(cols, props.MaxColumns)
		end
		layout.CellSize = UDim2.fromOffset(math.floor((w - gap * (cols - 1)) / cols), h)
	end
	f:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.defer(fit)
	return f
end

---------------------------------------------------------------------------
-- Rewards
---------------------------------------------------------------------------
function Kit.rewardItems(reward: Rewards.Reward): { RewardItem }
	local out: { RewardItem } = {}
	if reward.Cash and reward.Cash > 0 then
		table.insert(out, { Icon = "cash", Color = Theme.Color.Cash, Text = "$" .. Format.short(reward.Cash) })
	end
	if reward.XP and reward.XP > 0 then
		table.insert(out, { Icon = "star", Color = Theme.Color.XP, Text = Format.short(reward.XP) .. " XP" })
	end
	if reward.Trophies and reward.Trophies > 0 then
		table.insert(out, { Icon = "trophy", Color = Theme.Color.Trophy, Text = Format.short(reward.Trophies) })
	end
	if reward.RebirthTokens and reward.RebirthTokens > 0 then
		table.insert(out, { Icon = "token", Color = Theme.Color.Token, Text = tostring(reward.RebirthTokens) })
	end
	if reward.Boosts then
		for _, def in Boosts.List do
			local n = reward.Boosts[def.Id]
			if n and n > 0 then
				table.insert(out, { Icon = "boost", Color = def.Color, Text = if n > 1 then `{def.Name} x{n}` else def.Name })
			end
		end
	end
	if reward.Title then
		local t = Cosmetics.Titles[reward.Title]
		if t then
			table.insert(out, { Icon = "user", Color = t.Color, Text = `"{t.Text}"` })
		end
	end
	if reward.Emote then
		local e = Cosmetics.Emotes[reward.Emote]
		if e then
			table.insert(out, { Icon = "emote", Color = Theme.Color.Info, Text = e.Name })
		end
	end
	if reward.Aura then
		local a = Cosmetics.Auras[reward.Aura]
		if a then
			table.insert(out, { Icon = "star", Color = Theme.Color.Token, Text = a.Name .. " aura" })
		end
	end
	if reward.Decor then
		local d = Cosmetics.Decor[reward.Decor]
		if d then
			table.insert(out, { Icon = "trophy", Color = Theme.Color.TextDim, Text = d.Name })
		end
	end
	if reward.Companion then
		local c = Companions.Defs[reward.Companion]
		if c then
			table.insert(out, { Icon = "companion", Color = Theme.Color.Success, Text = c.Name })
		end
	end
	return out
end

function Kit.rewardText(reward: Rewards.Reward): string
	local parts: { string } = {}
	for _, item in Kit.rewardItems(reward) do
		table.insert(parts, item.Text)
	end
	return table.concat(parts, " · ")
end

-- Compact chip row. Props: LayoutOrder, Size, Position, AnchorPoint, Align ("Left"|"Right"), Max.
function Kit.rewardChips(parent: Instance, reward: Rewards.Reward, props: { [string]: any }?): Frame
	local p: { [string]: any } = props or {}
	local row = C.frame({
		Parent = parent,
		Name = "Rewards",
		LayoutOrder = p.LayoutOrder,
		Size = p.Size or UDim2.new(1, 0, 0, 24),
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
	})
	C.list(row, "H", 6, if p.Align == "Right" then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	for i, item in Kit.rewardItems(reward) do
		if p.Max and i > p.Max then
			break
		end
		local chip = C.frame({
			Parent = row,
			LayoutOrder = i,
			Size = UDim2.fromOffset(0, 24),
			AutoSize = Enum.AutomaticSize.X,
			Color = Theme.Color.Surface2,
			Transparency = 0.15,
			Radius = Theme.Radius.Pill,
		})
		C.padding(chip, 0, 9, 0, 6)
		C.list(chip, "H", 5, nil, Enum.VerticalAlignment.Center)
		local icon = Icons.make(item.Icon, 14, item.Color)
		icon.LayoutOrder = 1
		icon.Parent = chip
		C.label({
			Parent = chip,
			LayoutOrder = 2,
			Text = item.Text,
			Font = Theme.Font.Bold,
			TextSize = Theme.TextSize.Caption - 1,
			Size = UDim2.new(0, 0, 1, 0),
			AutoSize = Enum.AutomaticSize.X,
		})
	end
	return row
end

---------------------------------------------------------------------------
-- Missions & achievements
---------------------------------------------------------------------------
local EVENT_VISUAL: { [string]: { icon: string, color: Color3 } } = {
	Rep = { icon = "flame", color = Theme.Color.Accent },
	PerfectRep = { icon = "star", color = Theme.Color.Success },
	ComboReached = { icon = "flame", color = Color3.fromRGB(236, 120, 96) },
	TrainCash = { icon = "cash", color = Theme.Color.Cash },
	BoostBought = { icon = "boost", color = Color3.fromRGB(240, 146, 60) },
	EventJoined = { icon = "trophy", color = Theme.Color.Trophy },
	EventPodium = { icon = "trophy", color = Theme.Color.Trophy },
	DuelWin = { icon = "ranks", color = Color3.fromRGB(232, 92, 74) },
	PartyRep = { icon = "party", color = Theme.Color.Info },
	CourseFinish = { icon = "clock", color = Color3.fromRGB(86, 196, 128) },
	NewStationToday = { icon = "stats", color = Theme.Color.Info },
	LevelUp = { icon = "up", color = Theme.Color.XP },
	DailyMissionDone = { icon = "daily", color = Theme.Color.Accent },
}

function Kit.missionVisual(t: Missions.MissionTemplate): (string, Color3)
	local stat = string.match(t.Event, "^Rep:(%a+)$")
	if stat and Stats.isStat(stat) then
		return "stats", Stats.Defs[stat :: Stats.StatId].Color
	end
	local v = EVENT_VISUAL[t.Event]
	if v then
		return v.icon, v.color
	end
	return "missions", Theme.Color.Accent
end

function Kit.missionText(t: Missions.MissionTemplate, target: number): string
	local n = if string.find(t.Text, "%${n}") then Format.short(target) else Format.commas(target)
	return (string.gsub(t.Text, "{n}", n))
end

local function countTrue(t: any): number
	local n = 0
	if type(t) == "table" then
		for _, v in t do
			if v == true then
				n += 1
			end
		end
	end
	return n
end

-- Mirrors AchievementService.progress so bars match what the server unlocks.
function Kit.achievementProgress(def: Achievements.AchievementDef, data: DataSchema.PlayerData): (number, number, boolean)
	local target = def.Target
	local track = def.Track
	if track == "Counter" then
		local v = data.Counters[def.Key or ""] or 0
		return v, target, v >= target
	elseif track == "Min" then
		local v = data.Counters[def.Key or ""] or 0
		return v, target, v > 0 and v <= target
	elseif track == "Level" then
		return data.Level, target, data.Level >= target
	elseif track == "Power" then
		local p = Progression.power(data.Stats :: any)
		return p, target, p >= target
	elseif track == "Rebirths" then
		return data.Rebirths, target, data.Rebirths >= target
	elseif track == "Owned" then
		local n = countTrue(data.Owned.Companions)
		return n, target, n >= target
	elseif track == "Visited" then
		local n = countTrue(data.Visited)
		return n, target, n >= target
	elseif track == "Streak" then
		return data.Daily.Best, target, data.Daily.Best >= target
	end
	return 0, target, false
end

---------------------------------------------------------------------------
-- Daily rewards (mirrors DailyRewardService)
---------------------------------------------------------------------------
Kit.DailyMaxCycle = 5 -- keep in sync with DailyRewardService.MaxCycle

export type DailyPreview = { Claimable: boolean, Streak: number, Day: number, Cycle: number, Reset: boolean }

function Kit.dailyPreview(data: DataSchema.PlayerData, today: number): DailyPreview
	local d = data.Daily
	local days = #DailyRewards.Days
	local last = d.LastClaimDay
	if last >= today and last > 0 then
		local day = (math.max(d.Streak, 1) - 1) % days + 1
		return { Claimable = false, Streak = d.Streak, Day = day, Cycle = math.max(1, d.Cycle), Reset = false }
	end
	local continuing = last > 0 and today - last == 1 and d.Streak > 0
	local streak = if continuing then d.Streak + 1 else 1
	return {
		Claimable = true,
		Streak = streak,
		Day = (streak - 1) % days + 1,
		Cycle = (streak - 1) // days + 1,
		Reset = not continuing and d.Streak > 0,
	}
end

function Kit.dailyReward(day: number, cycle: number, level: number, vip: boolean): Rewards.Reward
	local reward = DailyRewards.scaled(day, math.min(cycle, Kit.DailyMaxCycle), level)
	if vip then
		local boosts: { [string]: number } = if reward.Boosts then table.clone(reward.Boosts) else {}
		boosts.PreWorkout = (boosts.PreWorkout or 0) + 1
		reward.Boosts = boosts
	end
	return reward
end

return Kit
