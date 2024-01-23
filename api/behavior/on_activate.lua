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
