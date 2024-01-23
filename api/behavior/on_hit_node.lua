function ballistics.on_hit_node_freeze(self, node_pos, node, axis, old_velocity, new_velocity)
	local obj = self.object
	local our_pos = obj:get_pos()
	if not our_pos then
		return
	end

	local collision_position = ballistics.guess_collision_position(self, new_velocity)
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
	local pos0 = get_adjacent_node(self, node_pos, axis)
	return ballistics.util.replace(self, pos0)
end

function ballistics.on_hit_node_active_sound_stop(self)
	if self._active_sound_handle then
		minetest.sound_stop(self._active_sound_handle)
		self._active_sound_handle = nil
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

function ballistics.on_hit_node_become_non_physical(self)
	self.object:set_properties({ physical = false })
end
