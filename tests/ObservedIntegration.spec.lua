-- Contract checks only; no live services or real mouse input are executed.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Roblox = require("@lune/roblox")
local Signal = require("../src/Utils/Signal")
local M1Input = require("../src/Game/M1Input")
local Adapter = require("../src/Game/AnimeZeroAdapter")
local Configuration = require("../src/Core/Configuration")
local Automation = require("../src/Core/AutomationController")
local Movement = require("../src/Movement/MovementController")
local Logger = require("../src/Core/Logger")
local ObservedIntegration = luau.load(fs.readFile("src/Game/ObservedIntegration.lua"), {
	environment = {
		script = false,
		Enum = Roblox.Enum,
		Vector3 = Roblox.Vector3,
		require = function(path)
			assert(path == "./M1Input")
			return M1Input
		end,
	},
})()

local function node(class, name, parent)
	local object = {
		ClassName = class,
		Name = name,
		Parent = parent,
		children = {},
		attributes = {},
		Visible = true,
		Enabled = true,
	}
	if parent then
		table.insert(parent.children, object)
	end
	function object:IsA(kind)
		return kind == self.ClassName
			or (kind == "BasePart" and self.ClassName == "Part")
			or (kind == "GuiObject" and (self.ClassName == "TextLabel" or self.ClassName == "Frame"))
	end
	function object:FindFirstChild(childName, recursive)
		for _, item in self.children do
			if item.Name == childName then
				return item
			end
			if recursive then
				local found = item:FindFirstChild(childName, true)
				if found then
					return found
				end
			end
		end
		return nil
	end
	function object:FindFirstChildOfClass(kind)
		for _, item in self.children do
			if item:IsA(kind) then
				return item
			end
		end
		return nil
	end
	object.FindFirstChildWhichIsA = object.FindFirstChildOfClass
	function object:GetChildren()
		return table.clone(self.children)
	end
	function object:GetAttribute(key)
		return self.attributes[key]
	end
	return object
end

local function nested(parent, names)
	for _, name in names do
		parent = node("Frame", name, parent)
	end
	parent.ClassName, parent.Text = "TextLabel", ""
	return parent
end

local function fixture()
	local h = { time = 0, presses = 0, releases = 0, focused = true, hover = {} }
	h.workspace = node("Workspace", "Workspace")
	h.folder = node("Folder", "enemies", h.workspace)
	h.player = node("Player", "LocalPlayer")
	h.gui = node("PlayerGui", "PlayerGui", h.player)
	function h.gui:GetGuiObjectsAtPosition()
		return h.hover
	end
	h.counter = nested(h.gui, { "RoundHUD", "Container", "TopPart", "RemainingFrame", "EnemyCount" })
	h.counter.Text = "Nightmare - Area 1/5 - 2 left"
	h.result = nested(h.gui, { "EndScreen", "Holder", "ConstraintedHolder", "ResultText" })
	h.result.Text, h.result.Visible = "VICTORY!", false
	h.character = node("Model", "Character", h.workspace)
	h.player.Character = h.character
	local humanoid = node("Humanoid", "Humanoid", h.character)
	humanoid.Health = 100
	h.root = node("Part", "HumanoidRootPart", h.character)
	h.root.Position = Roblox.Vector3.zero
	h.inputService = { WindowFocusReleased = Signal.new(), TextBoxFocused = Signal.new() }
	function h.inputService:GetFocusedTextBox()
		return nil
	end
	function h.inputService:GetMouseLocation()
		return Roblox.Vector2.zero
	end
	function h.inputService:IsMouseButtonPressed()
		return false
	end
	h.guiService = { MenuIsOpen = false, MenuOpened = Signal.new() }
	h.heartbeat = Signal.new()
	h.bindings = ObservedIntegration.new({
		player = h.player,
		workspace = h.workspace,
		inputService = h.inputService,
		guiService = h.guiService,
		heartbeat = h.heartbeat,
		placeId = 109151342576374,
		clock = function()
			return h.time
		end,
		input = {
			press = function()
				h.presses += 1
			end,
			release = function()
				h.releases += 1
			end,
			focused = function()
				return h.focused
			end,
		},
	})
	function h:enemy(name, distance, parent)
		local model = node("Model", name, parent or self.folder)
		local health = node("Humanoid", "Humanoid", model)
		health.Health = 100
		local root = node("Part", "HumanoidRootPart", model)
		root.Position = Roblox.Vector3.new(distance, 0, 0)
		return model
	end
	function h:controller()
		self.config = Configuration.new()
		self.config:Set("autoBreakRubble", false)
		self.config:Set("autoNextArea", false)
		self.logger = Logger.new(self.config, function() end)
		self.driver = { moves = 0 }
		function self.driver:moveTo()
			self.moves += 1
		end
		function self.driver:cancel() end
		function self.driver:getError()
			return nil
		end
		function self.driver:destroy() end
		self.automation =
			Automation.new(Adapter.new(self.bindings), Movement.new(self.driver), self.config, self.logger)
		return self.automation
	end
	function h:destroy()
		if self.automation then
			self.automation:Destroy()
			self.logger:Destroy()
			self.config:Destroy()
		else
			self.bindings.destroy()
		end
	end
	return h
end

return function(t)
	t.it("Auto Farm with aura still follows to sword distance in the input trial", function()
		local h = fixture()
		h:enemy("0", 7)
		local c = h:controller()
		h.config:Set("killAura", true)
		c:Start()
		c:Tick(0)
		t.equal(h.driver.moves, 1)
		t.equal(h.presses, 0)
		h.root.Position = Roblox.Vector3.new(3, 0, 0)
		c:Tick(1)
		t.equal(h.presses, 1)
		h:destroy()
	end)
	t.it("observed rubble requires readable HP, zero HUD count, and normal input range", function()
		local h = fixture()
		local world = node("Folder", "World", h.workspace)
		local map = node("Model", "Map", world)
		local border = node("Part", "Border1", map)
		border.CFrame, border.Size = Roblox.CFrame.new(10, 0, 0), Roblox.Vector3.new(2, 10, 10)
		border.attributes.RubbleHealth = 500
		local state = h.bindings.snapshot()
		t.equal(state.areaCleared, false)
		h.counter.Text = "Nightmare - Area 1/5 - 0 left"
		state = h.bindings.snapshot()
		t.equal(state.areaCleared, true)
		t.equal(state.rubble[1].health, 500)
		t.equal(state.rubble[1].position.x, 9)
		t.equal(h.bindings.breakRubble(state.rubble[1].id, state.runId), false)
		t.equal(h.presses, 0)
		h.root.Position = Roblox.Vector3.new(4, 0, 0)
		t.equal(h.bindings.breakRubble(state.rubble[1].id, state.runId), true)
		border.attributes.RubbleHealth = 417
		state = h.bindings.snapshot()
		t.equal(state.rubble[1].health, 417)
		border.attributes.RubbleHealth = 0
		h.counter.Text = "Enter area 2/5"
		state = h.bindings.snapshot()
		t.equal(#state.rubble, 0)
		t.equal(state.nextEntrance, nil)
		t.equal(h.releases, 1)
		h:destroy()
	end)
	t.it("script-window hover pauses M1, while victory is still observed under its overlay", function()
		local h = fixture()
		h:enemy("0", 3)
		local c = h:controller()
		local screen = node("ScreenGui", "MohammadAndAli", h.gui)
		local frame = node("Frame", "Window", screen)
		h.hover = { frame }
		c:Start()
		c:Tick(0)
		t.equal(h.presses, 0)
		t.equal(c.attempts, 0)
		h.hover = {}
		c:Tick(1)
		t.equal(h.presses, 1)
		h.counter.Text = "Nightmare - Area 5/5 - 0 left"
		h.result.Visible = true
		h.hover = { h.result }
		c:Tick(2)
		t.equal(c.machine.state, "DUNGEON_COMPLETE")
		t.equal(c.enabled, false)
		t.equal(h.releases, 1)
		h:destroy()
	end)
	t.it("observed targeting excludes allies/GUI rigs and never fabricates HP", function()
		local h = fixture()
		h:enemy("1", 4)
		h:enemy("Ally", 2, h.workspace)
		h:enemy("PreviewRig", 1, h.gui)
		local state = h.bindings.snapshot()
		t.equal(#state.npcs, 1)
		t.equal(state.npcs[1].health, nil)
		t.equal(state.npcs[1].healthKnown, false)
		t.equal(state.areaCleared, false)
		h:destroy()
	end)
	t.it("Auto Farm moves, holds M1 in range, releases on Stop and switches removed targets", function()
		local h = fixture()
		local first = h:enemy("0", 30)
		h:enemy("1", 35)
		local c = h:controller()
		t.equal(c:Start(), true)
		c:Tick(0)
		t.equal(h.driver.moves, 1)
		t.equal(h.presses, 0)
		h.root.Position = Roblox.Vector3.new(28, 0, 0)
		c:Tick(1)
		t.equal(h.presses, 1)
		local previous = c.targetId
		first.Parent = nil
		table.remove(h.folder.children, 1)
		c:Tick(2)
		assert(c.targetId ~= previous)
		assert(h.releases >= 1)
		c:Stop()
		t.equal(c.enabled, false)
		h:destroy()
	end)
	t.it("observed Kill Aura respects range without NPC pursuit", function()
		local h = fixture()
		h:enemy("0", 5)
		local c = h:controller()
		h.config:Set("autoFarm", false)
		h.config:Set("killAura", true)
		h.config:Set("attackRange", 3)
		c:Start()
		c:Tick(0)
		t.equal(h.presses, 0)
		t.equal(h.driver.moves, 0)
		h.config:Set("attackRange", 6)
		c:Tick(1)
		t.equal(h.presses, 1)
		h.config:Set("killAura", false)
		assert(h.releases >= 1)
		h:destroy()
	end)
	t.it("unchanged unknown HP has a bounded failure without pretending damage succeeded", function()
		local h = fixture()
		h:enemy("0", 3)
		local c = h:controller()
		h.config:Set("combatProgressTimeout", 5)
		h.config:Set("maxRecoveryAttempts", 0)
		c:Start()
		c:Tick(0)
		c:Tick(6)
		t.equal(c.enabled, false)
		assert(c.status.lastError:find("Unverified damage", 1, true))
		t.equal(h.releases, 1)
		h:destroy()
	end)
	t.it("focus pause cancels movement/M1 without recovery loops and resumes after focus", function()
		local h = fixture()
		h:enemy("0", 3)
		local c = h:controller()
		c:Start()
		c:Tick(0)
		h.focused = false
		h.heartbeat:Fire()
		t.equal(h.releases, 1)
		c:Tick(100)
		t.equal(c.attempts, 0)
		t.equal(c.enabled, true)
		h.focused = true
		c:Tick(101)
		t.equal(h.presses, 2)
		h:destroy()
	end)
	t.it(
		"observed victory stops input, manual Retry changes local run identity, and checkpoints are not guessed",
		function()
			local h = fixture()
			h.counter.Text = "Enter area 2/5"
			local state = h.bindings.snapshot()
			t.equal(state.area, 1)
			t.equal(state.nextEntrance, nil)
			t.equal(state.manualObjective, true)
			h.counter.Text = "Nightmare - Area 5/5 - 0 left"
			h.result.Visible = true
			state = h.bindings.snapshot()
			t.equal(state.completed, true)
			local runId = state.runId
			h.result.Visible = false
			h.counter.Text = "Nightmare - Area 1/5 - 6 left"
			state = h.bindings.snapshot()
			assert(state.runId ~= runId)
			t.equal(h.bindings.requestReplay, nil)
			t.equal(h.presses, 0)
			h:destroy()
		end
	)
end
