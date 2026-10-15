local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Theme)
local Components = {}

function Components.create(class, props, parent)
	local instance = Instance.new(class)
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

function Components.corner(parent, radius)
	return Components.create("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, parent)
end

function Components.stroke(parent, color)
	return Components.create(
		"UIStroke",
		{ Color = color or Theme.border, Thickness = 1, Transparency = 0.25 },
		parent
	)
end

function Components.text(parent, text, size, color, props)
	local settings = {
		BackgroundTransparency = 1,
		Text = text,
		Font = Theme.font,
		TextSize = size or 14,
		TextColor3 = color or Theme.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		BorderSizePixel = 0,
	}
	for key, value in props or {} do
		settings[key] = value
	end
	return Components.create("TextLabel", settings, parent)
end

function Components.tween(instance, properties)
	local tween = TweenService:Create(instance, TweenInfo.new(0.16, Enum.EasingStyle.Quad), properties)
	tween:Play()
	return tween
end

function Components.button(parent, text, callback, cleanup, props)
	local settings = {
		Text = text,
		Font = Theme.bold,
		TextSize = 13,
		TextColor3 = Theme.text,
		BackgroundColor3 = Theme.raised,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(150, 36),
	}
	for key, value in props or {} do
		settings[key] = value
	end
	local button = Components.create("TextButton", settings, parent)
	Components.corner(button, 8)
	cleanup:Add(button.Activated:Connect(callback))
	local baseTransparency = button.BackgroundTransparency
	cleanup:Add(button.MouseEnter:Connect(function()
		if button.Active then
			Components.tween(button, { BackgroundTransparency = math.max(baseTransparency, 0.1) })
		end
	end))
	cleanup:Add(button.MouseLeave:Connect(function()
		if button.Active then
			Components.tween(button, { BackgroundTransparency = baseTransparency })
		end
	end))
	return button
end

function Components.stack(parent, gap)
	return Components.create(
		"UIListLayout",
		{ Padding = UDim.new(0, gap or 10), SortOrder = Enum.SortOrder.LayoutOrder },
		parent
	)
end

function Components.card(parent, height)
	local card = Components.create(
		"Frame",
		{ Size = UDim2.new(1, -2, 0, height), BackgroundColor3 = Theme.surface, BorderSizePixel = 0 },
		parent
	)
	Components.corner(card)
	Components.stroke(card)
	return card
end

function Components.note(parent, message, height)
	local frame = Components.card(parent, height or 62)
	Components.text(
		frame,
		message,
		12,
		Theme.muted,
		{ Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 1, -20), TextWrapped = true }
	)
	return frame
end

local function row(parent, title, description, height)
	local frame = Components.card(parent, height or 68)
	Components.text(
		frame,
		title,
		14,
		Theme.text,
		{ Position = UDim2.fromOffset(16, 12), Size = UDim2.new(0.64, 0, 0, 20), Font = Theme.bold }
	)
	Components.text(
		frame,
		description,
		11,
		Theme.muted,
		{ Position = UDim2.fromOffset(16, 34), Size = UDim2.new(0.67, -16, 0, 22), TextWrapped = true }
	)
	return frame
end

function Components.toggle(parent, title, description, callback, cleanup, supported, onUnavailable)
	local frame = row(parent, title, description)
	local enabled, value = supported ~= false, false
	local track = Components.button(frame, "", function()
		if enabled then
			callback(not value)
		elseif onUnavailable then
			onUnavailable()
		end
	end, cleanup, { Size = UDim2.fromOffset(48, 26), Position = UDim2.new(1, -66, 0, 20) })
	track:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 20)
	local knob = Components.create("Frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Theme.muted,
		BorderSizePixel = 0,
	}, track)
	Components.corner(knob, 20)
	track.Active, track.Selectable = enabled or onUnavailable ~= nil, enabled or onUnavailable ~= nil
	track.BackgroundTransparency = if enabled then 0 else 0.55
	return {
		Set = function(_, nextValue)
			value = nextValue
			Components.tween(
				track,
				{ BackgroundColor3 = if value and enabled then Theme.cyan else Theme.raised }
			)
			Components.tween(knob, {
				Position = UDim2.fromOffset(if value then 26 else 4, 4),
				BackgroundColor3 = if value then Theme.background else Theme.muted,
			})
		end,
	}
end

function Components.slider(parent, title, description, minimum, maximum, step, callback, cleanup, supported)
	local frame = row(parent, title, description, 92)
	local enabled = supported ~= false
	local output = Components.text(frame, "", 14, Theme.cyan, {
		Position = UDim2.new(1, -100, 0, 12),
		Size = UDim2.fromOffset(82, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Theme.bold,
	})
	local bar = Components.create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.raised,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -36, 0, 16),
		Position = UDim2.fromOffset(18, 66),
		Active = enabled,
		Selectable = enabled,
	}, frame)
	Components.corner(bar, 10)
	local fill = Components.create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = if enabled then Theme.cyan else Theme.muted,
		BorderSizePixel = 0,
	}, bar)
	Components.corner(fill, 10)
	local dragging, touch, value = false, nil, minimum
	local function set(nextValue)
		value = math.clamp(nextValue, minimum, maximum)
		output.Text = string.format(if step < 1 then "%.1f" else "%.0f", value)
		fill.Size = UDim2.fromScale((value - minimum) / (maximum - minimum), 1)
	end
	local function inputAt(x)
		local fraction = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
		local nextValue =
			math.clamp(math.round((minimum + fraction * (maximum - minimum)) / step) * step, minimum, maximum)
		set(nextValue)
		callback(nextValue)
	end
	cleanup:Add(bar.InputBegan:Connect(function(input)
		if not enabled then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging, touch = true, if input.UserInputType == Enum.UserInputType.Touch then input else nil
			inputAt(input.Position.X)
		end
	end))
	cleanup:Add(UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				(touch and input == touch)
				or (not touch and input.UserInputType == Enum.UserInputType.MouseMovement)
			)
		then
			inputAt(input.Position.X)
		end
	end))
	cleanup:Add(UserInputService.InputEnded:Connect(function(input)
		if input == touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging, touch = false, nil
		end
	end))
	cleanup:Add(bar.InputBegan:Connect(function(input)
		if not enabled then
			return
		end
		if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.DPadLeft then
			callback(math.max(minimum, value - step))
		elseif input.KeyCode == Enum.KeyCode.Right or input.KeyCode == Enum.KeyCode.DPadRight then
			callback(math.min(maximum, value + step))
		end
	end))
	return {
		Set = function(_, nextValue)
			set(nextValue)
		end,
	}
end

function Components.dropdown(parent, title, description, options, callback, cleanup)
	local frame = row(parent, title, description, 72)
	local selected = options[1]
	-- Compact, keyboard/touch accessible choice menu. Click reveals all options.
	local menu = Components.create("Frame", {
		Visible = false,
		ZIndex = 20,
		Size = UDim2.fromOffset(162, #options * 34 + 8),
		Position = UDim2.new(1, -180, 0, 56),
		BackgroundColor3 = Theme.raised,
		BorderSizePixel = 0,
	}, frame)
	Components.corner(menu, 8)
	Components.stroke(menu)
	local function close()
		menu.Visible = false
		frame.Size = UDim2.new(1, -2, 0, 72)
	end
	local opener = Components.button(frame, selected .. "  ▾", function()
		menu.Visible = not menu.Visible
		frame.Size = UDim2.new(1, -2, 0, if menu.Visible then 80 + #options * 34 else 72)
	end, cleanup, { Position = UDim2.new(1, -180, 0, 18), Size = UDim2.fromOffset(162, 36) })
	for index, option in options do
		Components.button(
			menu,
			option,
			function()
				close()
				callback(option)
			end,
			cleanup,
			{
				Position = UDim2.fromOffset(4, 4 + (index - 1) * 34),
				Size = UDim2.new(1, -8, 0, 32),
				ZIndex = 21,
			}
		)
	end
	cleanup:Add(frame:GetPropertyChangedSignal("Visible"):Connect(close))
	return {
		Set = function(_, value)
			selected = value
			opener.Text = selected .. "  ▾"
		end,
	}
end

return Components
