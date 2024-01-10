--- on_activate callbacks ---

function ballistics.on_activate_active_sound_play(self, staticdata)
	local pprops = self._parameters.active_sound
	if not (pprops and pprops.spec and pprops.spec.name) then
		error("most specify parameters.active_sound.spec.name in projectile definition")
	end
	local spec = pprops.spec
	local parameters = table.copy(pprops.parameters or {})
	parameters.pos = nil
	parameters.object = self.object
	parameters.to_player = nil
	parameters.exclude_player = nil
	self._active_sound_handle = minetest.sound_play(spec, parameters)
end

--- end on_activate callbacks ---
--- on_deactivate callbacks ---

function ballistics.on_deactivate_active_sound_stop(self, removal)
	if self._active_sound_handle then
		minetest.sound_stop(self._active_sound_handle)
	end
end

--- end on_deactivate callbacks ---
--- on_hit_node callbacks ---

function ballistics.on_hit_node_freeze(self, node_pos, node, axis, old_velocity, new_velocity)
	local obj = self.object
	local pos = obj:get_pos()
	if not pos then
		return
	end

	local collision_position =
		ballistics.estimate_collision_position(self._last_pos, self._last_velocity, pos, new_velocity)
	if collision_position then
		obj:set_pos(collision_position)
	end

	ballistics.freeze(self)
end

local function get_adjacent_node(self, node_pos, axis)
	local last_pos = self._last_pos:round()
	local delta = vector.zero()
	if axis == "x" then
		if node_pos.x < last_pos.x then
			delta = vector.new(1, 0, 0)
		else
			delta = vector.new(-1, 0, 0)
		end
	elseif axis == "y" then
		if node_pos.y < last_pos.y then
			delta = vector.new(0, 1, 0)
		else
			delta = vector.new(0, -1, 0)
		end
	elseif axis == "z" then
		if node_pos.z < last_pos.z then
			delta = vector.new(0, 0, 1)
		else
			delta = vector.new(0, 0, -1)
		end
	end
	return node_pos + delta
end

function ballistics.on_hit_node_add_entity(self, node_pos, node, axis, old_velocity, new_velocity)
	local pprops = self._parameters.add_entity
	assert(pprops, "must define parameters.add_entity in projectile definition")
	local entity_name = pprops.entity_name
	assert(pprops, "must specify parameters.add_entity.entity_name in projectile definition")
	local chance = pprops.chance or 1
	local staticdata = pprops.staticdata

	if math.random(chance) == 1 then
		minetest.add_entity(get_adjacent_node(self, node_pos, axis), entity_name, staticdata)
	end

	self.object:remove()
	return true
end

if minetest.get_modpath("tnt") then
	function ballistics.on_hit_node_boom(self, node_pos, node, axis, old_velocity, new_velocity)
		local boom = self._parameters.boom or {}
		local def = table.copy(boom)
		if self._source_obj and minetest.is_player(self._source_obj) then
			def.owner = self._source_obj:get_player_name()
		end
		self.object:remove()
		tnt.boom(node_pos, def)
		return true
	end
end

-- TODO: the ball never stops bouncing and "rolls" endlessly?
function ballistics.on_hit_node_bounce(self, node_pos, node, axis, old_velocity)
	local bounce = self._parameters.bounce or {}
	local efficiency = bounce.efficiency or 1
	local clamp = bounce.clamp or 0

	local delta_velocity = vector.zero()
	if axis == "x" then
		local dx = -old_velocity.x * efficiency
		if dx > clamp then
			delta_velocity.x = dx
		end
	elseif axis == "y" then
		local dy = -old_velocity.y * efficiency
		if dy > clamp then
			delta_velocity.y = dy
		end
	elseif axis == "z" then
		local dz = -old_velocity.z * efficiency
		if dz > clamp then
			delta_velocity.z = dz
		end
	end

	if not delta_velocity:equals(vector.zero()) then
		self.object:add_velocity(delta_velocity)
	end
end

function ballistics.on_hit_node_dig(self, node_pos, node, axis, old_velocity, new_velocity)
	minetest.node_dig(node_pos, node, self._source_obj)
	self.object:remove()
	return true
end

-- TODO: allow specifying multiple possible targets, groups
function ballistics.on_hit_node_replace(self, node_pos, node, axis, old_velocity, new_velocity)
	local pprops = self._parameters.replace
	assert(pprops, "must specify parameters.replace in projectile definition")
	local target = pprops.target or "air"
	local replacement = pprops.replacement
	assert(replacement, "must specify parameters.replace.replacement in projectile definition")
	if type(replacement) == "string" then
		replacement = { name = replacement }
	end
	local radius = pprops.radius or 0
	local pos0 = get_adjacent_node(self, node_pos, axis)
	for x = -radius, radius do
		for y = -radius, radius do
			for z = -radius, radius do
				local pos = pos0:offset(x, y, z)
				if minetest.get_node(pos).name == target then
					minetest.set_node(pos, replacement)
				end
			end
		end
	end
	self.object:remove()
	return true
end

function ballistics.on_hit_node_active_sound_stop(self)
	if self._active_sound_handle then
		minetest.sound_stop(self._active_sound_handle)
	end
end

function ballistics.on_hit_node_hit_sound_play(self)
	local pos = self.object:get_pos() or self._last_pos
	if not pos then
		return
	end
	local pprops = self._parameters.hit_sound
	if not (pprops and pprops.spec and pprops.spec.name) then
		error("most specify parameters.hit_sound.spec.name in projectile definition")
	end
	local spec = pprops.spec
	local parameters = table.copy(pprops.parameters or {})
	parameters.pos = pos
	parameters.loop = nil
	parameters.to_player = nil
	parameters.exclude_player = nil
	minetest.sound_play(spec, parameters, true)
end

--- end on_hit_node callbacks ---
--- on_hit_object callbacks ---

local function get_target_visual_size(target)
	local parent = target:get_attach()
	while parent do
		target = parent
		parent = target:get_attach()
	end
	return target:get_properties().visual_size
end

-- TODO: this function currently does *NOT* work correctly
function ballistics.on_hit_object_stick(self, target, axis, old_velocity, new_velocity)
	local obj = self.object
	if not obj:get_pos() then
		return
	end

	ballistics.freeze(self)
	local target_visual_size = get_target_visual_size(target)
	local our_visual_size = obj:get_properties().visual_size
	obj:set_properties({
		-- note: using `:divide` to get schur quotient is deprecated
		-- https://github.com/minetest/minetest/issues/12533
		visual_size = vector.new(
			our_visual_size.x / target_visual_size.x,
			our_visual_size.y / target_visual_size.y,
			our_visual_size.z / target_visual_size.z
		),
	})
	local our_rotation = obj:get_rotation()
	local target_rotation = target:get_rotation()
	if not (our_rotation and target_rotation) then
		return
	end
	local rotation = futil.vector.compose_rotations(futil.vector.inverse_rotation(target_rotation), our_rotation)

	local target_center = futil.get_object_center(target)
	local position = target_center - target:get_pos()
	--local ray = Raycast(self._last_pos, target_center, true, false)
	--for pointed_thing in ray do
	--	if pointed_thing.type =="object" and pointed_thing.ref == target then
	--		position = pointed_thing.intersection_point - target:get_pos()
	--	end
	--end

	-- TODO: need to rotate the position too... around what exactly?

	-- after, to allow the visual size to propagate
	minetest.after(0, function()
		if not (obj:get_pos() and target:get_pos()) then
			return
		end
		obj:set_attach(target, "", position, rotation:apply(math.deg))
	end)
end

local function scale_tool_capabilities(tool_capabilities, scale_speed, velocity)
	local speed = velocity:length()
	local scale = speed / scale_speed
	local scaled_caps = table.copy(tool_capabilities)
	for group, damage in pairs(scaled_caps.damage_groups) do
		scaled_caps.damage_groups[group] = futil.math.probabilistic_round(damage * scale)
	end
	return scaled_caps
end

function ballistics.on_hit_object_punch(self, target, axis, old_velocity, new_velocity)
	local pprops = self._parameters.punch
	assert(
		pprops and pprops.tool_capabilities,
		"must specify parameters.punch.tool_capabilities in the projectile's definition"
	)
	local tool_capabilities = pprops.tool_capabilities
	local scale_speed = pprops.scale_speed or self._initial_speed
	local remove = futil.coalesce(pprops.remove, false)
	local direction = (target:get_pos() - self._last_pos):normalize()
	local puncher
	if self._source_player_name then
		-- so that if the player disconnects, they can't be responsible for damage
		puncher = minetest.get_player_by_name(self._source_player_name)
	elseif self._source_obj and self._source_obj:get_pos() then
		puncher = self._source_obj
	else
		puncher = self.object
	end

	if puncher then
		target:punch(
			puncher,
			tool_capabilities.full_punch_interval or math.huge,
			scale_tool_capabilities(tool_capabilities, scale_speed, old_velocity),
			direction
		)
	end

	if remove then
		self.object:remove()
		return true
	end
end

function ballistics.on_hit_object_add_entity(self, target, axis, old_velocity, new_velocity)
	local pprops = self._parameters.add_entity
	local entity_name = pprops.entity_name
	local chance = pprops.chance or 1
	local staticdata = pprops.staticdata

	local target_pos = target:get_pos()
	if target_pos and math.random(chance) == 1 then
		local last_pos = self._last_pos:round()
		local delta = vector.zero()
		if axis == "x" then
			if target_pos.x < last_pos.x then
				delta = vector.new(1, 0, 0)
			else
				delta = vector.new(-1, 0, 0)
			end
		elseif axis == "y" then
			if target_pos.y < last_pos.y then
				delta = vector.new(0, 1, 0)
			else
				delta = vector.new(0, -1, 0)
			end
		elseif axis == "z" then
			if target_pos.z < last_pos.z then
				delta = vector.new(0, 0, 1)
			else
				delta = vector.new(0, 0, -1)
			end
		end
		minetest.add_entity(target_pos + delta, entity_name, staticdata)
	end

	self.object:remove()
	return true
end

if minetest.get_modpath("tnt") then
	function ballistics.on_hit_object_boom(self, target, axis, old_velocity, new_velocity)
		local boom = self._parameters.boom or {}
		local def = table.copy(boom)
		if self._source_obj and minetest.is_player(self._source_obj) then
			def.owner = self._source_obj:get_player_name()
		end
		local our_pos = self.object:get_pos() or self._last_pos
		self.object:remove()
		local target_pos = target:get_pos()
		if target_pos then
			tnt.boom(target_pos, def)
		else
			tnt.boom(our_pos, def)
		end
		return true
	end
end

-- TODO: allow specifying multiple possible targets, groups
function ballistics.on_hit_object_replace(self, object, axis, old_velocity, new_velocity)
	local pprops = self._parameters.replace
	assert(pprops, "must specify parameters.replace in projectile definition")
	local target = pprops.target or "air"
	local replacement = pprops.replacement
	assert(replacement, "must specify parameters.replace.replacement in projectile definition")
	if type(replacement) == "string" then
		replacement = { name = replacement }
	end
	local radius = pprops.radius or 0
	local pos0 = object:get_pos():round()
	if not pos0 then
		return
	end
	for x = -radius, radius do
		for y = -radius, radius do
			for z = -radius, radius do
				local pos = pos0:offset(x, y, z)
				if minetest.get_node(pos).name == target then
					minetest.set_node(pos, replacement)
				end
			end
		end
	end
	self.object:remove()
	return true
end

function ballistics.on_hit_object_active_sound_stop(self)
	if self._active_sound_handle then
		minetest.sound_stop(self._active_sound_handle)
	end
end

function ballistics.on_hit_object_hit_sound_play(self)
	local pos = self.object:get_pos() or self._last_pos
	if not pos then
		return
	end
	local pprops = self._parameters.hit_sound
	if not (pprops and pprops.spec and pprops.spec.name) then
		error("most specify parameters.hit_sound.spec.name in projectile definition")
	end
	local spec = pprops.spec
	local parameters = table.copy(pprops.parameters or {})
	parameters.pos = pos
	parameters.loop = nil
	parameters.to_player = nil
	parameters.exclude_player = nil
	minetest.sound_play(spec, parameters, true)
end

function ballistics.on_hit_object_drop_item(self)
	local pprops = self._parameters.drop_item
	assert(pprops and pprops.item, "must specify parameters.drop_item.item in projectile definition")
	local item = pprops.item
	local chance = pprops.chance or 1
	local obj = self.object
	if obj:get_velocity():length() > 0.001 then
		-- only drop as an item if not moving
		return
	end
	if math.random(chance) == 1 then
		minetest.add_item(obj:get_pos(), item)
	end
	obj:remove()
	return true
end

--- end on_hit_object callbacks ---
--- on_punch callbacks ---

function ballistics.on_punch_deflect(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
	if not dir then
		return
	end
	local obj = self.object
	local velocity = obj:get_velocity()
	if not velocity then
		return
	end
	local speed = velocity:length()
	obj:set_velocity(dir * speed)
end

local add_velocity_scale = {
	constant = function(pprops)
		return (pprops.offset or 1)
	end,
	linear = function(pprops, damage)
		if (pprops.input or "damage") == "damage" then
			return (pprops.scale or 1) * damage + (pprops.offset or 0)
		else
			error(string.format("unknown input %s", pprops.input))
		end
	end,
}

function ballistics.on_punch_add_velocity(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
	if not dir then
		return
	end
	local obj = self.object
	local velocity = obj:get_velocity()
	if not velocity then
		return
	end
	local pprops = self._parameters.add_velocity or {}
	local scale = add_velocity_scale[pprops.scale or "constant"](pprops, damage)
	obj:add_velocity(dir * scale)
end

function ballistics.on_punch_drop_item(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
	local pprops = self._parameters.drop_item
	assert(pprops and pprops.item, "must specify parameters.drop_item.item in projectile definition")
	local item = pprops.item
	local chance = pprops.chance or 1
	local obj = self.object
	if obj:get_velocity():length() > 0.001 then
		-- only drop as an item if not moving
		return
	end
	if math.random(chance) == 1 then
		minetest.add_item(obj:get_pos(), item)
	end
	obj:remove()
	return true
end

--- end on_punch callbacks ---
--- on_step callbacks ---

function ballistics.on_step_particles(self, dtime, moveresult)
	local obj = self.object
	local pos = obj:get_pos()
	if not pos then
		return
	end

	if obj:get_attach() or obj:get_velocity():length() < 0.01 then
		return
	end

	local pprops = self._parameters.particles
	assert(pprops, "must specify parameters.particles in projectile definition (a particlespawner)")

	if pprops._period then
		local elapsed = (self._particles_elapsed or 0) + dtime
		if elapsed < pprops._period then
			self._particles_elapsed = elapsed
			return
		else
			self._particles_elapsed = elapsed - pprops._period
		end
	end

	local def = table.copy(pprops)
	def.minpos = def._delta_minpos and pos + def._delta_minpos or pos
	def.maxpos = def._delta_maxpos and pos + def._delta_maxpos or pos

	minetest.add_particlespawner(def)
end

function ballistics.on_step_seek_target(self, dtime, moveresult)
	if self._frozen then
		return
	end
	local target = self._target_obj
	if not target then
		return
	end
	local target_pos = futil.get_object_center(target)
	if not target_pos then
		return
	end
	local obj = self.object
	local our_pos = obj:get_pos()
	if not our_pos then
		return
	end
	local current_vel = obj:get_velocity()
	local current_acc = obj:get_acceleration()

	-- TODO: track the target's estimated position when we collide
	-- i'm not entirely sure why the target and source need to be switched?
	-- this also doesn't work quite how i expect it to, i may need to go back a step or estimate the next step
	local delta = ballistics.calculate_initial_velocity(target_pos, our_pos, current_vel:length(), current_acc.y)
	if not delta then
		return
	end

	local pprops = self._parameters.seek_target or {}
	local seek_speed = pprops.seek_speed or 1
	local new_vel = (current_vel + (delta:normalize() * seek_speed)):normalize() * current_vel:length()
	obj:set_velocity(new_vel)
end

function ballistics.on_step_apply_drag(self, dtime, moveresult)
	local pprops = self._parameters.drag
	assert(pprops and pprops.coefficient, "must specify parameters.drag.coefficient in projectile definition")
	ballistics.apply_drag(self, pprops.coefficient)
end

--- end on_step callbacks ---
