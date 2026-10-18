--!strict
-- Pure rules for the bowl fun-stuff (no Roblox calls): smash hits, boost pad spots and launches,
-- drift charge, magnet pull. Numbers: BowlConfig. Unit tested.

local BowlRules = {}

export type Vec = { x: number, z: number }

-- Is this hit a SMASH?
function BowlRules.isSmash(strength: number, from: number): boolean
	return strength >= from
end

-- Pop-up speed and spin for the car that got smashed (0 when the hit was not a smash).
function BowlRules.smashPop(
	strength: number,
	smash: { from: number, upSpeed: number, spin: number }
): (number, number)
	if strength < smash.from then
		return 0, 0
	end
	local s = math.clamp(strength, 0, 1)
	return smash.upSpeed * s, smash.spin * s
end

-- `count` boost pad spots spread round the bowl at `radius` from the middle (relative x, z).
-- The first pad sits `phase` radians round from the +X side so pads never line up with the spawns.
function BowlRules.padSpots(count: number, radius: number, phase: number): { Vec }
	local out: { Vec } = {}
	for i = 0, count - 1 do
		local a = phase + i / count * math.pi * 2
		table.insert(out, { x = math.cos(a) * radius, z = math.sin(a) * radius })
	end
	return out
end

-- Is the car (relative flat position) on the pad?
function BowlRules.onPad(car: Vec, pad: Vec, radius: number): boolean
	return (car.x - pad.x) ^ 2 + (car.z - pad.z) ^ 2 <= radius * radius
end

-- Launch velocity (x, y, z) for a car on a pad: sideways along the rim (a tangent, round the bowl),
-- plus lift. The way round follows the car's own flat velocity (vx, vz); a car that is standing
-- still goes counter-clockwise.
function BowlRules.padLaunch(
	pad: Vec,
	kick: number,
	lift: number,
	vx: number?,
	vz: number?
): (number, number, number)
	local len = math.sqrt(pad.x ^ 2 + pad.z ^ 2)
	if len < 0.001 then
		return 0, lift, 0
	end
	local tx, tz = -pad.z / len, pad.x / len
	if (vx or 0) * tx + (vz or 0) * tz < 0 then
		tx, tz = -tx, -tz
	end
	return tx * kick, lift, tz * kick
end

-- Seconds of boost cooldown given back this frame while a car is sliding (drifting).
function BowlRules.driftRefund(sliding: boolean, dt: number, perSecond: number): number
	return if sliding then perSecond * dt else 0
end

-- Speed change (studs/s) to pull the enemy toward the magnet car this frame (0 outside range).
function BowlRules.magnetPull(dist: number, range: number, pull: number, dt: number): number
	if dist <= 0.5 or dist > range then
		return 0
	end
	return pull * dt * (1 - dist / range * 0.5)
end

return BowlRules
