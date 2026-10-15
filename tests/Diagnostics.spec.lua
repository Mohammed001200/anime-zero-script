local Diagnostics = require("../src/Game/IntegrationDiagnostics")
local Adapter = require("../src/Game/AnimeZeroAdapter")
local MockClient = require("./MockClient")

local function setup()
	local host = MockClient.new()
	local diagnostics = Diagnostics.new(host.services.Players.LocalPlayer, {
		game = host.environment.game,
		players = host.services.Players,
		workspace = host.services.Workspace,
		replicatedStorage = host.services.ReplicatedStorage,
		collection = host.services.CollectionService,
		clock = function()
			return 0
		end,
		yield = function() end,
	})
	local function make(class, name, parent)
		local object = host.environment.Instance.new(class)
		object.Name, object.Parent = name, parent
		return object
	end
	return host, diagnostics, make
end

return function(t)
	t.it("diagnostic NPC sampling keeps nearby observations when its candidate cap is reached", function()
		local host, diagnostics, make = setup()
		local character = make("Model", "LocalCharacter", host.services.Workspace)
		host.services.Players.LocalPlayer.Character = character
		local root = make("Part", "HumanoidRootPart", character)
		root.Position = host.environment.Vector3.zero
		for index = 50, 1, -1 do
			local model = make("Model", "Actor" .. index, host.services.Workspace)
			local humanoid = make("Humanoid", "Humanoid", model)
			humanoid.Health, humanoid.MaxHealth = 100, 100
			local part = make("Part", "HumanoidRootPart", model)
			part.Position = host.environment.Vector3.new(index, 0, 0)
		end
		local report = diagnostics:Collect("Nearby", Adapter.new({}))
		t.equal(#report.npcs, 36)
		t.equal(report.npcs[1].distance, 1)
		t.equal(report.npcs[36].distance, 36)
		t.equal(report.truncated, true)
		diagnostics:Destroy()
	end)
	t.it("diagnostics report humanoid evidence and exclude player characters and the owned GUI", function()
		local host, diagnostics, make = setup()
		local model = make("Model", "ObservedActor", host.services.Workspace)
		model:SetAttribute("CurrentArea", 2)
		local humanoid = make("Humanoid", "Humanoid", model)
		humanoid.Health, humanoid.MaxHealth = 73, 100
		local part = make("Part", "HumanoidRootPart", model)
		part.Position = host.environment.Vector3.new(5, 3, 0)
		local character = make("Model", "PlayerCharacter", host.services.Workspace)
		host.services.Players.LocalPlayer.Character = character
		make("Humanoid", "Humanoid", character)
		local gui = make("ScreenGui", "OwnedGUI", host.playerGui)
		local label = make("TextLabel", "Replay", gui)
		label.Text = "Replay"
		local report = diagnostics:Collect("Before attack", Adapter.new({}), gui)
		t.equal(#report.npcs, 1)
		t.equal(report.npcs[1].health, 73)
		t.equal(report.npcs[1].attributes.CurrentArea, 2)
		assert(string.find(report.npcs[1].scope, "UNKNOWN", 1, true))
		t.equal(#report.ui, 0)
		t.equal(report.evidenceOnly, true)
		t.equal(report.scanErrors, 0)
		diagnostics:Destroy()
	end)
	t.it(
		"diagnostics observe prompts, tools, candidate rubble and replay UI without activating them",
		function()
			local host, diagnostics, make = setup()
			local object = make("Part", "RubbleCandidate", host.services.Workspace)
			object.Position = host.environment.Vector3.zero
			local prompt = make("ProximityPrompt", "ObservedPrompt", object)
			prompt.Enabled, prompt.ActionText, prompt.ObjectText = true, "Interact", "Obstacle"
			prompt.HoldDuration, prompt.MaxActivationDistance = 1, 10
			local calls = 0
			prompt.InputHoldBegin = function()
				calls += 1
			end
			local backpack = make("Backpack", "Backpack", host.services.Players.LocalPlayer)
			local tool = make("Tool", "ObservedTool", backpack)
			tool.Enabled, tool.RequiresHandle = true, false
			tool.Activate = function()
				calls += 1
			end
			local button = make("TextButton", "ObservedButton", host.playerGui)
			button.Text = "Replay Dungeon"
			local report = diagnostics:Collect("Completion", Adapter.new({}))
			t.equal(#report.objectives, 1)
			t.equal(#report.interactions, 1)
			t.equal(#report.tools, 1)
			t.equal(#report.ui, 1)
			t.equal(calls, 0)
			assert(string.find(Diagnostics.Format(report), "CANDIDATES ONLY", 1, true))
			diagnostics:Destroy()
		end
	)
	t.it("diagnostic capture budgets and cancellation are enforced", function()
		local host, diagnostics, make = setup()
		for index = 1, 150 do
			make("Folder", "Observed" .. index, host.services.Workspace)
		end
		local report = diagnostics:Collect("Limited", Adapter.new({}), nil, { maxNodes = 5 })
		assert(report.visited <= 5)
		t.equal(report.truncated, true)
		diagnostics.yield = function()
			diagnostics:Cancel()
		end
		local cancelled, reason = diagnostics:Collect("Cancel", Adapter.new({}))
		t.equal(cancelled, nil)
		t.equal(reason, "Capture cancelled")
		diagnostics.clock = function()
			return 10
		end
		local time = 0
		diagnostics.clock = function()
			time += 1
			return time
		end
		report = diagnostics:Collect("Timed", Adapter.new({}), nil, { maxSeconds = 0.1 })
		t.equal(report.visited, 0)
		t.equal(report.truncated, true)
		diagnostics:Destroy()
	end)
	t.it("before/after reports show observed health changes and do not infer bindings", function()
		local host, diagnostics, make = setup()
		local model = make("Model", "ObservedActor", host.services.Workspace)
		local humanoid = make("Humanoid", "Humanoid", model)
		humanoid.Health, humanoid.MaxHealth = 70, 100
		local before = diagnostics:Collect("Before", Adapter.new({}))
		humanoid.Health = 50
		local after = diagnostics:Collect("After", Adapter.new({}))
		local text = Diagnostics.Format(after, before)
		assert(string.find(text, "health=70", 1, true))
		assert(string.find(text, "health=50", 1, true))
		assert(string.find(text, "correlation only", 1, true))
		diagnostics:Destroy()
	end)
	t.it("diagnostics surface inaccessible-object read errors without stopping the capture", function()
		local host, diagnostics, make = setup()
		local object = make("Folder", "UnavailableObject", host.services.Workspace)
		function host.services.CollectionService:GetTags(node)
			if node == object then
				error("Injected read failure")
			end
			return {}
		end
		local report = diagnostics:Collect("Errors", Adapter.new({}))
		t.equal(report.scanErrors, 1)
		assert(string.find(Diagnostics.Format(report), "READ ERROR", 1, true))
		diagnostics:Destroy()
	end)
end
