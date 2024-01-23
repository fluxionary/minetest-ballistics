function ballistics.on_deactivate_active_sound_stop(self, removal)
	if self._active_sound_handle then
		minetest.sound_stop(self._active_sound_handle)
		self._active_sound_handle = nil
	end
end
