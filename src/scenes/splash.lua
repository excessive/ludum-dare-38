local anchor  = require "anchor"
local timer   = require "timer"
local tiny    = require "tiny"

local gs    = {}

function gs:enter()
	self.logos = {
		l3d   = love.graphics.newImage("assets/splash/logo-love3d.png"),
		exmoe = love.graphics.newImage("assets/splash/logo-exmoe.png")
	}
	self.timer = timer.new()
	self.delay = 5.5
	self.overlay = {
		opacity = 255
	}
	self.bgm = {
		volume = 0.5,
		music  = love.audio.newSource("assets/splash/love.ogg")
	}
	self.next_scene = "scenes.main-menu"

	love.graphics.setBackgroundColor(love.math.gammaToLinear(30, 30, 44))
	self.bgm.music:play()
	love.mouse.setVisible(false)

	-- BGM
	self.timer:script(function(wait)
		self.bgm.music:setVolume(self.bgm.volume)
		self.bgm.music:play()
		wait(self.delay)
		self.timer:tween(1.5, self.bgm, {volume = 0}, 'in-quad')
		wait(1.5)
		self.bgm.music:stop()
	end)

	-- Overlay fade
	self.timer:script(function(wait)
		-- Fade in
		self.timer:tween(1.5, self.overlay, {opacity=0}, 'cubic')
		-- Wait a little bit
		wait(self.delay)
		-- Fade out
		self.timer:tween(1.25, self.overlay, {opacity=255}, 'out-cubic')
		-- Wait briefly
		wait(1.5)
		-- Switch
		self.switch = true
	end)
end

function gs:leave()
	love.mouse.setVisible(true)

	self.logos      = nil
	self.timer      = nil
	self.delay      = nil
	self.overlay    = nil
	self.bgm        = nil
	self.next_scene = nil
	self.switch     = nil
end

function gs:update(dt)
	self.timer:update(dt)
	self.bgm.music:setVolume(self.bgm.volume)

	if self.switch then
		self.bgm.music:stop()
		_G.SCENE.switch(require(self.next_scene))
	end
	-- Skip if user wants to get the hell out of here.
	-- if self.world.inputs.game.menu_action:pressed() then
	-- 	self.switch = true
	-- end
end

function gs:draw()
	local cx, cy = anchor:center()

	local lw, lh = self.logos.exmoe:getDimensions()
	love.graphics.setColor(255, 255, 255, 255)
	love.graphics.draw(self.logos.exmoe, cx-lw/2, cy-lh/2 - 84)

	local lw, lh = self.logos.l3d:getDimensions()
	love.graphics.draw(self.logos.l3d, cx-lw/2, cy-lh/2 + 64)

	-- Full screen fade, we don't care about logical positioning for this.
	local w, h = love.graphics.getDimensions()
	love.graphics.setColor(0, 0, 0, self.overlay.opacity)
	love.graphics.rectangle("fill", 0, 0, w, h)
end

return gs
