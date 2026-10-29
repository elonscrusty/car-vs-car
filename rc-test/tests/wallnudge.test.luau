--!strict
-- The arena's wall bounce (WallNudge): gas on, crawling, wall ahead for 1.5 s = back and turn.
local H = require("./harness")
local WallNudge = require("../src/shared/WallNudge")
local test, eq = H.test, H.eq

test("grinding into a wall with the gas on bounces after 1.5 s, not before", function()
	local held, fire = WallNudge.tick(0, 1, true, true, true)
	eq(fire, false)
	held, fire = WallNudge.tick(held, 0.5, true, true, true)
	eq(fire, true)
	eq(held, 0)
end)

test("no bounce without the gas, while moving, or with nothing ahead", function()
	local held, fire = WallNudge.tick(1.4, 1, false, true, true)
	eq(held, 0)
	eq(fire, false)
	held, fire = WallNudge.tick(1.4, 1, true, false, true)
	eq(fire, false)
	held, fire = WallNudge.tick(1.4, 1, true, true, false)
	eq(fire, false)
end)

test("it turns toward the open side", function()
	eq(WallNudge.side(nil, 5), -1) -- nothing on the left
	eq(WallNudge.side(5, nil), 1)
	eq(WallNudge.side(nil, nil), 1)
	eq(WallNudge.side(8, 3), -1)
	eq(WallNudge.side(3, 8), 1)
end)

test("three bounces in 10 s that don't free it: leave it to the stuck reset", function()
	local times: { number } = {}
	for _, t in { 0, 2, 4 } do
		eq(WallNudge.allowed(times, t), true)
		table.insert(times, t)
	end
	eq(WallNudge.allowed(times, 6), false)
	eq(WallNudge.allowed(times, 10.5), true) -- the first one is old now
	eq(#times, 2)
end)
