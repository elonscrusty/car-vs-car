# Analytics (review item M3)

Code: `src/server/Telemetry.luau` (sends), `src/shared/TelemetryRules.luau` (pure rules), `src/shared/TelemetryConfig.luau` (step names, event schema, caps). Tests: `tests/telemetry.test.luau`.

Roblox only accepts these events from the server of a PUBLISHED game, so nothing shows from Studio (Telemetry is a no-op there). Dashboard: Creator Hub > Analytics > Funnels (onboarding funnel) and Custom Events. Custom events can take up to 24 h to appear.

API used (checked against the Roblox docs on 2026-10-18):
- `AnalyticsService:LogOnboardingFunnelStepEvent(player, stepNumber, stepName)`
- `AnalyticsService:LogCustomEvent(player, eventName, value?, customFields?)`; `customFields` keys are `Enum.AnalyticsCustomFieldKeys.CustomField01..03` names, values must be strings. The custom-events docs page does not print the full signature; the field-key rule is from the custom-fields page. Check the first events on the dashboard after publishing.

## Onboarding funnel (only the first log of a step per player counts)

| Step | Name | Fires when | Where (hook) | If the drop is bad | Action |
|---|---|---|---|---|---|
| 1 | joined | player joins | `init.server` onPlayerAdded | n/a (baseline) | n/a |
| 2 | stepped_on_pad | server accepts the pad join | `LobbyService` pad join | 1 to 2 big drop: players do not find the pad | bigger arrow, auto-walk camera, hide menu |
| 3 | launched | player sends a valid launch (group modes: match start) | `Match` launch, `Telemetry.matchStarted` | 2 to 3 drop: countdown/pick/aim confuses | skip pick when 1 car, auto-launch sooner |
| 4 | first_hit | first damage in the match | `Match` / `GroupMatch` resolveHit | 3 to 4 drop or slow: bowl too big, bots passive | shrink bowl, raise bot aggression |
| 5 | finished_first_match | player stays through the end screen | `init.server` onFinished | 4 to 5 drop: quitting mid-fight (see quit_during_match) | shorten fight, check HP/damage |
| 6 | saw_end_screen | win/lose screen goes up | `init.server` onEndScreen | 5 to 6 near 0 is normal | n/a |
| 7 | started_second_match | player's 2nd match starts | `init.server` startMatch | 5 to 7 low: fight not fun or no hook | check hit feel/sound, test the rematch prompt |
| 8 | opened_claw | first claw pull (server only sees the pull, not the menu opening) | `LobbyService` buyGacha | low: collection hook unseen | move the claw nearer the pad, check price/odds |

## Custom events

| Event | Value | Fields (CustomField01..03) | Fires when | If the number is bad | Action |
|---|---|---|---|---|---|
| match_end | seconds | mode, won, vs_bot | player finishes a match (stayed through end screen) | match length too short or too long; won rate far from ~50% (vs_bot false) or very low vs bots | tune HP and damage; bot level |
| time_to_first_hit | seconds | mode | first damage of a match, seconds since launch | average over 10 s: bowl too big or bots passive | shrink bowl, bot aggression |
| claw_pull | none (counter) | none | a claw pull is accepted | low share of players pulling: weak hook; very high: coins too easy | check odds, prices, coin rewards |
| rematch_tapped | none | none | player taps rematch | low vs matches finished: rematch prompt missed or fight not fun | prompt placement, hit feel/sound |
| quit_during_match | seconds | mode | player leaves while a match is running (before the end screen) | high count, or quits at a similar second: confusing or frustrating moment | watch the seconds; fix that phase (aim, long fights, a mode) |
| mode_picked | none (counter) | mode (auto, duel, hill, ice, soccer; anything else is logged as "other") | player picks a mode with the lobby MODE button | share per mode: which modes people choose; "other" above 0 means a wrong name is being sent | check the MODE button wiring; consider which modes to promote |
| left_match | seconds (since the match started, 0 before it starts) | phase (pad, pick, aim, fight, end; anything else is "other") | player taps LOBBY to leave a match | many in aim/fight: match is confusing or too long; many in end: end screen too slow; compare with quit_during_match | fix the phase that loses players |

mode_picked and left_match are only sent once the server calls `Telemetry.modePicked(player, mode)` and `Telemetry.leftMatch(player, phase)` from the MODE and LOBBY handlers (the lobby and server code, not Telemetry itself).

Time to first hit is measured from the player's own launch; in a 2-player match the first hit is counted from each player's launch, so a slow partner inflates it a little.

## Safety and numbers

- Each send is deferred (`task.defer`) inside `pcall`: errors or an API change cannot stop a match.
- Global cap per server: `TelemetryConfig.RateLimit` (200 events per 60 s) is a PLACEHOLDER; Roblox does not publish its limit. Events over the cap are dropped.
- Field text is stripped to letters, digits, space and `_-:.`, max 40 chars; values clamped to 0 to 86400.
- Roblox limit: 100 custom events per game (we use 5). Renaming a funnel step in the config starts a new dashboard step.
- Skipped steps are auto-completed by Roblox; repeated steps only count once but still use the rate limit, so we log each step once per player per visit.
