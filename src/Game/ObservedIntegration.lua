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

local function readNumber(instance, attributeName)
	local value = instance:GetAttribute(attributeName)
	if type(value) ~= "number" then
		local healthValue = instance:FindFirstChild(attributeName, true)
		if healthValue and (healthValue:IsA("NumberValue") or healthValue:IsA("IntValue")) then
			value = healthValue.Value
		end
	end
	if type(value) ~= "number" then
		-- Recorder labels a descendant's HP with its enclosing Border path.
		-- Read only the exact observed attribute name, with a bounded walk.
		local queue, index, found = { instance }, 1, nil
		while index <= #queue and index <= 256 do
			local candidate = queue[index]:GetAttribute(attributeName)
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

local function readRubble(instance)
	local health = readNumber(instance, "RubbleHealth")
	local maximum = readNumber(instance, "RubbleMaxHealth")
	if
		health ~= nil
		and (
			health < 0
			or (maximum ~= nil and (maximum < 0 or (health > 0 and maximum == 0) or health > maximum))
		)
	then
		return nil, maximum, "RubbleHealth/RubbleMaxHealth values are inconsistent"
	end
	return health, maximum
end

local function under(instance, parent)
	for _ = 1, 32 do
		if not instance then
			return false
		end
		if instance == parent then
			return true
		end
		instance = instance.Parent
	end
	return false
end

local function areaNumber(value)
	return tonumber(value:lower():match("area%s*[:%-]?%s*(%d+)"))
end

local function bounds(instance)
	local frame, size
	if instance:IsA("BasePart") then
		frame, size = instance.CFrame, instance.Size
	elseif instance:IsA("Model") and instance:FindFirstChildWhichIsA("BasePart", true) then
		frame, size = instance:GetBoundingBox()
	else
		return nil
	end
	return frame, size
end

local function crossingPoint(instance, origin)
	local frame, size = bounds(instance)
	if not frame then
		return nil, "No readable border geometry"
	end
	local alongX = size.X < size.Z
	local thickness = if alongX then size.X else size.Z
	local span = if alongX then size.Z else size.X
	if math.abs(frame.UpVector.Y) < 0.98 or thickness > 12 or span < math.max(6, thickness * 2) then
		return nil, "Border geometry does not identify a simple upright opening"
	end
	local localOrigin = frame:PointToObjectSpace(origin)
	local side = if alongX then localOrigin.X else localOrigin.Z
	if math.abs(side) <= thickness / 2 + 0.1 then
		return nil, "Border approach side is unclear"
	end
	local across = -math.sign(side) * (thickness / 2 + 8)
	local lateral = math.clamp(if alongX then localOrigin.Z else localOrigin.X, -span / 2 + 3, span / 2 - 3)
	local destination = frame:PointToWorldSpace(
		if alongX
			then Vector3.new(across, localOrigin.Y, lateral)
			else Vector3.new(lateral, localOrigin.Y, across)
	)
	-- This is an ordinary walk attempt through the observed opening. No
	-- checkpoint object/API or teleport is assumed; HUD entry must confirm it.
	return { x = destination.X, y = origin.Y, z = destination.Z }
end

local function rubblePoint(instance, origin)
	local frame, size = bounds(instance)
	if not frame then
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
	local clock = options.clock or os.clock
	local gates = {}
	local waveScope, sawFinalWaveEnemy, emptySince

	local function identity(instance)
		if not identities[instance] then
			serial += 1
			identities[instance] = "observed-" .. serial
		end
		return identities[instance]
	end
	local function playerCharacter(model)
		return model == player.Character
			or (options.players and options.players:GetPlayerFromCharacter(model) ~= nil)
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
		local side = child(playerGui, "RunSide", "Container", "Title")
		local objective = child(playerGui, "RoundHUD", "WaveTemplate", "Title")
		local nextArea = child(playerGui, "NextAreaChip", "Frame", "Title")
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
		local sideText = if visible(side) then text(side) else ""
		local objectiveText = if visible(objective) then text(objective) else ""
		local nextText = if visible(nextArea) then text(nextArea) else ""
		local counterEntering = counterText:lower():match("enter%s+area%s*[:%-]?%s*(%d+)")
		local objectiveEntering = objectiveText:lower():match("enter%s+area%s*[:%-]?%s*(%d+)")
		if counterEntering and objectiveEntering and counterEntering ~= objectiveEntering then
			return {
				ready = false,
				reason = "Next-area objective labels disagree; waiting for consistent HUD",
			}
		end
		local entering = counterEntering or objectiveEntering
		local area, total = counterText:lower():match("area%s+(%d+)%s*/%s*(%d+)")
		if counterEntering then
			area = nil
		end
		local remaining = tonumber(counterText:match("(%d+)%s+left"))
		area, total = tonumber(area), tonumber(total)
		if area and entering and tonumber(entering) <= area then
			entering = nil
		end
		if entering and (tonumber(entering) < 2 or tonumber(entering) > 5) then
			return { ready = false, reason = "Unrecognized next-area objective; waiting for consistent HUD" }
		end
		if area then
			currentArea = area
		elseif entering then
			currentArea = tonumber(entering) - 1
		elseif not currentArea and areaNumber(sideText) then
			currentArea = areaNumber(sideText)
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
			table.clear(gates)
			waveScope, sawFinalWaveEnemy, emptySince = nil, false, nil
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
			observedHUD = {
				counter = counterText,
				side = sideText,
				objective = objectiveText,
				nextArea = nextText,
			},
			npcs = {},
			rubble = {},
		}
		table.clear(targets)
		local folder = child(workspace, "enemies")
		local collectionReady = folder and (folder:IsA("Folder") or folder:IsA("Model"))
		if ready and collectionReady then
			local children = folder:GetChildren()
			if #children > 1000 then
				return {
					ready = false,
					blocked = true,
					reason = "Enemy folder exceeds the 1,000-object scan limit",
				}
			end
			for _, model in children do
				if not model:IsA("Model") or playerCharacter(model) then
					continue
				end
				local npcHumanoid = model:FindFirstChildOfClass("Humanoid")
				local npcRoot = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
				if
					npcHumanoid
					and npcHumanoid.Health > 0
					and npcRoot
					and npcRoot:IsA("BasePart")
					and under(npcRoot, model)
				then
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
		local infoText = text(info)
		local infoArea = tonumber(infoText:match("Area%s+(%d+)"))
		local wave, waves = (objectiveText .. " " .. sideText):match("[Ww]ave%s+(%d+)%s*/%s*(%d+)")
		-- Objective and side labels are supplied live observations. Neither is
		-- interpreted as a world-space checkpoint or an attack API.
		if wave then
			infoArea = currentArea
		else
			wave, waves = infoText:match("[Ww]ave%s+(%d+)%s*/%s*(%d+)")
		end
		wave, waves = tonumber(wave), tonumber(waves)
		local finalWave = infoArea == currentArea and wave ~= nil and wave == waves
		local moreWaves = infoArea == currentArea and wave ~= nil and waves ~= nil and wave < waves
		local nextScope = tostring(run)
			.. "/"
			.. currentArea
			.. "/"
			.. tostring(wave)
			.. "/"
			.. tostring(waves)
			.. "/"
			.. (if folder then identity(folder) else "missing")
		if waveScope ~= nextScope then
			waveScope, sawFinalWaveEnemy, emptySince = nextScope, false, nil
		end
		if #state.npcs > 0 then
			sawFinalWaveEnemy = sawFinalWaveEnemy or finalWave
			emptySince = nil
		elseif ready and collectionReady then
			emptySince = emptySince or clock()
		end
		local stableFinalClear = finalWave
			and sawFinalWaveEnemy
			and emptySince ~= nil
			and clock() - emptySince >= 0.25
		local rubbleInstruction = (counterText .. " " .. objectiveText):lower():find("rubble", 1, true) ~= nil
		local border = child(workspace, "World", "Map", "Border" .. currentArea)
		if ready and border then
			local health, maxHealth, healthProblem = readRubble(border)
			local position = rubblePoint(border, root.Position)
			if health ~= nil then
				local gate = gates[currentArea]
				if not gate or gate.instance ~= border or (gate.health == 0 and health > 0) then
					gate = { id = identity(border) .. "-opening", instance = border }
					gates[currentArea] = gate
				end
				if not gate.routeAttempted then
					gate.route, gate.problem = crossingPoint(border, root.Position)
					gate.routeAttempted = true
				end
				gate.health = health
				if health == 0 then
					gate.destroyed = true
				end
			end
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
					maxHealth = maxHealth,
					alive = true,
				})
				-- A stale counter was blocking the rubble transition. Require positive
				-- current-area border HP plus observed phase evidence, never absence alone.
				state.areaCleared = ready
					and collectionReady == true
					and #state.npcs == 0
					and (rubbleInstruction or stableFinalClear or (remaining == 0 and not moreWaves))
				if #state.npcs == 0 and not state.areaCleared then
					state.waitReason = border.Name
						.. " has HP; waiting for rubble/final-wave clearance. Objective: "
						.. objectiveText:sub(1, 100)
				end
			elseif health and health > 0 then
				state.waitReason = border.Name
					.. " has HP but no usable Part/Model bounds; capture its class and geometry"
			elseif health == nil then
				state.waitReason = healthProblem
					or (border.Name .. " has no unambiguous accessible RubbleHealth attribute/number value")
			end
		end
		local gate = gates[currentArea]
		local chipArea = areaNumber(nextText)
		if not entering and gate and gate.destroyed and chipArea == currentArea + 1 then
			entering = tostring(chipArea)
		end
		if entering then
			state.areaCleared, state.spawnPending = true, false
			local gate = gates[currentArea]
			if gate and not border then
				gate.destroyed = true
			end
			if tonumber(entering) == currentArea + 1 and gate and gate.destroyed and gate.route then
				state.nextEntrance = {
					id = gate.id,
					name = "Walk through Border" .. currentArea .. " opening",
					dungeonId = state.dungeonId,
					runId = state.runId,
					area = currentArea + 1,
					position = gate.route,
				}
			else
				state.objectiveReason = "Enter Area "
					.. entering
					.. " manually: "
					.. (gate and gate.problem or "no readable, confirmed broken-border route")
				state.manualObjective = true
			end
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
		if
			target.kind == "NPC"
			and (
				target.instance.Parent ~= target.folder
				or child(workspace, "enemies") ~= target.folder
				or not under(target.root, target.instance)
				or playerCharacter(target.instance)
			)
		then
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
			local configured, problem = input:Configure(config.m1Mode, config.m1PulseInterval)
			if not configured then
				return false, problem
			end
			return true
		end,
		integrationStatus = function()
			local available, reason = input:Available()
			return {
				configured = false,
				missing = {
					"enemy health/death confirmation",
					"verified checkpoint traversal",
					"requestReplay",
				},
				summary = if available
					then "Normal M1 farming was user-confirmed in 1.2. New rubble, opening-walk and Pulse changes need live tests. Enemy HP remains unknown."
					else reason,
				replay = "Broken-border walking requires live validation; unsupported geometry pauses. Auto Retry remains manual.",
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
