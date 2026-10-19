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

## Wave 1 and 2 features (sound, menu unlock, soccer, weekly board, invite)

Sound toggle
- [ ] The sound button mutes music and effects at once and shows the muted state
- [ ] Unmuting brings the lobby music back (not the arena track while in the lobby)
- [ ] The choice is not saved: after a rejoin sound is on again (expected, not a bug)
- [ ] With sound ids empty (placeholders) nothing errors and the toggle does nothing audible

Menu unlock after 2 matches
- [ ] A brand-new player sees only GIFT in the menu bar
- [ ] After the 1st finished match QUESTS and GARAGE are still hidden
- [ ] After the 2nd finished match QUESTS and GARAGE appear (no rejoin needed)
- [ ] A returning player (matches saved at 2 or more) sees the full menu at once
- [ ] Leaving mid match does not count; finishing a match as the loser counts

Car soccer
- [ ] Soccer comes up in the mode rotation and the small field loads with both goals
- [ ] Ball is visible, moves when hit, scores in the right net, resets after the goal pause
- [ ] Score and timer on the HUD match what actually happened; first to the goal limit wins
- [ ] Bots chase the ball and do not all pile into one corner
- [ ] A player who leaves is replaced by a bot; nobody gets forfeited for lag in soccer
- [ ] Match end: field, ball and cars are removed (look at Workspace in Studio test)

Mode button and LOBBY button
- [ ] The lobby shows a MODE button that cycles AUTO, DUEL, HILL, ICE, SOCCER and shows the current choice
- [ ] Pick SOCCER with the MODE button, step on a pad: the soccer field loads (not a duel)
- [ ] Pick each other mode (DUEL, HILL, ICE) once and check the match really is that mode; AUTO still rotates
- [ ] LOBBY button mid-match: you return to the lobby cleanly (no frozen camera, car and arena cleaned up, can start a new match)
- [ ] LOBBY button on the end screen: returns to the lobby right away
- [ ] LOBBY button with a human opponent: the other player gets a win or a clean end, not a stuck match
- [ ] MODE choice with 2 humans on one pad: note which rule applies (one player's pick, or AUTO) and check both see the same mode, in the match banner too
- [ ] Both buttons are reachable on a phone in landscape and do not cover the aim or steer controls
- [ ] Only the 12 launch cars show anywhere (no blocky old cars in the pick, store, garage or claw)

Weekly board
- [ ] Three boards in the lobby: all-time wins, this week, best streak; text readable
- [ ] A win moves the weekly count up within about a minute (board refresh)
- [ ] The weekly board name changes on Monday 00:00 UTC (check with a faked date)
- [ ] The bowl colors for the week match the weekly theme and are not unreadable

Invite
- [ ] After a WIN an Invite a friend button shows; after a loss it does not
- [ ] Tapping it opens Roblox's own friend picker; nothing is sent by the game itself
- [ ] If invites are not allowed for the account the button is simply hidden

Economy feel (see docs/economy-report.md, all prices are pretend)
- [ ] First claw pull is free in the first session; a second pull needs coins or a daily gift
- [ ] A casual player pulls a Rare in the first couple of days and a Legendary within weeks, not hours
- [ ] Duplicates give coins back and the refund text is shown

## Save, claw and payout checks (audit #103, #104, #105; needs a PUBLISHED private place)

Studio cannot save (DataStore needs a published place), so these three run on the published test.

Save and rejoin (#103)
1. Join with a test account. Note coins, wins, and the cars in the garage.
2. Win one match (soccer vs bots is fine). Note coins and wins again.
3. Pull the claw once. Note coins and the car you got.
4. Wait 5 seconds, then press Leave in the Roblox menu (the leave-save runs).
5. Rejoin the same place at once (the same server if possible: join a friend, or rejoin within 10 seconds). Check: same coins, wins and cars as step 3. No "Saving paused" text.
6. Repeat, but leave in the MIDDLE of the claw animation (right after tapping the pull). After rejoin the coins must be down by exactly 100 and the car must be in the garage, or coins unchanged and no car. Never coins gone and no car.
7. Check the Output (server log) for "[Profiles] ... failed" lines. Any "playing UNSAVED" line means the load failed: write down the time.
8. Warning text: "Saving paused. Your coins may not be kept." shows only when the save failed to load; it must NOT show in the normal run.

Double-tap claw (#104)
1. Use an account with exactly 100 coins and its free first pull already used (no daily gift).
2. Tap the pull button 5 times as fast as you can.
3. Expected: one pull. Coins end at 0, or 0 plus a duplicate refund if the car is a duplicate (the refund is less than 100). You get at most one car. The other taps do nothing or show "busy" / "not enough coins".
4. Rejoin: the numbers must be the same. Repeat 3 times.

Two-human soccer payout (#105)
1. Two humans on the same pad, soccer (set MODE to SOCCER), different accounts. Write down both coin and win counts before.
2. Play one full match. One team wins.
3. Check both players after the end screen: each gets ONE payout only (win coins for the winning side, lose coins for the other, plus any progress bonus). Wins +1 only for the winners, matches +1 for everyone.
4. Press REMATCH on both, finish the next match: again one payout each, not two.
5. Have one player leave during the end screen: the other still gets exactly one payout.

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
