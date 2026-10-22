# RC car feel test

One small RC car and three grey tracks (drift, race, rock climb). Only job: find out if driving
feels great. Nothing from the old Car VS Car game is used at run time.

- Serve in Studio: `rojo serve rc-test/default.project.json` (fresh Baseplate place; the script
  removes the baseplate and spawn).
- Tests: `cd rc-test && lune run tests/run`
- Feel numbers: `src/shared/Tuning.luau`. Track shapes: `src/shared/TrackData.luau`.

Controls: phone = steer stick (left thumb), GAS / BRAKE / DRIFT (right thumb), RESET, track
buttons on top. PC = W/S, A/D, Space drift, R reset, 1 2 3 tracks.

The player's device owns the car's physics (no lag). Wheels are drawn only on the driver's
screen for now; make them shared before multiplayer.
