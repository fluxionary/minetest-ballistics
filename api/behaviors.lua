local threshold = 0.0001

-- because objects keep moving after colliding...
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
	return true
end

local function get_target_visual_size(target)
	local parent = target:get_attach()
	while parent do
		target = parent
		parent = target:get_attach()
	end
	return target:get_properties().visual_size
end

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

	-- TODO: need to rotate the position... around what exactly?

	-- after, to allow the visual size to propagate
	minetest.after(0, function()
		if not (our_obj:get_pos() and target:get_pos()) then
			return
		end
		our_obj:set_attach(target, "", position, rotation:apply(math.deg))
	end)
end

function ballistics.on_punch_redirect(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
	if not dir then
		return
	end
	if not self.object then
		return
	end
	local velocity = self.object:get_velocity()
	if not velocity then
		return
	end
	local speed = velocity:length()
	self.object:set_velocity(dir * speed)
	return true
end
