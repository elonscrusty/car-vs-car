# Lobby contract (all helpers code against this; do not change it, ask the coordinator)

Look: night neon garage, chunky low-poly. Reference: spawn bottom-center, spinning showcase car center,
GACHA machine + STORE counter on the left, 3 green match pads right ("0/2 PLAYERS"), big neon CAR VS CAR wall sign.
Flow (Ball VS Ball style): walk to a pad, press E -> pad shows 1/2 -> countdown -> bot joins (2/2) -> player gets
3 random OWNED cars, picks 1 -> match vs bot -> win/lose coins -> back to lobby.
Players have a real Roblox character in the lobby (CharacterAutoLoads = true now). Phone first.

## Shared pure modules (helper A owns, Lune tested) in src/shared/
`LobbyConfig.luau` (exact):
```
LobbyConfig.Lobby = { origin = Vector3.new(0, 0, 500), padCount = 3 }
LobbyConfig.Pad = { maxPlayers = 2, countdownSeconds = 3, pickSeconds = 15 }
LobbyConfig.Rewards = { winCoins = 25, loseCoins = 5, endScreenSeconds = 4 }
LobbyConfig.StarterCars = { "Sedan" }          -- owned by a new player
LobbyConfig.PickChoices = 3
LobbyConfig.Rarity = built from CarConfig (Sedan, Compact, DuneBuggy, BoxTruck = Common; Muscle, Kart, DriftKing = Rare; SuperCar, MonsterTruck, Semi = Epic; Formula, ArmoredTruck = Legendary)
LobbyConfig.Gacha = { price = 100, firstPullFree = true,
  odds = { Common = 60, Rare = 30, Epic = 10 },   -- percent, must sum to 100
  duplicateRefund = 50 }                          -- coins back on a car you own
```
`Inventory.luau`: `export type Profile = { version: number, coins: number, wins: number, owned: { [string]: boolean }, freePullUsed: boolean }`
`Inventory.default(): Profile`, `Inventory.migrate(raw: any): Profile` (never errors, clamps/sanitizes, drops unknown car ids),
`Inventory.ownedList(p): {string}` (CarConfig.Order order), `Inventory.owns(p, id): boolean`, `Inventory.addCoins(p, n)`, `Inventory.grantCar(p, id): boolean` (true if new).
`Gacha.luau`: `Gacha.oddsTable(): { { rarity: string, percent: number, cars: { string } } }` (for the UI),
`Gacha.canBuy(p): (boolean, string?)` (reason: "coins"), `Gacha.pull(p, rng: () -> number): { carId: string, isNew: boolean, refund: number, free: boolean }`
(mutates p: pays price or uses free pull, grants car or refunds; rng returns [0,1)).
`PickChoices.luau`: `PickChoices.choose(owned: {string}, count: number, rng: () -> number): {string}` (no duplicates, fewer if you own fewer).

## Persistence (helper B) src/shared/SessionLock.luau + Retry.luau (pure, tested) and src/server/Profiles.luau
`Profiles.get(player): Inventory.Profile?` (nil until loaded) · `Profiles.waitFor(player, timeoutSeconds): Inventory.Profile?`
`Profiles.markDirty(player)` · `Profiles.release(player)` (save + unlock) · `Profiles.init()` (autosave 60s, BindToClose).
Session-locked UpdateAsync, jobId + timestamp lock, retries with backoff, never overwrite on load failure (player plays unsaved with a warning).
Imports `Inventory` (A). Until A lands, B may stub `Inventory.default()` locally in tests but must not create Inventory.luau.

Note: the lobby later gained a MODE button (AUTO/DUEL/HILL/ICE/SOCCER) and a LOBBY (leave match) button; their action names are in the code (`LobbyService`, `init.server`), not in this contract.

## Remotes (helper E edits Remotes.luau): two NEW RemoteEvents (total 6)
`LobbyAction` client->server: `(action: string, arg: any)` actions: "pickCar" (arg carId), "buyGacha" (no arg), "buyCar" (arg carId), "leavePad".
`LobbyUpdate` server->client, one table `{ kind = ... }`:
- `{kind="profile", coins:number, wins:number, owned:{string}, freePullAvailable:boolean}`
- `{kind="gacha", carId:string, isNew:boolean, refund:number, free:boolean, coins:number}` · `{kind="gachaError", reason:string}`
- `{kind="storeResult", ok:boolean, carId:string, reason:string?, coins:number}` (reason: unknown/owned/coins/busy/loading)
- `{kind="countdown", seconds:number}` (pad countdown; seconds=0 means cancelled)
- `{kind="choices", cars:{string}, seconds:number}` (show pick-1-of-3)
- `{kind="toLobby", coinsEarned:number, won:boolean}` (match over, player is back in lobby)
Types go in `Types.luau` (E): `export type LobbyUpdate = {...}` union by `kind`.
Server validates everything: carId must be in the offered choices; gacha rolled on server with `Random`; rate limit all actions.
The old `SelectCar` remote stays for the old pick menu but Match with `opts` skips it.

## Server (helper E): src/server/LobbyService.luau, edits Match.luau, init.server.luau, Remotes.luau, Types.luau
`Match.new(player, slot, remotes, opts: { carId: string, onFinished: (won: boolean) -> () }?)`: with opts it skips the pick phase,
uses opts.carId, and after matchEnd waits `Rewards.endScreenSeconds` then calls onFinished(won) (no play-again button).
Pad join = server listens to ProximityPrompt `Triggered` on prompts named "PadPrompt" (attribute `PadIndex` 1..3).
Pad text via lobby handle `pads[i].setStatus(text)`. Bot "joins" after countdown, player gets "choices".
After match: coins/wins added to profile, `Profiles.markDirty`, respawn character at lobby, send "profile" + "toLobby".
Player leaves pad/dies/leaves game during countdown or pick: cancel cleanly. One player = one pad = one match.

## Lobby world (helper C): src/server/Lobby.luau (+ small src/server/LobbyParts.luau if needed), built in code
`Lobby.build(): LobbyHandle`; `LobbyHandle = { spawn: SpawnLocation, pads: { PadHandle }, folder: Folder }`
`PadHandle = { part: BasePart, prompt: ProximityPrompt, setStatus: (text: string) -> () }` — setStatus puts text (e.g. "0/2 PLAYERS") on the pad sign (SurfaceGui/BillboardGui).
Prompts: pad prompt named "PadPrompt" with attribute PadIndex; gacha machine prompt named "GachaPrompt"; store counter prompt "StorePrompt"
(ActionText "Open", KeyboardKeyCode E, RequiresLineOfSight false, big MaxActivationDistance for phone).
Spawn SpawnLocation faces the showcase car. Showcase car slowly spins (server-side tween/Heartbeat, cheap). Use LobbyConfig.Lobby.origin.
Neon materials + PointLights, wet shiny floor (Reflectance small), signs with real TextLabels: "CAR VS CAR", "GACHA", "STORE".
One-time sample first is NOT needed here; carter sees one picture check at the end.

## Client (helper D): src/client/LobbyUi.luau (+ edits to init.client.luau, Ui.luau, CameraDirector.luau)
Listens `LobbyUpdate`. HUD: coins + wins top-left (small, phone safe). Prompts: client listens ProximityPromptService.PromptTriggered,
name "GachaPrompt" -> gacha screen, "StorePrompt" -> cars screen (list all cars, owned vs locked with rarity, no buying).
Gacha screen: SHOW ODDS (from `Gacha.oddsTable()`) and price BEFORE the button, button disabled when `Gacha.canBuy` false, reveal result popup (car name, NEW or "duplicate +N coins").
"choices": 3 big buttons with car name + blurb + rarity, countdown timer, sends `LobbyAction("pickCar", id)`.
"countdown": big number. "toLobby": hide match UI, camera back to Custom, show lobby HUD. Match end screen has NO play-again button now (server returns you).
All touch buttons >= 56px, UIScale/relative sizes, no tiny text. Rate limited clicks (debounce).

## Rules for every helper
- Only edit files you own. Do NOT commit/push, do NOT call mcp__hearthbot__ tools. Coordinator commits.
- Tools: `export PATH=/tmp/tools:$PATH` then `lune run tests/run`, `stylua src tests`, `selene src` (selene std may not generate; skip if it fails and say so).
- `--!strict` Luau, tabs (stylua), no `_G`, server decides everything. Unit tests per piece in tests/<name>.test.luau; add your require line to tests/run.luau (one line each, append only).
- When done: append a short "## Lobby: <your part>" section (what exists, how to tweak) to the END of SNAPSHOT.md and HANDOFF.md using `cat >> file <<'EOF'` (append only, never rewrite those files).
- Final answer: 5 lines max: files, tests added + pass count, anything not verified.
