local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Configuration = require(script.Parent.Core.Configuration)
local Logger = require(script.Parent.Core.Logger)
local AutomationController = require(script.Parent.Core.AutomationController)
local MovementController = require(script.Parent.Movement.MovementController)
local RobloxMovementDriver = require(script.Parent.Movement.RobloxMovementDriver)
local AnimeZeroAdapter = require(script.Parent.Game.AnimeZeroAdapter)
local StudioDemoAdapter = require(script.Parent.Game.StudioDemoAdapter)
local MainWindow = require(script.Parent.UI.MainWindow)
local Cleanup = require(script.Parent.Utils.Cleanup)
local Bootstrap = {}
local activeSession
local LIFETIME_NAME = "MA_ControllerLifetime"
local PROJECT = "MohammadAndAli"

function Bootstrap.start()
	assert(RunService:IsClient(), "Mohammad & Ali requires a Roblox client context, not a server Script")
	local player = Players.LocalPlayer
	assert(player, "Mohammad & Ali requires Players.LocalPlayer; wait until a client player is available")
	local playerGui = player:WaitForChild("PlayerGui", 10)
	assert(playerGui, "Mohammad & Ali: PlayerGui was unavailable after 10 seconds")
	local previous = playerGui:FindFirstChild(LIFETIME_NAME)
	if previous then
		assert(previous:IsA("BindableEvent"), "Mohammad & Ali: startup marker name is already in use")
		local owner = previous:GetAttribute("Project")
		if owner == PROJECT then
			local status = previous:GetAttribute("Status")
			assert(
				status ~= "Starting",
				"Mohammad & Ali initialization is already in progress; wait and retry"
			)
			assert(
				status == "Ready",
				"Mohammad & Ali: existing session is not ready; unload it before retrying"
			)
			previous:Fire("Show")
			if activeSession and not activeSession.destroyed then
				return activeSession
			end
			-- Independent bundle copies share the marker, not their module caches.
			return {
				reused = true,
				Show = function()
					if previous.Parent then
						previous:Fire("Show")
					end
				end,
				Destroy = function()
					if previous.Parent then
						previous:Fire("Destroy")
					end
				end,
			}
		end
		error(
			"Mohammad & Ali: older or unrecognized startup marker; unload the old session or rejoin before loading",
			0
		)
	end

	local lifetime = Instance.new("BindableEvent")
	lifetime.Name = LIFETIME_NAME
	lifetime:SetAttribute("Project", PROJECT)
	lifetime:SetAttribute("Status", "Starting")
	lifetime.Parent = playerGui
	local cleanup = Cleanup.new()
	cleanup:Add(lifetime)
	local session = { reused = false }
	function session:Show()
		if not self.destroyed and self.window then
			self.window:Show()
		end
	end
	function session:Destroy()
		if self.destroyed then
			return
		end
		self.destroyed = true
		cleanup:Destroy()
		if activeSession == self then
			activeSession = nil
		end
	end
	cleanup:Add(lifetime.Event:Connect(function(command)
		if command == "Show" then
			session:Show()
		else
			session:Destroy()
		end
	end))
	cleanup:Add(lifetime.Destroying:Connect(function()
		session:Destroy()
	end))

	local ok, result = xpcall(function()
		local bindings = require(script.Parent.Game.Integration)
		local adapter = if RunService:IsStudio() and bindings.snapshot == nil
			then StudioDemoAdapter.new(player)
			else AnimeZeroAdapter.new(bindings)
		local controller
		cleanup:Add(function()
			if not controller then
				adapter:destroy()
			end
		end)
		local config = Configuration.new()
		session.config = config
		cleanup:Add(config)
		local loaded, preferences = pcall(function()
			return adapter:loadPreferences()
		end)
		if loaded and preferences then
			config:Load(preferences)
		end
		local logger = Logger.new(config)
		cleanup:Add(logger)
		local movement =
			MovementController.new(RobloxMovementDriver.new(player, adapter.capabilities.movementSpeed))
		cleanup:Add(function()
			if not controller then
				movement:Destroy()
			end
		end)
		controller = AutomationController.new(adapter, movement, config, logger)
		session.controller = controller
		cleanup:Add(controller)
		local window = MainWindow.new(
			controller,
			config,
			adapter,
			logger,
			if getmetatable(adapter) == StudioDemoAdapter
				then "STUDIO DEMO"
				elseif bindings.snapshot then "CUSTOM ADAPTER · VERIFY IN GAME"
				else "VERIFIED ADAPTER REQUIRED",
			playerGui,
			cleanup
		)
		session.window = window
		local elapsed = 0
		cleanup:Add(RunService.Heartbeat:Connect(function(dt)
			elapsed += dt
			if elapsed < 0.1 then
				return
			end
			elapsed = 0
			controller:Tick(os.clock())
		end))
		cleanup:Add(window.screen.Destroying:Connect(function()
			session:Destroy()
		end))
		window:Show()
		activeSession = session
		lifetime:SetAttribute("Status", "Ready")
		logger:Log("INFO", "Interface ready", "Start a run from Dashboard")
		if not loaded then
			logger:Log("WARN", "Could not load preferences", preferences)
		end
		return session
	end, debug.traceback)
	if not ok then
		session:Destroy()
		error(
			"Mohammad & Ali initialization failed; partial resources were cleaned up.\n" .. tostring(result),
			0
		)
	end
	return result
end

return Bootstrap
