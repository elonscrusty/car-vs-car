--!strict
local Harness = require("./harness")
local SkidRules = require("../src/shared/SkidRules")

local test, eq, near, truthy = Harness.test, Harness.eq, Harness.near, Harness.truthy
local cfg = SkidRules.Config

print("SkidRules")

test("slip is the sideways part of the velocity", function()
	local look = Vector3.new(0, 0, -1)
	near(SkidRules.slipSpeed(Vector3.new(0, 0, -30), look), 0, 0.001)
	near(SkidRules.slipSpeed(Vector3.new(20, 5, 0), look), 20, 0.001)
	near(SkidRules.slipSpeed(Vector3.new(30, 0, -40), look), 30, 0.001)
	eq(SkidRules.slipSpeed(Vector3.new(9, 0, 9), Vector3.new(0, 1, 0)), 0)
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
