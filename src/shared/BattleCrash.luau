--!strict
-- Crash damage between the two cars (pure, unit tested). A plain crash hurts the car that gets
-- hit, by how fast the OTHER car was driving into it, so the faster car wins the shove. Five
-- full-speed crashes empty a car's HP (BattleConfig.Crash). Walls never hurt.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local BattleConfig = sibling("BattleConfig")

local BattleCrash = {}

-- Damage to the victim. `speedToward` = how fast the other car was moving toward it (studs/s,
-- before the crash); `cruise` = that car's cruising speed (studs/s).
function BattleCrash.damage(
	victimMaxHp: number,
	speedToward: number,
	cruise: number,
	massScale: number?
): number
	local C = BattleConfig.Crash
	local frac = math.clamp(speedToward / math.max(cruise, 1e-6), 0, 1)
	if frac < C.minSpeedFrac then
		return 0
	end
	return math.max(1, math.floor(victimMaxHp / C.hitsToKill * frac * (massScale or 1) + 0.5))
end

-- A heavy car hits harder than a light one: damage share by the attacker's weight over the victim's.
function BattleCrash.massScale(attackerDensity: number, victimDensity: number): number
	local C = BattleConfig.Crash
	local ratio = attackerDensity / math.max(victimDensity, 1e-6)
	return math.clamp(ratio ^ C.massPower, C.massMin, C.massMax)
end

-- Share of the full crash damage for the Nth crash in a chain (0 = first). Holding the gas into the other
-- car bounces and re-hits every moment; later hits of the chain hurt less so it cannot empty the HP bar.
function BattleCrash.chainScale(chain: number): number
	local scales = BattleConfig.Crash.chainScales
	return scales[math.clamp(chain + 1, 1, #scales)]
end

-- How fast something moving with velocity (vx, vz) goes toward a point in direction (dx, dz).
function BattleCrash.speedToward(vx: number, vz: number, dx: number, dz: number): number
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 1e-6 then
		return 0
	end
	return math.max(0, (vx * dx + vz * dz) / len)
end

-- True when a car's middle is past the arena walls or has dropped below the floor. The walls are
-- a box (halfX, halfZ), or a circle round the middle when `radius` is given (the bowl).
function BattleCrash.outside(
	localX: number,
	localZ: number,
	heightAboveFloor: number,
	halfX: number,
	halfZ: number,
	radius: number?
): boolean
	if radius then
		return localX * localX + localZ * localZ > (radius + 2) ^ 2 or heightAboveFloor < -4
	end
	return math.abs(localX) > halfX or math.abs(localZ) > halfZ or heightAboveFloor < -4
end

-- How hard a crash hit looks (0..1): grows with the damage as a share of the car's HP (20% = full).
function BattleCrash.power(damage: number, maxHp: number): number
	if maxHp <= 0 then
		return 0
	end
	return math.clamp(damage / (0.2 * maxHp), 0, 1)
end

return BattleCrash
