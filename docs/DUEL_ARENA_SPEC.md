# Duel Car Arena: carter's picks (2026-10-20, "too plain, make it a 9/10")

Base: his reference sheet "Duel Car Arena" (see docs/BATTLE_MAP.md). He answered 45 cards and said build.

WALLS: car height; rounded corners (cars bounce, no dead stop); round black tire stacks; lots of steady (not blinking) orange lights; orange and blue mixed all around; walls do not react to hits.
GARAGES: bigger, two cars wide; metal roller doors that roll up at GO; two waving flags each; a glowing sign with the PLAYER'S NAME (the bot gets a fun name like "Crusher"); inside: tool boxes, tire racks, crates. The player's color is random red or blue each match.
FLOOR: asphalt look; big orange/blue arrows by the garages; white dashed edge; center circle and lane lines; old skid marks; 4 cover blocks (gray, orange stripes, glowing light), anchored.
OUTSIDE: many more trees (round puffy and pines), rocks big and small, dirt paths to each garage, bushes and flowers, soft green hills far away, tall stadium light towers in the corners (lit in daytime), a big CAR VS CAR sign over one wall. No spectators.
LOOK: sunny day, blue sky with puffy clouds, soft shadows, colors like the sheet.
FLOW: countdown on screen only. A 2-second fly-over at spawn: zooms on your garage, then theirs, then behind your car. A car that leaves the arena loses the round. If phones lag, cut the far trees first (folder "FarScenery").
SOUNDS: silent sound spots (birds, garage doors, GO horn) in folder "Sounds" of the arena; carter supplies the ids.

## Hooks for the fight code (DuelArena controls, exposed on the arena object)
- `arena.setNames(aName, bName)`: text on the two garage signs (side a is the left garage, side b the right one).
- `arena.setTeams(aIsRed)`: side a garage, flags and start pad red when true, blue when false; side b gets the other color.
- `arena.openDoors()` at GO, `arena.closeDoors()` before the next round. The rolled-up door is look only: an invisible gate keeps cars out of the garage.
- Starts: SpawnA at x -60, SpawnB at x +60, z 0, facing each other. Garages sit behind the end walls, the door looks into the arena.
