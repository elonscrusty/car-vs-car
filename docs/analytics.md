# Analytics (review item M3)

Code: `src/server/Telemetry.luau` (sends), `src/shared/TelemetryRules.luau` (pure rules), `src/shared/TelemetryConfig.luau` (step names, event schema, caps). Tests: `tests/telemetry.test.luau`.

Roblox only accepts these events from the server of a PUBLISHED game, so nothing shows from Studio (Telemetry is a no-op there). Dashboard: Creator Hub > Analytics > Funnels (onboarding funnel) and Custom Events. Custom events can take up to 24 h to appear.

API used (checked against the Roblox docs on 2026-10-18):
- `AnalyticsService:LogOnboardingFunnelStepEvent(player, stepNumber, stepName)`
- `AnalyticsService:LogCustomEvent(player, eventName, value?, customFields?)`; `customFields` keys are `Enum.AnalyticsCustomFieldKeys.CustomField01..03` names, values must be strings. The custom-events docs page does not print the full signature; the field-key rule is from the custom-fields page. Check the first events on the dashboard after publishing.

## Onboarding funnel (only the first log of a step per player counts)

Step numbers changed in the audit update (two steps inserted): nothing had been published with the old numbers. Do not renumber again after the first publish.

| Step | Name | Fires when | Where (hook) | If the drop is bad | Action |
|---|---|---|---|---|---|
| 1 | joined | player joins | `init.server` onPlayerAdded | n/a (baseline) | n/a |
| 2 | first_input | first steer/move input of the visit (`Telemetry.firstInput`) | NOT WIRED YET (needs a call where the steer/move remote arrives) | 1 to 2 big drop: players do not start playing | clearer first screen |
| 3 | stepped_on_pad | server accepts the pad join | `LobbyService` pad join | 2 to 3 big drop: players do not find the pad | bigger arrow, auto-walk camera, hide menu |
| 4 | launched | player sends a valid launch (group modes: match start) | `Match` launch, `Telemetry.matchStarted` | 3 to 4 drop: countdown/pick/aim confuses | skip pick when 1 car, auto-launch sooner |
| 5 | first_hit | first damage in the match | `Match` / `GroupMatch` resolveHit | slow or low: bowl too big, bots passive | shrink bowl, raise bot aggression |
| 6 | first_score | first goal (soccer), tag (tag) or finish (race) of the visit (`Telemetry.firstScore(player, kind)`) | NOT WIRED YET (needs a call from GroupMatch on goal/tag/finish) | 4 to 6 drop: players never score | bot ease, ball/camera readability |
| 7 | finished_first_match | player stays through the end screen | `init.server` onFinished | 6 to 7 drop: quitting mid-fight (see quit_during_match) | shorten fight, check HP/damage |
| 8 | saw_end_screen | win/lose screen goes up | `init.server` onEndScreen | near 0 is normal | n/a |
| 9 | started_second_match | player's 2nd match starts | `init.server` startMatch | 7 to 9 low: fight not fun or no hook | check hit feel/sound, test the rematch prompt |
| 10 | opened_claw | first claw pull (server only sees the pull, not the menu opening) | `LobbyService` buyGacha | low: collection hook unseen | move the claw nearer the pad, check price/odds |

## Custom events

| Event | Value | Fields (CustomField01..03) | Fires when | If the number is bad | Action |
|---|---|---|---|---|---|
| match_end | seconds | mode, won, vs_bot | player finishes a match (stayed through end screen) | match length too short or too long; won rate far from ~50% (vs_bot false) or very low vs bots | tune HP and damage; bot level |
| time_to_first_hit | seconds | mode | first damage of a match, seconds since launch | average over 10 s: bowl too big or bots passive | shrink bowl, bot aggression |
| claw_pull | none (counter) | source (claw; anything else is "other") | a claw pull is accepted | low share of players pulling: weak hook; very high: coins too easy | check odds, prices, coin rewards |
| rematch_tapped | none | mode (the mode just played) | player taps rematch | low vs matches finished: rematch prompt missed or fight not fun | prompt placement, hit feel/sound |
| quit_during_match | seconds | mode | player leaves while a match is running (before the end screen) | high count, or quits at a similar second: confusing or frustrating moment | watch the seconds; fix that phase (aim, long fights, a mode) |
| mode_picked | none (counter) | mode (auto, duel, hill, ice, soccer, tag, race, lastStanding; anything else is logged as "other") | player picks a mode with the lobby MODE button | share per mode: which modes people choose; "other" above 0 means a wrong name is being sent | check the MODE button wiring; consider which modes to promote |
| left_match | seconds (since the match started, 0 before it starts) | phase (pad, pick, aim, fight, end; anything else is "other") | player taps LOBBY to leave a match | many in aim/fight: match is confusing or too long; many in end: end screen too slow; compare with quit_during_match | fix the phase that loses players |
| match_result | seconds | mode, place, score | match end, only when the caller passes a result: `Telemetry.matchEnded(player, won, result)`; place from `result.place`, score = `result.goals` (soccer) or `result.tags` (tag); empty text if missing | win/place spread per mode, goals per match | bot level, rewards by place |
| tag_survived | seconds | mode | match end, only when `result.survivedSeconds` is given | short average: IT too hard to escape | fuse length, tag-back time |
| first_score | seconds since match start | mode, kind (goal, tag, finish) | first goal/tag/finish of the visit | time of first goal over ~60 s: bots/ball/camera | soccer bot ease, ball size |
| first_input | seconds since join | none | first steer/move input | over ~30 s: slow start | onboarding |
| quit_after_elimination | seconds since elimination | mode | player leaves after `Telemetry.eliminated(player)` and before the match ended | many quits shortly after elimination: dead time (tag) | spectate / instant rematch |
| car_acquired | none (counter) | source (claw, store) | `Telemetry.carAcquired(player, source)` | share claw vs store | prices and odds |

mode_picked and left_match are only sent once the server calls `Telemetry.modePicked(player, mode)` and `Telemetry.leftMatch(player, phase)` from the MODE and LOBBY handlers (the lobby and server code, not Telemetry itself).

Time to first hit is measured from the player's own launch; in a 2-player match the first hit is counted from each player's launch, so a slow partner inflates it a little.

## Safety and numbers

- Each send is deferred (`task.defer`) inside `pcall`: errors or an API change cannot stop a match.
- Global cap per server: `TelemetryConfig.RateLimit` (200 events per 60 s) is a PLACEHOLDER; Roblox does not publish its limit. Events over the cap are dropped.
- Field text is stripped to letters, digits, space and `_-:.`, max 40 chars; values clamped to 0 to 86400.
- Roblox limit: 100 custom events per game (we use 14). Renaming a funnel step in the config starts a new dashboard step.
- Skipped steps are auto-completed by Roblox; repeated steps only count once but still use the rate limit, so we log each step once per player per visit.

## Measurement plan (audit section G)

What to read for each question. "Wired" = the event is sent today; "needs wiring" = the `Telemetry` function exists and is tested, but nobody calls it yet (the caller is in `init.server`, `GroupMatch` or `LobbyService`, files other helpers own).

| Measure | What it tells you | Event / funnel | Status |
|---|---|---|---|
| Time from join to first input | how quickly fun starts | `first_input` (value = seconds), funnel step 2 | needs wiring: `Telemetry.firstInput(player)` on every steer/move |
| Joined, stepped on a pad, first goal/tag/finish (funnel drop) | where players get lost | funnel steps 1, 3, 6 (`joined`, `stepped_on_pad`, `first_score`) | steps 1 and 3 wired; `first_score` needs `Telemetry.firstScore(player, "goal" / "tag" / "finish")` |
| First-match result (win/place) and quit after it | whether the first loss kills interest | `match_end` (won), `match_result` (place), `finished_first_match` | `match_end` wired; place needs the result passed to `matchEnded` |
| Matches per session, consecutive same-mode rematches | "one more round" | `started_second_match`, `rematch_tapped` with `mode` | wired (mode field added); compare with `match_end` mode |
| Per-mode rematch and quit-during-match rate | which modes to keep | `rematch_tapped` / `match_end` per `mode`; `quit_during_match` per `mode` | wired |
| Time of first goal and goals per match (soccer); time stuck (race); dead time after elimination (tag) | pacing and bot quality | `first_score` seconds, `match_result` score, `quit_after_elimination` seconds, `tag_survived` | needs wiring: `firstScore`, result with `goals`/`tags`/`survivedSeconds`, `Telemetry.eliminated(player)`. Race "stuck" time is not measured. |
| Claw pulls per player and share of cars from claw vs store | whether collecting is the hook | `claw_pull` (source), `car_acquired` (source) | claw_pull wired (source "claw"); `car_acquired` needs wiring at the claw reveal and the store buy |
| Coins per minute by mode | reward fairness | not an event: `match_end` seconds and mode, with the coin payout from `docs/economy-report.md` | derive; no coin event sent |
| Next-day and day-7 return | whether anything pulled players back | Roblox Retention page (no code) | n/a |
| Save-warning impressions (`ProfileUnsaved`) | reliability | not sent today. The attribute is set by `Profiles`; a server log line "[Profiles] ... UNSAVED" marks each case | not an event |

The result passed to `Telemetry.matchEnded(player, won, result)` is read defensively: `place`, `goals`, `tags`, `survivedSeconds`, all optional numbers. A wrong type or a missing field just leaves that field empty.
