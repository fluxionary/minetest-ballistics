ballistics.register_projectile("ballistics:test_arrow", {
	is_arrow = true,
	visual = "mesh",
	mesh = "ballistics_arrow.b3d",
	textures = { "ballistics_arrow_mesh.png" },
	collisionbox = { -0.2, -0.2, -0.2, 0.2, 0.2, 0.2 },
	selectionbox = { -0.05, -0.05, -0.2, 0.05, 0.05, 0.2, rotate = true },

	drag_coefficient = 0.1,

	on_hit_node = function(self, pos, node, axis, old_velocity, new_velocity)
		ballistics.chat_send_all("hit @1 @@ @2", node.name, minetest.pos_to_string(pos))
		ballistics.on_hit_node_freeze(self, pos, node, axis, old_velocity, new_velocity)
		minetest.after(15, function()
			if self.object then
				self.object:remove()
			end
		end)

		return true
	end,

	on_hit_object = function(self, object, axis, old_velocity, new_velocity)
		local name
		if minetest.is_player(object) then
			name = object:get_player_name()
		else
			name = (object:get_luaentity() or {}).name or "?"
		end
		ballistics.chat_send_all(
			"hit @1 @@ @2",
			name,
			minetest.pos_to_string(futil.vector.round(object:get_pos(), 0.01))
		)
		ballistics.on_hit_object_stick(self, object, axis, old_velocity, new_velocity)
		minetest.after(15, function()
			if self.object then
				self.object:remove()
			end
		end)

		return true
	end,
})

minetest.register_tool("ballistics:test_arrow", {
	name = "shoot an arrow",
	inventory_image = "ballistics_test_tool.png",
	groups = { not_in_creative_inventory = 1 },
	on_place = function(itemstack, placer, pointed_thing) end,
	on_secondary_use = function(itemstack, user, pointed_thing) end,
	on_use = function(itemstack, user, pointed_thing)
		ballistics.player_shoots("ballistics:test_arrow", user, 30)
	end,
})

ballistics.register_projectile("ballistics:test_ball", {
	visual = "mesh",
	mesh = "ballistics_ball.x",
	textures = { "ballistics_ball.png" },
	collisionbox = { -0.2, -0.2, -0.2, 0.2, 0.2, 0.2 },
	selectionbox = { -0.2, -0.2, -0.2, 0.2, 0.2, 0.2, rotate = true },

	drag_coefficient = 0.1,

	projectile_properties = {
		bounce = {
			efficiency = 0.6,
			clamp = 1,
		},
	},

	on_hit_node = ballistics.on_hit_node_bounce,

	on_hit_object = function(self, object, axis, old_velocity, new_velocity) end,
})

minetest.register_tool("ballistics:test_ball", {
	name = "shoot a ball",
	inventory_image = "ballistics_test_tool.png",
	groups = { not_in_creative_inventory = 1 },
	on_place = function(itemstack, placer, pointed_thing) end,
	on_secondary_use = function(itemstack, user, pointed_thing) end,
	on_use = function(itemstack, user, pointed_thing)
		ballistics.player_shoots("ballistics:test_ball", user, 10)
	end,
})
