-- Binding contracts only. These tests do NOT establish any Anime Zero API.
local Adapter = require("../src/Game/AnimeZeroAdapter")
local Configuration = require("../src/Core/Configuration")
local Logger = require("../src/Core/Logger")
local Automation = require("../src/Core/AutomationController")
local Movement = require("../src/Movement/MovementController")

local function fixture(bindings)
	local config = Configuration.new()
	local driver = { moves = 0 }
	function driver:moveTo()
		self.moves += 1
	end
	function driver:cancel() end
	function driver:getError()
		return nil
	end
	function driver:destroy() end
	local adapter = Adapter.new(bindings)
	local logger = Logger.new(config, function() end)
	local controller = Automation.new(adapter, Movement.new(driver), config, logger)
	return {
		config = config,
		adapter = adapter,
		controller = controller,
		driver = driver,
		destroy = function()
			controller:Destroy()
			logger:Destroy()
			config:Destroy()
		end,
	}
end

local function snapshot()
	return {
		ready = true,
		dungeonId = "contract-dungeon",
		runId = "contract-run",
		area = 1,
		totalAreas = 5,
		completed = false,
		areaCleared = false,
		spawnPending = false,
		characterReady = true,
		characterId = "character",
		position = { x = 0, y = 0, z = 0 },
		npcs = {},
		rubble = {},
	}
end

local function npc(state, id, distance)
	return {
		id = id,
		name = id,
		dungeonId = state.dungeonId,
		runId = state.runId,
		area = state.area,
		position = { x = distance, y = 0, z = 0 },
		alive = true,
		health = 100,
	}
end

return function(t)
	t.it("empty real adapter stops immediately without attempting recovery or movement", function()
		local h = fixture({})
		local started, reason = h.controller:Start()
		t.equal(started, false)
		assert(string.find(reason, "snapshot, attack, breakRubble", 1, true))
		for now = 1, 100 do
			h.controller:Tick(now)
		end
		t.equal(h.controller.machine.state, "ERROR")
		t.equal(h.controller.enabled, false)
		t.equal(h.controller.attempts, 0)
		t.equal(h.driver.moves, 0)
		h.controller:Recover()
		t.equal(h.controller.machine.state, "ERROR")
		h.destroy()
	end)
	t.it("missing combat and replay bindings are identified by enabled feature", function()
		local h = fixture({ snapshot = snapshot })
		h.config:Set("autoFarm", false)
		h.config:Set("autoBreakRubble", false)
		t.equal(h.adapter:preflight(h.config:Get()), true)
		h.config:Set("killAura", true)
		local ok, reason = h.adapter:preflight(h.config:Get())
		t.equal(ok, false)
		assert(string.find(reason, "attack", 1, true))
		h.config:Set("killAura", false)
		h.config:Set("autoRetry", true)
		ok, reason = h.adapter:preflight(h.config:Get())
		t.equal(ok, false)
		assert(string.find(reason, "requestReplay", 1, true))
		assert(string.find(h.adapter:integrationStatus().replay, "completion/new-run", 1, true))
		h.destroy()
	end)
	t.it("permanently blocked snapshot stops immediately even when callbacks exist", function()
		local h = fixture({
			snapshot = function()
				return { ready = false, blocked = true, reason = "Scope binding revoked" }
			end,
			attack = function()
				return true
			end,
			breakRubble = function()
				return true
			end,
		})
		h.controller:Start()
		h.controller:Tick(0)
		t.equal(h.controller.enabled, false)
		t.equal(h.controller.status.lastError, "Scope binding revoked")
		t.equal(h.controller.attempts, 0)
		h.destroy()
	end)
	t.it("Kill Aura attacks in-range scoped living targets without pursuing distant NPCs", function()
		local state, hits = snapshot(), {}
		local near, far = npc(state, "near", 4), npc(state, "far", 40)
		local foreign = npc(state, "foreign", 1)
		foreign.area = 2
		local dead = npc(state, "dead", 1)
		dead.alive = false
		dead.health = 0
		state.npcs = { far, foreign, dead, near }
		local h = fixture({
			snapshot = function()
				return state
			end,
			attack = function(id)
				table.insert(hits, id)
				near.health -= 20
				near.alive = near.health > 0
				return true
			end,
		})
		h.config:Set("autoFarm", false)
		h.config:Set("autoBreakRubble", false)
		h.config:Set("autoNextArea", false)
		h.config:Set("killAura", true)
		h.config:Set("attackRange", 6)
		h.controller:Start()
		for now = 0, 6 do
			h.controller:Tick(now)
		end
		t.equal(#hits, 5)
		for _, id in hits do
			t.equal(id, "near")
		end
		t.equal(h.driver.moves, 0)
		t.equal(h.controller.enabled, true)
		t.equal(h.controller.machine.state, "FIND_NPCS")
		h.destroy()
	end)
	t.it("Kill Aura range and OFF state cancel attacks independently of Auto Farm", function()
		local state, hits = snapshot(), 0
		state.npcs = { npc(state, "near", 4) }
		local h = fixture({
			snapshot = function()
				return state
			end,
			attack = function()
				hits += 1
				return true
			end,
		})
		h.config:Set("autoFarm", false)
		h.config:Set("autoBreakRubble", false)
		h.config:Set("killAura", true)
		h.config:Set("attackRange", 2)
		h.controller:Start()
		h.controller:Tick(0)
		t.equal(hits, 0)
		h.config:Set("attackRange", 6)
		h.controller:Tick(1)
		t.equal(hits, 1)
		h.config:Set("killAura", false)
		h.controller:Tick(2)
		t.equal(hits, 1)
		t.equal(h.driver.moves, 0)
		h.destroy()
	end)
	t.it("Auto Farm plus Kill Aura attacks at attack range without unnecessary pursuit", function()
		local state, hits = snapshot(), 0
		state.npcs = { npc(state, "near", 7) }
		local h = fixture({
			snapshot = function()
				return state
			end,
			attack = function()
				hits += 1
				return true
			end,
		})
		h.config:Set("autoBreakRubble", false)
		h.config:Set("killAura", true)
		h.config:Set("followDistance", 3)
		h.controller:Start()
		h.controller:Tick(0)
		t.equal(hits, 1)
		t.equal(h.driver.moves, 0)
		h.destroy()
	end)
	t.it("supplied replay binding is called once and requires a distinct run identity", function()
		local state, requests = snapshot(), 0
		state.completed = true
		local h = fixture({
			snapshot = function()
				return state
			end,
			requestReplay = function()
				requests += 1
				return true
			end,
		})
		h.config:Set("autoFarm", false)
		h.config:Set("autoBreakRubble", false)
		h.config:Set("autoRetry", true)
		h.controller:Start()
		h.controller:Tick(0)
		h.controller:Tick(1)
		h.controller:Tick(2)
		t.equal(requests, 1)
		state.completed, state.runId, state.spawnPending = false, "new-contract-run", true
		h.controller:Tick(3)
		t.equal(h.controller.machine.state, "WAIT_FOR_NPC_SPAWN")
		h.destroy()
	end)
end
