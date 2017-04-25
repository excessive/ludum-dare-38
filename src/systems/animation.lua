local tiny = require "tiny"

return tiny.processingSystem {
	name   = "Animation",
	filter = tiny.requireAll("animation"),
	onRemoveFromWorld = function(self)
	end,
	process = function(self, entity, dt)
		if entity.animation then
			entity.animation:update(dt)

			for _, track in ipairs(entity.animation.timeline) do
				local markers = entity.animation.animations[track.name].markers
				local cf      = track.frame  or 1
				local cm      = track.marker or 0

				if cf ~= cm then
					track.marker = cf
					local marker = markers[cf] or ""
					_G.EVENT:emit("anim " .. marker, entity)
				end
			end
		end
	end
}
