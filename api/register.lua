local deserialize = minetest.deserialize

function ballistics.register_missile(name, def)
	minetest.register_entity(name, {
		initial_properties = {
			physical = true,
			static_save = false,

			hp_max = def.hp_max or 1,
			collide_with_objects = futil.coalesce(def.collide_with_objects, true),
			pointable = futil.coalesce(def.pointable, true),
			is_visible = futil.coalesce(def.is_visible, true),

			visual = def.visual,
			collisionbox = def.collisionbox,
			selectionbox = def.selectionbox,
			visual_size = def.visual_size,
			mesh = def.mesh,
			textures = def.textures,
			spritediv = def.spritediv,
			initial_sprite_basepos = def.initial_sprite_basepos,
			colors = def.colors,
			use_texture_alpha = def.use_texture_alpha,
			backface_culling = def.backface_culling,
			glow = def.glow,
			damage_texture_modifier = def.damage_texture_modifier,
			shaded = def.shaded,
			show_on_minimap = def.show_on_minimap,
		},

		_on_hit_node = def.on_hit_node,
		_on_hit_object = def.on_hit_object,

		on_activate = function(self, staticdata)
			local obj = self.object
			if not obj then
				return
			end

			local initial_properties = deserialize(staticdata)

			self._shoot_param = initial_properties.shoot_param
			obj:set_velocity(initial_properties.velocity)
			obj:set_acceleration(initial_properties.acceleration)

			self._lifetime = 0
			self._last_lifetime = 0
			self._last_pos = obj:get_pos()
			self._last_velocity = vector.copy(initial_properties.velocity)

			if def.immortal ~= false then
				self.object:set_armor_groups({ immortal = 1 })
			end

			ballistics.set_initial_pitch(self)

			if def.on_activate then
				def.on_activate(self, staticdata)
			end
		end,

		on_deactivate = def.on_deactivate,
		on_death = def.on_death,
		on_punch = def.on_punch,
		on_rightclick = def.on_rightclick,

		on_step = function(self, dtime, moveresult)
			local obj = self.object
			if not obj then
				return
			end
			local pos = obj:get_pos()
			if not pos then
				return
			end
			local vel = obj:get_velocity()

			self._lifetime = (self._lifetime or 0) + dtime
			if def.on_step then
				if def.on_step(self, dtime, moveresult) then
					self._last_lifetime = self._lifetime
					self._last_pos = pos
					self._last_velocity = vel
					return
				end
			end

			-- first, handle collisions
			if moveresult then
				for _, collision in ipairs(moveresult.collisions) do
					if ballistics.handle_collision(self, collision) then
						self._last_lifetime = self._lifetime
						self._last_pos = pos
						self._last_velocity = vel
						return
					end
				end
			end

			if def.is_arrow then
				ballistics.adjust_pitch(self, dtime, def.update_period)
			end

			self._last_lifetime = self._lifetime
			self._last_pos = pos
			self._last_velocity = vel
		end,
	})
end
