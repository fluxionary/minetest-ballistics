function ballistics.register_projectile(name, def)
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

		_drag_coefficient = def.drag_coefficient or 0,
		_immortal = futil.coalesce(def.immortal, true),
		_is_arrow = futil.coalesce(def.is_arrow, false),
		_update_period = def.update_period,

		_on_hit_node = def.on_hit_node,
		_on_hit_object = def.on_hit_object,

		_projectile_properties = def.projectile_properties,

		_on_activate = def.on_activate,
		on_activate = function(self, staticdata)
			ballistics.on_activate(self, staticdata)
		end,

		on_attach_child = def.on_attach_child,
		on_deactivate = def.on_deactivate,
		on_death = def.on_death,
		on_detach = def.on_detach,
		on_detach_child = def.on_detach_child,
		on_punch = def.on_punch,
		on_rightclick = def.on_rightclick,

		_on_step = def.on_step,
		on_step = function(self, dtime, moveresult)
			ballistics.on_step(self, dtime, moveresult)
		end,
	})
end
