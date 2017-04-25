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

function system:update(dt)
	for _, emitter in ipairs(self.emitters) do
		local pd = emitter.particle.data
		-- we only care about emitters with butts, since those
		-- are the ones used for buttle (not effects)
		if not emitter.particle.butt then
			goto continue
		end

		local ecap = self.enemy.capsules.hit.root
		local bcap = { radius = emitter.size / 2, }
		for i = #pd.particles, 1, -1 do
			local bullet = pd.particles[i]
			bcap.a = bullet.position
			bcap.b = bullet.position

			local hit, p1, p2 = cpml.intersect.capsule_capsule(ecap, bcap)

			if hit then
				table.remove(pd.particles, i)
				if not self.enemy.combat.iframes then
					_G.EVENT:emit("give damage", self.player, self.enemy, p1, (p2 - p1):normalize())
				end
			end
		end
		::continue::
	end
end

return system
