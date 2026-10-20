# Battle map: "Toy Room Showdown"

A giant kid's bedroom. The cars fight on a play-mat (green mat, grey road loop, yellow dashes) on a wooden floor.
240 x 160 studs, walls 18 high, built in code. Numbers: `src/shared/BattleMapLayout.luau` (pure data, tested in
`tests/battlemap.test.luau`). Builders: `src/server/BattleMap.luau` (floor, solids, ramps, hazards),
`src/server/MapDecor.luau` (furniture walls, giant toys, lights, dust, soldiers), `src/server/MapParts.luau` (helpers).
`BattleArena.build(slot)` calls them. Top-down picture: `/mnt/project-files/car-vs-car/map/map-plan-top-down-v2.png`.

## For the fight code
- Start spots: parts `SpawnA` (x = -100, faces +x) and `SpawnB` (x = +100, faces -x) in the arena folder; `arena.spawnPoint("a"|"b")` reads them.
- `arena.solids` = everything collidable (shells stop at it), including the moving hazard parts.
- Match slots are 520 studs apart.

## Pieces
- STAGE in the middle (7 high) with a ramp from each spawn side, a neon red ring, a **spinner arm** that sweeps its top, sheer drops on the north and south faces.
- HIGHWAY overpasses along both long sides (10 high): ramps up at both ends, a deck in the middle, white curbs, **red blocks that slide across the deck** and shove cars toward the edge.
- Four bunkers sit beside the spawn lanes (two per side, z ±20), so a car driving straight from the start has a clear road to the middle. Four alphabet blocks A B C D with toy-brick studs, four toy soldiers by the starts, four corner bumpers.
- Walls are furniture: north = bed (patchwork quilt, pillows), south = bookshelf, west = toy chest, east = window with sunbeams and curtains.
- Outside: giant teddy, duck, rocket, crayons, block towers, beach balls, a lamp whose spotlight lights the arena, and a big wheel that turns (turned on each player's own screen by `client/MapFx`, no network cost).
- Effects: floating dust, gold sparkles over the ring, warm window light. Three emitters, three lights.

## Notes
- Ramps are wedges; after the map is in the workspace `BattleMap.verify` ray-casts each one and flips it if it drops.
- Cars drive about 40 studs/s, so long gap jumps are not possible (they fall short); the "big moments" are the drops off the stage and the highway.
- The old auto-battle AI (BattleBrain) still sees a plain 160x110 box in `BattleConfig.Arena`; manual driving does not use it.
