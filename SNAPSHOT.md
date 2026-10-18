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

## Cars and abilities (replaces the weapons)
- Weapons are gone (Weapon/WeaponUi/WeaponsConfig, the claw no longer gives weapons, no WEAPON button). Old saves with a `weapons` field just ignore it.
- A car is DATA: `src/shared/CarCatalog.luau` has 30 rows (id, name, FBX `model` name from vehicle-pack-30, rarity, ability, color). All 30 share `CarCatalog.Neutral` stats (carter: do not tune yet; a row can override with `stats`). Add a car = add one row (ids are saved in profiles: never rename). Rarities and abilities in the rows are PLACEHOLDERS.
- `CarConfig` still holds the 8 old cars (now with `rarity` + `ability`) and appends the catalog, so `CarConfig.Order/get/Cars` list 38 cars. `LobbyConfig.Rarity` is built from CarConfig. Rarities: Common, Rare, Epic, Legendary (`CarConfig.Rarities`). Claw odds 55/28/14/3 and the 2500 Legendary store price are placeholders.
- Abilities: Dash, Shield, Slam, Ram, Magnet, Jump. Numbers and rarity strength in `AbilitiesConfig` (Rarity.power/cooldown); pure `Abilities.resolve(id, rarity)` / `forCar(stats)`. Tests: `tests/abilities.test.luau`, `tests/catalog.test.luau`.
- Runtime: `server/Specials.luau` fires the car's ability on the SPECIAL button (Match -> `Moves.press`), server-checked cooldown, same rate limit as boost/jump. The fight message carries `ability` (name) and the SPECIAL button shows it. Shield = `Buffs.applyFor`; Ram = damage window read by Match; Slam/Magnet shove the enemy (mass-aware); Dash/Jump are impulses on your own car.
- Wheels/engine/armor (Build, BuildConfig) multiply any car's stats and keep `ability/rarity/model`, so they work on all 38 cars. Swap wheels overlaying a model's own wheels is Studio work, not done here.
- Not done: the 30 FBX models are not in the repo or used by CarBuilder yet (still box bodies; `model` names are ready for the Studio side). Not run in Studio; ability feel is untuned. selene and luau-analyze were not run locally (no Roblox API dump offline); CI lints.

## Bowl arena makeover (look only, no physics changes)
- Arena: grey concrete bowl, red/white rim, curb + steel skirt + asphalt ring road, hazard pads, tires, cones, barriers, 4 floodlight towers, trees, hills, rocks, ocean. `server/ArenaScenery.luau`, pure layout `shared/ArenaLayout.luau`, numbers `shared/ArenaLookConfig.luau`. About 330 parts per arena.
- Boost pads: blue sign panel + cyan chevrons (`BowlHazards`), still ground push only, no hop. Power-ups: icon + name pill + glow (`Pickups`, `shared/PickupStyle.luau`).
- Effects: skid marks + tire smoke (`client/SkidFx.luau`, `shared/SkidRules.luau`), sparks; NO "SMASH!" text, shockwave ring removed.
- HUD: YOU vs BOT banner, name + HP bar over cars (`HpBar`), joystick, BOOST (cyan) + ABILITY (yellow) only; JUMP button gone. `shared/HudStyle.luau`.
- Not checked by eye in Studio. Check: sign text mirrored (BowlHazards Face.Back/Front), sign clipping the wall, ocean visible from lobby, trail look.

## Bowl v2 (carter's feedback)
- Bigger + deeper: rim radius 62 -> 112, flat middle 28 -> 50, slope 18 -> 28 degrees (rim ~33 studs above the floor), 48 slabs, arenas 1000 apart. Spawn 92, bot run-up radius 88 / retreat 55. Scenery radii follow `RIM` in ArenaLookConfig (keep it equal to GameConfig.Arena.rimRadius).
- Spinner bar removed (no obstacles now).
- Boost pads push SIDEWAYS along the rim (tangent), the way round follows the car's own direction; chevrons point along the rim. `BowlRules.padLaunch(pad, kick, lift, vx, vz)`.
- Camera follows your car more (0.6 shift) and sits closer (60 back, 72 up). "Pull back, let go" text is small under the banner.
- Not checked in Studio: launch speeds (Launch min/max 70-150) may feel slow in the bigger bowl; steep slope driving; camera framing.

## Level-ups, win streak, leaderboards
- Car levels were already in (XP per match, badge). New: each level adds +3% HP and hit damage (`Progress.applyLevel`, used in `CarBuilder`; bots stay level 1) and pays one-time level-up coins (`ProgressConfig.LevelUpCoins`, folded into `coinsBonus`). All numbers are PLACEHOLDERS.
- Win streak bonus already existed (3/5/7+). New: `progress.bestStreak` (record, old saves migrate to 0 or current streak).
- Leaderboards: pure `shared/Leaderboard.luau` (scores, throttle, rows, text), server `Leaderboards.luau` (OrderedDataStores `TopWins_v1`, `BestStreak_v1`; best score only, throttled, retries; top 10 refreshed every 60 s; two boards built in code at `ProgressConfig.Board.spot`). Scores are sent from `LobbyService.finishMatch`.
- Tests: `tests/progress.test.luau`, `tests/leaderboard.test.luau` (236 pass). Not run in Studio: board position/look unchecked by eye, DataStore calls untested (Studio needs API access on).
## Daily spin wheel (quests + daily gift were already in; spin added)
- Quests and the daily gift (free claw try) already existed (`Quests`, `QuestsConfig`, `Daily`, `QuestUi`). New: daily spin wheel.
- `src/shared/SpinConfig.luau` (segments + weights; ALL rewards are placeholders), `Spin.luau` (pure: one spin per UTC day, `oddsTable`, `pick`, `spin`), tests `tests/spin.test.luau`.
- Server: `LobbyService` action `spin` (limited 2 per 3s) rolls with its Random, marks the day used BEFORE paying, sends `spinResult` + profile (`spinReady`). Save field `profile.spin = {lastDay}`.
- Client: `src/client/SpinUi.luau` (SPIN menu button, odds list shown before spinning, wheel turns to the server's pick). Not eyeballed in Studio.
- Also fixed: `Profiles.copyProfile` was dropping `build`, so garage builds were never saved.
## Fight modes (hill, ice, last standing, soccer)
- A match picks its mode by rotation: `Modes.pick(matchCounter)` in `init.server.luau` goes round `ModesConfig.Order` (duel, hill, ice, lastStanding, soccer). Take a name out of `Order` to stop it coming up. A rematch is the next mode.
- Pure rules + tests: `src/shared/Modes.luau`, numbers in `ModesConfig.luau`, tests `tests/modes.test.luau`.
- hill / ice stay 1v1 inside `Match.new(..., mode)`: hill = glowing circle (alone on it scores, hold 20 s wins, HP and ring-outs still count); ice = bowl friction and side grip way down (`GripMult` attribute on the car, read by `client/DriveCar`).
- lastStanding / soccer = `src/server/GroupMatch.luau` (same handle as Match). 1-2 players, bots fill to 8 cars (lastStanding, 60% HP each) or 3v3 (soccer, humans on team 1). No aiming: "ready" countdown, then drive. Soccer: giant ball, goal arcs on the bowl wall, first to 3, time up = more goals, tie = next goal wins.
- Look/props: `src/server/ModeFx.luau`. HUD line: UiUpdate `modeInfo`, shown by `src/client/ModeBanner.luau`.
- Checked: Lune tests (244). NOT checked in Studio or by eye: soccer ball feel, bot play in soccer/8-car, goal arcs, banner. Tune only in ModesConfig.
## Sound system (review M2)
- `src/shared/SoundConfig.luau` (events hitSoft/hitHard/boost/ability/win/lose/click/claw/coin/music_lobby/music_arena; ALL ids EMPTY = silent; volumes/pitch are placeholders), pure `Sounds.luau` (resolve -> spec or nil, hit strength -> soft/hard, volume clamp), client `SoundFx.luau` (lazy Sounds under SoundService, looping music, mute kept in a client-only SoundService attribute).
- Hooks: hit/win/lose/fight+lobby music in `init.client`, click in `UiStyle.polish` + `LobbyUi.button`, boost/ability in `ActionInput.press`, claw result and coin toast in `LobbyUi`. MUSIC mute button in the lobby menu.
- Carter must fill ids: see `docs/sounds-needed.md`. Tests: `tests/sounds.test.luau`. Not heard or run in Studio.
## Analytics (review M3)
- `src/server/Telemetry.luau` (funnel + custom events via AnalyticsService; pcall, deferred, no-op in Studio, global send cap), pure `src/shared/TelemetryRules.luau` + `TelemetryConfig.luau`, tests `tests/telemetry.test.luau`. One-line hooks in `init.server`, `LobbyService`, `Match`, `GroupMatch`. Table of events and what a bad number means: `docs/analytics.md`.
- PLACEHOLDER: `TelemetryConfig.RateLimit` (200 per 60 s). Not verified: real sends (only work in a published game), `LogCustomEvent` customFields argument against the live API, dashboard display.
## Fight fixes: fairness, pacing, hit flash, comeback (review M5, M6, V3)
- Fairness: `shared/Fairness.luau` + `FairnessConfig.luau` (`neutralizeHumanMatches`, default on). With 2+ humans in a match, `Match` passes `fair` to `CarBuilder.build`: car level bonus ignored, ability rarity forced to Common. Bots keep all bonuses. Garage build parts (`Build.stats`) are NOT neutralized.
- Pacing: bowl shrunk, rim radius 112 -> 85 (`ArenaLookConfig.RIM` = 85), spawn 92 -> 68, aim timeout 8 -> 6, bot run-up radius 66 / retreat 42, Light bot circles 0.7 s (was 2) at radius 16. Mode rings (`ModesConfig` spawn 68, soccer goalRadius 66) follow. `shared/Pacing.luau` + `GameConfig.Pacing` (target 8 s, detour 1.5) with a test on worst-case first contact (aim timeout + travel). The math is an estimate; real time-to-first-hit is NOT measured.
- Hit feel: `client/HitFlash.luau` (screen flash, "HIT!" label, strong hits get "HIT! -dmg" and extra shake) hooked in `init.client` hit handler; rule `shared/HitFeel.luau`; numbers `GameConfig.Feel` (flashFrom, strongFrom, extraShake). No sound. Not seen in Studio.
- Comeback: `shared/Comeback.luau` + `ComebackConfig.luau` (default on, under 25% HP, +35% speed fading over 0.9 s, once per fight on first boost/ability). Applied in server `Moves` (mods + popMult for client-driven cars; Match speed cap allows it). All numbers are placeholders.
- Tests: `tests/fightfix.test.luau` (265 pass total).

## Launch simplification (feature flags)
- `src/shared/FeatureFlags.luau`: pure flags. Off at launch: dailySpin, rankBadges, paintShop, perCarQuests, botLevelButton, lastStandingMode. On: soccerMode (carter kept it). Hidden = not built/ignored, no code deleted.
- ModesConfig.Order = duel, hill, ice, soccer (`ModesConfig.orderFor(flags)`). QuestsConfig.Catalog = win3, play5, bot2 (`catalogFor(flags)`). Spin and buyPaint/equipPaint server actions ignored while off; SpinUi/PaintUi/BotLevelUi not created; rank text empty.
- Bot level: `BotLevels.forWins` / `levelFor`, thresholds `BotLevelsConfig.AutoScale` (easy under 3 wins, medium under 15, else hard; placeholders).
- New-player menu: `MenuRules.visible(profile)` + `MenuConfig.matchesForFullMenu = 2`. Profile has a new `matches` counter (migrates to 0, +1 per finished match in `finishMatch`). `MenuBar.setShown` hides buttons.
- `client/SaveNotice.luau`: "Progress not saving right now" text when player attribute ProfileUnsaved is true.
- Tests: 264 pass (Lune). Not checked in Studio or by eye.

## Launch roster, distinct car stats, bot names (claude/fix-cars)
- `CarConfig.LaunchRoster` (12 cars: Heavy, Light, Sedan, DuneBuggy, Ramp, Bulldozer, Drift, Spike, Rocket, MonsterTruck, Formula, ArmoredTruck). `CarConfig.useFullRoster = false` hides the rest: `CarConfig.Order` is now the live list (claw odds, store, picks, quests, bots); `CarConfig.FullOrder` is every car (saves, remotes, `get`). `CarConfig.isLive(id)`; Store only sells live cars. Set `useFullRoster = true` to bring all 38 back.
- Stats: roster pack cars get own numbers + one-line role (shown as the existing `blurb`) in `CarCatalog.Tuned`. `CarPower.score` + `CarConfig.PowerWeights`/`PowerTolerance` (0.2) tested in `tests/roster.test.luau`. All stat numbers and weights are PLACEHOLDERS; abilities untouched.
- `BotNames.luau` (30 names, `pick(seed, taken)`, `pickCar(seed, roster)`); `nameOf` in Match/GroupMatch uses it, so bots show a friendly name instead of "BOT".

## Car soccer small field
- Soccer no longer uses the bowl. It has its own flat field (120 x 70 studs, 30 high walls, 45 degree cut corners, 24 wide goal mouth with 10 deep nets, invisible lid), built in code by `src/server/SoccerArena.luau` in the match's own slot (same far-away spot as the bowl). Team 1 defends the -X goal.
- Pure rules + tests: `src/shared/SoccerField.luau` (goal boxes + goal detection, spawn spots facing the ball, bot aim point, out-of-bounds, ball-stuck timer, ball speed cap, wall layout), numbers in `src/shared/SoccerFieldConfig.luau`, tests `tests/soccerfield.test.luau` (265 pass in total).
- `GroupMatch` uses it only for mode "soccer" (arena pick, goal boxes replace the circular arc test, ball stuck/out-of-bounds reset, cars that leave come back at their spot). Kept: scoreToWin, teams, bots, goal pause, timer, golden goal. `ModesConfig.Soccer.teamSize` is now 2 (2v2); the old bowl goal numbers there are unused. Bowl and the other modes are untouched.
- Empty Folders in the arena for Studio models later: `BallSpawn`, `GoalA`, `GoalB`, `ScoreBoardAnchor` (each has a `Position` attribute). No models are imported by code.
- Placeholders / not checked in Studio: field size, wall height, ball size/density/bounce/speed cap (9 studs, 0.3, 0.7, 100), bot aim offsets, camera framing of the small field, whether cars clear the net sides, grass/line look.
