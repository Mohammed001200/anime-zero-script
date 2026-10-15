-- Controlled Studio-only fixture. Nothing in this file is an Anime Zero API.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local root = Instance.new("Folder")
root.Name = "MA_StudioDemo"
root.Parent = ReplicatedStorage
local action = Instance.new("RemoteEvent")
action.Name, action.Parent = "Action", root
local sessions, laneCounter = {}, 0

local function part(parent, name, position, size, color)
	local instance = Instance.new("Part")
	instance.Name, instance.Anchored = name, true
	instance.Position, instance.Size, instance.Color = position, size, color
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	instance.Parent = parent
	return instance
end

local function label(instance, text)
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.StudsOffset, gui.AlwaysOnTop = UDim2.fromOffset(180, 44), Vector3.new(0, 5, 0), true
	gui.Parent = instance
	local title = Instance.new("TextLabel")
	title.Size, title.BackgroundTransparency, title.Text = UDim2.fromScale(1, 1), 1, text
	title.Font, title.TextSize, title.TextColor3 = Enum.Font.GothamBold, 17, Color3.new(1, 1, 1)
	title.Parent = gui
	return title
end

local function point(position)
	return { x = position.X, y = position.Y, z = position.Z }
end

local function publish(session)
	local state = {
		ready = true,
		dungeonId = session.dungeonId,
		runId = session.runId,
		area = session.area,
		totalAreas = 5,
		completed = session.completed,
		areaCleared = session.cleared,
		spawnPending = session.pending,
		npcs = {},
		rubble = {},
	}
	for _, target in session.targets do
		local item = {
			id = target.id,
			name = target.name,
			dungeonId = session.dungeonId,
			runId = session.runId,
			area = target.area,
			position = point(target.part.Position),
			health = target.health,
			alive = target.health > 0,
		}
		table.insert(if target.kind == "NPC" then state.npcs else state.rubble, item)
	end
	if session.cleared and session.area < 5 then
		local blocked = false
		for _, target in session.targets do
			if target.kind == "Rubble" and target.health > 0 then
				blocked = true
			end
		end
		if not blocked then
			state.nextEntrance = {
				id = "entrance-" .. (session.area + 1),
				dungeonId = session.dungeonId,
				runId = session.runId,
				area = session.area + 1,
				position = point(Vector3.new((session.area - 1) * 80 + 64, 3, session.lane)),
			}
		end
	end
	session.packet = state
	session.folder:SetAttribute("Snapshot", HttpService:JSONEncode(state))
end

local function startArea(session, area)
	session.area, session.cleared, session.pending, session.completed = area, false, true, false
	for _, target in session.targets do
		target.part:Destroy()
	end
	session.targets = {}
	publish(session)
	local runId = session.runId
	task.delay(2, function()
		if sessions[session.player] ~= session or session.runId ~= runId or session.area ~= area then
			return
		end
		local function target(kind, index, position, health)
			local id = kind .. "-" .. area .. "-" .. index
			local object = part(
				session.world,
				id,
				position,
				if kind == "NPC" then Vector3.new(3, 5, 3) else Vector3.new(3, 12, 36),
				if kind == "NPC" then Color3.fromRGB(173, 100, 255) else Color3.fromRGB(71, 90, 110)
			)
			if kind == "NPC" then
				object.CanCollide = false
			end
			local title = label(object, if kind == "NPC" then "TRAINING NPC" else "RUBBLE [BREAK IT]")
			session.targets[id] = {
				id = id,
				name = if kind == "NPC" then "Training NPC " .. index else "Rubble barrier",
				area = area,
				part = object,
				health = health,
				kind = kind,
				title = title,
			}
		end
		for index = 1, 3 do
			target(
				"NPC",
				index,
				Vector3.new((area - 1) * 80 + 12 + index * 7, 3, session.lane + (index - 2) * 9),
				60
			)
		end
		if area < 5 then
			target("Rubble", 1, Vector3.new((area - 1) * 80 + 47, 5, session.lane), 100)
		end
		session.pending = false
		publish(session)
	end)
end

local function addPlayer(player)
	laneCounter += 1
	local lane = laneCounter * 80
	local folder, world = Instance.new("Folder"), Instance.new("Folder")
	folder.Name, folder.Parent = tostring(player.UserId), root
	world.Name, world.Parent = "MA_Demo_" .. player.UserId, workspace
	part(world, "Floor", Vector3.new(185, -1, lane), Vector3.new(430, 2, 50), Color3.fromRGB(20, 26, 38))
	for area = 1, 5 do
		local marker = part(
			world,
			"AreaMarker",
			Vector3.new((area - 1) * 80, 0.1, lane),
			Vector3.new(4, 0.2, 46),
			Color3.fromRGB(50, 221, 235)
		)
		marker.CanCollide = false
		label(marker, "AREA " .. area .. " / 5")
	end
	local session = {
		player = player,
		folder = folder,
		world = world,
		lane = lane,
		dungeonId = "studio-" .. player.UserId,
		runId = HttpService:GenerateGUID(false),
		targets = {},
		lastAttack = -math.huge,
		lastPreferenceSave = -math.huge,
	}
	sessions[player] = session
	session.characterConnection = player.CharacterAdded:Connect(function(character)
		task.spawn(function()
			local rootPart = character:WaitForChild("HumanoidRootPart", 10)
			if not rootPart or sessions[player] ~= session or player.Character ~= character then
				return
			end
			character:PivotTo(CFrame.new((session.area - 1) * 80, 4, lane))
		end)
	end)
	startArea(session, 1)
	if player.Character then
		player.Character:PivotTo(CFrame.new(0, 4, lane))
	end
end

action.OnServerEvent:Connect(function(player, operation, id, runId)
	local session = sessions[player]
	if not session then
		return
	end
	local now = os.clock()
	if operation == "SavePreferences" then
		if now - session.lastPreferenceSave < 0.5 then
			return
		end
		session.lastPreferenceSave = now
		-- Demo preference lifetime is this server session, with a strict payload bound.
		if type(id) ~= "string" or #id > 4096 then
			return
		end
		local ok, data = pcall(HttpService.JSONDecode, HttpService, id)
		if ok and type(data) == "table" and data.version == 1 and type(data.values) == "table" then
			session.folder:SetAttribute("Preferences", id)
		end
		return
	end
	if runId ~= session.runId then
		return
	end
	if operation == "Replay" then
		-- Completion/run checks, rather than the combat throttle, gate replay.
		-- The last killing hit must not suppress the first replay request.
		if not session.completed then
			return
		end
		session.runId = HttpService:GenerateGUID(false)
		startArea(session, 1)
		if player.Character then
			player.Character:PivotTo(CFrame.new(0, 4, session.lane))
		end
		return
	end
	if operation ~= "NPC" and operation ~= "Rubble" then
		return
	end
	if type(id) ~= "string" or now - session.lastAttack < 0.3 then
		return
	end
	local target = session.targets[id]
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not target
		or target.kind ~= operation
		or target.health <= 0
		or target.area ~= session.area
		or not rootPart
		or not humanoid
		or humanoid.Health <= 0
		or (rootPart.Position - target.part.Position).Magnitude > 9
	then
		return
	end
	if operation == "Rubble" and not session.cleared then
		return
	end
	session.lastAttack = now
	target.health = math.max(0, target.health - (if operation == "NPC" then 20 else 25))
	target.title.Text = target.name .. " · " .. target.health .. " HP"
	if target.health == 0 then
		target.part.Transparency, target.part.CanCollide = 1, false
		target.title.Text = "CLEARED"
	end
	local remaining = 0
	for _, other in session.targets do
		if other.kind == "NPC" and other.health > 0 then
			remaining += 1
		end
	end
	session.cleared = not session.pending and remaining == 0
	if session.cleared and session.area == 5 then
		session.completed = true
	end
	publish(session)
end)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.15 then
		return
	end
	elapsed = 0
	for player, session in sessions do
		local entrance = session.packet and session.packet.nextEntrance
		local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if
			entrance
			and rootPart
			and (rootPart.Position - Vector3.new(
					entrance.position.x,
					entrance.position.y,
					entrance.position.z
				)).Magnitude
				<= 6
		then
			startArea(session, session.area + 1)
		end
	end
end)

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	session.characterConnection:Disconnect()
	session.folder:Destroy()
	session.world:Destroy()
end)
for _, player in Players:GetPlayers() do
	addPlayer(player)
end
