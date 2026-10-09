--!strict
--[[
	Lower level (B1, Y = -22) architecture: base slab on grade, finishes,
	partitions and the Boxing gym's exposed steel beams. The B1 ceiling is the
	underside of the ground slab (Shell/Ground); the retaining walls around the
	basement footprint are built by Shell/Facade. Engine: Shell/Ground.
]]

local Context = require("../Context")
local Ground = require("./Ground")
local Kit = require("../Kit")
local Layout = require("../Layout")

local Shell = Ground.Shell

local M = {}

function M.build(ctx: Context.Ctx)
	local spec = Shell.SPECS.B1
	local root = Kit.folder(ctx.Structure, "Lower")

	local slab = Kit.folder(root, "Slab")
	Shell.slabStructure(slab, Layout.BasementFootprint, spec.Y, spec.Holes, nil)
	Shell.slabFinish(slab, spec)

	Shell.partitions(root, spec)

	-- Boxing: exposed dark steel beams across the brick hall
	local boxing = Kit.folder(root, "BoxingStructure")
	local b = Layout.B1.Boxing
	for z = b.Z0 + 32, b.Z1 - 16, 32 do
		Shell.plate(boxing, b.X0 + 1, b.X1 - 0.5, z - 0.5, z + 0.5, spec.Ceil - 1.8, spec.Ceil, "SteelDark")
	end
end

return M
