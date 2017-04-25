local anchor     = require "anchor"
local i18n       = require "i18n"
local memoize    = require "memoize"
local scroller   = require "utils.scroller"
local get_font   = memoize(love.graphics.newFont)
local topx       = love.window.toPixels
local scene      = {}

function scene:enter()
	local transform = function(self, offset, count, index)
		self.x = 0
		self.y = math.floor(offset * topx(40))
	end

	self.menu_selected = "main"

	-- Prepare language
	self.language = i18n()
	self.language:set_fallback("en")
	self.language:set_locale(_G.PREFERENCES.language)

	-- List of menus and their options
	self.menus = {
		main = {
			{ label = "Model Viewer", i18n = false, action = function()
				_G.SCENE.switch(require "scenes.model-viewer")
			end },
			{ label = "Cheats", i18n = false, action = function()
				self.menu_selected = "cheats"
			end },
			{ label = "", skip = true },
			{ label = "return-menu", i18n = true, action = function()
				_G.SCENE.switch(require "scenes.main-menu")
			end }
		},

		cheats = {
			{ label = "Nothing to see here", i18n = false, skip = true },
			{ label = "back", i18n = true, action = function()
				self.scroller:reset()
				self.menu_selected = "main"
			end }
		}
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

		cheats = scroller(self.menus.cheats, {
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
			else
				love.graphics.print(item.label, item.x + topx(10), item.y + topx(10))
			end
		end
	end
end

return scene
