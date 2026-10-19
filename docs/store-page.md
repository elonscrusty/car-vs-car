# Store page drafts

Honest text only. Describe what is in the game today. Do not mention features that are not built or not on by default. Re-read this against the real game (and `src/shared/FeatureFlags.luau`) before publishing.

Rewritten for audit item #109: the old draft sold "Bowl Battles", a daily spin and a weekly bowl look. Those are off or not the main game. Car soccer is the main mode.

## Title options (pick one)

- Car VS Car
- Car VS Car: Soccer, Tag and Race

(Do not use "Bowl Battles" in the title.)

## Description draft

Drive a toy car, push a giant ball into the goal, and win cars from the claw machine!

Car Soccer is the main game: a small field, a giant ball and two goals. Jump in, steer, boost and use your car's special move to score. Short rounds, instant rematch.

- Car Soccer: bump the giant ball into the other team's goal
- Car Tag: one car is IT. Bump another car to pass it on, and do not be IT when the fuse ends
- Crazy Race: 3 laps over jumps, hit the checkpoints in order
- Also in the rotation: duel, king of the hill and ice bowl fights (use the MODE button to pick a mode, or leave it on AUTO)
- Collect cars with the claw machine; every car has a role and a special move
- Walk around the garages in the lobby and like your favourite
- Win coins and car XP
- Climb the leaderboards: most wins, wins this week, best win streak
- Invite friends after a win

(Delete any line above that is not true on launch day. Not in the game today and not to be mentioned: daily spin, rank badges, paint shop, the weekly bowl look, last car standing.)

## Thumbnail shots to capture (5 real 16:9, 1920x1080)

Take them in the real game, no mock-ups. Keep key content in the top and middle (nothing important at the bottom). Use soccer and race moments first; the lobby alone says nothing about the game.

1. Soccer: a car about to hit the giant ball with the goal behind it (camera at the normal match angle)
2. Soccer: the goal moment, ball in the net, with the goal burst / score banner showing
3. Race: several cars in the air over a jump with the track below
4. Race or tag: a close pack of cars at a checkpoint, or the IT car glowing in tag
5. The claw machine pulling a car, or the garage lobby with the claw in view (the collecting hook)

## Rules for what we sell

- Never sell power or claw pulls for Robux. Cosmetics only (paint, trails, looks).
- No Robux prices or product ids are set in the code; fill them in only when carter decides.
- Nothing on the store page, thumbnails or videos may show a feature the game does not have.

## Max Players (carter must set this; audit #107)

Max Players cannot be set from code. Steps for carter:

1. In Studio: Home > Game Settings > Basic Info (or Players).
2. Set Max Players to 12 (the lobby has 8 garages and 4 pads; use 8 if the 12-player test shows crowding). The old note said 12 to 16: start at 12.
3. Publish, then run the 6-person and 12-person tests in `docs/playtest-checklist.md` before the crowd playtest.
