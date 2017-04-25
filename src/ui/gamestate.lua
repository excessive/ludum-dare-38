local imgui = _G.imgui

return function(state)
	if not _G.windows.gamestate then
		return
	end

	if imgui.Begin("Game State") then
		_, state.player.night  = imgui.SliderInt("Night",  state.player.night,  1, 7)
		_, state.player.sanity = imgui.SliderInt("Sanity", state.player.sanity, 0, 20)
		_, state.combat.hp     = imgui.SliderInt("Health", state.combat.hp,     0, 10000)
	end
	imgui.End()
end
