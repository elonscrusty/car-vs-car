# Flame car (car 6) and its two skins (carter picked 10-30)

Look only, High detail like the Toxic Hot Rod. The flamethrower is built INTO the body (nozzles, fuel tanks, plumbing);
there is no roof plate. ~11.5k triangles per look, ~29 parts (Body, Accent, Chrome, Tank, ..., 4 Wheels, 12 Rim pieces).

| carter's pick | look | model id | obj folder | part prefix |
|---|---|---|---|---|
| the car | Napalm Charger: black muscle car, twin nozzles in the grille, two orange tanks, flame stripes | `flame_charger` | `obj/charger/` | `FlameCharger__` |
| skin | Dragon Furnace: red dragon face, nozzle in the mouth, horns, spine, tanks like a pack | `flame_dragon` | `obj/dragon/` | `FlameDragon__` |
| skin | Tanker Rod: rat rod, big cannon nozzle on the nose, giant fuel drum, roll cage | `flame_tanker` | `obj/tanker/` | `FlameTanker__` |

Put it in the game (carter's batch, Edit mode, no Play):
1. Studio: File > Import 3D, pick ALL the files in `obj/charger/` (and `obj/dragon/`, `obj/tanker/` for the skins)
   except the one-file `Flame<Look>.obj` (same car in one file, the backup if multi-select is awkward). Import as Model,
   leave the textures off.
2. Command bar: run `studio_flame_car.luau`. It makes `ReplicatedStorage.CarSkins.flame_charger` / `flame_dragon` /
   `flame_tanker` for whichever looks were imported (rename the ids in VARIANTS when CarCatalog has them), paints each
   part and checks the nose and left/right sides.
3. Ctrl+S.

Not tried in Studio yet: the OBJ import and the mover run (same method as `toxic_rod/`, which is also untried).
CarCatalog id / price / rarity for car 6 and its skins: not set, carter decides (never invented here).

Change a look: edit `flame-car-gen.js` (`opt.variant` 0 / 1 / 2; the preview page `kart-preview/flame-tries` in the
project files uses the same generator), then `node export.js`.
CarSkin (client) carries every extra part on the body and every `Rim<..>FL|FR|RL|RR` piece on its wheel.
