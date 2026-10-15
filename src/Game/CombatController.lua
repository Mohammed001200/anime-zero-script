local NPCDetector = require(if script then script.Parent.NPCDetector else "./NPCDetector")
local Geometry = require(if script then script.Parent.Parent.Utils.Geometry else "../Utils/Geometry")
local CombatController = {}
CombatController.__index = CombatController

function CombatController.new(adapter)
	return setmetatable({ adapter = adapter, lastAttack = -math.huge, active = false }, CombatController)
end

function CombatController:Attack(kind, target, snapshot, now, config)
	if
		not NPCDetector.valid(target, snapshot)
		or Geometry.distance(snapshot.position, target.position) > config.attackRange
	then
		self:Cancel()
		return false, "Target unavailable or out of range"
	end
	local key = kind .. "/" .. snapshot.runId .. "/" .. target.id
	if self.targetKey ~= key then
		self:Cancel()
		self.targetKey, self.health, self.progressAt = key, target.health, now
	elseif target.healthKnown ~= false and self.health ~= nil and target.health < self.health then
		self.health, self.progressAt = target.health, now
	elseif now - self.progressAt >= config.combatProgressTimeout then
		self:Cancel()
		return false,
			if target.healthKnown == false
				then "Unverified damage: observed target remained for the combat timeout. Increase timeout only after confirming normal M1 hits: "
					.. target.id
				else "Combat made no health progress: " .. target.id
	end
	if now - self.lastAttack < config.attackInterval then
		return true
	end
	local capability = if kind == "NPC" then "attack" else "breakRubble"
	if not self.adapter.capabilities[capability] then
		return false, "Adapter does not support " .. capability
	end
	self.lastAttack, self.active = now, true
	-- Adapter resolves the ID again and validates it at the action boundary.
	return self.adapter:attack(kind, target.id, snapshot.runId)
end

function CombatController:Cancel()
	self.targetKey = nil
	if self.active then
		self.active = false
		self.adapter:cancelCombat()
	end
end

function CombatController:Destroy()
	self:Cancel()
end

return CombatController
