# Analytics

Code: `src/server/Telemetry.luau` (sends), `src/shared/TelemetryRules.luau` (pure rules), `src/shared/TelemetryConfig.luau` (step names, event schema, caps). Tests: `tests/telemetry.test.luau`. Hooks: `BattleService` (fight start, first hit, fight end, quit), `LobbyService` (pad, gumball pull, car acquired), `init.server` (join, leave).

Roblox only accepts these events from the server of a PUBLISHED game, so nothing shows from Studio (Telemetry is a no-op there). In Studio you can only check that there are no errors. Dashboard: Creator Hub > Analytics > Funnels (onboarding funnel) and Custom Events. Custom events can take up to 24 h to appear.

API used: `AnalyticsService:LogOnboardingFunnelStepEvent(player, stepNumber, stepName)` and `AnalyticsService:LogCustomEvent(player, eventName, value?, customFields?)`; `customFields` keys are `CustomField01..03`, values are strings. Check the first events on the dashboard after publishing.

The old soccer, tag, race and group-mode events were removed. Nothing had been published with the old step numbers. Do not renumber again after the first publish.

## Onboarding funnel (only the first log of a step per player counts)

| Step | Name | Fires when | Hook | If the drop is bad |
|---|---|---|---|---|
| 1 | joined | player joins | `init.server` | baseline |
| 2 | stepped_on_pad | server accepts the PLAY pad join | `LobbyService` | players do not find the pad: bigger arrow |
| 3 | launched | the first round of a fight starts | `BattleService.startFight` | pick screen or 3-2-1 confuses or the queue is too long |
| 4 | first_hit | first damage in a fight | `BattleService` | slow or low: map too big, cars cannot find each other |
| 5 | finished_first_match | player stayed to the result of a whole match | `BattleService.settle` | 4 to 5 drop: quitting mid-fight (see quit_during_fight) |
| 6 | started_second_match | player's second fight starts | `BattleService.startFight` | low: fight not fun or no reason to go again |
| 7 | opened_gumball | first gumball pull | `LobbyService` | collection hook unseen: move the machine nearer the pad |

## Custom events

| Event | Value | Fields (CustomField01..03) | Fires when | If the number is bad |
|---|---|---|---|---|
| fight_start | none | car, vs_bot | a fight (whole match) begins | share per car: which cars people pick; vs_bot true should be 0 in a live server |
| fight_end | seconds since fight_start | car, won, rounds | the player stayed to the result | win rate per car far from about 50%: balance; seconds very short: forfeits |
| quit_during_fight | seconds since fight_start | phase (select, prep, fight, result, matchResult, server; else "other") | the player leaves before the match is finished | many quits in one phase or at a similar second: fix that moment |
| time_to_first_hit | seconds since the fight started | car | first damage of a fight | over about 10 s: map too big or cars passive |
| gumball_pull | none (counter) | none | a gumball pull is accepted | few pulls: weak hook; very many: coins too easy |
| car_acquired | none (counter) | source (gumball, store; else "other") | a car is obtained | gumball against store share |
| tutorial_start | none (counter) | first (true = a new player, false = a replay from Settings) | the tutorial begins (`TutorialService`) | few starts for new players: the portal is not found |
| tutorial_practice | seconds in the practice yard | none | the player comes back from the yard, or leaves the game while in it | very long: the boxes or the driving are hard; very short: skipped |
| tutorial_done | seconds since tutorial_start | gift (true = the coin gift was paid) | the tutorial was played to the end (a skip sends nothing) | starts far above dones: it is too long or confusing; look at the practice time first |

## Safety and numbers

- Each send is deferred (`task.defer`) inside `pcall`: errors or an API change cannot stop a match.
- Global cap per server: `TelemetryConfig.RateLimit` (200 events per 60 s) is a placeholder; Roblox does not publish its limit. Events over the cap are dropped.
- Field text is stripped to letters, digits, space and `_-:.`, max 40 characters; numbers are clamped to 0 to 86400.
- Roblox limit: 100 custom events per game (we use 9). Renaming a funnel step starts a new dashboard step.
- Each step is logged once per player per visit.

## Measurement plan

| Question | Read |
|---|---|
| Do people find and finish a fight? | funnel steps 2 to 5 |
| Do they come back for a second fight? | step 6 against step 5 |
| Is the balance fair? | `fight_end` won rate per car (about 40 to 60%) |
| Where do people quit? | `quit_during_fight` phase and seconds |
| Is the gumball machine the hook? | step 7, `gumball_pull`, `car_acquired` source |
| Next-day and day-7 return | Roblox Retention page (no code) |
