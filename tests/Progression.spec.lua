local Progression = require("../src/Dungeon/ProgressionController")
local Mock = require("./MockDungeon")
return function(t)
	t.it("accepted combat requests without health progress stop after bounded recovery", function()
		for _, kind in { "NPC", "Rubble" } do
			local h = Mock.harness()
			h.config:Set("combatProgressTimeout", 5)
			h.config:Set("maxRecoveryAttempts", 0)
			h.mock.noDamage = true
			if kind == "Rubble" then
				h.mock.pending, h.mock.cleared, h.mock.spawnAt = false, true, nil
			end
			h.controller:Start()
			h:advance(15)
			t.equal(h.controller.machine.state, "ERROR")
			assert(string.find(h.controller.status.lastError, "no health progress"))
			h:destroy()
		end
	end)
	t.it("empty targets are not proof of area completion", function()
		local h = Mock.harness()
		local snapshot = h.mock:snapshot()
		snapshot.spawnPending = false
		snapshot.areaCleared = false
		t.equal(Progression.nextObjective(snapshot, 0, snapshot.rubble[1]), "Wait")
		snapshot.areaCleared = true
		t.equal(Progression.nextObjective(snapshot, 0, snapshot.rubble[1]), "Rubble")
		h:destroy()
	end)
	t.it("spawn-pending wins over a stale clear flag", function()
		local h = Mock.harness()
		local snapshot = h.mock:snapshot()
		snapshot.areaCleared = true
		t.equal(Progression.nextObjective(snapshot, 0, snapshot.rubble[1]), "Wait")
		h:destroy()
	end)
	t.it("five areas clear enemies, break four barriers, and confirm completion", function()
		local h = Mock.harness()
		h.controller:Start()
		h:advance(90)
		t.equal(h.mock.area, 5)
		t.equal(h.controller.machine.state, "DUNGEON_COMPLETE")
		t.equal(h.controller.enabled, false)
		local rubbleHits, npcHits = 0, 0
		for _, attack in h.mock.attacks do
			if attack.kind == "NPC" then
				npcHits += 1
			else
				rubbleHits += 1
			end
		end
		t.equal(npcHits, 10)
		t.equal(rubbleHits, 8)
		for area = 1, 4 do
			local kill = table.find(h.mock.history, "NPC destroyed " .. area)
			local barrier = table.find(h.mock.history, "Rubble destroyed " .. area)
			local nextArea = table.find(h.mock.history, "Area " .. area + 1)
			assert(kill < barrier and barrier < nextArea)
		end
		for _, required in
			{
				"WAIT_FOR_NPC_SPAWN",
				"MOVE_TO_NPC",
				"ATTACK_NPCS",
				"CHECK_AREA_COMPLETION",
				"FIND_RUBBLE",
				"MOVE_TO_RUBBLE",
				"BREAK_RUBBLE",
				"MOVE_TO_NEXT_AREA",
				"DUNGEON_COMPLETE",
			}
		do
			assert(table.find(h.states, required), "Missing state " .. required)
		end
		t.equal(h.mock.destination, nil)
		h:destroy()
	end)
	t.it("delayed waves wait and then resume farming", function()
		local h = Mock.harness()
		h.mock.spawnAt = 3
		h.controller:Start()
		h:advance(2)
		t.equal(h.controller.machine.state, "WAIT_FOR_NPC_SPAWN")
		t.equal(#h.mock.attacks, 0)
		h:advance(2)
		assert(#h.mock.attacks > 0)
		h:destroy()
	end)
	t.it("destroyed rubble is never attacked again", function()
		local h = Mock.harness()
		h.controller:Start()
		h:advance(6)
		local count = 0
		for _, attack in h.mock.attacks do
			if attack.id == "rubble-1" then
				count += 1
			end
		end
		t.equal(count, 2)
		h:advance(5)
		local after = 0
		for _, attack in h.mock.attacks do
			if attack.id == "rubble-1" then
				after += 1
			end
		end
		t.equal(after, count)
		h:destroy()
	end)
	t.it("missing objectives wait instead of selecting spawn", function()
		local h = Mock.harness()
		h.mock.cleared, h.mock.pending, h.mock.noEntrance = true, false, true
		h.mock.rubble, h.mock.spawnAt = {}, nil
		h.controller:Start()
		h:advance(2)
		t.equal(#h.mock.moves, 0)
		t.equal(h.controller.machine.state, "FIND_RUBBLE")
		h:destroy()
	end)
	t.it("final empty area waits for reliable completion", function()
		local h = Mock.harness()
		h.mock:_area(5)
		h.mock.pending, h.mock.cleared, h.mock.spawnAt = false, true, nil
		h.controller:Start()
		h:advance(2)
		t.equal(h.controller.enabled, true)
		assert(h.controller.machine.state ~= "DUNGEON_COMPLETE")
		h:destroy()
	end)
	t.it("auto retry requests once and starts a run with a new identity", function()
		local h = Mock.harness()
		h.config:Set("autoRetry", true)
		h.mock.completed, h.mock.holdReplay = true, true
		h.controller:Start()
		h:advance(2)
		t.equal(h.mock.replayRequests, 1)
		t.equal(h.controller.machine.state, "DUNGEON_COMPLETE")
		h.mock.holdReplay = false
		h.mock.replayAt = h.mock.now + 0.1
		h:advance(2)
		t.equal(h.mock.run, 2)
		assert(#h.mock.attacks > 0)
		h:destroy()
	end)
	t.it("unsupported and rejected replay stop with clear errors", function()
		for _, mode in { "unsupported", "rejected" } do
			local h = Mock.harness()
			h.config:Set("autoRetry", true)
			h.mock.completed = true
			if mode == "unsupported" then
				h.mock.capabilities.replay = false
			else
				h.mock.rejectReplay = true
			end
			h.controller:Start()
			h:advance(0.2)
			t.equal(h.controller.machine.state, "ERROR")
			t.equal(h.controller.enabled, false)
			h:destroy()
		end
	end)
	t.it("replay timeout never sends a second request", function()
		local h = Mock.harness()
		h.config:Set("autoRetry", true)
		h.config:Set("spawnWaitTimeout", 5)
		h.mock.completed, h.mock.holdReplay = true, true
		h.controller:Start()
		h:advance(8)
		t.equal(h.mock.replayRequests, 1)
		t.equal(h.controller.machine.state, "ERROR")
		h:destroy()
	end)
	t.it("paused objectives and NPC settings cancel active actions", function()
		local h = Mock.harness()
		h.controller:Start()
		h:advance(1.1)
		h.config:Set("autoFarm", false)
		t.equal(h.mock.destination, nil)
		h:advance(1)
		t.equal(#h.mock.attacks, 0)
		h.mock.pending, h.mock.cleared, h.mock.npcs = false, true, {}
		h.config:Set("autoBreakRubble", false)
		h:advance(1)
		t.equal(#h.mock.attacks, 0)
		h.mock.rubble = {}
		h.config:Set("autoNextArea", false)
		h:advance(1)
		t.equal(h.mock.destination, nil)
		h:destroy()
	end)
	t.it("respawn stops actions and resumes with the new character", function()
		local h = Mock.harness()
		h.controller:Start()
		h:advance(1.1)
		h.mock.characterReady = false
		h:advance(0.2)
		t.equal(h.mock.destination, nil)
		t.equal(h.controller.machine.state, "RECOVERING")
		h.mock.characterId, h.mock.characterReady = "character-2", true
		h:advance(2)
		assert(#h.mock.attacks > 0)
		h:destroy()
	end)
	t.it("unexpected area changes discard previous navigation targets", function()
		local h = Mock.harness()
		h.controller:Start()
		h:advance(1.1)
		h.mock:_area(3)
		h:advance(0.1)
		t.equal(h.mock.destination, nil)
		t.equal(h.controller.status.area, 3)
		h:advance(3)
		assert(h.mock.destination == nil or h.mock.destination.x >= 60)
		h:destroy()
	end)
	t.it("manual recovery clears an error and rechecks the current area", function()
		local h = Mock.harness()
		h.mock.throwAttack = true
		h.controller:Start()
		h:advance(3)
		t.equal(h.controller.machine.state, "ERROR")
		h.mock.throwAttack = false
		h.controller:Recover()
		h:advance(3)
		t.equal(h.controller.status.lastError, "None")
		assert(#h.mock.attacks > 0)
		h:destroy()
	end)
	t.it("spawn waiting can be paused without exhausting recovery", function()
		local h = Mock.harness()
		h.config:Set("waitForNPCSpawn", false)
		h.config:Set("spawnWaitTimeout", 5)
		h.mock.spawnAt = nil
		h.controller:Start()
		h:advance(30)
		t.equal(h.controller.enabled, true)
		t.equal(h.controller.attempts, 0)
		h:destroy()
	end)
end
