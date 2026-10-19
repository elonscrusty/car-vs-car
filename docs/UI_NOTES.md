# UI notes (Champions UI)

## Buttons (done in code)
- Every button pops a little when the mouse is over it and squashes when pressed.
- Big buttons (PLAY and others 150 wide and 60 tall) get a slow shine sweep every 4.5 s.
- Turned off when "Reduced motion" is on.
- Later: Carter's own button skins (green, blue, red, navy) and sparkle on PLAY.

## Layout rules
- Top row next to the chat icon: coins + LV + XP bar (lobby). Settings at top right.
- CARS / SHOP / GIFT: left column, under the Roblox buttons, above the thumbstick.
- PLAY: bottom right, left of the jump button.
- Fight: scoreboard centered at the very top, LOBBY under the Roblox buttons, MENU top right.
- The dark dim behind menus covers the WHOLE screen, top bar too.
- Text shrinks to fit its box. Smallest sizes are 26 units for labels.
- Test small phones in Studio: set attribute `ScaleOverride = 0.58` on `PlayerGui.CVC_Champions`.

## Pictures
See `docs/UI_ICONS_NEEDED.md` (what Carter makes) and `docs/CARS_FOR_MESHY.md` (cars).
