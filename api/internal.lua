local f = string.format

local atan2 = math.atan2
local pi = math.pi
local sqrt = math.sqrt

local v_new = vector.new

function ballistics.handle_collision(self, collision)
	if collision.type == "node" then
		if self._on_hit_node then
			local pos = collision.node_pos
			local node = minetest.get_node_or_nil(pos)

			if not node then
				self.object.remove()
				return true
			end

			if self._on_hit_node(self, pos, node, collision.axis, collision.old_velocity, collision.new_velocity) then
				return true
			end
		else
			self.object:remove()
			return true
		end
	elseif collision.type == "object" then
		if self._on_hit_object then
			if
				self._on_hit_object(
					self,
					collision.object,
					collision.axis,
					collision.old_velocity,
					collision.new_velocity
				)
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

function ballistics.freeze(self)
	self.object:set_velocity(v_new(0, 0, 0))
	self.object:set_acceleration(v_new(0, 0, 0))

	self._frozen = true
end

function ballistics.set_initial_pitch(self)
	if not self.object then
		return
	end
	local v = self.object:get_velocity()
	if not v then
		return
	end
	self.object:set_yaw(minetest.dir_to_yaw(v:normalize()))
end

function ballistics.adjust_pitch(self, dtime, period)
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

	if not obj then
		return
	end

	local v = obj:get_velocity()
	local r = obj:get_rotation()

	if not (r and v) then
		return
	end

	-- TODO this is wrong?
	obj:set_rotation(v_new(atan2(v.y, sqrt(v.x ^ 2 + v.z ^ 2)), r.y, r.z + pi / 2))
end
