-- we need to require these before fire.save_the_world(), to prevent crashes
--hue
require "cpml"
require "iqm"
require "love3d".import(false)

local anchor = require "anchor"
local fire   = require "fire"
fire.save_the_world()

_G.EVENT = require "signal".new()
_G.SCENE = require "gamestate"

function love.load(args)
	local screen = "scenes.splash"
	local check_screen = false
	for _, v in pairs(args) do
		if v == "--debug" then
			_G.FLAGS.debug_mode = true
		end
		if v == "--hud" then
			_G.FLAGS.show_perfhud = true
		end
		if v == "--screen" then
			check_screen = true
		end
		if check_screen and not v:find("%-%-") then
			screen = string.format("scenes.%s", v)
			check_screen = false
		end
	end

	if _G.FLAGS.debug_mode then
		_G.imgui = require "imgui"
		_G.imgui.PushStyleColor("WindowBg", 0.0, 0.0, 0.0, 0.98)
		_G.imgui.PushStyleColor("ScrollbarBg", 0.2, 0.25, 0.3, 0.0)
		_G.imgui.PushStyleColor("ScrollbarGrab", 1.0, 1.0, 1.0, 0.3)
		_G.imgui.PushStyleColor("ScrollbarGrabHovered", 1.0, 0.85, 1.0, 0.5)
		_G.imgui.PushStyleColor("ScrollbarGrabActive", 1.0, 0.5, 0.69, 0.4)
		_G.imgui.PushStyleColor("CheckMark", 0.15, 0.0, 1.0, 0.91)
		_G.imgui.PushStyleColor("FrameBg", 0.94, 1.0, 1.0, 0.16)
		_G.imgui.PushStyleColor("Text", 1.0, 1.0, 1.0, 1.0)
		_G.imgui.PushStyleColor("PlotHistogram", 0.78, 0.21, 0.21, 1.0)
	else
		_G.imgui = setmetatable({}, { __index = function()
			return function() end
		end })
	end

	anchor:set_overscan(0.1)
	anchor:update()

	_G.SCENE.registerEvents {
		"update", "keypressed", "keyreleased", "wheelmoved",
		"mousepressed", "mousereleased", "mousemoved",
		"touchpressed", "touchreleased", "touchmoved",
		"textinput"
	}

	_G.DEFAULT_PREFERENCES = {
		fullscreen    = false,
		vsync         = true,
		msaa          = true,
		master_volume = 1.0,
		bgm_volume    = 1.0,
		sfx_volume    = 1.0,
		language      = "en"
	}

	_G.PREFERENCES = {}

	-- Load preferences
	if love.filesystem.isFile("preferences.json") then
		local json   = require "dkjson"
		local file   = love.filesystem.read("preferences.json")
		local decode = json.decode(file)
		-- copy default prefs first, in case some have been added.
		for k, v in pairs(_G.DEFAULT_PREFERENCES) do
			_G.PREFERENCES[k] = v
		end
		for k, v in pairs(decode) do
			_G.PREFERENCES[k] = v
		end
	else
		for k, v in pairs(_G.DEFAULT_PREFERENCES) do
			_G.PREFERENCES[k] = v
		end
	end

	local w, h, mode = love.window.getMode()
	mode.msaa        = _G.PREFERENCES.msaa and 4 or 1
	mode.vsync       = _G.PREFERENCES.vsync
	mode.fullscreen  = _G.PREFERENCES.fullscreen
	love.window.setMode(w, h, mode)

	_G.SCENE.switch(require(screen))
end

function love.quit()
	if _G.imgui then
		_G.imgui.ShutDown()
	end
end

function love.update(dt)
	anchor:update()
	if _G.imgui then
		_G.imgui.NewFrame()
	end

	if _G.FLAGS.debug_mode and not love.mouse.getRelativeMode() then
		if imgui.BeginMainMenuBar() then
			local top = _G.SCENE.current()
			if top.menu then
				top:menu()
			end
			imgui.EndMainMenuBar()
		end
	end
end

local function draw_overscan()
	love.graphics.setColor(180, 180, 180, 200)
	love.graphics.setLineStyle("rough")
	love.graphics.line(anchor:left(), anchor:center_y(), anchor:right(), anchor:center_y())
	love.graphics.line(anchor:center_x(), anchor:top(), anchor:center_x(), anchor:bottom())
	love.graphics.setColor(255, 255, 255, 255)
	love.graphics.rectangle("line", anchor:bounds())
end

function love.draw()
	local top = _G.SCENE.current()

	if not top.draw then
		fire.print("no draw function on the top screen.", 0, 0, "red")
	else
		top:draw()
	end

	love.graphics.setColor(255, 255, 255)
	if _G.imgui then
		_G.imgui.Render()
	end

	if _G.FLAGS.show_overscan then
		draw_overscan()
	end
end
