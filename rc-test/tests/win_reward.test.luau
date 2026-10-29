--!strict
-- The win screen's coins and LEVEL UP! (carter's pick A): the coins land in order, the number ends
-- on exactly what was paid, and the level banner comes after the last coin.
local H = require("./harness")
local WinReward = require("../src/shared/WinReward")

local test, eq, truthy = H.test, H.eq, H.truthy

print("WinReward")

test("coins leave one after another and land in order", function()
	for k = 2, WinReward.COINS do
		truthy(WinReward.leaves(k) > WinReward.leaves(k - 1), "leave in order")
		truthy(WinReward.lands(k) > WinReward.lands(k - 1), "land in order")
	end
	eq(WinReward.lands(1), WinReward.FIRST_AT + WinReward.FLIGHT)
end)

test("the coins number climbs and ends on exactly the total", function()
	for _, total in { 1, 5, 13, 14, 25, 155, 1000 } do
		local last = 0
		for k = 1, WinReward.COINS do
			local v = WinReward.shown(k, total)
			truthy(v >= last and v <= total, "never goes down or past the total")
			last = v
		end
		eq(WinReward.shown(WinReward.COINS, total), total)
		eq(WinReward.shown(0, total), 0)
	end
end)

test("a coin starts at its start, ends in the total and swings out between", function()
	for k = 1, WinReward.COINS do
		local x0, y0 = WinReward.fly(k, 0, 400, 150, 30, 340)
		local x1, y1 = WinReward.fly(k, 1, 400, 150, 30, 340)
		truthy(math.abs(x0 - 400) < 1e-6 and math.abs(y0 - 150) < 1e-6, "starts at the step")
		truthy(math.abs(x1 - 30) < 1e-6 and math.abs(y1 - 340) < 1e-6, "lands in the number")
		local _, ym, size = WinReward.fly(k, 0.3, 400, 150, 30, 340)
		truthy(ym < 340 and size > 1, "up in the air and bigger in the middle")
	end
	local w = WinReward.spin(3, 0.37)
	truthy(w >= 0.18 and w <= 1, "a spinning coin is never flat")
end)

test("the coins number pulses at a landing and settles", function()
	eq(WinReward.pulse(0), 1)
	eq(WinReward.pulse(0.3), 0)
	eq(WinReward.pulse(5), 0)
end)

test("the bar fills after the last coin and LEVEL UP! comes when it is full", function()
	truthy(WinReward.FILL_AT >= WinReward.lands(WinReward.COINS), "no coin still flying")
	truthy(WinReward.BANNER_AT >= WinReward.FILL_AT + WinReward.FILL_SECS - 0.01, "bar is full")
	truthy(WinReward.BANNER_AT + WinReward.BANNER_HOLD < 11, "gone before the next round")
end)

test("the burst's stars stay in the picture while they live", function()
	for i = 1, WinReward.STARS do
		eq(WinReward.star(i, -0.1, 422, 110), nil)
		eq(WinReward.star(i, WinReward.STAR_LIFE + 0.1, 422, 110), nil)
		for a = 0, 13 do
			local x, y = WinReward.star(i, a * 0.1, 422, 110)
			truthy(x ~= nil and y ~= nil, "alive")
			truthy((x :: number) > -40 and (x :: number) < 884, "sideways in the picture")
		end
	end
end)
