# ballistics

an api for projectiles. see API.md for details.

originally, the goal is to make use of minetest's built-in collision detection to do the heavy lifting, to avoid having
to do a bunch of raycasts, which may not be accurate if there is a lot of lag. however there's a number of problems:
* the collision detection doesn't actually tell you *where* the collision happened, nor does it stop movement in
  directions perpendicular to the collision axis
* players can jump off of physical projectiles in flight

so now we're going to go back to non-physical and use raycasts - but not in a simple way! the arc of the projectile
will be estimated, so that lag doesn't cause arrows to collide with things that aren't actually in their path.

this is alpha-quality currently - the API is not fully finalized.
