--!strict
-- Auto-aim helpers (pure, unit tested): weapons curve a little toward the enemy, and only when
-- the enemy is already roughly in front. Directions are flat (x, z) vectors.

local BattleAim = {}

-- Turns the unit direction (dx, dz) toward the target direction (tx, tz) by at most `maxRad`,
-- but only when the target is within `coneRad` of the heading. Returns the new unit direction.
function BattleAim.curve(
	dx: number,
	dz: number,
	tx: number,
	tz: number,
	maxRad: number,
	coneRad: number
): (number, number)
	local tl = math.sqrt(tx * tx + tz * tz)
	local dl = math.sqrt(dx * dx + dz * dz)
	if tl < 1e-6 or dl < 1e-6 then
		return dx, dz
	end
	dx, dz, tx, tz = dx / dl, dz / dl, tx / tl, tz / tl
	-- signed angle from the heading to the target (positive = counterclockwise)
	local ang = math.atan2(dx * tz - dz * tx, dx * tx + dz * tz)
	if math.abs(ang) > coneRad then
		return dx, dz
	end
	local turn = math.clamp(ang, -maxRad, maxRad)
	local c, s = math.cos(turn), math.sin(turn)
	return dx * c - dz * s, dx * s + dz * c
end

-- A steering value (-1..1, + = left) that nudges a straight charge toward a foe that is
-- `angle` radians off the nose (+ = foe on the left), only inside `coneRad`; `strength` is the most it steers.
function BattleAim.chargeTurn(angle: number, coneRad: number, strength: number): number
	if math.abs(angle) > coneRad or coneRad <= 0 then
		return 0
	end
	return math.clamp(angle / coneRad, -1, 1) * strength
end

return BattleAim
