local api = ballistics.api

function api.register_missile(name, def)
	local is_arrow = def.is_arrow

	minetest.register_entity(name, {
		initial_properties = {
			hp_max = 1,
			physical = true,
			collide_with_objects = true,
			pointable = true,
			is_visible = true,
			static_save = false,

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
		},

		get_staticdata = function(self)
			minetest.chat_send_all("ERROR ARROW IS STATIC SAVING")
		end,

		on_activate = function(self, staticdata, dtime_s)
			if def.on_activate then
				def.on_activate(self, staticdata, dtime_s)
			end
		end,

		on_deactivate = function(self, removal)
			if def.on_deactivate then
				def.on_deactivate(self, removal)
			end
		end,

		on_step = function(self, dtime, moveresult)
			if def.on_step then
				if def.on_step(self, dtime, moveresult) then
					return
				end
			end

			-- first, handle collisions
			for _, collision in ipairs(moveresult.collisions) do
				if api.handle_collision(self, collision, def.on_hit_node, def.on_hit_object) then
					return
				end
			end

			if is_arrow then
				api.adjust_pitch(self, dtime, def.update_period)
			end

			api.emerge_target(self, dtime)
		end,

		on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
			if def.on_punch then
				def.on_punch(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
			end
		end,

		on_rightclick = function(self, clicker)
			if def.on_rightclick then
				def.on_rightclick(self, clicker)
			end
		end,
	})
end
