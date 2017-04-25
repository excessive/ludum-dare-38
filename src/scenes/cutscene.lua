local anchor = require "anchor"
local timer  = require "timer"
local load   = require "utils.load-files"
local scene  = {}

function scene:enter(_, data)
	self.overlay  = { opacity = 255 }
	self.subtitle = { font    = load.font("assets/fonts/NotoSans-Bold.ttf", 25), text = "", opacity = 0 }
	self.data     = data[1]
	self.buffer   = 0.5
	self.scale    = love.graphics.getHeight() / load.texture(self.data.image):getHeight()

	if self.data.image == "assets/cutscenes/end-2.png" or
		self.data.image == "assets/cutscenes/end-3.png" then
		data.wake = false
		self.overlay.opacity = 0
	end

	-- Adjust gamestate
	if self.data.image == "assets/cutscenes/wake-1.png" and data.wake then
		data.player.night    = data.player.night + 1
		data.player.start_hp = data.player.hp

		-- If you beat all 7 phases
		if data.player.night > 7 then
			local text, duration
			local fin = { "end-1", "end-2", "end-3" }

			-- Prepare language
			local i18n     = require "i18n"
			local language = i18n()
			language:set_fallback("en")
			language:set_locale(_G.PREFERENCES.language)
			language:load(string.format("assets/locales/%s.lua", _G.PREFERENCES.language))

			for _, f in ipairs(fin) do
				text, duration = language:get("cutscene-"..f)
				table.insert(data, { image="assets/cutscenes/"..f..".png", text=text, duration=duration })
			end
		end
	elseif self.data.image == "assets/cutscenes/wake-2.png" then
		data.player.hp = data.player.start_hp
		data.player.scared    = true
	end

	-- Determine cutscene bgm
	load.sound("assets/music/ptsd.ogg"):stop()
	local bgm

	if self.data.image == "assets/cutscenes/wake-1.png" and data.player.night <= 7 then
		bgm = load.sound("assets/music/ambience.ogg")
	end

	if self.data.image == "assets/cutscenes/wake-2.png" then
		bgm = load.sound("assets/sfx/alarm.wav")
	end

	if self.data.image == "assets/cutscenes/outside.png" then
		load.sound("assets/music/ambience.ogg"):stop()
		bgm = load.sound("assets/music/ptsd.ogg")
	end

	if self.data.image == "assets/cutscenes/sleep.png" then
		load.sound("assets/music/ptsd.ogg"):stop()
		load.sound("assets/music/ambience.ogg"):stop()
		bgm = load.sound("assets/music/battle-theme.ogg")
	end

	if self.data.image == "assets/cutscenes/end-1.png" then
		bgm = load.sound("assets/music/fanfare.ogg")
	end


	if bgm then
		bgm:setVolume(_G.PREFERENCES.bgm_volume)
		bgm:play()
	end

	timer.script(function(wait)
		-- Fade in
		if not data.player.scared then
			timer.tween(0.5, self.overlay, { opacity=0 })
			wait(1)
		else
			self.overlay.opacity = 0
		end

		-- Display subtitle
		self:draw_text(self.data.text, self.data.duration)
		wait(0.25)

		wait(self.data.duration + self.buffer)

		-- pop cutscene
		table.remove(data, 1)

		-- go to next cutscene
		if #data > 0 then
			-- Fade out
			if self.data.image ~= "assets/cutscenes/end-1.png" and
				self.data.image ~= "assets/cutscenes/end-2.png" then
				timer.tween(0.5, self.overlay, { opacity=255 })
				wait(1)
			end
			_G.SCENE.switch(require "scenes.cutscene", data)
		else
			if data.wake then
				_G.SCENE.switch(require "scenes.choice", data.player)
				return
			end

			-- Fade out
			timer.tween(0.5, self.overlay, { opacity=255 })
			wait(1)

			if data.player.night > 7 then
				_G.SCENE.switch(require "scenes.credits")
				return
			end

			_G.SCENE.switch(require "scenes.play", data.player)
		end
	end)
end

function scene:update(dt)
	timer.update(dt)
end

function scene:draw()
	-- Cutscene
	love.graphics.setColor(255, 255, 255)
	love.graphics.draw(load.texture(self.data.image), 0, 0, 0, self.scale, self.scale)

	-- Subtitles
	local o = love.graphics.getFont()
	love.graphics.setFont(self.subtitle.font)
	love.graphics.setColor(0, 0, 0, self.subtitle.opacity)
	love.graphics.printf(
		self.subtitle.text,
		anchor:left() - 2,
		anchor:bottom() - 52,
		anchor:width(),
		"center"
	)
	love.graphics.printf(
		self.subtitle.text,
		anchor:left(),
		anchor:bottom() - 52,
		anchor:width(),
		"center"
	)
	love.graphics.printf(
		self.subtitle.text,
		anchor:left() + 2,
		anchor:bottom() - 52,
		anchor:width(),
		"center"
	)
	love.graphics.printf(
		self.subtitle.text,
		anchor:left() + 2,
		anchor:bottom() - 50,
		anchor:width(),
		"center"
	)
	love.graphics.printf(
		self.subtitle.text,
		anchor:left() + 2,
		anchor:bottom() - 48,
		anchor:width(),
		"center"
	)
	love.graphics.printf(
		self.subtitle.text,
		anchor:left(),
		anchor:bottom() - 48,
		anchor:width(),
		"center"
	)
	love.graphics.printf(
		self.subtitle.text,
		anchor:left() - 2,
		anchor:bottom() - 48,
		anchor:width(),
		"center"
	)
	love.graphics.printf(
		self.subtitle.text,
		anchor:left() - 2,
		anchor:bottom() - 50,
		anchor:width(),
		"center"
	)
	love.graphics.setColor(255, 255, 255, self.subtitle.opacity)
	love.graphics.printf(
		self.subtitle.text,
		anchor:left(),
		anchor:bottom() - 50,
		anchor:width(),
		"center"
	)
	love.graphics.setFont(o)
	love.graphics.setColor(255, 255, 255, 255)

	-- Fade
	if self.overlay.opacity > 0 then
		love.graphics.setColor(0, 0, 0, self.overlay.opacity)
		local w, h = love.graphics.getDimensions()
		love.graphics.rectangle("fill", 0, 0, w, h)
	end
end

function scene:draw_text(text, duration)
	self.subtitle.text    = text or ""
	self.subtitle.opacity = 0

	timer.script(function(wait)
		timer.tween(0.25, self.subtitle, { opacity=255 }, 'in-cubic')
		wait(duration + 0.25)
		timer.tween(0.25, self.subtitle, { opacity=0 }, 'out-cubic', function()
			self.subtitle.text = ""
		end)
	end)
end

return scene
