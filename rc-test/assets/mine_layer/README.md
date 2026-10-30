# Mine-layer cars (car 5; Grave Layer, Widow Maker, Rust Hopper)

Same faceted style and HIGH detail as the Toxic Hot Rod. The mine layer is built INTO the body: mines in a rack /
revolver drum / tubes behind the cabin, one more behind the tail panel, and a swing arm (spoon + weight) that throws
mines out the back. ~15-19k triangles per car, 38 parts each (Body, Accent, Chrome, ..., Mine, Spike, Blink, 4 Wheels,
12 Rim pieces that turn with their wheel, Arm* and Loaded* for the arm). Nose +Z, car's left +X, ground y = 0.

Preview page with a Drop mine button (arm swing, flying mine, blink, boom): project files `kart-preview/minelayer-tries/`
(`car5.html`; same generator). Pick of the 3: see the handoff, plans/handoffs/car-mine-layer.md.

## Put it in the game (carter's batch, Edit mode, no Play)
1. Studio: File > Import 3D, pick ALL files in `obj/<car>/` except `<Prefix>.obj` (the whole car in one file, the
   backup if multi-select is awkward). Import as Model, leave textures off. Do this for each car you want
   (`grave_layer`, `widow_maker`, `rust_hopper`); the mover skips a car it finds no parts for.
2. Command bar: run `studio_mine_layer.luau`. It makes `ReplicatedStorage.CarSkins.<id>` for each car, paints the parts,
   and checks nose and left/right. Set `MAIN` at the top to the main car's id and the other cars get attribute
   `SkinOf` = that id (skins of the main car).
3. Ctrl+S.

## Still to do (not done here)
- A CarCatalog entry (id, price, rarity) for each car: not invented. The ids above are placeholders.
- The swing arm is static in the game: turn the `Arm*` + `Loaded*` parts about the centre of `ArmHinge` (axis X; the
  preview swings it about +0.9 rad in 0.28 s, flings the Loaded* mine out, shows a new one after 1.3 s). Real mines
  drop where Mine.luau already puts them; a launch point at `LoadedMine` is the next step.
- Not tried in Studio: the OBJ import and the mover run. Not run: Lune tests / stylua on the repo (CI is the first run;
  this folder is outside `src` and `tests`). The mover parsed and formatted with the StyLua wasm build.

## Change a car
Edit `mine-layer-gen.js` (the 3 specs at the top: body tables, colours, `kind`), then `node export.js` (writes `obj/` and
`studio_mine_layer.luau` from `studio_mine_layer.template.luau`; run StyLua over the .luau after).
