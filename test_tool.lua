local f = string.format

local api = ballistics.api

minetest.register_craftitem("ballistics:test", {
	wield_image = "ballistics_test.png",
})

api.register_missile("ballistics:test", {
	is_arrow = true,
	visual = "wielditem",
	textures = { "ballistics:test" },

	on_hit_node = function(self, pos, node, axis, old_velocity, new_velocity)
		minetest.chat_send_all(f("hit %s @ %s", node.name, minetest.pos_to_string(pos)))

		api.freeze(self)

		minetest.after(5, function()
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
			name = object:get_luaentity().name
		end

		minetest.chat_send_all(f("hit %s @ %s", name, minetest.pos_to_string(object:get_pos())))

		api.freeze(self)

		minetest.after(5, function()
			if self.object then
				self.object:remove()
			end
		end)

		return true
	end,
})

minetest.register_tool("ballistics:test_tool", {
	name = "shooty stick",
	inventory_image = "ballistics_test_tool.png",
	groups = { not_in_creative_inventory = 1 },

	on_place = function(itemstack, placer, pointed_thing) end,

	on_secondary_use = function(itemstack, user, pointed_thing) end,

	on_use = function(itemstack, user, pointed_thing)
		api.player_shoots("ballistics:test", user, 30)
	end,
})
