# Models needed for the big open garages

The garages work today with plain code-built parts (steel gray/blue, cartoon). These Blender models
would make them look right. Flat colors, steel gray/blue, real garage (not a racetrack pit stop).
Sizes are in studs. Garage = 40 wide (along the wall) x 30 deep, opening faces the hall.

1. **GarageOpenFront** (one per garage, 8 uses): wall frame for the opening, 40 wide x about 20 high.
   Header beam with a flat panel for the name sign (14 x 3.6). Low front wall 1.8 high with a 14 wide
   gap in the middle, yellow cap on top. Walk-in gap must stay empty.
2. **GarageRoomBig**: the room behind it, 30 deep x 40 wide x 17.6 high. Steel walls, concrete floor
   mark, two light bars, no clutter in the middle (the lift stands there).
3. **LikeHeart**: a chunky red heart, about 3 studs wide, on a small post or bracket. Sits by the
   gap on the right side of the door. (Code puts a red ball + heart text there for now.)
4. **GarageNameSign**: the board over the door, 14 x 3.6, flat front face for the text (name,
   level, likes).
5. **PaintBooth** (1 use, front right of the hall): a walk-up booth about 20 wide x 12 deep x 12 high,
   open at the front (facing the lane). Bright cartoon colors, a big paint-can-and-roller roof sign
   (flat panel for the word PAINT, 10 x 3), a counter with 3 paint buckets, a spray gun on the wall.
   Pivot at the bottom center, front toward -Z. Code keeps the "Customize" prompt on the old counter.
6. **ShopBooth** (1 use, front left of the hall): a market stall about 20 wide x 12 deep x 12 high,
   open at the front. Striped awning, a counter with tires and boxes on shelves behind it, a flat
   panel for the word STORE (10 x 3). Same pivot and facing as the PaintBooth.
7. **GumballMachine** (1 use, back wall, right corner; small prop, optional): about 9 wide x 7 deep x
   17 high. Red cabinet, a big clear globe full of colored balls, a yellow cap, a coin slot and
   crank on the front, a chute with a small tray. Back is flat so it stands against the wall.
   Name the loose parts `GumballDrop` (one ball that drops out) and `GumballCrank` if you can: the
   drop animation moves them. Code builds a plain version from parts today.
8. Optional: a **ParkingMark** (yellow floor outline for 4 parked cars along the back wall).

How they connect: code is in `src/server/Lobby.luau` (bay parts), `src/server/LobbyBays.luau`
(lift on the left, parked cars on the right, name sign on the back wall, heart prompt). Inside a garage the lift is on the left and the tools on the right (seen from the door), so the opening stays clear. Sizes live in `src/shared/LobbyLayout.luau` (`bay`, `bays`).
