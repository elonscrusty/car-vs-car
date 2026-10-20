--!strict
-- The first-time tutorial: numbers and words (carter's picks L1-L20 and L53-L60 in
-- docs/LOBBY_POLISH.md). Pure data, so the tests can check every number. Short words, one idea per
-- bubble. Steps: portal -> gas -> steer -> smash (the practice yard) -> gumball machine -> PLAY pad.

local TutorialConfig = {}

-- L10: finishing gives a small coin gift, well under one 120-coin gumball pull. The server pays it
-- once per player, and not sooner than `minGiftSeconds` after the tutorial started.
TutorialConfig.giftCoins = 30
TutorialConfig.minGiftSeconds = 20

-- L57: the practice ends after 3 boxes are smashed.
TutorialConfig.boxesNeeded = 3
-- The practice yard also ends by itself after this long (the server unparks the character a bit later).
TutorialConfig.practiceMaxSeconds = 150
TutorialConfig.serverPracticeGraceSeconds = 20

-- How long the bubbles ask you to try things (seconds of gas, seconds of steering).
TutorialConfig.gasSeconds = 0.6
TutorialConfig.steerSeconds = 0.5
TutorialConfig.steerThreshold = 0.35 -- the wheel must be turned this far (0..1) to count

-- Where the blue portal stands (studs from the lobby origin, on the front path between the spawn and
-- the PLAY pads) and how close counts as "walked in". It is only built on the screens of tutorial
-- players (L59).
TutorialConfig.portal = { x = 0, z = 33, radius = 4.5, enterRadius = 3.4 }

-- The green path leads to a point in front of the gumball machine; the machine's tap prompt works
-- from 40 studs, so "near" is a little closer than that.
TutorialConfig.gumballStop = { x = 0, z = -29 }
TutorialConfig.gumballMachine = { x = 0, z = -60 } -- where the prompt is (the machine body, inside the workshop)
TutorialConfig.gumballNearStuds = 34

-- Seconds a "done" bubble (check + confetti) stays before the next step starts.
TutorialConfig.celebrateSeconds = 1.1
-- Seconds the last bubble (the coin gift) stays.
TutorialConfig.finishSeconds = 4

-- What each step says, for a phone and for a PC (L17). `{n}` and `{total}` are filled in for the box
-- counter. `anchor` tells the bubble where to stand when no button is named (see TutorialUi).
TutorialConfig.text = {
	portal = {
		phone = "Walk into the blue portal!",
		pc = "Press W A S D to walk into the blue portal!",
	},
	gas = { phone = "Hold GAS to drive!", pc = "Hold W to drive!" },
	steer = { phone = "Slide here to steer!", pc = "Press A and D to steer!" },
	smash = {
		phone = "Smash {total} boxes!  {n} / {total}",
		pc = "Smash {total} boxes!  {n} / {total}",
	},
	gumballWalk = {
		phone = "Follow the green line to the gumball machine!",
		pc = "Follow the green line to the gumball machine!",
	},
	gumballTap = {
		phone = "Tap the gumball machine!",
		pc = "Press E at the gumball machine!",
	},
	gumballPullFree = {
		phone = "Tap here! Your first pull is FREE!",
		pc = "Click here! Your first pull is FREE!",
	},
	gumballPull = {
		phone = "Tap here to pull a new car!",
		pc = "Click here to pull a new car!",
	},
	gumballConfirm = { phone = "Tap again to spin!", pc = "Click again to spin!" },
	gumballReveal = { phone = "A new car! Tap DONE.", pc = "A new car! Click DONE." },
	gumballClose = {
		phone = "Tap the red X to go back.",
		pc = "Click the red X to go back.",
	},
	play = {
		phone = "Tap PLAY, or step on a glowing pad!",
		pc = "Click PLAY, or step on a glowing pad!",
	},
	done = { phone = "Great job! You got {coins} coins!", pc = "Great job! You got {coins} coins!" },
	-- the coin gift was not paid (the tutorial was played before, or the server said no)
	doneNoGift = { phone = "Great job!", pc = "Great job!" },
} :: { [string]: { phone: string, pc: string } }

-- The practice yard controls named for the bubbles (UI names, see TutorialUi / PracticeClient).
TutorialConfig.names = {
	gas = "PracticeGas",
	stick = "Stick",
	play = "Play",
	pull = "PullClaw",
	confirm = "ConfirmPurchase",
	revealDone = "RevealDone",
	close = "Close",
}

return TutorialConfig
