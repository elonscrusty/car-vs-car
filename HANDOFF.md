# HANDOFF

## Run it
1. Install Rokit tools: `rokit install` (rojo, lune, stylua, selene).
2. `rojo serve`, open an empty place in Studio, click Connect in the Rojo plugin, press Play.
3. Tests: `lune run tests/run`. Format: `stylua src tests`. Lint: `selene generate-roblox-std && selene src tests`.

## Tweak the feel
- `src/shared/CarConfig.luau`: hp, mass, maxSpeed, accel, turnRate, damageMult, hitLift per car.
- `src/shared/GameConfig.luau`: Arena (flat/rim radius, tiltDeg), Launch speeds, Damage scale, Ai timings.

## Next 3
1. Real car models + sunny map art (after one sample picture).
2. One ability button per car (boost / spike pop / ramp flip).
3. PvP matchmaking and DataStore saves (hearts, wins, unlocked cars).

## Known gaps
- Rojo build and Studio playtest not yet run by CI-less author; check Output for errors first.
