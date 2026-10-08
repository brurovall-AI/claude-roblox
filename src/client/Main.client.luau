--!strict
--[[
	Client bootstrap. Every ModuleScript under Controllers (recursively) is a controller:

		local MyController = {}
		MyController.Priority = 50        -- optional; lower runs first (default 100)
		function MyController.Init() end  -- build UI / connect remotes; must not yield
		function MyController.Start() end -- runs in its own thread after every Init
		return MyController
]]

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Controllers = script.Parent:WaitForChild("Controllers")

type Controller = { Priority: number?, Init: (() -> ())?, Start: (() -> ())? }
type Entry = { name: string, mod: Controller }

local loaded: { Entry } = {}
for _, inst in Controllers:GetDescendants() do
	if inst:IsA("ModuleScript") then
		local ok, mod = pcall(require, inst)
		if ok and type(mod) == "table" then
			table.insert(loaded, { name = inst.Name, mod = mod :: Controller })
		else
			warn(`[Client] failed to load {inst:GetFullName()}: {mod}`)
		end
	end
end

table.sort(loaded, function(a: Entry, b: Entry)
	local pa, pb = a.mod.Priority or 100, b.mod.Priority or 100
	if pa == pb then
		return a.name < b.name
	end
	return pa < pb
end)

for _, entry in loaded do
	local init = entry.mod.Init
	if init then
		local ok, err = pcall(init)
		if not ok then
			warn(`[Client] {entry.name}.Init failed: {err}`)
		end
	end
end

for _, entry in loaded do
	local start = entry.mod.Start
	if start then
		task.spawn(function()
			local ok, err = pcall(start)
			if not ok then
				warn(`[Client] {entry.name}.Start failed: {err}`)
			end
		end)
	end
end
