--!strict
-- The breakable crates (shared/BreakCrates): touch / bullet / boom breaks, grow-back, flying karts,
-- weapon fx, and the crate spots (open, flat, off the starts and boxes, apart from each other).
local H = require("./harness")
local C = require("../src/shared/BreakCrates")
local A = require("../src/shared/ArenaData")
local TrackData = require("../src/shared/TrackData")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Breakable crates")

local v = vector.create
local S = C.SCALE
local function at(x: number, z: number): vector
	return v(x * S, 0, z * S)
end
local function kart(id: number, x: number, z: number, y: number?): C.Kart
	return { id = id, position = v(x * S, (y or 1) * S, z * S), alive = true }
end

test("scale matches the arena's RC scale", function()
	eq(C.SCALE, TrackData.RC_SCALE)
end)

test("a touching kart breaks the crate once, a far one does not", function()
	local cr = { C.newCrate(at(0, 0)) }
	eq(#C.step(cr, { kart(1, 30, 0) }, 1), 0)
	truthy(cr[1].up, "still up")
	local b = C.step(cr, { kart(1, 2, 0) }, 2)
	eq(#b, 1)
	eq(b[1], 1)
	truthy(not cr[1].up, "down")
	eq(#C.step(cr, { kart(1, 0, 0) }, 3), 0, "one break only")
end)

test("a flying kart or a dead one does not break it", function()
	local cr = { C.newCrate(at(0, 0)) }
	eq(#C.step(cr, { kart(1, 0, 0, C.REACH_UP + 3) }, 1), 0)
	local dead = kart(2, 0, 0)
	dead.alive = false
	eq(#C.step(cr, { dead }, 1), 0)
	truthy(cr[1].up)
end)

test("it comes back after RESPAWN, not before", function()
	local cr = { C.newCrate(at(0, 0)) }
	C.step(cr, { kart(1, 0, 0) }, 10)
	C.step(cr, {}, 10 + C.RESPAWN - 0.1)
	truthy(not cr[1].up, "not yet")
	C.step(cr, {}, 10 + C.RESPAWN)
	truthy(cr[1].up, "back")
	C.step(cr, { kart(1, 0, 0) }, 10 + C.RESPAWN + 0.1)
	truthy(not cr[1].up, "breakable again")
end)

test("reset puts every crate back", function()
	local cr = { C.newCrate(at(0, 0)), C.newCrate(at(9, 0)) }
	C.hitAt(cr, at(4, 0), 50, 1)
	truthy(not cr[1].up and not cr[2].up)
	for _, c in cr do
		C.reset(c)
	end
	truthy(cr[1].up and cr[2].up and cr[1].backAt == nil)
end)

test("a boom breaks the crates in reach and no others", function()
	local cr = { C.newCrate(at(0, 0)), C.newCrate(at(5, 0)), C.newCrate(at(40, 0)) }
	local b = C.hitAt(cr, at(2, 0), C.HIT_BOOM, 1)
	eq(#b, 2)
	truthy(cr[3].up)
	eq(#C.hitAt(cr, at(2, 0), C.HIT_BOOM, 2), 0, "already down")
end)

test("weapon fx: a bullet through a crate breaks it; a miss or a short one does not", function()
	local y = v(0, C.SIZE / 2 * S, 0)
	local k = { C.newCrate(at(0, 0)) }
	eq(#C.fromFx(k, "GunShot", { from = at(-20, 0) + y, to = at(20, 0) + y }, 1), 1)
	local k2 = { C.newCrate(at(0, 0)) }
	eq(#C.fromFx(k2, "GunShot", { from = at(-20, 9) + y, to = at(20, 9) + y }, 1), 0)
	eq(#C.fromFx(k2, "GunShot", { from = at(-20, 0) + y, to = at(-10, 0) + y }, 1), 0)
	eq(#C.fromFx(k2, "RocketBoom", { pos = at(3, 3) }, 1), 1)
	local k3 = { C.newCrate(at(0, 0)) }
	eq(#C.fromFx(k3, "MineBoom", { position = at(3, 3), quiet = true }, 1), 0, "quiet = no")
	eq(#C.fromFx(k3, "MineBoom", { position = at(3, 3) }, 1), 1)
	eq(#C.fromFx(k3, "Nope", { pos = at(0, 0) }, 1), 0)
	eq(#C.fromFx(k3, "GunShot", "junk", 1), 0)
end)

test("crate spots: open, flat, off the starts and boxes, apart from each other", function()
	eq(#C.SPOTS, 10)
	local function dist(a: { number }, b: { number }): number
		return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
	end
	for i, p in C.SPOTS do
		truthy(A.clear(p[1], p[2], 7), `crate {i} has room round it`)
		for dx = -6, 6, 3 do
			for dy = -6, 6, 3 do
				eq(
					A.groundAt({ p[1] + dx, p[2] + dy }) < 0.01,
					true,
					`crate {i} stands on flat ground`
				)
			end
		end
		for _, s in A.START do
			truthy(dist(p, s) >= 18, `crate {i} is too close to a start spot`)
		end
		for _, b in A.BOXES do
			truthy(dist(p, b) >= 12, `crate {i} is too close to a "?" box`)
		end
		for j = i + 1, #C.SPOTS do
			truthy(dist(p, C.SPOTS[j]) >= 9, `crates {i} and {j} are too close`)
		end
	end
end)
