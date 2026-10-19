# Playtest checklist

From the launch review (sections 7 and 9). Run these in order, on a private published build. Watch silently; do not help. Afterwards ask only: "What did you do? Would you play again? Who would you invite?"

## Playtest 1: two-device bug hunt (you + 1 friend, one phone, one PC)

Tick each one on BOTH devices.

- [ ] Join: both reach the lobby, see each other, find the pad
- [ ] Fight: a match starts, both can launch and drive, hits land, a winner is shown
- [ ] Coins and XP appear after the match
- [ ] Disconnect mid-match: friend closes the game during the fight. The other player gets a win or a clean end screen (no frozen match, no stuck camera)
- [ ] Rematch with a leaver: one taps REMATCH, the other has left. The waiting player is not stuck on "WAITING..." forever
- [ ] Rejoin: the friend comes back, spawns in the lobby, can start a new match
- [ ] Coins saved: leave and rejoin, coins, wins and car level are what they were
- [ ] A car that drives off the bowl or gets flung high is handled (ring out, no stuck car)
- [ ] Invite a friend button appears after a WIN only and opens the Roblox invite window
- [ ] Both leaderboards (all-time and this week) show, or say "No scores yet"

## Playtest 2: five first-timers, no help, 10 minutes

- [ ] Each reaches a pad within 30 s without being told
- [ ] Time to first hit under about 8 s (stopwatch)
- [ ] Most matches last 30 to 75 s
- [ ] Note every "huh?" moment (write the exact words and the time)
- [ ] How many start a 2nd match? How many open the claw?

## Playtest 3: six at once (crowding)

- [ ] 6 people in the lobby at the same time: pads, bays and boards are not blocked
- [ ] Several matches running together: no lag spikes, frame rate stable
- [ ] Group modes (last standing, soccer) with 2 humans plus bots work
- [ ] Nobody gets stuck in a wall, bay or pad
- [ ] Max Players is set (see docs/store-page.md) and the 7th to 12th person can still join

## Phone check (do on a real phone, not the emulator)

- [ ] Buttons are big enough to tap with a thumb
- [ ] Text is readable at arm's length (HUD, end screen, menus, boards)
- [ ] Nothing covers the middle of the screen during a fight
- [ ] Frame rate feels stable during a 6-car match
- [ ] The end screen buttons (REMATCH, Invite a friend) are not cut off

## Before pressing Publish

- [ ] Human-vs-human ignores level and rarity bonuses
- [ ] Sound: about 8 effects and 1 music loop
- [ ] Title, icon and 3 to 5 real 16:9 thumbnails match the game
- [ ] Carter says "publish" and presses Publish himself
