local v_new = vector.new
local v_rotate_around_axis = vector.rotate_around_axis

local serialize = minetest.serialize

local movement_gravity = tonumber(minetest.settings:get("movement_gravity")) or 9.81
local acceleration_due_to_gravity = v_new(0, -2 * movement_gravity, 0)

-- may return nil
function ballistics.shoot(entity_name, pos, vel, acc, source_obj, projectile_properties)
	local obj = minetest.add_entity(
		pos,
		entity_name,
		serialize({
			projectile_properties = projectile_properties,
			velocity = vel,
			acceleration = acc or acceleration_due_to_gravity,
		})
	)
	if not obj then
		return
	end
	local ent = obj:get_luaentity()
	if not ent then
		return
	end
	ent._source_obj = source_obj
	return obj
end

function ballistics.player_shoots(entity_name, player, speed, gravity, projectile_properties)
	if not futil.is_player(player) then
		-- TODO: figure out fake player compatibility
		return
	end
	local look = player:get_look_dir()
	local eye_height = v_new(0, player:get_properties().eye_height, 0)
	local eye_offset = player:get_eye_offset() * 0.1
	local yaw = player:get_look_horizontal()
	local start = player:get_pos() + eye_height + v_rotate_around_axis(eye_offset, { x = 0, y = 1, z = 0 }, yaw)
	return ballistics.shoot(
		entity_name,
		start,
		(look * speed) + futil.get_velocity(player),
		v_new(0, -2 * (gravity or movement_gravity), 0),
		player,
		projectile_properties
	)
end
