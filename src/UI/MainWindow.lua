local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)
local Notifications = require(script.Parent.Notifications)
local Cleanup = require(script.Parent.Parent.Utils.Cleanup)
local MainWindow = {}
MainWindow.__index = MainWindow

function MainWindow.new(controller, config, adapter, logger, mode, playerGui, constructionCleanup)
	local self = setmetatable({
		controller = controller,
		config = config,
		adapter = adapter,
		cleanup = Cleanup.new(),
		bindings = {},
		pages = {},
		tabs = {},
		statusLabels = {},
		minimized = false,
	}, MainWindow)
	-- Register before creating widgets so a failed constructor can be rolled back.
	if constructionCleanup then
		constructionCleanup:Add(function()
			self:Destroy()
		end)
	end
	playerGui = playerGui or Players.LocalPlayer:WaitForChild("PlayerGui", 10)
	assert(playerGui, "Mohammad & Ali: cannot create GUI without PlayerGui")
	local screen = Components.create("ScreenGui", {
		Name = "MohammadAndAli",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 25,
		IgnoreGuiInset = false,
	}, playerGui)
	self.screen = screen
	self.notifications = Notifications.new(screen, config)
	local window = Components.create("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(960, 650),
		BackgroundColor3 = Theme.background,
		BorderSizePixel = 0,
	}, screen)
	self.window = window
	Components.corner(window, 16)
	Components.stroke(window)
	local scale = Components.create("UIScale", { Scale = 1 }, window)
	self.scale = scale
	local sidebar = Components.create(
		"Frame",
		{ Size = UDim2.new(0, 186, 1, 0), BackgroundColor3 = Theme.sidebar, BorderSizePixel = 0 },
		window
	)
	Components.corner(sidebar, 16)
	self.sidebar = sidebar
	Components.text(
		sidebar,
		"M / A",
		28,
		Theme.cyan,
		{ Position = UDim2.fromOffset(22, 27), Size = UDim2.fromOffset(140, 40), Font = Theme.bold }
	)
	Components.text(
		sidebar,
		"DUNGEON CONTROL",
		10,
		Theme.muted,
		{ Position = UDim2.fromOffset(23, 68), Size = UDim2.fromOffset(150, 20) }
	)
	local nav = Components.create(
		"Frame",
		{ Position = UDim2.fromOffset(12, 120), Size = UDim2.new(1, -24, 0, 320), BackgroundTransparency = 1 },
		sidebar
	)
	self.navLayout = Components.stack(nav, 8)
	self.navigation = nav
	local entries = {
		{ "Dashboard", "◈" },
		{ "Auto Farm", "◎" },
		{ "Dungeon", "▦" },
		{ "Movement", "↗" },
		{ "Settings", "≡" },
		{ "Credits", "◇" },
	}
	self.navEntries = entries
	for _, entry in entries do
		local button = Components.button(
			nav,
			entry[2] .. "   " .. entry[1],
			function()
				self:SelectTab(entry[1])
			end,
			self.cleanup,
			{
				Size = UDim2.new(1, 0, 0, 42),
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundColor3 = Theme.sidebar,
			}
		)
		Components.create("UIPadding", { PaddingLeft = UDim.new(0, 14) }, button)
		self.tabs[entry[1]] = button
	end
	Components.text(
		sidebar,
		"VERSION " .. Theme.version,
		10,
		Theme.muted,
		{ Position = UDim2.new(0, 23, 1, -70), Size = UDim2.fromOffset(150, 18) }
	)
	Components.text(
		sidebar,
		"CREATED FOR\nMOHAMMAD & ALI",
		11,
		Theme.purple,
		{ Position = UDim2.new(0, 23, 1, -48), Size = UDim2.fromOffset(150, 34), Font = Theme.bold }
	)
	local header = Components.create("Frame", {
		Name = "DragHandle",
		Active = true,
		Position = UDim2.fromOffset(210, 18),
		Size = UDim2.new(1, -234, 0, 62),
		BackgroundTransparency = 1,
	}, window)
	self.header = header
	self.brandTitle = Components.text(
		header,
		"MOHAMMAD & ALI",
		24,
		Theme.text,
		{ Size = UDim2.new(1, -180, 0, 32), Font = Theme.bold }
	)
	Components.text(
		header,
		"ANIME ZERO | AUTOMATION HUB",
		10,
		Theme.cyan,
		{ Position = UDim2.fromOffset(1, 36), Size = UDim2.fromOffset(390, 18) }
	)
	Components.button(header, "—", function()
		self:SetMinimized(true)
	end, self.cleanup, { Position = UDim2.new(1, -78, 0, 6), Size = UDim2.fromOffset(34, 30) })
	Components.button(
		header,
		"×",
		function()
			self:Hide()
		end,
		self.cleanup,
		{ Position = UDim2.new(1, -36, 0, 6), Size = UDim2.fromOffset(34, 30), TextColor3 = Theme.muted }
	)
	self.pageTitle = Components.text(
		window,
		"Dashboard",
		18,
		Theme.text,
		{ Position = UDim2.fromOffset(212, 96), Size = UDim2.new(1, -430, 0, 26), Font = Theme.bold }
	)
	self.modeLabel = Components.text(window, mode, 10, Theme.purple, {
		Position = UDim2.new(1, -300, 0, 100),
		Size = UDim2.fromOffset(274, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local content = Components.create("Frame", {
		Position = UDim2.fromOffset(210, 138),
		Size = UDim2.new(1, -234, 1, -210),
		BackgroundTransparency = 1,
	}, window)
	self.content = content
	for _, entry in entries do
		local page = Components.create("ScrollingFrame", {
			Name = entry[1],
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme.border,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}, content)
		Components.create("UIPadding", {
			PaddingTop = UDim.new(0, 2),
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 12),
		}, page)
		Components.stack(page, 10)
		self.pages[entry[1]] = page
	end
	local footer = Components.create(
		"Frame",
		{ Position = UDim2.new(0, 210, 1, -56), Size = UDim2.new(1, -234, 0, 40), BackgroundTransparency = 1 },
		window
	)
	self.footer = footer
	self.footerStatus = Components.text(
		footer,
		"●  IDLE",
		11,
		Theme.cyan,
		{ Size = UDim2.new(1, -180, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd }
	)
	Components.button(
		footer,
		"■  EMERGENCY STOP",
		function()
			controller:Stop("Emergency stop")
			self.notifications:Show("All automation stopped")
		end,
		self.cleanup,
		{
			Position = UDim2.new(1, -176, 0, 2),
			Size = UDim2.fromOffset(176, 36),
			TextColor3 = Theme.danger,
			BackgroundColor3 = Color3.fromRGB(45, 24, 36),
		}
	)
	self.restore = Components.button(
		screen,
		"M / A  ·  OPEN",
		function()
			self:Show()
		end,
		self.cleanup,
		{
			Visible = false,
			Position = UDim2.new(0, 16, 0.5, -22),
			Size = UDim2.fromOffset(144, 44),
			TextColor3 = Theme.cyan,
		}
	)
	self:_dashboard()
	self:_farm()
	self:_dungeon()
	self:_movement()
	self:_settings()
	self:_credits()
	self.cleanup:Add(config.Changed:Connect(function(values)
		self:_refreshPreferences(values)
	end))
	self.cleanup:Add(controller.Changed:Connect(function(status)
		self:_refreshStatus(status)
	end))
	self.cleanup:Add(logger.Message:Connect(function(entry)
		if entry.level == "ERROR" or entry.level == "WARN" then
			self.notifications:Show(entry.message .. ": " .. tostring(entry.context), entry.level == "ERROR")
		end
	end))
	self:_refreshPreferences(config:Get())
	self:_refreshStatus(controller:GetStatus())
	self:SelectTab("Dashboard")
	self:_interaction(header)
	return self
end

function MainWindow:_bind(key, control)
	table.insert(self.bindings, { key = key, control = control })
	return control
end

function MainWindow:_toggle(page, key, title, description, supported)
	return self:_bind(
		key,
		Components.toggle(page, title, description, function(value)
			local ok, err = self.config:Set(key, value)
			if not ok then
				self.notifications:Show(err, true)
			end
		end, self.cleanup, supported)
	)
end

function MainWindow:_slider(page, key, title, description, minimum, maximum, step, supported)
	return self:_bind(
		key,
		Components.slider(page, title, description, minimum, maximum, step, function(value)
			self.config:Set(key, value)
		end, self.cleanup, supported)
	)
end

function MainWindow:_dropdown(page, key, title, description, choices)
	return self:_bind(
		key,
		Components.dropdown(page, title, description, choices, function(value)
			self.config:Set(key, value)
		end, self.cleanup)
	)
end

function MainWindow:_progress(page)
	local card = Components.card(page, 94)
	Components.text(
		card,
		"DUNGEON PROGRESS",
		10,
		Theme.muted,
		{ Position = UDim2.fromOffset(16, 12), Size = UDim2.fromOffset(220, 18), Font = Theme.bold }
	)
	local areaLabel = Components.text(card, "AREA — / 5", 12, Theme.cyan, {
		Position = UDim2.new(1, -148, 0, 10),
		Size = UDim2.fromOffset(130, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Theme.bold,
	})
	local segments = {}
	for index = 1, 5 do
		local segment = Components.create("Frame", {
			Position = UDim2.new((index - 1) / 5, 16, 0, 44),
			Size = UDim2.new(0.2, -22, 0, 30),
			BackgroundColor3 = Theme.raised,
			BorderSizePixel = 0,
		}, card)
		Components.corner(segment, 6)
		local text = Components.text(
			segment,
			"0" .. index,
			11,
			Theme.muted,
			{ Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.bold }
		)
		table.insert(segments, { frame = segment, label = text })
	end
	self.progressViews = self.progressViews or {}
	table.insert(self.progressViews, { label = areaLabel, segments = segments })
end

function MainWindow:_dashboard()
	local page = self.pages.Dashboard
	local hero = Components.card(page, 92)
	Components.create(
		"UIGradient",
		{ Color = ColorSequence.new(Theme.surface, Color3.fromRGB(24, 34, 53)), Rotation = 15 },
		hero
	)
	Components.text(
		hero,
		"YOUR NEXT CLEAR STARTS HERE",
		10,
		Theme.cyan,
		{ Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -210, 0, 18), Font = Theme.bold }
	)
	self.heroState = Components.text(hero, "IDLE", 18, Theme.text, {
		Position = UDim2.fromOffset(18, 37),
		Size = UDim2.new(1, -210, 0, 25),
		Font = Theme.bold,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	self.startButton = Components.button(
		hero,
		"▶  START RUN",
		function()
			if self.controller.enabled then
				self.controller:Stop()
			else
				self.controller:Start()
			end
		end,
		self.cleanup,
		{
			Position = UDim2.new(1, -172, 0, 27),
			Size = UDim2.fromOffset(154, 38),
			BackgroundColor3 = Theme.cyan,
			TextColor3 = Theme.background,
		}
	)
	self:_progress(page)
	local grid = Components.card(page, 186)
	local fields = {
		{ "area", "CURRENT AREA" },
		{ "target", "CURRENT TARGET" },
		{ "state", "AUTOMATION STATE" },
		{ "npcsRemaining", "NPCS REMAINING" },
		{ "rubble", "RUBBLE STATUS" },
		{ "destination", "CURRENT DESTINATION" },
	}
	for index, field in fields do
		local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
		Components.text(grid, field[2], 9, Theme.muted, {
			Position = UDim2.new(column * 0.5, 16, 0, 12 + row * 58),
			Size = UDim2.new(0.5, -28, 0, 16),
			Font = Theme.bold,
		})
		self.statusLabels[field[1]] = Components.text(grid, "—", 13, Theme.text, {
			Position = UDim2.new(column * 0.5, 16, 0, 31 + row * 58),
			Size = UDim2.new(0.5, -28, 0, 22),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end
	local errorCard = Components.card(page, 66)
	Components.text(
		errorCard,
		"LAST ERROR",
		9,
		Theme.danger,
		{ Position = UDim2.fromOffset(16, 9), Size = UDim2.fromOffset(200, 16), Font = Theme.bold }
	)
	self.errorLabel = Components.text(errorCard, "None", 11, Theme.muted, {
		Position = UDim2.fromOffset(16, 28),
		Size = UDim2.new(1, -32, 0, 30),
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	self:_toggle(page, "autoFarm", "Auto Farm", "Farm living enemies in the active area")
	self:_toggle(
		page,
		"autoBreakRubble",
		"Auto Break Rubble",
		"Clear the barrier after the area is confirmed clear"
	)
	self:_toggle(page, "autoNextArea", "Auto Next Area", "Follow the verified entrance to the next area")
	self:_toggle(
		page,
		"autoRetry",
		"Auto Retry Dungeon",
		"Request a new run through the configured replay mechanism",
		self.adapter.capabilities.replay
	)
end

function MainWindow:_farm()
	local page = self.pages["Auto Farm"]
	self:_toggle(page, "autoFarm", "NPC farming", "Pause or resume enemy targeting and combat")
	self:_dropdown(
		page,
		"targetingMode",
		"Targeting mode",
		"Only living targets in this area and run",
		{ "Nearest", "LowestHealth" }
	)
	self:_slider(
		page,
		"maxTargetDistance",
		"Target distance",
		"Maximum acquisition distance in studs",
		10,
		500,
		5
	)
	self:_slider(
		page,
		"attackRange",
		"Attack range",
		"Adapter and server may enforce a smaller range",
		2,
		20,
		1
	)
	self:_slider(page, "followDistance", "Follow distance", "Clamped to the selected attack range", 1, 18, 1)
	self:_slider(
		page,
		"targetRefreshInterval",
		"Target refresh",
		"Seconds between target priority checks",
		0.1,
		3,
		0.1
	)
	self:_slider(
		page,
		"attackInterval",
		"Attack interval",
		"Seconds between supported combat requests",
		0.1,
		3,
		0.1
	)
	self:_slider(
		page,
		"combatProgressTimeout",
		"Combat progress timeout",
		"Recover when target health stops decreasing",
		5,
		120,
		1
	)
end

function MainWindow:_dungeon()
	local page = self.pages.Dungeon
	self:_progress(page)
	self:_toggle(page, "autoBreakRubble", "Auto Break Rubble", "Use the configured rubble interaction")
	self:_toggle(page, "autoNextArea", "Auto Next Area", "Move to the verified next-area entrance")
	self:_toggle(
		page,
		"waitForNPCSpawn",
		"Wait for NPC Spawn",
		"Enable timed recovery while waiting; off pauses until new state"
	)
	self:_toggle(
		page,
		"autoRetry",
		"Auto Retry",
		"One replay request per completed run",
		self.adapter.capabilities.replay
	)
	self:_slider(
		page,
		"spawnWaitTimeout",
		"Spawn / objective timeout",
		"Seconds before bounded recovery begins",
		5,
		120,
		1
	)
	self:_slider(
		page,
		"maxRecoveryAttempts",
		"Recovery attempts",
		"Stop with an error when this limit is exceeded",
		0,
		5,
		1
	)
	Components.button(page, "↻  RECOVER CURRENT AREA", function()
		self.controller:Recover()
	end, self.cleanup, { Size = UDim2.new(1, -2, 0, 42), TextColor3 = Theme.cyan })
end

function MainWindow:_movement()
	local page = self.pages.Movement
	self:_dropdown(
		page,
		"movementMode",
		"Movement mode",
		"One cancellable navigation task owns movement",
		{ "Pathfinding", "MoveTo" }
	)
	local supported = self.adapter.capabilities.movementSpeed
	self:_toggle(
		page,
		"applyMovementSpeed",
		"Apply movement speed",
		if supported
			then "Restore the previous WalkSpeed when movement stops"
			else "Unavailable with this adapter",
		supported
	)
	self:_slider(
		page,
		"movementSpeed",
		"Movement speed",
		if supported then "Studs per second, when enabled above" else "Requires explicit adapter support",
		8,
		32,
		1,
		supported
	)
	self:_toggle(page, "stuckDetection", "Stuck detection", "Recover if the character stops making progress")
	self:_slider(page, "stuckTimeout", "Stuck timeout", "Seconds without significant movement", 2, 20, 1)
	self:_slider(
		page,
		"movementTimeout",
		"Movement timeout",
		"Maximum seconds for one destination",
		5,
		120,
		1
	)
	Components.note(
		page,
		"Ground navigation uses Humanoid:MoveTo and PathfindingService. Height offsets are unavailable for this movement driver."
	)
end

function MainWindow:_settings()
	local page = self.pages.Settings
	Components.note(
		page,
		"Right Shift: show / hide  ·  End: emergency stop\nUse the floating M / A button to restore the window on touch devices."
	)
	self:_toggle(page, "notifications", "Notifications", "Show status messages; errors remain visible")
	self:_toggle(page, "debug", "Debug logging", "Include target acquisition details in Output")
	Components.button(page, "HIDE GUI", function()
		self:Hide()
	end, self.cleanup, { Size = UDim2.new(1, -2, 0, 40) })
	Components.button(page, "MINIMIZE", function()
		self:SetMinimized(true)
	end, self.cleanup, { Size = UDim2.new(1, -2, 0, 40) })
	Components.button(page, "SAVE PREFERENCES", function()
		local ok, accepted, message = pcall(function()
			return self.adapter:savePreferences(self.config:Export())
		end)
		self.notifications:Show(
			if not ok
				then tostring(accepted)
				else (
					message or (accepted and "Preferences saved" or "Preference persistence is unavailable")
				),
			not ok or not accepted
		)
	end, self.cleanup, { Size = UDim2.new(1, -2, 0, 40), TextColor3 = Theme.cyan })
	Components.button(page, "RESET CONFIGURATION", function()
		self.config:Reset()
		self.notifications:Show("Default preferences restored")
	end, self.cleanup, { Size = UDim2.new(1, -2, 0, 40) })
	Components.note(
		page,
		if self.adapter.capabilities.preferences
			then "Studio demo saves preferences for this server session. Cross-session storage requires a verified server persistence binding."
			else "Preferences apply for this GUI session. Saving reports unavailable until a persistence binding is configured."
	)
end

function MainWindow:_credits()
	local page = self.pages.Credits
	local card = Components.card(page, 188)
	Components.text(
		card,
		"M / A",
		42,
		Theme.cyan,
		{ Position = UDim2.fromOffset(22, 20), Size = UDim2.new(1, -44, 0, 54), Font = Theme.bold }
	)
	Components.text(
		card,
		"Mohammad and Ali Script",
		20,
		Theme.text,
		{ Position = UDim2.fromOffset(22, 84), Size = UDim2.new(1, -44, 0, 30), Font = Theme.bold }
	)
	Components.text(
		card,
		"Created for Mohammad and Ali\nVersion " .. Theme.version .. " · Independent Luau implementation",
		13,
		Theme.muted,
		{ Position = UDim2.fromOffset(22, 125), Size = UDim2.new(1, -44, 0, 42), TextWrapped = true }
	)
	Components.note(
		page,
		"Live Anime Zero compatibility has not been verified. The included five-area dungeon is a developer-owned Studio fixture. See docs/GAME_INTEGRATION.md before connecting game mechanics.",
		82
	)
end

function MainWindow:_refreshPreferences(values)
	for _, binding in self.bindings do
		binding.control:Set(values[binding.key])
	end
end

function MainWindow:_refreshStatus(status)
	self.heroState.Text = status.label
	self.startButton.Text = if status.enabled then "■  STOP RUN" else "▶  START RUN"
	self.footerStatus.Text = "●  " .. status.label .. "  ·  " .. status.reason
	self.footerStatus.TextColor3 = if status.state == "ERROR" then Theme.danger else Theme.cyan
	for key, label in self.statusLabels do
		label.Text = if key == "area"
			then (if status.area > 0 then status.area .. " / " .. status.totalAreas else "Awaiting state")
			elseif key == "state" then status.label
			else tostring(status[key])
	end
	self.errorLabel.Text = status.lastError
	for _, view in self.progressViews do
		view.label.Text = "AREA "
			.. (if status.area > 0 then status.area else "—")
			.. " / "
			.. status.totalAreas
		for index, segment in view.segments do
			local complete = index < status.area or status.state == "DUNGEON_COMPLETE"
			segment.frame.BackgroundColor3 = if complete
				then Theme.cyan
				elseif index == status.area then Theme.purple
				else Theme.raised
			segment.label.TextColor3 = if complete
				then Theme.background
				elseif index == status.area then Theme.text
				else Theme.muted
		end
	end
end

function MainWindow:SelectTab(name)
	for pageName, page in self.pages do
		page.Visible = pageName == name
	end
	for tabName, tab in self.tabs do
		tab.BackgroundColor3 = if tabName == name then Theme.raised else Theme.sidebar
		tab.TextColor3 = if tabName == name then Theme.cyan else Theme.muted
	end
	self.pageTitle.Text = name
end

function MainWindow:Hide()
	self.window.Visible, self.restore.Visible = false, true
end

function MainWindow:Show()
	self.minimized = false
	self.window.Visible, self.restore.Visible = true, false
end

function MainWindow:SetMinimized(value)
	self.minimized = value
	if value then
		self:Hide()
	else
		self:Show()
	end
end

function MainWindow:_interaction(header)
	local cameraConnection
	local function resize()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local compact = camera.ViewportSize.X < 700
		local width, height = if compact then 580 else 960, if compact then 740 else 650
		self.window.Size = UDim2.fromOffset(width, height)
		self.sidebar.Visible = not compact
		self.navigation.Parent = if compact then self.window else self.sidebar
		self.navigation.Position = UDim2.fromOffset(if compact then 18 else 12, if compact then 88 else 120)
		self.navigation.Size = if compact then UDim2.new(1, -36, 0, 40) else UDim2.new(1, -24, 0, 320)
		self.navLayout.FillDirection = if compact
			then Enum.FillDirection.Horizontal
			else Enum.FillDirection.Vertical
		self.navLayout.Padding = UDim.new(0, if compact then 4 else 8)
		for _, entry in self.navEntries do
			local button = self.tabs[entry[1]]
			button.Size = if compact then UDim2.fromOffset(87, 38) else UDim2.new(1, 0, 0, 42)
			button.Text = if compact then entry[1] else entry[2] .. "   " .. entry[1]
			button.TextSize = if compact then 11 else 13
			button.TextXAlignment = if compact then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
			button:FindFirstChildOfClass("UIPadding").PaddingLeft = UDim.new(0, if compact then 0 else 14)
		end
		local left, trim = if compact then 18 else 210, if compact then 36 else 234
		self.header.Position, self.header.Size = UDim2.fromOffset(left, 18), UDim2.new(1, -trim, 0, 62)
		self.brandTitle.TextSize = if compact then 22 else 24
		self.brandTitle.Size = UDim2.new(1, -100, 0, 32)
		self.pageTitle.Position = UDim2.fromOffset(left + 2, if compact then 146 else 96)
		self.modeLabel.Position = UDim2.new(1, -300, 0, if compact then 150 else 100)
		self.content.Position, self.content.Size =
			UDim2.fromOffset(left, if compact then 186 else 138),
			UDim2.new(1, -trim, 1, if compact then -258 else -210)
		self.footer.Position, self.footer.Size = UDim2.new(0, left, 1, -56), UDim2.new(1, -trim, 0, 40)
		self.scale.Scale = math.max(
			0.1,
			math.min(1, (camera.ViewportSize.X - 24) / width, (camera.ViewportSize.Y - 60) / height)
		)
		self.window.Position = UDim2.fromScale(0.5, 0.5)
	end
	local function bindCamera()
		if cameraConnection then
			cameraConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		if camera then
			cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
		end
		resize()
	end
	self.cleanup:Add(function()
		if cameraConnection then
			cameraConnection:Disconnect()
		end
	end)
	self.cleanup:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
	bindCamera()
	local dragging, touch, origin, original
	self.cleanup:Add(header.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging, touch, origin, original =
				true,
				if input.UserInputType == Enum.UserInputType.Touch then input else nil,
				input.Position,
				self.window.Position
		end
	end))
	self.cleanup:Add(UserInputService.InputChanged:Connect(function(input)
		if
			not dragging
			or not (
				(touch and input == touch)
				or (not touch and input.UserInputType == Enum.UserInputType.MouseMovement)
			)
		then
			return
		end
		local delta = input.Position - origin
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local size = self.window.AbsoluteSize
		local x = camera.ViewportSize.X * original.X.Scale + original.X.Offset + delta.X
		local y = camera.ViewportSize.Y * original.Y.Scale + original.Y.Offset + delta.Y
		self.window.Position = UDim2.fromOffset(
			math.clamp(x, size.X / 2, camera.ViewportSize.X - size.X / 2),
			math.clamp(y, size.Y / 2, camera.ViewportSize.Y - size.Y / 2)
		)
	end))
	self.cleanup:Add(UserInputService.InputEnded:Connect(function(input)
		if input == touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging, touch = false, nil
		end
	end))
	self.cleanup:Add(UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.RightShift then
			if self.window.Visible then
				self:Hide()
			else
				self:Show()
			end
		elseif input.KeyCode == Enum.KeyCode.End then
			self.controller:Stop("Emergency stop shortcut")
		end
	end))
end

function MainWindow:Destroy()
	if self.destroyed then
		return
	end
	self.destroyed = true
	self.cleanup:Destroy()
	if self.screen then
		self.screen:Destroy()
	end
end

return MainWindow
