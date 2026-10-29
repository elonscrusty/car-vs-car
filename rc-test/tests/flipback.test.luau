--!strict
-- The arena's flip back (FlipBack): tipped for 1 s = back on its wheels, where it is.
local H = require("./harness")
local FlipBack = require("../src/shared/FlipBack")
local test, eq = H.test, H.eq

test("a kart upside down or on its side is put back after 1 s, not before", function()
	local held, fire = FlipBack.tick(0, 0.5, -1, true) -- upside down
	eq(fire, false)
	held, fire = FlipBack.tick(held, 0.5, 0, true) -- now on its side: still tipped
	eq(fire, true)
	eq(held, 0) -- starts counting again
end)

test("a kart that rights itself, or just leans in a turn or on a ramp, is left alone", function()
	local held, fire = FlipBack.tick(0, 0.9, -1, true)
	held, fire = FlipBack.tick(held, 0.05, 1, true) -- landed on its wheels
	eq(held, 0)
	eq(fire, false)
	held, fire = FlipBack.tick(0, 5, 0.7, true) -- 45 degrees over for a long time
	eq(fire, false)
	held, fire = FlipBack.tick(0, 0.8, -1, false) -- upside down, a short tumble or slide
	eq(held, 0.8)
	eq(fire, false)
end)

-- frame by frame at 60 fps: seconds until it's put back (nil = never in 5 s)
local function until_(upY: number, still: boolean): number?
	local held, t = 0, 0
	for _ = 1, 300 do
		local fire
		held, fire = FlipBack.tick(held, 1 / 60, upY, still)
		t += 1 / 60
		if fire then
			return t
		end
	end
	return nil
end

test("upside down, on its side, nose down: back on its wheels inside 2 s, moving or not", function()
	local cases = {
		{ "upside down", -1 },
		{ "on its side", 0 },
		{ "nose down (up arrow flat)", 0.02 },
		{ "60+ degrees over", 0.45 },
	}
	for _, c in cases do
		for _, still in { true, false } do
			local at = until_(c[2], still)
			H.truthy(at ~= nil and at < 2, `{c[1]}, still={still}: put back at {at}`)
		end
	end
	eq(until_(-1, true) and math.floor(until_(-1, true) * 10 + 0.5) / 10, 1, "stopped: after 1 s")
	eq(until_(0.6, false), nil, "a hard lean in a turn: never")
end)

test("a tumble that lands on its wheels starts the count over", function()
	local held, fire = FlipBack.tick(0, 1.2, -1, false)
	eq(fire, false)
	held, fire = FlipBack.tick(held, 1 / 60, 1, false)
	eq(held, 0)
	held, fire = FlipBack.tick(held, 1.2, -1, false)
	eq(fire, false, "a new 1.2 s, not 2.4")
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
