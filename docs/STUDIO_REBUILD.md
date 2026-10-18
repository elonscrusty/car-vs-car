# Rebuilding the Studio place

The place lived only in an unsaved Studio window once and was lost (2026-10-18). Everything needed to
rebuild it is in this repo now.

1. `rojo build -o CarVsCar.rbxlx` (all scripts), open it in Studio, press **Ctrl+S** right away, then
   **File > Publish to Roblox**.
2. Studio: Home > Import, open `assets/models` (one folder at a time, or copy all the `.fbx` files from the
   sub folders into one folder first), type `*.fbx` in the name box, Ctrl+A, Import.
3. Paste `tools/studio-sort.luau` into the command bar. It moves the imports into
   `ServerStorage.Models.<Shell|Decor|More|Bowl|Props|Extras>` and renames the claw machine.
4. The 30 cars (`ServerStorage.Models.Cars`) come from `vehicles/vehicle-pack-30.zip`; see HANDOFF.md.
5. Optional steel look for the lobby models: upload `assets/models/palette-steel.png` as an image in Studio,
   then run in the command bar: `game.ServerStorage.Models:SetAttribute("SteelPalette", "rbxassetid://<id>")`.
   `LobbyDecor.clone` then swaps every lobby model's color sheet (the red becomes steel gray). The bowl keeps
   its own colors.
