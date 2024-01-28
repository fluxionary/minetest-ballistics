local f = string.format
local S = ballistics.S

ballistics.show_collisions_by_player_name = {}

minetest.register_chatcommand("ballistics_show_collision", {
	description = S("toggle showing collision position as a temporary waypoint"),
	privs = { server = true },
	func = function(name)
		if ballistics.show_collisions_by_player_name[name] then
			ballistics.show_collisions_by_player_name[name] = nil
			return true, S("disable showing collisions")
		else
			ballistics.show_collisions_by_player_name[name] = true
			return true, S("enable showing collisions")
		end
	end,
})

ballistics.register_on_hit_node(
	function(self, node_pos, node, above_pos, intersection_point, intersection_normal, box_id)
		for name in pairs(ballistics.show_collisions_by_player_name) do
			local player = minetest.get_player_by_name(name)
			if player then
				futil.create_ephemeral_hud(player, 60, {
					hud_elem_type = "image_waypoint",
					text = "ballistics_waypoint.png",
					scale = { x = -1 / 16 * 9, y = -1 },
					alignment = { x = 0, y = -1 },
					world_pos = intersection_point,
				})
				futil.create_ephemeral_hud(player, 60, {
					hud_elem_type = "waypoint",
					name = f("%s\n%s@%s", self.name, node.name, minetest.pos_to_string(node_pos)),
					number = 0xffffff,
					precision = 0,
					world_pos = intersection_point,
					alignment = { x = 0, y = 1 },
				})
			end
		end
	end
)

ballistics.register_on_hit_object(function(self, target, intersection_point, intersection_normal, box_id)
	for name in pairs(ballistics.show_collisions_by_player_name) do
		local player = minetest.get_player_by_name(name)
		if player then
			futil.create_ephemeral_hud(player, 60, {
				hud_elem_type = "image_waypoint",
				text = "ballistics_waypoint.png",
				scale = { x = -1 / 16 * 9, y = -1 },
				alignment = { x = 0, y = -1 },
				world_pos = intersection_point,
			})
			futil.create_ephemeral_hud(player, 60, {
				hud_elem_type = "waypoint",
				name = f("%s\n%s", self.name, tostring(target)),
				number = 0xffffff,
				precision = 0,
				world_pos = intersection_point,
				alignment = { x = 0, y = 1 },
			})
		end
	end
end)
