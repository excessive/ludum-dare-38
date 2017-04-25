local tiny   = require "tiny"
local cpml   = require "cpml"
local system = tiny.processingSystem {
	name   = "Player Collision",
	filter = tiny.requireAll("capsules", "transform")
}

function system:process(entity)
	-- Attack collision
	for _, other in ipairs(self.entities) do
		if not entity.combat.attacking then break end  -- don't check if you're not attacking
		if other == entity then goto continue end      -- don't check against yourself
		if other.combat.iframes then goto continue end -- don't check if other is invincible

		for _, ecap in pairs(entity.capsules.hurt) do
			for bone, ocap in pairs(other.capsules.hit) do -- do math so you can attach particle emitter to bone!
				local hit, p1, p2 = cpml.intersect.capsule_capsule(ecap, ocap)
				if hit and not other.combat.iframes then -- gotta check again!
					if other.player then
						_G.EVENT:emit("take damage", other, entity, (p1+p2)/2, p1-p2)
					else
						_G.EVENT:emit("give damage", entity, other, (p1+p2)/2, p1-p2)
					end
				end
			end
		end

		::continue::
	end

	if not entity.player then return end

	local function cc_hit(ecap, ocap)
		local hit, p1, p2 = cpml.intersect.capsule_capsule(ecap, ocap)

		if hit then
			local transform = entity.transform
			local direction = (p1 - p2):normalize()

			local power        = transform.velocity:dot(direction)
			local reject       = direction * -power
			transform.velocity = transform.velocity + reject * transform.velocity:len()

			local offset       = p1 - transform.position
			transform.position = p2 - offset + direction * (ecap.radius + ocap.radius)
		end
	end

	-- Hitbox collision
	for _, other in ipairs(self.entities) do
		if other == entity then goto continue end

		for _, ecap in pairs(entity.capsules.hit) do
			-- Collide with hit capsules
			for _, ocap in pairs(other.capsules.hit) do
				cc_hit(ecap, ocap)
			end
		end

		::continue::
	end
end

return system
