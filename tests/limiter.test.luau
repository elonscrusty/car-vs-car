--!strict
local Harness = require("./harness")
local RateLimiter = require("../src/shared/RateLimiter")

local test, eq = Harness.test, Harness.eq

print("RateLimiter")

test("allows up to max per window then blocks", function()
	local rl = RateLimiter.new(3, 1)
	eq(rl.allow("a", 0), true)
	eq(rl.allow("a", 0.1), true)
	eq(rl.allow("a", 0.2), true)
	eq(rl.allow("a", 0.3), false)
end)

test("window resets", function()
	local rl = RateLimiter.new(1, 1)
	eq(rl.allow("a", 0), true)
	eq(rl.allow("a", 0.5), false)
	eq(rl.allow("a", 1.1), true)
end)

test("keys are independent and clear works", function()
	local rl = RateLimiter.new(1, 10)
	eq(rl.allow("a", 0), true)
	eq(rl.allow("b", 0), true)
	eq(rl.allow("a", 1), false)
	rl.clear("a")
	eq(rl.allow("a", 1), true)
end)
