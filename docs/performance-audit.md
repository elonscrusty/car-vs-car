# Performance audit (code reading, not profiled)

Scope: `src/server/Lobby*.luau`, `Arena*.luau`, `SoccerArena.luau`, `GroupMatch.luau`, `Match.luau`
plus the helpers they use. Nothing here was measured in Studio: part counts are from reading the
build code and `ArenaLayout`/config counts, rates are from the configs. Verify with the MicroProfiler
and Stats > Network in a 6-player test.

## Ranked findings

### 1. Fixed: a connection per player kept forever (small, real leak)
`LobbyService.luau` stored every player's `CharacterAdded` connection in the shared `conns` list
(old line ~754) and only disconnected it at `stop()`. Each join added an entry that was never
dropped. Fix applied: the connection now lives in `charConns[player]`, is disconnected in
`onPlayerRemoving`, and the rest are cleared in `stop()`. Growth was tiny per player, but it is
unbounded on a long-lived server. No Lune test: it needs Roblox signals, not pure code.

### 2. Per-car `Touched` connections, high event rate (watch, not a leak)
`Match.luau:453` and `GroupMatch.luau:369` connect `Touched` on every colliding part of every car
(cars hold about 5 to 15 parts each). In a pile of 6 soccer cars plus a ball, Touched fires many
times per frame. They are disconnected correctly (`clearCars`, `Match.luau:173`,
`GroupMatch.luau:125`) and the handlers early-out on a hit cooldown (`GameConfig` hitCooldown
0.5 s), so cost is event dispatch only. If lag shows with 6+ cars, connect only on the body part.

### 3. Heartbeat fight loops run physics-heavy work for every car (expected cost)
`Match.luau:672` and `GroupMatch.luau:566`: each frame runs `Autopilot.step`/`stepManual`
(raycasts for ground and steering) for every server-driven car, then the ring-out check. Clients
that drive their own car skip steering and only run `CarSanity.step`. The loops disconnect in
`destroy` (`Match.luau:885`, `GroupMatch.luau:781`) and exit early outside `phase == "fight"`.
Cost is per-match: 2 cars in a duel, up to 8 in last standing. 4 concurrent pads (`LobbyConfig`
padCount 4) means up to 8 cars server-driven in duels, or one big group match.

### 4. Part counts (estimates)
- Duel bowl (`Arena.build`): 48 slope slabs + 48 walls + floor + 2 floor lines = about 99 parts.
  Scenery adds barriers 8, tire stacks 11, cones 14, towers 4, hill props 14, hazard pads 4,
  trees 63, rocks 20, clouds 5 (counts from `ArenaLayout`) = about 143 more. Roughly 240 parts per
  bowl, set `Persistent` streaming (`Arena.luau:44`) so every client receives all of them.
  With four slots live that is about 1000 parts replicated to everyone, including players who are
  only in the lobby. Mitigation if needed: scenery trees/rocks/clouds as non-colliding, anchored,
  `CanTouch=false` (already mostly true), or stream the scenery only.
- Soccer field (`SoccerArena.build`): floor, stripes, lines, 10 walls and lids, goals with net
  panels; likely 60 to 90 parts. Cheap.
- Cars: about 8 to 15 parts each (body plus welded visual).
- Lobby (`Lobby.luau` 1741 lines, `LobbyBays`, `LobbyDecor`, `LobbyProps`, `LobbyShell`,
  `LobbyLife`): 8 garages with runways/ramps (each 4 runway + 4 ramp parts), hall, props and
  signs; likely 1500 to 3000 parts. Static, anchored, never destroyed. Not a growth risk, but the
  main memory baseline. Check `Stats > Memory > PhysicsParts` in Studio.

### 5. Lobby decor loops (steady cost, 20 Hz)
`Lobby.luau:1269` (showcase car spin), `LobbyBays.luau:476` (lifts: moves 4 runways, 4 ramps and
the car per garage, 8 garages, about 80 CFrame writes per tick), `LobbyLife.luau:224` (lift, ring,
beams, lights, sign), `LobbyGarage.luau:84` (spinners). All throttle to 20 Hz (0.05 s) and
disconnect on `folder.Destroying`, except `LobbyBays` which is disconnected by `bays.destroy()`
from `LobbyService.stop` (`LobbyService.luau` ~870). Small allocations: `LobbyBays.luau:490` and
`:494` create `{ -1, 1 }` tables every tick for every garage (16 tiny tables per tick). Replace
with module-level constants if GC shows up in a profile. CFrame writes on anchored parts replicate
at 20 Hz: with 8 garages that is a constant background trickle to every client, about 80 part
updates x 20 per second. If the network is noisy at idle, drop the garage lift to 5 Hz or make
the lift a client-side visual.

### 6. Remote traffic rates
- Steer: client sends when the value changes plus a resend interval
  (`GameConfig.Steer.resendSeconds`), server cap 60 calls/s per player
  (`GameConfig.Remote.steerMaxPerWindow`).
- Launch/Action/Lobby: 6 per 2 s, 8 per 2 s, 6 per 2 s (`init.server.luau:30-35`).
- Server to client: `UiUpdate` is event-driven (hits, ko, countdown); the only periodic senders
  are `modeInfo` for hill (`ModesConfig.Hill.hudSeconds` 0.5 s, `Match.luau:768`) and last
  standing (1 s, `GroupMatch.luau:679`). Fine.
- Pickups (`Pickups.luau:279`) animate at 20 Hz: each live pickup (max 2 per bowl) moves 1 to 3
  parts, 40 to 120 property updates per second per bowl.
- Server-driven car physics replicates automatically; client-driven cars (network owner is the
  driver) avoid that cost for the driver.

### 7. Memory growth sources checked and found clean
- Match end: `destroy` disconnects the fight connection, runs `clearCars` (touch connections,
  car models, buffs), destroys hazards and pickups, and destroys the arena model
  (`Match.luau:882-890`). `GroupMatch.destroy` also destroys the ball and the arena
  (`GroupMatch.luau:778-790`). The entry script calls `destroy` when the last participant leaves
  (`init.server.luau:55-65`) and on `PlayerRemoving` (`init.server.luau:148`).
- Pickups: tweens are cancelled and the model destroyed in `remove` (`Pickups.luau:268-276`);
  `destroy` disconnects Heartbeat.
- Dummy (crash dummy) and Specials sparks use `Debris:AddItem` (`Dummy.luau:82`,
  `Specials.luau:63`).
- Per-player tables (`groups`, `rematch.records`, `Telemetry.active`, `Profiles.states`, limiters,
  `bayKeys`) are all cleared on removal.
- `LobbyBays` like prompts connect once per garage and are disconnected in `destroy`.
- Delayed callbacks (`task.delay` in match end, hit stop) check `destroyed` before touching
  instances, so they cannot resurrect a dead match.

### 8. Leaderboards DataStore budget
`Leaderboards.luau:219-226` refreshes 3 boards every 60 s (3 `GetSortedAsync`/min) and writes once
per win and one gated submit per match (min gap 20 s, `ProgressConfig.Board.minSubmitGap`).
Well inside the DataStore budget for a small server; recheck if many servers run.

## Not done (needs Studio)
Real part counts (`#workspace:GetDescendants()` in a live server), MicroProfiler captures of the
Heartbeat loops, and network KB/s. Open question: does `Persistent` streaming of four bowls hurt
low-end phones? Test on a phone with all four pads busy.

## Phone FPS test procedure (audit #88)

Goal: know the frame rate in a 6-car soccer match on the oldest phone you can borrow.

1. Publish privately (a phone cannot join a Studio test, so it needs the published private place).
2. On the phone: Roblox Settings > Graphics: leave on Automatic first, then repeat once at the lowest quality level.
3. Show FPS: Roblox in-game menu > Settings > Performance Stats (turn on). Read the FPS number during play; if it is not available, record the screen and count with the Roblox stats overlay of a second device.
4. Start a 6-car Car Soccer match (you plus bots, then once with a second human). Play the full round.
5. Write down, for each of: lobby standing still, lobby walking near the 8 garages, soccer match start, soccer pile-up near the ball, goal burst, race start with 6 cars: FPS low and typical, and whether the ball felt late.
6. Test the same with the phone on weak Wi-Fi (or one bar of mobile data) for ball touch accuracy (see audit #101).
7. Pass line to judge against, not a rule: typical 30 FPS or more with no long freezes. If it is lower, reduce in this order: scenery parts, particle counts, the lobby 20 Hz decor loops (finding 5), then Persistent streaming of the four bowls (finding 4).
8. Record the phone model, Roblox version, the numbers and the quality level in the playtest notes.
