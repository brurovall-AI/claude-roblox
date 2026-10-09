--!strict
-- Locker rooms A and B + the east corridor; 24 personal locker slots.
local Context = require("../Context")
local Fit = require("./Fit")
local Gameplay = require("../Gameplay")
local Kit = require("../Kit")
local Layout = require("../Layout")
local Props = require("../Props")

local M = {}

function M.build(ctx: Context.Ctx)
	local f = Kit.folder(ctx.Areas, "Lockers")
	local y = Layout.Y.G
	local A, B, corridor = Layout.G.LockersA, Layout.G.LockersB, Layout.G.EastCorridor

	-- personal locker banks with 12 slots each: A south wall, B north wall
	local slot = 0
	for _, bank in { { rect = A, side = "S" }, { rect = B, side = "N" } } do
		local cf = Fit.againstWall(bank.rect, bank.side, 111, y, 2)
		Props.lockers(f, cf, 12, 2, "Oak")
		for i = 1, 12 do
			slot += 1
			local x = 111 - 12 + (i - 0.5) * 2
			local z = if bank.side == "S" then bank.rect.Z0 + 3.3 else bank.rect.Z1 - 3.3
			Gameplay.lockerSlot(f, slot, Kit.place(x, y + 4.6, z, if bank.side == "S" then 180 else 0))
		end
		-- second bank on the opposite wall + benches
		Props.lockers(f, Fit.againstWall(bank.rect, if bank.side == "S" then "N" else "S", 100, y, 2), 8, 2, "Oak")
		Props.bench(f, Kit.place(111, y, (bank.rect.Z0 + bank.rect.Z1) / 2, 90), 14, "Oak")
		-- shower stalls along the east wall
		for i = 0, 3 do
			local z = bank.rect.Z0 + 5 + i * 6.5
			Kit.box(f, CFrame.new(144, y + 4, z - 3), Vector3.new(10, 8, 0.4), "TileWhite")
			Kit.box(f, CFrame.new(148.5, y + 7.4, z), Vector3.new(0.6, 0.3, 0.6), "Chrome", Kit.DETAIL)
		end
		Kit.box(f, CFrame.new(144, y + 0.06, (bank.rect.Z0 + bank.rect.Z1) / 2), Vector3.new(10, 0.12, bank.rect.Z1 - bank.rect.Z0 - 2), "TileGrey", Kit.DETAIL)
		Props.towelRack(f, Fit.againstWall(bank.rect, bank.side, 132, y, 1.4))
		Props.mirror(f, Fit.wallCf(bank.rect, if bank.side == "S" then "N" else "S", 128, y + 6, 0.65), 10, 5, "Walnut")
		Fit.lights(f, bank.rect, Layout.CEIL.G, "Panel", 18, nil, { Brightness = 1.1, Range = 20 })
	end
	Props.wallSign(f, Fit.wallCf(corridor, "E", -24, y + 9, 0.6), "LOCKERS A", Vector2.new(6, 1.4), "Wayfinding")
	Props.wallSign(f, Fit.wallCf(corridor, "E", 10, y + 9, 0.6), "LOCKERS B", Vector2.new(6, 1.4), "Wayfinding")
	Props.waterFountain(f, Fit.wallCf(corridor, "W", 0, y + 1.8, 0.6))
	Fit.lights(f, corridor, Layout.CEIL.G, "Downlight", 18, nil, { Brightness = 1.1, Range = 18 })
end

return M
