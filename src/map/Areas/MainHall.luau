--!strict
-- Main Training Hall: industrial hall with a functional turf lane down the middle.
local Context = require("../Context")
local Fit = require("./Fit")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")
local Equipment = require("../Equipment")

local M = {}

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "MainHall")
	local r = Layout.G.MainHall
	local y = Layout.Y.G
	local cols: { Fit.Rect } = {}
	for _, x in { -30, 30 } do
		for _, z in { 30, 70 } do
			table.insert(cols, Fit.rect(x - 4.5, x + 4.5, z - 4.5, z + 4.5))
		end
	end
	local keep = table.clone(cols)
	for _, name in { "LobbyToMainHallWest", "LobbyToMainHallEast", "MainHallToFreeWeights", "MainHallToCables", "MainHallToCardio" } do
		table.insert(keep, Fit.doorKeepout(Layout.door("G", name), 11))
	end
	table.insert(keep, Fit.rect(-13, 13, r.Z0, r.Z1)) -- turf lane

	-- Turf lane with yard lines
	Kit.box(f, CFrame.new(0, y + 0.06, 47), Vector3.new(24, 0.12, 94), "Turf", Kit.DETAIL)
	for i = 0, 9 do
		Kit.box(f, CFrame.new(0, y + 0.13, 2 + i * 10), Vector3.new(24, 0.02, 0.35), "FabricWhite", Kit.DETAIL)
	end
	for _, x in { -12.2, 12.2 } do
		Kit.box(f, CFrame.new(x, y + 0.13, 47), Vector3.new(0.4, 0.02, 94), "PowderYellow", Kit.DETAIL)
	end
	local opts: Equipment.BuildOpts = { AreaId = "MainHall" }
	for i, x in { -6, 0, 6 } do
		Equipment.build(f, "SledPush", if i == 2 then 3 else 2, Kit.place(x, y, 74, 180), opts)
		Equipment.build(f, "BattleRopes", if i == 2 then 3 else 2, Kit.place(x * 1.2, y, 24, 180), opts)
	end

	Fit.pack(f, Fit.rect(r.X0, -13, r.Z0, r.Z1), y, "W", {
		{ Decor = "Rig", Tier = 2, Length = 16 },
		{ Type = "PullUpBar", Tier = 2, Count = 2 },
		{ Type = "PullUpBar", Tier = 3 },
		{ Type = "PlyoBox", Tier = 2, Count = 3 },
		{ Decor = "PlyoBoxSet", Tier = 2 },
		{ Decor = "KettlebellRack", Tier = 2, Length = 8 },
	}, keep, { AreaId = "MainHall", Aisle = 6 })
	Fit.pack(f, Fit.rect(13, r.X1, r.Z0, r.Z1), y, "E", {
		{ Type = "ChestPress", Tier = 2, Count = 2 },
		{ Type = "LegPress", Tier = 2, Count = 2 },
		{ Type = "AgilityLadder", Tier = 2, Count = 2 },
		{ Decor = "MedBallRack", Tier = 2, Length = 6 },
	}, keep, { AreaId = "MainHall", Aisle = 6 })

	Props.wallSign(f, Fit.wallCf(r, "N", 0, y + 17, 1.15), "MAIN HALL", Vector2.new(30, 4.5), "Brand")
	Props.logo(f, Fit.wallCf(r, "N", 0, y + 9, 1.15), 14, "Light")
	Props.cleaningStation(f, Fit.againstWall(r, "N", -40, y, 1.6))
	Props.cleaningStation(f, Fit.againstWall(r, "N", 40, y, 1.6))
	Props.chalkBowl(f, CFrame.new(-18, y, 50))
	Props.fan(f, Fit.againstWall(r, "W", 88, y, 2), "Standing")
	Fit.lights(f, r, Layout.CEIL.G - 2.4, "Industrial", 24, nil, { Brightness = 1.6, Range = 34, Drop = 2 })
end

return M
