--!strict
-- Numbers for the three bot levels. Change freely; BotLevels.luau only reads these.
-- noiseDeg: launch aim error (random in -x..x degrees). powerMin/powerMax: launch power range 0..1.
-- turnGainMult: multiplies how sharply the bot steers. speedMult: multiplies its top speed.
-- wanderEvery/wanderDeg/wanderFade: every N seconds the aim is knocked off by up to wanderDeg
--   degrees, fading out over wanderFade seconds (0 = never wanders).
-- runUpMult: how often it backs off for a run-up (higher = sooner and more often).
-- rewardMult: coin reward multiplier (read through BotLevels.rewardMultiplier).
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
}

local Config = {
	Names = { "easy", "medium", "hard" },
	Default = "medium",
	-- Auto level while the bot button is hidden: total wins under easyUnder = easy, under mediumUnder = medium, else hard.
	AutoScale = { easyUnder = 3, mediumUnder = 15 },
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
		},
		hard = {
			noiseDeg = 3,
			powerMin = 0.85,
			powerMax = 1,
			turnGainMult = 1.4,
			speedMult = 1.1,
			wanderEvery = 0,
			wanderDeg = 0,
			wanderFade = 1,
			runUpMult = 1.8,
			rewardMult = 1.3,
		},
	} :: { [string]: Entry },
}

return Config
