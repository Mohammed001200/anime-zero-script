-- Headless startup fixture, not a Roblox emulator or rendered-GUI test.
-- Uses real Lune Roblox value types, but mocks instances, services and signals.
local Roblox = require("@lune/roblox")
local Signal = require("../src/Utils/Signal")
local MockClient = {}

function MockClient.new()
	local host = { warnings = {}, delayed = {}, tweenCalls = 0 }
	local methods, meta = {}, {}
	function meta:__index(key)
		if methods[key] then
			return methods[key]
		end
		return self.props[key]
	end
	function meta:__newindex(key, value)
		if key == "Parent" then
			local parent = self.props.Parent
			if parent then
				local index = table.find(parent.children, self)
				if index then
					table.remove(parent.children, index)
				end
			end
			if value then
				table.insert(value.children, self)
			end
		end
		local previous = self.props[key]
		self.props[key] = value
		if value ~= previous and self.changed[key] then
			self.changed[key]:Fire()
		end
	end
	local function instance(class)
		local self = setmetatable({
			props = {
				ClassName = class,
				Name = class,
				Visible = true,
				BackgroundTransparency = 0,
				AbsolutePosition = Roblox.Vector2.zero,
				AbsoluteSize = Roblox.Vector2.new(960, 650),
				Position = Roblox.UDim2.new(),
				Size = Roblox.UDim2.new(),
			},
			children = {},
			attributes = {},
			changed = {},
			destroyed = false,
		}, meta)
		for _, event in
			{
				"Destroying",
				"Activated",
				"MouseEnter",
				"MouseLeave",
				"InputBegan",
				"InputChanged",
				"InputEnded",
				"SelectionGained",
				"Event",
				"Heartbeat",
			}
		do
			self[event] = Signal.new()
		end
		return self
	end
	function methods:IsA(class)
		return self.ClassName == class
			or class == "Instance"
			or (self.ClassName == "Part" and class == "BasePart")
			or (
				(
					self.ClassName == "NumberValue"
					or self.ClassName == "IntValue"
					or self.ClassName == "StringValue"
					or self.ClassName == "BoolValue"
				) and class == "ValueBase"
			)
	end
	function methods:GetChildren()
		return table.clone(self.children)
	end
	function methods:GetFullName()
		return if self.Parent then self.Parent:GetFullName() .. "." .. self.Name else self.Name
	end
	function methods:GetAttributes()
		return table.clone(self.attributes)
	end
	function methods:FindFirstChildWhichIsA(class)
		for _, child in self.children do
			if child:IsA(class) then
				return child
			end
		end
		return nil
	end
	function methods:FindFirstChild(name)
		for _, child in self.children do
			if child.Name == name then
				return child
			end
		end
		return nil
	end
	function methods:FindFirstChildOfClass(class)
		for _, child in self.children do
			if child.ClassName == class then
				return child
			end
		end
		return nil
	end
	function methods:WaitForChild(name, timeout)
		host.lastWaitTimeout = timeout
		return self:FindFirstChild(name)
	end
	function methods:SetAttribute(key, value)
		self.attributes[key] = value
	end
	function methods:GetAttribute(key)
		return self.attributes[key]
	end
	function methods:GetPropertyChangedSignal(key)
		if not self.changed[key] then
			self.changed[key] = Signal.new()
		end
		return self.changed[key]
	end
	function methods:Fire(...)
		self.Event:Fire(...)
	end
	function methods:Destroy()
		if self.destroyed then
			return
		end
		rawset(self, "destroyed", true)
		self.Destroying:Fire()
		for _, child in self:GetChildren() do
			child:Destroy()
		end
		self.Parent = nil
		for _, value in self.props do
			if type(value) == "table" and getmetatable(value) == Signal then
				value:Destroy()
			end
		end
		for _, value in self.changed do
			value:Destroy()
		end
	end
	local services = {}
	for _, name in
		{
			"RunService",
			"Players",
			"ReplicatedStorage",
			"PathfindingService",
			"HttpService",
			"TweenService",
			"UserInputService",
			"Workspace",
			"CollectionService",
		}
	do
		services[name] = instance(name)
	end
	function services.RunService:IsClient()
		return not host.server
	end
	function services.RunService:IsStudio()
		return host.studio == true
	end
	local player = instance("Player")
	local playerGui = instance("PlayerGui")
	playerGui.Parent = player
	services.Players.LocalPlayer = player
	function services.Players:GetPlayers()
		return host.players or { self.LocalPlayer }
	end
	function services.CollectionService:GetTags(object)
		return object.MockTags or {}
	end
	local camera = instance("Camera")
	camera.ViewportSize = Roblox.Vector2.new(1280, 800)
	services.Workspace.CurrentCamera = camera
	function services.TweenService:Create(target, _info, properties)
		host.tweenCalls += 1
		if host.onTween then
			host.onTween()
		end
		if host.failTween then
			error("Injected GUI construction failure")
		end
		return {
			Play = function()
				for key, value in properties do
					target[key] = value
				end
			end,
		}
	end
	local fakeGame = { PlaceId = 12345, GameId = 67890 }
	function fakeGame:GetService(name)
		assert(services[name], "Mock service missing: " .. name)
		return services[name]
	end
	local environment = {
		game = fakeGame,
		workspace = services.Workspace,
		Instance = { new = instance },
		Enum = Roblox.Enum,
		Color3 = Roblox.Color3,
		ColorSequence = Roblox.ColorSequence,
		UDim = Roblox.UDim,
		UDim2 = Roblox.UDim2,
		Vector2 = Roblox.Vector2,
		Vector3 = Roblox.Vector3,
		TweenInfo = {
			new = function()
				return {}
			end,
		},
		task = {
			spawn = function(callback)
				callback()
			end,
			wait = function() end,
			delay = function(_, callback)
				table.insert(host.delayed, callback)
			end,
		},
		warn = function(message)
			table.insert(host.warnings, tostring(message))
		end,
		print = function() end,
		-- No filesystem, native require, HTTP, script instance, or loadstring.
		require = false,
		script = false,
		loadstring = false,
	}
	host.environment, host.services, host.playerGui = environment, services, playerGui
	function host:connections(signal)
		local count = 0
		for connection in signal.listeners do
			if connection.Connected then
				count += 1
			end
		end
		return count
	end
	return host
end

return MockClient
