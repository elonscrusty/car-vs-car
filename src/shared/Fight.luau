--!strict
-- Pure fight rules: counter timing, special move ranges, ring-out. No Roblox calls so Lune can test it.

local Fight = {}

export type CounterState = { tapAt: number, readyAt: number }

function Fight.newCounter(): CounterState
	return { tapAt = -math.huge, readyAt = -math.huge }
end

-- A tap only counts when the counter is ready. A tap (even a miss) locks it for `cooldown` seconds.
function Fight.tap(state: CounterState, now: number, cooldown: number): boolean
	if now < state.readyAt then
		return false
	end
	state.tapAt = now
	state.readyAt = now + cooldown
	return true
end

-- Was the last counted tap just before this impact?
function Fight.isCountered(state: CounterState, now: number, window: number): boolean
	return now - state.tapAt <= window
end

-- A counter can only block one hit.
function Fight.consume(state: CounterState)
	state.tapAt = -math.huge
end

-- Damage after a counter.
function Fight.counterDamage(damage: number, mult: number): number
	return damage * mult
end

-- Beyond the rim (plus a margin) the car is out of the ring.
function Fight.isRingOut(horizDist: number, rimRadius: number, margin: number): boolean
	return horizDist > rimRadius + margin
end

-- Straight-ahead check for Ramp: enemy within `range` and in front (dot of look vs direction to enemy).
function Fight.inCone(dist: number, dot: number, range: number, minDot: number): boolean
	return dist <= range and dot >= minDot
end

-- 1 at the center, 0 at the edge of the radius.
function Fight.falloff(dist: number, radius: number): number
	if radius <= 0 then
		return 0
	end
	return math.clamp(1 - dist / radius, 0, 1)
end

-- Specials: ready when cooldown is over.
function Fight.canSpecial(cooldownLeft: number): boolean
	return cooldownLeft <= 0
end

return Fight
