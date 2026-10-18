# SNAPSHOT — Car VS Car

## Phase 1 (design: /mnt/project-files/car-vs-car/game-plan.md, D3 changed by carter)
Aim once, then the cars drive themselves. Flow: drag back like a slingshot, let go -> both cars launch ->
Autopilot (run-up + ram) drives both -> HP drops on hits -> HP 0 = match over. Time up (120 s): higher HP wins,
equal HP = next hit wins. Camera sits behind YOUR car (it is the near one).
- Removed: boost, specials, counters, hearts, A/D + LOCK AIM buttons, power meter, the "coast only" loop.
- New: `src/shared/Duel.luau` (drag math, bot aim, timeout winner; tests in `tests/duel.test.luau`), `Drag` in GameConfig.
- Aim angles are absolute (-180..180, 0 = +Z); the server clamps angle and power.
- Solo vs bot. Phase 2 = two real players.
- Checked in Studio by script (launch, run-up, hits, HP, no errors). NOT checked by eye or on a phone:
  the real drag gesture, how it looks. Tune `Launch`, `Drag`, `Drive`, `Ai`, `Damage` after a play test.
- Leftovers (unused): `Fight.luau` counter/special helpers, `FightFx.counter`, `Effects.counterSparks`,
  `Ability` remote (created, not handled), `Logic.loseHeart/tickBoost/canBoost`.

The sections below describe the OLD prototype and the lobby; parts about autopilot, boost, specials, hearts are out of date.


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

## Lobby: shared pure modules (helper A)
`src/shared/LobbyConfig.luau` (all lobby numbers: price, odds, rarity, rewards, starters), `Inventory.luau` (Profile, default/migrate/ownedList/owns/addCoins/grantCar), `Gacha.luau` (oddsTable/canBuy/pull), `PickChoices.luau`. Tests: `tests/lobby.test.luau`.
Tweak odds/prices/rarity in LobbyConfig only (odds must sum to 100; every car needs a Rarity). `Gacha.pull` errors if unaffordable, so check `canBuy` first. `migrate` gives starters if nothing valid is owned. LobbyConfig.Lobby.origin falls back to a plain table under Lune (no Vector3).

## Lobby: persistence (helper B)
- `src/shared/SessionLock.luau` (pure: canClaim/claim/save/release over `{lock={jobId,t}, data}`, TTL 150s), `src/shared/Retry.luau` (pure backoff + `run` with injectable wait), tests in `tests/saves.test.luau`.
- `src/server/Profiles.luau`: `get`, `waitFor`, `markDirty`, `release`, `init` (call once from init.server). DataStore `PlayerProfiles_v1`, key `p_<UserId>`, autosave 60s (staggered), release on PlayerRemoving, BindToClose flush.
- Load failure or lost lock: player gets a default profile with attribute `ProfileUnsaved=true` and it is never written. Tweak constants at the top of Profiles.luau.

## Lobby: world (Lobby.luau)
`src/server/Lobby.luau` builds the night neon garage in code at `LobbyConfig.Lobby.origin` and returns `{ spawn, pads, folder }` (pads have `part`, `prompt` "PadPrompt" with attr PadIndex, `setStatus(text)`). Also "GachaPrompt" and "StorePrompt". Showcase car spins on Heartbeat.
All positions/sizes (room, pads, gacha, store, spawn) are in the pure `src/shared/LobbyLayout.luau` (tests: `tests/lobbylayout.test.luau`). Tweak layout there; colours are constants at the top of Lobby.luau.

## Lobby: client UI (helper D)
- `src/client/LobbyUi.luau`: coins/wins HUD, gacha screen (odds from `Gacha.oddsTable()` + price shown above the OPEN button, disabled via `Gacha.canBuy`), cars list (owned/locked), pick-1-of-3 with timer, pad countdown + LEAVE, reward toast. Prompts "GachaPrompt"/"StorePrompt" open screens.
- Text/logic helpers in `src/shared/LobbyText.luau` (tests: `tests/lobbytext.test.luau`). Colors/sizes are constants at the top of LobbyUi.
- `Ui.hideMatch()` hides match UI; PLAY AGAIN and the start-up pick menu are gone. `CameraDirector.release()` returns the camera to Custom on `toLobby`.
- Not verified in Studio (no luau-analyze here); eyeball on phone size.

## Lobby: server flow (LobbyService, PadLogic)
- `src/shared/PadLogic.luau` (pure, tested): pad states idle/countdown/locked, join/leave/tick/cancel, one player = one pad, pick validated against offered cars, timeout auto-pick.
- `src/server/LobbyService.luau`: listens to pad prompts, ticks countdown (LobbyConfig.Pad), bot fills at 0, sends `choices`, validates `pickCar`, auto-picks on timeout, rolls gacha on the server (`Gacha.pull` + `Random`), pays rewards, `LoadCharacter` back at the lobby, sends `profile` + `toLobby`. Cancels cleanly if the player walks away (prompt distance + 10 studs), dies or leaves.
- `Match.new(player, slot, remotes, opts)`: with `opts {carId, onFinished}` skips pick, no play-again, calls onFinished after `Rewards.endScreenSeconds`.
- `init.server.luau`: CharacterAutoLoads = true, Matches created on demand (freeSlot), `LobbyAction` limited to 6 per window, gacha 2 per 3s. New remotes: LobbyAction, LobbyUpdate.

## Fight upgrades (top 5)
- Faster start: Launch 80-170, car accel/maxSpeed up ~35%/15%, Drive.turnGain 8, Ai retreatTime 1.1 / retreatDist 28.
- Specials (Q / SPECIAL button, 8s cooldown): Heavy slam, Light dash, Ramp flip kick, Spike spikes-out. Numbers: GameConfig.Special. Bot uses them too.
- Counter hit: tap boost within 0.25s before a hit lands = 35% damage + attacker shoved. Tap locks counter 4s. GameConfig.Counter.
- Ring-out: past rim radius + 3 studs (or fell) = round lost, "RING OUT!". GameConfig.RingOut.
- K.O. moment: server sends ko/counter/special updates; client FightFx (white flash, big text, FOV punch). Pure rules in src/shared/Fight.luau (tests/fight.test.luau).
- Not eyeballed in Studio yet.

## Latest (driving rewrite)
Flat arena with spinner, ramps, blocks and pillars. Full driving (joystick / WASD), player's device owns their car during the fight. Details in HANDOFF.md, section "Driving now". Tests: 170 passing.

## Car weapons
- 8 weapons (src/shared/WeaponsConfig.luau), one worn per player, won from the claw (dupes = coins). Server runtime: src/server/Weapon.luau (called from Match). WEAPON button (Q) only for active weapons. Menu: src/client/WeaponUi.luau.
- Studio test shortcut: set player attribute DevWeapon to a weapon id, then DEV: BOT MATCH.
- Flame shoots from the back; bot picks a random weapon.

## Bowl arena makeover (look only, no physics changes)
- Arena: grey concrete bowl, red/white rim, curb + steel skirt + asphalt ring road, hazard pads, tires, cones, barriers, 4 floodlight towers, trees, hills, rocks, ocean. `server/ArenaScenery.luau`, pure layout `shared/ArenaLayout.luau`, numbers `shared/ArenaLookConfig.luau`. About 330 parts per arena.
- Boost pads: blue sign panel + cyan chevrons (`BowlHazards`), still ground push only, no hop. Power-ups: icon + name pill + glow (`Pickups`, `shared/PickupStyle.luau`).
- Effects: skid marks + tire smoke (`client/SkidFx.luau`, `shared/SkidRules.luau`), sparks; NO "SMASH!" text, shockwave ring removed.
- HUD: YOU vs BOT banner, name + HP bar over cars (`HpBar`), joystick, BOOST (cyan) + ABILITY (yellow) only; JUMP button gone. `shared/HudStyle.luau`.
- Not checked by eye in Studio. Check: sign text mirrored (BowlHazards Face.Back/Front), sign clipping the wall, ocean visible from lobby, trail look.
