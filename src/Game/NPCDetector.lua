local Geometry = require(if script then script.Parent.Parent.Utils.Geometry else "../Utils/Geometry")
local NPCDetector = {}

function NPCDetector.valid(target, snapshot)
	return type(target) == "table"
		and type(target.id) == "string"
		and target.id ~= ""
		and target.alive == true
		and ((Geometry.finite(target.health) and target.health > 0) or (target.healthKnown == false and target.observedPresence == true and target.health == nil))
		and target.dungeonId == snapshot.dungeonId
		and target.runId == snapshot.runId
		and target.area == snapshot.area
		and Geometry.valid(target.position)
end

function NPCDetector.list(snapshot)
	local result = {}
	for _, target in snapshot.npcs do
		if NPCDetector.valid(target, snapshot) then
			table.insert(result, target)
		end
	end
	return result
end

function NPCDetector.select(snapshot, config, previousId, refresh)
	local best, score
	for _, target in NPCDetector.list(snapshot) do
		local distance = Geometry.distance(snapshot.position, target.position)
		if distance <= config.maxTargetDistance then
			if not refresh and target.id == previousId then
				return target
			end
			local candidate = if config.targetingMode == "LowestHealth"
				then target.health or math.huge
				else distance
			if not best or candidate < score or (candidate == score and target.id < best.id) then
				best, score = target, candidate
			end
		end
	end
	return best
end

return NPCDetector
