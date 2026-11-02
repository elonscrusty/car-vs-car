--!strict
-- The fire pits (shared/FirePits): burn ticks, flares, flyers, and the pit spots (open, flat,
-- far from the starts, boxes and dynamite kegs).
local H = require("./harness")
local F = require("../src/shared/FirePits")
local B = require("../src/shared/Barrels")
local A = require("../src/shared/ArenaData")
local TrackData = require("../src/shared/TrackData")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Fire pits")

local v = vector.create
local S = F.SCALE
local function kart(id: number, x: number, z: number, y: number?): F.Kart
	return { id = id, position = v(x * S, (y or 1) * S, z * S), alive = true }
end
local function new(): F.State
	return F.new({ v(0, 0, 0) })
end

test("scale matches the arena's RC scale", function()
	eq(F.SCALE, TrackData.RC_SCALE)
end)

test("a kart on the pit burns; one outside does not", function()
	local s = new()
	local hurt = F.step(s, { kart(1, 3, 0), kart(2, F.RADIUS + 1, 0) }, 0)
	eq(#hurt, 1)
	eq(hurt[1].id, 1)
	eq(hurt[1].damage, F.BURN)
end)

test("burns tick every BURN_EVERY, not faster", function()
	local s = new()
	local k = { kart(1, 0, 0) }
	eq(#F.step(s, k, 0), 1)
	eq(#F.step(s, k, F.BURN_EVERY - 0.1), 0, "too soon")
	eq(#F.step(s, k, F.BURN_EVERY), 1, "next tick")
end)

test("sitting on a pit for 5 s hurts but never smashes a full kart", function()
	local s = new()
	local k = { kart(1, 0, 0) }
	local total = 0
	for i = 0, 49 do
		for _, h in F.step(s, k, i * 0.1) do
			total += h.damage
		end
	end
	truthy(total >= 20 and total < 100, `5 s of burning took {total}`)
end)

test("flares: last FLARE_LEN of each period, warned just before, hit harder", function()
	truthy(not F.flaring(0))
	truthy(not F.flaring(F.PERIOD - F.FLARE_LEN - 0.01))
	truthy(F.flaring(F.PERIOD - F.FLARE_LEN))
	truthy(F.flaring(F.PERIOD - 0.01))
	truthy(not F.flaring(F.PERIOD), "next period starts calm")
	truthy(F.flaring(F.PERIOD * 3 + F.PERIOD - 1))
	truthy(F.warning(F.PERIOD - F.FLARE_LEN - 0.5))
	truthy(not F.warning(F.PERIOD - 0.5))
	truthy(not F.warning(1))
	truthy(F.burn(F.PERIOD - 1) > F.burn(1))
	eq(F.step(new(), { kart(1, 0, 0) }, F.PERIOD - 1)[1].damage, F.BURN_FLARE)
end)

test("a kart flying over, or smashed, does not burn", function()
	local s = new()
	eq(#F.step(s, { kart(1, 0, 0, F.REACH_UP + 4) }, 0), 0)
	local dead = kart(2, 0, 0)
	dead.alive = false
	eq(#F.step(s, { dead }, 0), 0)
end)

test("two pits under one kart burn it once", function()
	local s = F.new({ v(0, 0, 0), v(1 * S, 0, 0) })
	eq(#F.step(s, { kart(1, 0.5, 0) }, 0), 1)
end)

test("reset forgets the burn clock", function()
	local s = new()
	F.step(s, { kart(1, 0, 0) }, 0)
	F.reset(s)
	eq(#F.step(s, { kart(1, 0, 0) }, 0.1), 1)
end)

test("pit spots: open, flat, off the starts, boxes, kegs and each other", function()
	eq(#F.SPOTS, 4)
	local function dist(a: { number }, b: { number }): number
		return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
	end
	for i, p in F.SPOTS do
		truthy(A.clear(p[1], p[2], 7), `pit {i} has room round it`)
		for dx = -8, 8, 4 do
			for dy = -8, 8, 4 do
				eq(A.groundAt({ p[1] + dx, p[2] + dy }) < 0.01, true, `pit {i} is on flat ground`)
			end
		end
		for _, st in A.START do
			truthy(dist(p, st) >= 30, `pit {i} is too close to a start spot`)
		end
		for _, b in A.BOXES do
			truthy(dist(p, b) >= 14, `pit {i} is too close to a "?" box`)
		end
		for _, k in B.SPOTS do
			truthy(dist(p, k) >= 25, `pit {i} is too close to a keg`)
		end
		for j = i + 1, #F.SPOTS do
			truthy(dist(p, F.SPOTS[j]) >= 40, `pits {i} and {j} are too close`)
		end
	end
end)

test("a spawn never lands in a ring (no spawn camping)", function()
	local ring = F.RADIUS / A.K
	for _, p in F.SPOTS do
		for _, st in A.START do
			truthy(math.sqrt((p[1] - st[1]) ^ 2 + (p[2] - st[2]) ^ 2) > ring * 3)
		end
	end
end)
