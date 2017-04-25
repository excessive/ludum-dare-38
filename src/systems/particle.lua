local tiny   = require "tiny"
local cpml   = require "cpml"
local system = tiny.system{
	filter          = tiny.requireAll("particle", "transform"),
	time            = 0,
	default_texture = love.graphics.newImage("assets/textures/particle.png"),
	default_size    = 0.5,
	layout          = {
		{ "VertexPosition", "float", 2 },
		{ "VertexTexCoord", "float", 2 }
	}
}

function system:onAdd(entity)
	local particle = entity.particle
	local w, h, aspect
	if particle.texture then
		w, h = particle.texture:getDimensions()
	else
		w, h = self.default_texture:getDimensions()
	end
	aspect = w/h
	local m = particle.mesh
	if not m then
		local size = entity.size or self.default_size
		local data = {
			{ -size*aspect/2, -size/2, 0, 0 },
			{ size*aspect/2, -size/2, 1, 0 },
			{ size*aspect/2, size/2, 1, 1 },
			{ -size*aspect/2, size/2, 0, 1 },
		}
		m = love.graphics.newMesh(self.layout, data, "fan", "static")
		m:setTexture(particle.texture or self.default_texture)
	end
	local bucket_size = 5
	local map_size = 30
	particle.data = {
		particles       = {},
		buckets         = {},
		bucket_size     = bucket_size,
		map_size        = map_size,
		current_count   = 0,
		last_spawn_time = 0,
		index           = 0,
		mesh            = m
	}
end

function system:onRemove(entity)
	entity.particle.data = nil
end

function system:spawn_particle(entity)
	local transform = entity.transform
	local particle  = entity.particle

	local rand = love.math.random
	local pd   = particle.data
	local r    = particle.spawn_radius
	local s    = particle.spread

	pd.last_spawn_time = self.time
	pd.current_count   = pd.current_count + 1
	pd.index           = pd.index + 1

	-- Account for object attachment
	local pos          = transform.position
	local vel          = particle.velocity or cpml.vec3()
	local despawn_time = self.time
	local life         = particle.lifetime

	if type(life) == "table" then
		despawn_time = despawn_time + rand(life[1]*10000, life[2]*10000) / 10000
	else
		despawn_time = despawn_time + life
	end

	-- No need to add lifetime every update, might as well do it here.
	table.insert(pd.particles, {
		despawn_time = despawn_time,
		position     = pos + cpml.vec3((2*rand()-1)*r, (2*rand()-1)*r, 0),
		velocity     = cpml.vec3(
			vel.x + (2 * rand()-1) * s,
			vel.y + (2 * rand()-1) * s,
			vel.z + (2 * rand()-1) * s
		)
	})
end

function system:update(dt)
	self.time = self.time + dt

	for _, entity in ipairs(self.entities) do
		self:process(entity, dt)
	end
end

function system:process(entity, dt)
	local particle = entity.particle
	local pd       = particle.data

	-- It's been too long since our last particle spawn and we need more, time
	-- to get to work.
	local spawn_delta = self.time - pd.last_spawn_time
	if particle.pulse then
		if pd.current_count + particle.spawn_rate < particle.limit and spawn_delta >= particle.pulse then
			for _=1, particle.spawn_rate do
				self:spawn_particle(entity)

				if type(particle.update) == "function" then
					particle.update(particle, pd.index)
				end
			end
		end
	else
		local rate = 1/particle.spawn_rate
		if pd.current_count < particle.limit and spawn_delta >= rate then
			-- XXX: Why is this spawning so many at once?
			local need = math.floor(spawn_delta / rate)
			-- print(string.format("Spawning %d particles", need))
			for _=1, math.min(need, 2) do
				self:spawn_particle(entity)

				if type(particle.update) == "function" then
					particle.update(particle, pd.index)
				end
			end
		end
	end

	pd.buckets = {}

	-- Because particles are added in order of time and removals maintain
	-- order, we can simply count the number we need to get rid of and process
	-- the rest.
	local remove_n = 0
	for i=1, #pd.particles do
		local p = pd.particles[i]
		if self.time > p.despawn_time then
			remove_n = remove_n + 1
		else
			p.position.x = p.position.x + p.velocity.x * dt
			p.position.y = p.position.y + p.velocity.y * dt
			p.position.z = p.position.z + p.velocity.z * dt

			local bx = math.floor(p.position.x / pd.bucket_size)
			local by = math.floor(p.position.y / pd.bucket_size)
			local hash = bx + by * pd.map_size
			pd.buckets[hash] = pd.buckets[hash] or {}
			pd.buckets[hash][#pd.buckets[hash]+1] = { p, i }
		end
	end

	-- Particles be gone!
	if remove_n > 0 then
		-- print(string.format("Despawning %d particles", remove_n))
		pd.current_count = pd.current_count - remove_n
	end
	for _=1, remove_n do
		table.remove(pd.particles, 1)
	end
end

return system
