--!strict
local Harness = require("./harness")
local CarLook = require("../src/shared/CarLook")

local test, eq, near, truthy = Harness.test, Harness.eq, Harness.near, Harness.truthy

print("CarLook")

test("outline: known rarity, unknown falls back to Common", function()
	eq(CarLook.outlineRgb("Legendary")[1], 255)
	eq(CarLook.outlineRgb("Nope")[1], CarLook.Config.outline.Common[1])
	eq(CarLook.outlineRgb(nil)[1], CarLook.Config.outline.Common[1])
end)

test("every rarity has an rgb triple", function()
	for _, rgb in CarLook.Config.outline do
		eq(#rgb, 3)
	end
end)

test("wheel radius is half the diameter, never 0", function()
	near(CarLook.wheelRadius(2, 3), 1.5, 0.001)
	truthy(CarLook.wheelRadius(0, 0) > 0)
end)

test("spin: forward turns negative, backward positive, clamped", function()
	truthy(CarLook.spinStep(20, 1, 0.016) < 0)
	truthy(CarLook.spinStep(-20, 1, 0.016) > 0)
	near(CarLook.spinStep(0, 1, 0.016), 0, 0.0001)
	near(CarLook.spinStep(1e6, 1, 1), -CarLook.Config.maxWheelSpin, 0.001)
end)

test("wheel names", function()
	truthy(CarLook.isWheel("Wheel_FL"))
	truthy(not CarLook.isWheel("Visual"))
end)
