# Lobby polish, tutorial and props (carter's tap picks, 2026-10-20)

Source: carter tapped these on cards (relayed by the coordinator). The lobby base spec is
`docs/LOBBY_SPEC.md`; where a pick below disagrees with it, THIS file wins. Picks are numbered as
carter saw them (L1..L60). Models are made by Claude from code (Parts), never imported.

## Tutorial and guiding (L1-L20)
- L1 Glow path: a glowing line on the ground leads new players to PLAY (replaces the old arrow).
- L2 Teaching = plain text boxes and arrows. No character.
- L3 Shows once on first join, has a Skip button, can be replayed from Settings.
- L4 Practice drive: new players drive the Ram on a small track and smash a few boxes before the first fight. No bot.
- L6 The practice track is a separate area: players are sent there and come back to the lobby after.
- L7 Standing on a PLAY pad = just wait on the waiting screen. No driving while waiting.
- L8 Calm lobby: no bouncy pads, no kickable cones, no honking cars.
- L9 Sunny day, bright blue sky, no day/night cycle.
- L10 Finishing the tutorial gives a small coin gift (well under one 120-coin pull), granted on the server once per player.
- L11 Short: about 1 minute, basics only.
- L12 Drive only: the attack button is not taught. Boxes are smashed by driving into them.
- L13 The practice track looks like a small Wreck City junkyard.
- L14 Tutorial only: nobody goes back to the track later, so no portal in the lobby.
- L15 Words show in a small bubble next to the button they talk about. The screen middle stays clear.
- L16 Skip shows right away.
- L17 Match the device: phone players see phone buttons, PC players see keys.
- L18 The tutorial walks players to the gumball (glow path) and shows how pulls work.
- L19 Basics only: no special move or horn steps.
- L20 If a new player leaves mid-tutorial it never shows again (Settings replay still works).

## Props and look (L21-L50)
- L21 Plain wooden park benches. L49 Nobody can sit on them.
- L22 Rainbow cones in many bright colors (not orange). Cones stay rainbow even though props match their building (L40).
- L23 The parked cars are the real game cars you can win from the gumball. L24 On slowly spinning car-show stands.
- L25 Big bright billboards. L26 They show short game tips (for example HIT FROM THE SIDE).
- L27 No street lamps.
- L28 A few colorful cartoon junk piles of old car parts at the edges.
- L29 Stacks of bright tires. L30 A chain fence round the lobby edge.
- L31 Round puffy cartoon trees. L32 No flowers or bushes. L48 Puffy cartoon clouds in the sky.
- L33 The ground is dark road with bright painted lines. L34 The ground paint is black tire skid marks (not race stripes).
- L35 No gas station. L37 No flags or banners. L38 No statue.
- L36 Tool props by the Customize garage (toolboxes, car jacks, wrench racks).
- L39 Chunky toy-size props, a bit bigger and rounder than real life.
- L40 Each prop's color matches the building near it (cones stay rainbow).
- L41 Make the lobby smaller: a shorter walk from spawn to PLAY and the gumball.
- L42 Players spawn facing the PLAY pads. L43 Walking is a bit faster than normal Roblox.
- L44 The PLAY pads stay a glowing ring, like now but nicer.
- L45 When a player is found, go to the fight right away (no 3-2-1 on the pad). The fight's own VS screen and 3-2-1-GO stay.
- L46 The waiting screen shows Cancel plus a short game tip. (Pad matching and waiting screen belong to the "New lobby from picture" thread.)
- L47 The leaderboards move to near the spawn.
- L50 Everyone nearby sees a gumball pull (the machine shakes and drops a ball).
- L51 A rare pull shows a small message at the top of the screen for the whole server.
- L52 Phones stay smooth: watch the part count, keep props cheap.

## Tutorial flow details (L53-L60)
- L53 The glow path is GREEN (not the old arrow, not orange).
- L54 Each finished step gets a green check and a small confetti burst.
- L55 No sign at spawn: no big CAR VS CAR sign where players land.
- L56 The practice yard has no ramps. Flat ground, junkyard look.
- L57 Practice ends after 3 boxes are smashed.
- L58 After practice the player lands at the normal lobby spawn.
- L59 The blue portal to the practice yard shows only to tutorial players (client side only).
- L60 Practice ends by itself, or when the player taps Skip. There is no EXIT button.

## Flow
welcome bubble -> blue portal (tutorial players only) -> practice drive (3 boxes) -> land at normal
spawn -> green glow path to the gumball (shows how a pull works) -> green glow path to PLAY ->
saved as seen. The flag is saved when the tutorial STARTS, so leaving half-way never shows it again.
The coin gift (about 30 coins) is granted by the server once per player, when the tutorial ends.

## Order of work
Props first (L5), then the tutorial, then the practice yard, then the layout shrink.

## Status (2026-10-20 night, after PR 204, 213, 215-217, 220 and 221)

IN = built and tested on the fake Roblox. SEEN = also seen in real Studio pictures (PR 204, in
`/mnt/project-files/car-vs-car/review/lobby204/`). TUTORIAL = built and tested, not seen in Studio yet.
OTHER = belongs to the "New lobby from picture" thread; not changed here.

| Pick | State | Where |
|---|---|---|
| L1 | IN, TUTORIAL | `client/GuideTrail` green line (floats 0.85 above the floor); tests `tutorialworld`, `tutorialclient` |
| L2 | IN, TUTORIAL | `client/TutorialUi`: text bubble, ring, arrow; no character |
| L3 | IN, TUTORIAL | `Tutorial.isNew`, `TutorialRules.markStart`, SKIP pill, Settings row SHOW THE TUTORIAL (`ChampionsAdapter`) |
| L4 | IN, TUTORIAL | `client/PracticeClient`, `PracticeCar` (Ram), `shared/PracticeYard`; no bot |
| L5 | IN | order of work: props (PR 204) before the tutorial (PR 213) |
| L6 | IN, TUTORIAL | yard at (-6000, 40, 0); `server/TutorialService` parks the character, `PracticeClient` fades in and out |
| L7 | OTHER | PLAY pad queues for the 1v1 (`BattleService`); waiting screen is not mine |
| L8 | IN, SEEN | cones look-only, no seats, no bounce pads (`tests/lobbyprops`) |
| L9 | IN, SEEN | `server/Atmosphere`: ClockTime 14, no cycle; blue sky and clouds seen |
| L10 | IN | `TutorialConfig.giftCoins = 30`, paid once by the server, not sooner than 20 s after the start |
| L11 | IN, not timed | 3 boxes, two short walks, hard stop at 150 s; the real time needs a person to measure |
| L12 | IN, TUTORIAL | gas and steer only, no attack button |
| L13 | IN | `shared/PracticeYard` junkyard (its look will follow the new art style) |
| L14 | IN | the portal is built on the new player's screen only and removed after |
| L15 | IN, SEEN (tutorial run) | `shared/BubbleLayout`: beside the button, never over the screen middle, and off the other buttons (`avoid`, `tests/bubblelayout`, `tutorialui`) |
| L16 | IN | SKIP pill from the first bubble |
| L17 | IN | `TutorialConfig.text`: phone words and PC keys |
| L18 | IN, TUTORIAL | green line to the gumball, then tap, pull, confirm, reveal, close |
| L19 | IN | no special move or horn steps |
| L20 | IN | flag saved at the START; Settings replay works, no second gift |
| L21, L49 | IN, SEEN | wooden benches, plain parts, never seats |
| L22 | IN, SEEN | rainbow cones, look-only (colors will follow the new art style) |
| L23, L24 | IN, SEEN | `LobbyParking`, `LobbyCarModels`: real game cars on slowly spinning stands |
| L25, L26 | IN, SEEN | 4 billboards with true tips |
| L27 | IN | no street lamps (the tire wall keeps its small orange lights) |
| L28, L29, L30 | IN, SEEN | junk piles, tire stacks, chain fence |
| L31, L32, L48 | IN, SEEN | round trees, no flowers or bushes, puffy clouds |
| L33, L34 | IN, SEEN | dark road, painted lines, black skid marks |
| L35, L37, L38 | IN | nothing built; `tests/lobbyprops` lists the forbidden things |
| L36 | IN | toolboxes, jacks, wrench rack, cart by the Customize garage |
| L39, L40 | IN | chunky props; `LobbyProps.accentAt` colors a prop like the nearest building |
| L41 | IN, SEEN | plaza 172 x 126 studs |
| L42 | IN | the spawn looks at the PLAY ring (`tests/lobbybuild`, `lobbylayout`) |
| L43 | IN | `LobbyLayout.walkSpeed = 24` |
| L44 | IN, SEEN | glowing pad rings |
| L45, L46 | OTHER | pad match start and the waiting screen with Cancel and a tip |
| L47 | IN, SEEN | boards beside the front path, near the spawn |
| L50 | IN | `server/GumballAnim` runs on the server, so everyone sees it (`tests/lobbyworkshop`) |
| L51 | IN, TUTORIAL | Epic or better: server announce, `client/RareBanner` (`tests/rarebanner`) |
| L52 | IN | part budget test: lobby under 2300 parts (1965 now) |
| L53 | IN | the line is green |
| L54 | IN | green check and 18 confetti bits per finished step |
| L55 | IN | no sign at the spawn (the arch has none) |
| L56 | IN | flat junkyard, no ramps |
| L57 | IN | `TutorialConfig.boxesNeeded = 3` |
| L58 | IN | back at the normal spawn |
| L59 | IN | client-only portal |
| L60 | IN | the practice ends by itself or on SKIP; no EXIT button |

## Real Studio run of the tutorial (2026-10-20 21:00, Play as a new player, PC keys)

Pictures and notes: `/mnt/project-files/car-vs-car/review/tutorial213/` (`report.md`, 14 pictures). The
run was on the code of PR 215 (e91049a); PR 217, 220 and 221 and the bubble fix below came after.
- Output: no red line, client or server.
- Seen working: the portal bubble; the yard (Hold W, Smash 0/3 to 2/3); back at the spawn with the green
  line (clearly visible on the path and on the plaza, weakest where it crosses the white pad ring);
  Press E at the machine; the claw screen with the free pull; confirm; the new car; the red X; the PLAY
  step; stepping on a pad (coins 0 to 30, then the waiting screen); SKIP inside the yard (truck gone,
  back at the spawn, HUD back); Settings > SHOW THE TUTORIAL (starts again at the portal).
- Found and fixed: the yard camera cut the truck off at the bottom edge at the start (PR 221); the
  "Click again to spin!" bubble stood on the CANCEL button, and the "A new car! Click DONE" bubble on the
  button beside DONE (a bubble now keeps off the other buttons on its screen: tests only, not seen again).
- Not seen: the burst crate, green check and confetti; the gift bubble (it stays 4 s); the rare-pull
  banner (the pull was only Rare); a phone.
- Not mine: the new-car picture on the reveal screen is empty (`src/champions/shared/Assets.luau` has
  no pictures for the three fight cars); the line "PICK A CAR. DRIVE IT AND HIT!" beside PLAY is always on.

Not done or not checked:
- A real phone play of the tutorial buttons, bubble sizes, GAS button and stick; the PC run above is the only real one.
- The Studio helper has still to re-take the yard start and the spin screen with the fixes.
- No sounds yet (no sound ids).
- L7, L45, L46 are owned by the other thread.
- On hold: the texture, color and detail pass. carter dislikes the bright cartoon look and is
  choosing a new art style. Colors live in `LobbyLayout.colors` (and `LobbyProps.billboardColors`),
  so a re-skin is mostly a palette and material swap.
