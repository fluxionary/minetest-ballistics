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

	self._lifetime = 0
	self._last_lifetime = 0
	self._last_pos = obj:get_pos()

	local initial_properties = deserialize(staticdata)

	local parameters = initial_properties.parameters or {}
	setmetatable(parameters, { __index = self._parameters })
	self._parameters = parameters
	if initial_properties.velocity then
		obj:set_velocity(initial_properties.velocity)
		self._initial_speed = initial_properties.velocity:length()
		self._last_velocity = vector.copy(initial_properties.velocity)
	else
		self._initial_speed = 0
		self._last_velocity = vector.zero()
	end
	if initial_properties.acceleration then
		obj:set_acceleration(initial_properties.acceleration)
		self._initial_gravity = initial_properties.acceleration.y
	else
		self._initial_gravity = 0
	end

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

	local done = false -- whether to stop processing early
	if self._on_step and self._on_step(self, dtime, moveresult) then
		done = true
	end

	if moveresult and not done then
		for _, collision in ipairs(moveresult.collisions) do
			if
				ballistics.handle_collision(
					self,
					collision,
					moveresult.touching_ground,
					moveresult.collides,
					moveresult.standing_on_object
				)
			then
				done = true
				break
			end
		end
	end

	if not done then
		if self._is_arrow then
			ballistics.adjust_pitch(self, dtime, self._update_period)
		end

		ballistics.apply_drag(self)
	end

	self._last_lifetime = self._lifetime
	self._last_pos = pos
	self._last_velocity = vel
end

-- if true is returned, the rest of the on_step callback isn't called - generally, assume the object was removed.
function ballistics.handle_collision(self, collision, touching_ground, collides, standing_on_object)
	if collision.type == "node" then
		if self._on_hit_node then
			local pos = collision.node_pos
			local node = minetest.get_node_or_nil(pos)

			if not node then
				self.object:remove()
				return true
			end

			if
				self._on_hit_node(
					self,
					pos,
					node,
					collision.axis,
					collision.old_velocity,
					collision.new_velocity,
					touching_ground,
					collides,
					standing_on_object
				)
			then
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
					collision.new_velocity,
					touching_ground,
					collides,
					standing_on_object
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
	local obj = self.object
	if not obj then
		return
	end
	local v = obj:get_velocity()
	if not v then
		return
	end
	obj:set_yaw(minetest.dir_to_yaw(v:normalize()))
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
