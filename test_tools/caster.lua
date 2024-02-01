minetest.register_tool("ballistics:caster", {
	description = ballistics.S("cast a ray and see what it hits"),
	inventory_image = "ballistics_test_tool.png",
	groups = { not_in_creative_inventory = 1 },
	on_place = function(itemstack, placer, pointed_thing) end,
	on_secondary_use = function(itemstack, user, pointed_thing) end,
	on_use = function(itemstack, user, pointed_thing)
		if not minetest.is_player(user) then
			return
		end
		local look = user:get_look_dir()
		local eye_height = vector.new(0, user:get_properties().eye_height, 0)
		local eye_offset = user:get_eye_offset() * 0.1
		local yaw = user:get_look_horizontal()
		local start = user:get_pos() + eye_height + vector.rotate_around_axis(eye_offset, { x = 0, y = 1, z = 0 }, yaw)

		for pt in Raycast(start, start + (100 * look)) do
			if pt.type ~= "object" or pt.ref ~= user then
				futil.create_ephemeral_hud(user, 60, {
					hud_elem_type = "image_waypoint",
					text = "ballistics_waypoint.png",
					scale = { x = -1 / 16 * 9, y = -1 },
					alignment = { x = 0, y = -1 },
					world_pos = pt.intersection_point,
				})
				break
			end
		end
	end,
})
