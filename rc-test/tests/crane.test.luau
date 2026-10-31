--!strict
-- The swinging crane ball (shared/Crane): the swing clock, who it hits, cooldown, shove, and the
-- crane's spot (open, flat, off the starts, boxes and kegs).
local H = require("./harness")
local C = require("../src/shared/Crane")
local B = require("../src/shared/Barrels")
local A = require("../src/shared/ArenaData")
local TrackData = require("../src/shared/TrackData")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near

print("Crane ball")

local v = vector.create
local S = C.SCALE
local foot = v(0, 0, 0)
-- big units -> studs: a kart on the floor at lane x
local function kart(id: number, x: number, z: number?, y: number?): C.Kart
	return { id = id, position = v(x * S, (y or 1.5) * S, (z or 0) * S), alive = true }
end

test("scale matches the arena's RC scale", function()
	eq(C.SCALE, TrackData.RC_SCALE)
end)

test("the ball swings there and back: straight down at t=0, widest at a quarter period", function()
	near(C.angle(0), 0)
	near(C.angle(C.PERIOD / 4), C.AMP)
	near(C.angle(C.PERIOD / 2), 0, 1e-9)
	near(C.angle(C.PERIOD * 3 / 4), -C.AMP)
	near(C.angle(C.PERIOD), 0, 1e-9)
	local lo = C.ball(foot, 0)
	near(lo.y / S, C.PIVOT_H - C.CHAIN, 1e-6, "lowest in the middle")
	local hi = C.ball(foot, C.PERIOD / 4)
	truthy(hi.y > lo.y and hi.x > 0, "swung up and east")
	truthy(C.ball(foot, C.PERIOD * 3 / 4).x < 0, "and west")
end)

test("way: east on the way out, west on the way back", function()
	eq(C.way(0.1), 1)
	eq(C.way(C.PERIOD / 2 + 0.1), -1)
end)

test("the ball is low enough to hit a kart only near the middle of the lane", function()
	local st = C.newState()
	-- ball at the bottom (t = 0): a kart under it is hit
	eq(#C.step(st, foot, { kart(1, 0) }, 0), 1)
	-- widest swing: ball high up, a kart under it is safe
	local st2 = C.newState()
	eq(#C.step(st2, foot, { kart(1, math.sin(C.AMP) * C.CHAIN) }, C.PERIOD / 4), 0)
	-- the far end of the lane at ground level is never reached
	local reach = math.sin(C.AMP) * C.CHAIN
	for i = 0, 400 do
		local t = i * 0.01
		eq(#C.step(C.newState(), foot, { kart(1, reach + C.HIT_R + 1) }, t), 0)
	end
end)

test("a hit: damage, shove along the way it goes, then a cooldown", function()
	local st = C.newState()
	local hits = C.step(st, foot, { kart(1, 0) }, 0.05)
	eq(#hits, 1)
	eq(hits[1].damage, C.DAMAGE)
	truthy(hits[1].shove.x > 0 and hits[1].shove.y >= 0, "east, a little up")
	truthy(vector.magnitude(hits[1].shove) <= C.KNOCK_MAX + C.KNOCK_UP)
	eq(#C.step(st, foot, { kart(1, 0) }, 0.1), 0, "no second hit in the cooldown")
	-- coming back west half a period later
	local back = C.step(st, foot, { kart(1, 0) }, C.PERIOD / 2 + 0.05)
	eq(#back, 1)
	truthy(back[1].shove.x < 0, "west on the way back")
end)

test("smashed karts and karts flying above are not hit", function()
	local dead = kart(1, 0)
	dead.alive = false
	eq(#C.step(C.newState(), foot, { dead }, 0), 0)
	eq(#C.step(C.newState(), foot, { kart(2, 0, 0, 40) }, 0), 0, "flying over")
	eq(#C.step(C.newState(), foot, { kart(3, 0, 20) }, 0), 0, "outside the lane's depth")
end)

test("reset lets a kart be hit again at once", function()
	local st = C.newState()
	C.step(st, foot, { kart(1, 0) }, 0)
	C.reset(st)
	eq(#C.step(st, foot, { kart(1, 0) }, 0.1), 1)
end)

test("three swings do not smash a full-health kart at once", function()
	truthy(C.DAMAGE * 3 >= 90 and C.DAMAGE < 50, "one hit never takes half")
end)

test("crane spot: the whole lane is open, flat, off starts, boxes and kegs", function()
	local reachP = C.reach() / A.K
	local halfW = C.LANE_W / A.K
	local p0 = C.SPOT
	local function dist(a: { number }, b: { number }): number
		return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
	end
	local dx = -reachP
	while dx <= reachP do
		for _, dy in { -halfW - 2, 0, halfW + 2 } do
			local p = { p0[1] + dx, p0[2] + dy }
			truthy(A.clear(p[1], p[2], 5), `lane point {dx},{dy} is blocked`)
			truthy(math.abs(A.groundAt(p :: any)) < 0.01, `lane point {dx},{dy} is not flat`)
			for _, s in A.START do
				truthy(dist(p, s) >= 14, "too close to a start spot")
			end
			for _, b in A.BOXES do
				truthy(dist(p, b) >= 8, "too close to a box")
			end
			for _, k in B.SPOTS do
				truthy(dist(p, k) >= B.RADIUS / A.K + 4, "inside a keg's ring")
			end
		end
		dx += 3
	end
end)
