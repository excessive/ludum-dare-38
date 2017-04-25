local camera = require "camera"
local cpml   = require "cpml"
local iqm    = require "iqm"
local tiny   = require "tiny"
local anim9  = require "anim9"
local scene  = {}

function scene:enter()
	self.world           = tiny.world()
	self.renderer        = require("systems.render")()
	self.renderer.camera = camera {
		fov      = 50,
		position = cpml.vec3(0, -5, 2),
		target   = cpml.vec3(0, 0, 1.5)
	}
	self.world:add(require("systems.animation"))
	self.world:add(require("systems.matrix"))
	self.world:add(self.renderer)

	self.cube = self.world:addEntity {
		visible     = true,
		mesh        = iqm.load("assets/models/debug/color-cube.iqm"),
		position    = cpml.vec3(0, 0, 1.0),
		orientation = cpml.quat(0, 0, 0, 1),
		scale       = cpml.vec3(0.5, 0.5, 0.5)
	}

	if love.filesystem.isFile("assets/models/mc2.iqm") then
		self.mc = self.world:addEntity {
			visible     = true,
			mesh        = iqm.load("assets/models/mc2.iqm"),
			animation   = iqm.load_anims("assets/models/mc2.iqm"),
			position    = cpml.vec3(1.5, 0, 0),
		}
		self.mc.animation = anim9(self.mc.animation)
		local idle = self.mc.animation:new_track("idle", 0.5)
		self.mc.animation:play(idle)
	end

	love.mouse.setRelativeMode(true)
end

function scene:leave()
	self.cube = nil
	self.mc = nil

	self.world:clearEntities()
	self.world:clearSystems()
	self.renderer = nil

	self.world:refresh()
	self.world = nil

	love.mouse.setRelativeMode(false)
end

function scene:mousemoved(_, _, mx, my)
	self.renderer.camera.target = false
	self.renderer.camera:rotate_xy(mx, my)
end

function scene:keypressed(k)
	if k == "escape" then
		_G.SCENE.switch(require "scenes.main-menu")
	end
end

function scene:update(dt)
	self.cube.orientation = cpml.quat.rotate(dt,     cpml.vec3.unit_z) * self.cube.orientation
	self.cube.orientation = cpml.quat.rotate(dt*0.5, cpml.vec3.unit_x) * self.cube.orientation
	self.world:update(dt)
end

function scene:draw()
	self.renderer:draw()
end

return scene
