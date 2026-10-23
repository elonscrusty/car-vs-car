# Car models

`RockCrawler.fbx`: the rock car's truck skin (look only). Made from carter's Meshy truck: side
text painted out, 4 wheels cut off so they spin and ride the springs, 10k-triangle body +
1.5k per wheel, one 1024 colour + normal texture baked from the 1.5M-face original.

To use it in Studio: File > Import 3D > pick the file > Import. Then move the imported model
into ReplicatedStorage, put it in a Folder named `CarSkins`, and name the model `RockCrawler`.
It needs MeshParts `Body`, `WheelFL`, `WheelFR`, `WheelRL`, `WheelRR` (front is -Z).
`src/client/CarSkin.luau` draws it on the rock car; B turns it off and on.
