--!strict
-- The arena's flip back (FlipBack): tipped for 1 s = back on its wheels, where it is.
local H = require("./harness")
local FlipBack = require("../src/shared/FlipBack")
local test, eq = H.test, H.eq

test("a kart upside down or on its side is put back after 1 s, not before", function()
	local held, fire = FlipBack.tick(0, 0.5, -1) -- upside down
	eq(fire, false)
	held, fire = FlipBack.tick(held, 0.5, 0) -- now on its side: still tipped
	eq(fire, true)
	eq(held, 0) -- starts counting again
end)

test("a kart that rights itself, or just leans in a turn or on a ramp, is left alone", function()
	local held, fire = FlipBack.tick(0, 0.9, -1)
	held, fire = FlipBack.tick(held, 0.05, 1) -- landed on its wheels
	eq(held, 0)
	eq(fire, false)
	held, fire = FlipBack.tick(0, 5, 0.7) -- 45 degrees over for a long time
	eq(fire, false)
end)

test("put back facing the way its nose pointed, flat", function()
	local x, z = FlipBack.facing(0, -2, 1, 0)
	eq(x, 0)
	eq(z, -1)
	x, z = FlipBack.facing(0.01, 0, 0, 3) -- nose straight up: the roof's way
	eq(x, 0)
	eq(z, 1)
	x, z = FlipBack.facing(0, 0, 0, 0)
	eq(z, 1)
end)
