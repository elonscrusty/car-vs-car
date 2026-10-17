--!strict
-- Small pure rules (no Roblox objects) so they can be unit tested.

local Logic = {}

function Logic.isFinite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function Logic.clamp(n: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, n))
end

-- Checks launch numbers from a client. Returns clamped (angleDeg, power) or nil if junk.
function Logic.sanitizeLaunch(angle: any, power: any, maxAngle: number): (number?, number?)
	if not Logic.isFinite(angle) or not Logic.isFinite(power) then
		return nil
	end
	return Logic.clamp(angle :: number, -maxAngle, maxAngle), Logic.clamp(power :: number, 0, 1)
end

-- Power 0..1 -> speed in studs/sec.
function Logic.launchSpeed(power: number, minSpeed: number, maxSpeed: number): number
	return minSpeed + (maxSpeed - minSpeed) * Logic.clamp(power, 0, 1)
end

-- Power bar: goes 0 -> 1 -> 0 over `period` seconds, repeating.
function Logic.powerAt(t: number, period: number): number
	local phase = (t % period) / period
	if phase < 0.5 then
		return phase * 2
	end
	return 2 - phase * 2
end

-- Damage from one collision. Slow bumps (below minSpeed) do nothing.
function Logic.impactDamage(relSpeed: number, mult: number, scale: number, minSpeed: number): number
	if relSpeed < minSpeed then
		return 0
	end
	return relSpeed * mult * scale
end

-- Returns (newHp, isDead). HP never goes below 0.
function Logic.applyDamage(hp: number, dmg: number): (number, boolean)
	local newHp = math.max(0, hp - dmg)
	return newHp, newHp <= 0
end

-- True when enough time passed since the last counted hit.
function Logic.canHit(now: number, lastHitAt: number, cooldown: number): boolean
	return now - lastHitAt >= cooldown
end

-- Which car is the attacker: speed of car 1 toward car 2 vs car 2 toward car 1.
-- Returns 1 or 2 (ties go to 1).
function Logic.attackerIndex(speed1Toward2: number, speed2Toward1: number): number
	if speed2Toward1 > speed1Toward2 then
		return 2
	end
	return 1
end

-- Upside-down timer. Returns (newTimer, shouldFlip).
function Logic.updateFlipTimer(
	timer: number,
	upY: number,
	dt: number,
	threshold: number,
	limit: number
): (number, boolean)
	if upY >= threshold then
		return 0, false
	end
	local t = timer + dt
	if t >= limit then
		return 0, true
	end
	return t, false
end

-- How hard a hit was, 0..1 (1 = `bigSpeed` or faster).
function Logic.hitStrength(relSpeed: number, bigSpeed: number): number
	return Logic.clamp(relSpeed / bigSpeed, 0, 1)
end

-- Freeze time for a hit. Weak hits (below `from`) do not freeze at all.
function Logic.hitStopTime(strength: number, minT: number, maxT: number, from: number): number
	if strength < from then
		return 0
	end
	local k = (strength - from) / (1 - from)
	return minT + (maxT - minT) * Logic.clamp(k, 0, 1)
end

return Logic
