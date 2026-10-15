local Mock = require("./MockDungeon")
return function(t)
	t.it("navigation stops outside a solid target at the configured follow distance", function()
		local h = Mock.harness()
		h.movement:Move(
			{ id = "rubble", position = { x = 20, y = 0, z = 0 } },
			h.mock.position,
			0,
			h.config:Get(),
			5
		)
		t.equal(h.mock.destination.x, 15.5)
		h:destroy()
	end)
	t.it("movement timeout stops even when stuck detection is disabled", function()
		local h = Mock.harness()
		h.mock.freeze = true
		h.config:Set("stuckDetection", false)
		h.config:Set("movementTimeout", 5)
		h.config:Set("maxRecoveryAttempts", 0)
		h.controller:Start()
		h:advance(10)
		t.equal(h.controller.machine.state, "ERROR")
		assert(string.find(h.controller.status.lastError, "Movement timeout"))
		t.equal(h.mock.destination, nil)
		h:destroy()
	end)
	t.it("stuck recovery is bounded and does not return to spawn", function()
		local h = Mock.harness()
		h.mock.freeze = true
		h.config:Set("stuckTimeout", 2)
		h.config:Set("maxRecoveryAttempts", 1)
		h.controller:Start()
		h:advance(12)
		t.equal(h.controller.machine.state, "ERROR")
		t.equal(h.controller.attempts, 2)
		for _, move in h.mock.moves do
			assert(move.x > 0)
		end
		h:destroy()
	end)
	t.it("driver interruptions cancel navigation and enter recovery", function()
		local h = Mock.harness()
		h.controller:Start()
		h:advance(1.1)
		h.driver.error = "Path blocked"
		h:advance(0.1)
		t.equal(h.controller.machine.state, "RECOVERING")
		t.equal(h.mock.destination, nil)
		h:destroy()
	end)
	t.it("invalid destination is rejected before invoking movement driver", function()
		local h = Mock.harness()
		local result = h.movement:Move(
			{ id = "bad", position = { x = 0 / 0, y = 0, z = 0 } },
			h.mock.position,
			0,
			h.config:Get(),
			2
		)
		t.equal(result, "error")
		t.equal(#h.mock.moves, 0)
		h:destroy()
	end)
	t.it("changing destination cancels the previous movement owner", function()
		local h = Mock.harness()
		local config = h.config:Get()
		h.movement:Move({ id = "one", position = { x = 20, y = 0, z = 0 } }, h.mock.position, 0, config, 2)
		h.movement:Move({ id = "two", position = { x = 30, y = 0, z = 0 } }, h.mock.position, 1, config, 2)
		t.equal(h.mock.cancelCount, 1)
		t.equal(h.movement.active.id, "two")
		h.movement:Cancel()
		t.equal(h.mock.destination, nil)
		h:destroy()
	end)
end
