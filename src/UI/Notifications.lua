local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)
local Notifications = {}
Notifications.__index = Notifications

function Notifications.new(screen, config)
	local holder = Components.create("Frame", {
		BackgroundTransparency = 1,
		ZIndex = 50,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(320, 320),
	}, screen)
	Components.create("UIListLayout", {
		Padding = UDim.new(0, 8),
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, holder)
	return setmetatable({ holder = holder, config = config, sequence = 0 }, Notifications)
end

function Notifications:Show(message, isError)
	if not self.holder.Parent or (not self.config:Get().notifications and not isError) then
		return
	end
	self.sequence += 1
	local children = {}
	for _, child in self.holder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(children, child)
		end
	end
	if #children >= 3 then
		table.sort(children, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		children[1]:Destroy()
	end
	local toast = Components.card(self.holder, 70)
	toast.LayoutOrder = self.sequence
	Components.text(
		toast,
		isError and "ACTION REQUIRED" or "MOHAMMAD & ALI",
		10,
		isError and Theme.danger or Theme.cyan,
		{ Position = UDim2.fromOffset(14, 9), Size = UDim2.new(1, -28, 0, 16), Font = Theme.bold }
	)
	Components.text(
		toast,
		tostring(message),
		12,
		Theme.text,
		{ Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 34), TextWrapped = true }
	)
	task.delay(5, function()
		if toast.Parent then
			toast:Destroy()
		end
	end)
end

return Notifications
