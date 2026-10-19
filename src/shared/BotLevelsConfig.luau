--!strict
-- Numbers for the three bot levels. Change freely; BotLevels.luau only reads these.
-- noiseDeg: launch aim error (random in -x..x degrees). powerMin/powerMax: launch power range 0..1.
-- turnGainMult: multiplies how sharply the bot steers. speedMult: multiplies its top speed.
-- wanderEvery/wanderDeg/wanderFade: every N seconds the aim is knocked off by up to wanderDeg
--   degrees, fading out over wanderFade seconds (0 = never wanders).
-- runUpMult: how often it backs off for a run-up (higher = sooner and more often).
-- rewardMult: coin reward multiplier (read through BotLevels.rewardMultiplier).
-- lead: 0..1, how well it aims where the enemy is going once a chase drags on (0 = never).
-- moveUse: 0..1, how often the bot takes a good chance to boost or use its ability.
export type Entry = {
	noiseDeg: number,
	powerMin: number,
	powerMax: number,
	turnGainMult: number,
	speedMult: number,
	wanderEvery: number,
	wanderDeg: number,
	wanderFade: number,
	runUpMult: number,
	rewardMult: number,
	moveUse: number,
	lead: number,
}

local Config = {
	Names = { "easy", "medium", "hard" },
	Default = "medium",
	-- Auto level while the bot button is hidden: total wins under easyUnder = easy, under mediumUnder = medium, else hard.
	AutoScale = { easyUnder = 3, mediumUnder = 15 },
	-- Same idea by PLAYER LEVEL (what the fight uses): bots get harder as you level up. PLACEHOLDER.
	LevelScale = { easyUnder = 3, mediumUnder = 9 },
	-- A player's first N finished matches always get the easy bots, in every mode, even if they
	-- picked a harder level. PLACEHOLDER.
	FirstMatchesEasy = 2,
	Levels = {
		easy = {
			noiseDeg = 28,
			powerMin = 0.4,
			powerMax = 0.8,
			turnGainMult = 0.55,
			speedMult = 0.8,
			wanderEvery = 3,
			wanderDeg = 40,
			wanderFade = 0.9,
			runUpMult = 0.6,
			rewardMult = 0.8,
			moveUse = 0.2,
			lead = 0.25,
		},
		medium = {
			noiseDeg = 10,
			powerMin = 0.6,
			powerMax = 1,
			turnGainMult = 1,
			speedMult = 1,
			wanderEvery = 0,
			wanderDeg = 0,
			wanderFade = 1,
			runUpMult = 1,
			rewardMult = 1,
			moveUse = 0.65,
			lead = 0.4,
		},
		hard = {
			noiseDeg = 3,
			powerMin = 0.85,
			powerMax = 1,
			turnGainMult = 1.8,
			speedMult = 1.2,
			wanderEvery = 0,
			wanderDeg = 0,
			wanderFade = 1,
			runUpMult = 1.5,
			rewardMult = 1.3,
			moveUse = 1,
			lead = 0.5,
		},
	} :: { [string]: Entry },
}

return Config
