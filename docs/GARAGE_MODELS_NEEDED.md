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
5. Optional: a **ParkingMark** (yellow floor outline for 4 parked cars along the back wall).

How they connect: code is in `src/server/Lobby.luau` (bay parts), `src/server/LobbyBays.luau`
(lift, parked cars, sign, heart prompt). Sizes live in `src/shared/LobbyLayout.luau` (`bay`, `bays`).
