local f = string.format

local atan2 = math.atan2
local sqrt = math.sqrt

local v_new = vector.new

local api = ballistics.api

function api.handle_collision(self, collision, on_hit_node, on_hit_object)
	if collision.type == "node" then
		if on_hit_node then
			local pos = collision.node_pos
			local node = minetest.get_node_or_nil(pos)

			if not node then
				self.object.remove()
				return true
			end

			if on_hit_node(self, pos, node, collision.axis, collision.old_velocity, collision.new_velocity) then
				return true
			end
		else
			self.object:remove()
			return true
		end
	elseif collision.type == "object" then
		if on_hit_object then
			if
				on_hit_object(self, collision.object, collision.axis, collision.old_velocity, collision.new_velocity)
			then
				return true
			end
		else
			self.object:remove()
			return true
		end
	else
		error(f("unexepcted collision %s", dump(collision)))
	end
end

function api.freeze(self)
	self.object:set_velocity(v_new(0, 0, 0))
	self.object:set_acceleration(v_new(0, 0, 0))

	self._frozen = true
end

function api.adjust_pitch(self, dtime, period)
	if self._frozen then
		return
	end

	if period then
		local elapsed = (self._elapsed or 0) + dtime
		if elapsed < period then
			self._last_pitch_adjust = elapsed
			return
		else
			self._last_pitch_adjust = 0
		end
	end

	local obj = self.object
	local v = obj:get_velocity()
	local r = obj:get_rotation()

	obj:set_rotation({
		x = atan2(v.y, sqrt(v.x ^ 2 + v.z ^ 2)),
		y = r.y,
		z = r.z,
	})
end

function api.emerge_target(self, dtime)
	local obj = self.object
	local pos = obj:get_pos()
	dtime = 1.5 * dtime -- TODO: use some heuristic based on the length of a server step to balance this
	local destination = pos + (obj:get_velocity() + obj:get_acceleration() * dtime) * dtime

	minetest.emerge_area(pos, destination)
end
