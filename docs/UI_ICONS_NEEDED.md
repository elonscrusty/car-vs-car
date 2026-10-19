# Pictures Carter makes for the UI

Carter makes all UI art. The menu draws plain stand-ins until a picture is added.
Where a picture goes: `src/champions/shared/Assets.luau`. Paste the `rbxassetid://` number in the
matching line. Empty `""` = the menu draws its own stand-in.

How to upload: Roblox Creator Hub > Assets > Images > upload PNG. Copy the **Image** asset id
(not the Decal id). Tell Claude the id; Claude pastes it in.

Make each picture a PNG with a clear (transparent) background. Flat bright cartoon toy look, thick
dark outline, one style for all.

## Must have
| # | Picture | Size | Slot in Assets.luau | Where it shows |
|---|---|---|---|---|
| 1 | CAR VS CAR logo (one line) | 512 x 140 | `Logo` | top of every menu + loading |
| 2 | Coin | 256 x 256 | `Icons.coin` | coin counts everywhere |
| 3 | PLAY icon (two cars crashing or crossed bumpers) | 256 x 256 | `Icons.duel` | big green PLAY button |
| 4 | CARS icon | 256 x 256 | `Icons.car` | CARS button |
| 5 | SHOP icon | 256 x 256 | `Icons.shop` | SHOP button |
| 6 | GIFT icon | 256 x 256 | `Icons.gift` | GIFT button |
| 7 | SETTINGS icon (gear) | 256 x 256 | `Icons.gear` | SETTINGS button |
| 8 | X close button (new look) | 256 x 256 | `Icons.close` | red X on every menu |
| 9 | BOOST icon | 256 x 256 | `Icons.boost` | fight BOOST button |
| 10 | Gumball machine icon | 256 x 256 | `Icons.claw` | spin box buttons |

## Ability icons (fight button + car cards)
| Picture | Slot | Cars that use it |
|---|---|---|
| Dash | `Icons.Dash` | Sedan, Compact, Super Car, Formula |
| Jump | `Icons.Jump` | Dune Buggy, Racing Kart |
| Slam | `Icons.Slam` | Box Truck, Monster Truck |
| Ram | `Icons.Ram` | Muscle, Semi |
| Magnet | `Icons.Magnet` | Drift King |
| Shield | `Icons.Shield` | Armored Truck |

## Small ones
| Picture | Slot |
|---|---|
| Lock | `Icons.lock` |
| Equipped check mark | `Icons.check` |

## Car pictures (12)
Real pictures of OUR pack cars (see CARS_FOR_MESHY.md). One PNG each, 3/4 front view, car
facing right-down, 512 x 320, clear background. Slot: `Vehicles.<Id>` (ids in the cars list).
Right now the menu shows 12 stand-in pictures that are NOT our cars.

## Nice to have later
- Button skins (green, blue, red, navy), 9-slice, with a shine.
- Loading screen picture.
- Rarity chip art (Common, Rare, Epic, Legendary).
