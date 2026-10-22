--!strict
local H = require("./harness")
local CarMath = require("../src/shared/CarMath")
local Tuning = require("../src/shared/Tuning")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near

print("CarMath")

test("approach never overshoots", function()
	eq(CarMath.approach(0, 1, 0.3), 0.3)
	eq(CarMath.approach(0.9, 1, 0.3), 1)
	eq(CarMath.approach(0, -1, 0.5), -0.5)
end)

test("steering gets narrower with speed", function()
	near(CarMath.steerLimit(0), Tuning.steerLow)
	near(CarMath.steerLimit(Tuning.topSpeed), Tuning.steerHigh)
	truthy(CarMath.steerLimit(20) > CarMath.steerLimit(60))
	near(CarMath.steerLimit(-40), CarMath.steerLimit(40))
end)

test("counter-steer points toward the slide and stays small", function()
	-- sliding right at speed, hands off: wheels go right
	truthy(CarMath.steerTarget(0, 40, 0.5) > 0.1)
	truthy(CarMath.steerTarget(0, 40, -0.5) < -0.1)
	-- no counter-steer when slow or going backwards
	eq(CarMath.steerTarget(0, 3, 0.5), 0)
	eq(CarMath.steerTarget(0, -20, 0.5), 0)
	-- never past the hard limit
	truthy(math.abs(CarMath.steerTarget(1, 40, 3)) <= Tuning.steerMax)
end)

test("slip angle", function()
	near(CarMath.slipAngle(0, 50), 0)
	truthy(CarMath.slipAngle(20, 20) > 0.7)
	truthy(CarMath.slipAngle(-20, 20) < -0.7)
	truthy(CarMath.slipAngle(0, 0) == 0)
end)

test("engine fades to zero at top speed", function()
	near(CarMath.engineAccel(0, true), Tuning.accel + Tuning.crawlBoost)
	near(
		CarMath.engineAccel(Tuning.crawlSpeed, true),
		Tuning.accel * (1 - (Tuning.crawlSpeed / Tuning.topSpeed) ^ 2)
	)
	near(CarMath.engineAccel(Tuning.topSpeed, true), 0)
	near(CarMath.engineAccel(Tuning.topSpeed * 2, true), 0)
	truthy(CarMath.engineAccel(0, false) < Tuning.accel)
	near(CarMath.engineAccel(-Tuning.reverseTop, false), 0)
end)

test("spring never pulls", function()
	eq(CarMath.springForce(0, 0, 100, 10), 0)
	eq(CarMath.springForce(0.1, -50, 100, 10), 0)
	near(CarMath.springForce(1, 2, 100, 10), 120)
end)

test("traction circle trades forward grip for sideways grip", function()
	local fx, fy = CarMath.tractionCircle(10, 10, 100, 100)
	near(fx, 10)
	near(fy, 10)
	local fx2, fy2 = CarMath.tractionCircle(100, 100, 100, 100)
	near(fx2, 100)
	-- floor: sideways grip never vanishes
	near(fy2, 100 * Tuning.minLatShare)
	local _, fy3 = CarMath.tractionCircle(0, -500, 100, 100)
	near(fy3, -100)
	local fx4 = CarMath.tractionCircle(500, 0, 100, 100)
	near(fx4, 100)
end)

test("fov widens with speed", function()
	near(CarMath.fov(0), Tuning.camFovLow)
	near(CarMath.fov(1000), Tuning.camFovHigh)
	truthy(CarMath.fov(50) > CarMath.fov(10))
end)

test("drift points only when sideways and fast", function()
	eq(CarMath.driftPoints(10, 0.8, 1), 0)
	eq(CarMath.driftPoints(60, 0.1, 1), 0)
	truthy(CarMath.driftPoints(60, 0.6, 1) > 0)
	truthy(CarMath.driftPoints(60, -0.6, 1) > 0)
	truthy(CarMath.driftPoints(80, 0.6, 1) > CarMath.driftPoints(40, 0.6, 1))
end)

test("time text", function()
	eq(CarMath.formatTime(0), "0:00.0")
	eq(CarMath.formatTime(65.43), "1:05.4")
	eq(CarMath.formatTime(-3), "0:00.0")
end)

test("tyre slips a little before full grip, never overshoots", function()
	-- small slip at speed: partial force
	local f = CarMath.lateralForce(2, 80, 100, 1, 1 / 60)
	truthy(f < 0 and f > -100)
	-- big slip: full grip, opposite the slide
	near(CarMath.lateralForce(-30, 80, 100, 1, 1 / 60), 100)
	-- nearly stopped: only what stops the slide this frame
	local tiny = CarMath.lateralForce(0.01, 0, 1000, 1, 1 / 60)
	near(tiny, -0.01 * Tuning.gripResponse * 60)
end)

test("a longer held slide scores more per second", function()
	eq(CarMath.driftCombo(0), 1)
	eq(CarMath.driftCombo(1.4), 1)
	eq(CarMath.driftCombo(1.5), 2)
	eq(CarMath.driftCombo(4.6), 4)
	eq(CarMath.driftCombo(100), 5)
end)

test("drift angle limiter turns a spin into a push back", function()
	-- small slide: untouched
	eq(CarMath.driftYaw(2, 0.3, 50, 1 / 60), 2)
	-- slow: untouched
	eq(CarMath.driftYaw(2, 1.2, 5, 1 / 60), 2)
	-- sliding right past the limit while turning left (making it worse): yaw pulled down
	truthy(CarMath.driftYaw(3, 1.0, 50, 1 / 60) < 3)
	-- mirror
	truthy(CarMath.driftYaw(-3, -1.0, 50, 1 / 60) > -3)
	-- already turning back hard enough: untouched
	eq(CarMath.driftYaw(-5, 1.0, 50, 1 / 60), -5)
end)

test("4x4 when crawling, rear-heavy when fast", function()
	near(CarMath.frontShare(0), Tuning.crawlFrontDrive)
	near(CarMath.frontShare(80), Tuning.frontDrive)
	near(CarMath.frontShare(-80), Tuning.frontDrive)
end)

test("hill hold pushes uphill against gravity", function()
	truthy(CarMath.holdForce(1, 196.2, 0.5) > 0)
	truthy(CarMath.holdForce(1, 196.2, -0.5) < 0)
	eq(CarMath.holdForce(1, 196.2, 0), 0)
end)

test("track modes change numbers and switch back cleanly", function()
	local T = Tuning :: any
	local baseTop = Tuning.topSpeed
	T.setMode("rock")
	truthy(Tuning.topSpeed < 20, "rock is crawl slow")
	truthy(Tuning.maxSusp >= 4, "rock has long springs")
	eq(Tuning.stuckWait, 10)
	truthy(Tuning.uprightAssist > 0, "rock eases back upright")
	truthy(Tuning.yawHold > 0, "rock holds its line")
	-- rock must still be able to climb a 0.6 slope at walking pace
	truthy(
		CarMath.engineAccel(4, true) > 196.2 * math.sin(math.atan(0.6)),
		"rock too weak to climb"
	)
	-- springs must not sit bottomed out at rest
	truthy(196.2 / Tuning.springOmega ^ 2 < Tuning.maxSusp * 0.7, "rock springs too soft")
	T.setMode("drift")
	truthy(Tuning.topSpeed > baseTop, "drift should be faster than race")
	truthy(Tuning.baseMu < 1.1, "drift should be more slippery than race")
	truthy(Tuning.camHeight > 3, "drift cam should sit higher")
	truthy(Tuning.powerSlide > 0)
	T.setMode("race")
	eq(Tuning.topSpeed, baseTop)
	eq(Tuning.camHeight, 3)
	eq(Tuning.stuckWait, 3)
	eq(Tuning.uprightAssist, 0)
	eq(Tuning.yawHold, 0)
	eq(Tuning.powerSlide, 0)
	eq(Tuning.driftAngleMax, 0.6)
end)

test("drift thrust only on the drift track, only while sliding on the gas", function()
	local T = Tuning :: any
	T.setMode("race")
	eq(CarMath.driftThrust(40, 0.6, 1), 0)
	T.setMode("drift")
	truthy(CarMath.driftThrust(40, 0.6, 1) > 0)
	eq(CarMath.driftThrust(40, 0.1, 1), 0)
	eq(CarMath.driftThrust(40, 0.6, 0), 0)
	eq(CarMath.driftThrust(Tuning.topSpeed, 0.6, 1), 0)
	T.setMode("race")
end)

test("low gear holds the rock crawler to its top speed downhill", function()
	local T = Tuning :: any
	T.setMode("rock")
	eq(CarMath.governor(10, 1, 1 / 60), 0)
	truthy(CarMath.governor(Tuning.topSpeed + 20, 1, 1 / 60) < 0)
	truthy(CarMath.governor(-(Tuning.topSpeed + 20), 1, 1 / 60) > 0)
	T.setMode("race")
	eq(CarMath.governor(500, 1, 1 / 60), 0)
end)

test("RC size shrinks lengths and speeds but not angles or grip", function()
	local T = Tuning :: any
	T.setMode("race")
	local bigTop, bigLen, bigMu, bigOmega =
		Tuning.topSpeed, Tuning.bodyZ, Tuning.baseMu, Tuning.springOmega
	T.setScale(0.25)
	near(Tuning.topSpeed, bigTop * 0.25)
	near(Tuning.bodyZ, bigLen * 0.25)
	eq(Tuning.baseMu, bigMu)
	eq(Tuning.springOmega, bigOmega)
	-- modes still work at RC size
	T.setMode("rock")
	truthy(Tuning.topSpeed < 30 * 0.25)
	-- the steering curve is the same shape at the same fraction of top speed
	local smallSteer = CarMath.steerLimit(Tuning.topSpeed * 0.5)
	T.setScale(1)
	near(CarMath.steerLimit(Tuning.topSpeed * 0.5), smallSteer)
	-- drift score is the same at both sizes
	T.setScale(0.25)
	local small = CarMath.driftPoints(60 * 0.25, 0.6, 1)
	T.setScale(1)
	near(CarMath.driftPoints(60, 0.6, 1), small)
	T.setMode("race")
end)
