--!strict
--[[
	Vector icons drawn from Frames (no image assets, crisp at any scale).
		local icon = Icons.make("stats", 24, Theme.Color.Text)
	Every icon is a transparent square Frame; shapes are laid out in 0..1 units.
	Recolour later with Icons.recolor(icon, color).
]]

local Icons = {}

type Opts = { r: number?, rot: number?, stroke: number?, alpha: number?, hole: boolean? }

local function shape(parent: Frame, cx: number, cy: number, w: number, h: number, color: Color3, o: Opts?)
	local opts: Opts = o or {}
	local f = Instance.new("Frame")
	f.Name = "Shape"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(cx, cy)
	f.Size = UDim2.fromScale(w, h)
	f.BorderSizePixel = 0
	f.Rotation = opts.rot or 0
	f.BackgroundColor3 = color
	f.BackgroundTransparency = opts.alpha or 0
	if opts.r then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(opts.r, 0)
		c.Parent = f
	end
	if opts.stroke then
		f.BackgroundTransparency = 1
		local s = Instance.new("UIStroke")
		s.Color = color
		s.Thickness = opts.stroke
		s.Transparency = opts.alpha or 0
		s.Parent = f
		f:SetAttribute("StrokeShape", true)
	end
	if opts.hole then
		f:SetAttribute("Hole", true)
	end
	f.Parent = parent
	return f
end

local DRAW: { [string]: (f: Frame, c: Color3, px: number) -> () } = {}

DRAW.stats = function(f: Frame, c: Color3)
	shape(f, 0.22, 0.9 - 0.175, 0.18, 0.35, c, { r = 0.3 })
	shape(f, 0.5, 0.9 - 0.3, 0.18, 0.6, c, { r = 0.3 })
	shape(f, 0.78, 0.9 - 0.42, 0.18, 0.84, c, { r = 0.3 })
end

DRAW.gear = function(f: Frame, c: Color3)
	shape(f, 0.5, 0.5, 0.56, 0.1, c, { r = 0.5 })
	shape(f, 0.29, 0.5, 0.11, 0.52, c, { r = 0.3 })
	shape(f, 0.71, 0.5, 0.11, 0.52, c, { r = 0.3 })
	shape(f, 0.15, 0.5, 0.09, 0.34, c, { r = 0.3 })
	shape(f, 0.85, 0.5, 0.09, 0.34, c, { r = 0.3 })
end

DRAW.shop = function(f: Frame, c: Color3, px: number)
	shape(f, 0.5, 0.33, 0.36, 0.38, c, { r = 0.5, stroke = math.max(1.5, px * 0.08) })
	shape(f, 0.5, 0.64, 0.72, 0.54, c, { r = 0.18 })
end

DRAW.missions = function(f: Frame, c: Color3)
	for i, y in { 0.24, 0.5, 0.76 } do
		shape(f, 0.18, y, 0.16, 0.16, c, { r = 0.3, alpha = if i == 1 then 0 else 0 })
		shape(f, 0.62, y, 0.56, 0.1, c, { r = 0.5, alpha = 0.15 })
	end
end

DRAW.daily = function(f: Frame, c: Color3)
	shape(f, 0.5, 0.64, 0.7, 0.5, c, { r = 0.14 })
	shape(f, 0.5, 0.34, 0.82, 0.16, c, { r = 0.25 })
	shape(f, 0.5, 0.58, 0.12, 0.66, Color3.new(0, 0, 0), { alpha = 0.55 })
	shape(f, 0.39, 0.19, 0.2, 0.2, c, { r = 0.3, rot = 45 })
	shape(f, 0.61, 0.19, 0.2, 0.2, c, { r = 0.3, rot = 45 })
end

DRAW.ranks = function(f: Frame, c: Color3)
	shape(f, 0.5, 0.92 - 0.3, 0.28, 0.6, c, { r = 0.12 })
	shape(f, 0.2, 0.92 - 0.2, 0.26, 0.4, c, { r = 0.12, alpha = 0.2 })
	shape(f, 0.8, 0.92 - 0.14, 0.26, 0.28, c, { r = 0.12, alpha = 0.35 })
end

DRAW.social = function(f: Frame, c: Color3)
	shape(f, 0.67, 0.34, 0.24, 0.24, c, { r = 0.5, alpha = 0.35 })
	shape(f, 0.69, 0.76, 0.36, 0.28, c, { r = 0.45, alpha = 0.35 })
	shape(f, 0.37, 0.3, 0.28, 0.28, c, { r = 0.5 })
	shape(f, 0.37, 0.74, 0.46, 0.34, c, { r = 0.45 })
end

DRAW.party = function(f: Frame, c: Color3)
	shape(f, 0.2, 0.38, 0.2, 0.2, c, { r = 0.5, alpha = 0.35 })
	shape(f, 0.8, 0.38, 0.2, 0.2, c, { r = 0.5, alpha = 0.35 })
	shape(f, 0.2, 0.74, 0.3, 0.24, c, { r = 0.45, alpha = 0.35 })
	shape(f, 0.8, 0.74, 0.3, 0.24, c, { r = 0.45, alpha = 0.35 })
	shape(f, 0.5, 0.3, 0.26, 0.26, c, { r = 0.5 })
	shape(f, 0.5, 0.72, 0.42, 0.32, c, { r = 0.45 })
end

DRAW.settings = function(f: Frame, c: Color3)
	shape(f, 0.5, 0.33, 0.8, 0.09, c, { r = 0.5, alpha = 0.3 })
	shape(f, 0.5, 0.67, 0.8, 0.09, c, { r = 0.5, alpha = 0.3 })
	shape(f, 0.32, 0.33, 0.24, 0.24, c, { r = 0.5 })
	shape(f, 0.68, 0.67, 0.24, 0.24, c, { r = 0.5 })
end

DRAW.close = function(f: Frame, c: Color3)
	shape(f, 0.5, 0.5, 0.78, 0.11, c, { r = 0.5, rot = 45 })
	shape(f, 0.5, 0.5, 0.78, 0.11, c, { r = 0.5, rot = -45 })
end

DRAW.plus = function(f: Frame, c: Color3)
	shape(f, 0.5, 0.5, 0.7, 0.12, c, { r = 0.5 })
	shape(f, 0.5, 0.5, 0.12, 0.7, c, { r = 0.5 })
end

DRAW.check = function(f: Frame, c: Color3)
	shape(f, 0.35, 0.6, 0.34, 0.13, c, { r = 0.5, rot = 45 })
	shape(f, 0.6, 0.5, 0.62, 0.13, c, { r = 0.5, rot = -48 })
end

DRAW.cash = function(f: Frame, c: Color3)
	shape(f, 0.5, 0.5, 0.88, 0.58, c, { r = 0.16 })
	shape(f, 0.5, 0.5, 0.26, 0.26, Color3.new(0, 0, 0), { r = 0.5, alpha = 0.6 })
	shape(f, 0.17, 0.5, 0.08, 0.08, Color3.new(0, 0, 0), { r = 0.5, alpha = 0.6 })
	shape(f, 0.83, 0.5, 0.08, 0.08, Color3.new(0, 0, 0), { r = 0.5, alpha = 0.6 })
end

DRAW.trophy = function(f: Frame, c: Color3, px: number)
	shape(f, 0.2, 0.33, 0.2, 0.24, c, { r = 0.5, stroke = math.max(1.2, px * 0.06) })
	shape(f, 0.8, 0.33, 0.2, 0.24, c, { r = 0.5, stroke = math.max(1.2, px * 0.06) })
	shape(f, 0.5, 0.34, 0.52, 0.44, c, { r = 0.32 })
	shape(f, 0.5, 0.66, 0.12, 0.22, c)
	shape(f, 0.5, 0.82, 0.46, 0.12, c, { r = 0.3 })
end

DRAW.token = function(f: Frame, c: Color3)
	shape(f, 0.5, 0.5, 0.56, 0.56, c, { r = 0.12, rot = 45 })
	shape(f, 0.5, 0.5, 0.22, 0.22, Color3.new(1, 1, 1), { r = 0.12, rot = 45, alpha = 0.6 })
end

DRAW.energy = function(f: Frame, c: Color3)
	shape(f, 0.57, 0.3, 0.18, 0.48, c, { r = 0.2, rot = 22 })
	shape(f, 0.5, 0.5, 0.46, 0.14, c, { r = 0.3, rot = -10 })
	shape(f, 0.43, 0.7, 0.18, 0.48, c, { r = 0.2, rot = 22 })
end

DRAW.lock = function(f: Frame, c: Color3, px: number)
	shape(f, 0.5, 0.36, 0.4, 0.46, c, { r = 0.5, stroke = math.max(1.5, px * 0.08) })
	shape(f, 0.5, 0.67, 0.64, 0.46, c, { r = 0.18 })
	shape(f, 0.5, 0.67, 0.1, 0.16, Color3.new(0, 0, 0), { r = 0.5, alpha = 0.5 })
end

DRAW.star = function(f: Frame, c: Color3)
	shape(f, 0.5, 0.5, 0.5, 0.5, c, { r = 0.1 })
	shape(f, 0.5, 0.5, 0.5, 0.5, c, { r = 0.1, rot = 45 })
end

DRAW.user = function(f: Frame, c: Color3)
	shape(f, 0.5, 0.32, 0.34, 0.34, c, { r = 0.5 })
	shape(f, 0.5, 0.8, 0.66, 0.36, c, { r = 0.45 })
end

DRAW.clock = function(f: Frame, c: Color3, px: number)
	shape(f, 0.5, 0.5, 0.82, 0.82, c, { r = 0.5, stroke = math.max(1.5, px * 0.08) })
	shape(f, 0.5, 0.36, 0.09, 0.3, c, { r = 0.5 })
	shape(f, 0.6, 0.52, 0.24, 0.09, c, { r = 0.5, rot = 25 })
end

DRAW.flame = function(f: Frame, c: Color3)
	shape(f, 0.5, 0.62, 0.56, 0.56, c, { r = 0.5 })
	shape(f, 0.5, 0.42, 0.4, 0.4, c, { r = 0.15, rot = 45 })
	shape(f, 0.5, 0.66, 0.22, 0.22, Color3.new(1, 1, 1), { r = 0.5, alpha = 0.55 })
end

DRAW.companion = function(f: Frame, c: Color3)
	shape(f, 0.5, 0.18, 0.06, 0.18, c)
	shape(f, 0.5, 0.1, 0.12, 0.12, c, { r = 0.5 })
	shape(f, 0.5, 0.56, 0.74, 0.58, c, { r = 0.24 })
	shape(f, 0.36, 0.54, 0.12, 0.14, Color3.new(0, 0, 0), { r = 0.5, alpha = 0.3 })
	shape(f, 0.64, 0.54, 0.12, 0.14, Color3.new(0, 0, 0), { r = 0.5, alpha = 0.3 })
end

DRAW.emote = function(f: Frame, c: Color3, px: number)
	shape(f, 0.5, 0.5, 0.82, 0.82, c, { r = 0.5, stroke = math.max(1.5, px * 0.08) })
	shape(f, 0.37, 0.4, 0.1, 0.12, c, { r = 0.5 })
	shape(f, 0.63, 0.4, 0.1, 0.12, c, { r = 0.5 })
	shape(f, 0.5, 0.64, 0.34, 0.09, c, { r = 0.5 })
end

DRAW.rebirth = function(f: Frame, c: Color3, px: number)
	shape(f, 0.5, 0.52, 0.72, 0.72, c, { r = 0.5, stroke = math.max(1.6, px * 0.09) })
	shape(f, 0.74, 0.22, 0.24, 0.24, c, { r = 0.1, rot = 45 })
end

DRAW.camera = function(f: Frame, c: Color3, px: number)
	shape(f, 0.5, 0.56, 0.86, 0.58, c, { r = 0.16 })
	shape(f, 0.36, 0.24, 0.24, 0.12, c, { r = 0.3 })
	shape(f, 0.5, 0.56, 0.34, 0.34, Color3.new(0, 0, 0), { r = 0.5, alpha = 0.45 })
	shape(f, 0.5, 0.56, 0.2, 0.2, c, { r = 0.5, stroke = math.max(1, px * 0.05) })
end

DRAW.info = function(f: Frame, c: Color3, px: number)
	shape(f, 0.5, 0.5, 0.84, 0.84, c, { r = 0.5, stroke = math.max(1.5, px * 0.08) })
	shape(f, 0.5, 0.3, 0.12, 0.12, c, { r = 0.5 })
	shape(f, 0.5, 0.6, 0.1, 0.32, c, { r = 0.4 })
end

DRAW.boost = function(f: Frame, c: Color3)
	shape(f, 0.5, 0.14, 0.26, 0.1, c, { r = 0.3 })
	shape(f, 0.5, 0.26, 0.2, 0.14, c, { alpha = 0.25 })
	shape(f, 0.5, 0.62, 0.46, 0.62, c, { r = 0.2 })
	shape(f, 0.5, 0.62, 0.46, 0.14, Color3.new(1, 1, 1), { alpha = 0.6 })
end

DRAW.elevator = function(f: Frame, c: Color3)
	shape(f, 0.5, 0.5, 0.78, 0.86, c, { r = 0.14, alpha = 0.75 })
	shape(f, 0.42, 0.33, 0.2, 0.08, c, { r = 0.5, rot = -45 })
	shape(f, 0.58, 0.33, 0.2, 0.08, c, { r = 0.5, rot = 45 })
	shape(f, 0.42, 0.67, 0.2, 0.08, c, { r = 0.5, rot = 45 })
	shape(f, 0.58, 0.67, 0.2, 0.08, c, { r = 0.5, rot = -45 })
end

local function chevron(f: Frame, c: Color3, rot: number)
	local holder = Instance.new("Frame")
	holder.Name = "Chevron"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Rotation = rot
	holder.Parent = f
	shape(holder :: Frame, 0.36, 0.4, 0.46, 0.13, c, { r = 0.5, rot = -45 })
	shape(holder :: Frame, 0.64, 0.4, 0.46, 0.13, c, { r = 0.5, rot = 45 })
	shape(holder :: Frame, 0.5, 0.62, 0.13, 0.5, c, { r = 0.5 })
end
DRAW.up = function(f: Frame, c: Color3)
	chevron(f, c, 0)
end
DRAW.right = function(f: Frame, c: Color3)
	chevron(f, c, 90)
end
DRAW.down = function(f: Frame, c: Color3)
	chevron(f, c, 180)
end
DRAW.left = function(f: Frame, c: Color3)
	chevron(f, c, 270)
end

function Icons.make(name: string, size: number, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = "Icon_" .. name
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(size, size)
	f:SetAttribute("Icon", name)
	local draw = DRAW[name] or DRAW.info
	draw(f, color, size)
	return f
end

-- Recolours an icon (keeps the dark accent shapes).
function Icons.recolor(icon: Instance, color: Color3)
	for _, d in icon:GetDescendants() do
		if d:IsA("Frame") and d.Name == "Shape" then
			local fr = d :: Frame
			if fr.BackgroundColor3 ~= Color3.new(0, 0, 0) and fr.BackgroundColor3 ~= Color3.new(1, 1, 1) then
				fr.BackgroundColor3 = color
				local stroke = fr:FindFirstChildOfClass("UIStroke") :: UIStroke?
				if stroke then
					stroke.Color = color
				end
			end
		end
	end
end

function Icons.has(name: string): boolean
	return DRAW[name] ~= nil
end

return Icons
