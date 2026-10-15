local NPCDetector = require("../src/Game/NPCDetector")
local RubbleDetector = require("../src/Game/RubbleDetector")
local AreaDetector = require("../src/Game/AreaDetector")
local Mock = require("./MockDungeon")
return function(t)
	t.it("nearest selection ignores dead, foreign-area and foreign-run NPCs", function()
		local h = Mock.harness()
		h.mock:advance(1)
		local near = h.mock:_target("near", 4, 40)
		local dead = h.mock:_target("dead", 1, 0)
		local foreign = h.mock:_target("foreign", 1, 40)
		foreign.area = 2
		local old = h.mock:_target("old", 1, 40)
		old.runId = "previous"
		local outside = h.mock:_target("outside", 1, 40)
		outside.dungeonId = "another"
		h.mock.npcs = { h.mock.npcs[1], near, dead, foreign, old, outside }
		t.equal(NPCDetector.select(h.mock:snapshot(), h.config:Get(), nil, true).id, "near")
		h:destroy()
	end)
	t.it("lowest health and target distance settings affect selection", function()
		local h = Mock.harness()
		h.mock:advance(1)
		h.mock.npcs = { h.mock:_target("healthy", 5, 90), h.mock:_target("weak", 25, 1) }
		h.config:Set("targetingMode", "LowestHealth")
		t.equal(NPCDetector.select(h.mock:snapshot(), h.config:Get(), nil, true).id, "weak")
		h.config:Set("maxTargetDistance", 10)
		t.equal(NPCDetector.select(h.mock:snapshot(), h.config:Get(), nil, true).id, "healthy")
		h:destroy()
	end)
	t.it("selection retains a valid target until refresh and resolves ties deterministically", function()
		local h = Mock.harness()
		h.mock:advance(1)
		h.mock.npcs = { h.mock:_target("b", 5, 40), h.mock:_target("a", 5, 40) }
		t.equal(NPCDetector.select(h.mock:snapshot(), h.config:Get(), "b", false).id, "b")
		t.equal(NPCDetector.select(h.mock:snapshot(), h.config:Get(), "b", true).id, "a")
		h:destroy()
	end)
	t.it("target disappearance cancels navigation without returning to spawn", function()
		local h = Mock.harness()
		h.controller:Start()
		h:advance(1.1)
		h.mock.npcs = {}
		h.mock.cleared = false
		h.mock.spawnAt = nil
		h:advance(0.2)
		t.equal(h.mock.destination, nil)
		t.equal(h.controller.machine.state, "WAIT_FOR_NPC_SPAWN")
		for _, move in h.mock.moves do
			assert(move.x > 0, "Unexpected return to spawn")
		end
		h:destroy()
	end)
	t.it("rubble discovery rejects destroyed or foreign barriers", function()
		local h = Mock.harness()
		local wrong = h.mock:_target("foreign", 0, 10)
		wrong.area = 2
		local dead = h.mock:_target("dead", 0, 0)
		table.insert(h.mock.rubble, wrong)
		table.insert(h.mock.rubble, dead)
		t.equal(RubbleDetector.find(h.mock:snapshot()).id, "rubble-1")
		h.mock.rubble[1].alive = false
		t.equal(RubbleDetector.find(h.mock:snapshot()), nil)
		h:destroy()
	end)
	t.it("malformed positions and health cannot become targets", function()
		local h = Mock.harness()
		h.mock:advance(1)
		h.mock.npcs[1].position.x = math.huge
		t.equal(NPCDetector.select(h.mock:snapshot(), h.config:Get(), nil, true), nil)
		h.mock.npcs[1].position.x = 2
		h.mock.npcs[1].health = 0 / 0
		t.equal(#NPCDetector.list(h.mock:snapshot()), 0)
		h:destroy()
	end)
	t.it("entrances require matching dungeon, run and immediately following area", function()
		local h = Mock.harness()
		h.mock.cleared = true
		local snapshot = h.mock:snapshot()
		assert(AreaDetector.entrance(snapshot))
		snapshot.nextEntrance.area = 4
		t.equal(AreaDetector.entrance(snapshot), nil)
		snapshot.nextEntrance.area = 2
		snapshot.nextEntrance.runId = "old"
		t.equal(AreaDetector.entrance(snapshot), nil)
		h:destroy()
	end)
	t.it("invalid game state is rejected before decisions", function()
		local h = Mock.harness()
		local snapshot = h.mock:snapshot()
		snapshot.area = 1.5
		t.equal(AreaDetector.validate(snapshot), false)
		snapshot.area = 1
		snapshot.areaCleared = nil
		t.equal(AreaDetector.validate(snapshot), false)
		h:destroy()
	end)
end
