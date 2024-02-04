function ballistics.on_punch_deflect(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
	if not dir then
		return
	end
	local obj = self.object
	local velocity = obj:get_velocity()
	if not velocity then
		return
	end
	local speed = velocity:length()
	obj:set_velocity(dir * speed)
end

local add_velocity_scale = {
	constant = function(pprops)
		return (pprops.offset or 1)
	end,
	linear = function(pprops, damage)
		if (pprops.input or "damage") == "damage" then
			return (pprops.scale or 1) * damage + (pprops.offset or 0)
		else
			error(string.format("unknown input %s", pprops.input))
		end
	end,
}

function ballistics.on_punch_add_velocity(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
	if not dir then
		return
	end
	local obj = self.object
	local velocity = obj:get_velocity()
	if not velocity then
		return
	end
	local pprops = self._parameters.add_velocity or {}
	local scale = add_velocity_scale[pprops.scale or "constant"](pprops, damage)
	obj:add_velocity(dir * scale)
end

function ballistics.on_punch_drop_item(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
	local pprops = self._parameters.drop_item
	assert(pprops and pprops.item, "must specify parameters.drop_item.item in projectile definition")
	local obj = self.object
	local pos = obj:get_pos()
	if not pos then
		return
	end
	if obj:get_velocity():length() > 0.001 then
		-- only drop as an item if not moving
		return
	end
	local item = pprops.item
	local chance = pprops.chance or 1
	if math.random(chance) == 1 then
		minetest.add_item(pos, item)
	end
	obj:remove()
	return true
end

function ballistics.on_punch_pickup_item(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
	local pprops = self._parameters.pickup_item
	assert(pprops and pprops.item, "must specify parameters.pickup_item.item in projectile definition")
	if not minetest.is_player(puncher) then
		return
	end
	local obj = self.object
	local vel = obj:get_velocity()
	if vel and vel:length() > 0.001 then
		return
	end
	local item = pprops.item
	local chance = pprops.chance or 1
	local is_creative = minetest.is_creative_enabled(puncher:get_player_name())
	if math.random(chance) == 1 and not (is_creative and puncher:get_inventory():contains_item("main", item)) then
		local leftover = minetest.item_pickup(ItemStack(item), puncher, { type = "object", ref = obj })
		if not leftover:is_empty() then
			local pos = obj:get_pos() or puncher:get_pos()
			if pos then
				minetest.add_item(pos, item)
			end
		end
	end
	obj:remove()
	return true
end
