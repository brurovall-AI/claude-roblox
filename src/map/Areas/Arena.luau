--!strict
-- The Arena: raised competition stage, bleachers, arm-wrestling dais, lighting truss.
local Context = require("../Context")
local Equipment = require("../Equipment")
local Fit = require("./Fit")
local Gameplay = require("../Gameplay")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")

local M = {}

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "Arena")
	local r, hall = Layout.L2.Arena, Layout.L2.EastHall
	local y = Layout.Y.L2

	-- stage (north half) with a central lifting platform
	local stageY = y + 3
	Kit.box(f, CFrame.new(112, y + 1.5, 84), Vector3.new(66, 3, 28), "PowderBlack")
	Kit.box(f, CFrame.new(112, y + 3.02, 70.2), Vector3.new(66, 0.05, 0.4), "Gold", Kit.DETAIL)
	for i = 1, 3 do -- front steps
		Kit.box(f, CFrame.new(112, y + i * 0.75 - 0.375, 69.5 - (4 - i) * 1.3), Vector3.new(14, i * 0.75, 1.3), "PowderBlack")
	end
	Kit.box(f, CFrame.new(112, stageY + 0.1, 84), Vector3.new(12, 0.2, 12), "Oak")
	Kit.box(f, CFrame.new(112, stageY + 0.12, 84), Vector3.new(6, 0.2, 12), "RubberFloor", Kit.DETAIL)
	for i = 1, 8 do
		local x = 112 + (i - 4.5) * 7
		Gameplay.eventSpot(f, "MaxLift", "Lane", i, CFrame.new(x, stageY + 3, 90))
	end
	for i = 1, 12 do
		local x = 112 + (i - 6.5) * 5
		Gameplay.eventSpot(f, "EnduranceHold", "Lane", i, CFrame.new(x, stageY + 3, 76))
	end
	-- big screen above the stage
	Gameplay.scoreboard(f, "Arena", Kit.place(112, y + 16, 98.6, 0) * CFrame.Angles(0, math.rad(180), 0), Vector3.new(30, 8, 0.4))
	Props.wallSign(f, Fit.wallCf(r, "N", 112, y + 22, 1.15), "THE ARENA", Vector2.new(24, 3.2), "Brand")

	-- bleachers facing the stage
	Props.bleachers(f, Kit.place(78, y, 52, 180), 24, 5, "PowderGraphite")
	Props.bleachers(f, Kit.place(140, y, 40, 180), 18, 5, "PowderGraphite")

	-- arm-wrestling dais (south-west)
	Kit.box(f, CFrame.new(84, y + 0.5, 22), Vector3.new(40, 1, 18), "CarpetBurgundy")
	for i = 1, 4 do
		Equipment.duelTable(f, Kit.place(70 + (i - 1) * 9.5, y + 1, 22, 0), "A" .. i, 4)
	end
	Props.wallSign(f, Fit.wallCf(r, "W", 22, y + 12, 1.15), "ARM WRESTLING", Vector2.new(16, 2.2), "Area")

	-- lighting truss with spots over the stage
	for _, z in { 76, 92 } do
		Props.truss(f, Vector3.new(80, y + 20, z), Vector3.new(144, y + 20, z), 2.4, "SteelDark")
	end
	for i = 0, 5 do
		Props.ceilingLight(f, CFrame.new(84 + i * 11, y + 19, 80) * CFrame.Angles(0, math.rad(180), 0), "Spot", { Tilt = 25, Brightness = 2.4, Range = 40, Shadows = i == 2 })
	end
	Fit.lights(f, Fit.rect(r.X0, r.X1, r.Z0, 66), Layout.CEIL.L2, "Downlight", 22, nil, { Brightness = 1.2, Range = 24, Color = Color3.fromRGB(255, 220, 190) })
	Fit.lights(f, hall, Layout.CEIL.L2, "Downlight", 20, nil, { Brightness = 1.2, Range = 20 })
	Props.wallSign(f, Fit.wallCf(hall, "N", 105, y + 14, 0.6), "ARENA", Vector2.new(8, 1.6), "Wayfinding")
	Props.wallSign(f, Fit.wallCf(hall, "S", 105, y + 14, 0.6), "VIP CLUB", Vector2.new(8, 1.6), "Wayfinding")
end

return M
