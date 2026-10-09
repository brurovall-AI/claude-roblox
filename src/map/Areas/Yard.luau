--!strict
-- The Yard: outdoor track, sprint lanes, obstacle course and strongman zone.
local Context = require("../Context")
local Fit = require("./Fit")
local Gameplay = require("../Gameplay")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")
local Track = require("./Track")

local M = {}

local function obstacleCourse(f: Instance, y: number)
	local o = Layout.Yard.Obstacle
	local cx = (o.X0 + o.X1) / 2
	local z = o.Z0 + 4
	Gameplay.checkpoint(f, "Obstacle", 0, CFrame.new(cx, y + 4, z), Vector3.new(24, 8, 1))
	Gameplay.eventSpot(f, "ObstacleDash", "Start", 1, CFrame.new(cx, y + 3, z - 3))
	local idx = 0
	local function cp(zz: number)
		idx += 1
		Gameplay.checkpoint(f, "Obstacle", idx, CFrame.new(cx, y + 6, zz), Vector3.new(26, 12, 1))
	end
	-- hurdles
	for i = 1, 4 do
		local hz = z + 6 + i * 4
		Kit.box(f, CFrame.new(cx, y + 1.6, hz), Vector3.new(20, 0.3, 0.3), "PowderWhite", { Collide = true })
		for _, sx in { -10, 10 } do
			Kit.box(f, CFrame.new(cx + sx, y + 0.8, hz), Vector3.new(0.3, 1.6, 1), "PowderGraphite", Kit.DETAIL)
		end
	end
	cp(z + 26)
	-- stepping platforms
	for i = 0, 5 do
		local px = cx + (if i % 2 == 0 then -4 else 4)
		Kit.box(f, CFrame.new(px, y + 1 + i * 0.6, z + 32 + i * 5), Vector3.new(6, 2 + i * 1.2, 4), "Plywood")
	end
	cp(z + 60)
	-- balance beams
	for _, bx in { -6, 0, 6 } do
		Kit.box(f, CFrame.new(cx + bx, y + 1.5, z + 70), Vector3.new(0.8, 0.4, 16), "OakSolid", { Collide = true })
		for _, bz in { -7.5, 7.5 } do
			Kit.box(f, CFrame.new(cx + bx, y + 0.65, z + 70 + bz), Vector3.new(0.6, 1.3, 0.6), "PowderGraphite", Kit.DETAIL)
		end
	end
	Kit.box(f, CFrame.new(cx, y + 0.05, z + 70), Vector3.new(22, 0.1, 18), "Sand", Kit.DETAIL)
	-- final wall with a ramp
	Kit.box(f, CFrame.new(cx, y + 2.5, z + 86), Vector3.new(20, 5, 1), "Plywood")
	Kit.wedge(f, CFrame.new(cx, y + 2.25, z + 83) , Vector3.new(20, 4.5, 5), "Plywood")
	cp(z + 92)
end

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "Yard")
	local Y = Layout.Yard
	local y = Layout.Y.G
	Track.stadium(f, Y.TrackCenter, Y.TrackStraight / 2, Y.TrackInnerRadius, Y.TrackLanes, Y.TrackLaneWidth)

	-- sprint lanes (4 x 6 studs) with start and finish lines
	local s = Y.SprintLanes
	Kit.box(f, CFrame.new((s.X0 + s.X1) / 2, y + 0.06, (s.Z0 + s.Z1) / 2), Vector3.new(s.X1 - s.X0, 0.12, s.Z1 - s.Z0), "TrackRed", { Collide = false })
	for l = 0, 4 do
		Kit.box(f, CFrame.new(s.X0 + l * 6, y + 0.13, (s.Z0 + s.Z1) / 2), Vector3.new(0.2, 0.02, s.Z1 - s.Z0), "FabricWhite", Kit.DETAIL)
	end
	for _, z in { Y.SprintStartZ, Y.SprintFinishZ } do
		Kit.box(f, CFrame.new((s.X0 + s.X1) / 2, y + 0.14, z), Vector3.new(s.X1 - s.X0, 0.02, 0.6), "FabricWhite", Kit.DETAIL)
	end
	Gameplay.checkpoint(f, "Sprint", 0, CFrame.new((s.X0 + s.X1) / 2, y + 4, Y.SprintStartZ), Vector3.new(s.X1 - s.X0, 8, 1))
	Gameplay.checkpoint(f, "Sprint", 1, CFrame.new((s.X0 + s.X1) / 2, y + 4, Y.SprintFinishZ), Vector3.new(s.X1 - s.X0, 8, 1))
	for i = 1, 6 do
		Gameplay.eventSpot(f, "SprintRace", "Lane", i, CFrame.new(s.X0 + 2 + (i - 1) * 4, y + 3, Y.SprintStartZ - 3))
	end
	-- finish gantry
	for _, x in { s.X0 - 1, s.X1 + 1 } do
		Kit.box(f, CFrame.new(x, y + 6, Y.SprintFinishZ), Vector3.new(0.8, 12, 0.8), "PowderBlack")
	end
	local banner = Kit.box(f, CFrame.new((s.X0 + s.X1) / 2, y + 11, Y.SprintFinishZ), Vector3.new(s.X1 - s.X0 + 2.6, 2, 0.6), "Ink")
	Kit.sign(banner, "FINISH", { Face = Enum.NormalId.Back })

	obstacleCourse(f, y)

	-- strongman zone
	local st = Y.Strongman
	Kit.box(f, CFrame.new((st.X0 + st.X1) / 2, y + 0.06, (st.Z0 + st.Z1) / 2), Vector3.new(st.X1 - st.X0, 0.12, st.Z1 - st.Z0), "TurfDark", Kit.DETAIL)
	Fit.pack(f, st, y, "E", {
		{ Type = "TireFlip", Tier = 3, Count = 2 },
		{ Type = "LogPress", Tier = 3, Count = 2 },
		{ Type = "AtlasStone", Tier = 3, Count = 2 },
		{ Type = "SledPush", Tier = 3, Count = 2 },
		{ Type = "PullUpBar", Tier = 3, Count = 2 },
		{ Type = "BattleRopes", Tier = 3 },
	}, nil, { AreaId = "Yard", Aisle = 6, Gap = 4 })
	Props.bleachers(f, Kit.place(-250, y, 86, 180), 30, 4, "PowderGraphite")
	for _, p in { { -190, -120 }, { -190, 120 }, { -420, -120 }, { -420, 120 }, { -300, -125 }, { -300, 125 } } do
		Props.lampPost(f, CFrame.new(p[1], y, p[2]), "Flood")
	end
	for _, p in { { -200, -100 }, { -205, 100 }, { -430, 0 }, { -360, -110 } } do
		Props.tree(f, CFrame.new(p[1], y, p[2]), "Oak", 1.1)
	end
end

return M
