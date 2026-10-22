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
