--!strict
-- Pure special-move math (no Roblox calls so Lune can test it).

local SpecialLogic = {}

-- Seconds left until `readyAt` (0 = ready).
function SpecialLogic.cooldownLeft(readyAt: number, now: number): number
	return math.max(0, readyAt - now)
end

-- 1 at the centre, 0 at `radius` and beyond (linear).
function SpecialLogic.falloff(dist: number, radius: number): number
	if radius <= 0 or dist >= radius then
		return 0
	end
	return 1 - math.max(dist, 0) / radius
end

-- Heavier targets move less: refMass / mass, clamped.
function SpecialLogic.massScale(mass: number, refMass: number, lo: number, hi: number): number
	if mass <= 0 then
		return hi
	end
	return math.clamp(refMass / mass, lo, hi)
end

-- Is the target (tx, tz relative to me) inside the cone around my forward (fx, fz) and in reach?
function SpecialLogic.inCone(
	fx: number,
	fz: number,
	tx: number,
	tz: number,
	reach: number,
	halfAngleDeg: number
): boolean
	local dist = math.sqrt(tx * tx + tz * tz)
	if dist > reach then
		return false
	end
	if dist < 1e-6 then
		return true
	end
	local fl = math.sqrt(fx * fx + fz * fz)
	if fl < 1e-6 then
		return false
	end
	local cosAngle = (fx * tx + fz * tz) / (fl * dist)
	return cosAngle >= math.cos(math.rad(halfAngleDeg))
end

-- Damage multiplier: `mult` while now < expiresAt, otherwise 1.
function SpecialLogic.damageMult(expiresAt: number, now: number, mult: number): number
	if now < expiresAt then
		return mult
	end
	return 1
end

return SpecialLogic
