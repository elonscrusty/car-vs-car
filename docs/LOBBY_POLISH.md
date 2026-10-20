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
