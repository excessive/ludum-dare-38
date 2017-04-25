local tiny   = require "tiny"
local cpml   = require "cpml"
local system = tiny.system {
	filter = tiny.requireAny("particle", "capsules")
}

function system:onAddToWorld()
	self.player   = {}
	self.enemy    = {}
	self.emitters = {}
	setmetatable(self.emitters, { __mode = 'v'})

end

function system:onRemoveFromWorld()
	self.player   = nil
	self.enemy    = nil
	self.emitters = nil
end

function system:onAdd(e)
	if e.particle then
		table.insert(self.emitters, e)
	end
	if e.player then
		self.player = e
	end
	if e.ai then
		self.enemy = e
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

function system:onRemove(e)
	remove("particle", self.emitters, e)

	if e.player then
		self.player = nil
	end
	if e.ai then
		self.enemy = nil
	end
end


local function hash(pd, pos)
	local bx = math.floor(pos.x / pd.bucket_size)
	local by = math.floor(pos.y / pd.bucket_size)
	return bx + by * pd.map_size
end

function system:update(dt)
	for _, emitter in ipairs(self.emitters) do
		local pd = emitter.particle.data
		-- we only care about emitters with update functions, since those
		-- are the ones used for battle (not effects)
		if not emitter.particle.update then
			goto continue
		end

		local pcap = self.player.capsules.hit.root
		local bcap = { radius = emitter.size / 2, }

		local bucket = hash(pd, self.player.capsules.hit.root.a)
		local bin = pd.buckets[bucket] or {}
		for i = #bin, 1, -1 do
			local bullet = bin[i][1]
			bcap.a = bullet.position
			bcap.b = bullet.position

			local hit, p1, p2 = cpml.intersect.capsule_capsule(pcap, bcap)

			if hit then
				table.remove(pd.particles, bin[i][2])
				if not self.player.combat.iframes then
					_G.EVENT:emit("take damage", self.player, self.enemy, p1, (p2 - p1):normalize())
				end
			end
		end
		::continue::
	end
end

return system
