local anchor = require "anchor"
local tiny   = require "tiny"
local cpml   = require "cpml"
local i18n   = require "i18n"
local timer  = require "timer"
local lume   = require "lume"
local load   = require "utils.load-files"
local imgui  = _G.imgui
local scene  = {}

function scene:enter(_, data)
	love.mouse.setRelativeMode(true)

	self.overlay   = { opacity=255, distortion=0 }
	self.huge_font = load.font("assets/fonts/Make Juice.ttf", 60)
	self.font      = load.font("assets/fonts/NotoSans-Regular.ttf", 20)
	self.bgm       = load.sound("assets/music/battle-theme.ogg")
	data           = data or {}

	-- Prepare language
	self.language = i18n()
	self.language:set_fallback("en")
	self.language:set_locale(_G.PREFERENCES.language)
	self.language:load(string.format("assets/locales/%s.lua", _G.PREFERENCES.language))

	_G.windows = {}
	self.menu = function()
		if imgui.BeginMenu("Info") then
			if imgui.MenuItem("Camera...") then
				_G.windows.camera = not _G.windows.camera
			end
			if imgui.MenuItem("Animations...") then
				_G.windows.animation = not _G.windows.animation
			end
			if imgui.MenuItem("Renderer...") then
				_G.windows.renderflags = not _G.windows.renderflags
			end
			if imgui.MenuItem("Game State...") then
				_G.windows.gamestate = not _G.windows.gamestate
			end
			if imgui.MenuItem("Collisions...") then
				_G.windows.collision_info = not _G.windows.collision_info
			end
			imgui.EndMenu()
		end
	end

	-- New world
	self.world = tiny.world()

	-- Load level into world
	load.map("assets/levels/level.lua", self.world)

	-- Prepare systems
	local pc             = require "systems.player-controller"
	self.renderer        = require("systems.render")()
	self.renderer.camera = require("camera") {
		fov          = 75,
		orbit_offset = cpml.vec3(0, 0, -7),
		offset       = cpml.vec3(0, 0, -2.5),
		exposure     = 0.1,
		distortion   = 1 - (data.sanity or 10) / 20 / 2
	}
	pc.camera = self.renderer.camera

	-- Add systems to world
	self.world:add(pc)
	self.world:add(require "systems.ai")
	self.world:add(require "systems.animation")
	self.world:add(require "systems.matrix")
	self.world:add(require "systems.capsule-update")
	self.world:add(require "systems.particle")
	self.world:add(require "systems.player-collision")
	self.world:add(require "systems.bullet-collision")
	self.world:add(require "systems.enemy-bullet-collision")

	self.world:addSystem(tiny.system {
		update = function()
			local transform = self.player.transform
			local pos = transform.position / 10
			love.audio.setPosition(pos:unpack())
			love.audio.setOrientation(
				transform.direction.x,
				transform.direction.y,
				transform.direction.z,
				0, 0, 1
			)
		end
	})

	self.world:add(self.renderer)

	-- Add entities to world
	local hit_spark = function(particle)
		return {
			transform = {
				position = particle.position
			},
			particle = {
				spawn_rate   = particle.spawn_rate   or 1,
				spawn_radius = particle.spawn_radius or 1,
				lifetime     = particle.lifetime     or 1,
				spread       = particle.spread       or 1,
				limit        = particle.limit        or 100,
				velocity     = particle.velocity,
				texture      = particle.texture,
				update       = particle.update,
				butt         = particle.butt,
				mesh         = particle.mesh
			},
			visible = particle.visible or true,
			color   = particle.color   or { 0.75, 0, 0, 1 },
			size    = particle.size    or 1
		}
	end

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

	self.enemy = self.world:addEntity {
		mesh      = load.model("assets/models/spooky.iqm"),
		animation = load.anims("assets/models/spooky.iqm"),
		ai = {
			target      = false,
			targetting  = false,
			destination = false,
			speed       = 4,
			cooldown    = 2
		},
		combat = {
			hp        = 10000,
			attack    = 21 - (data.sanity or 10),
			iframes   = false,
			attacking = false
		},
		capsules = {
			hit = {
				["root"] = { a = cpml.vec3(), b = cpml.vec3(), radius = 0.85, length = 4 }
			}
		},
		transform = {
			position = cpml.vec3(0, 12, -1.5)
		},
		visible = true
	}
	self.enemy.animation:play(self.enemy.animation:new_track("run"))

	self.player = self.world:addEntity {
		combat = {
			start_hp  = data.start_hp or 10000,
			hp        = data.hp       or 10000,
			attack    = data.sanity   or 10,
			iframes   = false,
			attacking = false
		},
		player = {
			radius   = cpml.vec3(0.25, 0.25, 0.75),
			speed    = 5,
			actions  = {},
			move_len = 0,
			freeze   = false,
			sanity   = data.sanity or 10,
			night    = data.night  or 1
		},
		transform = {
			orientation = cpml.quat(0, 1, 0, 1),
			direction   = cpml.vec3(0, 1, 0),
			position    = cpml.vec3(0, -10, 0),
			velocity    = cpml.vec3(0, 0, 0),
		},
		material = {
			roughness = 0.1
		},
		capsules = {
			hit = {
				["root"] = { a = cpml.vec3(), b = cpml.vec3(), radius = 0.25, length = -1.3 }
			},
			hurt = {}
		},
		visible   = true,
		mesh      = load.model("assets/models/player.iqm"),
		animation = load.anims("assets/models/player.iqm", nil, "assets/markers/player.lua")
	}

	-- Animation tracks
	local actions  = self.player.player.actions
	local anim     = self.player.animation
	actions.attack = anim:new_track("run")
	actions.run    = anim:new_track("run")
	actions.idle   = anim:new_track("idle")
	anim:play(actions.idle)

	-- Sound effects
	self.sfx = {
		swim       = love.audio.newSource("assets/sfx/swim.wav"),
		lights_out = love.audio.newSource("assets/sfx/switch-off.wav"),
		lights_on  = love.audio.newSource("assets/sfx/switch-on.wav"),
		gun_shoot  = love.audio.newSource("assets/sfx/gun-shoot.wav"),
		lazer      = love.audio.newSource("assets/sfx/lazer.wav"),
		harpoon    = love.audio.newSource("assets/sfx/flesh.wav")
	}

	for _, sfx in pairs(self.sfx) do
		sfx:setVolume(_G.PREFERENCES.sfx_volume)
		sfx:setRelative(true)
	end

	-- Register events
	_G.EVENT:register("player attack", function(player)
		if not anim:find_track(actions.attack) then
			anim:transition(actions.attack, 0.2)
		end

		player.combat.attacking = 1.1
		timer.tween(player.combat.attacking, player.combat, { attacking = 0 }, nil, function()
			player.combat.attacking = false
		end)

		local bone = player.animation.current_matrices.gun * player.matrix

		-- Particle emitter
		local emit = self.world:add(hit_spark {
			position     = cpml.vec3(bone[13], bone[14], bone[15]),
			velocity     = player.transform.direction * 40,
			spawn_rate   = 1,
			spawn_radius = 0,
			lifetime     = 2,
			spread       = 0,
			limit        = 1,
			color        = { 1, 1, 1, 1 },
			butt         = true, -- shhh
			mesh         = load.model("assets/models/harpoon.iqm")
		})
		timer.script(function(wait)
			wait(0.25)
			emit.particle.limit = 0
			wait(2)
			self.world:remove(emit)
		end)

		self.sfx.gun_shoot:play()
	end)

	_G.EVENT:register("take damage", function(player, enemy, point, normal)
		local pcombat = player.combat
		local ecombat = enemy.combat

		-- Particle emitter
		local emit = self.world:add(hit_spark {
			position     = point,
			velocity     = normal * 3,
			spawn_rate   = 100,
			spawn_radius = 0,
			lifetime     = { 0.15, 0.5 },
			spread       = 0.75,
			limit        = 100,
			size         = 0.35
		})
		timer.script(function(wait)
			wait(0.25)
			emit.particle.limit = 0
			wait(0.25)
			self.world:remove(emit)
		end)

		-- HP and iframes
		pcombat.hp      = math.max(pcombat.hp - love.math.random(75, 125) * ecombat.attack * 2, 0)
		pcombat.iframes = true
		timer.after(1, function()
			pcombat.iframes = false
		end)

		-- Dead
		if pcombat.hp == 0 then
			-- Switch immediately with no fade!
			self.switch = true
		else
			self.sfx.lazer:play()
		end
	end)

	_G.EVENT:register("give damage", function(player, enemy, point, normal)
		local pcombat = player.combat
		local ecombat = enemy.combat

		-- Particle emitter
		local emit = self.world:add(hit_spark {
			position     = point,
			velocity     = normal * 7,
			spawn_rate   = 100,
			spawn_radius = 0,
			lifetime     = { 0.15, 0.5 },
			spread       = 1,
			limit        = 100,
			size         = 0.85
		})
		timer.script(function(wait)
			wait(0.25)
			emit.particle.limit = 0
			wait(0.25)
			self.world:remove(emit)
		end)

		-- HP and iframes
		ecombat.hp      = math.floor(math.max(ecombat.hp - love.math.random(75, 125) * pcombat.attack / 3, 0))
		ecombat.iframes = true
		timer.after(1, function()
			ecombat.iframes = false
		end)

		self.sfx.harpoon:play()

		-- Dead
		if ecombat.hp == 0 then
			timer.script(function(wait)
				player.player.freeze = true
				wait(1)

				-- Fade out
				timer.tween(0.5, self.overlay, { opacity=255 })
				wait(1)

				self.switch = true
			end)
		end
	end)

	_G.EVENT:register("enemy swap", function(player, enemy)
		timer.script(function(wait)
			wait(0.5)

			player.player.freeze = true
			self.overlay.opacity = 255
			self.sfx.lights_out:play()

			player.transform.position, enemy.transform.position = enemy.transform.position, player.transform.position
			enemy.ai.targetting = false
			wait(0.75)

			player.player.freeze = false
			self.overlay.opacity = 0
			self.sfx.lights_on:play()

			if player.player.sanity > 5 then
				player.player.sanity = player.player.sanity - 1
			end
		end)


	end)

	_G.EVENT:register("enemy shoot", function(position, duration)
		local patterns = {
			spiral = {
				pulse      = false,
				spawn_rate = 20,
				velocity   = cpml.vec3(0.25, 5, 0),
				lifetime   = 7,
				update     = function(p, i)
					p.velocity = p.velocity:rotate(math.pi / p.spawn_rate, cpml.vec3.unit_z)
				end
			},
			pulse = {
				pulse      = 0.5,
				spawn_rate = 20,
				velocity   = cpml.vec3(0, 5, 0),
				lifetime   = 7,
				update     = function(p, i)
					local ring = math.floor(i / p.spawn_rate)
					if p.ring and p.ring < ring then
						if not p.swap then p.swap = 1 end

						if ring % p.swap_rate == 0 then
							p.swap = p.swap * -1
						end

						p.velocity = p.velocity:rotate(p.swap, cpml.vec3.unit_z)
					end
					p.ring = ring

					p.velocity = p.velocity:rotate((math.pi * 2 / p.spawn_rate), cpml.vec3.unit_z)
				end
			}
		}

		local pattern = patterns[lume.weightedchoice {
			spiral = 1,
			pulse  = 1
		}]

		local epos = position:clone()
		epos.z = 0

		timer.script(function(wait)
			wait(0.5)
			local e = self.world:add {
				transform = {
					position = epos + cpml.vec3(0, 0, 0.5)
				},
				particle = {
					texture      = load.texture("assets/textures/bubble.png"),
					pulse        = pattern.pulse,
					spawn_rate   = pattern.spawn_rate,
					swap_rate    = 5,
					spawn_radius = 0,
					lifetime     = pattern.lifetime,
					spread       = 0,
					limit        = 1000,
					velocity     = pattern.velocity,
					update       = pattern.update,
					mesh         = load.model("assets/models/debug/unit-sphere.iqm")
				},
				visible = true,
				color   = { 0, 0, 0, 1 },
				size    = 1.25
			}
			wait(duration)
			e.particle.spawn_rate = 0
			wait(duration)
			self.world:remove(e)
		end)
	end)

	_G.EVENT:register("anim swim", function()
		self.sfx.swim:play()
	end)

	self.world:refresh()

	-- Fade in
	timer.tween(0.5, self.overlay, { opacity=0 })
end

function scene:leave()
	love.mouse.setRelativeMode(false)
	timer:clear()
	self.world:clearEntities()
	self.world:clearSystems()
	self.world:refresh()
	self.world  = nil
	self.player = nil
	self.enemy  = nil
	self.switch = nil
	_G.EVENT = require "signal".new()
end

function scene:keypressed(key)
	imgui.KeyPressed(key)
	if not imgui.GetWantCaptureKeyboard() then
		if key == "escape" then
			love.mouse.setRelativeMode(not love.mouse.getRelativeMode())
		end

		--[[ DEBUG KILL BUTTONS!!! ]]--

		if key == "backspace" then
			_G.EVENT:emit("take damage", self.player, self.enemy, self.player.transform.position + cpml.vec3.unit_z, cpml.vec3.unit_y)
		end

		if key == "\\" then
			_G.EVENT:emit("give damage", self.player, self.enemy, self.player.transform.position + cpml.vec3.unit_z, cpml.vec3.unit_y)
		end
	end
end

function scene:keyreleased(key)
	imgui.KeyReleased(key)
	if not imgui.GetWantCaptureKeyboard() then
		-- Pass event to the game
	end
end

function scene:mousemoved(x, y, mx, my, touch)
	if love.mouse.getRelativeMode() then
		self.renderer.camera:rotate_xy(mx, my)
		return
	end

	imgui.MouseMoved(x, y)
	if not imgui.GetWantCaptureMouse() then
		-- do stuff
	end
end

function scene:mousepressed(x, y, button, touch)
	if love.mouse.getRelativeMode() then
		return
	end

	imgui.MousePressed(button)
	if not imgui.GetWantCaptureMouse() then
		-- Pass event to the game
	end
end

function scene:mousereleased(x, y, button, touch)
	if love.mouse.getRelativeMode() then
		return
	end

	imgui.MouseReleased(button)
	if not imgui.GetWantCaptureMouse() then
		-- Pass event to the game
	end
end

function scene:wheelmoved(x, y)
	if love.mouse.getRelativeMode() then
		return
	end

	imgui.WheelMoved(y)
	if not imgui.GetWantCaptureMouse() then
		-- Pass event to the game
	end
end

function scene:textinput(t)
	imgui.TextInput(t)
	if not imgui.GetWantCaptureKeyboard() then
		-- a
	end
end

function scene:update(dt)
	timer.update(dt)
	self.world:update(dt)

	self.renderer.camera.distortion = 1 - self.player.player.sanity / 20 + self.overlay.distortion / 2
	self.renderer.camera.exposure = self.player.player.sanity / 20 * 0.2

	if _G.FLAGS.debug_mode then
		require("ui.camera")(self.renderer.camera)
		require("ui.anim")(self.player.animation)
		require("ui.render")(self.renderer)
		require("ui.gamestate")(self.player)
	end

	self.renderer.camera.position = self.player.transform.position

	if self.switch then
		self.bgm:stop()

		local image, text, duration
		if self.player.combat.hp > 0 then
			image = "assets/cutscenes/wake-1.png"
			text, duration = self.language:get("cutscene-wake-1")
		else
			image = "assets/cutscenes/wake-2.png"
			text, duration = self.language:get("cutscene-wake-2")
		end

		_G.SCENE.switch(require "scenes.cutscene", {
			{ image=image, text=text, duration=duration },
			player = {
				sanity   = self.player.player.sanity,
				hp       = self.player.combat.hp,
				start_hp = self.player.combat.start_hp,
				night    = self.player.player.night,
			},
			wake = true
		})
	end
end

function scene:draw()
	love.graphics.setColor(255, 255, 255)
	self.renderer:draw()
	local text

	--== Draw UI ==--

	-- Player
	love.graphics.setFont(self.font)
	love.graphics.setColor(0, 0, 0, 191)
	love.graphics.rectangle("fill", anchor:left(), anchor:bottom() - 55, 137, 55)
	love.graphics.setColor(255, 255, 255)
	text = self.language:get("label-health")
	love.graphics.print(string.format("%s: %d%%", text, self.player.combat.hp / 10000 * 100), anchor:left() + 6, anchor:bottom() - 55)
	text = self.language:get("label-sanity")
	love.graphics.print(string.format("%s: %d%%", text, self.player.player.sanity / 20 * 100), anchor:left() + 6, anchor:bottom() - 30)

	-- Nightmare phases
	love.graphics.setColor(0, 0, 0, 191)
	love.graphics.rectangle("fill", anchor:center_x() - 362, anchor:top() + 60, 724, 26)
	for i=0, 6 do
		love.graphics.setColor(0, 0, 0, 255)
		love.graphics.rectangle("fill", anchor:center_x() - 359 + (i * 3) + (i * 100), anchor:top() + 63, 100, 20)
	end
	local n = 7 - self.player.player.night
	for i=0, n do
		love.graphics.setColor(191, 0, 0, 255)
		love.graphics.rectangle("fill", anchor:center_x() - 359 + (i * 3) + (i * 100), anchor:top() + 63, 100, 20)
		love.graphics.setColor(0, 191, 0, 255)
		local len = 100
		if i == n then
			len = math.floor(self.enemy.combat.hp / 10000 * 100)
		end
		love.graphics.rectangle("fill", anchor:center_x() - 359 + (i * 3) + (i * 100), anchor:top() + 63, len, 20)
	end

	-- Nightmare label
	love.graphics.setFont(self.huge_font)
	text    = self.language:get("label-nightmare")
	local w = self.huge_font:getWidth(text)
	love.graphics.setColor(0, 0, 0, 255)
	love.graphics.print(text, anchor:center_x() - w/2, anchor:top() + 3)
	love.graphics.setColor(191, 191, 191)
	love.graphics.print(text, anchor:center_x() - w/2, anchor:top())

	-- Fade
	if self.overlay.opacity > 0 then
		love.graphics.setColor(0, 0, 0, self.overlay.opacity)
		local w, h = love.graphics.getDimensions()
		love.graphics.rectangle("fill", 0, 0, w, h)
	end
end

return scene
