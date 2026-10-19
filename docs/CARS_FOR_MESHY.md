# Cars in the game (12) — what to make

These are the 12 live cars, in menu order. Size is in studs (width x height x length). The car faces
forward = -Z in Roblox. The model name is what the game looks for in
`ServerStorage.Models.Cars`.

| # | Id | Name | Rarity | Ability | Model name | Size | Feel |
|---|---|---|---|---|---|---|---|
| 1 | Sedan | Sedan | Common | Dash | 02_sedan | 5x2x8 | Balanced. Good at everything. |
| 2 | Compact | Compact | Common | Dash | 01_compact | 4x2x7 | Small and quick. Breaks easy. |
| 3 | DuneBuggy | Dune Buggy | Common | Jump | 09_open_dune_buggy | 4x2x7 | Light and bouncy. Quick turns. |
| 4 | BoxTruck | Box Truck | Common | Slam | 15_box_truck | 6x3x10 | Heavy box. Slow, tough. |
| 5 | Muscle | Muscle | Rare | Ram | 04_muscle | 5x2x8 | Plows through. Hits hard. |
| 6 | Kart | Racing Kart | Rare | Jump | 26_low_racing_kart | 4x2x6 | Tiny. Grips and turns fast. |
| 7 | DriftKing | Drift King | Rare | Magnet | 29_drift | 5x2x8 | Slides around you. |
| 8 | SuperCar | Super Car | Epic | Dash | 05_super_car | 5x2x8 | Very fast. Breaks easy. |
| 9 | MonsterTruck | Monster Truck | Epic | Slam | 08_monster_truck | 7x3x11 | Big wheels. Smashes hard. |
| 10 | Semi | Semi | Epic | Ram | 16_semi | 7x4x12 | Huge. Big damage. |
| 11 | Formula | Formula | Legendary | Dash | 27_open_wheel_formula | 4x2x7 | Super fast. Easy to break. |
| 12 | ArmoredTruck | Armored Truck | Legendary | Shield | 28_wheeled_armored_truck | 7x4x11 | Steel wall. Slow to turn. |

## Tips for Meshy / Tripo
- Style: bright cartoon toy car, flat colors, chunky, same look for all 12. Rare cars glow later in code.
- Make one picture first (front 3/4 view), then image-to-3D from it. Keep the same prompt style.
- Low poly: aim for under 8,000 triangles per car. Game has 4 cars on screen plus the lobby.
- Wheels as separate parts if the tool allows it (they spin). If not, still fine for now.
- Export FBX or GLB. Origin at bottom-center. Car faces forward = -Z.
- Pack picture for the menu: render the finished car from the front 3/4 on a clear background.
