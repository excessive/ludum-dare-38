local anim9   = require "anim9"
local cpml    = require "cpml"
local iqm     = require "iqm"
local memoize = require "memoize"
local load    = {}

local _lanim = memoize(function(filename)
	return iqm.load_anims(filename)
end)

local _lmark = memoize(function(filename)
	return love.filesystem.load(filename)()
end)

load.model = memoize(function(filename, actor, invert)
	local m = iqm.load(filename, actor, invert)
	if actor then
		-- print(filename, #m.triangles)
		for _, triangle in ipairs(m.triangles) do
			for i=1,#triangle do
				if not cpml.vec3.is_vec3(triangle[i].position) then
					triangle[i].position = cpml.vec3(triangle[i].position)
				end
			end
		end
	end
	return m
end)

load.anims = function(filename, anims, markers)
	if markers then
		return anim9(_lanim(filename), anims, _lmark(markers))
	end

	return anim9(_lanim(filename), anims)
end


load.sound = memoize(function(filename)
	return love.audio.newSource(filename)
end)

load.font = memoize(function(filename, size)
	return love.graphics.newFont(filename, size)
end)

load.texture = memoize(function(filename, flags)
	print(string.format("Loading texture %s", filename))
	local texture = love.graphics.newImage(filename, flags or { mipmaps = true })
	texture:setFilter("linear", "linear", 16)
	return texture
end)

-- Calculate aabb for individual polygons in a mesh
local function calculate_aabb(polygon)
	local aabb = {
		min = polygon[1]:clone(),
		max = polygon[1]:clone()
	}

	for i, vertex in ipairs(polygon) do
		if i > 1 then
			aabb.min.x = math.min(aabb.min.x, vertex.x)
			aabb.min.y = math.min(aabb.min.y, vertex.y)
			aabb.min.z = math.min(aabb.min.z, vertex.z)

			aabb.max.x = math.max(aabb.max.x, vertex.x)
			aabb.max.y = math.max(aabb.max.y, vertex.y)
			aabb.max.z = math.max(aabb.max.z, vertex.z)
		end
	end

	aabb.size   = aabb.max - aabb.min
	aabb.center = (aabb.max + aabb.min) / 2

	return aabb
end

local function add_triangles(octree, entity, oriented)
	local total_triangles = 0
	local m = cpml.mat4()
	if oriented then
		m
			:translate(m, entity.transform.position)
			:rotate(m, entity.transform.orientation)
			:scale(m, entity.transform.scale)
	end

	if entity.mesh then
		for _, triangle in ipairs(entity.mesh.triangles) do
			local t = {
				m * triangle[1].position,
				m * triangle[2].position,
				m * triangle[3].position
			}

			local aabb = calculate_aabb(t)
			octree:add(t, aabb)
			total_triangles = total_triangles + 1
		end
	end
	return total_triangles
end

load.map = memoize(function(filename, world)
	local map = love.filesystem.load(filename)()

	local cpcl = require "cpcl"
	world.octree = cpcl.octree(256, cpml.vec3(), 8, 1)

	for _, data in ipairs(map.objects) do
		local entity = {}

		for k, v in pairs(data) do
			entity[k] = v
		end

		entity.transform = {}
		entity.transform.position = cpml.vec3(entity.position)
		if entity.path then
			entity.transform.orientation = cpml.quat(entity.orientation)
			entity.transform.scale       = cpml.vec3(entity.scale)
			entity.mesh = load.model(entity.path, true)
		elseif entity.sound then
			entity.sound = load.sound(entity.sound)
		end

		add_triangles(world.octree, entity, true)

		world:addEntity(entity)

		love.event.pump()
		collectgarbage "step"
	end

	return true
end)

return load
