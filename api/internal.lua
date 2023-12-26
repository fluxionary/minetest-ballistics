local f = string.format

local atan2 = math.atan2
local pi = math.pi
local sqrt = math.sqrt

local v_new = vector.new

local deserialize = minetest.deserialize

function ballistics.on_activate(self, staticdata)
	local obj = self.object
	if not obj then
		return
	end

	local initial_properties = deserialize(staticdata)

	self._shoot_param = initial_properties.shoot_param
	obj:set_velocity(initial_properties.velocity)
	obj:set_acceleration(initial_properties.acceleration)

	self._lifetime = 0
	self._last_lifetime = 0
	self._last_pos = obj:get_pos()
	self._last_velocity = vector.copy(initial_properties.velocity)

	if self._immortal then
		self.object:set_armor_groups({ immortal = 1 })
	end

	ballistics.set_initial_yaw(self)

	if self._on_activate then
		self._on_activate(self, staticdata)
	end
end

function ballistics.on_step(self, dtime, moveresult)
	local obj = self.object
	if not obj then
		return
	end
	local pos = obj:get_pos()
	if not pos then
		return
	end
	local vel = obj:get_velocity()

	self._lifetime = (self._lifetime or 0) + dtime
	if self._on_step then
		if self._on_step(self, dtime, moveresult) then
			self._last_lifetime = self._lifetime
			self._last_pos = pos
			self._last_velocity = vel
			return
		end
	end

	-- first, handle collisions
	if moveresult then
		for _, collision in ipairs(moveresult.collisions) do
			if ballistics.handle_collision(self, collision) then
				self._last_lifetime = self._lifetime
				self._last_pos = pos
				self._last_velocity = vel
				return
			end
		end
	end

	if self._is_arrow then
		ballistics.adjust_pitch(self, dtime, self._update_period)
	end

	ballistics.apply_drag(self)

	self._last_lifetime = self._lifetime
	self._last_pos = pos
	self._last_velocity = vel
end

-- if true is returned, the rest of the on_step callback isn't called - assume the object was removed.
function ballistics.handle_collision(self, collision)
	if collision.type == "node" then
		if self._on_hit_node then
			local pos = collision.node_pos
			local node = minetest.get_node_or_nil(pos)

			if not node then
				self.object:remove()
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

function ballistics.set_initial_yaw(self)
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

	obj:set_rotation(v_new(atan2(v.y, sqrt(v.x ^ 2 + v.z ^ 2)), r.y, r.z + pi / 2))
end
