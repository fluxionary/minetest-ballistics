local v_new = vector.new
local v_rotate_around_axis = vector.rotate_around_axis

local serialize = minetest.serialize

local movement_gravity = tonumber(minetest.settings:get("movement_gravity")) or 9.81
local acceleration_due_to_gravity = v_new(0, -2 * movement_gravity, 0)

-- may return nil
function ballistics.shoot(entity_name, pos, vel, acc, source_obj, target_obj, parameters, properties)
	local obj = minetest.add_entity(
		pos,
		entity_name,
		serialize({
			parameters = parameters,
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
	if properties then
		obj:set_properties(properties)
	end
	ent._source_obj = source_obj
	if minetest.is_player(source_obj) then
		ent._source_player_name = source_obj:get_player_name()
	end
	ent._target_obj = target_obj
	local cast = ballistics.path_cast_midpoint(
		pos,
		vel,
		nil,
		nil,
		(ent._parameters.drag or {}).coefficient,
		nil,
		false,
		false,
		function(pos_)
			ballistics.chat_send_all("[DE-BUG] pos_=@1", minetest.pos_to_string(futil.vector.round(pos_, 0.01)))
			minetest.add_particlespawner({
				amount = 1,
				time = 0.1,
				texture = "ballistics_arrow_particle.png^[colorize:red:127",
				animation = {
					type = "vertical_frames",
					aspect_w = 8,
					aspect_h = 8,
					length = 1,
				},
				glow = 1,
				minvel = { x = 0, y = 0, z = 0 },
				maxvel = { x = 0, y = 0, z = 0 },
				minacc = { x = 0, y = 0, z = 0 },
				maxacc = { x = 0, y = 0, z = 0 },
				minexptime = 10,
				maxexptime = 10,
				minsize = 2,
				maxsize = 2,
				minpos = pos_,
				maxpos = pos_,
			})
		end
	)
	ballistics.chat_send_all("[DE-BUG] cast() = @1", dump(cast()))

	return obj
end

function ballistics.player_shoots(entity_name, player, speed, gravity, parameters, properties)
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
		nil,
		parameters,
		properties
	)
end

function ballistics.shoot_at(entity_name, source, target, initial_speed, gravity, parameters, properties)
	local source_pos, source_obj, target_pos, target_obj
	if vector.check(source) then
		source_pos = source
	else
		source_pos = futil.get_object_center(source)
		source_obj = source
	end
	if vector.check(target) then
		target_pos = target
	else
		target_pos = futil.get_object_center(target)
		target_obj = target
	end
	if not (source_pos and target_pos) then
		return
	end

	local vel = ballistics.calculate_initial_velocity(source_pos, target_pos, initial_speed, gravity)
	if not vel then
		return
	end

	return ballistics.shoot(entity_name, source_pos, vel, gravity, source_obj, target_obj, parameters, properties)
end
