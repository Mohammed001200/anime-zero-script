local PathfindingService = game:GetService("PathfindingService")
local Driver = {}
Driver.__index = Driver

function Driver.new(player, speedSupported)
	return setmetatable(
		{ player = player, speedSupported = speedSupported, generation = 0, connections = {} },
		Driver
	)
end

function Driver:_disconnect()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
end

function Driver:_character()
	local character = self.player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
	return nil
end

function Driver:cancel()
	self.generation += 1
	self:_disconnect()
	if self.speedHumanoid and self.speedHumanoid.Parent then
		self.speedHumanoid.WalkSpeed = self.originalSpeed
	end
	self.speedHumanoid = nil
	local humanoid, root = self:_character()
	if humanoid then
		humanoid:MoveTo(root.Position)
	end
	self.error = nil
end

function Driver:getError()
	return self.error
end

function Driver:moveTo(point, config)
	self:cancel()
	local generation = self.generation
	local humanoid, root = self:_character()
	if not humanoid then
		self.error = "Character unavailable"
		return
	end
	if config.applyMovementSpeed and self.speedSupported then
		self.speedHumanoid, self.originalSpeed = humanoid, humanoid.WalkSpeed
		humanoid.WalkSpeed = config.movementSpeed
	end
	local destination = Vector3.new(point.x, point.y, point.z)
	if config.movementMode == "MoveTo" then
		humanoid:MoveTo(destination)
		return
	end
	-- ComputeAsync may yield. Every continuation checks the generation token.
	task.spawn(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
		local ok, err = pcall(function()
			path:ComputeAsync(root.Position, destination)
		end)
		if generation ~= self.generation then
			path:Destroy()
			return
		end
		if not ok or path.Status ~= Enum.PathStatus.Success then
			self.error = "No navigation path: " .. tostring(err or path.Status)
			path:Destroy()
			return
		end
		local waypoints, index = path:GetWaypoints(), 2
		local function advance()
			if generation ~= self.generation or not humanoid.Parent then
				return
			end
			local waypoint = waypoints[index]
			if not waypoint then
				return
			end
			if waypoint.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
			humanoid:MoveTo(waypoint.Position)
		end
		table.insert(
			self.connections,
			path.Blocked:Connect(function(blockedIndex)
				if generation == self.generation and blockedIndex >= index then
					self.error = "Navigation path blocked; replan required"
				end
			end)
		)
		table.insert(
			self.connections,
			humanoid.MoveToFinished:Connect(function(reached)
				if generation ~= self.generation then
					return
				end
				if not reached then
					self.error = "Navigation interrupted"
					return
				end
				index += 1
				advance()
			end)
		)
		-- Disconnect destroys the path when this job is superseded.
		table.insert(self.connections, {
			Disconnect = function()
				path:Destroy()
			end,
		})
		if #waypoints < 2 then
			humanoid:MoveTo(destination)
		else
			advance()
		end
	end)
end

function Driver:destroy()
	self:cancel()
end

return Driver
