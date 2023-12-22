local threshold = 0.0001

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

function ballistics.on_hit_object_stick(self, object, axis, old_velocity, new_velocity)
	if not self.object then
		return
	end
	local pos = self.object:get_pos()
	if not pos then
		return
	end

	ballistics.freeze(self)
	self.object:set_attach(object)
end

function ballistics.on_punch_redirect(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
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
