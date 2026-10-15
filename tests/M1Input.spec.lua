local M1Input = require("../src/Game/M1Input")

local function fixture()
	local state = { time = 0, focused = true, allowed = true, presses = 0, releases = 0 }
	state.input = M1Input.new({
		press = function()
			state.presses += 1
		end,
		release = function()
			state.releases += 1
		end,
		focused = function()
			return state.focused
		end,
	}, function()
		return state.allowed, "Pointer over UI"
	end, function()
		return state.time
	end)
	return state
end

return function(t)
	t.it("unimplemented host focus functions stop input instead of waiting forever", function()
		local h = fixture()
		h.input.functions.focused = function()
			error("Not implemented")
		end
		t.equal(h.input:Hold(), false)
		t.equal(h.input:Available(), false)
		t.equal(h.presses, 0)
	end)
	t.it("M1 holds once, renews its lease, and releases on focus loss", function()
		local h = fixture()
		t.equal(h.input:Hold(), true)
		h.time = 1
		t.equal(h.input:Hold(), true)
		t.equal(h.presses, 1)
		h.focused = false
		h.input:Poll()
		t.equal(h.releases, 1)
		t.equal(h.input.held, false)
		t.equal(h.input:Hold(), false)
		t.equal(h.presses, 1)
	end)
	t.it("M1 watchdog releases expired input without a controller tick", function()
		local h = fixture()
		h.input:Hold()
		h.time = 1.6
		h.input:Poll()
		t.equal(h.releases, 1)
		h.input:Release()
		t.equal(h.releases, 1)
	end)
	t.it("M1 never presses over UI and releases a held button on UI entry", function()
		local h = fixture()
		h.allowed = false
		t.equal(h.input:Hold(), false)
		t.equal(h.presses, 0)
		h.allowed = true
		h.input:Hold()
		h.allowed = false
		h.input:Poll()
		t.equal(h.releases, 1)
	end)
	t.it("M1 press errors trigger cleanup and prevent subsequent presses", function()
		local h = fixture()
		h.input.functions.press = function()
			error("Injected press failure")
		end
		t.equal(h.input:Hold(), false)
		t.equal(h.releases, 1)
		t.equal(h.input:Available(), false)
	end)
	t.it("M1 release errors and missing functions fail closed", function()
		local h = fixture()
		h.input:Hold()
		h.input.functions.release = function()
			error("Injected release failure")
		end
		t.equal(h.input:Release(), false)
		t.equal(h.input:Hold(), false)
		t.equal(h.presses, 1)
		h = fixture()
		h.input.functions.release = nil
		t.equal(h.input:Hold(), false)
		t.equal(h.presses, 0)
	end)
end
