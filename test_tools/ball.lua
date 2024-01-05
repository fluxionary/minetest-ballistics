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
			clamp = 0.1,
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
