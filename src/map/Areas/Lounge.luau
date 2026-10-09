--!strict
-- The Lounge: juice bar, companion corner, boutique, selfie wall, sofas.
local Context = require("../Context")
local Fit = require("./Fit")
local Gameplay = require("../Gameplay")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")

local M = {}

local function promptPad(f: Instance, cf: CFrame): Part
	return Kit.box(f, cf, Vector3.new(2.6, 0.2, 1), "Brass", Kit.DETAIL)
end

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "Lounge")
	local r = Layout.G.Lounge
	local y = Layout.Y.G

	-- Juice bar along the east wall
	Props.counter(f, Kit.place(141, y, -70, 90), 22, 4, "Marble", "Walnut")
	Gameplay.shopCounter(f, "JuiceBar", promptPad(f, CFrame.new(138.6, y + 3.9, -70)), "Juice Bar · Boosts")
	Props.fridge(f, Fit.againstWall(r, "E", -78, y, 2.4))
	Props.fridge(f, Fit.againstWall(r, "E", -74.5, y, 2.4))
	Props.shelf(f, Fit.againstWall(r, "E", -62, y, 1.6), 10, 8, "Shakers")
	Props.wallSign(f, Fit.wallCf(r, "E", -70, y + 12), "JUICE BAR", Vector2.new(16, 2.6), "Neon")
	for i = 0, 5 do
		Props.stool(f, CFrame.new(136.5, y, -79 + i * 3.6))
	end

	-- Companion corner (north-west)
	for i, x in { 80, 88, 96 } do
		Kit.cylY(f, CFrame.new(x, y + 1.2, -46), 2.4, 3.2, "MarbleDark")
		Kit.cylY(f, CFrame.new(x, y + 2.45, -46), 0.1, 3.4, "Brass", Kit.DETAIL)
		local _ = i
	end
	Gameplay.shopCounter(f, "Companions", promptPad(f, CFrame.new(88, y + 2.6, -48)), "Training Crew · Companions")
	Props.wallSign(f, Fit.wallCf(r, "N", 88, y + 10), "TRAINING CREW", Vector2.new(16, 2.2), "Area")

	-- Boutique (south-west)
	Props.counter(f, Kit.place(84, y, -86, 0), 10, 3, "Walnut", "Walnut")
	Gameplay.shopCounter(f, "Cosmetics", promptPad(f, CFrame.new(84, y + 3.8, -88)), "Boutique · Cosmetics")
	Props.shelf(f, Fit.againstWall(r, "S", 84, y, 1.6), 14, 8, "Merch")

	-- Selfie wall (north wall, east of the companion corner)
	Kit.box(f, CFrame.new(118, y + 8, -40.9), Vector3.new(22, 16, 0.6), "PlasterGreen")
	Props.logo(f, Kit.place(118, y + 10, -41.3, 0), 12, "Brass")
	Props.ringLight(f, Kit.place(111, y, -52, -20))
	Props.ringLight(f, Kit.place(125, y, -52, 20))
	Gameplay.photoSpot(f, Kit.place(118, y + 3, -45, 0), CFrame.lookAt(Vector3.new(118, y + 5.4, -57), Vector3.new(118, y + 4.4, -45)))

	-- Sofa groups
	for _, c in { { 104, -80 }, { 104, -62 } } do
		Props.rug(f, CFrame.new(c[1], y, c[2]), Vector2.new(16, 11), "Carpet")
		Props.sofa(f, Kit.place(c[1], y, c[2] - 4.5, 180), 3, "Velvet")
		Props.armchair(f, Kit.place(c[1] - 6, y, c[2] + 2, 135), "Leather")
		Props.armchair(f, Kit.place(c[1] + 6, y, c[2] + 2, -135), "Leather")
		Props.coffeeTable(f, Kit.place(c[1], y, c[2], 0))
	end
	Props.plant(f, CFrame.new(146, y, -96), "Palm", 1.3)
	Props.plant(f, CFrame.new(64, y, -44), "Monstera", 1.2)
	Props.plant(f, CFrame.new(122, y, -96), "Olive", 1.2)
	Props.vending(f, Fit.againstWall(r, "S", 136, y, 3), "Drinks")
	Fit.lights(f, r, Layout.CEIL.G, "Pendant", 16, nil, { Drop = 6, Brightness = 1.4, Range = 26 })
end

return M
