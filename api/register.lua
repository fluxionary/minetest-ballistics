ballistics.registered_on_hit_nodes, ballistics.register_on_hit_node = futil.make_registration()
ballistics.registered_on_hit_objects, ballistics.register_on_hit_object = futil.make_registration()

function ballistics.register_projectile(name, def)
	minetest.register_entity(name, {
		initial_properties = {
			physical = false,
			collide_with_objects = false,

			static_save = def.static_save or false,

			hp_max = def.hp_max or 1,
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

		_immortal = futil.coalesce(def.immortal, true),
		_is_arrow = futil.coalesce(def.is_arrow, false),
		_collide_with_objects = futil.coalesce(def.collide_with_objects, true),
		_update_period = def.update_period,

		_parameters = def.parameters or {},

		_on_hit_node = def.on_hit_node,
		_on_hit_object = def.on_hit_object,

		_on_activate = def.on_activate,
		on_activate = function(self, staticdata)
			-- wrapped to allow overriding ballistics.on_activate
			ballistics.on_activate(self, staticdata)
		end,

		get_staticdata = def.get_staticdata,

		_on_step = def.on_step,
		on_step = function(self, dtime)
			-- wrapped to allow overriding ballistics.on_step
			ballistics.on_step(self, dtime)
		end,

		on_attach_child = def.on_attach_child,
		on_deactivate = def.on_deactivate,
		on_death = def.on_death,
		on_detach = def.on_detach,
		on_detach_child = def.on_detach_child,
		on_punch = def.on_punch,
		on_rightclick = def.on_rightclick,
	})
end
