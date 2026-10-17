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
- Studio playtest was driven by script (fired the remotes), not by hand.
- After a hit, cars now drive away and swing back with speed (run-up) instead of reversing. Tune `Ai.retreatTime/retreatDist` in GameConfig.
- Floor and car friction are low (`Drive.groundFriction`) so cars keep speed; `Drive.grip` stops sideways drifting; `turnRate` per car sets how well it can hit.
- Arena is set to always stream to clients (place may have StreamingEnabled on).

- Next: lobby (walkable) after carter sends an image he likes; show top-down map first.

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

## Fight upgrades: tweak
- All numbers in GameConfig: Launch, Special, Counter, RingOut, Ai, Drive. Car speeds in CarConfig.
- Ability remote now takes "boost" or "special". UiUpdate kinds added: special, counter, ko.

## Update (Phase 1: drag to launch, then auto-pilot)
Design follows `/mnt/project-files/car-vs-car/game-plan.md`, but carter chose (2026-10-17) to KEEP the auto-pilot after launch (plan D3 said coast only). Boost, specials, counters, hearts are gone; see top of SNAPSHOT.md. Next: carter plays on phone and says how it feels, then tune. Then Phase 2 (two real players). Lobby code untouched (gacha still there; plan says claw machine in Phase 5).

## Update: two players + claw machine
- Match.new takes 1-2 participants; two players aim at the same time, fight starts when both launch (or aim timeout). A lone player fights the bot. Tested in Studio headless with two fake players: both got aim/fight/hit/ko/roundEnd/matchEnd and one winner.
- Not tested yet: two real players on two devices, a player leaving mid-match in Studio.
- Claw machine: Lobby.luau swaps the placeholder gacha for ServerStorage.Models.ClawMachine (imported FBX, painted by name in Studio since the FBX has no colors; CLAW_YAW_DEG = -90 faces +X). The model lives only in the saved Studio place, not in the repo.

## Manual steering (OLD: replaced by "Driving now" below)
- After the launch a human's car drives forward by itself (gas always on, up to maxSpeed) and the player steers with two big arrow buttons (bottom corners) or A/D / arrow keys. Bot cars keep the autopilot.
- `src/shared/Steer.luau` (pure, tests in `tests/steer.test.luau`): `sanitize`, `spin` (steer right = NEGATIVE Y spin, same sign convention as `Ai.signedAngle`), `smooth`, and a timestamped state where input older than `GameConfig.Steer.staleSeconds` (0.5 s) counts as 0.
- Remote `Steer` (client -> server, one number -1..1), limited to `Remote.steerMaxPerWindow` per second in `init.server.luau`, forwarded to `Match.steer(player, value)`; ignored outside the fight, reset at fight start.
- `Autopilot.stepManual(car, steerInput, dt, rayParams)` shares flip recovery, grounded check, impulse, slope assist and grip with `Autopilot.step` (local helpers). Turn strength: `car.stats.turnRate * Drive.manualTurn`; easing speed `Steer.smoothRate`. Turning only works while grounded.
- Client: `src/client/SteerInput.luau`, started on the "fight" UiUpdate, stopped on roundEnd/matchEnd/onToLobby; re-sends the held value every `Steer.resendSeconds` (0.1 s), sends 0 on release/stop.
- Not verified in Studio (no Roblox runtime offline): button layout on phone, feel of turnRate/smoothRate, real touch release handling.

## Fight moves and game loop (added after manual steering)
- Fight: boost, jump, one special per car, drift, bowl power-ups (shield, big hit, speed), weak spots (back/side hit 2x), two-fast-hits combo (parts breaking off was removed on request). Numbers: `MovesConfig`, `SpecialsConfig`, `PickupsConfig`, `CombatConfig`. Server code: `Moves`, `Specials`, `Pickups`, `Buffs`; client: `ActionInput`, `BuffUi`.
- Loop: win streak bonus, car levels (paint + badge), daily gift (free claw try), quests, paint shop, rank badges, rematch button, bot levels (easy/medium/hard). Pure rules in `Progress`, `Quests`, `Daily`, `Paint`, `Rematch`, `BotLevels`; services `RematchService`, `Appearance`, `Badge`; lobby buttons come from `client/MenuBar`.
- Profile fields added with migration defaults: hintsSeen, progress, botLevel, quests, daily, paint.
- Checked by Lune tests (168) and one scripted Studio fight vs a bot (no errors). Not yet played by hand on a phone; feel is untuned. Prices are placeholders.

## Driving now (arena, controls, network ownership)
- Arena: flat disc (`GameConfig.Arena`, tiltDeg 0, radius 62, walls 14 high), one per match far from the lobby. Obstacles in `Arena.obstacles` (mirrored): a motor-driven spinner bar in the middle, two ramps, two blocks, four pillars. Kinds are built in `server/Arena.luau`; add one by adding a config row.
- Controls: joystick bottom-left (touch or mouse) plus WASD / arrows. Up/W gas, Down/S reverse, A/D steer. `client/SteerInput.luau` (sends steer + gas, throttled 25/s, server limit 60/s).
- A human's car is driven on THEIR device: `shared/CarDrive` (shared with the bot code in `server/Autopilot`) is called every frame by `client/DriveCar`. The server calls `SetNetworkOwner(player)` at the fight start and keeps hits, HP, winner and a speed cap (`Match.limitSpeed`). Bots and fake test players stay server-driven.
- Gotchas: a server `ApplyImpulse` on a client-owned part does nothing, so use `server/Impulse` (it sets velocity). A device only simulates parts near its character, so `Match.parkCharacter` anchors the character under the arena at fight start; `LoadCharacter` in the lobby flow restores it.
- Grip numbers (`Drive.groundFriction` 0.4, `grip` 24) were picked by Carter's play: 0.25/16 too slippery, 0.7/35 too sticky.
- Cars Heavy, Tank, Bulldozer were made faster after Carter said Heavy was not fun. Win rates need a re-check after any speed change.

## Car weapons
- 8 weapons (src/shared/WeaponsConfig.luau), one worn per player, won from the claw (dupes = coins). Server runtime: src/server/Weapon.luau (called from Match). WEAPON button (Q) only for active weapons. Menu: src/client/WeaponUi.luau.
- Studio test shortcut: set player attribute DevWeapon to a weapon id, then DEV: BOT MATCH.
- Flame shoots from the back; bot picks a random weapon.
- Lobby is a garage: concrete upper wall, steel roof (look-only, CanQuery off), hanging lamps, roller door gate, tool walls, oil stains. Spawn z=40 so the camera stays inside.
- Garage small stuff lives in src/server/LobbyDetail.luau (lift+car, carts, tire rack, lounge/TV, posters, pipes, string lights, floor marks). All look-only.
- Look: src/server/Atmosphere.luau sets lighting, haze, soft bloom, colour grade at start (bloom kept low: neon washes out).
