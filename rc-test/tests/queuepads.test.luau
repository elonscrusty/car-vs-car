--!strict
-- Play pads (QueuePads.luau): standing still on a pad sends you, walking across does not.
local H = require("./harness")
local Q = require("../src/server/QueuePads")

local test, truthy, eq = H.test, H.truthy, H.eq

print("Queue pads")

test("standing on a pad for HOLD seconds sends you once, then again after another HOLD", function()
	local timers = {}
	eq(Q.tick(timers, "a", "drift", 0), false)
	eq(Q.tick(timers, "a", "drift", Q.HOLD - 0.1), false)
	eq(Q.tick(timers, "a", "drift", Q.HOLD), true)
	eq(Q.tick(timers, "a", "drift", Q.HOLD + 0.2), false)
	eq(Q.tick(timers, "a", "drift", 2 * Q.HOLD), true)
end)

test("walking across, or hopping to another pad, starts over", function()
	local timers = {}
	Q.tick(timers, "a", "race", 0)
	Q.tick(timers, "a", nil, 1)
	eq(Q.tick(timers, "a", "race", 1.5), false)
	eq(Q.tick(timers, "a", "race", 1.5 + Q.HOLD - 0.1), false)
	Q.tick(timers, "b", "rock", 0)
	eq(Q.tick(timers, "b", "drift", Q.HOLD + 1), false)
	truthy(Q.tick(timers, "b", "drift", 2 * Q.HOLD + 1), "drift after hold")
end)

test("after a race you land beside a pad, never on it", function()
	-- on the pad: out past the nearest edge, by the gap
	local x, z = Q.offPad(1, 4, 5, 5, 4)
	eq(x, 1)
	eq(z, 9)
	x, z = Q.offPad(-4, 2, 5, 5, 4)
	eq(x, -9)
	eq(z, 2)
	-- the middle: still off it
	x, z = Q.offPad(0, 0, 6, 4, 4)
	truthy(math.abs(x) > 6 or math.abs(z) > 4, "off the pad")
	-- already off it: stays put
	x, z = Q.offPad(8, 0, 5, 5, 4)
	eq(x, 8)
	eq(z, 0)
end)
