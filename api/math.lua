local atan2 = math.atan2
local cos = math.cos
local sin = math.sin
local sqrt = math.sqrt

local movement_gravity = tonumber(minetest.settings:get("movement_gravity")) or 9.81
local acceleration_due_to_gravity = vector.new(0, -2 * movement_gravity, 0) -- 2x because minetest

-- https://en.wikipedia.org/wiki/Projectile_motion#Angle_%CE%B8_required_to_hit_coordinate_(x,_y)
-- https://gamedev.stackexchange.com/questions/163212/projectile-initial-motion-to-hit-a-target-position
-- TODO: can we do this with drag? -- https://physics.stackexchange.com/a/127994
function ballistics.calculate_initial_velocity(source_pos, target_pos, initial_speed, gravity, drag)
	gravity = gravity or movement_gravity
	drag = drag or 0
	if drag ~= 0 then
		error("drag with non-zero values is not currently supported")
	end
	local delta = target_pos - source_pos
	if gravity == 0 then
		return delta:normalize() * initial_speed
	end

	local x, y, z = delta.x, delta.y, delta.z
	local v2 = initial_speed * initial_speed
	local x2z2 = x * x + z * z
	local other_part = gravity * (gravity * x2z2 + 2 * y * v2)
	local v4 = v2 * v2
	if other_part > v4 then
		-- no solution possible
		return
	end
	local theta1 = atan2(v2 + sqrt(v4 - other_part), gravity * sqrt(x2z2))
	local theta2 = atan2(v2 - sqrt(v4 - other_part), gravity * sqrt(x2z2))
	-- the lesser angle should have a reduced flight time
	-- note that in "proper" spherical coordinates, theta is the angle between the vertical axis and the ray
	-- whereas the theta we compute above is the complement of that
	local theta = (math.pi / 2) - math.min(theta1, theta2)
	local phi = atan2(delta.z, delta.x)
	-- https://en.wikipedia.org/wiki/List_of_common_coordinate_transformations#From_spherical_coordinates
	-- note that the vertical direction is y, not z
	return vector.new(
		initial_speed * sin(theta) * cos(phi),
		initial_speed * cos(theta),
		initial_speed * sin(theta) * sin(phi)
	)
end

-- Raycast in steps along an approximation of the arc of a projectile
-- https://en.wikipedia.org/wiki/Midpoint_method
-- https://indico.cern.ch/event/831093/attachments/1896309/3218515/ub_py410_odes.pdf (page 9)
-- TODO https://scicomp.stackexchange.com/questions/21060/runge-kutta-simulation-for-projectile-motion-with-drag
function ballistics.ballistic_cast(def)
	--[[
		start_pos = vector,
		start_vel = vector,
		acceleration = {0, 2 * 9.81, 0},  -- 2x cuz minetest
		drag = 0,
		stop_after = 10,  -- in seconds
		dt = 0.01,  -- timestep, in seconds
		objects = true,  -- passed to Raycast
		liquids = true,  -- passed to Raycast
		on_step = function(pos) end,  -- if provided, called for each new point in the iteration. useful for visuals.
	]]
	local pos = assert(def.pos, "must specify a starting position")
	local velocity = assert(def.velocity, "must specify a starting velocity")
	local base_acceleration = def.acceleration or acceleration_due_to_gravity
	local drag = def.drag or 0
	local stop_after = def.stop_after or 10
	local dt = def.dt or 0.01
	local objects = futil.coalesce(def.objects, true)
	local liquids = futil.coalesce(def.liquids, true)
	local on_step = def.on_step

	local function get_acceleration(pos2, velocity2)
		local node = minetest.get_node(pos2:round())
		local rho = ballistics.get_density(node.name)
		local drag_acc = -velocity2:normalize() * 0.5 * rho * drag * velocity2:dot(velocity2)
		return drag_acc + base_acceleration
	end

	local acceleration = get_acceleration(pos, velocity)

	local t = 0

	local function get_next_ray()
		local next_pos = pos + dt * (velocity + 0.5 * dt * acceleration)
		local ray = Raycast(pos, next_pos, objects, liquids)

		if on_step then
			on_step(next_pos)
		end

		t = t + dt
		pos = next_pos
		velocity = velocity + acceleration * dt
		acceleration = get_acceleration(pos, velocity)
		return ray
	end

	local ray = get_next_ray()

	return function()
		local pointed_thing = ray()
		while t <= stop_after and not pointed_thing do
			ray = get_next_ray()
			pointed_thing = ray()
		end
		return pointed_thing
	end
end
