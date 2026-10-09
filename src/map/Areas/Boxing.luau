--!strict
-- Boxing Gym: brick, timber, a raised ring as the hero, bags and footwork drills.
local Context = require("../Context")
local Fit = require("./Fit")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")

local M = {}

local function ring(f: Instance, cx: number, y: number, cz: number)
	local size, h = 22, 3
	Kit.box(f, CFrame.new(cx, y + h / 2, cz), Vector3.new(size, h, size), "PowderBlack")
	Kit.box(f, CFrame.new(cx, y + h + 0.05, cz), Vector3.new(size - 0.4, 0.1, size - 0.4), "FabricBlue", Kit.DETAIL)
	Kit.box(f, CFrame.new(cx, y + h - 0.6, cz), Vector3.new(size + 0.2, 1, size + 0.2), "FabricRed", Kit.DETAIL)
	local half = size / 2 - 0.6
	local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
	for i, c in corners do
		local px, pz = cx + c[1] * half, cz + c[2] * half
		Kit.cylY(f, CFrame.new(px, y + h + 2.6, pz), 5.2, 0.5, "SteelBrushed")
		Kit.box(f, CFrame.new(px, y + h + 2.8, pz), Vector3.new(0.9, 3.6, 0.9), if i % 2 == 0 then "VinylRed" else "VinylBlack", Kit.DETAIL)
		local n = corners[i % 4 + 1]
		local qx, qz = cx + n[1] * half, cz + n[2] * half
		for k, ry in { 1.4, 2.6, 3.8 } do
			Kit.span(f, Vector3.new(px, y + h + ry, pz), Vector3.new(qx, y + h + ry, qz), 0.18, if k == 2 then "FabricWhite" else "FabricRed", Kit.DETAIL)
		end
	end
	for i = 1, 3 do -- steps
		Kit.box(f, CFrame.new(cx, y + i * 0.75 - 0.375, cz - size / 2 - (4 - i) * 1.2), Vector3.new(4, i * 0.75, 1.2), "WornTimber")
	end
end

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "Boxing")
	local r = Layout.B1.Boxing
	local y = Layout.Y.B1
	ring(f, -105, y, 30)
	local keep = { Fit.doorKeepout(Layout.door("B1", "ConcourseToBoxing"), 12), Fit.rect(-120, -90, 10, 50) }
	Fit.pack(f, Fit.rect(r.X0, r.X1, r.Z0, 6), y, "W", {
		{ Type = "HeavyBag", Tier = 3, Count = 4 },
		{ Type = "HeavyBag", Tier = 4, Count = 2 },
		{ Type = "SpeedBag", Tier = 3, Count = 3 },
		{ Type = "SpeedBag", Tier = 4, Count = 2 },
		{ Type = "AgilityLadder", Tier = 3, Count = 2 },
	}, keep, { AreaId = "Boxing", Aisle = 6, Gap = 4 })
	Props.mirror(f, Fit.wallCf(r, "W", -60, y + 5.5, 1.15), 30, 8, "PowderBlack")
	Props.wallSign(f, Fit.wallCf(r, "E", 30, y + 13, 0.6), "IRONHAVEN BOXING", Vector2.new(24, 3), "Brand")
	for i, z in { -90, -70, 40 } do
		Props.poster(f, Fit.wallCf(r, "E", z, y + 7, 0.6), Vector2.new(5, 7), if i == 2 then "Vintage" else "Boxing")
	end
	Props.bleachers(f, Kit.place(-80, y, 54, 180), 14, 3, "WornTimber")
	Props.towelStack(f, CFrame.new(-146, y, 56), 6)
	Props.waterBottle(f, CFrame.new(-92, y, 18))
	Fit.lights(f, r, Layout.CEIL.B1, "Pendant", 24, nil, { Drop = 4, Brightness = 1.9, Range = 34, Color = Color3.fromRGB(255, 200, 150) })
end

return M
