-- https://en.wikipedia.org/wiki/Drag_(physics)

local get_node = minetest.get_node

local density = {}

local function is_full_node(def)
	local box = def.node_box or def.collision_box
	if not box then
		return true
	elseif box.type == "regular" then
		return true
	elseif box.type == "fixed" and futil.is_box(box.fixed) then
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
				density[node_name] = 0.1204
			end
		elseif def.liquidtype == "none" then
			density[node_name] = 0.1204
		else
			density[node_name] = (def.move_resistance or def.liquid_viscosity or 1) * 10
		end
	end
end)

function ballistics.apply_drag(self)
	local obj = self.object
	if not obj then
		return
	end
	local pos = obj:get_pos()
	if not pos then
		return
	end
	local drag_coefficient = self._drag_coefficient
	if drag_coefficient == 0 then
		return
	end

	pos = pos:round()
	local node = get_node(pos)
	local rho = density[node.name] or math.huge
	local velocity = obj:get_velocity()
	local speed = velocity:length()
	if speed == 0 then
		return
	end
	local acceleration = 0.5 * rho * (speed * speed) * self._drag_coefficient
	local delta_v = acceleration * (self._lifetime - self._last_lifetime)
	delta_v = math.min(speed, delta_v) -- don't go backwards due to lag or something...
	local new_velocity = velocity * ((speed - delta_v) / speed)
	obj:set_velocity(new_velocity)
end
