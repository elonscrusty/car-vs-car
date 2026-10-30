# Rocket Truck (car 3, carter picked Missile Mule 10-30)

Look only: heavy black pickup with the rocket pods built INTO the body (no roof weapon spot). Same faceted low-poly
style and high detail as the Toxic Hot Rod. carter's rule: the tries he did not pick are kept as skins.

| file prefix | skin id (mover) | look |
| --- | --- | --- |
| `RocketTruck` | `rocket_truck` | **Missile Mule** (the car): two 4-rocket pods in the bed, red |
| `RocketTruckHauler` | `rocket_truck_hauler` | skin **Blast Hauler**: one 6-rocket battery on a cradle, orange |
| `RocketTruckFury` | `rocket_truck_fury` | skin **Fender Fury**: pods in the front fenders, yellow |

~16k triangles per truck in 29 parts (Body, Accent, Chrome, Bed, Warhead, ..., 4 Wheels, 12 Rim pieces that turn
with their wheel). No part is over 10k triangles.

Put it in the game (carter's batch, Edit mode, no Play):
1. Studio: File > Import 3D, pick ALL the `obj/RocketTruck*__*.obj` part files (not the one-file `RocketTruck*.obj`
   backups). Import as Model, leave the textures off. One truck is enough; the mover skips any it does not find.
2. Command bar: run `studio_rocket_truck.luau`. It makes `ReplicatedStorage.CarSkins.rocket_truck` (and
   `_hauler`, `_fury`), paints the parts, checks the nose and left/right sides. Rename the ids in TRUCKS to the ones in
   CarCatalog when the car has them.
3. Ctrl+S.

Not tried in Studio yet: the OBJ import and the mover run (CI does not check assets). Needs the CarSkin rim change from
PR #1072 (Toxic Hot Rod) for the RimChrome/RimDark pieces.

Change the car: edit `rocket-truck-gen.js` (opt.variant 0 Hauler / 1 Mule / 2 Fury, opt.splitWheels), then `node export.js`.
The preview page and its build files live in the project files, `car-vs-car/rocket-truck-tries/` (src/ = the generator parts).
