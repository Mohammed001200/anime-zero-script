local Signal = require(if script then script.Parent.Parent.Utils.Signal else "../Utils/Signal")
local Geometry = require(if script then script.Parent.Parent.Utils.Geometry else "../Utils/Geometry")
local Configuration = {}
Configuration.__index = Configuration
Configuration.VERSION = 1
Configuration.defaults = table.freeze({
	autoFarm = true,
	killAura = false,
	autoBreakRubble = true,
	autoNextArea = true,
	autoRetry = false,
	waitForNPCSpawn = true,
	targetingMode = "Nearest",
	maxTargetDistance = 180,
	attackRange = 8,
	followDistance = 5,
	targetRefreshInterval = 0.5,
	attackInterval = 0.6,
	combatProgressTimeout = 15,
	movementMode = "Pathfinding",
	applyMovementSpeed = false,
	movementSpeed = 16,
	stuckDetection = true,
	stuckTimeout = 5,
	movementTimeout = 35,
	spawnWaitTimeout = 30,
	maxRecoveryAttempts = 3,
	notifications = true,
	debug = false,
})
local ranges = {
	maxTargetDistance = { 10, 500 },
	attackRange = { 2, 20 },
	followDistance = { 1, 18 },
	targetRefreshInterval = { 0.1, 3 },
	attackInterval = { 0.1, 3 },
	combatProgressTimeout = { 5, 120 },
	movementSpeed = { 8, 32 },
	stuckTimeout = { 2, 20 },
	movementTimeout = { 5, 120 },
	spawnWaitTimeout = { 5, 120 },
	maxRecoveryAttempts = { 0, 5 },
}
local options = {
	targetingMode = { Nearest = true, LowestHealth = true },
	movementMode = { Pathfinding = true, MoveTo = true },
}

function Configuration.new(saved)
	local self =
		setmetatable({ values = table.clone(Configuration.defaults), Changed = Signal.new() }, Configuration)
	if saved then
		self:Load(saved)
	end
	return self
end

function Configuration:Set(key, value)
	local default = Configuration.defaults[key]
	if default == nil or type(value) ~= type(default) then
		return false, "Invalid preference: " .. tostring(key)
	end
	if ranges[key] then
		if not Geometry.finite(value) then
			return false, "Value must be finite"
		end
		value = math.clamp(value, ranges[key][1], ranges[key][2])
	elseif options[key] and not options[key][value] then
		return false, "Unsupported option: " .. tostring(value)
	end
	self.values[key] = value
	self.values.followDistance = math.min(self.values.followDistance, self.values.attackRange)
	self.Changed:Fire(self:Get())
	return true
end

function Configuration:Get()
	return table.clone(self.values)
end

function Configuration:Load(saved)
	if type(saved) ~= "table" or saved.version ~= Configuration.VERSION or type(saved.values) ~= "table" then
		return false, "Unsupported preference format"
	end
	-- Apply range first so table iteration order cannot change followDistance.
	self:Set("attackRange", saved.values.attackRange or self.values.attackRange)
	for key, value in saved.values do
		if key ~= "attackRange" and key ~= "followDistance" then
			self:Set(key, value)
		end
	end
	self:Set("followDistance", saved.values.followDistance or self.values.followDistance)
	return true
end

function Configuration:Export()
	return { version = Configuration.VERSION, values = self:Get() }
end

function Configuration:Reset()
	self.values = table.clone(Configuration.defaults)
	self.Changed:Fire(self:Get())
end

function Configuration:Destroy()
	self.Changed:Destroy()
end

return Configuration
