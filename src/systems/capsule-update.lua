local tiny   = require "tiny"
local cpml   = require "cpml"
local system = tiny.processingSystem {
	filter = tiny.requireAll("capsules", "animation")
}

function system:process(entity)
	if not entity.matrix then return end

	for _, category in pairs(entity.capsules) do
		for joint, capsule in pairs(category) do
			local base = { 0, 0, 0, 1 }
			local pos4 = entity.animation.current_matrices[joint] * entity.matrix * base
			capsule.a = cpml.vec3(pos4[1], pos4[2], pos4[3])

			base = { 0, capsule.length, 0, 1 }
			pos4 = entity.animation.current_matrices[joint] * entity.matrix * base
			capsule.b = cpml.vec3(pos4[1], pos4[2], pos4[3])
		end
	end
end

return system
