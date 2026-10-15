local Geometry = require(if script then script.Parent.Parent.Utils.Geometry else "../Utils/Geometry")
local MovementController = {}
MovementController.__index = MovementController

function MovementController.new(driver)
	return setmetatable({ driver = driver, active = nil, destroyed = false }, MovementController)
end

function MovementController:Cancel()
	if self.active then
		self.active = nil
		self.driver:cancel()
	end
end

-- One tick, never yields. The driver owns at most one cancellable navigation job.
function MovementController:Move(target, position, now, config, radius)
	assert(not self.destroyed, "Movement controller destroyed")
	if not Geometry.valid(target.position) or not Geometry.valid(position) then
		self:Cancel()
		return "error", "Invalid destination or character position"
	end
	if Geometry.distance(position, target.position) <= radius then
		self:Cancel()
		return "arrived"
	end
	local active = self.active
	if not active or active.id ~= target.id then
		self:Cancel()
		active = { id = target.id, started = now, progressed = now, anchor = position, sent = -math.huge }
		self.active = active
	end
	if now - active.started >= config.movementTimeout then
		self:Cancel()
		return "error", "Movement timeout: " .. target.id
	end
	if Geometry.distance(position, active.anchor) >= 0.75 then
		active.anchor, active.progressed = position, now
	elseif config.stuckDetection and now - active.progressed >= config.stuckTimeout then
		self:Cancel()
		return "error", "Character stuck: " .. target.id
	end
	local driverError = self.driver:getError()
	if driverError then
		self:Cancel()
		return "error", driverError
	end
	local settings = config.movementMode
		.. tostring(config.applyMovementSpeed)
		.. tostring(config.movementSpeed)
	if
		not active.destination
		or Geometry.distance(active.destination, target.position) > 2
		or now - active.sent >= 4
		or active.settings ~= settings
	then
		active.destination, active.sent, active.settings = target.position, now, settings
		-- Navigate to attack range rather than inside a solid rubble model.
		local dx, dz = position.x - target.position.x, position.z - target.position.z
		local horizontal = math.sqrt(dx * dx + dz * dz)
		local dy = position.y - target.position.y
		local standOff = math.sqrt(math.max(0, radius * radius - dy * dy)) * 0.9
		local destination = { x = target.position.x, y = position.y, z = target.position.z }
		if horizontal > 0 then
			destination.x += dx / horizontal * standOff
			destination.z += dz / horizontal * standOff
		end
		self.driver:moveTo(destination, config)
	end
	return "moving"
end

function MovementController:Destroy()
	if self.destroyed then
		return
	end
	self:Cancel()
	self.destroyed = true
	self.driver:destroy()
end

return MovementController
