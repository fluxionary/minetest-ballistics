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

* `ballistics.shoot(entity_name, pos, vel, [acc, [source_obj, [shoot_params]]])`

  if acceleration is not specified or nil, it will be chosen to be the server's standard gravity.
  shoot_param is additional data to pass to the entity when it is initialized. it must be serializable.

* `ballistics.player_shoots(entity_name, player, speed, [gravity, [shoot_params]])`

  gravity and shoot_param as above. speed is a scalar, and the player must exist and be logged in. this function is
  a wrapper around the above, which automatically calculates the velocity depending on where the player is looking
  and the player's own velocity.

## pre-defined callbacks ##

### on_hit_node callbacks ###

the default on_hit_node behavior is to disappear.

* `on_hit_node = ballistics.on_hit_node_freeze`

  when the projectile hits a node, it will stop moving. useful for making arrows that "stick into" the ground and
  stay there.

* `on_hit_node = ballistics.on_hit_node_add_entity`

  when the projectile hits a node, add an entity adjacent to the face which was struck. the projectile is removed.
  this requires additional parameters specified in the projectile definition:
  ```lua
  projectile_properties = {
      add_entity = {
          entity_name = "mymod:myentity",
          chance = nil,  -- 1 / chance to spawn entity, defaults to 1
          staticdata = nil,  -- optional, in case you want to specify staticdata to the entity on initialization
      },
  }
  ```

* `on_hit_node = ballistics.on_hit_node_boom`

  only available if the tnt mod is present. on hitting a node, create an explosion. the projectile is removed.
  optionally, explosion parameters can be specified in the projectile definition:
  ```lua
  projectile_properties = {
      boom = {
          -- see https://github.com/minetest/minetest_game/blob/43185f19e386af3b7a0831fc8e7417d0e54544e7/game_api.txt#L546-L547
      },
  }
  ```

* `on_hit_node = ballistics.on_hit_node_bounce`

  NOTE: this is not functioning properly yet and may be removed and added to a separate "ball" mod.
  on hitting a node, bounce off of the node. some parameters controlling how much bounce are optional:
  ```lua
  projectile_properties = {
      bounce = {
          efficiency = nil,  -- what quantity of the speed in the relevant axis is preserved. default is 1 (100%).
          clamp = nil,  -- if specified, if the speed in the relevant axis is below this value, set it to 0. default 0.
      },
  }
  ```

* `on_hit_node = ballistics.on_hit_node_dig`

  on hitting a node, dig it. if a projectile associated with a player hits the node, the player may get the node's drops
  in their inventory. otherwise, the node disappears. the projectile is removed.

* `on_hit_node = ballistics.on_hit_node_replace`

  on hitting a node, replace the node adjacent to the face of the node with a different node. the projectile is removed.
  this requires additional parameters specified in the projectile definition:
  ```lua
  projectile_properties = {
      replace = {
          target = nil,  -- what to replace. defaults to "air". multiple nodes and groups are planned for a future release.
          replacement = "mymod:mynode" or {name = "mymod:mynode", param2 = 0},  -- what to replace it with. required.
          radius = nil,  -- how many additional nodes around the center to replace. defaults to 0 (just the center).
      },
  }
  ```

### on_hit_object callbacks ###

the default on_hit_object behavior is to disappear.

* `on_hit_object = ballistics.on_hit_object_stick`

  NOTE: this function currently does *NOT* work correctly - the projectile is *not* attached in the right place.
  when the projectile hits an object, it will attach itself to the object.

* `on_hit_object = ballistics.on_hit_object_punch`

  punch the object. if the projectile originated from a player or entity, the punch appears to be caused by that
  player or entity, allowing integration with e.g. PvP mods, or mobs to attack the origin of the projectile. damage is
  scaled with projectile speed. this requires additional parameters specified in the projectile definition:
  ```lua
  projectile_properties = {
      punch = {
          tool_capabilities = {
              -- required. see https://github.com/minetest/minetest/blob/335af393f09b3629587f14d41a90ded4a3cbddcd/doc/lua_api.md?plain=1#L2248-L2436
              -- for details. probably only damage_groups are relevant.
          },
          scale_speed = nil,  -- speed to which damage from the projectile is scaled. defaults to 20.
          remove = nil,  -- if true, the projectile is removed. leave this alone if you want to e.g. leave an arrow
                         -- attached to the target
      },
  }
  ```

* `on_hit_object = ballistics.on_hit_object_add_entity`

  when the projectile hits an object, add an entity adjacent to it. the projectile is removed.
  this requires additional parameters specified in the projectile definition:
  ```lua
  projectile_properties = {
      add_entity = {
          entity_name = "mymod:myentity",
          chance = nil,  -- 1 / chance to spawn entity, defaults to 1
          staticdata = nil,  -- optional, in case you want to specify staticdata to the entity on initialization
      },
  }
  ```

* `on_hit_object = ballistics.on_hit_object_boom`

  only available if the tnt mod is present. on hitting an object, create an explosion. the projectile is removed.
  optionally, explosion parameters can be specified in the projectile definition:
  ```lua
  projectile_properties = {
      boom = {
          -- see https://github.com/minetest/minetest_game/blob/43185f19e386af3b7a0831fc8e7417d0e54544e7/game_api.txt#L546-L547
      },
  }
  ```

* `on_hit_object = ballistics.on_hit_object_replace`

  on hitting an object, replace the node adjacent to the face of the node with a different node. the projectile is removed.
  this requires additional parameters specified in the projectile definition:
  ```lua
  projectile_properties = {
      replace = {
          target = nil,  -- what to replace. defaults to "air". multiple nodes and groups are planned for a future release.
          replacement = "mymod:mynode" or {name = "mymod:mynode", param2 = 0},  -- what to replace it with. required.
          radius = nil,  -- how many additional nodes around the center to replace. defaults to 0 (just the center).
      },
  }
  ```

### on_punch callbacks ###

* `on_punch = ballistics.on_punch_deflect`

  when the projectile is punched, redirect the projectile in the direction it was punched.

* `on_punch = ballistics.on_punch_add_velocity`

  when the projectile is punched, add velocity in the direction it was punched, according to how much "damage" was done

* `on_punch = ballistics.on_punch_drop_item`

  when the projectile is punched, it is removed and an item is dropped in its place. this behavior only triggers if
  the projectile is not moving. requires additional parameters specified in the projectile definition:
  ```lua
  projectile_properties = {
      replace = {
          item = "mymod:itemname",
          chance = nil,  -- 1 in `chance` chance that the item will drop. defaults to 1.
      },
  }
  ```

### on_step callbacks ###

* `on_step = ballistics.on_step_particles`
