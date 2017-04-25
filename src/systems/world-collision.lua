local tiny = require "tiny"
local cpcl = require "cpcl"
local cpml = require "cpml"

local system = tiny.system {
	filter = tiny.requireAll("player", "transform"),
	now = 0
}

function system:update(dt)
	self.now = self.now + dt

	for _, entity in ipairs(self.entities) do
		self:process(entity, dt)
	end
end

function system:process(entity, dt)
	local player = entity.player
	local transform = entity.transform

	-- improve contact stability using our last frame on_ground results
	-- TODO: try to find a less hacky solution for this
	local magnet_force = 8
	if not player.jump and player.on_ground then
		transform.velocity.z = transform.velocity.z - magnet_force
	end

	local params = {
		radius   = player.radius,
		velocity = transform.velocity * dt,
		position = transform.position
	}
	local packet = cpcl.collision.packet_from_entity(params)

	local scale  = 1.2 -- a little oversized for the octree
	local bounds = {
		min = packet.position - packet.e_radius * cpml.vec3(scale),
		max = packet.position + packet.e_radius * cpml.vec3(scale)
	}

	local total_triangles, total_objects, checks = 0, 0, 0
	function packet.check_collision(col_packet)
		local soup = self.world.octree:get_colliding(bounds)

		checks = checks + 1
		total_objects = total_objects + #soup

		for _, object in ipairs(soup) do
			-- Is it a single triangle, or something irrelevant?
			if type(object.data) == "table" and object.data[3] then
				local triangle = object.data

				total_triangles  = total_triangles + 1
				local radius     = col_packet.e_radius
				local e_triangle = {
					triangle[1] / radius,
					triangle[2] / radius,
					triangle[3] / radius
				}

				cpcl.collision.check_triangle(col_packet, e_triangle, true)
			end
		end
	end

	cpcl.collision.collide_and_slide(packet, 0.6)

	-- if last-frame was on the ground but this one isn't, fix the lurching
	if not player.jump and player.on_ground and not packet.on_ground then
		packet.position.z = packet.position.z + magnet_force * dt
	end

	-- cast a ray down from player center to prevent sinking into the ground
	local function hit_fn(ray, soup, ret)
		for _, o in ipairs(soup) do
			local hit = cpml.intersect.ray_triangle(ray, o.data)
			if hit then
				table.insert(ret, hit)
			end
		end
	end

	local results = {}
	self.world.octree:cast_ray({
		position = transform.position + cpml.vec3(0, 0, player.radius.z),
		direction = -cpml.vec3.unit_z
	}, hit_fn, results)

	for _, hit in ipairs(results) do
		packet.position.z = math.max(packet.position.z, hit.z)
	end

	transform.position.x = packet.position.x
	transform.position.y = packet.position.y
	transform.position.z = packet.position.z

	player.on_ground  = packet.on_ground
	player.on_wall    = packet.on_wall

	if player.on_ground then
		player.jump = false
	end

	if not player.on_ground and not player.jump then
		player.on_ground = false
		player.jump = {
			start    = self.now,
			position = transform.position.z,
			velocity = player.move_len*player.speed,
			falling  = true
		}
	end

	-- Invisible walls!
	local len = transform.position:len()
	local stage_radius = 10
	if len > stage_radius then
		-- transform.position = transform.position / len * stage_radius
	end

	-- kill z
	if transform.position.z < -2 then
		if entity.combat then
			entity.combat.hp = entity.combat.hp - 1000
		end
		transform.position.x = 0
		transform.position.y = 0
		transform.position.z = 0
	end
end

return system
