local StateMachine = require(if script then script.Parent.StateMachine else "./StateMachine")
local Signal = require(if script then script.Parent.Parent.Utils.Signal else "../Utils/Signal")
local AreaDetector =
	require(if script then script.Parent.Parent.Game.AreaDetector else "../Game/AreaDetector")
local NPCDetector = require(if script then script.Parent.Parent.Game.NPCDetector else "../Game/NPCDetector")
local DungeonController =
	require(if script then script.Parent.Parent.Dungeon.DungeonController else "../Dungeon/DungeonController")
local CombatController =
	require(if script then script.Parent.Parent.Game.CombatController else "../Game/CombatController")
local AutomationController = {}
AutomationController.__index = AutomationController

function AutomationController.new(adapter, movement, config, logger)
	local self = setmetatable({
		adapter = adapter,
		movement = movement,
		config = config,
		logger = logger,
		combat = CombatController.new(adapter),
		machine = StateMachine.new(),
		Changed = Signal.new(),
		enabled = false,
		destroyed = false,
		attempts = 0,
		lastRefresh = -math.huge,
		status = {
			area = 0,
			totalAreas = 5,
			target = "None",
			npcsRemaining = 0,
			rubble = "Unknown",
			destination = "None",
			lastError = "None",
		},
	}, AutomationController)
	self.configConnection = config.Changed:Connect(function()
		self:_cancel()
		self.targetId, self.waitKey = nil, nil
	end)
	self.stateConnection = self.machine.Changed:Connect(function(state, previous, reason)
		if state ~= previous then
			self.logger:Log("INFO", StateMachine.labels[state], reason)
		end
	end)
	return self
end

function AutomationController:_cancel()
	-- A failing integration cleanup must not prevent the other owner stopping.
	for _, cancel in
		{
			function()
				self.movement:Cancel()
			end,
			function()
				self.combat:Cancel()
			end,
		}
	do
		local ok, err = pcall(cancel)
		if not ok then
			self.logger:Log("WARN", "Action cleanup failed", err)
		end
	end
	self.status.target, self.status.destination = "None", "None"
end

function AutomationController:GetStatus()
	local result = table.clone(self.status)
	result.enabled, result.state = self.enabled, self.machine.state
	result.label, result.reason = StateMachine.labels[self.machine.state], self.machine.reason
	return result
end

function AutomationController:_publish()
	self.Changed:Fire(self:GetStatus())
end

function AutomationController:Start()
	if self.destroyed then
		return false, "Controller destroyed"
	end
	if self.enabled then
		return true
	end
	self.enabled, self.attempts = true, 0
	self.waitKey, self.completedRun, self.scope, self.retryAt, self.targetId = nil, nil, nil, nil, nil
	self.status.lastError = "None"
	self.machine:Set("FIND_NPCS", "Automation started")
	self:_publish()
	return true
end

function AutomationController:Stop(reason)
	self.enabled = false
	self:_cancel()
	self.machine:Set("IDLE", reason or "Stopped")
	self:_publish()
end

function AutomationController:Recover()
	if self.destroyed then
		return
	end
	self:Stop("Manual recovery")
	self:Start()
	self.machine:Set("RECOVERING", "Rechecking the current area")
	self:_publish()
end

function AutomationController:_fail(message)
	self.enabled = false
	self:_cancel()
	self.status.lastError = tostring(message)
	self.logger:Log("ERROR", "Automation stopped", message)
	self.machine:Set("ERROR", tostring(message))
end

function AutomationController:_recover(message, now)
	self:_cancel()
	self.attempts += 1
	self.status.lastError = message
	if self.attempts > self.config:Get().maxRecoveryAttempts then
		self:_fail(message)
		return
	end
	self.retryAt = now + 1
	self.waitKey = nil
	self.logger:Log("WARN", "Recovery attempt " .. self.attempts, message)
	self.machine:Set("RECOVERING", message)
end

function AutomationController:_wait(key, state, reason, now, config, timed)
	self:_cancel()
	if self.waitKey ~= key then
		self.waitKey, self.waitStarted = key, now
	end
	self.machine:Set(state, reason)
	if timed and now - self.waitStarted >= config.spawnWaitTimeout then
		self:_recover("Timed out: " .. reason, now)
	end
end

function AutomationController:_move(target, snapshot, now, config, radius, state)
	self.status.destination = target.name or target.id
	local result, message = self.movement:Move(target, snapshot.position, now, config, radius)
	if result == "error" then
		self:_recover(message, now)
	elseif result == "moving" then
		self.machine:Set(state, self.status.destination)
	end
	return result
end

function AutomationController:_complete(snapshot, now, config)
	self:_cancel()
	self.machine:Set("DUNGEON_COMPLETE", "Confirmed by dungeon state")
	if not config.autoRetry then
		self.enabled = false
		return
	end
	if self.completedRun ~= snapshot.runId then
		if not self.adapter.capabilities.replay then
			self:_fail("No verified replay mechanism configured")
			return
		end
		self.completedRun, self.replayStarted = snapshot.runId, now
		local accepted, message = self.adapter:requestReplay(snapshot.runId)
		if not accepted then
			self:_fail(message or "Replay request rejected")
		end
	elseif now - self.replayStarted >= config.spawnWaitTimeout then
		self:_fail("Replay requested, but no new run was confirmed")
	end
end

function AutomationController:_step(snapshot, now)
	local config = self.config:Get()
	local valid, problem = AreaDetector.validate(snapshot)
	if not valid then
		self:_wait("invalid", "RECOVERING", problem, now, config, true)
		return
	end
	self.status.area, self.status.totalAreas = snapshot.area, snapshot.totalAreas
	local scope = snapshot.dungeonId
		.. "/"
		.. snapshot.runId
		.. "/"
		.. snapshot.area
		.. "/"
		.. tostring(snapshot.characterId)
	if scope ~= self.scope then
		self:_cancel()
		self.scope, self.waitKey, self.targetId, self.clearedScope = scope, nil, nil, nil
		self.retryAt, self.attempts, self.lastRefresh = nil, 0, -math.huge
		self.machine:Set("FIND_NPCS", "Dungeon, area, or character changed")
	end
	if self.retryAt then
		if now < self.retryAt then
			return
		end
		self.retryAt = nil
	end
	if snapshot.completed then
		self:_complete(snapshot, now, config)
		return
	end
	if self.completedRun and snapshot.runId == self.completedRun then
		self:_wait("replay", "RECOVERING", "Waiting for a new run identity", now, config, true)
		return
	end
	if not snapshot.characterReady then
		self:_wait("character", "RECOVERING", "Waiting for character respawn", now, config, true)
		return
	end
	local inspection = DungeonController.inspect(snapshot)
	self.status.npcsRemaining = #inspection.npcs
	self.status.rubble = if inspection.rubble
		then string.format("Active · %.0f HP", inspection.rubble.health)
		else "No active barrier"
	if inspection.objective == "NPCs" then
		if not config.autoFarm then
			self:_wait("pausedNPC", "FIND_NPCS", "NPC farming is paused", now, config, false)
			return
		end
		local refresh = now - self.lastRefresh >= config.targetRefreshInterval
		local target = NPCDetector.select(snapshot, config, self.targetId, refresh)
		if refresh then
			self.lastRefresh = now
		end
		if not target then
			self:_wait("outOfRange", "FIND_NPCS", "Enemies are outside target distance", now, config, true)
			return
		end
		self.waitKey = nil
		if target.id ~= self.targetId then
			self.combat:Cancel()
			self.logger:Log("DEBUG", "NPC target acquired", target.id)
		end
		self.targetId, self.status.target = target.id, target.name or target.id
		local result = self:_move(target, snapshot, now, config, config.followDistance, "MOVE_TO_NPC")
		if result == "arrived" then
			self.machine:Set("ATTACK_NPCS", self.status.target)
			local ok, err = self.combat:Attack("NPC", target, snapshot, now, config)
			if not ok then
				self:_recover(err or "Combat action rejected", now)
			end
		else
			self.combat:Cancel()
		end
		return
	end
	if self.targetId then
		self.combat:Cancel()
	end
	self.targetId = nil
	if inspection.objective == "Wait" then
		self:_wait(
			"spawn",
			"WAIT_FOR_NPC_SPAWN",
			"Waiting for wave or area-clear confirmation",
			now,
			config,
			config.waitForNPCSpawn
		)
		return
	end
	if self.clearedScope ~= scope then
		self.clearedScope = scope
		self.machine:Set("CHECK_AREA_COMPLETION", "Area cleared by verified state")
		self.machine:Set("FIND_RUBBLE", "Checking progression objectives")
	end
	if inspection.objective == "Rubble" then
		if not config.autoBreakRubble then
			self:_wait("pausedRubble", "FIND_RUBBLE", "Rubble breaking is paused", now, config, false)
			return
		end
		self.waitKey = nil
		local target = inspection.target
		self.status.target = target.name or target.id
		local result = self:_move(target, snapshot, now, config, config.followDistance, "MOVE_TO_RUBBLE")
		if result == "arrived" then
			self.machine:Set("BREAK_RUBBLE", self.status.target)
			local ok, err = self.combat:Attack("Rubble", target, snapshot, now, config)
			if not ok then
				self:_recover(err or "Rubble action rejected", now)
			end
		else
			self.combat:Cancel()
		end
	elseif inspection.objective == "Entrance" then
		self.combat:Cancel()
		if not config.autoNextArea then
			self:_wait(
				"pausedEntrance",
				"MOVE_TO_NEXT_AREA",
				"Next-area movement is paused",
				now,
				config,
				false
			)
			return
		end
		local result = self:_move(inspection.target, snapshot, now, config, 2.5, "MOVE_TO_NEXT_AREA")
		if result == "arrived" then
			self:_wait(
				"entrance",
				"WAIT_FOR_NPC_SPAWN",
				"Waiting for next-area entry confirmation",
				now,
				config,
				true
			)
		else
			self.waitKey = nil
		end
	else
		self:_wait(
			"objective",
			"FIND_RUBBLE",
			"Waiting for rubble, entrance, or completion state",
			now,
			config,
			true
		)
	end
end

function AutomationController:Tick(now)
	if self.destroyed or not self.enabled then
		return
	end
	local ok, err = xpcall(function()
		self:_step(self.adapter:snapshot(), now)
	end, debug.traceback)
	if not ok then
		self:_fail(err)
	end
	self:_publish()
end

function AutomationController:Destroy()
	if self.destroyed then
		return
	end
	self:Stop("Controller unloaded")
	self.destroyed = true
	self.configConnection:Disconnect()
	self.stateConnection:Disconnect()
	for _, dispose in
		{
			function()
				self.combat:Destroy()
			end,
			function()
				self.movement:Destroy()
			end,
			function()
				self.adapter:destroy()
			end,
		}
	do
		local ok, err = pcall(dispose)
		if not ok then
			self.logger:Log("WARN", "Controller cleanup failed", err)
		end
	end
	self.machine:Destroy()
	self.Changed:Destroy()
end

return AutomationController
