# Saw Rammer (car 7, carter picked the Road Saw 10-30)

Look only: charcoal body, hazard-orange trim, chrome, big octagon lamps, smoke stacks, spiked skirts, saw-blade door badge.
The weapon is built INTO the nose: a spinning buzzsaw. Same style and High detail as the Toxic Hot Rod.
A flat steel plate on the roof is the spot the shared weapon clicks onto (WeaponMounts.Roof).
Body ~10.3k triangles in 27 parts, plus a saw kit of 1.4k to 2.7k triangles. 3 looks (carter: keep the pick, the others are skins):
- `saw_rammer` Road Saw (the car): flat saw lying under a steel plough nose.
- `saw_rammer_big` Big Saw (skin): one huge raked saw behind an orange guard.
- `saw_rammer_twin` Twin Saws (skin): two corner saws, steel ram in the middle.

Put it in the game (carter's batch, Edit mode, no Play):
1. Studio: File > Import 3D, pick ALL the files in `obj/` and in `obj/skin_plow`, `obj/skin_big`, `obj/skin_twin`
   (the body and the three kits; the preview page is the same generator). Import as Model, leave the textures off.
2. Command bar: run `studio_saw_rammer.luau`. It makes `ReplicatedStorage.CarSkins.saw_rammer` and the two skin models,
   paints each part and checks the nose and left/right sides (rename CAR_ID to the car's id in CarCatalog when it has one).
3. Ctrl+S.

The blades (`SawBlade*`, `SawHub*`) are their own parts and carry a `SpinAxis` attribute (model space); the spin itself
is weapon code, not in this PR. A blade is symmetric around its axis, so its part position is the spin centre.
CarSkin (client) carries every extra part on the body and every `Rim<..>FL|FR|RL|RR` piece on its wheel (that is in the
Toxic Hot Rod PR; without it the rims stay still).

Not tried in Studio yet: the OBJ import (multi-file) and the mover run. Part positions come out right only if the importer
keeps each mesh where it was; the mover turns the car round / swaps left and right if it did not.

Change the car: edit `saw-rammer-gen.js` (opt.saw 'plow' | 'nose' | 'twin' | 'none'), then `node export.js`.
