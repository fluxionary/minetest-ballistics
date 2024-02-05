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
	if self._is_frozen then
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
	ballistics.apply_drag(self)
end
