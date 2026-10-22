# RC car feel test

One small RC car and four grey plots (drift, race, rock climb, show car). Only job: find out if driving
feels great. Nothing from the old Car VS Car game is used at run time.

Lobby: you start walking on the street in front of the RC plots. Walk onto a plot's driver stand
and press E (or tap the Drive prompt) to drive there; E or WALK goes back to walking.

- Serve in Studio: `rojo serve rc-test/default.project.json` (fresh Baseplate place; the script
  removes the baseplate and spawn).
- Tests: `cd rc-test && lune run tests/run`
- Feel numbers: `src/shared/Tuning.luau`. Plots: `src/shared/Plots/<Type>.luau` (rules in `src/shared/Plots/Kit.luau`).

Controls: phone = steer stick (left thumb), GAS / BRAKE / DRIFT (right thumb), RESET, track
buttons on top. PC = W/S, A/D, Space drift, R reset, 1-4 plots.

The player's device owns the car's physics (no lag). Wheels are drawn only on the driver's
screen for now; make them shared before multiplayer.
