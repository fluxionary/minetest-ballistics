--- on_activate callbacks ---

function ballistics.on_activate_sound_play(self, staticdata)
	local pprops = self._projectile_properties.sound
	local spec = pprops.spec
	local parameters = table.copy(pprops.parameters or {})
	parameters.pos = nil
	parameters.object = self.object
	parameters.to_player = nil
	parameters.exclude_player = nil
	self._sound_handle = minetest.sound_play(spec, parameters)
end

--- end on_activate callbacks ---
--- on_deactivate callbacks ---

function ballistics.on_deactivate_sound_stop(self, removal)
	if self._sound_handle then
		minetest.sound_stop(self._sound_handle)
	end
end

--- end on_deactivate callbacks ---
--- on_hit_node callbacks ---

local threshold = 0.0001

-- because objects keep moving after colliding, use geometry to figure our approximate location of the actual collision
-- https://palitri.com/vault/stuff/maths/Rays%20closest%20point.pdf
local function correct_position(self, cur_pos, cur_vel)
	local last_pos = self._last_pos
	local last_vel = self._last_velocity
	local a = cur_vel
	local b = last_vel
	local a2 = a:dot(a)
	if a2 < threshold then
		return
	end
	local b2 = b:dot(b)
	if b2 < threshold then
		return
	end
	local ab = a:dot(b)
	local denom = (a2 * b2) - (ab * ab)
	if denom < threshold then
		return
	end
	local A = cur_pos
	local B = last_pos
	local c = last_pos - cur_pos
	local bc = b:dot(c)
	local ac = a:dot(c)
	local D = A + a * ((ac * b2 - ab * bc) / denom)
	local E = B + b * ((ab * ac - bc * a2) / denom)
	self.object:set_pos((D + E) / 2)
end

function ballistics.on_hit_node_freeze(self, node_pos, node, axis, old_velocity, new_velocity)
	local obj = self.object
	local pos = obj:get_pos()
	if not pos then
		return
	end
	correct_position(self, pos, new_velocity)

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
	local pprops = self._projectile_properties.add_entity
	assert(pprops, "must define projectile_properties.add_entity in projectile definition")
	local entity_name = pprops.entity_name
	assert(pprops, "must specify projectile_properties.add_entity.entity_name in projectile definition")
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
		local boom = self._projectile_properties.boom or {}
		local def = table.copy(boom)
		if self._source_obj and minetest.is_player(self._source_obj) then
			def.owner = self._source_obj:get_player_name()
		end
		self.object:remove()
		tnt.boom(node_pos, def)
		return true
	end
end

-- TODO: the ball never stops bouncing and rolls endlessly?
function ballistics.on_hit_node_bounce(self, node_pos, node, axis, old_velocity)
	local bounce = self._projectile_properties.bounce or {}
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
	local pprops = self._projectile_properties.replace
	assert(pprops, "must specify projectile_properties.replace in projectile definition")
	local target = pprops.target or "air"
	local replacement = pprops.replacement
	assert(replacement, "must specify projectile_properties.replace.replacement in projectile definition")
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

function ballistics.on_hit_node_sound_stop(self)
	if self._sound_handle then
		minetest.sound_stop(self._sound_handle)
	end
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
	local pprops = self._projectile_properties.punch
	assert(
		pprops and pprops.tool_capabilities,
		"must specify projectile_properties.punch.tool_capabilities in the projectile's definition"
	)
	local tool_capabilities = pprops.tool_capabilities
	local scale_speed = pprops.scale_speed or 20
	local remove = futil.coalesce(pprops.remove, false)
	local direction = (target:get_pos() - self._last_pos):normalize()
	local puncher
	if self._source_obj and self._source_obj:get_pos() then
		puncher = self._source_obj
	else
		puncher = self.object
	end
	target:punch(
		puncher,
		tool_capabilities.full_punch_interval or math.huge,
		scale_tool_capabilities(tool_capabilities, scale_speed, old_velocity),
		direction
	)
	if remove then
		self.object:remove()
		return true
	end
end

function ballistics.on_hit_object_add_entity(self, target, axis, old_velocity, new_velocity)
	local pprops = self._projectile_properties.add_entity
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
		local boom = self._projectile_properties.boom or {}
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
	local pprops = self._projectile_properties.replace
	assert(pprops, "must specify projectile_properties.replace in projectile definition")
	local target = pprops.target or "air"
	local replacement = pprops.replacement
	assert(replacement, "must specify projectile_properties.replace.replacement in projectile definition")
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

function ballistics.on_hit_object_sound_stop(self)
	if self._sound_handle then
		minetest.sound_stop(self._sound_handle)
	end
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
	local pprops = self._projectile_properties.add_velocity or {}
	local scale = add_velocity_scale[pprops.scale or "constant"](pprops, damage)
	obj:add_velocity(dir * scale)
end

function ballistics.on_punch_drop_item(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
	local pprops = self._projectile_properties.drop_item
	assert(pprops and pprops.item, "must specify projectile_properties.drop_item.item in projectile definition")
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
	self.obj:remove()
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

	local pprops = self._projectile_properties.particles
	assert(pprops, "must specify projectile_properties.particles in projectile definition (a particlespawner)")

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

-- TODO doesn't work
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

	local delta = ballistics.calculate_initial_velocity(our_pos, target_pos, current_vel:length(), current_acc.y)
	if not delta then
		return
	end

	local pprops = self._projectile_properties.seek_target or {}
	local seek_velocity = pprops.seek_velocity or 1
	local new_vel = (current_vel + (delta:normalize() * seek_velocity)):normalize() * current_vel:length()
	obj:set_velocity(new_vel)
end

--- end on_step callbacks ---
