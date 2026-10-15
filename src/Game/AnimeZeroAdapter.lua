-- No live Anime Zero hierarchy, remotes, or combat API have been verified.
-- Supply developer-authorized, non-yielding bindings; fail closed otherwise.
local Adapter = {}
Adapter.__index = Adapter

function Adapter.new(bindings)
	bindings = bindings or {}
	return setmetatable({
		bindings = bindings,
		capabilities = {
			attack = type(bindings.attack) == "function",
			breakRubble = type(bindings.breakRubble) == "function",
			replay = type(bindings.requestReplay) == "function",
			preferences = type(bindings.savePreferences) == "function",
			movementSpeed = bindings.movementSpeed == true,
		},
	}, Adapter)
end

function Adapter:snapshot()
	if not self.bindings.snapshot then
		return {
			ready = false,
			reason = "Anime Zero integration is not configured. Use the Studio demo or verified bindings.",
		}
	end
	return self.bindings.snapshot()
end

function Adapter:attack(kind, id, runId)
	local action = if kind == "NPC" then self.bindings.attack else self.bindings.breakRubble
	if not action then
		return false, "Combat binding is unavailable"
	end
	return action(id, runId)
end

function Adapter:cancelCombat()
	if self.bindings.cancelCombat then
		self.bindings.cancelCombat()
	end
end

function Adapter:requestReplay(runId)
	if not self.bindings.requestReplay then
		return false, "Replay binding is unavailable"
	end
	return self.bindings.requestReplay(runId)
end

function Adapter:savePreferences(preferences)
	if not self.bindings.savePreferences then
		return false, "Preference persistence is unavailable"
	end
	return self.bindings.savePreferences(preferences)
end

function Adapter:loadPreferences()
	if self.bindings.loadPreferences then
		return self.bindings.loadPreferences()
	end
	return nil
end

function Adapter:destroy()
	self:cancelCombat()
	if self.bindings.destroy then
		self.bindings.destroy()
	end
end

return Adapter
