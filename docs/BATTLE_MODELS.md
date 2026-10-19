# 1v1 auto-battle: model setup checklist

The 3 fighters use carter's supplied models (source files: `assets/battle-models/*.fbx` in the project
files). Authored models stay untouched in `ReplicatedStorage.BattleModels`; every round the server
clones them, scales the clone to `BattleConfig.Fighters[id].lengthStuds` and fights with the clone.

## What was checked in the FBX files (by reading them, not by eye in Studio)
| File | Is | Triangles | Notes |
| --- | --- | --- | --- |
| RamTruck.fbx | red truck, front plow | ~50,000 | one merged mesh, 4096px textures |
| CannonVan.fbx | blue van, roof cannon | ~50,000 | one merged mesh |
| SawBuggy.fbx | green buggy, front saw blades | ~50,000 | one merged mesh |

All three: nose toward +Z, up +Y, about 1 unit long. ~50k triangles is over the 20k limit Roblox
usually allows for one mesh: the Studio importer may reduce it, check the look after import.

## Per car: put it in the place
1. Import the FBX. Make a `Model` named exactly `RamTruck` / `CannonVan` / `SawBuggy` in
   `ReplicatedStorage.BattleModels`.
2. The mesh inside is named `Body` and is the model's `PrimaryPart`.
3. The nose points toward **-Z** (turn the mesh 180 degrees about Y if it imported toward +Z).
4. Do not recolor. No scaling needed (the server scales the clone).

## What is NOT in the supplied models (missing, nothing was made up)
- Wheels, the cannon, and the saw blade are not separate parts, so **wheels do not spin, and the saw
  does not spin on its own**. To get those, export them as separate meshes:
  `Wheel_FL/FR/RL/RR` (all cars), `Saw` (Saw Buggy, a spinning disc pivoted on its axle), `Turret`
  (Cannon Van, optional). They must stay separate (not merged into Body) so they can animate.
- No hit parts exist. The server measures them from the body size (`weaponForward`, `weaponUp`,
  `hitSize` in `BattleConfig`): `RamHit` (front of the Ram), `SawHit` (front of the Saw), `Muzzle`
  (top front of the Cannon Van). A part with the same name inside the model overrides the measured one.
- The cannon `Muzzle` point is a measurement of the barrel tip from the mesh (0.425 L ahead, 0.633 L
  up). Check it by eye once.

## Studio test switches (Studio only, off by default, never saved)
- `workspace:SetAttribute("BattleTestUnlock", true)`: all three cars usable, labeled **Test**.
- `workspace:SetAttribute("BattleStandIn", true)`: plain labeled boxes while a model is missing.
- In the queue panel the **TEST BOT (Studio only)** button starts a match against a labeled bot.
