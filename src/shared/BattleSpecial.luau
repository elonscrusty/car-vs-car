--!strict
-- The special move energy bar (pure, unit tested). Hitting the foe fills it; when it is full the
-- SPECIAL button glows and one press spends all of it.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local BattleConfig = sibling("BattleConfig")

local BattleSpecial = {}

-- New energy (0..1) after dealing `damage` HP of damage.
function BattleSpecial.gain(energy: number, damage: number): number
	return math.clamp(energy + math.max(0, damage) * BattleConfig.Special.energyPerDamage, 0, 1)
end

function BattleSpecial.ready(energy: number): boolean
	return energy >= 1 - 1e-6
end

return BattleSpecial
