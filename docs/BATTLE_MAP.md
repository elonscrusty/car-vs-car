# Battle map: "Toy Box Showdown"

200 x 140 studs, walls 16 high, everything built in code (about 130 parts). Numbers live in
`src/shared/BattleMapLayout.luau`; the server builds it in `src/server/BattleMap.luau`; `BattleArena.build(slot)`
calls it. Tests: `tests/battlemap.test.luau` (symmetry, clear lanes, ramp slopes, spawns).

Top-down picture: `/mnt/project-files/car-vs-car/map/map-plan-top-down.png`.

- Spawns: A at x = -84 facing +x, B at x = +84 facing -x (z = 0). Read them with `arena.spawnPoint("a" | "b")`
  , or the pad parts `SpawnA` and `SpawnB` (the red and blue pads) in the arena folder
  (LookVector = driving direction).
- Center: yellow plateau (7 high) with an orange ramp from each spawn side. North and south faces are sheer drops.
- Bunkers: a wall 22 wide and 11 high 20 studs in front of each spawn, cover from the opening cannon shot.
- Four cover blocks and four green kicker ramps in the outer lanes (flank jumps). Four red corner bumpers.
- `arena.solids` holds every collidable piece (shells stop at them); the checker tiles, stripes and scenery
  have no collision and no query.
- Ramps are wedges. After the map is in the workspace `BattleMap.verify` ray-casts each one and flips it if
  it drops instead of rises (so a wrong guess about wedge direction cannot ship).
- The old auto-battle AI (BattleBrain) still sees a plain 160x110 box in `BattleConfig.Arena`; it does not know
  this map. Manual driving does not use it.

## Upgrade pass (premium toy look)
- Four toy soldiers (cover and landmarks) stand beside each spawn; four alphabet blocks (A B C D, studs on top);
  bunkers and blocks have toy-brick studs; white bands on bunkers and corner bumpers.
- HAZARD: a slow spinner arm over the plateau (`Layout.spinner`, turned by `BattleMap.animate`, stops when the arena
  is destroyed). It shoves cars toward the sheer drop. To switch it off, remove the Spinner model build in `BattleMap`.
- Floor: cream/blue checker, white start lines, glowing yellow chevrons pointing up the plateau ramps, glowing red ring.
- Walls: white caps, stripes, and pennant strings on both long walls. Plateau has a light lip and a darker skirt.
- Outside: giant crayons, block towers, beach balls, corner flags (looks only, no collision).
