local ObservedIntegration =
	require(if script then script.Parent.ObservedIntegration else "./ObservedIntegration")

return {
	create = function(player)
		-- Scope comes from the supplied recordings, not a guessed game identity.
		if game.PlaceId ~= 109151342576374 or game.GameId ~= 10512942223 then
			return {}
		end
		return ObservedIntegration.new({
			player = player,
			placeId = game.PlaceId,
			workspace = game:GetService("Workspace"),
			inputService = game:GetService("UserInputService"),
			guiService = game:GetService("GuiService"),
			heartbeat = game:GetService("RunService").Heartbeat,
			input = { press = mouse1press, release = mouse1release, focused = isrbxactive },
		})
	end,
}
