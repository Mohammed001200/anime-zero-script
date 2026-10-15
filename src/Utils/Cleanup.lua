local Cleanup = {}
Cleanup.__index = Cleanup

function Cleanup.new()
	return setmetatable({ items = {} }, Cleanup)
end

function Cleanup:Add(item)
	table.insert(self.items, item)
	return item
end

function Cleanup:Destroy()
	local items = self.items
	self.items = {}
	for index = #items, 1, -1 do
		local item = items[index]
		local ok, err = pcall(function()
			if type(item) == "function" then
				item()
			elseif
				typeof(item) == "RBXScriptConnection"
				or (type(item) == "table" and type(item.Disconnect) == "function")
			then
				item:Disconnect()
			else
				item:Destroy()
			end
		end)
		if not ok then
			warn("[Mohammad & Ali] Cleanup failed: " .. tostring(err))
		end
	end
end

return Cleanup
