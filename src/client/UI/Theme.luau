--!strict
--[[
	Ironhaven UI design tokens. Warm graphite surfaces, warm-white text and a
	single brand accent (Ironhaven Amber). Everything in the UI should pull from
	here so screens stay consistent.
]]

local Theme = {}

local function hex(h: string): Color3
	return Color3.fromHex(h)
end

Theme.Color = {
	Backdrop = hex("#0B0B0D"),
	Surface0 = hex("#141518"), -- windows
	Surface1 = hex("#1D1E22"), -- cards
	Surface2 = hex("#272830"), -- raised / hover
	Surface3 = hex("#33343C"), -- pressed / selected
	Stroke = hex("#FFFFFF"),
	Text = hex("#F4F2EE"),
	TextDim = hex("#ABA8A2"),
	TextMute = hex("#75726D"),
	Accent = hex("#F2A93B"),
	AccentDeep = hex("#C7832A"),
	AccentText = hex("#1B1408"),
	Success = hex("#4CC38A"),
	Warning = hex("#F2C14E"),
	Danger = hex("#E5534B"),
	Info = hex("#6FB7E8"),
	Cash = hex("#7AD678"),
	Trophy = hex("#F0BA50"),
	Token = hex("#C48CFF"),
	XP = hex("#F2A93B"),
	Energy = hex("#58B0E2"),
}

Theme.Transparency = {
	Window = 0.04,
	Card = 0.0,
	Hud = 0.18, -- HUD chips sit lighter over the world
	Stroke = 0.9,
	StrokeStrong = 0.78,
	Dim = 0.45,
}

Theme.Radius = {
	Small = UDim.new(0, 6),
	Medium = UDim.new(0, 10),
	Large = UDim.new(0, 14),
	Pill = UDim.new(1, 0),
}

Theme.Space = { XS = 4, S = 8, M = 12, L = 16, XL = 20, XXL = 28 }

local FAMILY = "rbxasset://fonts/families/BuilderSans.json"
Theme.Font = {
	Regular = Font.new(FAMILY, Enum.FontWeight.Regular),
	Medium = Font.new(FAMILY, Enum.FontWeight.Medium),
	SemiBold = Font.new(FAMILY, Enum.FontWeight.SemiBold),
	Bold = Font.new(FAMILY, Enum.FontWeight.Bold),
	Heavy = Font.new(FAMILY, Enum.FontWeight.ExtraBold),
}

Theme.TextSize = {
	Display = 40,
	Title = 22,
	Heading = 17,
	Body = 15,
	Caption = 13,
	Micro = 11,
}

Theme.Tween = {
	Fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Base = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Spring = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

-- Minimum touch target (px, before UIScale).
Theme.Touch = 44

return Theme
