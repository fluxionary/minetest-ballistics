local S = ballistics.S

local function get_pos1(name)
	if minetest.get_modpath("worldedit") and worldedit.pos1[name] then
		return worldedit.pos1[name]
	end
	if minetest.get_modpath("areas") and areas.pos1[name] then
		return vector.new(areas.pos1[name])
	end
end

local function get_pos2(name)
	if minetest.get_modpath("worldedit") and worldedit.pos2[name] then
		return worldedit.pos2[name]
	end
	if minetest.get_modpath("areas") and areas.pos2[name] then
		return vector.new(areas.pos2[name])
	end
end

ballistics.register_projectile("ballistics:test_target", {
	visual = "sprite",
	textures = { "ballistics_ball.png" },
	collisionbox = { -0.2, -0.2, -0.2, 0.2, 0.2, 0.2 },
	selectionbox = { -0.2, -0.2, -0.2, 0.2, 0.2, 0.2, rotate = true },

	on_step = ballistics.on_step_seek_target,

	on_hit_node = function(self, pos, node, axis, old_velocity, new_velocity)
		ballistics.on_hit_node_freeze(self, pos, node, axis, old_velocity, new_velocity)
		minetest.after(15, function()
			if self.object then
				self.object:remove()
			end
		end)

		return true
	end,

	on_hit_object = function(self)
		ballistics.freeze(self)
		minetest.after(15, function()
			if self.object then
				self.object:remove()
			end
		end)

		return true
	end,
})

minetest.register_chatcommand("ballistics_target_test", {
	privs = { server = 1 },
	func = function(name, speed)
		if not name then
			return false, S("need a name")
		end
		local source = get_pos1(name)
		if not source then
			return false, S("mark pos1 (source) with worldedit or areas")
		end
		local target = get_pos2(name)
		if not target then
			return false, S("mark pos2 (target) with worldedit or areas")
		end

		speed = tonumber(speed) or 30

		local obj = ballistics.shoot_at("ballistics:test_target", source, target, speed)
		if not obj then
			return true, S("target is too far from the source for a projectile @@@1 n/s", tostring(speed))
		end
		return true, S("missile launched")
	end,
})

minetest.register_chatcommand("ballistics_target_me", {
	privs = { server = 1 },
	func = function(name, speed)
		if not name then
			return false, S("need a name")
		end
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, S("you need to be logged in")
		end
		local source = get_pos1(name)
		if not source then
			return false, S("mark pos1 (source) with worldedit or areas")
		end

		speed = tonumber(speed) or 30

		local obj = ballistics.shoot_at("ballistics:test_target", source, player, speed, nil, {
			seek_target = {
				seek_speed = 5,
			},
		})
		if not obj then
			return true, S("you are too far from the source for a projectile @@@1 n/s", tostring(speed))
		end
		return true, S("missile launched")
	end,
})
