-- No live Anime Zero hierarchy, remotes, or combat API have been verified.
-- Supply developer-authorized, non-yielding bindings; fail closed otherwise.
local Adapter = {}
Adapter.__index = Adapter

function Adapter.new(bindings)
	bindings = bindings or {}
	return setmetatable({
		bindings = bindings,
		capabilities = {
			inputTrial = bindings.inputTrial == true,
			snapshot = type(bindings.snapshot) == "function",
			attack = type(bindings.attack) == "function",
			breakRubble = type(bindings.breakRubble) == "function",
			replay = type(bindings.requestReplay) == "function",
			preferences = type(bindings.savePreferences) == "function",
			movementSpeed = bindings.movementSpeed == true,
		},
	}, Adapter)
end

function Adapter:integrationStatus()
	if self.bindings.integrationStatus then
		return self.bindings.integrationStatus()
	end
	local missing = {}
	for _, key in { "snapshot", "attack", "breakRubble", "requestReplay" } do
		if type(self.bindings[key]) ~= "function" then
			table.insert(missing, key)
		end
	end
	return {
		configured = #missing == 0,
		missing = missing,
		summary = if #missing > 0
			then "Missing game bindings: " .. table.concat(missing, ", ")
			else "Bindings supplied; real gameplay still requires validation",
		replay = if self.capabilities.replay
			then "Replay binding supplied; completion and new-run confirmation required"
			else "Auto Retry unavailable: missing requestReplay binding and confirmed completion/new-run state",
	}
end

function Adapter:preflight(config)
	local required = { "snapshot" }
	if config.autoFarm or config.killAura then
		table.insert(required, "attack")
	end
	if config.autoBreakRubble then
		table.insert(required, "breakRubble")
	end
	if config.autoRetry then
		table.insert(required, "requestReplay")
	end
	local missing = {}
	for _, key in required do
		if type(self.bindings[key]) ~= "function" then
			table.insert(missing, key)
		end
	end
	if #missing > 0 then
		return false,
			"Integration unavailable: missing "
				.. table.concat(missing, ", ")
				.. ". Automation stopped; open Diagnostics. Recovery cannot create game bindings."
	end
	if self.bindings.preflight then
		return self.bindings.preflight(config)
	end
	return true
end

function Adapter:snapshot()
	if not self.bindings.snapshot then
		return {
			ready = false,
			blocked = true,
			reason = "Missing snapshot binding: dungeon/run/area, NPCs, rubble and completion are unknown. Open Diagnostics.",
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
