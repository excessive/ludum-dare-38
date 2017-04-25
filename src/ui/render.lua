return function(renderer)
	if not _G.windows.renderflags then
		return
	end

	if imgui.Begin("Renderer") then
		if imgui.Checkbox("Light View", renderer.light_debug) then
			renderer.light_debug = not renderer.light_debug
		end
		if imgui.Checkbox("Show Bullets", renderer.bullet_debug) then
			renderer.bullet_debug = not renderer.bullet_debug
		end
		if imgui.Checkbox("Show Capsules", renderer.capsule_debug) then
			renderer.capsule_debug = not renderer.capsule_debug
		end
		if imgui.Checkbox("Show Octree", renderer.octree_debug) then
			renderer.octree_debug = not renderer.octree_debug
		end
	end
	imgui.End()
end
