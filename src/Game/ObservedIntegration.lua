-- Opt-in controller startup, using paths observed in the user's recordings.
-- This is a client observation/input trial, not a developer-provided combat API.
local M1Input = require(if script then script.Parent.M1Input else "./M1Input")
local Integration = {}

local function child(parent, ...)
	for _, name in { ... } do
		parent = parent and parent:FindFirstChild(name)
	end
	return parent
end

local function point(position)
	return { x = position.X, y = position.Y, z = position.Z }
end

local function visible(instance)
	if not instance then
		return false
	end
	while instance do
		if instance:IsA("GuiObject") and not instance.Visible then
			return false
		elseif instance:IsA("ScreenGui") and not instance.Enabled then
			return false
		end
		instance = instance.Parent
	end
	return true
end

local function text(instance)
	if instance and (instance:IsA("TextLabel") or instance:IsA("TextButton")) then
		return instance.Text:gsub("<[^>]*>", "")
	end
	return ""
end

local function readRubble(instance)
	local value = instance:GetAttribute("RubbleHealth")
	if type(value) ~= "number" then
		local healthValue = instance:FindFirstChild("RubbleHealth", true)
		if healthValue and (healthValue:IsA("NumberValue") or healthValue:IsA("IntValue")) then
			value = healthValue.Value
		end
	end
	if type(value) ~= "number" then
		-- Recorder labels a descendant's HP with its enclosing Border path.
		-- Read only the exact observed attribute name, with a bounded walk.
		local queue, index, found = { instance }, 1, nil
		while index <= #queue and index <= 256 do
			local candidate = queue[index]:GetAttribute("RubbleHealth")
			if type(candidate) == "number" then
				if found ~= nil and found ~= candidate then
					return nil -- Conflicting sources are not a usable health binding.
				end
				found = candidate
			end
			for _, descendant in queue[index]:GetChildren() do
				if #queue >= 256 then
					return nil
				end
				table.insert(queue, descendant)
			end
			index += 1
		end
		value = found
	end
	if type(value) == "number" and value == value and math.abs(value) < math.huge then
		return value
	end
	return nil
end

local function rubblePoint(instance, origin)
	local frame, size
	if instance:IsA("BasePart") then
		frame, size = instance.CFrame, instance.Size
	elseif instance:IsA("Model") and instance:FindFirstChildWhichIsA("BasePart", true) then
		frame, size = instance:GetBoundingBox()
	else
		return nil
	end
	-- Approach the nearest surface, rather than the center of a wide solid wall.
	local localPosition = frame:PointToObjectSpace(origin)
	local closest = Vector3.new(
		math.clamp(localPosition.X, -size.X / 2, size.X / 2),
		math.clamp(localPosition.Y, -size.Y / 2, size.Y / 2),
		math.clamp(localPosition.Z, -size.Z / 2, size.Z / 2)
	)
	return frame:PointToWorldSpace(closest)
end

function Integration.new(options)
	local player, workspace = options.player, options.workspace
	local inputService, guiService = options.inputService, options.guiService
	local run = 1
	local wasCompleted = false
	local identities, serial = setmetatable({}, { __mode = "k" }), 0
	local targets = {}
	local connections = {}
	local destroyed = false
	local currentArea
	local heldTarget
	local attackRange = 8
	local input

	local function identity(instance)
		if not identities[instance] then
			serial += 1
			identities[instance] = "observed-" .. serial
		end
		return identities[instance]
	end

	local function guard(held)
		if destroyed then
			return false, "Input integration unloaded"
		end
		if guiService.MenuIsOpen or inputService:GetFocusedTextBox() then
			return false, "Paused: close the Roblox menu or text field"
		end
		local playerGui = player:FindFirstChild("PlayerGui")
		if not playerGui then
			return false, "Paused: PlayerGui is unavailable"
		end
		local mouse = inputService:GetMouseLocation()
		for _, object in playerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y) do
			if visible(object) then
				local ancestor = object
				while ancestor and ancestor ~= playerGui do
					if ancestor.Name == "MohammadAndAli" or ancestor.Name == "EndScreen" then
						return false,
							"Paused: move the pointer off the script/result window into the game view"
					end
					ancestor = ancestor.Parent
				end
				if object:IsA("GuiButton") or object:IsA("TextBox") then
					return false, "Paused: move the pointer off interactive UI into the game view"
				end
			end
		end
		if not held and inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			return false, "Paused: release your physical left mouse button before automatic M1"
		end
		return true
	end

	input = M1Input.new(options.input, guard, options.clock)

	local function cancel()
		heldTarget = nil
		input:Release()
	end

	local function snapshot()
		local safe, reason = input:Safe()
		if not safe then
			cancel()
		end
		local playerGui = player:FindFirstChild("PlayerGui")
		local counter = child(playerGui, "RoundHUD", "Container", "TopPart", "RemainingFrame", "EnemyCount")
		local info = child(playerGui, "RunManage", "Sheet", "Title", "Info")
		local result = child(playerGui, "EndScreen", "Holder", "ConstraintedHolder", "ResultText")
		local completed = visible(result) and text(result):match("VICTORY!") ~= nil
		-- A result overlay may block the pointer; still report victory to Stop.
		if not safe and not completed then
			return {
				ready = false,
				paused = input.fault == nil,
				blocked = input.fault ~= nil,
				reason = reason,
			}
		end
		if completed then
			cancel()
		end
		local counterText = if visible(counter) or completed then text(counter) else ""
		local area, total = counterText:match("Area%s+(%d+)%s*/%s*(%d+)")
		local entering = counterText:match("[Ee]nter area%s+(%d+)%s*/")
		local remaining = tonumber(counterText:match("(%d+)%s+left"))
		area, total = tonumber(area), tonumber(total)
		if area then
			currentArea = area
		elseif entering then
			currentArea = tonumber(entering) - 1
		elseif not currentArea and visible(info) then
			-- The recording shows this label advances before physical area entry.
			-- Use it only as an initial hint; it never supplies a checkpoint position.
			currentArea = tonumber(text(info):match("Area%s+(%d+)"))
		end
		if not currentArea or currentArea < 1 or currentArea > 5 or (total and total ~= 5) then
			return { ready = false, reason = "Waiting for the observed five-area dungeon HUD" }
		end
		if wasCompleted and not completed and currentArea == 1 then
			run += 1
			wasCompleted = false
		end
		if completed then
			wasCompleted = true
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local ready = root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0
		local state = {
			ready = true,
			source = "client-observation",
			dungeonId = "observed-place-" .. tostring(options.placeId),
			runId = "client-run-" .. run,
			area = currentArea,
			totalAreas = 5,
			completed = completed,
			areaCleared = false,
			spawnPending = true,
			characterReady = ready,
			characterId = if character then identity(character) else "unavailable",
			position = if ready then point(root.Position) else nil,
			npcs = {},
			rubble = {},
		}
		table.clear(targets)
		local folder = child(workspace, "enemies")
		if ready and folder and (folder:IsA("Folder") or folder:IsA("Model")) then
			local children = folder:GetChildren()
			if #children > 1000 then
				return {
					ready = false,
					blocked = true,
					reason = "Enemy folder exceeds the 1,000-object scan limit",
				}
			end
			for _, model in children do
				if not model:IsA("Model") then
					continue
				end
				local npcHumanoid = model:FindFirstChildOfClass("Humanoid")
				local npcRoot = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
				if npcHumanoid and npcHumanoid.Health > 0 and npcRoot and npcRoot:IsA("BasePart") then
					local id = identity(model)
					targets[id] = { instance = model, folder = folder, root = npcRoot, kind = "NPC" }
					table.insert(state.npcs, {
						id = id,
						name = model.Name .. " (HP unknown)",
						dungeonId = state.dungeonId,
						runId = state.runId,
						area = currentArea,
						position = point(npcRoot.Position),
						alive = true,
						healthKnown = false,
						observedPresence = true,
					})
				end
			end
		end
		local border = child(workspace, "World", "Map", "Border" .. currentArea)
		if ready and border then
			local health = readRubble(border)
			local position = rubblePoint(border, root.Position)
			if health and health > 0 and position then
				local id = identity(border)
				targets[id] = { instance = border, root = border, kind = "Rubble" }
				table.insert(state.rubble, {
					id = id,
					name = border.Name,
					dungeonId = state.dungeonId,
					runId = state.runId,
					area = currentArea,
					position = point(position),
					health = health,
					alive = true,
				})
				-- Require an observed barrier with HP; an empty enemy list alone is insufficient.
				state.areaCleared = #state.npcs == 0 and remaining == 0
				if #state.npcs == 0 and not state.areaCleared then
					state.waitReason = border.Name
						.. " has HP, but the HUD has not confirmed zero remaining enemies"
				end
				-- Some recorded HUD counters remain stale at 1 after the final wave.
				-- Those snapshots wait for clear confirmation, rather than guessing.
			elseif health == nil then
				state.waitReason = border.Name
					.. " has no unambiguous accessible RubbleHealth attribute/number value"
			end
		end
		if entering then
			state.areaCleared, state.spawnPending = true, false
			state.objectiveReason = "Checkpoint crossing is unverified. Enter Area "
				.. entering
				.. " manually; farming resumes after entry."
			state.manualObjective = true
		else
			state.spawnPending = not state.areaCleared and #state.npcs == 0
			if not folder then
				state.waitReason =
					"Waiting for observed Workspace.enemies; missing/streamed objects do not prove clear"
			end
		end
		if heldTarget and not targets[heldTarget] then
			cancel()
		end
		return state
	end

	local function attack(id, runId)
		if runId ~= "client-run-" .. run then
			cancel()
			return false, "Observed run changed"
		end
		local target = targets[id]
		if not target or not target.instance.Parent then
			cancel()
			return false, "Target is no longer observed; disappearance does not prove death"
		end
		if target.kind == "NPC" and (target.instance.Parent ~= target.folder or not target.root.Parent) then
			cancel()
			return false, "Enemy left the observed enemy folder"
		end
		if target.kind == "Rubble" and (readRubble(target.instance) or 0) <= 0 then
			cancel()
			return false, "Rubble health is unavailable or no longer positive"
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local destination = if target.kind == "NPC"
			then target.root.Position
			else root and rubblePoint(target.instance, root.Position)
		if
			not root
			or not humanoid
			or humanoid.Health <= 0
			or not destination
			or not ((destination - root.Position).Magnitude <= attackRange)
		then
			cancel()
			return false, "Character/target changed or moved outside the selected attack range"
		end
		if heldTarget ~= id then
			cancel()
		end
		heldTarget = id
		return input:Hold()
	end

	-- Independent lease watchdog releases M1 even if the controller stops refreshing it.
	table.insert(
		connections,
		options.heartbeat:Connect(function()
			input:Poll()
		end)
	)
	for _, signal in { inputService.WindowFocusReleased, inputService.TextBoxFocused, guiService.MenuOpened } do
		table.insert(connections, signal:Connect(cancel))
	end

	return {
		inputTrial = true,
		preflight = function(config)
			attackRange = config.attackRange
			local available, reason = input:Available()
			if not available then
				return false, reason
			end
			if config.targetingMode == "LowestHealth" then
				return false, "Enemy HP is unverified. Select Nearest targeting for the input trial."
			end
			if config.attackInterval > 1 then
				return false, "Input trial requires Attack interval <= 1 second to renew the M1 safety lease"
			end
			return true
		end,
		integrationStatus = function()
			local available, reason = input:Available()
			return {
				configured = false,
				missing = { "enemy health/death confirmation", "nextEntrance", "requestReplay" },
				summary = if available
					then "INPUT TRIAL: observed enemy models + normal M1. HP unknown; bounded target timeout. Live damage is not verified."
					else reason,
				replay = "Auto Retry and checkpoint crossing remain unavailable; enter checkpoints and Retry manually.",
			}
		end,
		snapshot = snapshot,
		attack = attack,
		breakRubble = attack,
		cancelCombat = cancel,
		destroy = function()
			destroyed = true
			cancel()
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
			table.clear(targets)
		end,
	}
end

return Integration
