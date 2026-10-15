local AreaDetector =
	require(if script then script.Parent.Parent.Game.AreaDetector else "../Game/AreaDetector")
local Progression = {}

function Progression.nextObjective(snapshot, npcCount, rubble)
	if snapshot.completed then
		return "Complete"
	end
	if npcCount > 0 then
		return "NPCs"
	end
	-- Zero targets is not proof that the current wave or area is over.
	if snapshot.spawnPending or not snapshot.areaCleared then
		return "Wait"
	end
	if rubble then
		return "Rubble", rubble
	end
	local entrance = AreaDetector.entrance(snapshot)
	if entrance then
		return "Entrance", entrance
	end
	return "WaitObjective" -- Includes the final area until completion is authoritative.
end

return Progression
