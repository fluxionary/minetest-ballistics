local function get_target_visual_size(target)
	local parent = target:get_attach()
	while parent do
		target = parent
		parent = target:get_attach()
	end
	return target:get_properties().visual_size
end

-- TODO: this function currently does *NOT* work correctly
function ballistics.on_hit_object_attach(self, target, intersection_point, intersection_normal, box_id)
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

local function scale_tool_capabilities(tool_capabilities, scale_speed, speed)
	local scale = (speed / scale_speed) ^ 2 -- F = mv^2
	local scaled_caps = table.copy(tool_capabilities)
	for group, damage in pairs(scaled_caps.damage_groups) do
		scaled_caps.damage_groups[group] = futil.math.probabilistic_round(damage * scale)
	end
	return scaled_caps
end

function ballistics.on_hit_object_punch(self, target, intersection_point, intersection_normal, box_id)
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
	elseif self.object:get_pos() then
		puncher = self.object
	end

	if puncher then
		local arrow_velocity = self.object:get_velocity() or self._last_velocity
		if arrow_velocity then
			local relative_speed = (arrow_velocity - target:get_velocity()):length()
			target:punch(
				puncher,
				tool_capabilities.full_punch_interval or math.huge,
				scale_tool_capabilities(tool_capabilities, scale_speed, relative_speed),
				direction
			)
		else
			ballistics.log("warning", "on_hit_object_punch: arrow has no known velocity")
		end
	end

	if remove then
		self.object:remove()
		return true
	end
end

function ballistics.on_hit_object_add_entity(self, target, intersection_point, intersection_normal, box_id)
	local pprops = self._parameters.add_entity
	local entity_name = pprops.entity_name
	local chance = pprops.chance or 1
	local staticdata = pprops.staticdata

	local target_pos = target:get_pos()
	if target_pos and math.random(chance) == 1 then
		minetest.add_entity(target_pos + intersection_normal, entity_name, staticdata)
	end

	self.object:remove()
	return true
end

if minetest.get_modpath("tnt") then
	function ballistics.on_hit_object_boom(self, target, intersection_point, intersection_normal, box_id)
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

function ballistics.on_hit_object_replace(self, object, intersection_point, intersection_normal, box_id)
	local pos
	if object:get_pos() then
		pos = futil.get_object_center(object)
	elseif self.object:get_pos() then
		pos = futil.get_object_center(self.object)
	else
		return
	end
	pos = pos:round()
	return ballistics.util.replace(self, pos)
end

function ballistics.on_hit_object_active_sound_stop(self, object, intersection_point, intersection_normal, box_id)
	if self._active_sound_handle then
		minetest.sound_stop(self._active_sound_handle)
		self._active_sound_handle = nil
	end
end

function ballistics.on_hit_object_hit_sound_play(self, object, intersection_point, intersection_normal, box_id)
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

function ballistics.on_hit_object_add_item(self, object, intersection_point, intersection_normal, box_id)
	local pprops = self._parameters.add_item
	assert(pprops and pprops.item, "must specify parameters.add_item.item in projectile definition")
	local item = pprops.item
	local chance = pprops.chance or 1
	local obj = self.object
	local pos = obj:get_pos()
	if not pos then
		return
	end
	if obj:get_velocity():length() > 0.001 then
		-- only drop as an item if not moving
		return
	end
	if math.random(chance) == 1 then
		minetest.add_item(pos, item)
	end
	obj:remove()
	return true
end
