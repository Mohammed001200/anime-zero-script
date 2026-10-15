local NPCDetector = require(if script then script.Parent.Parent.Game.NPCDetector else "../Game/NPCDetector")
local RubbleDetector =
	require(if script then script.Parent.Parent.Game.RubbleDetector else "../Game/RubbleDetector")
local Progression = require(if script then script.Parent.ProgressionController else "./ProgressionController")
local DungeonController = {}

function DungeonController.inspect(snapshot)
	local npcs = NPCDetector.list(snapshot)
	local rubble = RubbleDetector.find(snapshot)
	local objective, target = Progression.nextObjective(snapshot, #npcs, rubble)
	return { npcs = npcs, rubble = rubble, objective = objective, target = target }
end

return DungeonController
