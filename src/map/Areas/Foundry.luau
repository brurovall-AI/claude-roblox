--!strict
-- The Foundry: heavy lifting. Tier-4 racks and platforms, tier-5 heavy platform at the north end.
local Context = require("../Context")
local Fit = require("./Fit")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")

local M = {}

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "Foundry")
	local r = Layout.L2.Foundry
	local y = Layout.Y.L2
	local keep: { Fit.Rect } = { Fit.doorKeepout(Layout.door("L2", "HallwayToFoundry"), 12) }
	for _, z in { -50, 0, 50 } do
		table.insert(keep, Fit.rect(-110, -100, z - 5, z + 5))
	end
	-- safety-yellow walkway down the middle
	for _, x in { -110, -100 } do
		Kit.box(f, CFrame.new(x, y + 0.04, -20), Vector3.new(0.5, 0.08, 156), "PowderYellow", Kit.DETAIL)
	end
	Fit.pack(f, Fit.rect(r.X0, -112, r.Z0, 60), y, "W", {
		{ Type = "SquatRack", Tier = 4, Count = 4 },
		{ Decor = "PlateTree", Tier = 4, Count = 2 },
	}, keep, { AreaId = "Foundry", Aisle = 6 })
	Fit.pack(f, Fit.rect(-98, r.X1, r.Z0, 60), y, "E", {
		{ Type = "Deadlift", Tier = 4, Count = 4 },
		{ Type = "BenchPress", Tier = 4, Count = 3 },
		{ Decor = "BarbellRack", Tier = 4, Length = 8 },
	}, keep, { AreaId = "Foundry", Aisle = 6 })
	-- heavy platform (tier 5)
	Kit.box(f, CFrame.new(-105, y + 0.5, 81), Vector3.new(86, 1, 36), "DiamondPlate")
	Kit.box(f, CFrame.new(-105, y + 1.02, 63.2), Vector3.new(86, 0.06, 0.5), "PowderYellow", Kit.DETAIL)
	Fit.pack(f, Fit.rect(r.X0, r.X1, 64, r.Z1), y + 1, "N", {
		{ Type = "SquatRack", Tier = 5, Count = 2 },
		{ Type = "Deadlift", Tier = 5, Count = 2 },
		{ Type = "BenchPress", Tier = 5, Count = 2 },
	}, nil, { AreaId = "Foundry", Gap = 4 })
	Props.wallSign(f, Fit.wallCf(r, "E", -60, y + 16, 0.6), "THE FOUNDRY", Vector2.new(30, 4.5), "Brand")
	for _, z in { -80, -30, 20 } do
		Props.chalkBowl(f, CFrame.new(-105, y, z))
	end
	Props.plateStack(f, CFrame.new(-145, y, 58), "Rubber", 5)
	Props.cleaningStation(f, Fit.againstWall(r, "S", -105, y, 1.6))
	Fit.lights(f, r, Layout.CEIL.L2 - 2.6, "Industrial", 26, nil, { Brightness = 2, Range = 44, Drop = 2 })
end

return M
