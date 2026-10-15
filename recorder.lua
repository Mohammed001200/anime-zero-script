-- Mohammad & Ali - Anime Zero read-only observation recorder
-- Records local input and replicated state only. It never fires remotes,
-- activates tools/prompts, changes health, or moves the character.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
assert(localPlayer, "Anime Zero recorder must run on the client")

local Recorder = {}
Recorder.__index = Recorder

local POLL_INTERVAL = 0.20
local NEARBY_RADIUS = 160
local MAX_INITIAL_OBJECTS = 15000
local MAX_REPORT_LINES = 12000
local PROGRESS_WORDS = {
	area = true,
	currentarea = true,
	dungeonarea = true,
	stage = true,
	wave = true,
	progress = true,
	room = true,
	zone = true,
	completed = true,
	dungeoncomplete = true,
}

local function clock()
	return os.clock()
end

local function timestamp()
	local ok, result = pcall(os.date, "!%Y-%m-%dT%H:%M:%SZ")
	return ok and result or tostring(DateTime.now().UnixTimestampMillis)
end

local function clean(value)
	local text = tostring(value):gsub("[%c]", " ")
	return #text > 180 and text:sub(1, 177) .. "..." or text
end

local function pathOf(instance)
	local ok, result = pcall(instance.GetFullName, instance)
	return ok and result or clean(instance)
end

local function positionOf(model)
	local root = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function formatPosition(position)
	if not position then
		return "unavailable"
	end
	return string.format("(%.2f, %.2f, %.2f)", position.X, position.Y, position.Z)
end

local function playerPosition()
	return positionOf(localPlayer.Character)
end

local function isOtherPlayerCharacter(model)
	return model and Players:GetPlayerFromCharacter(model) ~= nil
end

local function simpleValue(value)
	local valueType = typeof(value)
	if valueType == "string" or valueType == "number" or valueType == "boolean" then
		return clean(value)
	end
	return nil
end

local function isProgressName(name)
	local normalized = string.lower(name):gsub("[^%w]", "")
	return PROGRESS_WORDS[normalized] == true
end

local function borderNumber(instance)
	local current = instance
	while current and current ~= Workspace do
		local number = current.Name:match("^[Bb]order(%d+)$")
		if number then
			return number, current
		end
		current = current.Parent
	end
	return nil, nil
end

function Recorder.new()
	return setmetatable({
		running = false,
		startedAt = 0,
		startedTimestamp = nil,
		lines = {},
		connections = {},
		humanoids = {},
		observedNpcHealth = {},
		rubbleSources = {},
		observedRubble = {},
		progressSources = {},
		textSources = {},
		observedProgress = {},
		mouseDownAt = nil,
		lastAttackSample = 0,
		generation = 0,
	}, Recorder)
end

function Recorder:_write(kind, message)
	if #self.lines >= MAX_REPORT_LINES then
		if #self.lines == MAX_REPORT_LINES then
			table.insert(self.lines, "[LIMIT] Report line limit reached; later events were omitted.")
		end
		return
	end
	local elapsed = self.startedAt > 0 and clock() - self.startedAt or 0
	table.insert(self.lines, string.format("[+%07.3fs] %-14s %s", elapsed, kind, message))
end

function Recorder:_register(instance)
	if instance:IsA("TextLabel") or instance:IsA("TextButton") then
		self.textSources[instance] = true
	end
	local ownBorderNumber = instance.Name:match("^[Bb]order(%d+)$")
	if ownBorderNumber then
		self.rubbleSources[instance] = {
			attribute = "RubbleHealth",
			label = "Border" .. ownBorderNumber,
			path = pathOf(instance),
		}
	end

	if instance:IsA("Humanoid") and instance.Parent and instance.Parent:IsA("Model") then
		self.humanoids[instance] = true
	end

	if instance:IsA("ValueBase") then
		if string.lower(instance.Name) == "rubblehealth" then
			local number, border = borderNumber(instance)
			self.rubbleSources[instance] = {
				label = number and ("Border" .. number) or "unscoped rubble",
				path = pathOf(border or instance),
			}
		end
		if isProgressName(instance.Name) then
			self.progressSources[instance] = {
				kind = "value",
				path = pathOf(instance),
			}
		end
	end

	local ok, attributes = pcall(instance.GetAttributes, instance)
	if ok then
		for attributeName in pairs(attributes) do
			local lower = string.lower(attributeName)
			if lower == "rubblehealth" then
				local number, border = borderNumber(instance)
				self.rubbleSources[instance] = {
					attribute = attributeName,
					label = number and ("Border" .. number) or "unscoped rubble",
					path = pathOf(border or instance),
				}
			elseif isProgressName(attributeName) then
				self.progressSources[instance] = self.progressSources[instance] or {}
				self.progressSources[instance][attributeName] = true
			end
		end
	end
end

function Recorder:_unregister(instance)
	self.humanoids[instance] = nil
	self.observedNpcHealth[instance] = nil
	self.rubbleSources[instance] = nil
	self.observedRubble[instance] = nil
	self.progressSources[instance] = nil
	self.textSources[instance] = nil
	self.observedProgress[instance] = nil
end

function Recorder:_scanNearby(reason)
	local origin = playerPosition()
	local entries = {}
	if not origin then
		self:_write("NPC_SNAPSHOT", reason .. ": player position unavailable")
		return
	end

	for humanoid in pairs(self.humanoids) do
		local model = humanoid.Parent
		if humanoid.Parent and model and model:IsA("Model") and not isOtherPlayerCharacter(model) then
			local position = positionOf(model)
			if position then
				local distance = (position - origin).Magnitude
				if distance <= NEARBY_RADIUS then
					table.insert(entries, {
						distance = distance,
						text = string.format(
							"%s | health=%.2f/%.2f | position=%s | distance=%.1f | path=%s",
							clean(model.Name),
							humanoid.Health,
							humanoid.MaxHealth,
							formatPosition(position),
							distance,
							pathOf(model)
						),
					})
				end
			end
		end
	end

	table.sort(entries, function(a, b)
		return a.distance < b.distance
	end)
	if #entries == 0 then
		self:_write("NPC_SNAPSHOT", reason .. ": none within " .. NEARBY_RADIUS .. " studs")
	else
		for index = 1, math.min(#entries, 20) do
			self:_write("NPC_SNAPSHOT", reason .. ": " .. entries[index].text)
		end
	end
end

function Recorder:_pollNpcs()
	local origin = playerPosition()
	if not origin then
		return
	end
	for humanoid in pairs(self.humanoids) do
		local model = humanoid.Parent
		if model and model:IsA("Model") and humanoid.Parent and not isOtherPlayerCharacter(model) then
			local position = positionOf(model)
			if position and (position - origin).Magnitude <= NEARBY_RADIUS then
				local health = humanoid.Health
				local previous = self.observedNpcHealth[humanoid]
				if previous == nil then
					self:_write(
						"NPC_SEEN",
						string.format(
							"%s | health=%.2f/%.2f | position=%s | path=%s",
							clean(model.Name),
							health,
							humanoid.MaxHealth,
							formatPosition(position),
							pathOf(model)
						)
					)
				elseif previous ~= health then
					self:_write(
						"NPC_HEALTH",
						string.format(
							"%s | %.2f -> %.2f | position=%s | path=%s",
							clean(model.Name),
							previous,
							health,
							formatPosition(position),
							pathOf(model)
						)
					)
				end
				self.observedNpcHealth[humanoid] = health
			end
		end
	end
end

function Recorder:_pollRubble()
	for instance, source in pairs(self.rubbleSources) do
		if instance.Parent then
			local value
			if source.attribute then
				value = simpleValue(instance:GetAttribute(source.attribute))
			elseif instance:IsA("ValueBase") then
				value = simpleValue(instance.Value)
			end
			if value ~= nil then
				local previous = self.observedRubble[instance]
				if previous == nil then
					self:_write(
						"RUBBLE_SEEN",
						source.label .. " | health=" .. value .. " | path=" .. source.path
					)
				elseif previous ~= value then
					self:_write(
						"RUBBLE_HEALTH",
						source.label .. " | " .. previous .. " -> " .. value .. " | path=" .. source.path
					)
				end
				self.observedRubble[instance] = value
			end
		end
	end
end

function Recorder:_pollProgress()
	for instance in pairs(self.textSources) do
		if instance.Parent then
			local text = clean(instance.Text)
			local lower = string.lower(text)
			if
				isProgressName(instance.Name)
				or lower:match("%f[%a]area%f[%A]")
				or lower:match("%f[%a]wave%f[%A]")
				or lower:match("%f[%a]stage%f[%A]")
				or lower:match("dungeon.*complet")
				or lower:match("victory")
			then
				local key = pathOf(instance) .. "::Text"
				local value = text .. " | visible=" .. tostring(instance.Visible)
				local previous = self.observedProgress[key]
				if previous ~= value then
					self:_write("PROGRESS_UI", key .. " | " .. (previous or "unobserved") .. " -> " .. value)
					self.observedProgress[key] = value
				end
			end
		end
	end
	for instance, source in pairs(self.progressSources) do
		if instance.Parent then
			local values = {}
			if source.kind == "value" and instance:IsA("ValueBase") then
				values.Value = simpleValue(instance.Value)
			else
				for attributeName in pairs(source) do
					values[attributeName] = simpleValue(instance:GetAttribute(attributeName))
				end
			end
			for name, value in pairs(values) do
				if value ~= nil then
					local key = pathOf(instance) .. "::" .. name
					local previous = self.observedProgress[key]
					if previous == nil then
						self:_write("PROGRESS_SEEN", key .. "=" .. value)
					elseif previous ~= value then
						self:_write("PROGRESS", key .. " | " .. previous .. " -> " .. value)
					end
					self.observedProgress[key] = value
				end
			end
		end
	end
end

function Recorder:_mouseDown(processed)
	if self.mouseDownAt then
		return
	end
	self.mouseDownAt = clock()
	self.lastAttackSample = 0
	self:_write(
		"MOUSE_DOWN",
		"processed=" .. tostring(processed) .. " | player=" .. formatPosition(playerPosition())
	)
	self:_scanNearby("mouse down")
end

function Recorder:_mouseUp(reason)
	if not self.mouseDownAt then
		return
	end
	local duration = clock() - self.mouseDownAt
	self:_write(
		"MOUSE_UP",
		string.format(
			"duration=%.3fs | player=%s | reason=%s",
			duration,
			formatPosition(playerPosition()),
			reason
		)
	)
	self:_scanNearby("mouse up")
	self.mouseDownAt = nil
end

function Recorder:Start()
	if self.running then
		warn("[M&A Recorder] Already recording.")
		return false
	end

	self.running = true
	self.generation += 1
	self.startedAt = clock()
	self.startedTimestamp = timestamp()
	table.clear(self.lines)
	table.clear(self.humanoids)
	table.clear(self.rubbleSources)
	table.clear(self.progressSources)
	table.clear(self.textSources)
	table.clear(self.observedNpcHealth)
	table.clear(self.observedRubble)
	table.clear(self.observedProgress)
	self:_write(
		"START",
		"timestamp="
			.. self.startedTimestamp
			.. " | placeId="
			.. tostring(game.PlaceId)
			.. " | radius="
			.. NEARBY_RADIUS
	)
	self:_write(
		"NOTICE",
		"Read-only sampling; each left click is only an attack marker, and replicated values are observations rather than verified game APIs."
	)

	self:_register(Workspace)
	local descendants = Workspace:GetDescendants()
	for index = 1, math.min(#descendants, MAX_INITIAL_OBJECTS) do
		self:_register(descendants[index])
	end
	if #descendants > MAX_INITIAL_OBJECTS then
		self:_write("LIMIT", "Initial workspace scan capped at " .. MAX_INITIAL_OBJECTS .. " objects")
	end
	self:_register(localPlayer)
	for _, instance in ipairs(localPlayer:GetDescendants()) do
		self:_register(instance)
	end

	table.insert(
		self.connections,
		Workspace.DescendantAdded:Connect(function(instance)
			self:_register(instance)
		end)
	)
	table.insert(
		self.connections,
		Workspace.DescendantRemoving:Connect(function(instance)
			self:_unregister(instance)
		end)
	)
	table.insert(
		self.connections,
		localPlayer.DescendantAdded:Connect(function(instance)
			self:_register(instance)
		end)
	)
	table.insert(
		self.connections,
		localPlayer.DescendantRemoving:Connect(function(instance)
			self:_unregister(instance)
		end)
	)
	table.insert(
		self.connections,
		UserInputService.InputBegan:Connect(function(input, processed)
			if self.running and input.UserInputType == Enum.UserInputType.MouseButton1 then
				self:_mouseDown(processed)
			end
		end)
	)
	table.insert(
		self.connections,
		UserInputService.InputEnded:Connect(function(input)
			if self.running and input.UserInputType == Enum.UserInputType.MouseButton1 then
				self:_mouseUp("released")
			end
		end)
	)

	local generation = self.generation
	task.spawn(function()
		while self.running and generation == self.generation do
			self:_pollNpcs()
			self:_pollRubble()
			self:_pollProgress()
			if self.mouseDownAt and clock() - self.lastAttackSample >= POLL_INTERVAL then
				self.lastAttackSample = clock()
				self:_write("ATTACK_POSITION", "player=" .. formatPosition(playerPosition()))
			end
			task.wait(POLL_INTERVAL)
		end
	end)

	print("[M&A Recorder] Recording started. Run getgenv().MohammadAliRecorder:Stop() when finished.")
	return true
end

function Recorder:_copy(report)
	local environment = _G
	local ok, customEnvironment = pcall(function()
		return getgenv()
	end)
	if ok and type(customEnvironment) == "table" then
		environment = customEnvironment
	end
	local copy = rawget(environment, "setclipboard") or rawget(environment, "toclipboard")
	if type(copy) == "function" then
		local copied, message = pcall(copy, report)
		return copied, copied and nil or clean(message)
	end
	return false, "clipboard function unavailable"
end

function Recorder:Stop()
	if not self.running then
		warn("[M&A Recorder] Recorder is not running.")
		return self.lastReport
	end

	self:_pollNpcs()
	self:_pollRubble()
	self:_pollProgress()
	self:_mouseUp("recording stopped while held")
	self:_write("STOP", "timestamp=" .. timestamp())
	self.running = false
	self.generation += 1
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	table.clear(self.connections)

	local report = table.concat({
		"MOHAMMAD & ALI - ANIME ZERO READ-ONLY RECORDING",
		"Started: " .. tostring(self.startedTimestamp),
		"Generated: " .. timestamp(),
		"Player: " .. clean(localPlayer.Name),
		"PlaceId: " .. tostring(game.PlaceId) .. " | GameId: " .. tostring(game.GameId),
		"",
		table.concat(self.lines, "\n"),
	}, "\n")
	self.lastReport = report

	local copied, copyError = self:_copy(report)
	print(report)
	if copied then
		print("[M&A Recorder] Stopped. Timestamped report copied to clipboard.")
	else
		warn("[M&A Recorder] Stopped. Report printed to console; " .. copyError .. ".")
	end
	return report
end

local environment = _G
local ok, customEnvironment = pcall(function()
	return getgenv()
end)
if ok and type(customEnvironment) == "table" then
	environment = customEnvironment
end

local previous = rawget(environment, "MohammadAliRecorder")
if type(previous) == "table" and type(previous.Stop) == "function" then
	pcall(function()
		previous:Stop()
	end)
end

local recorder = Recorder.new()
environment.MohammadAliRecorder = recorder
recorder:Start()
return recorder
