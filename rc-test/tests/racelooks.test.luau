--!strict
-- Race looks: sparks only on a real hit, never on braking or a bump.
local H = require("./harness")
local RaceLooks = require("../src/shared/RaceLooks")

local test, truthy = H.test, H.truthy

print("Race looks")

test("sparks: a wall stops the car in a frame; brakes and bumps don't", function()
	local s = 0.25 -- RC size
	truthy(RaceLooks.slammed(40, 8, s), "into a wall at speed")
	truthy(not RaceLooks.slammed(40, 39, s), "braking hard: about 1 stud/s a frame")
	truthy(not RaceLooks.slammed(4, 0, s), "a slow nudge is too small")
	truthy(not RaceLooks.slammed(40, 45, s), "speeding up")
end)
