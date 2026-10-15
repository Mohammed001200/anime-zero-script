-- Read-only observations. Candidates never become automation bindings automatically.
-- No remote calls, source reads, input simulation, prompt triggering or damage writes.
local Diagnostics = {}
Diagnostics.__index = Diagnostics
local hints = {
	"area",
	"dungeon",
	"wave",
	"stage",
	"rubble",
	"debris",
	"barrier",
	"checkpoint",
	"entrance",
	"complete",
	"retry",
	"replay",
	"break",
	"health",
	"progress",
	"runid",
	"victory",
	"success",
	"cleared",
	"spawn",
	"hp",
	"hitpoint",
	"zone",
	"level",
	"round",
	"alive",
}
local obstacleHints = { "rubble", "debris", "barrier", "checkpoint", "entrance", "gate" }

local function clean(value, limit)
	return string.sub(tostring(value):gsub("[%c]", " "), 1, limit or 180)
end

local function matches(value, words)
	value = string.lower(tostring(value))
	for _, word in words or hints do
		if string.find(value, word, 1, true) then
			return true
		end
	end
	return false
end

local function path(instance)
	local ok, result = pcall(function()
		return instance:GetFullName()
	end)
	return clean(if ok then result else instance.Name, 240)
end

local function primitive(value)
	local kind = type(value)
	if kind == "boolean" then
		return value
	end
	if kind == "number" and value == value and math.abs(value) < math.huge then
		return value
	end
	if kind == "string" then
		return clean(value, 100)
	end
	return nil
end

local function attributes(instance)
	local result, count = {}, 0
	local values = instance:GetAttributes()
	local keys = {}
	for key in values do
		if matches(key) then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	for _, key in keys do
		local value = primitive(values[key])
		if value ~= nil and count < 12 then
			result[clean(key, 80)] = value
			count += 1
		end
	end
	return result
end

local function position(instance)
	local part = if instance:IsA("BasePart")
		then instance
		elseif instance:IsA("Model") then instance.PrimaryPart or instance:FindFirstChild(
			"HumanoidRootPart"
		) or instance:FindFirstChildWhichIsA("BasePart")
		else nil
	if part and part:IsA("BasePart") then
		local p = part.Position
		return { x = math.round(p.X * 10) / 10, y = math.round(p.Y * 10) / 10, z = math.round(p.Z * 10) / 10 },
			part
	end
	return nil
end

function Diagnostics.new(player, services)
	services = services
		or {
			game = game,
			workspace = game:GetService("Workspace"),
			players = game:GetService("Players"),
			replicatedStorage = game:GetService("ReplicatedStorage"),
			collection = game:GetService("CollectionService"),
		}
	return setmetatable({
		player = player,
		services = services,
		generation = 0,
		clock = services.clock or os.clock,
		yield = services.yield or function()
			task.wait()
		end,
	}, Diagnostics)
end

function Diagnostics:Cancel()
	self.generation += 1
end

function Diagnostics:Destroy()
	self:Cancel()
end

function Diagnostics:Collect(phase, adapter, ownedGui, limits)
	self:Cancel()
	local generation, started = self.generation, self.clock()
	limits = limits or {}
	local maxNodes = math.clamp(limits.maxNodes or 4000, 1, 12000)
	local maxSeconds = math.clamp(limits.maxSeconds or 3, 0.1, 8)
	local services = self.services
	local report = {
		version = 1,
		phase = clean(phase or "Unlabelled observation"),
		placeId = services.game.PlaceId,
		gameId = services.game.GameId,
		visited = 0,
		truncated = false,
		scanErrors = 0,
		errors = {},
		evidenceOnly = true,
		nonAtomic = true,
		npcs = {},
		objectives = {},
		interactions = {},
		tools = {},
		state = {},
		ui = {},
		adapter = if adapter.integrationStatus
			then adapter:integrationStatus().summary
			else "Adapter has no live binding report",
	}
	local caps = { npcs = 36, objectives = 24, interactions = 28, tools = 12, state = 36, ui = 36 }
	local function add(group, item)
		if group == "npcs" then
			table.insert(report.npcs, item)
			table.sort(report.npcs, function(a, b)
				return (a.distance or math.huge) < (b.distance or math.huge)
			end)
			if #report.npcs > caps.npcs then
				table.remove(report.npcs)
				report.truncated = true
			end
			return
		end
		if #report[group] < caps[group] then
			table.insert(report[group], item)
		else
			report.truncated = true
		end
	end
	local excluded = {}
	for _, player in services.players:GetPlayers() do
		if player.Character then
			excluded[player.Character] = true
		end
	end
	if ownedGui then
		excluded[ownedGui] = true
	end
	local function tool(instance)
		add("tools", {
			path = path(instance),
			enabled = instance.Enabled,
			requiresHandle = instance.RequiresHandle,
			equipped = instance.Parent == self.player.Character,
			manualActivationOnly = instance.ManualActivationOnly,
			attributes = attributes(instance),
		})
	end
	local character = self.player.Character
	if character then
		local ok, characterPosition = pcall(position, character)
		if ok then
			report.characterPosition = characterPosition
		end
		for index, child in character:GetChildren() do
			if index > 64 then
				report.truncated = true
				break
			end
			if child:IsA("Tool") then
				tool(child)
			end
		end
	end
	local queue, seen, index = {}, {}, 1
	for _, root in
		{
			self.player:FindFirstChild("PlayerGui"),
			services.workspace,
			services.replicatedStorage,
			self.player:FindFirstChild("Backpack"),
		}
	do
		if root then
			table.insert(queue, root)
		end
	end
	while index <= #queue and report.visited < maxNodes do
		if generation ~= self.generation then
			return nil, "Capture cancelled"
		end
		if self.clock() - started >= maxSeconds then
			report.truncated = true
			break
		end
		local node = queue[index]
		index += 1
		if seen[node] or excluded[node] then
			continue
		end
		seen[node] = true
		report.visited += 1
		local ok, err = pcall(function()
			local attrs = attributes(node)
			local tags = services.collection:GetTags(node)
			local limitedTags = {}
			for tagIndex, tag in tags do
				if tagIndex <= 8 then
					table.insert(limitedTags, clean(tag, 80))
				end
			end
			local metadata =
				{ path = path(node), class = node.ClassName, attributes = attrs, tags = limitedTags }
			if next(attrs) ~= nil then
				add("state", metadata)
			end
			if node:IsA("ValueBase") and matches(node.Name) then
				local value = primitive(node.Value)
				if value ~= nil then
					add("state", { path = path(node), value = value })
				end
			end
			if node:IsA("Model") then
				local humanoid = node:FindFirstChildOfClass("Humanoid")
				if humanoid then
					local p, rootPart = position(node)
					local record = table.clone(metadata)
					record.health, record.maxHealth = humanoid.Health, humanoid.MaxHealth
					record.alive = humanoid.Health > 0
					record.position, record.root =
						p, if rootPart then path(rootPart) else "No root part observed"
					record.scope = "UNKNOWN: dungeon/run/area membership not established"
					if p and report.characterPosition then
						local origin = report.characterPosition
						record.distance = math.round(
							math.sqrt((p.x - origin.x) ^ 2 + (p.y - origin.y) ^ 2 + (p.z - origin.z) ^ 2) * 10
						) / 10
					end
					add("npcs", record)
				end
			end
			if
				(node:IsA("Model") or node:IsA("BasePart"))
				and (
					matches(node.Name, obstacleHints)
					or matches(table.concat(limitedTags, " "), obstacleHints)
				)
			then
				local record = table.clone(metadata)
				record.position = position(node)
				record.scope = "UNVERIFIED name/tag candidate, not a confirmed progression objective"
				add("objectives", record)
			end
			if node:IsA("ProximityPrompt") then
				add("interactions", {
					path = path(node),
					class = node.ClassName,
					enabled = node.Enabled,
					action = clean(node.ActionText),
					object = clean(node.ObjectText),
					holdDuration = node.HoldDuration,
					maxDistance = node.MaxActivationDistance,
					attributes = attrs,
				})
			elseif node:IsA("ClickDetector") then
				add("interactions", {
					path = path(node),
					class = node.ClassName,
					maxDistance = node.MaxActivationDistance,
					attributes = attrs,
				})
			elseif node:IsA("Tool") then
				tool(node)
			elseif node:IsA("TextLabel") or node:IsA("TextButton") then
				if matches(node.Text) or matches(node.Name) then
					add("ui", {
						path = path(node),
						text = clean(node.Text, 220),
						visible = node.Visible,
						attributes = attrs,
					})
				end
			end
			local children = node:GetChildren()
			for _, child in children do
				if #queue >= maxNodes then
					report.truncated = true
					break
				end
				table.insert(queue, child)
			end
		end)
		if not ok then
			report.scanErrors += 1
			if #report.errors < 8 then
				table.insert(report.errors, path(node) .. ": " .. clean(err, 200))
			end
		end
		if report.visited % 100 == 0 then
			self.yield()
		end
	end
	if generation ~= self.generation then
		return nil, "Capture cancelled"
	end
	if index <= #queue then
		report.truncated = true
	end
	report.duration = math.round((self.clock() - started) * 1000) / 1000
	return report
end

local function valueText(value)
	if type(value) ~= "table" then
		return clean(value, 240)
	end
	local fields = {}
	for key, item in value do
		table.insert(fields, clean(key, 80) .. "=" .. valueText(item))
	end
	table.sort(fields)
	return "{" .. table.concat(fields, ", ") .. "}"
end

function Diagnostics.Diff(before, after)
	if not before then
		return "No previous capture for comparison."
	end
	local changes = {}
	for _, group in { "npcs", "objectives", "interactions", "tools", "state", "ui" } do
		local previous = {}
		for _, record in before[group] do
			previous[record.path] = record
		end
		for _, record in after[group] do
			local old = previous[record.path]
			if not old then
				table.insert(changes, "Observed: " .. record.path)
			elseif valueText(old) ~= valueText(record) then
				table.insert(
					changes,
					"Changed: "
						.. record.path
						.. "\n  Before: "
						.. valueText(old)
						.. "\n  After: "
						.. valueText(record)
				)
			end
			previous[record.path] = nil
		end
		for fullPath in previous do
			table.insert(changes, "No longer observed (may be streamed out): " .. fullPath)
		end
	end
	if #changes == 0 then
		return "No changes in the sampled fields."
	end
	while #changes > 40 do
		table.remove(changes)
	end
	return table.concat(changes, "\n")
end

function Diagnostics.Format(report, previous)
	local lines = {
		"MOHAMMAD & ALI | LIVE OBSERVATION - CANDIDATES ONLY",
		"Phase: " .. report.phase .. " | PlaceId: " .. tostring(report.placeId) .. " | GameId: " .. tostring(
			report.gameId
		),
		report.adapter,
		string.format(
			"Visited %d objects in %.3fs | Truncated: %s | Read errors: %d",
			report.visited,
			report.duration,
			tostring(report.truncated),
			report.scanErrors
		),
		"Read-only, non-atomic scan. Names/tags/UI text do not establish server authority or valid dungeon scope.",
		"No attacks, remote calls, prompt activation, source reads, or automatic binding changes were performed.",
		"\nCHANGES SINCE PREVIOUS CAPTURE (correlation only)",
		Diagnostics.Diff(previous, report),
	}
	for _, group in { "npcs", "objectives", "interactions", "tools", "state", "ui" } do
		table.insert(lines, "\n" .. string.upper(group) .. " CANDIDATES / OBSERVATIONS")
		if #report[group] == 0 then
			table.insert(lines, "None observed in this bounded sample.")
		end
		for _, record in report[group] do
			table.insert(lines, valueText(record))
		end
	end
	table.insert(
		lines,
		"\nSTILL NEEDED: verified scope/area/wave/completion data; supported combat and rubble action; replay action and new-run confirmation."
	)
	local text = table.concat(lines, "\n")
	for _, err in report.errors do
		text ..= "\nREAD ERROR: " .. err
	end
	if #text > 30000 then
		text = string.sub(text, 1, 30000)
			.. "\n[DISPLAY TRUNCATED: collect closer to the relevant objective.]"
	end
	return text
end

return Diagnostics
