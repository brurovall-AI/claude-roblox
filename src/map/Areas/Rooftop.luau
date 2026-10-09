--!strict
-- Rooftop: skyline running track, open-air training infield, event stage, lounge.
local Context = require("../Context")
local Fit = require("./Fit")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")
local Track = require("./Track")

local M = {}

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "Rooftop")
	local y = Layout.Y.ROOF
	local R = Layout.Roof
	Track.rounded(f, Vector3.new(0, y, 0), Vector2.new(R.TrackOuterHalf.X, R.TrackOuterHalf.Z), R.TrackCornerRadius, R.TrackLanes * R.TrackLaneWidth, R.TrackLanes)

	-- east infield: open-air training on turf and teak
	Kit.box(f, CFrame.new(88, y + 0.05, 0), Vector3.new(60, 0.1, 110), "Turf", Kit.DETAIL)
	Fit.pack(f, Fit.rect(58, 118, -55, 55), y, "E", {
		{ Type = "PullUpBar", Tier = 5, Count = 2 },
		{ Type = "BattleRopes", Tier = 5, Count = 2 },
		{ Type = "PlyoBox", Tier = 5, Count = 2 },
		{ Type = "TireFlip", Tier = 5 },
		{ Type = "AgilityLadder", Tier = 5 },
		{ Type = "SledPush", Tier = 5 },
	}, nil, { AreaId = "Rooftop", Aisle = 6, Gap = 4 })
	-- west infield: yoga deck + lounge
	Kit.box(f, CFrame.new(-90, y + 0.15, -20), Vector3.new(40, 0.3, 40), "Teak")
	Fit.pack(f, Fit.rect(-110, -70, -40, 0), y + 0.3, "S", {
		{ Type = "YogaMat", Tier = 5, Count = 3 },
	}, nil, { AreaId = "Rooftop", Gap = 3 })
	for i = 0, 2 do
		Props.umbrellaTable(f, CFrame.new(-100 + i * 14, y, 30), "FabricCream")
	end
	for _, p in { { -118, -60 }, { -118, 50 }, { 120, -66 }, { 120, 64 }, { -60, 20 } } do
		Props.planter(f, CFrame.new(p[1], y, p[2]), Vector3.new(6, 2.4, 6), "ConcreteDark", "Bush")
	end
	-- event stage
	local s = R.EventStage
	Kit.box(f, CFrame.new((s.X0 + s.X1) / 2, y + 1, s.Z1 - 8), Vector3.new(s.X1 - s.X0, 2, 14), "Teak")
	Props.bleachers(f, Kit.place((s.X0 + s.X1) / 2, y, s.Z0 + 4, 0), 30, 3, "PowderGraphite")
	Props.wallSign(f, Kit.place((s.X0 + s.X1) / 2, y + 7, s.Z1 - 1, 0), "ROOFTOP EVENTS", Vector2.new(18, 2.4), "Brand")
	for _, p in { { -126, 0 }, { 126, 30 }, { 0, -76 }, { 0, 76 } } do
		Props.lampPost(f, CFrame.new(p[1], y, p[2]), "Park")
	end
end

return M
