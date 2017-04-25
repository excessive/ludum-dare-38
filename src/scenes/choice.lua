local anchor = require "anchor"
local i18n   = require "i18n"
local timer  = require "timer"
local load   = require "utils.load-files"
local scene  = {}

--[[

data = {
	[1] = { image, text, duration },
	[2] = { image, text, duration },
	[3] = { image, text, duration },
	player = { sanity, hp, start_hp, night }
}

--]]

function scene:enter(_, data)
	-- Prepare language
	self.language = i18n()
	self.language:set_fallback("en")
	self.language:set_locale(_G.PREFERENCES.language)
	self.language:load(string.format("assets/locales/%s.lua", _G.PREFERENCES.language))

	self.new_data        = {}
	self.new_data.player = data or { sanity=10, hp=10000, start_hp=10000, night=1 }

	local bgm = load.sound("assets/music/ambience.ogg")
	bgm:setVolume(_G.PREFERENCES.bgm_volume)
	bgm:play()

	-- If you won the previous phase
	if self.new_data.player.scared then
		self.image = load.texture("assets/cutscenes/wake-2.png")
		self.new_data.player.scared = nil
	else
		self.image = load.texture("assets/cutscenes/wake-1.png")
	end

	self.overlay  = { opacity=0 }
	self.scale    = love.graphics.getHeight() / self.image:getHeight()
	self.font     = load.font("assets/fonts/NotoSans-Regular.ttf", 20)
	self.choices  = {
		{ name="games",   sanity=3 },
		{ name="web",     sanity=-3 },
		{ name="tv",      sanity=3 },
		{ name="news",    sanity=-3 },
		{ name="clean",   sanity=3 },
		{ name="outside", sanity=-3 }
	}
	self.selected = { { name="phone" } }
end

function scene:leave()
	self.new_data = nil
end

function scene:mousepressed(x, y, button)
	if button ~= 1 or #self.selected == 2 then return end

	local function aabb(x, y, w, h, mx, my)
		return
			mx >= x     and
			my >= y     and
			mx <= x + w and
			my <= y + h
	end

	for k, choice in ipairs(self.choices) do
		if aabb(
			anchor:left(),
			anchor:top() + 40 + (k-1) * 40 + 1,
			400,
			40,
			x,
			y
		) then
			table.insert(self.selected, choice)
			break
		end
	end

	if #self.selected == 2 then
		for _, choice in ipairs(self.selected) do
			if choice.name == "phone" then
				local name = choice.name .. "-" .. self.new_data.player.night
				local text, duration = self.language:get("cutscene-"..name)
				table.insert(self.new_data, { image="assets/cutscenes/"..choice.name..".png", text=text, duration=duration })
			else
				local text, duration = self.language:get("cutscene-"..choice.name)
				table.insert(self.new_data, { image="assets/cutscenes/"..choice.name..".png", text=text, duration=duration })
				self.new_data.player.sanity = self.new_data.player.sanity + choice.sanity

				-- Good choices also heal you!
				if choice.sanity > 0 then
					self.new_data.player.hp       = self.new_data.player.hp       + 1000
					self.new_data.player.start_hp = self.new_data.player.start_hp + 1000
				end
			end
		end

		local text, duration = self.language:get("cutscene-sleep")
		table.insert(self.new_data, { image="assets/cutscenes/sleep.png", text=text, duration=duration })

		self.new_data.player.sanity   = math.max(math.min(20,    self.new_data.player.sanity),   0)
		self.new_data.player.hp       = math.max(math.min(10000, self.new_data.player.hp),       0)
		self.new_data.player.start_hp = math.max(math.min(10000, self.new_data.player.start_hp), 0)

		timer.script(function(wait)
			wait(0.25)

			-- Fade out
			timer.tween(0.5, self.overlay, { opacity=255 })
			wait(1)

			_G.SCENE.switch(require "scenes.cutscene", self.new_data)
		end)
	end
end

function scene:update(dt)
	timer.update(dt)
end

function scene:draw()
	love.graphics.setFont(self.font)
	local text, width

	-- Cutscene
	love.graphics.setColor(255, 255, 255)
	love.graphics.draw(self.image, 0, 0, 0, self.scale, self.scale)

	-- List of choices
	love.graphics.setColor(0, 0, 0, 192)
	love.graphics.rectangle("fill", anchor:left(), anchor:top(), 300, 40)
	love.graphics.setColor(255, 255, 255)
	text  = self.language:get("make-choice")
	width = self.font:getWidth(text)
	love.graphics.print(text, anchor:left() + (300 - width) / 2, anchor:top() + 5)

	for k, choice in ipairs(self.choices) do
		love.graphics.setColor(0, 0, 0, 192)
		love.graphics.rectangle("fill", anchor:left(), anchor:top() + k * 40, 300, 40)
		love.graphics.setColor(255, 255, 255)
		text = self.language:get("choice-"..choice.name)
		love.graphics.print(text, anchor:left() + 20, anchor:top() + k * 40 + 5)
	end

	-- Fade
	if self.overlay.opacity > 0 then
		love.graphics.setColor(0, 0, 0, self.overlay.opacity)
		local w, h = love.graphics.getDimensions()
		love.graphics.rectangle("fill", 0, 0, w, h)
	end
end

return scene
