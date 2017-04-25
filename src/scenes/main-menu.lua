local anchor   = require "anchor"
local tiny     = require "tiny"
local cpml     = require "cpml"
local i18n     = require "i18n"
local memoize  = require "memoize"
local load     = require "utils.load-files"
local scroller = require "utils.scroller"
local get_font = memoize(love.graphics.newFont)
local topx     = love.window.toPixels
local scene    = {}

function scene:enter(_, fromz)
	-- Prepare language
	self.language = i18n()
	self.language:set_fallback("en")
	self.language:set_locale(_G.PREFERENCES.language)
	self.language:load(string.format("assets/locales/%s.lua", _G.PREFERENCES.language))

	local bgm = load.sound("assets/music/ambience.ogg")
	bgm:setVolume(_G.PREFERENCES.bgm_volume / 2)
	bgm:play()

	local items = {
		{ label = "new-game", action = function()
			local image = "assets/cutscenes/wake-1.png"
			local text, duration = self.language:get("cutscene-wake-1")
			_G.SCENE.switch(require "scenes.cutscene", {
				{ image=image, text=text, duration=duration },
				player = {
					sanity   = 10,
					hp       = 10000,
					start_hp = 10000,
					night    = 0,
				},
				wake = true
			})
		end },
		{ label = "options", action = function()
			_G.SCENE.switch(require "scenes.options-menu")
		end },
		{ label = "credits", action = function()
			_G.SCENE.switch(require "scenes.credits")
		end },
		{ label = "exit", action = function()
			love.event.quit()
		end }
	}

	local transform = function(self, offset, count, index)
		self.x = 0
		self.y = math.floor(offset * topx(40))
	end

	self.scroller = scroller(items, {
		fixed        = true,
		size         = { w = topx(200), h = topx(40) },
		sounds       = {
			prev   = load.sound("assets/sfx/bloop.wav"),
			next   = load.sound("assets/sfx/bloop.wav"),
			select = load.sound("assets/sfx/bloop.wav")
		},
		transform_fn = transform,
		position_fn  = function()
			return anchor:left() + topx(100), anchor:center_y() - topx(50)
		end
	})

	for _, v in pairs(self.scroller.sounds) do
		v:setVolume(_G.PREFERENCES.sfx_volume)
	end

	self.logo = love.graphics.newImage("assets/textures/game-logo.png")
	love.graphics.setBackgroundColor(0, 0, 0)

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

	if fromz and fromz.renderer.camera.orientation then
		self.renderer.camera.orientation = fromz.renderer.camera.orientation
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
	self.world:clearEntities()
	self.world:clearSystems()
	self.world:refresh()
	self.world = nil
end

function scene:go()
	local item = self.scroller:get()
	if item.action then
		item.action()
		return
	end
	error "No action for the current item"
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
	if k == "return" then
		self:go()
		return
	end
	if k == "escape" then
		_G.SCENE.switch(require "scenes.splash")
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
			self:go()
		end
	end
end

function scene:update(dt)
	self.renderer.camera.orientation = cpml.quat.rotate(-dt * 0.025, cpml.vec3.unit_z) * self.renderer.camera.orientation
	self.renderer.camera.direction = self.renderer.camera.orientation * cpml.vec3.unit_y

	self.world:update(dt)

	self.scroller:hit(love.mouse.getPosition())
	self.scroller:update(dt)
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

	-- Draw highlight bar
	love.graphics.setColor(255, 255, 255, 50)
	love.graphics.rectangle("fill",
		self.scroller.cursor_data.x,
		self.scroller.cursor_data.y,
		self.scroller.size.w,
		self.scroller.size.h
	)

	-- Draw items
	love.graphics.setColor(255, 255, 255)
	for _, item in ipairs(self.scroller.data) do
		local text = self.language:get(item.label)
		love.graphics.print(text, item.x + topx(10), item.y + topx(10))
	end
end

return scene
