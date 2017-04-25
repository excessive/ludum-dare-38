local lvfx = require "lvfx"
local tiny = require "tiny"
local cpml = require "cpml"
local l3d  = require "love3d"
local load = require "utils.load-files"

return function()
	local render = tiny.system {
		filter = tiny.requireAny(
			tiny.requireAll("visible", "mesh"),
			tiny.requireAll("capsules"),
			tiny.requireAll("particle"),
			tiny.requireAll("sky")
		),
		time = 0
	}

	local default_camera = {
		exposure = 1.0
	}

	function render:onAddToWorld()
		-- use weak references so we don't screw with the gc
		self.objects = {}
		setmetatable(self.objects, { __mode = 'v'})

		self.capsules = {}
		setmetatable(self.capsules, { __mode = 'v'})

		self.particles = {}
		setmetatable(self.particles, { __mode = 'v'})

		self.views = {
			shadow      = lvfx.newView(),
			background  = lvfx.newView(),
			foreground  = lvfx.newView(),
			bullets     = lvfx.newView(),
			transparent = lvfx.newView(),
			debug       = lvfx.newView()
		}
		local res = 2048
		self.shadow_rt = l3d.new_canvas(res, res, "r32f", 1, true)

		local lag = 1.0
		self.canvas = l3d.new_canvas(1280*lag, 720*lag, "rg11b10f", 4, true)

		self.capsule_debug = false
		self.octree_debug  = false
		self.light_debug   = false

		self.views.shadow:setClear(0, 0, 0, 0)
		self.views.shadow:setCanvas(self.shadow_rt)
		self.views.shadow:setDepthClear(true)
		-- self.views.shadow:setCulling("front")
		self.views.shadow:setDepthTest("less", true)

		self.views.background:setCanvas(self.canvas)
		self.views.background:setClear(0.05, 0.3, 0.5, 1)
		self.views.background:setDepthClear(true)
		self.views.background:setCulling("front")
		self.views.background:setDepthTest("less", false)

		self.views.foreground:setCanvas(self.canvas)
		self.views.foreground:setDepthTest("less", true)
		self.views.foreground:setCulling("back")

		self.views.transparent:setCanvas(self.canvas, true)
		self.views.transparent:setDepthTest("less", false)

		self.views.bullets:setCanvas(self.canvas, true)
		self.views.bullets:setDepthTest("less", true)
		-- self.views.bullets:setBlendMode("add")

		self.views.debug:setDepthTest("less", false)

		self.light = {
			color     = { 10.0, 10.0, 10.0 },
			position  = cpml.vec3(0.0, 0.0, 0.0),
			direction = cpml.vec3(0.0, 0.7, 0.6),
			range     = 15
		}
		self.light.direction:normalize(self.light.direction)

		self.uniforms = {
			-- transform matrices
			proj       = lvfx.newUniform("u_projection"),
			invviewproj = lvfx.newUniform("u_inv_view_proj"),
			view       = lvfx.newUniform("u_view"),
			model      = lvfx.newUniform("u_model"),
			-- pose matrices
			pose       = lvfx.newUniform("u_pose"),
			-- camera stuff
			clips      = lvfx.newUniform("u_clips"),
			fog_color  = lvfx.newUniform("u_fog_color"),
			exposure   = lvfx.newUniform("u_exposure"),
			camera_dir = lvfx.newUniform("u_camera_position"),
			-- particle position
			position   = lvfx.newUniform("u_position"),
			-- lights
			light_dir  = lvfx.newUniform("u_light_direction"),
			light_col  = lvfx.newUniform("u_light_color"),
			light_v    = lvfx.newUniform("u_light_view"),
			light_p    = lvfx.newUniform("u_light_projection"),
			-- shadows
			shadow_tex = lvfx.newUniform("u_shadow_texture"),
			shadow_vp  = lvfx.newUniform("u_shadow_vp"),
			-- materials
			roughness  = lvfx.newUniform("u_roughness"),
			distortion = lvfx.newUniform("u_distortion"),
			time       = lvfx.newUniform("u_time")
		}

		self.shaders = {
			sky            = lvfx.newShader("assets/shaders/sky.glsl"),
			post           = lvfx.newShader("assets/shaders/post.glsl"),
			particle       = lvfx.newShader("assets/shaders/particle.glsl"),
			debug          = lvfx.newShader("assets/shaders/basic-normal.vs.glsl", "assets/shaders/flat.fs.glsl"),
			normal         = lvfx.newShader("assets/shaders/basic-normal.vs.glsl", "assets/shaders/basic.fs.glsl"),
			skinned        = lvfx.newShader("assets/shaders/basic-skinned.vs.glsl", "assets/shaders/basic.fs.glsl"),
			shadow_normal  = lvfx.newShader("assets/shaders/shadow-normal.vs.glsl", "assets/shaders/shadow.fs.glsl", true),
			shadow_skinned = lvfx.newShader("assets/shaders/shadow-skinned.vs.glsl", "assets/shaders/shadow.fs.glsl", true)
		}
		self.shaders.flat = self.shaders.debug
	end

	function render:onRemoveFromWorld()
		self.objects   = nil
		self.capsules  = nil
		self.particles = nil
		self.views     = nil
		self.uniforms  = nil
		self.world     = nil
	end

	function render:onAdd(e)
		if e.mesh then
			table.insert(self.objects, e)
		end
		if e.capsules then
			table.insert(self.capsules, e)
		end
		if e.particle then
			table.insert(self.particles, e)
		end
	end

	local function remove(k, t, e)
		if not e[k] then
			return false
		end
		for i, entity in ipairs(t) do
			if entity == e then
				table.remove(t, i)
				return true
			end
		end
		return false
	end

	function render:onRemove(e)
		remove("mesh", self.objects, e)
		remove("capsules", self.capsules, e)
		remove("particle", self.particles, e)
	end

	local default_pos   = cpml.vec3(0, 0, 0)
	local default_scale = cpml.vec3(1, 1, 1)

	local function draw_model(model, textures)
		for _, buffer in ipairs(model) do
			if textures and textures[buffer.material] then
				model.mesh:setTexture(load.texture(textures[buffer.material]))
			else
				model.mesh:setTexture()
			end
			model.mesh:setDrawRange(buffer.first, buffer.last)
			love.graphics.draw(model.mesh)
		end
	end

	function render:update(dt)
		self.time = self.time + dt
	end

	function render:draw()

		assert(self.camera, "A camera is required to draw the scene.")
		self.camera:update(self.views.foreground:getDimensions())

		self.uniforms.camera_dir:set({self.camera.direction:unpack()})
		self.uniforms.proj:set(self.camera.projection:to_vec4s())
		self.uniforms.view:set(self.camera.view:to_vec4s())
		self.uniforms.invviewproj:set(cpml.mat4():invert(self.camera.view * self.camera.projection):to_vec4s())
		self.uniforms.clips:set({self.camera.near, self.camera.far})
		self.uniforms.fog_color:set(self.views.background._clear)
		self.uniforms.light_dir:set({self.light.direction:unpack()})
		self.uniforms.light_col:set(self.light.color)

		self.uniforms.exposure:set(self.camera.exposure or default_camera.exposure)
		self.uniforms.distortion:set(math.min(0.2, (self.camera.distortion or 0) / 5))
		self.uniforms.time:set(self.time)

		local light_proj = cpml.mat4.from_ortho(-self.light.range, self.light.range, -self.light.range, self.light.range, -50, 50)
		local light_view = cpml.mat4()
		light_view:look_at(
			light_view,
			self.light.position,
			self.light.position - self.light.direction,
			cpml.vec3.unit_z
		)
		local bias = cpml.mat4 {
			0.5, 0.0, 0.0, 0.0,
			0.0, 0.5, 0.0, 0.0,
			0.0, 0.0, 0.5, 0.0,
			0.5, 0.5, 0.5, 1.0
		}
		self.uniforms.light_v:set(light_view:to_vec4s())
		self.uniforms.light_p:set(light_proj:to_vec4s())
		self.uniforms.shadow_vp:set((light_view * light_proj * bias):to_vec4s())
		self.uniforms.shadow_tex:set(self.shadow_rt)

		-- light debug
		if self.light_debug then
			self.uniforms.proj:set(light_proj:to_vec4s())
			self.uniforms.view:set(light_view:to_vec4s())
		end

		local w, h = love.graphics.getDimensions()
		lvfx.setShader(self.shaders.post)
		lvfx.draw(self.canvas, 0, h, 0, w/self.canvas:getWidth(), -h/self.canvas:getHeight())
		lvfx.submit(self.views.debug)

		if self.octree_debug then
			local cube = load.model("assets/models/debug/unit-cube.iqm")
			local shader = self.shaders.debug._handle

			lvfx.setShader(self.shaders.debug)
			lvfx.setDraw(function()
				self.world.octree:draw_objects(cube.mesh, shader, self.camera.position, function(o)
					return o[1] and o[2] and o[3]
				end)
			end)
			lvfx.submit(self.views.debug)

			lvfx.setShader(self.shaders.debug)
			lvfx.setDraw(function()
				love.graphics.setWireframe(true)
				self.world.octree:draw_bounds(cube.mesh, shader, self.camera.position)
				love.graphics.setWireframe(false)
			end)
			-- lvfx.submit(self.views.debug)
			lvfx.submit(false)
		end

		if self.bullet_debug then
			local sphere = load.model("assets/models/debug/unit-sphere.iqm")
			local function mtx(pos, radius)
				local ret = cpml.mat4()
				ret:translate(ret, pos)
				ret:scale(ret, cpml.vec3(radius, radius, radius))
				return ret
			end
			for _, entity in ipairs(self.particles) do
				local pd = entity.particle.data
				if not entity.particle.update then
					goto continue
				end
				for _, p in ipairs(pd.particles) do
					self.uniforms.model:set(mtx(p.position, entity.size/2):to_vec4s())
					lvfx.draw(sphere.mesh)
					lvfx.setColor(entity.color or { 1, 1, 1, 1 })
					lvfx.setShader(self.shaders.flat)
					lvfx.submit(self.views.transparent)
				end
				::continue::
			end
		end

		if self.capsule_debug then
			for _, entity in ipairs(self.capsules) do
				local function draw_capsules(list, r, g, b, a)
					local function mtx(capsule, radius)
						local ret = cpml.mat4()
						ret:translate(ret, capsule)
						ret:scale(ret, cpml.vec3(radius, radius, radius))
						return ret
					end
					local sphere = load.model("assets/models/debug/unit-sphere.iqm")
					local cylinder = load.model("assets/models/debug/unit-cylinder.iqm")
					for _, capsule in pairs(list) do
						lvfx.setShader(self.shaders.flat)
						lvfx.setColor(r, g, b, a)
						lvfx.draw(sphere.mesh)

						self.uniforms.model:set(mtx(capsule.a, capsule.radius):to_vec4s())
						lvfx.submit(self.views.transparent, true)

						self.uniforms.model:set(mtx(capsule.b, capsule.radius):to_vec4s())
						lvfx.submit(self.views.transparent, true)

						local cap = cpml.mat4()
						local dir = (capsule.b - capsule.a):normalize()
						local rot = cpml.quat.from_direction(dir, cpml.vec3.unit_z):normalize()
						cap:translate(cap, (capsule.a + capsule.b) / 2)
						cap:rotate(cap, rot)

						local length = capsule.a:dist(capsule.b)
						cap:scale(cap, cpml.vec3(capsule.radius, capsule.radius, length / 2))

						self.uniforms.model:set(cap:to_vec4s())
						lvfx.draw(cylinder.mesh)
						lvfx.submit(self.views.transparent)
					end
				end
				if entity.capsules.hurt then
					draw_capsules(entity.capsules.hurt, 1.0, 0.5, 0.5, 0.15)
				end
				if entity.capsules.hit then
					draw_capsules(entity.capsules.hit, 0.5, 0.5, 1.0, 0.15)
				end
			end
		end

		lvfx.touch(self.views.shadow)
		lvfx.touch(self.views.transparent)

		lvfx.setShader(self.shaders.sky)
		lvfx.rectangle("fill", -1, -1, 2, 2)
		lvfx.submit(self.views.background)

		for _, entity in ipairs(self.particles) do
			local pd = entity.particle.data

			local function mtx(pos, radius)
				local ret = cpml.mat4()
				ret:translate(ret, pos)
				ret:scale(ret, cpml.vec3(radius, radius, radius))
				return ret
			end

			self.uniforms.roughness:set(0.1)
			for _, p in ipairs(pd.particles) do
				if not entity.particle.mesh then
					self.uniforms.position:set {
						p.position.x,
						p.position.y,
						p.position.z
					}
					lvfx.draw(pd.mesh)
					lvfx.setColor(entity.color or { 1, 1, 1, 1 })
					lvfx.setShader(self.shaders.particle)
					lvfx.submit(self.views.transparent)
				else
					self.uniforms.model:set(mtx(p.position, entity.size/2):to_vec4s())
					lvfx.draw(entity.particle.mesh.mesh)
					lvfx.setColor(entity.color or { 1, 1, 1, 1 })
					lvfx.setShader(self.shaders.normal)
					lvfx.submit(self.views.bullets)
				end
			end
		end

		for _, entity in ipairs(self.objects) do
			if not entity.mesh then
				goto continue
			end

			self.uniforms.model:set((entity.matrix or cpml.mat4():identity()):to_vec4s())

			local anim = entity.animation
			if anim and anim.current_pose then
				self.uniforms.pose:set(unpack(anim.current_pose))
				lvfx.setShader(self.shaders.skinned)
			else
				lvfx.setShader(self.shaders.normal)
			end

			if entity.material then
				self.uniforms.roughness:set(entity.material.roughness or 0.5)
			end
			lvfx.setColor(entity.color or { 1, 1, 1, 1 })
			lvfx.setDraw(draw_model, { entity.mesh, entity.textures })
			lvfx.submit(self.views.foreground, true)

			if entity.no_shadow then
				lvfx.submit(false)
			else
				lvfx.setShader(anim and self.shaders.shadow_skinned or self.shaders.shadow_normal)
				-- lvfx.setShader(self.shaders.shadow_normal)
				lvfx.submit(self.views.shadow)
			end
			::continue::
		end

		lvfx.frame {
			self.views.shadow,
			self.views.background,
			self.views.foreground,
			self.views.bullets,
			self.views.transparent,
			self.views.debug
		}
	end

	return render
end
