--!strict
--[[
	Missions window body: Daily / Weekly / Achievements tabs.

		local view = MissionsWindow.build(body)
		view.refresh()        -- re-reads DataController (cheap; updates in place)
		view.opened() / view.closed()   -- start / stop the reset countdown
		view.select("Weekly")

	Mission cards: event icon, text, progress bar + count, reward preview chips
	and a claim button (Claim / progress / Claimed). Weekly adds the all-clear
	bonus card. Achievements: unlocked summary, category filter chips, rows with
	progress toward the target (locked first, unlocked at the bottom).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared.Config
local Achievements = require(Config.Achievements)
local DataSchema = require(Shared.DataSchema)
local Format = require(Shared.Util.Format)
local Missions = require(Config.Missions)

local UI = script.Parent.Parent
local C = require(UI.Components)
local Icons = require(UI.Icons)
local New = require(UI.Create)
local Theme = require(UI.Theme)
local Kit = require(script.Parent.MissionsKit)

local Controllers = UI.Parent.Controllers
local AudioController = require(Controllers.AudioController)
local DataController = require(Controllers.DataController)

type MissionState = DataSchema.MissionState
type Template = Missions.MissionTemplate
type AchievementDef = Achievements.AchievementDef

export type View = {
	refresh: () -> (),
	opened: () -> (),
	closed: () -> (),
	select: (tab: string) -> (),
}

local MissionsWindow = {}

local CARD_H = 86
local DONE_STROKE = Theme.Color.Accent

-- Diffing setter so frequent refreshes never restart button tweens.
local function buttonSetter(api: C.ButtonApi): (text: string, style: C.ButtonStyle, disabled: boolean) -> ()
	local lastText, lastStyle, lastDisabled = "", "", false
	local first = true
	return function(text: string, style: C.ButtonStyle, disabled: boolean)
		if first or text ~= lastText then
			lastText = text
			api.setText(text)
		end
		if first or style ~= lastStyle then
			lastStyle = style
			api.setStyle(style)
		end
		if first or disabled ~= lastDisabled then
			lastDisabled = disabled
			api.setDisabled(disabled)
		end
		first = false
	end
end

---------------------------------------------------------------------------
-- Mission card
---------------------------------------------------------------------------
type MissionCard = {
	Frame: Frame,
	update: (m: MissionState, t: Template, level: number, busy: boolean) -> (),
	flash: () -> (),
}

local function missionCard(parent: Instance, order: number, onClaim: () -> ()): MissionCard
	local card = C.frame({ Parent = parent, Name = "Mission", LayoutOrder = order, Size = UDim2.new(1, 0, 0, CARD_H), Color = Theme.Color.Surface1, Transparency = 0, Radius = Theme.Radius.Medium })
	local stroke = C.stroke(card, 0.9)
	C.padding(card, 12, 12, 12, 12)

	local badgeHolder = C.frame({ Parent = card, Size = UDim2.fromOffset(42, 42), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	local col = C.frame({ Parent = card, Name = "Info", Size = UDim2.new(1, -(54 + 126), 1, 0), Position = UDim2.fromOffset(54, 0) })
	local title = C.label({ Parent = col, Text = "", Font = Theme.Font.Bold, TextSize = Theme.TextSize.Body, Size = UDim2.new(1, -70, 0, 20) })
	local count = C.label({
		Parent = col,
		Text = "",
		Font = Theme.Font.SemiBold,
		TextSize = Theme.TextSize.Caption,
		Color = Theme.Color.TextDim,
		XAlign = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 70, 0, 20),
		Position = UDim2.new(1, -70, 0, 0),
	})
	local bar, setBar = C.progress({ Parent = col, Size = UDim2.new(1, 0, 0, 6), Position = UDim2.fromOffset(0, 26) })
	local fill = bar:FindFirstChild("Fill") :: Frame
	local rewards = C.frame({ Parent = col, Name = "RewardSlot", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 38) })

	local button = C.button({
		Parent = card,
		Text = "Claim",
		Style = "Primary",
		Size = UDim2.fromOffset(114, 40),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		TextSize = Theme.TextSize.Caption + 1,
		OnClick = onClaim,
	})
	local setButton = buttonSetter(button)

	local shownId: string? = nil
	local shownLevel = -1
	local shownStyle = ""
	local function update(m: MissionState, t: Template, level: number, busy: boolean)
		if shownId ~= m.Id or shownLevel ~= level then
			shownId = m.Id
			shownLevel = level
			badgeHolder:ClearAllChildren()
			local icon, color = Kit.missionVisual(t)
			C.iconBadge({ Parent = badgeHolder, Icon = icon, Color = color, Size = 42 })
			fill.BackgroundColor3 = color
			title.Text = Kit.missionText(t, m.Target)
			rewards:ClearAllChildren()
			Kit.rewardChips(rewards, t.Reward(level), { Size = UDim2.fromScale(1, 1) })
		end
		local done = m.Progress >= m.Target
		setBar(m.Progress / math.max(1, m.Target), true)
		count.Text = `{Format.short(math.floor(m.Progress))} / {Format.short(m.Target)}`

		local style: string
		if m.Claimed then
			style = "Claimed"
			setButton("Claimed", "Ghost", true)
		elseif done then
			style = if busy then "Busy" else "Claim"
			setButton(if busy then "Claiming…" else "Claim", "Primary", busy)
		else
			style = "Progress"
			setButton(`{math.floor(math.clamp(m.Progress / math.max(1, m.Target), 0, 1) * 100)}%`, "Secondary", true)
		end
		if style ~= shownStyle then
			shownStyle = style
			card.BackgroundTransparency = if m.Claimed then 0.45 else 0
			title.TextColor3 = if m.Claimed then Theme.Color.TextDim else Theme.Color.Text
			stroke.Color = if style == "Claim" or style == "Busy" then DONE_STROKE else Theme.Color.Stroke
			stroke.Transparency = if style == "Claim" or style == "Busy" then 0.45 else 0.9
			rewards.Visible = not m.Claimed
		end
	end

	local function flash()
		stroke.Color = Theme.Color.Success
		stroke.Transparency = 0.1
		C.tween(stroke, Theme.Tween.Slow, { Transparency = 0.9 })
	end

	return { Frame = card, update = update, flash = flash }
end

---------------------------------------------------------------------------
-- Category chips (achievement filter)
---------------------------------------------------------------------------
local function chips(parent: Instance, items: { { Id: string, Label: string } }, onSelect: (id: string) -> ()): Frame
	local bar = C.frame({ Parent = parent, Name = "Filters", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 70) })
	C.list(bar, "H", 6, nil, Enum.VerticalAlignment.Center)
	type Chip = { button: TextButton, label: TextLabel, stroke: UIStroke }
	local all: { [string]: Chip } = {}
	local current = ""
	local function paint()
		for id, chip in all do
			local on = id == current
			C.tween(chip.button, Theme.Tween.Fast, { BackgroundColor3 = if on then Theme.Color.Surface3 else Theme.Color.Surface1 })
			chip.stroke.Color = if on then Theme.Color.Accent else Theme.Color.Stroke
			chip.stroke.Transparency = if on then 0.35 else 0.88
			chip.label.TextColor3 = if on then Theme.Color.Text else Theme.Color.TextDim
		end
	end
	local function select(id: string)
		if id == current then
			return
		end
		current = id
		paint()
		onSelect(id)
	end
	for i, item in items do
		local b: TextButton = New("TextButton", {
			Name = item.Id,
			AutoButtonColor = false,
			Text = "",
			BorderSizePixel = 0,
			BackgroundColor3 = Theme.Color.Surface1,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = i,
			Parent = bar,
		})
		C.corner(b, Theme.Radius.Pill)
		local stroke = C.stroke(b, 0.88)
		C.padding(b, 0, 12)
		local label = C.label({ Parent = b, Text = item.Label, Font = Theme.Font.Bold, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextDim, Size = UDim2.new(0, 0, 1, 0), AutoSize = Enum.AutomaticSize.X })
		all[item.Id] = { button = b, label = label, stroke = stroke }
		b.Activated:Connect(function()
			AudioController.play("UIClick")
			select(item.Id)
		end)
	end
	select(items[1].Id)
	return bar
end

---------------------------------------------------------------------------
-- Achievement row
---------------------------------------------------------------------------
type AchievementRow = { Frame: Frame, def: AchievementDef, update: (data: DataSchema.PlayerData) -> boolean }

local function achievementRow(parent: Instance, def: AchievementDef): AchievementRow
	local row = C.frame({ Parent = parent, Name = def.Id, LayoutOrder = def.Order, Size = UDim2.new(1, 0, 0, 68), Color = Theme.Color.Surface1, Transparency = 0, Radius = Theme.Radius.Medium })
	local stroke = C.stroke(row, 0.9)
	C.padding(row, 12, 12, 12, 12)
	local badgeHolder = C.frame({ Parent = row, Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	local info = C.frame({ Parent = row, Size = UDim2.new(1, -(52 + 206), 1, 0), Position = UDim2.fromOffset(52, 0) })
	C.label({ Parent = info, Text = def.Name, Font = Theme.Font.Bold, TextSize = Theme.TextSize.Body, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 1) })
	C.label({ Parent = info, Text = def.Description, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextDim, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 23) })

	local right = C.frame({ Parent = row, Size = UDim2.new(0, 196, 1, 0), Position = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(1, 0) })
	Kit.rewardChips(right, def.Reward, { Align = "Right", Max = 2, Size = UDim2.new(1, 0, 0, 22) })
	local count = C.label({ Parent = right, Text = "", Font = Theme.Font.SemiBold, TextSize = Theme.TextSize.Micro + 1, Color = Theme.Color.TextDim, Size = UDim2.new(0, 70, 0, 14), Position = UDim2.fromOffset(0, 28) })
	local bar, setBar = C.progress({ Parent = right, Size = UDim2.new(1, -76, 0, 6), Position = UDim2.new(1, 0, 0, 32), AnchorPoint = Vector2.new(1, 0), Color = Theme.Color.Trophy })
	local unlockedPill = C.frame({ Parent = right, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 28), Visible = false })
	C.list(unlockedPill, "H", 5, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local check = Icons.make("check", 12, Theme.Color.Success)
	check.LayoutOrder = 1
	check.Parent = unlockedPill
	C.label({ Parent = unlockedPill, LayoutOrder = 2, Text = "UNLOCKED", Font = Theme.Font.Heavy, TextSize = Theme.TextSize.Micro, Color = Theme.Color.Success, Size = UDim2.new(0, 0, 1, 0), AutoSize = Enum.AutomaticSize.X })

	local shownUnlocked: boolean? = nil
	local function update(data: DataSchema.PlayerData): boolean
		local unlocked = data.Achievements[def.Id] == true
		local cur, target, _ = Kit.achievementProgress(def, data)
		if def.Track == "Min" then
			-- best time: closer to the target fills the bar
			count.Text = if cur > 0 then `Best {Format.seconds(cur)}` else "No time yet"
			setBar(if cur > 0 then math.clamp(target / cur, 0, 1) else 0, false)
		else
			count.Text = `{Format.short(math.min(cur, target))} / {Format.short(target)}`
			setBar(cur / math.max(1, target), false)
		end
		if unlocked ~= shownUnlocked then
			shownUnlocked = unlocked
			badgeHolder:ClearAllChildren()
			C.iconBadge({
				Parent = badgeHolder,
				Icon = Kit.CategoryIcon[def.Category] or "trophy",
				Color = if unlocked then Theme.Color.Trophy else Theme.Color.TextMute,
				Size = 40,
				Transparency = if unlocked then 0.78 else 0.9,
			})
			stroke.Color = if unlocked then Theme.Color.Trophy else Theme.Color.Stroke
			stroke.Transparency = if unlocked then 0.7 else 0.9
			count.Visible = not unlocked
			bar.Visible = not unlocked
			unlockedPill.Visible = unlocked
			row.LayoutOrder = def.Order + (if unlocked then 1000 else 0)
		end
		return unlocked
	end
	return { Frame = row, def = def, update = update }
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
function MissionsWindow.build(body: Frame): View
	local current = "Daily"
	local busy: { [string]: boolean } = {}
	local countdownThread: thread? = nil

	-- top bar: tabs + countdown / summary pill
	local top = C.frame({ Parent = body, Name = "Top", Size = UDim2.new(1, 0, 0, 34) })
	local pill = C.frame({
		Parent = top,
		Name = "Countdown",
		Size = UDim2.fromOffset(0, 30),
		AutoSize = Enum.AutomaticSize.X,
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = Theme.Color.Surface1,
		Transparency = 0,
		Radius = Theme.Radius.Pill,
	})
	C.stroke(pill, 0.9)
	C.padding(pill, 0, 12, 0, 10)
	C.list(pill, "H", 6, nil, Enum.VerticalAlignment.Center)
	local clock = Icons.make("clock", 14, Theme.Color.TextDim)
	clock.LayoutOrder = 1
	clock.Parent = pill
	local pillText = C.label({ Parent = pill, LayoutOrder = 2, Text = "", Font = Theme.Font.SemiBold, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextDim, Size = UDim2.new(0, 0, 1, 0), AutoSize = Enum.AutomaticSize.X })

	local pages = C.frame({ Parent = body, Name = "Pages", Size = UDim2.new(1, 0, 1, -46), Position = UDim2.fromOffset(0, 46) })
	local dailyPage = C.scroll({ Parent = pages, Name = "Daily", Gap = 10 })
	local weeklyPage = C.scroll({ Parent = pages, Name = "Weekly", Gap = 10, Visible = false })
	local achPage = C.frame({ Parent = pages, Name = "Achievements", Visible = false })

	local dailyEmpty = C.empty(dailyPage, "New missions are on their way…")
	local weeklyEmpty = C.empty(weeklyPage, "New challenges are on their way…")

	local cards: { Daily: { MissionCard }, Weekly: { MissionCard } } = { Daily = {}, Weekly = {} }
	local signature: { [string]: string } = { Daily = "", Weekly = "" }
	local refresh: () -> ()

	local function claim(kind: string, index: number)
		local key = kind .. index
		if busy[key] then
			return
		end
		busy[key] = true
		refresh()
		task.spawn(function()
			local ok = Kit.request("Missions.Claim", { Kind = kind, Index = index })
			busy[key] = nil
			local list = if kind == "Daily" then cards.Daily else cards.Weekly
			local card = list[index]
			if ok and card then
				card.flash()
			end
			refresh()
		end)
	end

	local function syncCards(kind: "Daily" | "Weekly", page: ScrollingFrame, list: { MissionState }, empty: TextLabel)
		local sig = ""
		for _, m in list do
			sig ..= m.Id .. ";"
		end
		local set = if kind == "Daily" then cards.Daily else cards.Weekly
		if sig ~= signature[kind] then
			signature[kind] = sig
			for _, card in set do
				card.Frame:Destroy()
			end
			table.clear(set)
			for i in list do
				table.insert(set, missionCard(page, i, function()
					claim(kind, i)
				end))
			end
		end
		local level = DataController.data.Level
		local shown = 0
		for i, m in list do
			local t = Missions.find(m.Id)
			local card = set[i]
			if card then
				card.Frame.Visible = t ~= nil
				if t then
					shown += 1
					card.update(m, t, level, busy[kind .. i] == true)
				end
			end
		end
		empty.Visible = shown == 0
	end

	-- weekly all-clear bonus card
	local bonus = C.frame({ Parent = weeklyPage, Name = "Bonus", LayoutOrder = 100, Size = UDim2.new(1, 0, 0, CARD_H), Color = Theme.Color.Surface1, Transparency = 0, Radius = Theme.Radius.Medium })
	local bonusStroke = C.stroke(bonus, 0.7, Theme.Color.Trophy)
	C.padding(bonus, 12, 12, 12, 12)
	local wash = C.frame({ Parent = bonus, Name = "Wash", Size = UDim2.new(1, 24, 1, 24), Position = UDim2.fromOffset(-12, -12), Color = Theme.Color.Trophy, Transparency = 0, Radius = Theme.Radius.Medium })
	wash.ZIndex = 0
	New("UIGradient", { Transparency = NumberSequence.new(0.86, 1), Parent = wash })
	C.iconBadge({ Parent = bonus, Icon = "trophy", Color = Theme.Color.Trophy, Size = 42, Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Transparency = 0.72 })
	local bonusCol = C.frame({ Parent = bonus, Size = UDim2.new(1, -(54 + 126), 1, 0), Position = UDim2.fromOffset(54, 0) })
	C.label({ Parent = bonusCol, Text = "Weekly all-clear bonus", Font = Theme.Font.Bold, Size = UDim2.new(1, -70, 0, 20) })
	local bonusCount = C.label({ Parent = bonusCol, Text = "", Font = Theme.Font.SemiBold, TextSize = Theme.TextSize.Caption, Color = Theme.Color.TextDim, XAlign = Enum.TextXAlignment.Right, Size = UDim2.new(0, 70, 0, 20), Position = UDim2.new(1, -70, 0, 0) })
	local _, setBonus = C.progress({ Parent = bonusCol, Size = UDim2.new(1, 0, 0, 6), Position = UDim2.fromOffset(0, 26), Color = Theme.Color.Trophy })
	Kit.rewardChips(bonusCol, { Trophies = Missions.WeeklyBonusTrophies }, { Position = UDim2.fromOffset(0, 38) })
	local bonusBusy = false
	local bonusButton = C.button({
		Parent = bonus,
		Text = "Claim",
		Style = "Primary",
		Size = UDim2.fromOffset(114, 40),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		TextSize = Theme.TextSize.Caption + 1,
		OnClick = function()
			if bonusBusy then
				return
			end
			bonusBusy = true
			refresh()
			task.spawn(function()
				Kit.request("Missions.ClaimWeeklyBonus")
				bonusBusy = false
				refresh()
			end)
		end,
	})
	local setBonusButton = buttonSetter(bonusButton)

	local function updateBonus(list: { MissionState })
		local m = DataController.data.Missions
		local claimed = 0
		for _, w in list do
			if w.Claimed then
				claimed += 1
			end
		end
		local total = #list
		bonus.Visible = total > 0
		setBonus(claimed / math.max(1, total), true)
		bonusCount.Text = `{claimed} / {total}`
		if m.WeeklyBonusClaimed then
			setBonusButton("Claimed", "Ghost", true)
		elseif claimed >= total and total > 0 then
			setBonusButton(if bonusBusy then "Claiming…" else "Claim", "Primary", bonusBusy)
		else
			setBonusButton("Locked", "Secondary", true)
		end
		bonusStroke.Transparency = if m.WeeklyBonusClaimed then 0.9 else 0.6
	end

	-- achievements: summary + filters + list
	local summary = C.frame({ Parent = achPage, Name = "Summary", Size = UDim2.new(1, 0, 0, 58), Color = Theme.Color.Surface1, Transparency = 0, Radius = Theme.Radius.Medium })
	C.stroke(summary, 0.9)
	C.padding(summary, 10, 14, 10, 12)
	C.iconBadge({ Parent = summary, Icon = "trophy", Color = Theme.Color.Trophy, Size = 38, Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Transparency = 0.75 })
	local sumText = C.label({ Parent = summary, Text = "", Font = Theme.Font.Bold, Size = UDim2.new(1, -50, 0, 20), Position = UDim2.fromOffset(50, 0) })
	local _, setSum = C.progress({ Parent = summary, Size = UDim2.new(1, -50, 0, 6), Position = UDim2.fromOffset(50, 26), Color = Theme.Color.Trophy })

	local filter = "All"
	local achList = C.scroll({ Parent = achPage, Name = "List", Gap = 8, Size = UDim2.new(1, 0, 1, -110), Position = UDim2.fromOffset(0, 110) })
	local rows: { AchievementRow } = {}
	for _, def in Achievements.List do
		table.insert(rows, achievementRow(achList, def))
	end
	local function applyFilter()
		for _, r in rows do
			r.Frame.Visible = filter == "All" or r.def.Category == filter
		end
	end
	local filterItems: { { Id: string, Label: string } } = { { Id = "All", Label = "All" } }
	local seen: { [string]: boolean } = {}
	for _, def in Achievements.List do
		if not seen[def.Category] then
			seen[def.Category] = true
			table.insert(filterItems, { Id = def.Category, Label = def.Category })
		end
	end
	chips(achPage, filterItems, function(id: string)
		filter = id
		applyFilter()
		achList.CanvasPosition = Vector2.zero
	end)

	local function updateAchievements()
		local data = DataController.data
		local unlocked = 0
		for _, r in rows do
			if r.update(data) then
				unlocked += 1
			end
		end
		sumText.Text = `{unlocked} of {#rows} achievements unlocked`
		setSum(unlocked / math.max(1, #rows), true)
	end

	-- tab dots (claimable rewards on Daily / Weekly)
	local tabs: C.TabsApi
	local dots: { [string]: Frame } = {}
	local function updateCountdown()
		if current == "Daily" then
			local s = Kit.untilDayReset()
			pillText.Text = if s > 1 then "New missions in " .. Format.duration(s) else "Refreshing…"
		elseif current == "Weekly" then
			local s = Kit.untilWeekReset()
			pillText.Text = if s > 1 then "Resets in " .. Format.duration(s) else "Refreshing…"
		else
			pillText.Text = "Unlock automatically as you play"
		end
	end

	refresh = function()
		local m = DataController.data.Missions
		syncCards("Daily", dailyPage, m.Daily, dailyEmpty)
		syncCards("Weekly", weeklyPage, m.Weekly, weeklyEmpty)
		updateBonus(m.Weekly)
		updateAchievements()
		local function ready(list: { MissionState }): boolean
			for _, x in list do
				if not x.Claimed and x.Progress >= x.Target then
					return true
				end
			end
			return false
		end
		local weeklyAll = #m.Weekly > 0 and not m.WeeklyBonusClaimed
		for _, w in m.Weekly do
			if not w.Claimed then
				weeklyAll = false
			end
		end
		if dots.Daily then
			dots.Daily.Visible = ready(m.Daily)
		end
		if dots.Weekly then
			dots.Weekly.Visible = ready(m.Weekly) or weeklyAll
		end
		updateCountdown()
	end

	tabs = C.tabs({
		Parent = top,
		Size = UDim2.new(1, -240, 1, 0),
		Tabs = {
			{ Id = "Daily", Label = "Daily" },
			{ Id = "Weekly", Label = "Weekly" },
			{ Id = "Achievements", Label = "Achievements" },
		},
		OnSelect = function(id: string)
			current = id
			dailyPage.Visible = id == "Daily"
			weeklyPage.Visible = id == "Weekly"
			achPage.Visible = id == "Achievements"
			updateCountdown()
		end,
	})
	for _, child in tabs.Frame:GetChildren() do
		if child:IsA("TextButton") then
			local b = child :: TextButton
			local id = if b.LayoutOrder == 1 then "Daily" elseif b.LayoutOrder == 2 then "Weekly" else nil
			if id then
				dots[id] = C.frame({
					Parent = b,
					Name = "Dot",
					Size = UDim2.fromOffset(8, 8),
					Position = UDim2.new(1, 8, 0, -2),
					AnchorPoint = Vector2.new(1, 0),
					Color = Theme.Color.Danger,
					Transparency = 0,
					Radius = Theme.Radius.Pill,
					Visible = false,
				})
			end
		end
	end
	tabs.select("Daily")
	refresh()

	return {
		refresh = refresh,
		opened = function()
			refresh()
			if countdownThread then
				task.cancel(countdownThread)
			end
			countdownThread = task.spawn(function()
				while true do
					task.wait(1)
					updateCountdown()
				end
			end)
		end,
		closed = function()
			if countdownThread then
				task.cancel(countdownThread)
				countdownThread = nil
			end
		end,
		select = function(id: string)
			tabs.select(id)
		end,
	}
end

return MissionsWindow
