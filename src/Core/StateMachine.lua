local Signal = require(if script then script.Parent.Parent.Utils.Signal else "../Utils/Signal")
local StateMachine = {}
StateMachine.__index = StateMachine
StateMachine.labels = table.freeze({
	IDLE = "IDLE",
	FIND_NPCS = "SEARCHING FOR NPCS",
	MOVE_TO_NPC = "MOVING TO NPC",
	ATTACK_NPCS = "FARMING NPCS",
	CHECK_AREA_COMPLETION = "AREA CLEARED",
	FIND_RUBBLE = "SEARCHING FOR RUBBLE",
	MOVE_TO_RUBBLE = "MOVING TO RUBBLE",
	BREAK_RUBBLE = "BREAKING RUBBLE",
	MOVE_TO_NEXT_AREA = "MOVING TO NEXT AREA",
	WAIT_FOR_NPC_SPAWN = "WAITING FOR NPC SPAWN",
	DUNGEON_COMPLETE = "DUNGEON COMPLETE",
	RECOVERING = "RECOVERING",
	ERROR = "ERROR",
})

function StateMachine.new()
	return setmetatable({ state = "IDLE", reason = "Ready", Changed = Signal.new() }, StateMachine)
end

function StateMachine:Set(state, reason)
	assert(StateMachine.labels[state], "Unknown automation state: " .. tostring(state))
	if self.state == state and self.reason == reason then
		return
	end
	local previous = self.state
	self.state, self.reason = state, reason or ""
	self.Changed:Fire(state, previous, self.reason)
end

function StateMachine:Destroy()
	self.Changed:Destroy()
end

return StateMachine
