--!strict
-- Shared build context handed to every shell / site / area module.
export type Ctx = {
	Map: Model,
	Structure: Folder, -- walls, slabs, stairs, facades (architecture)
	Areas: Folder, -- per-area dressing; each area module creates Areas/<AreaName>
	Gameplay: Folder, -- gameplay markers (event spots, boards, counters, checkpoints)
	Exterior: Folder, -- site, landscaping, city
}
return {}
