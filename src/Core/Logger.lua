local Signal = require(if script then script.Parent.Parent.Utils.Signal else "../Utils/Signal")
local Logger = {}
Logger.__index = Logger

function Logger.new(config, sink)
	return setmetatable(
		{ config = config, sink = sink or print, entries = {}, Message = Signal.new() },
		Logger
	)
end

function Logger:Log(level, message, context)
	if level == "DEBUG" and not self.config:Get().debug then
		return
	end
	local entry = { level = level, message = message, context = context }
	table.insert(self.entries, entry)
	if #self.entries > 150 then
		table.remove(self.entries, 1)
	end
	self.sink(
		"[Mohammad & Ali] [" .. level .. "] " .. message .. (context and " | " .. tostring(context) or "")
	)
	self.Message:Fire(entry)
end

function Logger:Destroy()
	self.Message:Destroy()
	table.clear(self.entries)
end

return Logger
