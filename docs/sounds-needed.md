# Sounds carter must supply

The game has a full sound system, but every id is EMPTY, so it is silent. Nothing breaks until you fill them.
Where: `src/shared/SoundConfig.luau`, field `id` of each event. Format: `"rbxassetid://123456789"`.
Use ONLY sounds from the Roblox licensed audio library (Creator Store > Audio, free/licensed to all experiences). Do not guess ids; test each in Studio first.
Style for all: short, cheerful, kid friendly, cartoon. No screaming, swearing, gore or scary tones.
Volume and pitch wobble live in the same file (`volume`, `pitchVariance`), so a too-loud sound is fixed there.

**Start with these four (they matter most, do them first):**

| Priority | Event | When it plays | What it should sound like |
|---|---|---|---|
| 1 | ballKick | your car or any car kicks the ball hard (soccer) | punchy rubber "thump" / ball whack, under 0.4 s |
| 2 | goal | a goal is scored (either team) | big cheer + horn burst or happy "GOAL" sting, ~1.5 s (must fit in 2.5 s) |
| 3 | boost | BOOST button | quick "whoosh" with a little rocket fizz, ~0.5 s |
| 4 | click | every menu / UI button | tiny "pop" or soft tick, under 0.15 s |

Full list (boost and click repeat from above):

| Event | When it plays | What it should sound like |
|---|---|---|
| hitSoft | a light car bump | soft "bonk" / rubber thud, under 0.4 s |
| hitHard | a big crash (strength 0.5 and up) | punchy cartoon "BOOM-crunch", under 0.7 s |
| boost | BOOST button | quick "whoosh" with a little rocket fizz, ~0.5 s |
| ability | ABILITY button | magical "zap" / power-up sparkle, ~0.6 s |
| win | you win the match | happy short fanfare, 1-2 s |
| lose | you lose the match | gentle "aww" / sad trombone (soft, not harsh), 1-2 s |
| click | every menu / UI button | tiny "pop" or soft tick, under 0.15 s |
| claw | claw machine prize result | cheerful "ta-da" prize jingle or arcade win chime, ~1 s |
| coin | coin reward after a match | classic coin "ka-ching" / "bling", under 0.5 s |
| ballKick | kick on the ball, strong hits only (see priority list) | punchy rubber "thump" / ball whack, under 0.4 s |
| goal | a goal is scored | big cheer + horn burst, ~1.5 s |
| countdownTick | each "3", "2", "1" of the kickoff countdown | short clean "tick" / beep, under 0.2 s |
| countdownGo | the "GO!" after the countdown | higher, brighter "ding" or start horn, ~0.4 s |
| engineLoop | your car's engine, looped; the pitch rises with speed | small cartoon engine hum, seamless loop, 2-4 s |
| skid | your car starts a drift | short tire "screech", under 0.6 s |
| land | a car lands after a ramp jump | soft "thump" with a little suspension squeak, under 0.4 s |
| wreck | the final blow (K.O.) | big cartoon explosion, ~1.5 s, not scary |
| ramCharge | the Ram starts a charge | engine rev + "whoomp", ~0.5 s |
| cannonFire | the Cannon fires | cartoon cannon "thoomp", under 0.5 s |
| sawRev | the Saw's rev dash | buzzy saw rev-up, ~0.6 s |
| boost | (also) the BOOST button in a fight | quick "whoosh" with a little rocket fizz, ~0.5 s |
| music_lobby | looping in the lobby | relaxed upbeat loop, seamless, 60+ s, no vocals |
| music_arena | looping during the fight | faster energetic racing loop, seamless, 60+ s, no vocals |

That is 22 ids (20 effects, 2 music loops). Hit sounds (hitSoft, hitHard), countdown and win/lose are also used in the 1v1 fight. The two music ones must be seamless loops.

Players can switch music off with the MUSIC button in the lobby menu (remembered only until they rejoin; effects stay on).
