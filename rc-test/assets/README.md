# Car models

`RockCrawler.fbx`: the rock car's truck skin (look only). Made from carter's Meshy truck: side
text painted out, 4 wheels cut off so they spin and ride the springs, 10k-triangle body +
1.5k per wheel, one 1024 colour + normal texture baked from the 1.5M-face original.

To use it in Studio: File > Import 3D > pick the file > Import. Then move the imported model
into ReplicatedStorage, put it in a Folder named `CarSkins`, and name the model `RockCrawler`.
It needs MeshParts `Body`, `WheelFL`, `WheelFR`, `WheelRL`, `WheelRR` (front is -Z).
`src/client/CarSkin.luau` draws it on the rock car; B turns it off and on.

`DriftCoupe.fbx`: the drift car's coupe skin (look only), made the same way from carter's Meshy
coupe. The back badge was painted out, and the front wheels are copies of the clean back wheels.
Import it the same way and name the model `DriftCoupe` in `CarSkins`. `Main.client.luau` picks
the skin per track (`SKINS`).

## Kart models (`karts/`)

Six low-poly karts from carter's reference picture (racer, bulldozer, buggy, monster, rocket, hot-rod),
made in Blender by `karts/build.py`, with a blocky Roblox driver in a cap and no weapon on them.
`karts/to_luau.py` turns its `karts.json` into `src/shared/KartMeshData.luau`, and the game builds
the karts from that while it runs (`src/client/KartMesh.luau`, EditableMesh): nothing to import.
Parts are painted per car by name (`ToyCars.kartPaint`), so 6 karts dress all 24 cars
(`ToyCars.KARTS`). To remake them: run `build.py` with Blender's Python, then
`python3 to_luau.py out/karts.json ../../src/shared/KartMeshData.luau` and `stylua` that file.
A model in `ReplicatedStorage.CarSkins` named a kart (`Kart_Racer`, ...) or a car id still wins.
