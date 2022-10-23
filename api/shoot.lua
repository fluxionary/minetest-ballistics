local v_new = vector.new
local v_rotate_around_axis = vector.rotate_around_axis

local movement_gravity = tonumber(minetest.settings:get("movement_gravity")) or 9.81

local api = ballistics.api

function api.shoot(name, pos, vel, acc, shoot_param)
	local obj = minetest.add_entity(pos, name)
	local ent = obj:get_luaentity()
	ent._shoot_param = shoot_param
	obj:set_velocity(vel)
	acc = acc or v_new(0, -movement_gravity, 0)
	obj:set_acceleration(acc)
	api.adjust_pitch(ent)
end

function api.player_shoots(name, player, speed, gravity, shoot_param)
	local look = player:get_look_dir()
	local eye_height = v_new(0, player:get_properties().eye_height, 0)
	local eye_offset = player:get_eye_offset() * 0.1
	local yaw = player:get_look_horizontal()
	local start = player:get_pos() + eye_height + v_rotate_around_axis(eye_offset, {x=0,y=1,z=0}, yaw)
	api.shoot(
		name,
		start,
		(look * speed) + player:get_velocity(),
		vector.new(0, -2 * (gravity or movement_gravity), 0),
		shoot_param
	)
end
