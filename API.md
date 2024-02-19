## defining a projectile

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
	collisionbox = { -0.05, -0.05, -0.05, 0.05, 0.05, 0.05 },
	selectionbox = { -0.05, -0.05, -0.2, 0.05, 0.05, 0.2, rotate = true },
	pointable = true,

	-- logical parameters
	static_save = false,
	hp_max = 1,
	immortal = true,  -- prevent engine from modifying our HP directly
	drag_coefficient = 0.0,  -- if > 0, projectile will slow down in air and slow down a lot in water.

	-- callbacks
	-- no callbacks are mandatory, and some pre-configured behaviors are available for use - see below
	on_hit_node = function(self, node_pos, node, above_pos, intersection_point, intersection_normal, box_id)  end,
	on_hit_object = function(self, target, intersection_point, intersection_normal, box_id)  end,

	on_activate = function(self, staticdata)
		-- staticdata can be passed on creation. it is expected to be a serialized table. internally, the keys "parameters",
		-- "velocity" and "acceleration" are used.
		-- projectiles will initialize their velocity, acceleration, and some other things before calling this function.
	end,

	on_step = function(self, dtime, moveresult)
		-- this is called after incrementing the projectile's lifetime. if it returns a truthy value, other standard
		-- projectile on_step actions will *not* be called - handling collisions, adjusting arrow pitch, and applying
		-- drag.
	end,

	-- these all are as in a standard minetest entity
	get_staticdata = function(self) end,
	on_attach_child = function(self, child) end,
	on_deactivate = function(self, removal) end,
	on_death = function(self, killer) end,
	on_detach = function(self, parent) end,
	on_detach_child = function(self, child) end,
	on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir, damage) end,
	on_rightclick = function(self, clicker) end,
})
```

## standard projectile entity "properties"

* `self._lifetime`

  how long the projectile has existed, in seconds

* `self._last_lifetime`

  the age of the arrow at the previous server tick

* `self._last_pos`

  the position of the projectile at the last server tick

* `self._last_velocity`

  the velocity of the projectile at the last server tick

* `self._last_acceleration`

  the acceleration of the projectile at the last server tick

* `self._initial_gravity`

  acceleration in the y dimension when the projectile was created.

* `self._initial_speed`

  speed of the projectile when it was created.

* `self._parameters`

  a table which contains configuration parameters for various behaviors.

## shooting

* `ballistics.shoot(entity_name, pos, vel, [acc, [source_obj, [parameters]]])`

  if acceleration is not specified or nil, it will be chosen to be the server's standard gravity.
  parameters are overrides to an arrows default parameters, or can contain custom data.

* `ballistics.player_shoots(entity_name, player, speed, [gravity, [parameters]])`

  gravity and parameters as above. speed is a scalar, and the player must exist and be logged in. this
  function is a wrapper around the above, which automatically calculates the projectile's initial velocity depending on
  where the player is looking and the player's own velocity.

* `ballistics.shoot_at(entity_name, source, target, speed, gravity, parameters)`

  gravity and projectile_properites as above. speed is a scalar. source and target can either be positions (vectors) or
  objects. this function is another wrapper around `ballistics.shoot`, but it computes an initial velocity vector given
  the source position, target position, initial speed, and gravity. if no such vector exists, no projectile will be
  created and this will return nil. *note*: projectiles with drag are not currently supported by this method.

## pre-defined callbacks ##

note that you aren't restricted to using a single callback, most of these can easily be used together, e.g.

```lua
	on_hit_node = function(...)
		ballistics.on_hit_node_attach(...)
		ballistics.on_hit_node_active_sound_stop(...)
	end
```

### on_activate_callbacks ###

* `on_activate = ballistics.on_activate_active_sound_play`

  specify a sound to play when the projectile is created. this is useful for e.g. an arrow "whistling" sound. the sound
  handle is stored in `self._active_sound_handle`.
  required parameters:
  ```lua
  parameters = {
	  active_sound = {
		  spec = {
			  -- see https://github.com/minetest/minetest/blob/master/doc/lua_api.md#simplesoundspec
			  name = "soundname",
		  },
		  parameters = {
			  -- optional, see https://github.com/minetest/minetest/blob/master/doc/lua_api.md#sound-parameter-table
		  },
	  }
  }
  ```

### on_deactivate_callbacks ###

* `on_deactivate = ballistics.on_deactivate_active_sound_stop`

  if there's an active sound, stop it.

### on_hit_node callbacks ###

the default on_hit_node behavior is to disappear.

* `on_hit_node = ballistics.on_hit_node_attach`

  when the projectile hits a node, it will stop moving. useful for making arrows that "stick into" the ground and
  stay there.

* `on_hit_node = ballistics.on_hit_node_add_entity`

  when the projectile hits a node, add an entity adjacent to the face which was struck. the projectile is removed.
  this is useful for e.g. thrown eggs which might spawn a chicken.
  this requires additional parameters specified in the projectile definition:
  ```lua
  parameters = {
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
  parameters = {
	  boom = {
		  -- see https://github.com/minetest/minetest_game/blob/43185f19e386af3b7a0831fc8e7417d0e54544e7/game_api.txt#L546-L547
	  },
  }
  ```

* `on_hit_node = ballistics.on_hit_node_dig`

  on hitting a node, dig it. if a projectile associated with a player hits the node, the player may get the node's drops
  in their inventory. otherwise, the node disappears. the projectile is removed.

* `on_hit_node = ballistics.on_hit_node_replace`

  on hitting a node, replace the node adjacent to the face of the node with a different node. the projectile is removed.
  useful for e.g. spider web projectiles or mime glue.
  this requires additional parameters specified in the projectile definition:
  ```lua
  parameters = {
	  replace = {
		  target = nil,  -- what to replace. defaults to "air". multiple nodes and groups are planned for a future release.
		  replacement = "mymod:mynode" or {name = "mymod:mynode", param2 = 0},  -- what to replace it with. required.
		  radius = nil,  -- how many additional nodes around the center to replace. defaults to 0 (just the center).
	  },
  }
  ```

* `on_hit_node = ballistics.on_hit_node_active_sound_stop`

  if the projectile has a sound handle associated with it, stop the sound when it hits a node.

* `on_hit_node = ballistics.on_hit_node_hit_sound_play`

  play a sound when you hit a node. a SimpleSoundSpec must be provided, a sound parameters table is optional:
  ```lua
  parameters = {
	  hit_sound = {
		  spec = {
			  -- see https://github.com/minetest/minetest/blob/master/doc/lua_api.md#simplesoundspec
			  name = "soundname",
		  },
		  parameters = {
			  -- optional, see https://github.com/minetest/minetest/blob/master/doc/lua_api.md#sound-parameter-table
		  },
	  }
  }
  ```

### on_hit_object callbacks ###

the default on_hit_object behavior is to disappear.

* `on_hit_object = ballistics.on_hit_object_attach`

  NOTE: this function currently does *NOT* work correctly - the projectile is *not* attached in the right place.
  when the projectile hits an object, it will attach itself to the object.

* `on_hit_object = ballistics.on_hit_object_punch`

  punch the object. if the projectile originated from a player or entity, the punch appears to be caused by that
  player or entity, allowing integration with e.g. PvP mods, or mobs to respond to the origin of the projectile.
  damage is scaled with projectile speed. this requires additional parameters specified in the projectile definition:
  ```lua
  parameters = {
	  punch = {
		  tool_capabilities = {
			  -- required. see https://github.com/minetest/minetest/blob/335af393f09b3629587f14d41a90ded4a3cbddcd/doc/lua_api.md?plain=1#L2248-L2436
			  -- for details. probably only damage_groups are relevant.
		  },
		  scale_speed = nil,  -- speed to which damage from the projectile is scaled. defaults to the initial speed.
		  remove = nil,  -- if true, the projectile is removed. leave this alone if you want to e.g. leave an arrow
						 -- attached to the target
	  },
  }
  ```

* `on_hit_object = ballistics.on_hit_object_add_entity`

  when the projectile hits an object, add an entity adjacent to it. the projectile is removed.
  this requires additional parameters specified in the projectile definition:
  ```lua
  parameters = {
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
  parameters = {
	  boom = {
		  -- see https://github.com/minetest/minetest_game/blob/43185f19e386af3b7a0831fc8e7417d0e54544e7/game_api.txt#L546-L547
	  },
  }
  ```

* `on_hit_object = ballistics.on_hit_object_replace`

  on hitting an object, replace the node the object is within with a different node. the projectile is removed.
  useful for e.g. spider web projectiles or mime glue.
  this requires additional parameters specified in the projectile definition:
  ```lua
  parameters = {
	  replace = {
		  target = nil,  -- what to replace. defaults to "air". multiple nodes and groups are planned for a future release.
		  replacement = "mymod:mynode" or {name = "mymod:mynode", param2 = 0},  -- what to replace it with. required.
		  radius = nil,  -- how many additional nodes around the center to replace. defaults to 0 (just the center).
	  },
  }
  ```

* `on_hit_object = ballistics.on_hit_object_active_sound_stop`

  on hitting an object, if a sound handle is associated with the projectile, make it stop.

* `on_hit_object = ballistics.on_hit_object_hit_sound_play`

  play a sound when you hit an object. a SimpleSoundSpec must be provided, a sound parameters table is optional:
  ```lua
  parameters = {
	  hit_sound = {
		  spec = {
			  -- see https://github.com/minetest/minetest/blob/master/doc/lua_api.md#simplesoundspec
			  name = "soundname",
		  },
		  parameters = {
			  -- optional, see https://github.com/minetest/minetest/blob/master/doc/lua_api.md#sound-parameter-table
		  },
	  }
  }
  ```

* `on_hit_object = ballistics.on_hit_object_add_item`

  when the projectile hits an object, the projectile is removed and an item is dropped in its place. requires additional
  parameters specified in the projectile definition:
  ```lua
  parameters = {
	  add_item = {
		  item = "mymod:itemname",
		  chance = nil,  -- 1 in `chance` chance that the item will drop. defaults to 1.
	  },
  }
  ```

### on_punch callbacks ###

* `on_punch = ballistics.on_punch_deflect`

  when the projectile is punched, redirect the projectile in the direction it was punched.

* `on_punch = ballistics.on_punch_add_velocity`

  when the projectile is punched, add velocity in the direction it was punched, according to some scale.
  scales are specified in parameters, e.g.
  ```lua
  parameters = {
	  add_velocity = {
		  scale = "constant",
		  offset = 10,
	  },
	  -- alternatively,
	  add_velocity = {
		  scale = "linear",
		  input = "damage",
		  scale = 3,
		  offset = 1,
	  },

  }
  ```

* `on_punch = ballistics.on_punch_add_item`

  when the projectile is punched, it is removed and an item is dropped in its place. this behavior only triggers if
  the projectile is not moving. requires additional parameters specified in the projectile definition:
  ```lua
  parameters = {
	  add_item = {
		  item = "mymod:itemname",
		  chance = nil,  -- 1 in `chance` chance that the item will drop. defaults to 1.
	  },
  }
  ```

* `on_punch = ballistics.on_punch_pickup_item`

  when the projectile is punched, it is removed and an item is added to the puncher's inventory. this behavior only
  triggers if the projectile is not moving. requires additional parameters specified in the projectile definition:
  ```lua
  parameters = {
	  pickup_item = {
		  item = "mymod:itemname",
		  chance = nil,  -- 1 in `chance` chance that the item will drop. defaults to 1.
	  },
  }
  ```

### on_step callbacks ###

* `on_step = ballistics.on_step_particles`

  show particles on step. must provide additional parameters in the projectile definition:
  ```lua
  parameters = {
	  particles = {
		  -- mostly, a ParticleSpawner definition
		  -- see https://github.com/minetest/minetest/blob/32e492837cbf286aeb91b4b63ecf3c890c71a1bc/doc/lua_api.md?plain=1#L10161-L10254
		  -- do *NOT* specify minpos and maxpos; instead, you can specify _delta_minpos and _delta_maxpos, which
		  -- will be added to the projectile's position
	  },
  }
  ```

* `on_step = on_step_seek_target`

  add some amount of "target seeking" to the projectile, to try to compensate for the target's movement since the
  projectile was created. accepts optional parameters:
  ```lua
  parameters = {
	  seek_target = {
		  seek_speed = .01,
	  },
  }
  ```
