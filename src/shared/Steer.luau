--!strict
-- Manual steering math (pure, unit tested). The player only sends a number -1..1
-- (-1 = left, +1 = right as seen from behind the car); the server turns it into a spin.

export type State = {
	value: number, -- last sanitized input
	at: number, -- time (seconds) it arrived
	throttle: number, -- last sanitized gas: 1 forward, -1 back, 0 coast
}

local Steer = {}

-- Anything that is not a real number becomes 0; the rest is clamped to -1..1.
function Steer.sanitize(v: any): number
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return 0
	end
	return math.max(-1, math.min(1, v))
end

-- Angular velocity about Y. Positive Y rotation turns LEFT seen from above (same sign as
-- Ai.signedAngle), so steering right (+1) gives a NEGATIVE spin.
function Steer.spin(input: number, turnRate: number, scale: number): number
	return -Steer.sanitize(input) * turnRate * scale
end

-- Eases `current` toward `target`, moving at most `rate` per second (no overshoot).
function Steer.smooth(current: number, target: number, dt: number, rate: number): number
	local step = math.max(0, rate * dt)
	if target > current then
		return math.min(target, current + step)
	end
	return math.max(target, current - step)
end

function Steer.newState(): State
	return { value = 0, at = -math.huge, throttle = 0 }
end

-- Stores a raw client value (sanitized) with the time it arrived. `rawThrottle` is the gas
-- (-1 back .. 1 forward); a client that sends none (nil) keeps the gas fully on.
function Steer.set(state: State, raw: any, now: number, rawThrottle: any?)
	state.value = Steer.sanitize(raw)
	state.throttle = if rawThrottle == nil then 1 else Steer.sanitize(rawThrottle)
	state.at = now
end

function Steer.reset(state: State)
	state.value = 0
	state.throttle = 0
	state.at = -math.huge
end

-- The gas to use right now: 0 (coast) when nothing arrived for `staleAfter` seconds.
function Steer.currentThrottle(state: State, now: number, staleAfter: number): number
	if now - state.at > staleAfter then
		return 0
	end
	return state.throttle
end

-- The input to use right now: 0 when nothing arrived for `staleAfter` seconds, so a lost
-- "released" message cannot keep a car spinning.
function Steer.current(state: State, now: number, staleAfter: number): number
	if now - state.at > staleAfter then
		return 0
	end
	return state.value
end

return Steer
