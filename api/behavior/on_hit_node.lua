function ballistics.on_hit_node_freeze(self, node_pos, node, above_pos, intersection_point, intersection_normal, box_id)
	local obj = self.object
	local our_pos = obj:get_pos()
	if not our_pos then
		return
	end

	obj:set_pos(intersection_point)

	ballistics.freeze(self)
end

function ballistics.on_hit_node_add_entity(
	self,
	node_pos,
	node,
	above_pos,
	intersection_point,
	intersection_normal,
	box_id
)
	local pprops = self._parameters.add_entity
	assert(pprops, "must define parameters.add_entity in projectile definition")
	local entity_name = pprops.entity_name
	assert(pprops, "must specify parameters.add_entity.entity_name in projectile definition")
	local chance = pprops.chance or 1
	local staticdata = pprops.staticdata

	if math.random(chance) == 1 then
		minetest.add_entity(above_pos, entity_name, staticdata)
	end

	self.object:remove()
	return true
end

if minetest.get_modpath("tnt") then
	function ballistics.on_hit_node_boom(
		self,
		node_pos,
		node,
		above_pos,
		intersection_point,
		intersection_normal,
		box_id
	)
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

function ballistics.on_hit_node_dig(self, node_pos, node, above_pos, intersection_point, intersection_normal, box_id)
	minetest.node_dig(node_pos, node, self._source_obj)
	self.object:remove()
	return true
end

function ballistics.on_hit_node_replace(
	self,
	node_pos,
	node,
	above_pos,
	intersection_point,
	intersection_normal,
	box_id
)
	return ballistics.util.replace(self, above_pos)
end

function ballistics.on_hit_node_active_sound_stop(
	self,
	node_pos,
	node,
	above_pos,
	intersection_point,
	intersection_normal,
	box_id
)
	if self._active_sound_handle then
		minetest.sound_stop(self._active_sound_handle)
		self._active_sound_handle = nil
	end
end

function ballistics.on_hit_node_hit_sound_play(
	self,
	node_pos,
	node,
	above_pos,
	intersection_point,
	intersection_normal,
	box_id
)
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
