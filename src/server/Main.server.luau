--!strict
--[[
	Server bootstrap. Every ModuleScript under Services (recursively) is a service:

		local MyService = {}
		MyService.Priority = 50        -- optional; lower runs Init/Start first (default 100)
		function MyService.Init() end  -- create remotes / register handlers; must not yield
		function MyService.Start() end -- connect to players, start loops (runs in its own thread)
		return MyService
]]

local Services = script.Parent:WaitForChild("Services")

type Service = { Priority: number?, Init: (() -> ())?, Start: (() -> ())? }
type Entry = { name: string, mod: Service }

local loaded: { Entry } = {}
for _, inst in Services:GetDescendants() do
	if inst:IsA("ModuleScript") then
		local ok, mod = pcall(require, inst)
		if ok and type(mod) == "table" then
			table.insert(loaded, { name = inst.Name, mod = mod :: Service })
		else
			warn(`[Server] failed to load {inst:GetFullName()}: {mod}`)
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
			warn(`[Server] {entry.name}.Init failed: {err}`)
		end
	end
end

for _, entry in loaded do
	local start = entry.mod.Start
	if start then
		task.spawn(function()
			local ok, err = pcall(start)
			if not ok then
				warn(`[Server] {entry.name}.Start failed: {err}`)
			end
		end)
	end
end

print(`[Ironhaven] server ready ({#loaded} services)`)
