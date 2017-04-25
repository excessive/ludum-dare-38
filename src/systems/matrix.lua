local tiny = require "tiny"
local cpml = require "cpml"

return tiny.processingSystem {
	filter = tiny.requireAny("transform"),
	process = function(_, entity, _)
		local transform = entity.transform
		-- update matrices for rendering and collision point updates
		local model = cpml.mat4()
		if transform.position then
			model:translate(model, transform.position)
		end
		if transform.orientation then
			model:rotate(model, transform.orientation)
		end
		if transform.scale then
			model:scale(model, transform.scale)
		end
		entity.matrix = model
	end
}
