--!strict
-- The dynamite kegs (shared/Barrels): the damage line, the shove, touch -> fuse -> boom, chains,
-- grow-back, flying karts, weapon fx, and the keg spots (open, flat, far from starts and boxes).
local H = require("./harness")
local B = require("../src/shared/Barrels")
local A = require("../src/shared/ArenaData")
local TrackData = require("../src/shared/TrackData")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near

print("Dynamite kegs")

local v = vector.create
local S = B.SCALE
-- big units -> studs on the floor at (x, 0, z)
local function at(x: number, z: number): vector
	return v(x * S, 0, z * S)
end
local function kart(id: number, x: number, z: number, y: number?): B.Kart
	return { id = id, position = v(x * S, (y or 1) * S, z * S), alive = true }
end

test("scale matches the arena's RC scale", function()
	eq(B.SCALE, TrackData.RC_SCALE)
end)

test("damage: most in the middle, least at the edge, none outside", function()
	near(B.damage(0), B.DAMAGE_MAX)
	near(B.damage(B.RADIUS), B.DAMAGE_MIN)
	eq(B.damage(B.RADIUS + 0.01), 0)
	truthy(B.damage(3) > B.damage(6) and B.damage(6) > B.damage(10), "falls off")
	truthy(B.DAMAGE_MAX < 100 / 2, "one keg never smashes a full-health kart")
	eq(B.damage(0 / 0), 0)
end)

test("shove: away from the keg, a little lift, never over the cap, none outside", function()
	local s = B.shove(at(0, 0), at(5, 0))
	truthy(s.x > 0 and math.abs(s.z) < 1e-6 and s.y > 0, "away (+x) and up")
	truthy(vector.magnitude(s) <= B.KNOCK_MAX + B.KNOCK_UP)
	eq(vector.magnitude(B.shove(at(0, 0), at(B.RADIUS + 1, 0))), 0)
	-- right on top of it: still a shove (some direction), not NaN
	local top = B.shove(at(0, 0), at(0, 0))
	truthy(top.x == top.x and vector.magnitude(top) > 0)
	truthy(
		vector.magnitude(B.shove(at(0, 0), at(2, 0)))
			> vector.magnitude(B.shove(at(0, 0), at(11, 0)))
	)
end)

test("a touched keg burns for the fuse, then goes off and hurts the ring", function()
	local kegs = { B.newKeg(at(0, 0)) }
	local karts = { kart(1, 2, 0), kart(2, 8, 0), kart(3, 30, 0) }
	eq(#B.step(kegs, karts, 10), 0, "lit, not off yet")
	truthy(kegs[1].litAt == 10, "lit at 10")
	eq(kegs[1].owner, 1, "the kart that touched it gets the credit")
	eq(#B.step(kegs, karts, 10 + B.FUSE - 0.05), 0, "still burning")
	local booms = B.step(kegs, karts, 10 + B.FUSE)
	eq(#booms, 1)
	eq(booms[1].owner, 1)
	local ids = {}
	for _, h in booms[1].hurt do
		ids[h.id] = h.damage
	end
	truthy(ids[1] and ids[2], "both karts in the ring are hurt")
	eq(ids[3], nil, "the far kart is not")
	truthy(ids[1] > ids[2], "closer = more")
	truthy(not kegs[1].up, "the keg is gone")
	eq(#B.step(kegs, karts, 10 + B.FUSE + 0.1), 0, "one boom only")
end)

test("a kart that drives away in the fuse takes less (or nothing)", function()
	local kegs = { B.newKeg(at(0, 0)) }
	local k = kart(1, 2, 0)
	B.step(kegs, { k }, 0)
	k.position = at(40, 0) + v(0, S, 0)
	local booms = B.step(kegs, { k }, B.FUSE)
	eq(#booms[1].hurt, 0)
end)

test("a kart flying over it does not touch it or feel the boom", function()
	local kegs = { B.newKeg(at(0, 0)) }
	B.step(kegs, { kart(1, 0, 0, B.REACH_UP + 4) }, 0)
	eq(kegs[1].litAt, nil, "not lit by a flyer")
	B.light(kegs[1], 0, nil)
	local booms = B.step(kegs, { kart(1, 0, 0, B.BLAST_UP + 4) }, B.FUSE)
	eq(#booms[1].hurt, 0)
end)

test("smashed karts neither light nor take it", function()
	local kegs = { B.newKeg(at(0, 0)) }
	local dead = kart(1, 0, 0)
	dead.alive = false
	B.step(kegs, { dead }, 0)
	eq(kegs[1].litAt, nil)
	B.light(kegs[1], 0, nil)
	eq(#B.step(kegs, { dead }, B.FUSE)[1].hurt, 0)
end)

test("a boom lights the keg beside it with the short fuse (chain)", function()
	local kegs = { B.newKeg(at(0, 0)), B.newKeg(at(8, 0)), B.newKeg(at(60, 0)) }
	B.light(kegs[1], 0, 7)
	eq(#B.step(kegs, {}, B.FUSE), 1)
	truthy(kegs[2].litAt ~= nil, "the near keg caught")
	eq(kegs[2].owner, 7, "the chain keeps the first spark's credit")
	eq(kegs[3].litAt, nil, "the far keg did not")
	eq(#B.step(kegs, {}, B.FUSE + B.CHAIN_FUSE - 0.05), 0)
	eq(#B.step(kegs, {}, B.FUSE + B.CHAIN_FUSE), 1)
end)

test("it grows back after RESPAWN, and a round reset puts it back at once", function()
	local k = B.newKeg(at(0, 0))
	B.light(k, 0, nil)
	B.step({ k }, {}, B.FUSE)
	truthy(not k.up)
	B.step({ k }, {}, B.FUSE + B.RESPAWN - 1)
	truthy(not k.up, "still gone")
	B.step({ k }, {}, B.FUSE + B.RESPAWN)
	truthy(k.up, "back")
	B.light(k, 100, nil)
	B.reset(k)
	truthy(k.up and k.litAt == nil)
end)

test("lighting twice keeps the first owner", function()
	local k = B.newKeg(at(0, 0))
	truthy(B.light(k, 0, 1))
	truthy(not B.light(k, 0.1, 2))
	eq(k.owner, 1)
end)

test(
	"weapon fx: a rocket or mine boom near a keg lights it; a quiet one or a far one does not",
	function()
		local kegs = { B.newKeg(at(0, 0)) }
		eq(B.lightFromFx(kegs, "RocketBoom", { pos = at(30, 0), owner = 4 }, 1), 0)
		eq(B.lightFromFx(kegs, "RocketBoom", { pos = at(2, 0), quiet = true }, 1), 0)
		eq(B.lightFromFx(kegs, "RocketBoom", { pos = at(4, 0), owner = 4 }, 1), 1)
		eq(kegs[1].owner, 4)
		local k2 = { B.newKeg(at(0, 0)) }
		eq(B.lightFromFx(k2, "MineBoom", { position = at(3, 3), owner = 9 }, 1), 1)
		eq(B.lightFromFx(k2, "MineBoom", "junk", 1), 0)
		eq(B.lightFromFx(k2, "Nope", { pos = at(0, 0) }, 1), 0)
	end
)

test("weapon fx: a bullet through a keg lights it; one that misses does not", function()
	local k = { B.newKeg(at(0, 0)) }
	local y = v(0, 2.5 * S, 0)
	eq(B.lightFromFx(k, "GunShot", { from = at(-20, 0) + y, to = at(20, 0) + y, owner = 5 }, 1), 1)
	eq(k[1].owner, 5)
	local k2 = { B.newKeg(at(0, 0)) }
	eq(B.lightFromFx(k2, "GunShot", { from = at(-20, 9) + y, to = at(20, 9) + y }, 1), 0)
	-- a bullet that stops short of it
	eq(B.lightFromFx(k2, "GunShot", { from = at(-20, 0) + y, to = at(-10, 0) + y }, 1), 0)
end)

test("keg spots: open, flat, off the starts and boxes, apart from each other", function()
	eq(#B.SPOTS, 6)
	local function dist(a: { number }, b: { number }): number
		return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
	end
	for i, p in B.SPOTS do
		truthy(A.clear(p[1], p[2], 7), `keg {i} has room round it`)
		for dx = -8, 8, 4 do
			for dy = -8, 8, 4 do
				eq(
					A.groundAt({ p[1] + dx, p[2] + dy }) < 0.01,
					true,
					`keg {i} stands on flat ground`
				)
			end
		end
		for _, s in A.START do
			truthy(
				dist(p, s) >= 30,
				`keg {i} is {dist(p, s)} from a start spot (the ring is {B.RADIUS / A.K})`
			)
		end
		for _, b in A.BOXES do
			truthy(dist(p, b) >= 14, `keg {i} is too close to a "?" box`)
		end
		for j = i + 1, #B.SPOTS do
			truthy(dist(p, B.SPOTS[j]) >= 25, `keg {i} and {j} are too close`)
		end
	end
end)

test("the ring never reaches a start spot (no spawn camping)", function()
	local ring = B.RADIUS / A.K -- picture units
	for _, p in B.SPOTS do
		for _, s in A.START do
			truthy(math.sqrt((p[1] - s[1]) ^ 2 + (p[2] - s[2]) ^ 2) > ring * 3)
		end
	end
end)
