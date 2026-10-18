--!strict
local Harness = require("./harness")
local SkidRules = require("../src/shared/SkidRules")

local test, eq, near, truthy = Harness.test, Harness.eq, Harness.near, Harness.truthy
local cfg = SkidRules.Config

print("SkidRules")

test("slip is the sideways part of the velocity", function()
	near(SkidRules.slipSpeed(0, -30, 0, -1), 0, 0.001)
	near(SkidRules.slipSpeed(20, 0, 0, -1), 20, 0.001)
	near(SkidRules.slipSpeed(30, -40, 0, -1), 30, 0.001)
	eq(SkidRules.slipSpeed(9, 9, 0, 0), 0)
end)

test("skid needs grounded, speed and slip", function()
	truthy(SkidRules.isSkidding(cfg.minSlip, cfg.minSpeed + 10, true))
	truthy(not SkidRules.isSkidding(cfg.minSlip - 1, 40, true))
	truthy(not SkidRules.isSkidding(30, 40, false))
	truthy(not SkidRules.isSkidding(30, cfg.minSpeed - 1, true))
end)

test("smoke rate clamps", function()
	eq(SkidRules.smokeRate(0), 0)
	eq(SkidRules.smokeRate(cfg.minSlip - 0.1), 0)
	truthy(SkidRules.smokeRate(cfg.minSlip) > 0)
	near(SkidRules.smokeRate(cfg.fullSlip), cfg.maxRate, 0.001)
	near(SkidRules.smokeRate(cfg.fullSlip * 5), cfg.maxRate, 0.001)
	truthy(SkidRules.smokeRate(30) < SkidRules.smokeRate(40))
end)
