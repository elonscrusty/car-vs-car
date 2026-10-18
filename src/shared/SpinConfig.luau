--!strict
-- Daily spin wheel numbers. All rewards and weights are PLACEHOLDERS: change them here only.

export type Segment = {
	label: string,
	weight: number, -- chance is weight / total weight (shown to the player before the spin)
	coins: number, -- coins paid (0 = none)
	freePulls: number, -- free claw tries added to the daily gift pile (0 = none)
}

local SpinConfig = {}

SpinConfig.dayLength = 86400 -- seconds; one free spin per UTC day

SpinConfig.Segments = {
	{ label = "10 coins", weight = 30, coins = 10, freePulls = 0 },
	{ label = "25 coins", weight = 25, coins = 25, freePulls = 0 },
	{ label = "50 coins", weight = 20, coins = 50, freePulls = 0 },
	{ label = "100 coins", weight = 12, coins = 100, freePulls = 0 },
	{ label = "Free claw try", weight = 7, coins = 0, freePulls = 1 },
	{ label = "200 coins", weight = 5, coins = 200, freePulls = 0 },
	{ label = "500 coins", weight = 1, coins = 500, freePulls = 0 },
} :: { Segment }

return SpinConfig
