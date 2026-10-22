--!strict
-- Pure car maths (no Roblox objects) so Lune can test it.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Tuning = sibling("Tuning")

local CarMath = {}

function CarMath.clamp(v: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, v))
end

-- Move `cur` toward `target` by at most `maxDelta`.
function CarMath.approach(cur: number, target: number, maxDelta: number): number
	if cur < target then
		return math.min(cur + maxDelta, target)
	end
	return math.max(cur - maxDelta, target)
end

-- Angle between where the car points and where it slides. 0 = straight, positive = sliding right.
function CarMath.slipAngle(vLat: number, vLong: number): number
	return math.atan2(vLat, math.max(math.abs(vLong), 1))
end

-- Biggest wheel angle allowed at this speed: wide when slow, small when fast.
function CarMath.steerLimit(speed: number): number
	local t = CarMath.clamp(math.abs(speed) / Tuning.topSpeed, 0, 1) ^ Tuning.steerCurve
	return Tuning.steerLow + (Tuning.steerHigh - Tuning.steerLow) * t
end

-- Where the front wheels want to point (positive = right). Adds counter-steer when the tail slides.
function CarMath.steerTarget(input: number, vLong: number, slip: number): number
	local i = CarMath.clamp(input, -1, 1)
	local target = i * CarMath.steerLimit(vLong)
	if vLong > 8 then
		local counter =
			CarMath.clamp(slip * Tuning.counterSteer, -Tuning.counterMax, Tuning.counterMax)
		target += counter * (1 - 0.5 * math.abs(i))
	end
	return CarMath.clamp(target, -Tuning.steerMax, Tuning.steerMax)
end

-- Engine push (studs/s^2) fading to nothing at top speed.
function CarMath.engineAccel(vLong: number, forward: boolean): number
	if forward then
		local t = CarMath.clamp(vLong / Tuning.topSpeed, 0, 1)
		local crawl = Tuning.crawlBoost
			* CarMath.clamp(1 - math.max(vLong, 0) / Tuning.crawlSpeed, 0, 1)
		return Tuning.accel * (1 - t * t) + crawl
	end
	local t = CarMath.clamp(-vLong / Tuning.reverseTop, 0, 1)
	return Tuning.accel * 0.6 * (1 - t * t)
end

-- Spring + damper. `compression` and `compSpeed` are positive when squashing. Never pulls.
function CarMath.springForce(compression: number, compSpeed: number, k: number, c: number): number
	return math.max(0, k * compression + c * compSpeed)
end

-- A tyre can only give so much grip in total: the more it pushes forward, the less it has
-- left for sideways. Returns (forward, sideways).
function CarMath.tractionCircle(
	fx: number,
	fy: number,
	capLong: number,
	capLat: number
): (number, number)
	local x = CarMath.clamp(fx, -capLong, capLong)
	local room = math.sqrt(math.max(capLat * capLat - x * x, 0))
	local limit = math.max(room, capLat * Tuning.minLatShare)
	return x, CarMath.clamp(fy, -limit, limit)
end

-- Sideways tyre force: grows with the tyre's slip angle up to full grip at `peakSlip`, so the
-- car leans into a small slide at speed instead of turning on rails. Never more than what
-- stops the slide this frame (no wobble when slow).
function CarMath.lateralForce(
	vLat: number,
	vLong: number,
	cap: number,
	wm: number,
	dt: number
): number
	local slip = math.atan2(vLat, math.max(math.abs(vLong), 4))
	local f = -cap * CarMath.clamp(slip / Tuning.peakSlip, -1, 1)
	local stop = math.abs(vLat) * wm * Tuning.gripResponse / dt
	return CarMath.clamp(f, -stop, stop)
end

-- Keeps a drift catchable: past `driftAngleMax` the spin that would make the slide worse is
-- turned around into a push back toward straight. `yaw` is positive turning left.
function CarMath.driftYaw(yaw: number, slip: number, vLong: number, dt: number): number
	local excess = math.abs(slip) - Tuning.driftAngleMax
	if vLong < 10 or excess <= 0 then
		return yaw
	end
	-- sliding right (slip > 0) means the nose is left of travel: turning left makes it worse
	local target = -math.sign(slip) * excess * Tuning.driftYawPush
	if yaw * math.sign(slip) > 0 or math.abs(yaw) < math.abs(target) then
		return CarMath.approach(yaw, target, 30 * dt)
	end
	return yaw
end

function CarMath.fov(speed: number): number
	local t = CarMath.clamp(speed / Tuning.topSpeed, 0, 1)
	return Tuning.camFovLow + (Tuning.camFovHigh - Tuning.camFovLow) * t
end

-- Drift score earned this frame: only when really sideways and fast.
function CarMath.driftPoints(speed: number, slip: number, dt: number): number
	local a = math.abs(slip)
	if speed < 15 or a < 0.25 then
		return 0
	end
	return speed * math.min(a, 1) * dt * 2
end

-- m:ss.t
function CarMath.formatTime(seconds: number): string
	local s = math.max(seconds, 0)
	local m = math.floor(s / 60)
	return string.format("%d:%04.1f", m, s - m * 60)
end

return CarMath
