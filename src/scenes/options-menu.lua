local anchor     = require "anchor"
local tiny       = require "tiny"
local cpml       = require "cpml"
local i18n       = require "i18n"
local json       = require "dkjson"
local memoize    = require "memoize"
local load       = require "utils.load-files"
local ringbuffer = require "utils.ringbuffer"
local scroller   = require "utils.scroller"
local slider     = require "utils.slider"
local get_font   = memoize(love.graphics.newFont)
local topx       = love.window.toPixels
local scene      = {}

local function apply_graphics_options(prefs)
	local w, h, mode = love.window.getMode()
	mode.msaa        = prefs.msaa and 4 or 1
	mode.vsync       = prefs.vsync
	mode.fullscreen  = prefs.fullscreen
	love.window.setMode(w, h, mode)
end

function scene:enter(from)
	local transform = function(self, offset)
		self.x = 0
		self.y = math.floor(offset * topx(40))
	end

	self.volume_slider = slider(0, 1, 0, 100)
	self.menu_selected = "main"

	-- Prepare language
	self.language = i18n()
	self.language:set_fallback("en")
	self.language:set_locale(_G.PREFERENCES.language)

	-- List of languages
	local languages = {}
	local files = love.filesystem.getDirectoryItems("assets/locales")
	for _, file in ipairs(files) do
		local name, ext = file:match("([^/]+)%.([^%.]+)$")

		if ext == "lua" then
			table.insert(languages, name)
			self.language:load(string.format("assets/locales/%s.lua", name))
		end
	end

	-- Select current language in buffer
	self.languages = ringbuffer(languages)
	while _G.PREFERENCES.language ~= self.languages:get() do
		self.languages:next()

		-- Cycled through all languages, preference is wrong, set to English
		if self.languages.current == 1 then
			_G.PREFERENCES.language = "en"
		end
	end

	local prefs = {}
	for k, v in pairs(_G.PREFERENCES) do
		prefs[k] = v
	end

	-- List of menus and their options
	self.menus = {
		main = {
			{ label = "graphics", i18n = true, action = function()
				self.menu_selected = "graphics"
			end },
			{ label = "audio", i18n = true, action = function()
				self.menu_selected = "audio"
			end },
			--{ label = "language", i18n = true, action = function()
			--	self.menu_selected = "language"
			--end },
			{ label = "reset-default", i18n = true, action = function()
				for k, v in pairs(_G.DEFAULT_PREFERENCES) do
					_G.PREFERENCES[k] = v
				end
			end },
			{ label = "", skip = true },
			{ label = "return-menu", i18n = true, action = function()
				_G.SCENE.switch(require "scenes.main-menu", self)
			end }
		},

		graphics = {
			{ label = "toggle-fullscreen", i18n = true, action = function()
				prefs.fullscreen = not prefs.fullscreen
			end },
			{ label = "toggle-vsync", i18n = true, action = function()
				prefs.vsync = not prefs.vsync
			end },
			{ label = "toggle-msaa", i18n = true, action = function()
				prefs.msaa = not prefs.msaa
			end },
			{ label = "", skip = true },
			{ label = "apply", i18n = true, action = function()
				apply_graphics_options(prefs)
				for k, v in pairs(prefs) do
					_G.PREFERENCES[k] = v
				end
			end },
			{ label = "back", i18n = true, action = function()
				apply_graphics_options(_G.PREFERENCES)
				self.scroller:reset()
				self.menu_selected = "main"
			end }
		},

		audio = {
			{ label = "master-volume", i18n = true, skip = true },
			{
				label = "%0.0f%%", volume = "master",
				prev = function()
					_G.PREFERENCES.master_volume = cpml.utils.clamp(_G.PREFERENCES.master_volume - 0.05, 0, 1)
				end,
				next = function()
					_G.PREFERENCES.master_volume = cpml.utils.clamp(_G.PREFERENCES.master_volume + 0.05, 0, 1)
				end
			},
			{ label = "bgm-volume", i18n = true, skip = true },
			{
				label = "%0.0f%%", volume = "bgm",
				prev = function()
					_G.PREFERENCES.bgm_volume = cpml.utils.clamp(_G.PREFERENCES.bgm_volume - 0.05, 0, 1)
				end,
				next = function()
					_G.PREFERENCES.bgm_volume = cpml.utils.clamp(_G.PREFERENCES.bgm_volume + 0.05, 0, 1)
				end
			},
			{ label = "sfx-volume", i18n = true, skip = true },
			{
				label = "%0.0f%%", volume = "sfx",
				prev = function()
					_G.PREFERENCES.sfx_volume = cpml.utils.clamp(_G.PREFERENCES.sfx_volume - 0.05, 0, 1)
				end,
				next = function()
					_G.PREFERENCES.sfx_volume = cpml.utils.clamp(_G.PREFERENCES.sfx_volume + 0.05, 0, 1)
				end
			},
			{ label = "", skip = true },
			{ label = "back", i18n = true, action = function()
				self.scroller:reset()
				self.menu_selected = "main"
			end }
		},

		language = {
			{ label = "toggle-language", i18n = true, skip = true },
			{
				label = "%s", language = true,
				prev = function()
					self.language:set_locale(self.languages:prev())
					_G.PREFERENCES.language = self.language:get_locale()
				end,
				next = function()
					self.language:set_locale(self.languages:next())
					_G.PREFERENCES.language = self.language:get_locale()
				end
			},
			{ label = "", skip = true },
			{ label = "back", i18n = true, action = function()
				self.scroller:reset()
				self.menu_selected = "main"
			end }
		},
	}

	local sounds = {
		prev   = love.audio.newSource("assets/sfx/bloop.wav"),
		next   = love.audio.newSource("assets/sfx/bloop.wav"),
		select = love.audio.newSource("assets/sfx/bloop.wav")
	}
	for _, v in pairs(sounds) do
		v:setVolume(_G.PREFERENCES.sfx_volume)
	end

	-- List of menu scrollers
	self.scrollers = {
		main = scroller(self.menus.main, {
			fixed        = true,
			size         = { w = topx(200), h = topx(40) },
			sounds       = sounds,
			transform_fn = transform,
			position_fn  = function()
				return anchor:left() + topx(100), anchor:center_y() - topx(50)
			end
		}),

		graphics = scroller(self.menus.graphics, {
			fixed        = true,
			size         = { w = topx(200), h = topx(40) },
			sounds       = sounds,
			transform_fn = transform,
			position_fn  = function()
				return anchor:left() + topx(300), anchor:center_y() - topx(50)
			end
		}),

		audio = scroller(self.menus.audio, {
			fixed        = true,
			size         = { w = topx(200), h = topx(40) },
			sounds       = sounds,
			transform_fn = transform,
			position_fn  = function()
				return anchor:left() + topx(300), anchor:center_y() - topx(50)
			end
		}),

		language = scroller(self.menus.language, {
			fixed        = true,
			size         = { w = topx(200), h = topx(40) },
			sounds       = sounds,
			transform_fn = transform,
			position_fn  = function()
				return anchor:left() + topx(300), anchor:center_y() - topx(50)
			end
		}),
	}

	self.active_scrollers = {}

	self.scroller = self.scrollers[self.menu_selected]
	self.logo     = love.graphics.newImage("assets/textures/game-logo.png")

	-- New world
	self.world = tiny.world()

	-- Load level into world
	load.map("assets/levels/level.lua", self.world)

	self.renderer        = require("systems.render")()
	self.renderer.camera = require("camera") {
		fov          = 75,
		orbit_offset = cpml.vec3(0, 0, 0),
		offset       = cpml.vec3(0, 0, 0),
		exposure     = 0.025,
		distortion   = 0
	}

	if from.renderer.camera.orientation then
		self.renderer.camera.orientation = from.renderer.camera.orientation
	end

	self.world:add(require "systems.matrix")
	self.world:add(require "systems.capsule-update")
	self.world:add(require "systems.particle")
	self.world:add(self.renderer)

	-- Particles (debris)
	self.world:addEntity {
		transform = {
			position = cpml.vec3(0, 0, -5)
		},
		particle = {
			spawn_rate   = 0.25,
			spawn_radius = 15,
			lifetime     = { 30, 50 },
			spread       = 2.0,
			limit        = 800,
			velocity     = cpml.vec3(0, 0, 3),
			texture = load.texture("assets/textures/particle.png")
		},
		size  = 0.25,
		color = { 0.5, 0.8, 0.9 }
	}

	-- Particles (bubbles)
	self.world:addEntity {
		transform = {
			position = cpml.vec3(0, 0, -5)
		},
		particle = {
			spawn_rate   = 0.45,
			spawn_radius = 15,
			lifetime     = { 30, 50 },
			spread       = 0.75,
			limit        = 60,
			velocity     = cpml.vec3(0, 0, 4),
			texture = load.texture("assets/textures/bubble.png")
		},
		size    = 0.35,
		color   = { 0.75, 0.9, 1.0 }
	}
	self.world:refresh()
end

function scene:leave()
	love.filesystem.write("preferences.json", json.encode(_G.PREFERENCES))

	self.world:clearEntities()
	self.world:clearSystems()
	self.world:refresh()
	self.world = nil
end

function scene:scroller_action()
	local item = self.scroller:get()
	if item.action then
		item.action()
	end
end

function scene:scroller_prev()
	local item = self.scroller:get()
	if item.prev then
		item.prev()
	end
end

function scene:scroller_next()
	local item = self.scroller:get()
	if item.next then
		item.next()
	end
end

function scene:keypressed(k)
	if k == "up" then
		self.scroller:prev()
		return
	end
	if k == "down" then
		self.scroller:next()
		return
	end
	if k == "left" then
		self:scroller_prev()
		return
	end
	if k == "right" then
		self:scroller_next()
		return
	end
	if k == "return" then
		self:scroller_action()
		return
	end
	if k == "escape" then
		if self.menu_selected == "main" then
			_G.SCENE.switch(require "scenes.main-menu")
		else
			self.menu_selected = "main"
		end
		return
	end
end

function scene:touchpressed(id, x, y)
	self:mousepressed(x, y, 1)
end

function scene:touchreleased(id, x, y)
	self:mousereleased(x, y, 1)
end

function scene:mousepressed(x, y, b)
	if self.scroller:hit(x, y, b == 1) then
		self.ready = self.scroller:get()
	end
end

function scene:mousereleased(x, y, b)
	if not self.ready then
		return
	end

	if self.scroller:hit(x, y, b == 1) then
		if self.ready == self.scroller:get() then
			self:scroller_action()
		end
	end
end

function scene:update(dt)
	self.renderer.camera.orientation = cpml.quat.rotate(-dt * 0.025, cpml.vec3.unit_z) * self.renderer.camera.orientation
	self.renderer.camera.direction = self.renderer.camera.orientation * cpml.vec3.unit_y

	self.world:update(dt)

	self.scroller = self.scrollers[self.menu_selected]
	self.scroller:hit(love.mouse.getPosition())

	-- Get main menu scroller and other scroller if available
	self.active_scrollers = {
		self.scrollers.main,
		self.scrollers[self.menu_selected] ~= self.scrollers.main and self.scrollers[self.menu_selected] or nil
	}

	for _, scroll in ipairs(self.active_scrollers) do
		scroll:update(dt)
	end
end

function scene:draw()
	love.graphics.setColor(255, 255, 255, 255)
	self.renderer:draw()

	-- Draw logo
	local x, y = anchor:left() + topx(100), anchor:center_y() - topx(150)
	local s = love.window.getPixelScale()
	love.graphics.draw(self.logo, x, y, 0, s, s)

	local font = get_font(topx(16))
	love.graphics.setFont(font)

	-- Iterate through scrollers and draw them
	for _, scroll in ipairs(self.active_scrollers) do
		-- Draw highlight bar
		if scroll == self.scroller then
			love.graphics.setColor(255, 255, 255, 50)
		else
			love.graphics.setColor(255, 255, 255, 20)
		end
		love.graphics.rectangle("fill",
			scroll.cursor_data.x,
			scroll.cursor_data.y,
			scroll.size.w,
			scroll.size.h
		)

		-- Draw items
		love.graphics.setColor(255, 255, 255, scroll == self.scroller and 255 or 100)
		for _, item in ipairs(scroll.data) do
			if item.i18n then
				local text = self.language:get(item.label)
				love.graphics.print(text, item.x + topx(10), item.y + topx(10))
			elseif item.language then
				local _, language = self.language:get_locale()
				love.graphics.print(language, item.x + topx(10), item.y + topx(10))
			elseif item.volume then
				local label
				if item.volume == "master" then
					label = string.format(item.label, self.volume_slider:map(_G.PREFERENCES.master_volume))
				elseif item.volume == "bgm" then
					label = string.format(item.label, self.volume_slider:map(_G.PREFERENCES.bgm_volume))
				elseif item.volume == "sfx" then
					label = string.format(item.label, self.volume_slider:map(_G.PREFERENCES.sfx_volume))
				end
				love.graphics.print(label, item.x + topx(10), item.y + topx(10))
			else
				love.graphics.print(item.label, item.x + topx(10), item.y + topx(10))
			end
		end
	end
end

return scene
