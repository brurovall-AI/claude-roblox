--!strict
--[[
	Builds part-based training gear (gloves, shoes, belt, wraps, headband) and
	welds it to an R15 character. Called by CharacterService whenever the
	character spawns or the equipped gear changes.

	apply(character, equipped) must be idempotent: remove previously attached
	gear (folder "IronhavenGear" under the character) before attaching new gear.
	(Implemented by the progression/shop slice.)
]]

local GearVisuals = {}

function GearVisuals.apply(character: Model, equipped: { [string]: string })
	local old = character:FindFirstChild("IronhavenGear")
	if old then
		old:Destroy()
	end
	local _ = equipped
end

return GearVisuals
