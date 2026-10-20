# Wreck City (chase map)

carter's brief (2026-10-20): Twisted Metal style chasing in a bright cartoon look, one MEDIUM map,
two levels with ramps, a tunnel, a ring road and one secret shortcut; breakable fences, signs and
barrels; one swinging crane that hurts everyone. NO pickups, no turbo, not dark. Original art only.
Claude (Opus helpers) makes every map model; carter makes only the cars. Walls still bounce.
Review list items folded in: hiding blockers (buildings), brighter road with colour lanes, small
props (not car-sized), low walls and barriers (the camera never hides behind them), rescue for a
stuck car, spawns face each other on the south road with a clear lane, part count logged.

## Files
- `src/shared/ChaseMapLayout.luau` (+ `tests/chasemap.test.luau`): every number. 312 x 312 studs
  inside the walls; ring road 36 wide; barrier ring at +-120 with gaps; deck 110 x 110 at y 14;
  tunnel under it (18 half width, 11 clear); ramps N S W E (60 long) and one hidden ramp behind a
  breakable fence in the north barrier; 8 buildings/blocks; crane on the east road.
- `src/server/ChaseMap.luau`: builds it (ground, roads, walls, deck, ramps, barriers, buildings,
  scenery, breakables, crane) and runs the live parts: `tick(dt, bodies)` smashes props and returns
  the cars the crane hit; `rescuePoint(pos)`; `resetBreakables()`; `verify()` (ramps rise).
- `src/server/ChaseProps.luau`, `src/server/ChaseLandmarks.luau`: the models (Opus).
- `src/server/BattleArena.luau`: `THEME = "chase"` (set `"duel"` or `"toy"` to bring the old maps back).
- `src/server/BattleService.luau`: calls `arena.tick` every fight frame (crane damage 10% of max HP,
  knock), puts a car back on the road when gas is held but it has not moved for 2.5 s, and calls
  `arena.resetBreakables()` at each round start.
- `src/client/MapFx.luau`: swings the crane on every client from the server clock (tag `MapCrane`).

## Rules the code relies on
- Parts named `Core` (and the crane `Column`) are the only colliders in models: solid, tagged
  `Bouncy`. Breakable models have a part `Body` (CanTouch/CanQuery, no collision) and attribute
  `Breakable`; a car overlapping `Body` bursts the model into flying pieces.
- Ramps are `WedgePart`s; `verify()` flips any that drop. Ramps are not `Bouncy`.
- `FarScenery` folder: cut it first if phones lag. Folder attribute `PartCount` is set on build.
