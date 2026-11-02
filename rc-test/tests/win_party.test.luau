--!strict
-- The win party (carter's pick A): the numbers behind the corner guns, the light rain and the
-- cheering karts stay inside the picture and never run away.
local H = require("./harness")
local WinParty = require("../src/shared/WinParty")

local test, eq, truthy = H.test, H.eq, H.truthy

print("WinParty")

test("the winner hops 3 times, getting lower, then bobs", function()
	eq(WinParty.winnerPose(0.5), nil, "the entrance runs first")
	local tops: { number } = {}
	for _, at in { 0.9, 1.6, 2.2 } do
		local best = 0
		for i = 0, 60 do
			local y = WinParty.winnerPose(at + i * 0.01)
			best = math.min(best, y or 0)
		end
		table.insert(tops, best)
	end
	truthy(
		tops[1] < tops[2] and tops[2] < tops[3] and tops[3] < -10,
		"each hop lower than the last"
	)
	truthy(tops[1] >= -52, "never leaves the podium for the title")
	local y, s = WinParty.winnerPose(5)
	truthy(y ~= nil and math.abs(y :: number) <= 4 and s == 1, "then a small bob")
end)

test("a hop has one arc: up, down, back to 0", function()
	eq(WinParty.hop(0.9, 1, 20, 0.5), nil)
	eq(WinParty.hop(2, 1, 20, 0.5), nil)
	eq(WinParty.hop(1, 1, 20, 0.5), 0)
	local mid = WinParty.hop(1.25, 1, 20, 0.5)
	truthy(mid ~= nil and math.abs((mid :: number) + 20) < 1e-6, "top of the arc is h")
	local y, s = WinParty.hop(1.55, 1, 20, 0.5)
	eq(y, 0)
	truthy(s ~= nil and s > 0.9 and s < 1.1, "squash stays small")
end)

test("2nd then 3rd clap along, one small hop each", function()
	eq(WinParty.clapPose(2, 0.5), nil)
	local first, second = 0, 0
	for i = 0, 200 do
		first = math.min(first, WinParty.clapPose(2, i * 0.01) or 0)
		second = math.min(second, WinParty.clapPose(3, i * 0.01) or 0)
	end
	truthy(first < -10 and first >= -16.5, "2nd hops")
	truthy(second < -10 and second >= -16.5, "3rd hops")
	truthy((WinParty.clapPose(2, 1.33 + 0.2) or 0) < -10, "2nd is up while 3rd has not started")
	eq(WinParty.clapPose(3, 1.33 + 0.2 - 0.18 + 0.005), nil, "3rd waits")
end)

test("each gun shoots up and inward from its own corner", function()
	for i = 1, WinParty.GUN_BITS do
		local l, r = WinParty.shot(1, i), WinParty.shot(-1, i)
		eq(l.x, 0)
		eq(r.x, WinParty.W)
		eq(l.y, WinParty.H)
		truthy(l.vx > 0 and r.vx < 0 and l.vy < -300, "up and in")
		eq(l.vx, -r.vx)
	end
	local stars = 0
	for i = 1, WinParty.GUN_BITS do
		if WinParty.shot(1, i).kind == "star" then
			stars += 1
		end
	end
	truthy(stars >= 2 and stars <= 8, "a few gold ones")
end)

test("paper falls slowly and every bit leaves the screen", function()
	local bits = { WinParty.drop(0.3, 0.5, 0.9) }
	for i = 1, WinParty.GUN_BITS do
		table.insert(bits, WinParty.shot(1, i))
		table.insert(bits, WinParty.shot(-1, i))
	end
	for _, b in bits do
		local t = 0
		while not WinParty.gone(b) do
			WinParty.step(b, 1 / 30)
			t += 1 / 30
			truthy(b.vy <= b.term + 1e-9, "never faster than paper falls")
			truthy(t < 12, "a bit hangs in the air for good")
		end
	end
end)

test("the pool holds both guns plus the rain", function()
	truthy(WinParty.POOL >= 2 * WinParty.GUN_BITS + 10)
	truthy(WinParty.ALIVE_MAX <= WinParty.POOL)
	local d = WinParty.drop(0, 0, 0)
	truthy(d.x >= 0 and d.y < 0 and d.vy > 0)
	local e = WinParty.drop(1, 1, 1)
	truthy(e.x <= WinParty.W)
end)
