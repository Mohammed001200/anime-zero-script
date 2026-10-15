-- Uses only the host functions whose presence the user checked in Solara.
-- A successful call means input was sent, never that the server accepted damage.
local M1Input = {}
M1Input.__index = M1Input

function M1Input.new(functions, guard, clock)
	return setmetatable({ functions = functions, guard = guard, clock = clock or os.clock }, M1Input)
end

function M1Input:Available()
	for _, name in { "press", "release", "focused" } do
		if type(self.functions[name]) ~= "function" then
			return false, "M1 input unavailable: missing host " .. name .. " function"
		end
	end
	if self.fault then
		return false, self.fault
	end
	return true
end

function M1Input:Safe()
	local available, problem = self:Available()
	if not available then
		return false, problem
	end
	local ok, focused = pcall(self.functions.focused)
	if not ok or type(focused) ~= "boolean" then
		self.fault = "Host window-focus check failed: " .. tostring(focused)
		return false, self.fault
	end
	if not focused then
		return false, "Paused: focus the Roblox game window"
	end
	local checked, safe, reason = pcall(self.guard, self.active == true or self.held == true)
	if not checked then
		self.fault = "Input guard failed: " .. tostring(safe)
		return false, self.fault
	end
	return safe, reason
end

function M1Input:_up()
	if not self.held then
		return self.fault == nil, self.fault
	end
	self.held = false
	local released, problem = pcall(self.functions.release)
	if not released then
		-- Do not issue any more presses after an uncertain release.
		self.fault = "M1 release failed; manually release M1 and unload: " .. tostring(problem)
	end
	return released, self.fault
end

function M1Input:Release()
	self.active = false
	self.nextPress, self.nextRelease = nil, nil
	return self:_up()
end

function M1Input:Configure(mode, interval)
	mode, interval = mode or "Hold", interval or 0.15
	if
		(mode ~= "Hold" and mode ~= "Pulse")
		or type(interval) ~= "number"
		or interval ~= interval
		or interval < 0.12
		or interval > 1
	then
		return false, "Invalid M1 mode/interval"
	end
	if self.mode ~= mode or self.interval ~= interval then
		local released, problem = self:Release()
		if not released then
			return false, problem
		end
		self.mode, self.interval = mode, interval
	end
	return true
end

function M1Input:_down()
	self.held = true
	local pressed, errorMessage = pcall(self.functions.press)
	if not pressed then
		self:Release()
		self.fault = self.fault or ("M1 press failed: " .. tostring(errorMessage))
		return false, self.fault
	end
	if self.mode == "Pulse" then
		local now = self.clock()
		self.nextRelease = now + math.min(0.05, self.interval / 3)
		self.nextPress = now + self.interval
	end
	return true
end

function M1Input:Hold()
	local safe, problem = self:Safe()
	if not safe then
		self:Release()
		return false, problem
	end
	self.lease = self.clock() + 1.5
	self.active = true
	if self.mode == "Pulse" then
		if not self.nextPress then
			return self:_down()
		end
		self:Poll()
		return self.fault == nil, self.fault
	end
	if self.held then
		return true
	end
	-- Mark ownership before calling: a host could send input then throw.
	return self:_down()
end

function M1Input:Poll()
	if not self.active and not self.held then
		return
	end
	local safe = self:Safe()
	if not safe or self.clock() >= self.lease then
		self:Release()
		return
	end
	if self.mode == "Pulse" then
		local now = self.clock()
		if self.held and now >= self.nextRelease then
			if not self:_up() then
				self.active = false
				return
			end
		end
		if not self.held and now >= self.nextPress then
			self:_down()
		end
	end
end

return M1Input
