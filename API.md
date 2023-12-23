```lua
ballistics.register_projectile("mymod:myarrow", {
    -- visual parameters, see minetest's lua_api.md for details
	is_arrow = true,  -- if true, entity will automatically be rotated depending on its velocity
    update_period = nil,  -- if a positive number, how often to rotate the entity
	visual = "mesh",
	mesh = "ballistics_arrow.b3d",
    visual_size = vector.new(1, 1, 1),
	textures = { "ballistics_arrow_mesh.png" },
    spritediv = {x = 1, y = 1},
    initial_sprite_basepos = {x = 0, y = 0},
    colors = {},
    is_visible = true,
    use_texture_alpha = false,
    backface_culling = true,
    glow = 0,
    damage_texture_modifier = "^[brighten",
    shaded = true,
    show_on_minimap = false,

    -- physical parameters
	collisionbox = { -0.2, -0.2, -0.2, 0.2, 0.2, 0.2 },
	selectionbox = { -0.2, -0.2, -0.2, 0.2, 0.2, 0.2, rotate = true },
    collide_with_objects = true,
    pointable = true,

    -- logical parameters
    hp_max = 1,
    immortal = true,  -- prevent engine from modifying our HP directly
	drag_coefficient = 0.0,  -- if > 0, projectile will slow down in air and slow down a lot in water.

    -- callbacks
    -- no callbacks are mandatory, and some pre-configured behaviors are available for use - see below
    on_hit_node = function(self, pos, node, collision_axis, old_velocity, new_velocity)  end,
    on_hit_object = function(self, object, collision_axis, old_velocity, new_velocity)  end,

    on_activate = function(self, staticdata)
        -- projectiles are ephemeral (they don't static save), but staticdata can be passed on creation
    end,
    on_attach_child = function(self, child) end,
    on_deactivate = function(self, removal) end,
    on_death = function(self, killer) end,
    on_detach = function(self, parent) end,
    on_detach_child = function(self, child) end,
    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir, damage) end,
    on_rightclick = function(self, clicker) end,
    on_step = function(self, dtime, moveresult) end,
})
```

* `ballistics.shoot(entity_name, pos, vel, [acc, [shoot_param]])`

  if acceleration is not specified or nil, it will be chosen to be the server's standard gravity.
  shoot_param is additional data to pass to the entity when it is initialized. it must be serializable.

* `ballistics.player_shoots(entity_name, player, speed, gravity, shoot_param)`

  gravity and shoot_param as above. speed is a scalar, and the player must exist and be logged in. this function is
  a wrapper around the above, which automatically calculates the velocity depending on where the player is looking
  and the player's own velocity.
