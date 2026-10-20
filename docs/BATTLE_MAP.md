# Battle map: Duel Car Arena (live)

Built from carter's reference sheet "Duel Car Arena", then dressed up to his 45 picks (docs/DUEL_ARENA_SPEC.md). Numbers live in `src/shared/DuelArenaLayout.luau`, the builder is `src/server/DuelArena.luau`, tests in `tests/duelarena.test.luau`.

- Floor: asphalt rounded rectangle, 170 x 120 studs, corner radius 24, floor top y = 0 (about 4 s to cross the long way). White dashed edge, lane lines through the middle, a center circle, big orange/blue arrows by the garages, old skid marks.
- Walls: car height (7), bouncy (elasticity 0.9, weight 100, so a hit throws the car back), orange and blue modules alternating all the way round, two steady glowing orange lights per module, three-tire black stacks (with a pale hole on top) where modules meet.
- Starts: SpawnA (x -60) and SpawnB (x +60) on the middle line z 0, facing each other. Straight lane between them (|z| < 14) has nothing in it (tested). Four orange-striped cover blocks sit off the lane at (+-24, +-31).
- Garages: behind the west and east walls, 40 wide (two cars), roller door that rolls up at GO, two waving flags (client side, tag MapWave), a glowing name sign on the roof, tool boxes, tire racks, crates, a bench and a ceiling light inside. An invisible gate keeps cars out. Fight hooks on the arena object: `setNames(a, b)`, `setTeams(aIsRed)`, `openDoors()`, `closeDoors()` (see docs/DUEL_ARENA_SPEC.md).
- Outside: 3x more greenery (puffy trees, pines, rocks big and small, bushes, flowers), dirt paths to each garage, soft green hills, four stadium light towers (neon lamps), a CAR VS CAR sign over the north wall, clouds in the sky. Far scenery is in folder `FarScenery`: delete it first if phones lag.
- Sound spots: folder `Sounds` (Birds, GarageDoorA, GarageDoorB, GoHorn), ids blank.
- Only floor, grass, walls, cover blocks and the two gates collide. `BattleArena` has `THEME = "duel"`; set it to `"toy"` to bring the toy bedroom (BattleMap, BattleMapLayout, MapDecor) back.

---

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
