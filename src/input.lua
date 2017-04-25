local tactile = require "tactile"

local deadzone  = 0.25

local input = {}

local function register_gamepad(input, id)
	local gb = tactile.gamepadButtons
	local ga = tactile.gamepadAxis

	input.move_x = input.move_x:addAxis(ga(id, "leftx"))
	input.move_y = input.move_y:addAxis(ga(id, "lefty"))

	-- Camera
	input.camera_x = input.camera_x:addAxis(ga(id, "rightx"))
	input.camera_y = input.camera_y:addAxis(ga(id, "righty"))

	-- Actions
	input.attack          = input.attack:addButton(gb(id, "a"))
	input.dodge           = input.dodge:addButton(gb(id, "b"))
	input.use_item        = input.use_item:addButton(gb(id, "y"))
	input.cycle_item_up   = input.cycle_item_up:addButton(gb(id, "leftshoulder"))
	input.cycle_item_down = input.cycle_item_down:addButton(gb(id, "rightshoulder"))
	input.pause           = input.pause:addButton(gb(id, "start"))

	-- Menu
	input.menu_back   = input.menu_back:addButton(gb(id, "b"))
	input.menu_action = input.menu_action:addButton(gb(id, "a"))
	input.menu_up     = input.menu_up:addButton(gb(id, "dpup"))
	input.menu_down   = input.menu_down:addButton(gb(id, "dpdown"))
	input.menu_left   = input.menu_left:addButton(gb(id, "dpleft"))
	input.menu_right  = input.menu_right:addButton(gb(id, "dpright"))
end

function input.configure()
	-- Shorthand functions
	-- Define inputs
	local k = tactile.keys
	local m = function(button)
		return function() return love.mouse.isDown(button) end
	end

	local t = {
		-- Move
		move_x = tactile.newControl():addButtonPair(k("a", "left"), k("d", "right")),
		move_y = tactile.newControl():addButtonPair(k("w", "up"), k("s", "down")),

		-- Camera
		camera_x = tactile.newControl(),
		camera_y = tactile.newControl(),

		-- Actions
		attack          = tactile.newControl():addButton(k("z", "k")):addButton(m(1)),
		dodge           = tactile.newControl():addButton(k("x", "l")):addButton(m(2)),
		use_item        = tactile.newControl():addButton(k("return", "space")):addButton(m(3)),
		cycle_item_up   = tactile.newControl():addButton(k("kp-", "q")),
		cycle_item_down = tactile.newControl():addButton(k("kp+", "e")),
		pause           = tactile.newControl():addButton(k("p")),

		-- Menu
		menu_back   = tactile.newControl():addButton(k("escape")),
		menu_action = tactile.newControl():addButton(k("return")),
		menu_up     = tactile.newControl():addButton(k("up", "w")),
		menu_down   = tactile.newControl():addButton(k("down", "s")),
		menu_left   = tactile.newControl():addButton(k("left", "a")),
		menu_right  = tactile.newControl():addButton(k("right", "d"))
	}

	local fields = {}
	for _, v in pairs(t) do
		table.insert(fields, v)
	end

	local sticks = love.joystick.getJoysticks()
	for i, js in ipairs(sticks) do
		if js:isGamepad() then
			register_gamepad(t, i)
		end
	end

	-- fuck off I'll deadzone this myself
	t.move_x.deadzone = deadzone
	t.move_y.deadzone = deadzone

	-- Process input
	t.update = function(self)
		for _, i in ipairs(fields) do
			i:update()
		end
	end

	t.deadzone = deadzone

	return t
end

return input
