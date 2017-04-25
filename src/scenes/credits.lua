local anchor = require "anchor"
local load   = require "utils.load-files"
local timer  = require "timer"
local gs     = {}

function gs:enter(from)
	love.audio.setDistanceModel("none")

	self.bgm = load.sound("assets/credits/credits.ogg")
	self.bgm:setVolume(_G.PREFERENCES.bgm_volume*0.5)
	self.bgm:play()

	self.frame  = 1
	self.frames = {
		load.texture("assets/cutscenes/fin-1.png"),
		load.texture("assets/cutscenes/fin-2.png")
	}
	self.scale  = love.graphics.getHeight() / self.frames[1]:getHeight()

	self.timer = timer.new()
	self.time  = 0
	self.crash = love.filesystem.read("assets/crash.log")   or "add crash.log"
	self.lines = love.filesystem.read("assets/credits.txt") or "add credits.txt"
	self.state = { opacity = 1, thanks_opacity = 0, volume = 0 }

	self.timer:every(0.5, function()
		self.frame = self.frame + 1
		if self.frame > #self.frames then
			self.frame = 1
		end
	end)

	self.timer:script(function(wait)
		self.timer:tween(2.0, self.state, { opacity = 0 }, 'out-quad')
		self.timer:tween(5.0, self.state, { volume = 0.25 }, 'out-quad')
		wait(15)
		self:transition_out()
	end)

	self.text         = ""
	self.scroll_speed = 400
	self.font         = love.graphics.newFont("assets/fonts/NotoSans-Regular.ttf", 16)

	local width, height = self.font:getWrap(self.lines, anchor:width())
	self.text_width     = width
	self.text_height    = #height * self.font:getHeight()

	love.graphics.setBackgroundColor(0, 0, 0)
end

function gs:transition_out()
	self.timer:script(function(wait)
		self.timer:tween(1, self.state, { opacity = 1, volume = 0 }, 'in-out-quad')
		wait(1)
		_G.SCENE.switch(require("scenes.main-menu"))
	end)
end

function gs:mousepressed(_, _, button)
	if self.input_locked then
		return
	end
	if button == 1 then
		self:transition_out()
	end
end

function gs:update(dt)
	self.timer:update(dt)
	self.time = self.time + dt
	self.text = self.crash:sub(self.time*self.scroll_speed,self.time*self.scroll_speed+1700)
end

function gs:draw()
	love.graphics.setColor(255, 255, 255)
	love.graphics.setFont(self.font)
	love.graphics.draw(self.frames[self.frame], 0, 0, 0, self.scale, self.scale)

	-- Credits
	love.graphics.setColor(0, 0, 0)
	love.graphics.printf(
		self.lines,
		anchor:left()+1,
		anchor:center_y() - self.text_height / 2 +1,
		anchor:width() / 2,
		"center"
	)

	love.graphics.setColor(0, 81, 215)
	love.graphics.printf(
		self.lines,
		anchor:left(),
		anchor:center_y() - self.text_height / 2,
		anchor:width() / 2,
		"center"
	)

	-- Crashlog
	love.graphics.setColor(0, 0, 0)
	love.graphics.printf(
		self.text,
		anchor:center_x()+1,
		anchor:top()+1,
		anchor:width() / 2,
		"left"
	)

	love.graphics.setColor(0, 81, 215)
	love.graphics.printf(
		self.text,
		anchor:center_x(),
		anchor:top(),
		anchor:width() / 2,
		"left"
	)

	-- Overlay
	love.graphics.setColor(0, 0, 0, 255 * self.state.opacity)
	love.graphics.rectangle(
		"fill", 0, 0,
		love.graphics.getWidth(),
		love.graphics.getHeight()
	)
end

function gs:keypressed(k)
	if k == "escape" or k == "return" then
		self:transition_out()
	end
end

function gs:leave()
	self.bgm:stop()
end

return gs
