--!strict
-- A car's simple "power score" (pure): a weighted sum of its stats. Used by tests (and tuning) to
-- keep every car roughly as strong as the others of its rarity. Weights live in CarConfig.

local CarPower = {}

export type Stats = {
	hp: number,
	mass: number,
	maxSpeed: number,
	accel: number,
	turnRate: number,
	damageMult: number,
}

function CarPower.score(stats: Stats, weights: { [string]: number }): number
	return stats.hp * weights.hp
		+ stats.mass * weights.mass
		+ stats.maxSpeed * weights.maxSpeed
		+ stats.accel * weights.accel
		+ stats.turnRate * weights.turnRate
		+ stats.damageMult * weights.damageMult
end

-- Average score of a list of stats (0 for an empty list).
function CarPower.average(list: { Stats }, weights: { [string]: number }): number
	if #list == 0 then
		return 0
	end
	local sum = 0
	for _, s in list do
		sum += CarPower.score(s, weights)
	end
	return sum / #list
end

return CarPower
