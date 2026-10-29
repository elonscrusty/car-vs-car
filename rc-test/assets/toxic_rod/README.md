# Toxic Hot Rod (car body, carter picked High 10-29)

Look only: black body, toxic-green trim, chrome, quad octagon lamps, blower, slime drips. No weapon built in;
a flat steel plate on the roof is the spot the shared weapon clicks onto (WeaponMounts.Roof).
~11.8k triangles in 27 parts (Body, Accent, Chrome, ..., 4 Wheels, 12 Rim pieces that turn with their wheel).

Put it in the game (carter's batch, Edit mode, no Play):
1. Studio: File > Import 3D, pick ALL the files in `obj/` except `ToxicRod.obj` (that one is the same car in one file,
   the backup if multi-select is awkward). Import as Model, leave the textures off.
2. Command bar: run `studio_toxic_rod.luau`. It makes `ReplicatedStorage.CarSkins.toxic_rod` (rename CAR_ID to the
   car's id in CarCatalog when it has one), paints each part and checks the nose and left/right sides.
3. Ctrl+S.

Not tried in Studio yet: the OBJ import (multi-file) and the mover run. Part positions come out right only if the
importer keeps each mesh where it was; the mover turns the car round / swaps left and right if it did not.

Change the car: edit `toxic-rod-gen.js` (detail 0 low / 1 middle / 2 high; the preview page
`kart-preview/toxic-tries` in the project files uses the same generator), then `node export.js`.
CarSkin (client) carries every extra part on the body and every `Rim<..>FL|FR|RL|RR` piece on its wheel.
