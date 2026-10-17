--!strict
-- Numbers for weak spots, combos and flying parts. Placeholder values: change freely.

return {
	Zones = {
		-- cos of the angle between the victim's look vector and the direction to the attacker.
		frontCos = 0.5, -- above this = front hit (within 60 degrees of the nose)
		backCos = -0.5, -- below this = back hit (within 60 degrees of the tail)
		frontMult = 1,
		sideMult = 1.5,
		backMult = 2,
	},
	Combo = {
		window = 1.5, -- seconds: a hit this soon after the last one by the same attacker chains
		mults = { 1, 1.25, 1.5 }, -- 1st, 2nd, 3rd (and later) hit of a chain
	},
	Parts = {
		thresholds = { 0.66, 0.33 }, -- HP fractions where parts break off (death breaks the rest)
		fractions = { 0.4, 0.5 }, -- share of the parts still attached that leave at each threshold
		lifetime = 4, -- seconds until debris is removed
		outSpeed = 22, -- studs/s outward kick
		upSpeed = 14, -- studs/s upward kick
	},
}
