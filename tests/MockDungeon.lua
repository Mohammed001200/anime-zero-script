local Configuration = require("../src/Core/Configuration")
local Logger = require("../src/Core/Logger")
local AutomationController = require("../src/Core/AutomationController")
local MovementController = require("../src/Movement/MovementController")
local Geometry = require("../src/Utils/Geometry")
local MockDungeon = {}
MockDungeon.__index = MockDungeon

function MockDungeon.new()
	local self = setmetatable({
		now = 0,
		area = 1,
		run = 1,
		position = { x = 0, y = 0, z = 0 },
		characterReady = true,
		characterId = "character-1",
		replayRequests = 0,
		attacks = {},
		moves = {},
		cancelCount = 0,
		destroyCount = 0,
		history = {},
		capabilities = {
			attack = true,
			breakRubble = true,
			replay = true,
			preferences = false,
			movementSpeed = true,
		},
	}, MockDungeon)
	self:_area(1)
	return self
end

function MockDungeon:_target(id, x, health)
	return {
		id = id,
		name = id,
		dungeonId = "test-dungeon",
		runId = tostring(self.run),
		area = self.area,
		position = { x = x, y = 0, z = 0 },
		health = health,
		alive = true,
	}
end

function MockDungeon:_area(area)
	self.area, self.cleared, self.completed, self.pending = area, false, false, true
	self.spawnAt = self.now + 1
	local base = (area - 1) * 30
	self.npcs = {}
	self.rubble = if area < 5 then { self:_target("rubble-" .. area, base + 18, 40) } else {}
	table.insert(self.history, "Area " .. area)
end

function MockDungeon:snapshot()
	return {
		ready = self.ready ~= false,
		reason = "Mock state unavailable",
		dungeonId = "test-dungeon",
		runId = tostring(self.run),
		area = self.area,
		totalAreas = 5,
		completed = self.completed,
		areaCleared = self.cleared,
		spawnPending = self.pending,
		characterReady = self.characterReady,
		characterId = self.characterId,
		position = table.clone(self.position),
		npcs = self.npcs,
		rubble = self.rubble,
		nextEntrance = if self.cleared
				and self.area < 5
				and not self.noEntrance
			then {
				id = "entrance-" .. self.area,
				dungeonId = "test-dungeon",
				runId = tostring(self.run),
				area = self.area + 1,
				position = { x = (self.area - 1) * 30 + 26, y = 0, z = 0 },
			}
			else nil,
	}
end

function MockDungeon:attack(kind, id, runId)
	if self.throwAttack then
		error("Mock combat exception")
	end
	if self.noDamage then
		return true
	end
	local targets = if kind == "NPC" then self.npcs else self.rubble
	for _, target in targets do
		if target.id == id and target.alive and target.runId == runId then
			table.insert(self.attacks, { kind = kind, id = id, area = self.area })
			target.health -= 20
			if target.health <= 0 then
				target.alive = false
				table.insert(self.history, kind .. " destroyed " .. self.area)
			end
			local living = 0
			for _, npc in self.npcs do
				if npc.alive then
					living += 1
				end
			end
			self.cleared = not self.pending and living == 0
			if self.cleared and self.area == 5 then
				self.completed = true
			end
			return true
		end
	end
	return false, "Mock target unavailable"
end

function MockDungeon:cancelCombat()
	self.combatCancels = (self.combatCancels or 0) + 1
end

function MockDungeon:requestReplay(_runId)
	self.replayRequests += 1
	if self.rejectReplay then
		return false, "Replay rejected by mock"
	end
	if not self.holdReplay then
		self.replayAt = self.now + 0.5
	end
	return true
end

function MockDungeon:destroy()
	self.destroyCount += 1
end

function MockDungeon:advance(dt)
	self.now += dt
	if self.replayAt and self.now >= self.replayAt then
		self.replayAt, self.run = nil, self.run + 1
		self.position = { x = 0, y = 0, z = 0 }
		self:_area(1)
	end
	if self.pending and self.spawnAt and self.now >= self.spawnAt then
		self.pending, self.spawnAt = false, nil
		self.npcs = { self:_target("npc-" .. self.area, (self.area - 1) * 30 + 8, 40) }
	end
	if self.destination and not self.freeze then
		local distance = Geometry.distance(self.position, self.destination)
		if distance > 0 then
			local alpha = math.min(1, dt * 16 / distance)
			self.position = {
				x = self.position.x + (self.destination.x - self.position.x) * alpha,
				y = self.position.y + (self.destination.y - self.position.y) * alpha,
				z = self.position.z + (self.destination.z - self.position.z) * alpha,
			}
		end
	end
	local snapshot = self:snapshot()
	if snapshot.nextEntrance and not self.noTransition then
		local barrierAlive = false
		for _, barrier in self.rubble do
			if barrier.alive then
				barrierAlive = true
			end
		end
		if not barrierAlive and Geometry.distance(self.position, snapshot.nextEntrance.position) <= 2.5 then
			self:_area(self.area + 1)
		end
	end
end

function MockDungeon.harness()
	local mock = MockDungeon.new()
	local driver = { mock = mock, destroyed = 0 }
	function driver:moveTo(position, _config)
		self.mock.destination = table.clone(position)
		table.insert(self.mock.moves, position)
	end
	function driver:cancel()
		self.mock.destination = nil
		self.mock.cancelCount += 1
	end
	function driver:getError()
		return self.error
	end
	function driver:destroy()
		self.destroyed += 1
	end
	local config = Configuration.new()
	local logger = Logger.new(config, function() end)
	local movement = MovementController.new(driver)
	local controller = AutomationController.new(mock, movement, config, logger)
	local harness = {
		mock = mock,
		driver = driver,
		config = config,
		logger = logger,
		movement = movement,
		controller = controller,
		states = {},
	}
	controller.machine.Changed:Connect(function(state)
		table.insert(harness.states, state)
	end)
	function harness:advance(seconds)
		for _ = 1, math.ceil(seconds / 0.1) do
			mock:advance(0.1)
			controller:Tick(mock.now)
		end
	end
	function harness:destroy()
		controller:Destroy()
		config:Destroy()
		logger:Destroy()
	end
	return harness
end

return MockDungeon
