local atan2 = math.atan2
local cos = math.cos
local sin = math.sin
local sqrt = math.sqrt

local movement_gravity = 2 * (tonumber(minetest.settings:get("movement_gravity")) or 9.81)

-- https://en.wikipedia.org/wiki/Projectile_motion#Angle_%CE%B8_required_to_hit_coordinate_(x,_y)
-- TODO: can we do this with drag?
-- https://gamedev.stackexchange.com/questions/163212/projectile-initial-motion-to-hit-a-target-position
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

-- because objects keep moving after colliding, use geometry to figure our approximate location of the actual collision.
-- we assume the collision point is closest to the last recorded vector of motion, and the current one.
-- https://palitri.com/vault/stuff/maths/Rays%20closest%20point.pdf
-- engine issue to make this moot:
-- https://github.com/minetest/minetest/issues/9966
local threshold = 0.0001 -- if certain values are too close to 0, the results will not be good
function ballistics.estimate_collision_position(last_pos, last_vel, cur_pos, cur_vel)
	local a = cur_vel
	local b = last_vel
	local a2 = a:dot(a)
	if a2 < threshold then
		return
	end
	local b2 = b:dot(b)
	if b2 < threshold then
		return
	end
	local ab = a:dot(b)
	local denom = (a2 * b2) - (ab * ab)
	if denom < threshold then
		return
	end
	local A = cur_pos
	local B = last_pos
	local c = last_pos - cur_pos
	local bc = b:dot(c)
	local ac = a:dot(c)
	local D = A + a * ((ac * b2 - ab * bc) / denom)
	local E = B + b * ((ab * ac - bc * a2) / denom)
	return (D + E) / 2
end
