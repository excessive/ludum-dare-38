local cpml    = require "cpml"
local tactile = require "tactile"
local tiny    = require "tiny"
local now     = 0
local system  = tiny.processingSystem {
	filter   = tiny.requireAll("player", "transform"),
	paused   = false,
	deadzone = 0.25
}

local function register_gamepad(input, id)
	local gb = tactile.gamepadButtons
	local ga = tactile.gamepadAxis

	input.move_x = input.move_x:addAxis(ga(id, "leftx"))
	input.move_y = input.move_y:addAxis(ga(id, "lefty"))

	-- Camera
	input.camera_x = input.camera_x:addAxis(ga(id, "rightx"))
	input.camera_y = input.camera_y:addAxis(ga(id, "righty"))

	-- Actions
	input.attack = input.attack:addButton(gb(id, "a"))
end

function system:onAddToWorld()
	-- Shorthand functions
	-- Define inputs
	local k = tactile.keys
	local m = function(button)
		return function() return love.mouse.isDown(button) end
	end

	self.input = {
		-- Move
		move_x = tactile.newControl():addButtonPair(k("a", "left"), k("d", "right")),
		move_y = tactile.newControl():addButtonPair(k("w", "up"),   k("s", "down")),

		-- Camera
		camera_x = tactile.newControl(),
		camera_y = tactile.newControl(),

		-- Actions
		attack = tactile.newControl():addButton(k("z", "return")):addButton(m(1))
	}

	local sticks = love.joystick.getJoysticks()
	for i, js in ipairs(sticks) do
		if js:isGamepad() then
			register_gamepad(self.input, i)
		end
	end

	-- fuck off I'll deadzone this myself
	self.input.move_x.deadzone = self.deadzone
	self.input.move_y.deadzone = self.deadzone
end

function system:onAdd(player)
	player.orientation_offset = cpml.quat(0, 0, 0, 1)
end

function system:process(entity, dt)
	now = now + dt

	local player    = entity.player
	local transform = entity.transform
	local combat    = entity.combat
	local in_menu   = false

	-- ignore all input if the player is using the UI
	if not love.mouse.getRelativeMode() then
		in_menu = true
	end

	--== Menu ==--

	local attack   = false
	local move_x   = 0
	local move_y   = 0
	local camera_x = 0
	local camera_y = 0

	if not in_menu then
		-- Process input
		for _, i in pairs(self.input) do
			i:update()
		end

		-- Check controls
		attack   = self.input.attack:isDown()
		move_x   = self.input.move_x:getValue()
		move_y   = self.input.move_y:getValue()
		camera_x = self.input.camera_x:getValue()
		camera_y = self.input.camera_y:getValue()
	end

	--== Camera ==--

	local function sign(v)
		return v > 0 and 1 or -1
	end

	camera_x = (camera_x^2) * sign(camera_x)
	camera_y = (camera_y^2) * sign(camera_y)
	self.camera:rotate_xy(camera_x*20, camera_y*10)

	--== Movement ==--

	local move        = cpml.vec3(move_x, -move_y, 0)
	local move_len    = move:len()
	local snap_cancel = false

	-- Each axis had a deadzone, but we also want a little more overall.
	if move_len < self.deadzone or player.freeze then
		move.x   = 0
		move.y   = 0
		move_len = 0
	elseif move_len > 1 then
		move     = move / move_len
		move_len = move:len()
	end
	player.move_len = move_len


	if not player.freeze then
		if move_len == 0 then
			if not entity.animation:find_track(player.actions.idle) then
				entity.animation:transition(player.actions.idle, 0.2)
			end
		else
			if not entity.animation:find_track(player.actions.run) then
				entity.animation:transition(player.actions.run, 0.2)
			end
		end
	end

	--== Orientation ==--

	local angle = cpml.vec2(move.x, move.y):angle_to() + math.pi / 2

	-- Change direction player is facing
	if (move.x ~= 0 or move.y ~= 0) then
		local snap_to = self.camera.orientation * cpml.quat.rotate(angle, cpml.vec3.unit_z)

		if player.snap_to then
			-- Directions
			local current = player.snap_to * cpml.vec3.unit_y
			local next    = snap_to * cpml.vec3.unit_y
			local from    = current:dot(self.camera.direction)
			local to      = next:dot(self.camera.direction)

			-- If you move in the opposite direction, snap to end of slerp
			if from ~= to and math.abs(from) - math.abs(to) == 0 then
				transform.orientation = player.snap_to:clone()
			end
		end

		player.snap_to = snap_to
		player.slerp   = 0
	end

	if player.snap_to then
		transform.orientation   = transform.orientation:slerp(player.snap_to, 8*dt*2)
		transform.orientation.x = 0
		transform.orientation.y = 0
		transform.orientation   = transform.orientation:normalize()
		player.slerp            = player.slerp + dt

		if player.slerp > 1/2 then
			player.snap_to = nil
			player.slerp   = 0
		end
	end

	-- Cancel snap if performing actions
	if attack then
		snap_cancel = true
	end

	--- cancel the orientation transition if needed
	if snap_cancel and player.snap_to then
		transform.orientation   = player.snap_to:clone()
		transform.orientation.x = 0
		transform.orientation.y = 0
		transform.orientation   = transform.orientation:normalize()
		player.snap_to          = nil
		player.slerp            = 0
	end

	transform.direction = transform.orientation * -cpml.vec3.unit_y

	-- Prevent the movement animation from moving you along the wrong
	-- orientation (we want to only move how the player is trying to)
	-- This means no more dancing forward!
	local move_orientation = self.camera.orientation:clone() * cpml.quat.rotate(angle, cpml.vec3.unit_z)
	if player.lock_velocity and player.snap_to then
		move_orientation = player.snap_to
	end
	move_orientation.x = 0
	move_orientation.y = 0
	move_orientation   = move_orientation:normalize()
	local move_direction = move_orientation * -cpml.vec3.unit_y
	transform.velocity  = (move_direction * math.min(move_len, 1)) * player.speed

	--== Actions ==--

	if attack and not player.freeze and not combat.attacking then
		_G.EVENT:emit("player attack", entity)
	end

	transform.position = transform.position + transform.velocity * dt

	-- Invisible walls!
	local len = transform.position:len()
	local stage_radius = 15
	if len > stage_radius then
		transform.position = transform.position / len * stage_radius
	end
	transform.position.z = 0
end

return system
