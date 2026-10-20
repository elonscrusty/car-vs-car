# Junkyard Bowl (the round battle map)

carter's 50 picks (M1 to M50, 2026-10-20) replace the Wreck City chase map. One medium ROUND bowl
with a sloped edge and a wall of stacked tires, a crusher machine in the middle that slams now and
then, red barrels that explode, smashable props, sunny day, bright rainbow toy-junk look. The cars
start at the two ends and charge head on. Walls bounce. First Studio look 2026-10-20 (see the end of
this file); driving in it is not tested yet.

## What the picks became
| Pick | In the build |
|---|---|
| M1 junkyard theme | junk props, tire wall, containers and hills far away, dirt patches |
| M2 medium | rim radius 120, wall radius 121 (about 242 studs across) |
| M3 round bowl, sloped edges | flat floor radius 92, then a 28 wide slope that rises 5.2 (10.5 degrees), then the wall |
| M4 ground only, no deck; M7 no loop; M8 no tunnel; M9 no crane; M14 no secret gate; M29 no moving platforms | none of those exist |
| M5, M6 fewer ramps, no huge jump | two low tent humps (2.8 high, 24 long); Wreck City had five ramps |
| M10, M11 dangers small | only the crusher and the red barrels; each does 5 to 8 percent of max HP (a full speed crash is 20) |
| M12 same breakables | 71, as before: 26 crates, 18 barrels, 8 red barrels, 8 cones, 5 signs, 6 fences (crates + barrels = 52, the most) |
| M15 no hiding spots, M38 no shortcuts, M39 no jump pads | open floor, nothing to hide behind |
| M16 crusher "Slams" | solid base radius 11, press above it falls every 12 s (first 8 s after GO) after a 1.8 s warning (flashing lamps, red floor); the shock ring reaches 27 studs; small damage (8 percent), clear push |
| M17 tires | 63 stacks of 2 tires (a dark one under a rainbow one, a hub cap on top) stand shoulder to shoulder against the solid wall, on a dirt berm. The solid wall boxes are INVISIBLE: the first Studio look showed a visible wall hiding every tire as a plain dark wall |
| M18 bigger bounce | wall elasticity 1 (was 0.9), car keeps its full speed back (was 85 percent) and the slide slows gently (`Human.bounceFriction` 0.8 per second; a crash knock slows by 2.2), 0.85 s wobble (was 0.6), hop 20 (`BattleConfig.Human.bounce*`). A full-speed head-on hit throws the car back about 1.6 car lengths. A driven Studio test measured the first build at 6 to 9 studs in half a second ("small"), so this is the second try |
| M19 ground mix, M20 no oil | dirt discs in the junk patches, grey road floor between, no puddles |
| M21 sunny, M41 no weather | `Atmosphere.apply()` (ClockTime 14) is the only lighting ever applied |
| M22 bright junk, M31 no car piles, M23 no crowd, M24 no sign | rainbow colours (never red barrels or crates; red is for the exploding ones), no car piles, no people, no WRECK CITY sign |
| M25, M26 far apart, head on | start pads at x = -64 and +64 on the lane z = 42, facing each other; the lane passes the crusher outside its shock ring and nothing stands on it |
| M27 stuck rescue | the old rule stays (gas held, not moving), puts the car on the nearest of 12 open spots, facing along the circle |
| M28 no edges | a solid floor disc and a closed wall all round; out-of-arena check is a circle (BattleCrash.outside, BattleCar.keepInside) |
| M30 phones smooth | 674 BaseParts (Wreck City had 1472 descendants); `FarScenery` (113 parts), `Detail` (63) and `Berm` (32) are removed on a slow phone by MapFx, which leaves 466 |
| M32, M33 red barrels | 8 BoomBarrels: a fireball and ring, cars within 24 studs get 5 percent damage and a push of 46 |
| M34 reset each round | `resetBreakables()` brings every prop back at the start of each round; the crusher clock restarts at GO |
| M35 camera moves closer, walls never fade | BattleUi: the camera stays inside a circle 9 studs in from the tires; the old ray pulls it in where something solid (wall, crusher base) is in the way; smashable props never block it. A camera that was pushed in looks less far ahead (`BowlView.lookAhead`, down to half a car length) so the car stays on screen: a driven test lost the car under the bottom edge when it backed into the wall |
| M36 no mini map | none |
| M37 no arrow to the enemy | `FeatureFlags.enemyArrow = false` hides the edge arrow; the lock ring on the enemy stays |
| M40 one look, M44 no dust | one palette, no zones; the landing dust cloud is removed (the thump stays) |
| M42 sparks | `BattleFx`: sparks where a moving car scrapes the tire wall or the crusher base, from 6 studs away (`BowlView.scrape` TOUCH): the bounce turns a car round 3 to 4 studs before the tires, and a driven Studio test saw no sparks in 14 hits while touching was 0.9 studs |
| M43 skid marks | `BattleFx`: dark strips behind the rear wheels in a hard sideways slide, gone after 4 s, none on a slow phone |
| M45 no shrink, M46 same map | one fixed map |
| M47 flyover | BattleUi: the camera sweeps from high over the far end, along the lane over the crusher, down to behind my car (4 s behind the VS screen in round 1, 2 s later) |
| M48 no lookout | none |
| M49 bot-vs-bot | `tests/bowlfight.test.luau` (2D copy, round wall, crusher) now; Studio `BattleSimRequest` after the map is synced (the tally also counts rescues, outs, slams, booms) |
| M50 just build | no plan picture first |

## Files
- `src/shared/BowlLayout.luau` (+ `tests/bowlmap.test.luau`): every number, the prop plan (deterministic), the crusher clock (`crusherState`, `crusherLift`, `shockFront`), rescue points, circles for the bots.
- `src/shared/BowlView.luau` (+ `tests/bowlview.test.luau`): pure client maths: crusher look, spark contact, skid amount, camera clamp, flyover path.
- `src/server/BowlMap.luau`, `src/server/BowlProps.luau` (+ `tests/bowlbuild.test.luau`): builds the map and runs the live parts (`tick`: props burst, red barrels explode, the crusher slams; `rescuePoint`; `resetBreakables`; `verify`).
- `src/server/BattleArena.luau`: `THEME = "bowl"` (set `"duel"` or `"toy"` to bring the older maps back).
- Fight code touched: `BattleService` (arena brain, hits with their own damage, radius, round end), `BattleBrain` (round wall, round blocks), `BattleCrash.outside`, `BattleCar.keepInside`, `BattleDrive.wallBounce` (looks past `BowlSlope`, bounce numbers), `BattleConfig.Human.bounce*`.
- Client: `MapFx` (crusher animation from the server clock, camera shake, slow phone cut), `BattleUi` (camera, flyover, arrow flag), `BattleFx` (sparks, skid marks).

## Rules the code relies on
- Only the floor, the slope wedges (tag `BowlSlope`, NOT bouncy), the wall boxes (tag `Bouncy`, invisible; the tire stacks touch their inner face), the hump wedges and kerbs and the crusher base collide. Tires, the berm under them, props, scenery and the press are look-only. Never make the wall boxes visible again: they hide the tires.
- Breakable models have a part `Body` (CanTouch and CanQuery, no collision) and attribute `Breakable`; a car overlapping `Body` bursts the model. Red ones also have attribute `Explosive`.
- The crusher model has attribute `RoundStart` (server time of GO, -1 = resting) and tag `BowlCrusher`. Every client draws it from the server clock; the server only decides who the ring caught.
- Slope wedges rise toward local +Z; `verify()` flips any that drop. Cars climb the 10.5 degree slope (the ground ray allows up to about 12).
- Sound spots (silent until carter gives ids): `Sounds` > `Spot_<name>` > Sound `<name>`: Birds, GoHorn, Slam (plays at each slam), Boom.

## Studio check, 2026-10-20 (pictures in /mnt/project-files/car-vs-car/map/bowl/)
Seen in Studio: the map builds with no script errors (630 parts then; 674 with the berm); bots fight in it (3 pairs, 9 series each: every series ends, nobody leaves the bowl, 1 stuck rescue, crusher slams and red barrels both fire); the crusher warning (red floor, press up), the slam and the ring look right and the first slam is at 8 s; colours are not blown out (pale blue-grey floor, sand slope, bright junk). The miss: the visible solid wall showed as a plain dark wall and hid the tires (fixed: the wall boxes are invisible now).

## Driven check, 2026-10-20 (PR 211: `DevDrive` steers the human car in Studio)
A real client drove a Ram against a Test Bot. Seen: 5 wall hits (head on, 45 degrees, shallow) and a reverse run: the car climbs the slope and bounces, never stuck, never upside down, no stuck rescue, body centre never past r 113.5; the camera never passes r 112.1; skid marks appear (up to 60 parts) and are gone in about 5 s; the flyover runs from (134, 103, 69) to the chase pose behind the pad; the chase camera at GO and the round 2 countdown look right. Misses (fixed in the next PR): no sparks in any hit (touching was 0.9 studs, the bounce turns the car 3 to 4 studs out), the car slid off screen in 8 of 25 frames when backed into the wall (the camera still looked 2.6 car lengths ahead), and the bounce was small (6 to 9 studs in half a second).

## Not checked in Studio yet
The new bounce numbers (`Human.bounceFriction`, `bounceStagger`, `bounceHop`) and the sparks and camera fixes (a re-drive); how long a car takes to get back to the floor; crusher damage numbers (`Layout.crusher`, 8 percent a slam); the 3 s stuck rescue for a driven car; a phone; colours and textures (carter dislikes the bright toy look, a new style is coming: `BowlLayout.colors` and `server/Atmosphere`).
