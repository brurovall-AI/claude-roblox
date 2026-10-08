--!strict
--[[
	Declarative instance builder:

		local frame = New("Frame", {
			Size = UDim2.fromOffset(200, 40),
			BackgroundColor3 = Theme.Color.Surface1,
			Parent = parent,
		}, {
			New("UICorner", { CornerRadius = Theme.Radius.Medium }),
			Label = New("TextLabel", { Text = "Hi" }),   -- named children
		})

	Special prop keys: Parent (applied last), [event name] = function for
	RBXScriptSignals given as `On<Event>` e.g. OnActivated = fn.
]]

local function New(className: string, props: { [string]: any }?, children: { [any]: Instance }?): any
	local inst = Instance.new(className)
	local parent: Instance? = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			elseif string.sub(key, 1, 2) == "On" and type(value) == "function" then
				local signal = (inst :: any)[string.sub(key, 3)]
				signal:Connect(value)
			else
				(inst :: any)[key] = value
			end
		end
	end
	if children then
		for key, child in children do
			if type(key) == "string" then
				child.Name = key
			end
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

return New
