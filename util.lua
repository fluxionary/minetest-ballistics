ballistics.util = {}

-- TODO: allow specifying multiple possible targets, groups
function ballistics.util.replace(self, pos0)
	local pprops = self._parameters.replace
	assert(pprops, "must specify parameters.replace in projectile definition")
	local target = pprops.target or "air"
	local replacement = pprops.replacement
	assert(replacement, "must specify parameters.replace.replacement in projectile definition")
	if type(replacement) == "string" then
		replacement = { name = replacement }
	end
	local radius = pprops.radius or 0
	pos0 = pos0:round()
	local try_place
	if minetest.is_player(self._source_obj) then
		local placer = self._source_obj
		local itemstack = ItemStack(replacement.name)
		local param2 = replacement.param2
		function try_place(pos)
			local pointed_thing = { type = "node", under = pos, above = pos }
			-- second argument is placed position or nil
			if select(2, minetest.item_place_node(itemstack, placer, pointed_thing, param2)) then
				return true
			end
		end
	else
		function try_place(pos)
			return minetest.place_node(pos, replacement)
		end
	end
	local placed = false
	for x = -radius, radius do
		for y = -radius, radius do
			for z = -radius, radius do
				local pos = pos0:offset(x, y, z)
				if minetest.get_node(pos).name == target and try_place(pos) then
					placed = true
				end
			end
		end
	end
	if placed and futil.coalesce(pprops.remove_on_success, true) then
		self.object:remove()
		return true
	end
end

function ballistics.util.show_path(pos, velocity, acceleration, drag)
	local cast = ballistics.ballistic_cast({
		pos = pos,
		velocity = velocity,
		acceleration = acceleration,
		drag = drag,
		dt = 0.01,
		objects = false,
		liquids = false,
		on_step = function(pos_)
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
		end,
	})
	cast()
end
