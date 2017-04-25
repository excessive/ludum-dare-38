-- magnet
-- forward = move_direction
-- right = forward x slope
-- new_forward = right x slope

-- known issues
-- 1) there is no friction in the world so that added gravity actually pulls you down any surface that isn't flat
-- 2) when you jump or fall off a ledge, the first frame pulls you down very far (this has negative effects when jumping up ledges, too)
-- 3) you can sometimes phase into walls a bit causing unwanted consequences like getting stuck or falling slowly

local cpml        = require "cpml"
local vec3        = cpml.vec3
local mesh        = cpml.mesh
local utils       = cpml.utils
local intersect   = cpml.intersect
local FLT_EPSILON = cpml.constants.FLT_EPSILON
local sqrt        = math.sqrt
local collision   = {}

local show_debug = false

-- a is a number
-- b is a number
-- c is a number
-- maxR is a number
-- returns root or false.
local function get_lowest_root(a, b, c, maxR)
	-- Check if a solution exists
	local determinant = b * b - 4 * a * c

	-- If determinant is negative it means no solutions.
	if determinant < 0 or a == 0 then return false end

	-- calculate the two roots: (if determinant == 0 then
	-- x1==x2 but let’s disregard that slight optimization)
	local sqrtD = sqrt(determinant)
	local invDA = 1 / (2 * a)
	local r1 = (-b - sqrtD) * invDA
	local r2 = (-b + sqrtD) * invDA

	-- Swap such that r1 <= r2
	if r1 > r2 then
		r1, r2 = r2, r1
	end

	-- Get lowest root:
	if r1 > 0 and r1 < maxR then
		return r1
	end

	-- It is possible that we want x2 - this can happen
	-- if x1 < 0
	if r2 > 0 and r2 < maxR then
		return r2
	end

	-- No (valid) solutions
	return false
end

function collision.packet_from_entity(entity, dt)
	local packet = {}

	assert(vec3.is_vec3(entity.radius), "Entity radius must be a vec3")

	-- Information about the move being requested: (in world space)
	packet.e_radius   = entity.radius
	packet.velocity   = entity.velocity:clone()

	-- useful if you are directly passing in an entity
	if dt then
		packet.velocity = packet.velocity:scale(dt)
	end

	packet.z_offset   = 0.0
	packet.position   = entity.position:clone()
	packet.position.z = packet.position.z + packet.e_radius.z + packet.z_offset

	-- Information about the move being requested: (in ellipsoid space)
	packet.e_velocity            = vec3.div(packet.velocity, packet.e_radius)
	packet.e_normalized_velocity = vec3.normalize(packet.e_velocity)
	packet.e_base_point          = vec3()

	-- Hit information
	packet.nearest_distance   = math.huge
	packet.found_collision    = false
	packet.on_ground          = false
	packet.on_wall            = false
	packet.intersection_point = vec3()
	packet.slope              = vec3()

	return packet
end

local stats = {
	hit = {},
	miss = {}
}
local stat_keys = {
	"parallel",
	"point",
	"edge",
	"vertex"
}
for _, v in ipairs(stat_keys) do
	stats.hit[v] = 0
	stats.miss[v] = 0
end

local function hit(test)
	if not stats.hit[test] then
		stats.hit[test] = 0
	end
	stats.hit[test] = stats.hit[test] + 1
end

local function miss(test)
	if not stats.miss[test] then
		stats.miss[test] = 0
	end
	stats.miss[test] = stats.miss[test] + 1
end

local function reset()
	for k in pairs(stats.hit) do
		stats.hit[k] = 0
	end
	for k in pairs(stats.miss) do
		stats.miss[k] = 0
	end
end

-- Assumes: triangle is given in ellipsoid space:
function collision.check_triangle(packet, triangle, cull_back_face)
	cull_back_face = cull_back_face and true or false

	-- Make the plane containing this triangle.
	local plane = mesh.plane_from_triangle(triangle)

	-- Is triangle front-facing to the velocity vector?
	-- We only check front-facing triangles
	-- (your choice of course)
	if cull_back_face and mesh.is_front_facing(plane, packet.e_normalized_velocity) then
		return
	end

	-- Get interval of plane intersection:
	local t0, t1
	local embedded_in_plane = false

	-- Calculate the signed distance from sphere
	-- position to triangle plane
	local signed_dist = mesh.signed_distance(packet.e_base_point, plane)

	-- cache this as we’re going to use it a few times below:
	local nv_dot = plane.normal:dot(packet.e_velocity)

	-- if sphere is travelling parallel to the plane:
	if math.abs(nv_dot) < FLT_EPSILON then
		if math.abs(signed_dist) >= 1 then
			-- Sphere is not embedded in plane.
			-- No collision possible:
			miss("parallel")
			return
		else
			-- sphere is embedded in plane.
			-- It intersects in the whole range [0..1]
			embedded_in_plane = true
			t0 = 0
			hit("parallel")
		end
	else
		-- N dot D is not 0. Calculate intersection interval:
		local nvi = 1/nv_dot
		t0 = (-1 - signed_dist) * nvi
		t1 = ( 1 - signed_dist) * nvi

		-- Swap so t0 < t1
		if t0 > t1 then
			t0, t1 = t1, t0
		end

		-- Check that at least one result is within range:
		if t0 > 1 or t1 < 0 then
			--print(signed_dist, t0, t1)
			-- Both t values are outside values [0,1]
			-- No collision possible:
			return
		end

		-- Clamp to [0,1]
		t0 = utils.clamp(t0, 0, 1)
		hit("parallel")
	end

	-- OK, at this point we have two time values t0 and t1
	-- between which the swept sphere intersects with the
	-- triangle plane. If any collision is to occur it must
	-- happen within this interval.
	local collision_point
	local found_collison = false
	local t = 1

	-- First we check for the easy case - collision inside
	-- the triangle. If this happens it must be at time t0
	-- as this is when the sphere rests on the front side
	-- of the triangle plane. Note, this can only happen if
	-- the sphere is not embedded in the triangle plane.
	if not embedded_in_plane then
		local plane_intersection_point = (packet.e_base_point - plane.normal) + packet.e_velocity * t0

		if intersect.point_triangle(plane_intersection_point, triangle) then
			t = t0
			collision_point = plane_intersection_point
			found_collison = true
			hit("point")
		else
			miss("point")
		end
	end

	-- if we haven’t found a collision yet we’ll have to
	-- sweep sphere against vertices of the triangle.
	if not found_collison then
		local base          = packet.e_base_point
		local velocity      = packet.e_velocity
		local velocity_len2 = velocity:len2()

		-- For each vertex a quadratic equation has to
		-- be solved. We parameterize this equation as
		-- a*t^2 + b*t + c = 0 and below we calculate the
		-- parameters a, b, and c for each test.
		-- Check against points:
		for _, vertex in ipairs(triangle) do
			local a = velocity_len2
			local b = velocity:dot(base - vertex) * 2
			local c = (vertex - base):len2() - 1

			local found = get_lowest_root(a, b, c, t)
			if found then
				t = found
				collision_point = vertex
				found_collison  = true
				hit("vertex")
			else
				miss("vertex")
			end
		end

		-- if we haven’t found a collision yet we’ll have to
		-- sweep sphere against edges of the triangle.
		local hax = { 2, 3, 1 }

		-- For each edge a quadratic equation has to
		-- be solved. We parameterize this equation as
		-- a*t^2 + b*t + c = 0 and below we calculate the
		-- parameters a, b, and c for each test.
		-- Check against edges:
		for v1, v2 in ipairs(hax) do
			local edge             = triangle[v2] - triangle[v1]
			local base_to_vertex   = triangle[v1] - base
			local edge_len2        = edge:len2()
			local ev_dot           = edge:dot(velocity)
			local eb_dot_to_vertex = edge:dot(base_to_vertex)

			-- Calculate parameters for equation
			local a = edge_len2 * -velocity_len2 + ev_dot * ev_dot
			local b = edge_len2 * (2 * velocity:dot(base_to_vertex)) - 2 * ev_dot * eb_dot_to_vertex
			local c = edge_len2 * (1 - base_to_vertex:len2()) + eb_dot_to_vertex  * eb_dot_to_vertex

			-- Does the swept sphere collide against infinite edge?
			local found = get_lowest_root(a, b, c, t)
			if found then
				-- Check if intersection is within line segment:
				local f = (ev_dot * found - eb_dot_to_vertex) / edge_len2

				if f >= 0 and f <= 1 then
					-- intersection took place within segment.
					t = found
					collision_point = triangle[v1] + edge * f
					found_collison  = true
					hit("edge")
				else
					miss("edge")
				end
			end
		end
	end

	-- Set result:
	if found_collison then
		-- distance to collision: ’t’ is time of collision
		local dist_to_collision = t * packet.velocity:len()

		-- Does this triangle qualify for the closest hit?
		-- it does if it’s the first hit or the closest
		if not packet.found_collision or dist_to_collision < packet.nearest_distance then
			-- Collision information necessary for sliding
			packet.nearest_distance   = dist_to_collision
			packet.intersection_point = collision_point
			packet.found_collision    = true
		end

		-- Work out the hit normal so we can determine if the player is in
		-- contact with a wall or the ground.
		local n = cpml.vec3.normalize(collision_point - packet.e_base_point)
		local dz = n:dot(cpml.vec3.unit_z)

		-- If you're on the ground, wall behavior doesn't make sense.
		if dz < 0 and dz > -0.1 then
			packet.on_wall = true
		elseif dz <= -0.1 then
			packet.on_ground = true
		end
	end
end

function collision.collide_with_world(packet, position, velocity, slope_threshold, depth)
	depth = depth or 1
	local very_close_distance = 0.00005 -- 5mm / 100

	-- do we need to worry?
	if depth > 5 then
		return position
	end

	-- Ok, we need to worry:
	packet.e_velocity            = velocity
	packet.e_normalized_velocity = velocity:normalize()
	packet.e_base_point          = position
	packet.found_collision       = false
	packet.nearest_distance      = math.huge

	-- Check for collision (calls the collision routines)
	-- Application specific!!
	packet:check_collision()

	-- If no collision we just move along the velocity
	if not packet.found_collision then
		return position + velocity
	end

	-- *** Collision occured ***
	-- The original destination point
	local destination_point = position + velocity
	local new_base_point    = position:clone()

	-- only update if we are not already very close
	-- and if so we only move very close to intersection..not
	-- to the exact spot.
	if packet.nearest_distance >= very_close_distance then
		local v = velocity:clone()
		v = v:trim(packet.nearest_distance - very_close_distance)
		new_base_point = packet.e_base_point + v
		-- Adjust polygon intersection point (so sliding
		-- plane will be unaffected by the fact that we
		-- move slightly less than collision tells us)
		v = v:normalize()
		packet.intersection_point = packet.intersection_point - v * very_close_distance
	end

	-- don't lift the player up above base position
	if packet.intersection_point.z > position.z then
		destination_point.z         = position.z
		packet.intersection_point.z = position.z
	end

	-- Determine the sliding plane
	local slide_plane = {
		origin = packet.intersection_point,
		normal = vec3.normalize(new_base_point - packet.intersection_point)
	}
	-- packet.slope = slide_plane.normal

	-- Again, sorry about formatting.. but look carefully ;)
	local slide_factor = mesh.signed_distance(destination_point, slide_plane)
	local new_destination_point = destination_point - slide_plane.normal * slide_factor

	-- Generate the slide vector, which will become our new
	-- velocity vector for the next iteration
	local new_velocity = new_destination_point - packet.intersection_point

	-- Recurse:
	-- dont recurse if the new velocity is very small
	if new_velocity:len() < very_close_distance then
		return new_base_point
	end

	return collision.collide_with_world(packet, new_base_point, new_velocity, slope_threshold, depth + 1)
end

-- packet is a player table
function collision.collide_and_slide(packet, slope_threshold)
	-- calculate position and velocity in eSpace
	local e_radius = packet.e_radius
	local e_position = packet.position / packet.e_radius
	local e_velocity = packet.velocity / packet.e_radius

	if _G.windows.collision_info then
		if imgui and imgui.Begin("cpcl") then
			show_debug = true
		end
	end

	reset()

	-- Iterate until we have our final position.
	local final_position = collision.collide_with_world(packet, e_position, e_velocity, slope_threshold)

	if packet.on_ground then
		packet.position.z = math.max(packet.intersection_point.z, packet.position.z)
	end

	if packet.on_wall then
		packet.on_ground = false
	end

	if show_debug then
		show_debug = false
		if imgui.TreeNode("stats") then
			imgui.Text("hit")
			for k, v in pairs(stats.hit) do
				imgui.Value(k, v)
			end
			imgui.Text("miss")
			for k, v in pairs(stats.miss) do
				imgui.Value(k, v)
			end
			imgui.TreePop()
		end
		if imgui.TreeNode("packet") then
			for k, v in pairs(packet) do
				imgui.Text(tostring(k))
				imgui.SameLine(200)
				imgui.Text(tostring(v))
			end
			imgui.TreePop()
		end
	end

	if imgui and _G.windows.collision_info then
		imgui.End()
	end

	-- Convert final result back to world space:
	packet.position = final_position * e_radius
	packet.position.z = packet.position.z - packet.e_radius.z - packet.z_offset
end

return collision
