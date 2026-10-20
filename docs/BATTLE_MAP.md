# Battle map: Duel Car Arena (live)

Built from carter's reference sheet "Duel Car Arena" (2026-10-20). Numbers live in `src/shared/DuelArenaLayout.luau`, the builder is `src/server/DuelArena.luau`, tests in `tests/duelarena.test.luau`. Top-down plan picture: `/mnt/project-files/car-vs-car/map/duel-arena-plan-top-down.png`.

- Floor: dark asphalt (#485363) rounded rectangle, 170 x 120 studs, corner radius 24, floor top y = 0. A car at about 45 studs/s crosses the long way in about 4 s. Whole scene is 240 x 200 with grass round it.
- Walls: car height (7), 4 thick, orange modules on the red (left) half and blue on the right, with a metal base and cap, a glowing orange light panel per module, and tire stacks (3 tires) where modules meet. Corners are 4 straight pieces each. Cars bounce, nothing hurts.
- Starts: SpawnA (red pad, x -60) and SpawnB (blue pad, x +60) at z -34, facing each other along x. The red garage and blue garage stand behind the north wall, over each pad (decoration, the wall stays closed).
- Cover: 4 striped barriers (16 x 6 x 7), mirrored left to right. The lane between the starts (z -48 to -20) has nothing in it (tested).
- White dashed line round the floor, orange and blue chevron pairs in the two south corners.
- Outside: 34 trees and 16 rocks on grass (same every time), flags and crates at the garages.
- Only floor, walls and blocks collide. `BattleArena` has `THEME = "duel"`; set it to `"toy"` to bring the toy bedroom (BattleMap, BattleMapLayout, MapDecor) back.

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
