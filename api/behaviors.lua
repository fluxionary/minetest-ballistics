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
	if not self.object then
		return
	end
	local pos = self.object:get_pos()
	if not pos then
		return
	end
	correct_position(self, pos, new_velocity)

	ballistics.freeze(self)
end

function ballistics.on_hit_node_add_entity(self, node_pos, node, axis, old_velocity, new_velocity)
	local entity_name = self._properties.add_entity.entity_name
	local chance = self._properties.add_entity.chance or 1
	local staticdata = self._properties.add_entity.staticdata
	if math.random(chance) == 1 then
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
		minetest.add_entity(node_pos + delta, entity_name, staticdata)
	end

	self.object:remove()
	return true
end

if minetest.get_modpath("tnt") then
	function ballistics.on_hit_node_boom(self, node_pos, node, axis, old_velocity, new_velocity)
		local boom = self._properties.boom or {}
		local def = table.copy(boom)
		if self._source_obj and minetest.is_player(self._source_obj) then
			def.owner = self._source_obj:get_player_name()
		end
		self.object:remove()
		tnt.boom(node_pos, def)
		return true
	end
end

function ballistics.on_hit_node_bounce(self, node_pos, node, axis, old_velocity)
	local bounce = self._properties.bounce or {}
	local efficiency = bounce.efficiency or 1
	local clamp = bounce.clamp or 0

	local new_velocity = vector.copy(old_velocity)
	if axis == "x" then
		new_velocity.x = -new_velocity.x * efficiency
	elseif axis == "y" then
		new_velocity.y = -new_velocity.y * efficiency
	elseif axis == "z" then
		new_velocity.z = -new_velocity.z * efficiency
	end

	if math.abs(new_velocity.x) <= clamp then
		new_velocity.x = 0
	end
	if math.abs(new_velocity.y) <= clamp then
		new_velocity.y = 0
	end
	if math.abs(new_velocity.z) <= clamp then
		new_velocity.z = 0
	end

	self.object:set_velocity(new_velocity)
	return true
end

function ballistics.on_hit_node_dig(self, node_pos, node, axis, old_velocity, new_velocity)
	minetest.node_dig(node_pos, node, self._source_obj)
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
	local our_obj = self.object
	if not self.object then
		return
	end
	if not our_obj:get_pos() then
		return
	end

	ballistics.freeze(self)
	local target_visual_size = get_target_visual_size(target)
	local our_visual_size = our_obj:get_properties().visual_size
	our_obj:set_properties({
		-- note: using `:divide` to get schur quotient is deprecated
		visual_size = vector.new(
			our_visual_size.x / target_visual_size.x,
			our_visual_size.y / target_visual_size.y,
			our_visual_size.z / target_visual_size.z
		),
	})
	local our_rotation = our_obj:get_rotation()
	local target_rotation = target:get_rotation()
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
		if not (our_obj:get_pos() and target:get_pos()) then
			return
		end
		our_obj:set_attach(target, "", position, rotation:apply(math.deg))
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
	assert(
		self._properties.punch and self._properties.punch.tool_capabilities,
		"must specify _properties.punch.tool_capabilities in the projectile's definition"
	)
	local tool_capabilities = self._properties.punch.tool_capabilities
	local scale_speed = self._properties.punch.scale_speed or 20
	local remove = futil.coalesce(self._properties.punch.remove, false)
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
	end
end

--- end on_hit_object callbacks ---
--- on_punch callbacks ---

function ballistics.on_punch_redirect(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
	if not dir then
		return
	end
	local obj = self.object
	if not obj then
		return
	end
	local velocity = obj:get_velocity()
	if not velocity then
		return
	end
	local speed = velocity:length()
	obj:set_velocity(dir * speed)
end

function ballistics.on_punch_drop_item(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
	assert(
		self._properties.drop_item and self._properties.drop_item.item,
		"must specify projectile_properties.drop_item.item in projectile definition"
	)
	local item = self._properties.drop_item.item
	local chance = self._properties.drop_item.chance or 1
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
