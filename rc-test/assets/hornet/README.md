# Hornet (car 4, twin gatling guns built in, carter picked Hood Twins 10-30)

Orange car with two 6-barrel gatling guns built into it (ammo drums, belts, trunnion cradles), black racing stripes,
brass trim, chrome, a roof light bar. Same faceted low-poly style and High detail as the Toxic Hot Rod.
Three gun places, one car (carter 10-30: "keep 1 and use 2 and 3 as skins"):
- `hornet` Hood Twins (main look): both guns on the hood, drums beside them.
- `hornet_nose` Nose Guns (skin): guns in the front corners, belts run from drums on the hood.
- `hornet_fender` Fender Pods (skin): big guns on the fenders, drums behind.

Parts (51 for the main look, ~16.2k triangles; each skin adds ~4.3k gun triangles instead of the main look's guns):
Body, Racing, Accent, Chrome, ..., 4 Wheels, 12 Rim pieces (turn with their wheel), `Gun*` (fixed gun parts),
`SpinL*` / `SpinR*` (the 6 barrels of each gun: turn about the Z axis through `PivotL` / `PivotR`),
`MuzzleL` / `MuzzleR` (where shots leave). Pivot and Muzzle are tiny see-through markers.

Put it in the game (carter's batch, Edit mode, no Play):
1. Studio: File > Import 3D, pick ALL the files in `obj/` except `Hornet.obj` (that one is the main look in one
   file, the backup if multi-select is awkward). Import as Model, leave the textures off.
2. Command bar: run `studio_hornet.luau`. It makes `ReplicatedStorage.CarSkins.hornet`, `.hornet_nose` and
   `.hornet_fender` (rename the ids to the car's id in CarCatalog when it has one), paints each part and checks
   the nose and left/right sides.
3. Ctrl+S.

Not tried yet: Lune, stylua, the OBJ import (multi-file) and the mover run in Studio (CI and the batch are the first
runs). Part positions come out right only if the importer keeps each mesh where it was; the mover turns the car
round / swaps left and right if it did not. Needs PR #1072's CarSkin change (every `Rim<..>FL|FR|RL|RR` rides on its wheel).

Still to do: an id/price/rarity in CarCatalog (never invented); the guns spinning and shooting from the Muzzle parts
(client code, not written); a Studio picture in the batch.

Change the car: edit `hornet-gen.js` (`genGatling({variant: 0|1|2})`; the preview page
`gatling-car-preview/hornet-tries.html` in the project files uses the same generator), then `node export.js`.
