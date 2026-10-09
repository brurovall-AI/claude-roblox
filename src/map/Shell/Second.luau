--!strict
--[[
	Second floor (Y = 28) architecture: the L2 slab (its underside is the
	ground-floor ceiling), finishes, partitions, the atrium void edge (walnut
	fascia + glass balustrade) and the Foundry's exposed black-steel structure.
	Engine: Shell/Ground (Ground.Shell).
]]

local Context = require("../Context")
local Ground = require("./Ground")
local Kit = require("../Kit")
local Layout = require("../Layout")

local Shell = Ground.Shell

local M = {}

-- Walnut fascia with a brass reveal on the slab edge around the atrium void.
local function fascia(parent: Instance, x0: number, x1: number, z0: number, z1: number)
	local y = Layout.Y.L2
	Shell.plate(parent, x0, x1, z0, z1, y - 2.6, y, "Walnut")
	Shell.plate(parent, x0, x1, z0, z1, y - 2.72, y - 2.6, "Brass", Kit.DETAIL)
end

function M.build(ctx: Context.Ctx)
	local spec = Shell.SPECS.L2
	local root = Kit.folder(ctx.Structure, "Second")
	local y = spec.Y

	local slab = Kit.folder(root, "Slab")
	Shell.slabStructure(slab, Layout.Building, y, spec.Holes, Shell.SPECS.G)
	Shell.slabFinish(slab, spec)

	Shell.partitions(root, spec)

	-- Atrium void: fascia on the exposed slab edges + glass balustrade with brass rail
	local atrium = Kit.folder(root, "AtriumEdge")
	local v = Layout.AtriumVoid
	local gs = Layout.GrandStair
	fascia(atrium, v.X0, v.X1, v.Z0, v.Z0 + 0.3)
	fascia(atrium, v.X0, v.X0 + 0.3, v.Z0 + 0.3, v.Z1)
	fascia(atrium, v.X1 - 0.3, v.X1, v.Z0 + 0.3, v.Z1)
	-- north edge sits over the Lobby/Main Hall wall: fascia proud of the wall face
	fascia(atrium, v.X0 + 0.3, gs.X0, v.Z1 - 0.8, v.Z1 - 0.5)
	fascia(atrium, gs.X1, v.X1 - 0.3, v.Z1 - 0.8, v.Z1 - 0.5)

	local inset = 0.5
	local sw = Vector3.new(v.X0 - inset, y, v.Z0 - inset)
	local se = Vector3.new(v.X1 + inset, y, v.Z0 - inset)
	local nw = Vector3.new(v.X0 - inset, y, v.Z1 + inset)
	local ne = Vector3.new(v.X1 + inset, y, v.Z1 + inset)
	Kit.railing(atrium, sw, se, 3.6, "Glass", "Brass")
	Kit.railing(atrium, sw, nw, 3.6, "Glass", "Brass")
	Kit.railing(atrium, se, ne, 3.6, "Glass", "Brass")
	Kit.railing(atrium, nw, Vector3.new(gs.X0 - 0.2, y, v.Z1 + inset), 3.6, "Glass", "Brass")
	Kit.railing(atrium, Vector3.new(gs.X1 + 0.2, y, v.Z1 + inset), ne, 3.6, "Glass", "Brass")

	-- Foundry: black steel columns (only at X = -105, Z = -50/0/50) + exposed girders
	local foundry = Kit.folder(root, "FoundryStructure")
	local fr = Layout.L2.Foundry
	for _, z in { -50, 0, 50 } do
		Shell.column(foundry, -105, z, y, spec.Ceil, "PowderBlack", "DiamondPlate")
		Shell.plate(foundry, fr.X0 + 1, fr.X1 - 0.5, z - 0.6, z + 0.6, spec.Ceil - 2.6, spec.Ceil, "PowderBlack")
	end
	Shell.plate(foundry, -105.7, -104.3, fr.Z0 + 1, fr.Z1 - 1, spec.Ceil - 2, spec.Ceil, "PowderBlack")
end

return M
