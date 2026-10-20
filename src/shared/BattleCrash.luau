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
function BattleCrash.damage(victimMaxHp: number, speedToward: number, cruise: number): number
	local C = BattleConfig.Crash
	local frac = math.clamp(speedToward / math.max(cruise, 1e-6), 0, 1)
	if frac < C.minSpeedFrac then
		return 0
	end
	return math.max(1, math.floor(victimMaxHp / C.hitsToKill * frac + 0.5))
end

-- How fast something moving with velocity (vx, vz) goes toward a point in direction (dx, dz).
function BattleCrash.speedToward(vx: number, vz: number, dx: number, dz: number): number
	local len = math.sqrt(dx * dx + dz * dz)
	if len < 1e-6 then
		return 0
	end
	return math.max(0, (vx * dx + vz * dz) / len)
end

-- True when a car's middle is past the arena walls or has dropped below the floor.
function BattleCrash.outside(
	localX: number,
	localZ: number,
	heightAboveFloor: number,
	halfX: number,
	halfZ: number
): boolean
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
