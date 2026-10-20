--!strict
-- The weight of a player-driven car, as plain numbers (no Roblox parts, so Lune tests can run it).

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local BattleConfig = sibling("BattleConfig")

local BattleFeel = {}

-- Pure driving-feel helpers (unit tested): a car has weight, so it gets up to speed and rolls to a stop over
-- a moment, turns less sharply the faster it goes, and the wheel swings to the stick instead of jumping.

-- Next forward speed. Gas toward `want`; letting go of the gas rolls (coast); gas the other way brakes.
function BattleFeel.nextSpeed(fwd: number, want: number, dt: number, cruise: number): number
	local mv = BattleConfig.Move
	local H = BattleConfig.Human
	local rate: number
	if want == 0 then
		rate = mv.brake * H.coastMult
	elseif want * fwd < 0 or math.abs(want) < math.abs(fwd) then
		rate = mv.brake * H.brakeMult
	else
		rate = mv.accel * H.accelMult
	end
	local step = rate * cruise * dt
	return fwd + math.clamp(want - fwd, -step, step)
end

-- The speed the car is COMMANDED to have. The floor's friction takes a little speed off every step, so
-- reading the speed back from physics each step would eat a slow build-up (the car would never get going).
-- So the commanded speed carries on from step to step, unless physics moved the car a lot (a crash, a
-- wall, a shove): then the real speed wins.
function BattleFeel.trust(commanded: number?, actual: number, cruise: number): number
	if commanded == nil then
		return actual
	end
	if math.abs(commanded - actual) > BattleConfig.Human.trustGapFrac * cruise then
		return actual
	end
	return commanded
end

-- Share of the full turn rate at this share of top speed: full when crawling, `turnTopScale` at top speed.
function BattleFeel.turnScale(speedFrac: number): number
	local top = BattleConfig.Human.turnTopScale
	return 1 - (1 - top) * math.clamp(speedFrac, 0, 1)
end

-- Moves the steering toward the stick at `steerRate` per second (1 = full lock in 1/steerRate seconds).
function BattleFeel.smoothTurn(current: number, target: number, dt: number): number
	local step = BattleConfig.Human.steerRate * dt
	return current + math.clamp(target - current, -step, step)
end

-- The chase camera trails the car's nose: its heading (radians) chases the car's heading, at most
-- `camSwingDegPerSec` per second, so a fast spin does not whip the whole view round.
function BattleFeel.trailYaw(current: number, target: number, dt: number): number
	local H = BattleConfig.Human
	local diff = (target - current + math.pi) % (2 * math.pi) - math.pi
	local cap = math.rad(H.camSwingDegPerSec) * dt
	return current + math.clamp(diff * H.camTrailRate * dt, -cap, cap)
end

return BattleFeel
