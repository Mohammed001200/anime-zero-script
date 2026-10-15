-- Synchronous signals; disconnecting during dispatch is supported.
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ listeners = {}, destroyed = false }, Signal)
end

function Signal:Connect(callback)
	assert(not self.destroyed, "Signal is destroyed")
	local connection = { Connected = true }
	self.listeners[connection] = callback
	function connection:Disconnect()
		self.Connected = false
	end
	return connection
end

function Signal:Fire(...)
	local pending = {}
	for connection, callback in self.listeners do
		table.insert(pending, { connection, callback })
	end
	for _, item in pending do
		if item[1].Connected then
			local ok, err = pcall(item[2], ...)
			if not ok then
				warn("[Mohammad & Ali] Listener failed: " .. tostring(err))
			end
		else
			self.listeners[item[1]] = nil
		end
	end
end

function Signal:Destroy()
	self.destroyed = true
	for connection in self.listeners do
		connection:Disconnect()
	end

	table.clear(self.listeners)
end

return Signal
