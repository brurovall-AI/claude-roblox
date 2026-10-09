--!strict
-- Cardio Deck: three terraces facing the north glass wall and the city.
local Context = require("../Context")
local Fit = require("./Fit")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")

local M = {}

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "Cardio")
	local r = Layout.G.Cardio
	local y = Layout.Y.G
	local opts = { AreaId = "Cardio" }
	local keep = {
		Fit.doorKeepout(Layout.door("G", "EastCorridorToCardio"), 10),
		Fit.doorKeepout(Layout.door("G", "MainHallToCardio"), 10),
	}
	-- terraces: back (south) highest
	local terraces: { { z0: number, z1: number, h: number, items: { Fit.Item } } } = {
		{ z0 = 30, z1 = 50, h = 2, items = { { Type = "Treadmill", Tier = 3, Count = 2 }, { Type = "Rower", Tier = 3, Count = 2 } } },
		{ z0 = 50, z1 = 72, h = 1, items = { { Type = "Bike", Tier = 2, Count = 6 }, { Type = "Rower", Tier = 2, Count = 4 } } },
		{ z0 = 72, z1 = 99, h = 0, items = { { Type = "Treadmill", Tier = 2, Count = 6 } } },
	}
	for _, t in terraces do
		local rect = Fit.rect(72, 148, t.z0, t.z1)
		if t.h > 0 then
			Kit.box(f, CFrame.new(110, y + t.h / 2, (t.z0 + t.z1) / 2), Vector3.new(76, t.h, t.z1 - t.z0), "ConcretePolished")
			Kit.box(f, CFrame.new(110, y + t.h - 0.03, t.z1 - 0.2), Vector3.new(76, 0.1, 0.4), "RubberTeal", Kit.DETAIL)
		end
		Fit.pack(f, rect, y + t.h, "N", t.items, keep, opts)
	end
	Props.tv(f, Kit.place(90, y + 14, 27.2, 180), 8, "IRONHAVEN CARDIO")
	Props.tv(f, Kit.place(130, y + 14, 27.2, 180), 8, "TRAIN HARD · RECOVER SMART")
	Props.waterFountain(f, Fit.wallCf(r, "E", 40, y + 1.8))
	Props.fan(f, CFrame.new(146, y, 96), "Standing")
	Props.fan(f, CFrame.new(74, y, 96), "Standing")
	Props.wallSign(f, Fit.wallCf(r, "E", 70, y + 14), "CARDIO DECK", Vector2.new(14, 2.4), "Area")
	Fit.lights(f, r, Layout.CEIL.G, "Downlight", 15, nil, { Brightness = 1.2, Range = 24 })
end

return M
