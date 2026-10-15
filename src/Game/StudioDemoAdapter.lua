local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Adapter = {}
Adapter.__index = Adapter

function Adapter.new(player)
	assert(RunService:IsStudio(), "Studio demo is restricted to Studio")
	return setmetatable({
		player = player,
		character = nil,
		characterVersion = 0,
		capabilities = {
			attack = true,
			breakRubble = true,
			replay = true,
			preferences = true,
			movementSpeed = true,
		},
	}, Adapter)
end

function Adapter:_references()
	local root = ReplicatedStorage:FindFirstChild("MA_StudioDemo")
	return root and root:FindFirstChild(tostring(self.player.UserId)), root and root:FindFirstChild("Action")
end

function Adapter:snapshot()
	local folder = self:_references()
	local packet = folder and folder:GetAttribute("Snapshot")
	if not packet then
		return { ready = false, reason = "Waiting for Studio demo server" }
	end
	local snapshot = HttpService:JSONDecode(packet)
	local character = self.player.Character
	if self.character ~= character then
		self.character, self.characterVersion = character, self.characterVersion + 1
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	snapshot.characterReady = humanoid ~= nil and root ~= nil and humanoid.Health > 0
	snapshot.characterId = tostring(self.characterVersion)
	snapshot.position = if root
		then { x = root.Position.X, y = root.Position.Y, z = root.Position.Z }
		else { x = 0, y = 0, z = 0 }
	return snapshot
end

function Adapter:attack(kind, id, runId)
	local snapshot = self:snapshot()
	if not snapshot.ready or not snapshot.characterReady or snapshot.runId ~= runId then
		return false, "Run or character changed"
	end
	local found = false
	for _, target in (if kind == "NPC" then snapshot.npcs else snapshot.rubble) do
		if target.id == id and target.alive and target.health > 0 and target.area == snapshot.area then
			found = true
		end
	end
	if not found then
		return false, "Target disappeared"
	end
	local _, remote = self:_references()
	if not remote then
		return false, "Demo action channel unavailable"
	end
	remote:FireServer(kind, id, runId)
	return true
end

function Adapter:cancelCombat() end -- Demo attacks are single requests, no background loop.

function Adapter:requestReplay(runId)
	local _, remote = self:_references()
	if not remote then
		return false, "Demo replay channel unavailable"
	end
	remote:FireServer("Replay", "", runId)
	return true
end

function Adapter:loadPreferences()
	local folder = self:_references()
	local saved = folder and folder:GetAttribute("Preferences")
	return if saved then HttpService:JSONDecode(saved) else nil
end

function Adapter:savePreferences(preferences)
	local folder, remote = self:_references()
	if not folder or not remote then
		return false, "Demo preference channel unavailable"
	end
	remote:FireServer("SavePreferences", HttpService:JSONEncode(preferences))
	return true, "Save requested · retained for this Studio server session"
end

function Adapter:destroy() end

return Adapter
