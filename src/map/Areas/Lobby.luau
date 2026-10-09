--!strict
-- Reception & atrium: first impression, pro shop desk, brand wall, wayfinding.
local Context = require("../Context")
local Fit = require("./Fit")
local Gameplay = require("../Gameplay")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")

local M = {}

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "Lobby")
	local r = Layout.G.Lobby
	local y = Layout.Y.G
	local atrium = Layout.AtriumVoid

	-- Reception desk + pro shop (west of the spawn, facing the entrance)
	local desk = Props.counter(f, Kit.place(-32, y, -76, 0), 20, 4, "Travertine", "Walnut")
	local _ = desk
	local promptPart = Kit.box(f, CFrame.new(-32, y + 3.9, -78.4), Vector3.new(3, 0.2, 0.8), "Brass", Kit.DETAIL)
	Gameplay.shopCounter(f, "ProShop", promptPart, "Pro Shop · Gear")
	Props.shelf(f, Fit.againstWall(r, "W", -76, y, 1.6), 18, 9, "Supplements")
	Props.logo(f, Fit.wallCf(r, "W", -76, 15), 20, "Brass")
	Props.tv(f, Kit.place(-38, y + 5.2, -74.2, 180), 3.2, "WELCOME TO IRONHAVEN")
	Props.tv(f, Kit.place(-26, y + 5.2, -74.2, 180), 3.2, "PRO SHOP · GEAR")

	-- Wayfinding beside the grand stair
	Props.wallSign(f, Kit.place(-15, y + 9, -60, 0), "UP  ·  PRO FLOOR · FOUNDRY · ARENA · VIP", Vector2.new(22, 1.8), "Wayfinding")
	Props.wallSign(f, Kit.place(42, y + 9, -58, 0), "DOWN  ·  BOXING · RECOVERY · PRIVATE", Vector2.new(20, 1.8), "Wayfinding")
	Props.wallSign(f, Fit.wallCf(r, "E", -74, 18), "THE LOUNGE  →", Vector2.new(14, 2), "Wayfinding")

	-- Waiting lounge on the east side of the entrance
	Props.rug(f, CFrame.new(30, y, -84), Vector2.new(18, 12), "Carpet")
	Props.sofa(f, Kit.place(30, y, -89, 180), 3, "Leather")
	Props.sofa(f, Kit.place(30, y, -79, 0), 3, "Leather")
	Props.coffeeTable(f, Kit.place(30, y, -84, 0))
	Props.plant(f, CFrame.new(41, y, -90), "Olive", 1.2)
	Props.plant(f, CFrame.new(19, y, -90), "Fiddle", 1.2)

	-- Entrance planters frame the doors
	Props.planter(f, CFrame.new(-18, y, -95), Vector3.new(6, 2.2, 3), "Travertine", "Bush")
	Props.planter(f, CFrame.new(18, y, -95), Vector3.new(6, 2.2, 3), "Travertine", "Bush")
	Props.plant(f, CFrame.new(-55, y, -95), "Monstera", 1.3)
	Props.plant(f, CFrame.new(55, y, -95), "Snake", 1.3)
	Props.cleaningStation(f, Fit.againstWall(r, "W", -56, y, 1.6))
	Props.fireExtinguisher(f, Fit.wallCf(r, "W", -60, y + 3))
	Props.exitSign(f, Kit.place(0, y + 15.5, -98.8, 180))

	-- Lighting: warm downlights around, statement globes in the double-height atrium
	Fit.lights(f, r, Layout.CEIL.G, "Downlight", 20, { atrium, Fit.rect(-12, 12, -62, -8) }, { Color = Color3.fromRGB(255, 226, 190), Brightness = 1.3, Range = 30 })
	for _, p in { { -20, -50 }, { 20, -50 }, { -20, -24 }, { 20, -24 } } do
		Props.ceilingLight(f, CFrame.new(p[1], Layout.CEIL.L2, p[2]), "Globe", { Drop = 12, Brightness = 1.6, Range = 34 })
	end
end

return M
