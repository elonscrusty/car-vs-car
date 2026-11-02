--!strict
-- The rolling barrels (shared/RollBarrels): a shove, friction, bounces, drum-on-drum, flying karts,
-- and the drum spots (open, flat, far from starts, "?" boxes and the dynamite kegs).
local H = require("./harness")
local R = require("../src/shared/RollBarrels")
local B = require("../src/shared/Barrels")
local A = require("../src/shared/ArenaData")
local TrackData = require("../src/shared/TrackData")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Rolling barrels")

local v = vector.create
local S = R.SCALE
local DT = 1 / 20
local function at(x: number, z: number): vector
	return v(x * S, 0, z * S)
end
-- a kart at (x, z) big units doing `speed` big units/s along +x
local function kart(id: number, x: number, z: number, speed: number, y: number?): R.Kart
	return {
		id = id,
		position = v(x * S, (y or 1) * S, z * S),
		velocity = v(speed * S, 0, 0),
		alive = true,
	}
end
local function run(drums: { R.Drum }, karts: { R.Kart }, secs: number, blocked: R.Blocked?)
	for _ = 1, math.round(secs / DT) do
		R.step(drums, karts, DT, S, blocked)
	end
end

test("scale matches the arena's RC scale", function()
	eq(R.SCALE, TrackData.RC_SCALE)
end)

test("a kart driving into a drum sends it rolling the same way", function()
	local d = R.newDrum(at(0, 0))
	R.step({ d }, { kart(1, -4, 0, 15) }, DT, S)
	truthy(d.vel.x > 0 and math.abs(d.vel.z) < 1e-6, "rolls +x")
	truthy(d.vel.x / S >= 15 * R.PUSH - 0.5, "leaves faster than the kart")
	truthy(d.vel.x / S <= R.MAX_SPEED + 1e-6, "never over the cap")
end)

test("a kart that only touches it gives a little nudge, not zero", function()
	local d = R.newDrum(at(0, 0))
	R.step({ d }, { kart(1, -4, 0, 0) }, DT, S)
	truthy(d.vel.x > 0, "nudged")
end)

test("a flying or dead kart does not touch it", function()
	local d = R.newDrum(at(0, 0))
	R.step({ d }, { kart(1, -4, 0, 15, 12) }, DT, S)
	eq(d.vel, vector.zero, "flying over")
	local dead = kart(2, -4, 0, 15)
	dead.alive = false
	R.step({ d }, { dead }, DT, S)
	eq(d.vel, vector.zero, "dead")
end)

test("a drum slows down by itself and stops", function()
	local d = R.newDrum(at(0, 0))
	d.vel = v(20 * S, 0, 0)
	local last = d.vel.x
	for _ = 1, 20 do
		R.step({ d }, {}, DT, S)
		truthy(d.vel.x <= last + 1e-9, "never speeds up")
		last = d.vel.x
	end
	run({ d }, {}, 6)
	eq(d.vel, vector.zero, "stopped")
	eq(d.moving, false)
	local x = d.pos.x
	run({ d }, {}, 1)
	eq(d.pos.x, x, "stays put")
	truthy(d.pos.x / S > 10 and d.pos.x / S < 60, "rolled a sensible way")
end)

test("it spins as it rolls and turns to roll the way it goes", function()
	local d = R.newDrum(at(0, 0))
	d.vel = v(0, 0, 10 * S)
	run({ d }, {}, 0.5)
	truthy(d.spin > 0, "spun")
	truthy(math.abs(d.head - math.pi / 2) < 0.5, "turned toward +z")
end)

test("it bounces off something solid and never goes inside it", function()
	local wall = 20 * S
	local blocked: R.Blocked = function(p)
		return p.x > wall
	end
	local d = R.newDrum(at(0, 0))
	d.vel = v(20 * S, 0, 0)
	for _ = 1, 100 do
		R.step({ d }, {}, DT, S, blocked)
		truthy(d.pos.x <= wall + 1e-6, "stays out of the wall")
	end
	truthy(d.vel.x <= 0, "came back")
end)

test("a kart never pushes a drum into something solid", function()
	local blocked: R.Blocked = function(p)
		return p.x > 2 * S
	end
	local d = R.newDrum(at(1.5, 0))
	R.step({ d }, { kart(1, -2.5, 0, 15) }, DT, S, blocked)
	truthy(d.pos.x <= 2 * S + 1e-6)
end)

test("a rolling drum bumps another and passes it the speed", function()
	local a, b = R.newDrum(at(0, 0)), R.newDrum(at(R.DRUM_R * 2 - 0.5, 0))
	a.vel = v(15 * S, 0, 0)
	R.step({ a, b }, {}, DT, S)
	truthy(b.vel.x > 0, "b moves")
	truthy(a.vel.x < 15 * S, "a gave it up")
	truthy(
		vector.magnitude(b.pos - a.pos) / S >= R.DRUM_R * 2 - 0.01,
		"pushed apart, not inside each other"
	)
end)

test("reset puts every drum back, still", function()
	local d = R.newDrum(at(5, 5))
	d.pos, d.vel, d.spin = at(30, 9), v(3, 0, 0), 12
	R.reset(d)
	eq(d.pos, at(5, 5))
	eq(d.vel, vector.zero)
	eq(d.spin, 0)
end)

test("drum spots: open, flat, far from starts, boxes and kegs", function()
	eq(#R.SPOTS, 3)
	local function dist(a: { number }, b: { number }): number
		return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
	end
	for i, p in R.SPOTS do
		truthy(A.clear(p[1], p[2], 9), `drum {i} has room round it`)
		for dx = -9, 9, 3 do
			for dy = -9, 9, 3 do
				truthy(
					A.groundAt({ p[1] + dx, p[2] + dy }) < 0.01,
					`drum {i} stands on flat ground`
				)
			end
		end
		for _, s in A.START do
			truthy(dist(p, s) >= 28, `drum {i} too close to a start spot`)
		end
		for _, b in A.BOXES do
			truthy(dist(p, b) >= 14, `drum {i} too close to a "?" box`)
		end
		for _, k in B.SPOTS do
			truthy(dist(p, k) >= 24, `drum {i} too close to a keg`)
		end
	end
end)
