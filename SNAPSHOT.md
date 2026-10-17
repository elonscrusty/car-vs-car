# SNAPSHOT — Car VS Car prototype

Status: unit tests pass (32), CI green. Studio playtest done on carter's PC: pick car -> aim -> launch -> auto-pilot fight -> damage -> hearts -> next round all ran, with a picture check. Not tested by hand: phone touch buttons, dummy ragdoll look, full YOU WIN screen.

## What exists
- Bowl arena (built in code), 4 placeholder cars (Heavy/Light/Ramp/Spike), solo vs bot.
- Pick car -> aim (A/D) -> power bar -> launch -> server auto-pilot -> impact damage -> HP bars
  -> loser's crash dummy ragdoll -> 3 hearts -> YOU WIN / YOU LOSE -> play again.
- Server owns all physics, damage, hearts. Client sends only: car choice, aim angle, launch power.
- 3 RemoteEvents: SelectCar, Launch, UiUpdate. Rate limited + validated on server.

## Layout
- `src/shared/` CarConfig (car numbers), GameConfig (feel numbers), Logic/Ai/ArenaMath/RateLimiter (pure, tested), Aim, Remotes, Types
- `src/server/` init.server (entry), Match (round flow + damage), Arena, CarBuilder, Autopilot, Dummy, HpBar
- `src/client/` init.client (entry), Ui, AimInput, CameraDirector
- `tests/` Lune tests: `lune run tests/run`

## Not done
No DataStore, no abilities, no sounds, no models, no slow-mo (camera follows dummy instead).

## Hit feel + boost (added)
- Server sends `hit` (pos, strength, damage) -> client shake, sparks, damage numbers. Hit stop = server anchors both cars 0.04-0.12s on strong hits.
- Smoke below 35% HP (Fx.luau). KO: camera pushes in on the dummy (not true slow-mo).
- Boost: Ability remote, 0.8s, 5s cooldown, key E/Shift or BOOST button, bot boosts too. Numbers: GameConfig.Feel / Boost.
- Studio check done by script (5 hits, 1 boost, KO, no errors); not eyeballed.
- Lobby: waiting for a reference image carter likes (first one rejected).
