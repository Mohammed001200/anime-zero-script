local Geometry = require(if script then script.Parent.Parent.Utils.Geometry else "../Utils/Geometry")
local AreaDetector = {}

function AreaDetector.validate(snapshot)
	if type(snapshot) ~= "table" then
		return false, "Adapter returned no snapshot"
	end
	if snapshot.ready ~= true then
		return false, snapshot.reason or "Waiting for verified dungeon state"
	end
	if
		type(snapshot.dungeonId) ~= "string"
		or snapshot.dungeonId == ""
		or type(snapshot.runId) ~= "string"
		or snapshot.runId == ""
	then
		return false, "Missing dungeon/run identity"
	end
	if
		not Geometry.finite(snapshot.area)
		or not Geometry.finite(snapshot.totalAreas)
		or snapshot.area % 1 ~= 0
		or snapshot.totalAreas % 1 ~= 0
		or snapshot.area < 1
		or snapshot.area > snapshot.totalAreas
	then
		return false, "Invalid area state"
	end
	for _, field in { "completed", "areaCleared", "spawnPending", "characterReady" } do
		if type(snapshot[field]) ~= "boolean" then
			return false, "Missing boolean: " .. field
		end
	end
	if type(snapshot.npcs) ~= "table" or type(snapshot.rubble) ~= "table" then
		return false, "Missing target collections"
	end
	if
		snapshot.characterReady
		and (not Geometry.valid(snapshot.position) or type(snapshot.characterId) ~= "string")
	then
		return false, "Invalid character position/identity"
	end
	return true
end

function AreaDetector.entrance(snapshot)
	local entry = snapshot.nextEntrance
	if
		type(entry) == "table"
		and type(entry.id) == "string"
		and entry.dungeonId == snapshot.dungeonId
		and entry.runId == snapshot.runId
		and entry.area == snapshot.area + 1
		and entry.area <= snapshot.totalAreas
		and Geometry.valid(entry.position)
	then
		return entry
	end
	return nil
end

return AreaDetector
