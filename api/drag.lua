-- https://en.wikipedia.org/wiki/Drag_(physics)

local get_node = minetest.get_node

local density = {}

local function is_full_node(def)
	local box = def.collision_box or def.node_box
	if not box then
		return true
	elseif box.type == "regular" then
		return true
	elseif box.type == "fixed" then
		return futil.equals(box.fixed, { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 })
	end
	return false
end

minetest.register_on_mods_loaded(function()
	for node_name, def in pairs(minetest.registered_nodes) do
		if def.walkable then
			if is_full_node(def) then
				density[node_name] = math.huge
			else
				-- for things like stairs, where part of them is not there
				density[node_name] = 0.1204
			end
		elseif def.liquidtype == "none" then
			density[node_name] = 0.1204
		else
			density[node_name] = (def.move_resistance or def.liquid_viscosity or 1) + 1
		end
	end
end)

function ballistics.get_density(node_name)
	return density[node_name] or math.huge
end

function ballistics.apply_drag(entity)
	local pprops = entity._parameters.drag
	if not pprops then
		return
	end

	local drag_coefficient = pprops.coefficient
	if drag_coefficient == 0 then
		return
	end
	if entity._is_frozen then
		return
	end
	local obj = entity.object
	if not obj then
		return
	end
	local pos = obj:get_pos()
	if not pos then
		return
	end

	pos = pos:round()
	local node = get_node(pos)
	local rho = ballistics.get_density(node.name)
	local velocity = obj:get_velocity()
	local speed = velocity:length()
	if speed == 0 then
		return
	end
	local acceleration = 0.5 * rho * (speed * speed) * drag_coefficient
	local delta_v = acceleration * (entity._lifetime - entity._last_lifetime)
	delta_v = math.min(speed, delta_v) -- don't go backwards due to lag or something...
	local delta_velocity = velocity * (-delta_v / speed)
	obj:add_velocity(delta_velocity)
end

--[[
-- TODO: this needs to apply drag iteratively, not all at once, because lag
function ballistics.apply_drag(entity)
	local pprops = entity._parameters.drag
	if not pprops then
		return
	end

	local drag_coefficient = pprops.coefficient
	if drag_coefficient == 0 then
		return
	end
	if entity._is_frozen then
		return
	end
	local obj = entity.object
	if not obj then
		return
	end
	local pos = obj:get_pos()
	if not pos then
		return
	end

	local dtime = entity._lifetime - entity._last_lifetime

	pos = pos:round()
	local node = get_node(pos)
	local rho = ballistics.get_density(node.name)
	local base_velocity = obj:get_velocity()
	local speed = base_velocity:length()
	if speed == 0 then
		return
	end
	local velocity = base_velocity

	local elapsed = 0
	for _ = 0, dtime, .01 do
		elapsed = _
		local acceleration = 0.5 * rho * (speed * speed) * drag_coefficient
		local delta_v = math.min(speed, acceleration * .01) -- don't go backwards due to lag or something...
		velocity = velocity * (1 - (delta_v / speed))
		speed = velocity:length()
	end

	local acceleration = 0.5 * rho * (speed * speed) * drag_coefficient
	local delta_v = math.min(speed, acceleration * (dtime - elapsed)) -- don't go backwards due to lag or something...
	velocity = velocity * (1 - (delta_v / speed))

	obj:add_velocity(base_velocity - velocity)
end
]]
