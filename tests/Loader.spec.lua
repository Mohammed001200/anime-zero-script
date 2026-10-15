local fs = require("@lune/fs")
local luau = require("@lune/luau")
local MockClient = require("./MockClient")
local source = fs.readFile("loader.lua")
local function execute(host)
	return luau.load(source, { environment = host.environment, debugName = "loader.lua" })()
end

return function(t)
	t.it("recorded-place bundle detects M1 input, stays idle, and rolls back its watchdog", function()
		local Signal = require("../src/Utils/Signal")
		local host = MockClient.new()
		host.environment.game.PlaceId = 109151342576374
		host.environment.game.GameId = 10512942223
		host.services.GuiService = { MenuIsOpen = false, MenuOpened = Signal.new() }
		host.services.UserInputService.WindowFocusReleased = Signal.new()
		host.services.UserInputService.TextBoxFocused = Signal.new()
		local presses = 0
		host.environment.mouse1press = function()
			presses += 1
		end
		host.environment.mouse1release = function() end
		host.environment.isrbxactive = function()
			return true
		end
		host.failTween = true
		local ok = pcall(execute, host)
		t.equal(ok, false)
		t.equal(host:connections(host.services.RunService.Heartbeat), 0)
		t.equal(host:connections(host.services.UserInputService.WindowFocusReleased), 0)
		host.failTween = false
		local session = execute(host)
		t.equal(session.controller.adapter.capabilities.inputTrial, true)
		t.equal(session.config:Get().movementMode, "MoveTo")
		t.equal(session.controller.enabled, false)
		t.equal(presses, 0)
		t.equal(host:connections(host.services.RunService.Heartbeat), 2)
		local duplicate = execute(host)
		t.equal(duplicate.reused, true)
		t.equal(host:connections(host.services.RunService.Heartbeat), 2)
		session:Destroy()
		t.equal(host:connections(host.services.RunService.Heartbeat), 0)
		t.equal(host:connections(host.services.GuiService.MenuOpened), 0)
	end)
	t.it(
		"real adapter startup errors immediately and Auto Retry click explains its missing binding",
		function()
			local host = MockClient.new()
			local session = execute(host)
			local ok, reason = session.controller:Start()
			t.equal(ok, false)
			assert(string.find(reason, "missing snapshot", 1, true))
			t.equal(session.controller.attempts, 0)
			t.equal(session.controller.enabled, false)
			local function findLabel(parent)
				for _, child in parent:GetChildren() do
					if child.ClassName == "TextLabel" and child.Text == "Auto Retry Dungeon" then
						return child
					end
					local found = findLabel(child)
					if found then
						return found
					end
				end
				return nil
			end
			local label = findLabel(session.window.pages.Dashboard)
			assert(label, "Auto Retry control missing")
			local notifications = session.window.notifications.sequence
			label.Parent:FindFirstChildOfClass("TextButton").Activated:Fire()
			t.equal(session.config:Get().autoRetry, false)
			t.equal(session.window.pages.Diagnostics.Visible, true)
			assert(session.window.notifications.sequence > notifications)
			session.window:_captureDiagnostics()
			assert(string.find(session.window.reportBox.Text, "CANDIDATES ONLY", 1, true))
			session.window.capturePhase = "After manual Replay"
			session.window:_captureDiagnostics()
			assert(string.find(session.window.reportBox.Text, "After manual Replay", 1, true))
			session:Destroy()
		end
	)
	t.it("plain Lua/Lune runtime fails with an explicit client-runtime requirement", function()
		local host = MockClient.new()
		host.environment.game, host.environment.Instance = nil, nil
		local ok, err = pcall(execute, host)
		t.equal(ok, false)
		assert(string.find(err, "requires a Roblox client runtime", 1, true))
	end)
	t.it("unrecognized startup markers are preserved and cannot create duplicate controllers", function()
		local host = MockClient.new()
		local marker = host.environment.Instance.new("BindableEvent")
		marker.Name, marker.Parent = "MA_ControllerLifetime", host.playerGui
		local ok, err = pcall(execute, host)
		t.equal(ok, false)
		assert(string.find(err, "older or unrecognized", 1, true))
		t.equal(marker.Parent, host.playerGui)
		t.equal(host:connections(host.services.RunService.Heartbeat), 0)
	end)
	t.it("destroying the shared initialization marker also unloads its controller", function()
		local host = MockClient.new()
		local session = execute(host)
		host.playerGui:FindFirstChild("MA_ControllerLifetime"):Destroy()
		t.equal(session.destroyed, true)
		t.equal(host.playerGui:FindFirstChild("MohammadAndAli"), nil)
		t.equal(host:connections(host.services.RunService.Heartbeat), 0)
	end)
	t.it("standalone bundle resolves modules and opens the GUI without external require or HTTP", function()
		local host = MockClient.new()
		local session = execute(host)
		assert(host.playerGui:FindFirstChild("MohammadAndAli"))
		t.equal(session.window.window.Visible, true)
		t.equal(session.controller.enabled, false)
		t.equal(host:connections(host.services.RunService.Heartbeat), 1)
		session:Destroy()
	end)
	t.it("running independent bundle copies reuses and reveals one GUI with one heartbeat", function()
		local host = MockClient.new()
		local session = execute(host)
		session.window:Hide()
		local duplicate = execute(host)
		t.equal(duplicate.reused, true)
		t.equal(session.window.window.Visible, true)
		t.equal(host:connections(host.services.RunService.Heartbeat), 1)
		local windows = 0
		for _, child in host.playerGui:GetChildren() do
			if child.Name == "MohammadAndAli" then
				windows += 1
			end
		end
		t.equal(windows, 1)
		duplicate:Destroy()
		t.equal(host.playerGui:FindFirstChild("MohammadAndAli"), nil)
		t.equal(host:connections(host.services.RunService.Heartbeat), 0)
	end)
	t.it("failed GUI construction rolls back partial resources and permits a clean retry", function()
		local host = MockClient.new()
		host.failTween = true
		local ok, err = pcall(execute, host)
		t.equal(ok, false)
		assert(string.find(err, "partial resources were cleaned up", 1, true))
		t.equal(host.playerGui:FindFirstChild("MA_ControllerLifetime"), nil)
		t.equal(host.playerGui:FindFirstChild("MohammadAndAli"), nil)
		t.equal(host:connections(host.services.RunService.Heartbeat), 0)
		t.equal(host:connections(host.services.UserInputService.InputChanged), 0)
		host.failTween = false
		local session = execute(host)
		assert(session.window.window.Visible)
		session:Destroy()
	end)
	t.it("overlapping initialization is rejected before constructing a duplicate GUI", function()
		local host = MockClient.new()
		local nestedOk, nestedError
		host.onTween = function()
			host.onTween = nil
			nestedOk, nestedError = pcall(execute, host)
		end
		local session = execute(host)
		t.equal(nestedOk, false)
		assert(string.find(nestedError, "already in progress", 1, true))
		t.equal(host:connections(host.services.RunService.Heartbeat), 1)
		session:Destroy()
	end)
	t.it("server execution and missing LocalPlayer have clear startup errors", function()
		local host = MockClient.new()
		host.server = true
		local ok, err = pcall(execute, host)
		t.equal(ok, false)
		assert(string.find(err, "requires client execution", 1, true))
		host.server = false
		host.services.Players.LocalPlayer = nil
		ok, err = pcall(execute, host)
		t.equal(ok, false)
		assert(string.find(err, "requires Players.LocalPlayer", 1, true))
		t.equal(#host.playerGui:GetChildren(), 0)
	end)
	t.it("missing PlayerGui uses a bounded wait and leaves no startup marker", function()
		local host = MockClient.new()
		host.playerGui.Parent = nil
		local ok, err = pcall(execute, host)
		t.equal(ok, false)
		assert(string.find(err, "PlayerGui was unavailable after 10 seconds", 1, true))
		t.equal(host.lastWaitTimeout, 10)
	end)
	t.it("destroying the GUI unloads the controller and allows another load", function()
		local host = MockClient.new()
		local session = execute(host)
		session.window.screen:Destroy()
		t.equal(session.destroyed, true)
		t.equal(host:connections(host.services.RunService.Heartbeat), 0)
		local replacement = execute(host)
		t.equal(replacement.reused, false)
		replacement:Destroy()
	end)
end
