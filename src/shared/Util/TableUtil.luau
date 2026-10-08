--!strict
local TableUtil = {}

function TableUtil.deepCopy<T>(t: T): T
	local value: any = t
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = TableUtil.deepCopy(v)
	end
	return out :: any
end

-- Fills keys missing from `target` using `template` (recursively). Existing values win.
function TableUtil.reconcile(target: { [any]: any }, template: { [any]: any }): { [any]: any }
	for k, v in template do
		if target[k] == nil then
			target[k] = TableUtil.deepCopy(v)
		elseif type(v) == "table" and type(target[k]) == "table" and next(v) ~= nil then
			-- only recurse into "record" tables (non-empty templates); empty templates are maps
			TableUtil.reconcile(target[k], v)
		end
	end
	return target
end

function TableUtil.count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

function TableUtil.keys<K>(t: { [K]: any }): { K }
	local out = {}
	for k in t do
		table.insert(out, k)
	end
	return out
end

-- Path helpers for replication: {"Stats","Strength"} style paths.
function TableUtil.getPath(root: { [any]: any }, path: { any }): any
	local node: any = root
	for _, key in path do
		if type(node) ~= "table" then
			return nil
		end
		node = node[key]
	end
	return node
end

function TableUtil.setPath(root: { [any]: any }, path: { any }, value: any)
	local node: any = root
	for i = 1, #path - 1 do
		local key = path[i]
		if type(node[key]) ~= "table" then
			node[key] = {}
		end
		node = node[key]
	end
	node[path[#path]] = value
end

return TableUtil
