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
- (Old note, the blocky cars are gone) Heavy, Tank, Bulldozer were made faster once. Win rates need a re-check after any speed change.

## Cars and abilities (replaces the weapons)
- Weapons are gone (Weapon/WeaponUi/WeaponsConfig, the claw no longer gives weapons, no WEAPON button). Old saves with a `weapons` field just ignore it.
- A car is DATA: `src/shared/CarCatalog.luau` has 30 rows (id, name, FBX `model` name from vehicle-pack-30, rarity, ability, color). All 30 share `CarCatalog.Neutral` stats (carter: do not tune yet; a row can override with `stats`). Add a car = add one row (ids are saved in profiles: never rename). Rarities and abilities in the rows are PLACEHOLDERS.
- `CarConfig.Cars` is now the pack catalog only (the 8 old blocky cars were removed; ids kept in `CarConfig.Retired`), so `CarConfig.FullOrder` lists the pack cars and `CarConfig.Order` the 12 launch cars. `LobbyConfig.Rarity` is built from CarConfig. Rarities: Common, Rare, Epic, Legendary (`CarConfig.Rarities`). Claw odds 55/28/14/3 and the 2500 Legendary store price are placeholders.
- Abilities: Dash, Shield, Slam, Ram, Magnet, Jump. Numbers and rarity strength in `AbilitiesConfig` (Rarity.power/cooldown); pure `Abilities.resolve(id, rarity)` / `forCar(stats)`. Tests: `tests/abilities.test.luau`, `tests/catalog.test.luau`.
- Runtime: `server/Specials.luau` fires the car's ability on the SPECIAL button (Match -> `Moves.press`), server-checked cooldown, same rate limit as boost/jump. The fight message carries `ability` (name) and the SPECIAL button shows it. Shield = `Buffs.applyFor`; Ram = damage window read by Match; Slam/Magnet shove the enemy (mass-aware); Dash/Jump are impulses on your own car.
- Wheels/engine/armor (Build, BuildConfig) multiply any car's stats and keep `ability/rarity/model`, so they work on every pack car. Swap wheels overlaying a model's own wheels is Studio work, not done here.
- Not done: the 30 FBX models are not in the repo or used by CarBuilder yet (still box bodies; `model` names are ready for the Studio side). Not run in Studio; ability feel is untuned. selene and luau-analyze were not run locally (no Roblox API dump offline); CI lints.
- Lobby roof is steel with skylights and hanging lamps (look-only, CanQuery off). Spawn z=54, 12+ studs inside the gate so the camera stays inside.
- Lobby is a 180x140 warehouse race HQ (LobbyLayout + Lobby.luau): bay-door gate, pad row, hero truck stage, back mezzanine + big CAR VS CAR sign, garage corner (left), claw + lounge (right), store (back left), skylights/windows. Props are Blender v2 models swapped in by name (LobbyProps.luau); motion/glow in LobbyLife.luau. All look-only.
- Look: src/server/Atmosphere.luau sets lighting, haze, soft bloom, colour grade at start (bloom kept low: neon washes out).

## Build and watch (auto fight)
- `GameConfig.Mode.autoFight`: `false` (now) = you aim, launch and drive your own car in the bowl; `true` = the cars fight by themselves (build and watch). `Mode.useBuild = true` = the garage car and parts are used in both (no pick 1 of 3).
- Players build a car in the GARAGE (button on the left): car, wheels, engine, armor, level per slot. Rules are in `Build`/`BuildConfig` (pure, tested). Prices are placeholders.
- In a match the server drives every car with `Autopilot.step`; taps (boost, special) still add power moves. "ready" countdown, then fight, short freeze on the KO.
- Bots get random parts near the player's average level. Win 60 / lose 20 coins.
- Player bays: `LobbyBays` puts each player's car doing donuts on the mezzanine, with a name + level sign.

## Bowl fun (BowlConfig / BowlRules / BowlHazards)
- SMASH: hits at strength >= 0.6 pop the other car up and spin it, tag "SMASH!".
- 4 boost pads on the slope launch a car over the middle. Low 2.5 lip: knocked over the edge = RING OUT.
- No shrinking ring (Carter said no). Boost pads are cyan with a BOOST sign; each power-up has its own shape, color and name sign, and a name pops up when grabbed.
- Drifting gives boost cooldown back (1.4s per second). New power-ups: magnet (M), rocket (R).
- Not done: 4-6 cars in one bowl (Match is built for 2 cars: `cars[3 - idx]`); sounds (no verified asset ids).

## Claw machine prizes (claw thread)
- Prize rolled on the server (`Gacha.pull`), claw animation plays from the result. Shown odds = rolled odds (`Gacha.oddsTable` skips rarities with no cars, re-scales to 100). Duplicate coins grow with rarity: `LobbyConfig.Gacha.duplicateRefunds`, `Gacha.refundFor`. All numbers are PRETEND. New cars join the claw by getting a rarity in the catalog.
## Update: bowl arena makeover
See SNAPSHOT.md section "Bowl arena makeover". Tune scenery in ArenaLookConfig, skid numbers in SkidRules.Config, pad sign numbers in BowlConfig.Pads. Outside grass beyond the road is not solid (cars fall to the out-of-bounds drop). Lighting (Atmosphere.luau) untouched.

## 2026-10-18: Studio place lost, rebuilt from the repo
The real place was never saved and was lost with the Studio window. Now in the repo: all 115 lobby/bowl model
sources (`assets/models`, Blender FBX), `tools/studio-sort.luau` and `docs/STUDIO_REBUILD.md`. Lobby is being
re-themed from racetrack red to garage steel (`LobbyDecor.clone` + optional `SteelPalette` attribute). The 30
cars still need their own import. Always Ctrl+S and Publish a rebuilt place first.

## Level-ups, streak record, leaderboards
See SNAPSHOT.md section "Level-ups, win streak, leaderboards". Tune in `ProgressConfig` (LevelStatBonus, LevelUpCoins, Board). Boards are server-built SurfaceGuis (`Leaderboards.init`); if they hide behind a prop, change `Board.spot`. Changing a store name in `Leaderboard.Boards` starts a fresh board.
## Daily spin wheel
Tune rewards/odds only in `src/shared/SpinConfig.luau` (placeholders). Quests: `QuestsConfig.luau`. Daily gift: `QuestsConfig.Daily`. Spin UI not yet checked by eye on a phone or in Studio.
## Fight modes
See "Fight modes" in SNAPSHOT.md. Tweak `src/shared/ModesConfig.luau` only (hill hold time, ice grip, 8-car hpScale, ball size/density, goal size, score to win). Untested in Studio: first play test should check the soccer ball (too heavy/light?), that bots do not all pile on the ball, and the top banner on a phone.
## Sound system
All sound ids in `src/shared/SoundConfig.luau` are empty (silent). Fill them from `docs/sounds-needed.md` (Roblox licensed library only, test in Studio). Levels and pitch wobble are placeholders in the same file.

## Analytics
See `docs/analytics.md` and SNAPSHOT.md "Analytics". After publishing, play two matches and a claw pull, then check Creator Hub > Analytics (funnel immediately, custom events within 24 h). Step names and the event schema are in `src/shared/TelemetryConfig.luau`.

## Fight fixes (fairness, pacing, hit flash, comeback)
See SNAPSHOT.md "Fight fixes". Tune in `FairnessConfig`, `GameConfig` (Arena radii, Match.aimTimeout, Ai, Feel, Pacing), `ComebackConfig`. First playtest: log time-to-first-hit, check the smaller bowl scenery fit, the HIT! flash size on a phone, and that bots now dive in sooner. Bowl FBX/scenery sized for 112 may sit too far out.
## Launch simplification
See SNAPSHOT.md "Launch simplification". To bring a cut feature back, set its flag in `src/shared/FeatureFlags.luau`. Placeholders: `BotLevelsConfig.AutoScale` (3 / 15 wins), `MenuConfig.matchesForFullMenu` (2). Per-car quests saved in old profiles are dropped and refilled while the flag is off. Not checked in Studio.

## Launch roster, distinct car stats, bot names (claude/fix-cars)
- `CarConfig.LaunchRoster` (12 cars: Sedan, Compact, DuneBuggy, BoxTruck, Muscle, Kart, DriftKing, SuperCar, MonsterTruck, Semi, Formula, ArmoredTruck). `CarConfig.useFullRoster = false` hides the rest: `CarConfig.Order` is now the live list (claw odds, store, picks, quests, bots); `CarConfig.FullOrder` is every car (saves, remotes, `get`). `CarConfig.isLive(id)`; Store only sells live cars. Set `useFullRoster = true` to bring every pack car back. The 8 old blocky cars (Heavy, Light, Tank, Ramp, Drift, Bulldozer, Spike, Rocket) are removed from `CarConfig.Cars` and listed in `CarConfig.Retired`; old saves that own one get coins back (`Inventory.migrate`).
- Stats: roster pack cars get own numbers + one-line role (shown as the existing `blurb`) in `CarCatalog.Tuned`. `CarPower.score` + `CarConfig.PowerWeights`/`PowerTolerance` (0.2) tested in `tests/roster.test.luau`. All stat numbers and weights are PLACEHOLDERS; abilities untouched.
- `BotNames.luau` (30 names, `pick(seed, taken)`, `pickCar(seed, roster)`); `nameOf` in Match/GroupMatch uses it, so bots show a friendly name instead of "BOT".

## Car soccer small field
See SNAPSHOT.md "Car soccer small field". Tune only in `src/shared/SoccerFieldConfig.luau` (and `ModesConfig.Soccer` for teamSize, scoreToWin, time, goal pause). First play test: ball too heavy/light, bots pile on the ball, ball sticking in corners or nets, camera view of the small field.

## Social + safety
See SNAPSHOT.md "Social + safety". Tune cheat limits in `src/shared/CarSanityConfig.luau` (placeholders; if honest players get snapped back, raise `teleportSlack`/`graceSeconds`). Weekly store name changes every Monday UTC automatically. Carter: set Max Players 12 to 16 in Game Settings (not settable from code).

## Big open garages + likes
- Done in code and unit tests (`lune run tests/run` 330 pass, stylua clean). NOT seen in Studio: how the longer hall, low walls and heart look is unchecked. Lobby wall props were moved by hand (`LobbyMore`, `LobbyDecor`, `LobbyShell`); check for overlaps in the picture check.
- Studio placement of any new Blender garage models is the Studio thread's job (`docs/GARAGE_MODELS_NEEDED.md`).

## Onboarding (w2)
- Placeholders to tune: `FirstWinConfig` (confettiCount, coinCount, bannerScale, texts), `Hints.AimNudgeSeconds`. Nothing needs Roblox ids. First win gives no bonus coins; add one in `LobbyService.finishMatch` if wanted.
## Soccer polish (claude/w2-soccer)
See SNAPSHOT.md "Soccer polish". Tune in `SoccerFieldConfig` (keeper*, cam*) and `ModesConfig.Soccer` (countdown/goal timings). Unverified in Studio: unfreeze re-handing of network ownership (`handOver`), camera framing, keeper play. Tests: 340 pass.
## Car feel traits
See SNAPSHOT.md "Car feel" and `docs/car-feel.md`. Retune in `src/shared/CarTraitsConfig.luau`. First play test: does Compact/DriftKing slide enough, does Armored/Monster push wide without feeling stuck, do bigger pack cars (Monster 1.35x, Armored 1.4x) fit the bowl and garages, do bars fit the store card at small widths.
## Phone UI layout (claude/w2-phone-ui)
- Tune HUD positions only in `src/shared/UiLayoutConfig.luau`; run `lune run tests/run` (uilayout tests catch overlap, small touch targets, anything in the screen middle, anything under the 56 px top bar).
- To check by eye: Studio device emulator at 640x360 and 800x360 landscape. Placeholders: topInset 56, edge 16, lane shares, row heights, menu column numbers.
- Owner of SaveNotice may want to move it clear of the power bar lane (bottom centre).
## Economy sim + perf audit
- Read `docs/economy-report.md` first: the 12-car collection completes by about day 30 and there is no coin sink afterwards; recommendations (higher pull price, sink, pity timer) are NOT applied. Raising the pull price needs `tests/lobby.test.luau` re-pinned (hardcodes 100).
- `docs/performance-audit.md`: nothing measured in Studio; check part counts, `Persistent` streaming of four bowls, and garage lift replication on a phone.
## Bots (w2-bots)
See SNAPSHOT.md "Bots feel like people". Tune in `GameConfig.Ai` and `BotLevelsConfig` (placeholders, tuned on a headless sim not on live physics). If a live bot rides the rim, raise `edgeRadius` risk margin (lower it) or `edgeLook`; if bots never boost, check `moveSpeedShare`/`boostAimDeg`; `GameConfig.Ai.useMoves = false` turns bot boost/ability off. First play test: watch bots on the rim, nose-to-nose time, boost use.

## Mode button, LOBBY button, telemetry (w3)
- Lobby has a MODE button (AUTO / DUEL / HILL / ICE / SOCCER) and a LOBBY button that leaves a match (mid-match and on the end screen). The code for these lives in `LobbyService`, `init.server` and the client UI, not in this note; see the playtest checklist "Mode button and LOBBY button" for what to check.
- Telemetry has two new events, `mode_picked` (mode name from a fixed allowlist) and `left_match` (which phase LOBBY was tapped in). The functions `Telemetry.modePicked(player, mode)` and `Telemetry.leftMatch(player, phase)` exist and are tested; the call sites in the lobby/server code must be added by whoever owns those files. See `docs/analytics.md`.

## Audit fixes: group modes
- Lobby side (other thread): in `LobbyService.finishMatch` call `GroupResults.take(player)` (server/GroupResults) and add `result.coinsBonus` to `earned`; show `place`/`placeOf` ("2nd of 6"), `goals`, `tags`, `survivedSeconds` on the end screen. `init.server`'s `onFinished` wrapper only passes `won`/`stay`, so the result travels through this registry (or read the `Match*` Player attributes in the client). `result == nil` for the 1v1 modes.
- Client side (UI thread / carter): read `KickoffMark` (soccer ring/arrow on your car), `TagFuseEndsAt`/`TagFuseLeft`/`TagIt` (fuse ring over the IT car), `RaceCanReset` (show a RESET button; fire the Action remote with `"reset"`), `MatchOut` (spectate state; Action `"rematch"` is accepted from out players), boost pad discs are neon parts `BoostPad1..6`. Not done: glowing next checkpoint gate and its ping (art/Studio), sounds (no ids invented).
- Studio test list: (1) soccer pad pickup makes BOOST usable at once - the client's own cooldown display may not know it, check the button; (2) `[soccer-stats]` lines in the output after 10 bot matches (#19: goals for the loser, idle > 5 s); (3) race: stand still 6 s = back to last gate, `reset` after 3 s works, ramps never trip the 70 stud ceiling; (4) tag: first IT is a bot, round ends 2 s after the last human is out; (5) leave mid-match in soccer, tag, race: the bot must drive the car; (6) front row start in the first 3 matches.
- #101 (ball network ownership near the nearest human) NOT done on purpose: switching ownership while the ball is touched by cars owned by other clients can desync goals and the speed cap (the server must read the ball position to score). Test first on a throttled device: if the ball jumps, try `ball:SetNetworkOwner(nearestHuman)` only while a human is within ~25 studs and hand it back to the server (nil) otherwise and always before the goal check.
- Not changed: `Autopilot` (the group bots needed no change), `LobbyService`, UI files, `Types`.
## Audit fixes: rewards and lobby
- Wire-up needed in files outside this branch: `init.server.luau` wraps `part.onFinished` as `function(won)` and `Match`/`GroupMatch` call `part.onFinished(youWon)`. Pass the per-player result as the third argument, `finished(won, again, { mode = ..., place = ..., goals = ..., survivedSeconds = ..., tags = ... })` (all optional). Without it every match pays the old flat 60/20 and mode quests / "last mode" / next-goal modes stay empty. Passing `mode` is the safest; otherwise it is guessed from which fields exist.
- Client (carter): show `resultText` instead of YOU LOSE when it is not empty; use `profile.xp`, `levelBonus`, `nextGoal`, `daily.secondsToNext`, `claw` (odds with owned marks, pity bar, labels), `unlockNotice` (then send `hintSeen "unlock"`), `toLobby.invitePrompt`; ask for the session card with lobby action `summary`; send `hintSeen` with `soccer`/`tag`/`race` the first time the mode starts.
- Possible bug found, not in my files: `Profiles.copyProfile` has no `garage`, so garage likes never reach the DataStore. Add `garage = GarageLikes.copy(...)` there.
- Placeholders to tune: everything in `LobbyConfig.ResultRewards`, `Gacha.pityEvery` (10), `Rewards.endScreenSeconds/MaxSeconds` (8/20), `BotLevelsConfig.FirstMatchesEasy` (2), `LobbyConfig.NextGoal.nearCoins` (60), the new quest rewards.
- Not verified: Luau type-check (no analyzer here), anything in Studio. The `send` helper in `LobbyService` now accepts `any` because new message fields are not in `Types.LobbyUpdate`.
## Audit fixes: client feel (claude/audit-client-feel)
Tests: `lune run tests/run` all pass, stylua clean. NOT seen in Studio or on a phone: every item below is unverified by eye.
- **Calm effects (#86):** no button yet (carter builds UI). A UI sets the client attribute `CalmEffects` on `SoundService` to true (`game:GetService("SoundService"):SetAttribute("CalmEffects", true)`), default off, not saved. Name lives in `GameConfig.Feel.calmAttribute`. It fades the hit flash, shrinks shake and FOV punches, halves speed lines and the goal camera snap. The hit flash is also capped at 3 per second (`Feel.maxFlashesPerSecond`), calm or not.
- **Soccer camera (#15):** `FeelRules.soccerCamera` pulls the old framing back/up (`Feel.soccerCamBackMult/UpMult`) and grows it until your car, the ball and your own goal fit. Walls between camera and your car/ball fade via `LocalTransparencyModifier`. Check on a phone at kickoff and when defending.
- **Bowl camera (#99):** `Feel.bowlCam*`; used only in arenas that have `Slope` parts and no `Road` (race and tag keep the old view).
- **Goal burst (#23):** `client/GoalFx` reacts to the "ko" message "GOAL!" / "THEY SCORED!". The server does not send the scorer name yet; if a `scorer` string is added to that message GoalFx shows "NAME SCORES!". Team colour comes from your car's `Marker` colour.
- **Ball (#91), boost (#92), countdown sounds (#93):** `client/BallFx`, boost FOV + `Effects.speedLines`, new sound events `ballKick`, `goal`, `countdownTick`, `countdownGo` (ids empty, listed in docs/sounds-needed.md, four priority sounds first). The bigger "GO!" pop is not done (CenterBanner is UI).
- **Touch steering (#52):** stick steer eases and curves for cars with turnRate >= `Feel.smallCarTurnRate` (`CarConfig` has no steer-smooth number, so the constants are in `GameConfig.Feel.touchSteer*`). Needs the 3-children phone test.
- **Colour-blind icons (#81):** `client/TeamIcons`: bomb above IT (the `TagIt` Highlight), chevron above teammates (cars whose `Marker` colour matches yours in a soccer arena).
- **Low-end fallback (#88):** `client/Quality` cuts particle counts (sparks, smoke, confetti, ball trail) when the average frame time passes 1/28 s; numbers in `Feel.quality`.
- Skipped: #83 (LOBBY leave confirm is UI).
## Audit fixes: docs and telemetry
- Telemetry: new events match_result, tag_survived, first_score, first_input, quit_after_elimination, car_acquired; claw_pull and rematch_tapped now carry source/mode; funnel is now 10 steps (first_input, first_score inserted). `Telemetry.matchEnded(player, won, result?)` reads place/goals/tags/survivedSeconds defensively. NOT YET CALLED: firstInput, firstScore, eliminated, carAcquired, and the result argument (callers live in init.server / GroupMatch / LobbyService). See docs/analytics.md.
- Docs: store-page rewritten to the real game (soccer, tag, race, claw, garages), Max Players steps for carter; playtest-checklist has save/rejoin, claw double-tap and two-human payout steps; performance-audit has a phone FPS procedure.
- Code: SaveNotice text is "Saving paused. Your coins may not be kept." (shown only when ProfileUnsaved is true); leaderboards say "No scores yet" after 5 s without data (weekly board is the middle one); Profiles waits for an in-flight leave-save before a same-server rejoin loads (stale-data fix); claw double-pull test in tests/telemetry.test.luau.
## Audit fixes: cars
- GroupMatch owner: set attribute `GameMode` (string "soccer" | "tag" | "race"; anything else or missing = old behaviour) on the Arena folder/model that contains the cars (Specials walks up from the car model). Soccer: Slam pushes / Magnet pulls the unanchored part named `Ball` inside that instance. Tag: Shield sets `TagImmuneUntil` (server time) on the car model for 2 s; the tag rules must call `Specials.tagImmune(car)` before passing IT. NOT wired yet, GroupMatch is another helper's file.
- UI: read car model attributes `AbilityReadyAt` / `AbilityCooldown` (fraction = `Abilities.cooldownFraction(readyAt, cooldown, workspace:GetServerTimeNow())`), `CosmeticRarity`, `TrailColor`, `AbilityEffectColor`. `CarCatalog.modeStars(id)` for pick-screen stars. Level cosmetics: `CarCatalog.LevelCosmetics`.
- Client steering helper: ease the steer value with `Steer.smooth(cur, target, dt, CarConfig.steerSmoothRate(stats.turnRate))`.
- Untested in Studio: ball impulses, attributes, rarity flash colors. Only the pure rules have unit tests. Tests: 448 pass.
## Carter's Champions UI is in (replaces the old lobby + match screens)
- Source: `src/champions/` (his package, runtime approach, preview off). Rojo mounts `ReplicatedStorage.CVC_Champions` (Shared modules + 4 BindableEvents Actions/State/Open/Notify) and `StarterPlayerScripts.ChampionsClient`. Do not show the static `editable/` screens too.
- Glue: `src/shared/ChampionsAdapter.luau` (pure, tests/champions.test.luau) turns server messages into UI snapshots and UI buttons into the old remotes; `src/client/ChampionsBridge.luau` connects it. UI buttons: PLAY/CANCEL = LobbyAction play/cancelPlay (QUEUE text from the countdown message), BuyCar=buyCar, EquipCar=buildCar, PullClaw=buyGacha, ClaimGift=claimDaily, ChooseCar=pickStarter (new player) or pickCar (pad pick), Rematch=rematch (end screen) or play (back in lobby), LeaveMatch=leaveMatch, Boost/Ability=Action boost/special. SetMode/ResetCar/spectate arrows send nothing.
- His edits to make it fit: one mode "FIGHT" (id DUEL so his icon/layout apply; scoreboard shows YOU round wins / cars LEFT / clock / ROUND n); the MODE button on the lobby bar is now PLAY/CANCEL; the lobby hint says PRESS PLAY TO FIGHT. Cars, rarities, abilities, prices, claw odds and gift coins come from the game (`champions/shared/Config.luau` reads CarConfig/Store/Gacha), so they cannot drift. His 12 pictures are mapped to the 12 launch cars by closest look in `champions/shared/Assets.luau` (Semi/ArmoredTruck/Kart are loose matches: swap the ids there).
- Server additions: `fightHud` UiUpdate (cars left, my round wins, round) every second in the car fight; `fight` also carries wins/carsLeft; profile `daily.coins` (what the next gift pays, `Daily.nextCoins`). The Studio-only DEV: BOT MATCH button and `devMatch` action are gone.
- Removed client UI he replaced: LobbyUi (coins box, claw modal, cars/store list, pick card, countdown, toast), ModeUi, ProgressUi, ActionInput (BOOST/ABILITY buttons; Space still jumps via the bridge), CarStatsUi, the old top banner/LOBBY/REMATCH buttons in Ui. Kept: QuestUi (QUESTS panel; no GIFT button any more), BuildUi garage, CenterBanner, ModeBanner (moved under his scoreboard), BuffUi, hints, all world effects.
- Win flow: matchEnd shows the old headline + confetti for 3.5 s, then his Results screen; toLobby fills in coins and keeps Results open until he taps LOBBY or REMATCH(=PLAY).
- Not verified by eye / phone yet: see the pictures in /mnt/project-files/car-vs-car/shots/ui/ when they exist. Settings: only SFX switch is wired (mutes all sound); music/reduced motion are display only.

## 1v1 auto-battle (latest)
All tuning is in `src/shared/BattleConfig.luau` (HP, speeds in L per second, weapon numbers, timings, prices = placeholders).
Sim results (tests/battlesim, NOT real physics) show Saw beats Ram and Cannon, Ram beats Cannon: playtest then tune.
Garage performance upgrades and car levels do not apply here. XP, quests and car levels are not wired to this mode.
Flip `FeatureFlags.battleMode` to false to get the old pad fights back.
## Battle map (Toy Box Showdown)
Fight code: read spawns from `arena.spawnPoint(side)` (or `SpawnA|B` pad parts). Match slots are 520 studs apart. The map is now "Toy Room Showdown" (240x160): spawns x = +-100. To change the map, edit numbers in `src/shared/BattleMapLayout.luau`; `lune run tests/run` checks symmetry and clear lanes. Look check in Studio still to do.

- Map: spawn lanes are clear now (bunkers beside the lane). Studio helper: sync the newest map and check a straight drive from each spawn reaches the middle.

- Map: Duel Car Arena is live (PR pending). Studio helper: sync, save, drive straight from each start, take pictures (top, each start, a wall + tire stack, a garage, cover block, trees outside).

- Map: Duel arena 9/10 pass. Driving thread: call arena.setTeams(random), arena.setNames(player, bot name) at match start and arena.openDoors() at GO, arena.closeDoors() for the next round. Studio helper: sync, save, take the 8-10 pictures asked for.

## New Car Battle Lobby (2026-10-20, carter's 70 picks)
Replaces the warehouse lobby (archived in `archive/lobby_v1`, shipped to ServerStorage.LobbyArchive, never run). Spec: `docs/LOBBY_SPEC.md`. NOT seen in Studio yet.
- Layout numbers: `src/shared/LobbyLayout.luau` (pure, `tests/lobbylayout.test.luau`). Builders: `Lobby.luau` (entry, `Lobby.build()` returns spawn, folder, claw anim, parking, pads, boards, showcase) + `LobbyGround`, `LobbyScenery`, `LobbyGarageShell` + `LobbyWorkshop` / `LobbyCustomize` / `LobbyShop` / `LobbyBoards`, `GumballAnim`, `LobbyPads`, `LobbyParking`, `LobbyShowcase`, `LobbyCarModels`, `LobbyPlayers` (walk speed 24 + name tags + crown tag).
- PLAY: 4 mini pads, 2 players each (`PadSlots`, pure). Standing on a pad (checked 4x/second in `LobbyPads.start`) or the PLAY button (walks you onto a pad) joins it; two on one pad start a fight (`BattleService.padSync`); one player waits forever, no bot. `BattleService` parks fighters under the lobby (anchored) and `returnToLobby` puts them next to the pads. The old global queue (`BattleQueue`, `queueSeconds`) is gone.
- Prompts by name: `GachaPrompt` (gumball), `CustomizePrompt` (paint + garage), `StorePrompt` (shop). Boards: `Leaderboards.init(panels, face, onChampion)`; the weekly #1 gets the gold car on the workshop stage + a crown tag.
- Client: `LobbyClient` (arrow for new players, fade into/out of the fight, rare pulls in chat via LobbyUpdate `announce`, cuts FarScenery on a slow phone). QUESTS/GARAGE menu buttons stay hidden: the screen has PLAY, CARS, SHOP and GIFT.
- Tests: `tests/robloxmock.luau` is a small fake Roblox so builders run under Lune (`lobbybuild.test`, `lobbyground.test`, ...). It checks sizes, heights and errors, NOT looks.
- Still needed from carter: sound ids (lobby music spot is silent), coin pack / VIP ids + prices, icons. Shop contents are carter's Champions UI.
