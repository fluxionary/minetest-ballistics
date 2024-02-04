local f = string.format

local atan2 = math.atan2
local pi = math.pi
local sqrt = math.sqrt

local v_new = vector.new
local v_zero = vector.zero

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

	local parameters = table.copy(self._parameters)
	if initial_properties.parameters then
		futil.table.set_all(parameters, initial_properties.parameters)
	end
	self._parameters = parameters

	if initial_properties.velocity then
		local velocity = vector.copy(initial_properties.velocity)
		obj:set_velocity(velocity)
		self._last_velocity = velocity
		self._initial_speed = velocity:length()
	else
		self._last_velocity = vector.zero()
		self._initial_speed = 0
	end
	if initial_properties.acceleration then
		local acceleration = vector.copy(initial_properties.acceleration)
		obj:set_acceleration(acceleration)
		self._last_acceleration = acceleration
		self._initial_gravity = acceleration.y
	else
		self._last_acceleration = vector.zero()
		self._initial_gravity = 0
	end

	if self._immortal then
		self.object:set_armor_groups({ immortal = 1 })
	end

	ballistics.set_initial_yaw(self)
	if self._is_arrow then
		ballistics.adjust_pitch(self)
	end

	if self._on_activate then
		self._on_activate(self, staticdata)
	end
end

local function handle_object_collision(self, pointed_thing)
	local args = {
		self,
		pointed_thing.ref,
		pointed_thing.intersection_point,
		pointed_thing.intersection_normal,
		pointed_thing.box_id,
	}

	for i = 1, #ballistics.registered_on_hit_objects do
		local rv = ballistics.registered_on_hit_objects[i](unpack(args))
		if rv then
			return rv
		end
	end

	if self._on_hit_object then
		return self._on_hit_object(unpack(args))
	else
		self.object:remove()
		return true
	end
end

local function handle_node_collision(self, pointed_thing)
	local node_pos = pointed_thing.under
	local node = minetest.get_node_or_nil(node_pos)

	if not node then
		-- hit unloaded map, abort
		self.object:remove()
		return true
	end

	local args = {
		self,
		node_pos,
		node,
		pointed_thing.above,
		pointed_thing.intersection_point,
		pointed_thing.intersection_normal,
		pointed_thing.box_id,
	}

	for i = 1, #ballistics.registered_on_hit_nodes do
		local rv = ballistics.registered_on_hit_nodes[i](unpack(args))
		if rv then
			return rv
		end
	end

	if self._on_hit_node then
		return self._on_hit_node(unpack(args))
	else
		self.object:remove()
		return true
	end
end

local function cast_for_collisions(self)
	local obj = self.object
	local cast = ballistics.ballistic_cast({
		pos = self._last_pos,
		velocity = self._last_velocity,
		acceleration = self._last_acceleration,
		drag = (self._parameters.drag or {}).coefficient or 0,
		dt = 0.01,
		stop_after = self._lifetime - self._last_lifetime + 0.01,
		objects = true,
		liquids = false,
	})

	for pointed_thing in cast do
		if pointed_thing.type == "object" then
			local ref = pointed_thing.ref
			local props = ref:get_properties()
			-- TODO collision with source should be an optional parameter
			-- TODO non-physical entities should also be an optional parameter (use arrows to pick up remote items!)
			if ref ~= self._source_obj and ref ~= obj and props.physical and props.collide_with_objects then
				return handle_object_collision(self, pointed_thing)
			end
		elseif pointed_thing.type == "node" then
			local node = minetest.get_node(pointed_thing.under)
			local def = ItemStack(node.name):get_definition()
			if def.walkable then -- TODO this should also be an optional parameter?
				return handle_node_collision(self, pointed_thing)
			end
		else
			error(f("unexpected pointed_thing type %s", dump(pointed_thing)))
		end
	end
end

function ballistics.on_step(self, dtime)
	local obj = self.object
	if not obj then
		return
	end
	local pos = obj:get_pos()
	if not pos then
		return
	end

	local velocity = obj:get_velocity()
	local acceleration = obj:get_acceleration()

	self._lifetime = (self._lifetime or 0) + dtime

	local done = false -- whether to stop processing early

	if self._on_step then
		done = done or self._on_step(self, dtime)
	end

	if not self._frozen then
		done = done or cast_for_collisions(self)

		if (not done) and self._is_arrow then
			ballistics.adjust_pitch(self, dtime, self._update_period)
		end
	end

	self._last_lifetime = self._lifetime
	self._last_pos = pos
	self._last_velocity = velocity
	self._last_acceleration = acceleration
end

function ballistics.freeze(self)
	local obj = self.object
	obj:set_velocity(v_zero())
	obj:set_acceleration(v_zero())

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
		local last_pitch_adjust = self._last_pitch_adjust
		if last_pitch_adjust then
			local elapsed = last_pitch_adjust + dtime
			if elapsed < period then
				self._last_pitch_adjust = elapsed
				return
			else
				self._last_pitch_adjust = 0
			end
		else
			-- always adjust pitch on first step
			self._last_pitch_adjust = dtime
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
