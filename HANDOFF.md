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

## Update (Phase 1, coast-only duel)
Design now follows `/mnt/project-files/car-vs-car/game-plan.md` (carter approved all star picks). Autopilot, boost, specials, counters and hearts are removed; see top of SNAPSHOT.md. Next: carter plays on phone and says how it feels, then tune `GameConfig.Coast/Launch/Drive`. Then Phase 2 (two real players, simultaneous aim). Lobby code is untouched (gacha still there; plan says claw machine in Phase 5).
