--!strict
-- CarBoom: the numbers for the car smash boom and the come-back (carter's pick: Mega Fireball).

local H = require("./harness")
local CarBoom = require("../src/shared/CarBoom")
local Match = require("../src/shared/Match")

local test, truthy, eq, near = H.test, H.truthy, H.eq, H.near

print("Car boom")

test(
	"sizes follow the car: a 6-stud car is 1, an RC kart is small, bad lengths are safe",
	function()
		near(CarBoom.unit(6), 1)
		near(CarBoom.unit(1.4), 1.4 / 6)
		truthy(CarBoom.unit(0.01) >= 0.1, "never vanishes")
		eq(CarBoom.unit(0 / 0), 1)
		eq(CarBoom.unit(-3), 1)
		eq(CarBoom.unit(math.huge), 1)
	end
)

test("phones throw fewer bits, never none", function()
	eq(CarBoom.count(70, false), 70)
	truthy(CarBoom.count(70, true) < 70, "fewer on a phone")
	eq(CarBoom.count(1, true), 1)
end)

test("the wreck streams stay under the phone cap (100 a second per emitter)", function()
	for name, layer in CarBoom.WRECK do
		truthy(layer.count <= 100, name)
	end
	local total = 0
	for _, layer in CarBoom.BURST do
		total += layer.count
	end
	truthy(total <= 300, "one boom stays under 300 bits")
end)

test("every bright stack has a dark layer (the smoke), and the flash is short", function()
	eq(CarBoom.BURST.smoke.glow, 0)
	eq(CarBoom.WRECK.smoke.glow, 0)
	truthy(CarBoom.FLASH.secs <= 0.15, "flash 0.15 s or less")
	for _, r in CarBoom.RINGS do
		truthy(r.delay + r.secs <= 0.8, "rings are quick")
	end
end)

test("the 3-2-1 counts the real respawn wait", function()
	eq(CarBoom.countdown(0, Match.RESPAWN), 3)
	eq(CarBoom.countdown(0.99, Match.RESPAWN), 3)
	eq(CarBoom.countdown(1.0, Match.RESPAWN), 2)
	eq(CarBoom.countdown(2.5, Match.RESPAWN), 1)
	eq(CarBoom.countdown(Match.RESPAWN, Match.RESPAWN), nil)
	eq(CarBoom.countdown(-1, Match.RESPAWN), nil)
end)

test("parts fly up and out; exactly one wheel rolls away low and fast", function()
	local rolls = 0
	for _, p in CarBoom.PIECES do
		for _, r in { { 0, 0, 0 }, { 1, 1, 1 }, { 0.5, 0.2, 0.9 } } do
			local x, y, z = CarBoom.fling(p, r[1], r[2], r[3])
			truthy(y > 0, p.name .. " goes up")
			truthy(math.sqrt(x * x + z * z) > 2, p.name .. " goes out")
		end
		if p.roll then
			rolls += 1
			truthy(p.wheel == true, "the roller is a wheel")
			local x, y = CarBoom.fling(p, 0.5, 0.5, 0.5)
			truthy(math.abs(x) > y, "rolls more than it jumps")
		end
	end
	eq(rolls, 1)
end)

test("a bounce keeps less speed and settles", function()
	local x, y, z = CarBoom.bounce(10, -10, 5)
	truthy(y > 0 and y < 10, "bounces up, lower")
	truthy(math.abs(x) < 10 and math.abs(z) < 5, "slows")
	local _, y2 = CarBoom.bounce(1, -1, 1)
	eq(y2, 0)
end)

test("rings grow out and wait for their delay", function()
	eq(CarBoom.ringGrow(0, 0.5, 0.1), nil)
	near(CarBoom.ringGrow(0.1, 0.5, 0.1) :: number, 0)
	near(CarBoom.ringGrow(1, 0.5, 0) :: number, 1)
	truthy((CarBoom.ringGrow(0.25, 0.5, 0) :: number) > 0.5, "fast at the start")
end)
