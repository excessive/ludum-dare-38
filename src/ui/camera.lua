local cpml = require "cpml"

local function to_euler(q)
	return {
		math.atan2(2*q.y*q.w-2*q.x*q.z , 1 - 2*q.y^2 - 2*q.z^2), -- heading
		math.asin(2*q.x*q.y + 2*q.z*q.w), -- attitude
		math.atan2(2*q.x*q.w-2*q.y*q.z , 1 - 2*q.x^2 - 2*q.z^2) -- bank
	}
end

local function from_euler(eulers)
	local heading, attitude, bank = eulers[1], eulers[2], eulers[3]
	local c1 = math.cos(heading*0.5)
	local s1 = math.sin(heading*0.5)
	local c2 = math.cos(attitude*0.5)
	local s2 = math.sin(attitude*0.5)
	local c3 = math.cos(bank*0.5)
	local s3 = math.sin(bank*0.5)
	local c1c2 = c1*c2
	local s1s2 = s1*s2
	return cpml.quat(
		c1c2*s3 + s1s2*c3,
		s1*c2*c3 + c1*s2*s3,
		c1*s2*c3 - s1*c2*s3,
		c1c2*c3 - s1s2*s3
	)
end

return function(camera)
	if not _G.windows.camera then
		return
	end

	if imgui.Begin("Camera") then
		_, camera.fov = imgui.SliderFloat("fov", camera.fov, 45.0, 120.0)
		_, camera.near, camera.far = imgui.SliderFloat2("range", camera.near, camera.far, 0.1, 1000.0)
		camera.near = math.min(camera.near, camera.far)
		camera.far = math.max(camera.near, camera.far)

		_, camera.pitch_limit_up = imgui.SliderFloat("limit up", camera.pitch_limit_up, 0.05, 0.95)
		_, camera.pitch_limit_down = imgui.SliderFloat("limit down", camera.pitch_limit_down, 0.05, 0.95)

		local angle = to_euler(camera.orientation)
		_, angle[1], angle[2], angle[3] = imgui.SliderFloat3("rotation", angle[1], angle[2], angle[3], -math.pi, math.pi)
		camera.orientation = from_euler(angle)
		camera.orientation = camera.orientation:normalize()
		camera.direction   = camera.orientation * cpml.vec3.unit_y

		imgui.InputFloat3("position", camera.position.x, camera.position.y, camera.position.z)
		imgui.Text("target " .. tostring(camera.target))
	end
	imgui.End()
end
