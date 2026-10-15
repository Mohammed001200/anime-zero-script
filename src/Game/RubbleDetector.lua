local NPCDetector = require(if script then script.Parent.NPCDetector else "./NPCDetector")
local Geometry = require(if script then script.Parent.Parent.Utils.Geometry else "../Utils/Geometry")
local RubbleDetector = {}

function RubbleDetector.find(snapshot)
	local best, distance
	for _, target in snapshot.rubble do
		if NPCDetector.valid(target, snapshot) then
			local d = Geometry.distance(snapshot.position, target.position)
			if not best or d < distance then
				best, distance = target, d
			end
		end
	end
	return best
end

return RubbleDetector
