local function dump(k, v, ip)
	if type(v) == "table" then
		if imgui.TreeNode(tostring(k)) then
			for _k, t in (ip and ipairs or pairs)(v) do
				dump(_k, t)
			end
			imgui.TreePop()
		end
		return
	end
	imgui.Text(tostring(k))
	imgui.SameLine(150)
	imgui.Text(tostring(v))
end

-- local function line(p, key)
-- 	imgui.Text(tostring(key))
-- 	imgui.SameLine(150)
-- 	imgui.Text(tostring(p[key]))
-- end
local function is_child(skeleton, bone, which)
	local next = skeleton[bone]
	if bone == which then
		return true
	elseif next.parent < which then
		return false
	else
		return is_child(skeleton, next.parent, which)
	end
end

return function(anim)
	if not _G.windows.animation then
		return
	end

	if imgui.Begin("Animation") then
		if imgui.TreeNode("skeleton") then
			for i, t in ipairs(anim.skeleton) do
				imgui.Text(tostring(i))
				imgui.SameLine(75)
				imgui.Text(t.name)
			end
			imgui.TreePop()
		end
	end
	dump("everything else", anim)
	imgui.End()
end
