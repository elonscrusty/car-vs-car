--!strict
-- StreakFire: the fire on a car with 3+ smashes in a row (carter's pick: Hot Rod Flames), and the
-- server's streak count it reads (Match karts' `streak`).

local H = require("./harness")
local StreakFire = require("../src/shared/StreakFire")
local Match = require("../src/shared/Match")

local test, truthy, eq, near = H.test, H.truthy, H.eq, H.near

print("Streak fire")

test("no fire under 3 in a row; sizes start at 3, 5 and 7; junk is no fire", function()
	eq(StreakFire.level(0), 0)
	eq(StreakFire.level(2), 0)
	eq(StreakFire.level(3), 1)
	eq(StreakFire.level(4), 1)
	eq(StreakFire.level(5), 2)
	eq(StreakFire.level(6), 2)
	eq(StreakFire.level(7), 3)
	eq(StreakFire.level(40), 3)
	eq(StreakFire.level(nil), 0)
	eq(StreakFire.level(0 / 0), 0)
	eq(StreakFire.level(-5), 0)
end)

test("the fire grows with the level", function()
	truthy(StreakFire.size(1) < StreakFire.size(2) and StreakFire.size(2) < StreakFire.size(3))
	eq(StreakFire.size(0), StreakFire.SIZE[1]) -- (a level under 1 counts as 1)
	eq(StreakFire.size(9), StreakFire.SIZE[3])
end)

test("the white core shows from 5, the tall column from 7; the rest from 3", function()
	for _, e in StreakFire.EMITTERS do
		eq(StreakFire.rate(e, 0, false), 0)
		if e.name == "Core" then
			eq(StreakFire.rate(e, 1, false), 0)
			truthy(StreakFire.rate(e, 2, false) > 0)
		elseif e.name == "Column" then
			eq(StreakFire.rate(e, 2, false), 0)
			truthy(StreakFire.rate(e, 3, false) > 0)
		else
			truthy(StreakFire.rate(e, 1, false) > 0, e.name)
		end
	end
end)

test("phones get fewer flames, and one car at 7 in a row keeps under 500 bits alive", function()
	local alive = 0
	for _, e in StreakFire.EMITTERS do
		local full = StreakFire.rate(e, 3, false)
		if full > 0 then
			near(StreakFire.rate(e, 3, true), full * StreakFire.PHONE)
		end
		alive += full * #e.spots * (e.life[1] + e.life[2]) / 2
	end
	truthy(alive <= 500, `one burning car keeps {alive} bits alive`)
end)

test("a dark smoke layer sits under the fire, and every spot has x, y, z", function()
	local smoke = false
	for _, e in StreakFire.EMITTERS do
		for _, at in e.spots do
			eq(#at, 3)
		end
		truthy(e.life[1] > 0 and e.life[2] >= e.life[1], e.name)
		if e.glow == 0 then
			smoke = true
		end
	end
	truthy(smoke, "a smoke layer")
end)

test("sizes follow the car, bad lengths are safe", function()
	near(StreakFire.unit(6), 1)
	near(StreakFire.unit(3), 0.5)
	eq(StreakFire.unit(0 / 0), 1)
	eq(StreakFire.unit(-1), 1)
	truthy(StreakFire.unit(0.01) >= 0.1)
end)

test("Match streak: smashes in a row count up and being smashed starts it over", function()
	local m = Match.new(0)
	for i = 1, 3 do
		Match.add(m, i, `P{i}`, true, 0)
	end
	local now = Match.SHIELD + 1
	local function smash(victim: number, by: number)
		for _ = 1, 3 do
			Match.damage(m, victim, by, Match.HIT, now)
		end
	end
	eq(m.karts[1].streak, 0)
	smash(2, 1)
	eq(m.karts[1].streak, 1)
	smash(3, 1)
	eq(m.karts[1].streak, 2)
	-- being smashed starts it over, even by its own mine (that scores nobody)
	for _ = 1, 3 do
		Match.damage(m, 1, 1, Match.HIT, now + 5)
	end
	eq(m.karts[1].streak, 0)
	eq(m.karts[1].smashes, 2)
end)
