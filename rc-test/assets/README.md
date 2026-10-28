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

`Kart_Racer`, `Kart_Buggy`, `Kart_Speedster`, `Kart_Muscle`, `Kart_Bubble`, `Kart_Truck`: six
low-poly karts made in Blender by `karts/build.py` (run it with Blender's Python to remake them).
Each has a blocky driver and MeshParts `Body`, `Accent`, `Trim`, `Driver`, `Head`, `Headlights`,
`Taillights`, `WeaponMount`, `WheelFL`, `WheelFR`, `WheelRL`, `WheelRR`. The game paints them per car
by part name (`ToyCars.kartPaint`), so 6 models dress all 24 cars (`ToyCars.KARTS`).

To use them in Studio: File > Import 3D > pick each file > Import. Move each model into
`ReplicatedStorage.CarSkins` and keep its name (`Kart_Racer`, ...). Either nose direction works
(the game finds the nose by the headlights). A car's own model, named its car id, still wins.
