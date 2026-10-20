--!strict
local H = require("./harness")
local BattleBrain = require("../src/shared/BattleBrain")
local BattleConfig = require("../src/shared/BattleConfig")
local BattleCrash = require("../src/shared/BattleCrash")
local BowlLayout = require("../src/shared/BowlLayout")
local Sim = require("./battlesim")

print("Bowl fights (bots, round wall, crusher base)")

local FIGHTERS = { "RamTruck", "CannonVan", "SawBuggy" }

H.test("the bots are told about the round wall and the crusher's base", function()
	local arena = Sim.bowl()
	H.eq(arena.radius, BowlLayout.wallRadius)
	local circles = arena.circles or {}
	H.eq(#circles, 1)
	H.near(circles[1].r, BowlLayout.crusher.baseRadius, 1e-9)
end)

H.test("a straight line through the crusher base is blocked, one beside it is not", function()
	local arena = Sim.bowl()
	local pad = 3
	local lane = BowlLayout.laneZ
	local r = BowlLayout.crusher.baseRadius
	-- through the middle
	H.truthy(BattleBrain.lineBlocked(arena, -60, 0, 60, 0, pad))
	-- along the lane the cars charge down: clear of the base
	H.eq(BattleBrain.lineBlocked(arena, -64, lane, 64, lane, pad), false)
	-- a line that stops short of the base
	H.eq(BattleBrain.lineBlocked(arena, -60, 0, -20, 0, pad), false)
	-- grazing the base: the pad counts
	H.truthy(BattleBrain.lineBlocked(arena, -60, r + pad - 1, 60, r + pad - 1, pad))
	H.eq(BattleBrain.lineBlocked(arena, -60, r + pad + 1, 60, r + pad + 1, pad), false)
	-- the old box arena has no circles: nothing changes there
	H.eq(BattleBrain.lineBlocked(Sim.arena(), -60, 0, 60, 0, pad), false)
end)

H.test("out of the arena: a circle on the bowl, a box elsewhere", function()
	local R = BowlLayout.wallRadius
	local inCorner, pastCorner = R * 0.7, R * 0.8
	H.eq(BattleCrash.outside(0, 0, 1, R, R, R), false)
	H.eq(BattleCrash.outside(R - 5, 0, 1, R, R, R), false)
	-- the corner of the box is out past the circle's edge only when it is really past it
	H.eq(BattleCrash.outside(inCorner, inCorner, 1, R, R, R), false)
	H.eq(BattleCrash.outside(pastCorner, pastCorner, 1, R, R, R), true)
	H.eq(BattleCrash.outside(R + 3, 0, 1, R, R, R), true)
	-- below the floor is out on both
	H.eq(BattleCrash.outside(0, 0, -5, R, R, R), true)
	-- without a radius the box rules stay as they were
	H.eq(BattleCrash.outside(pastCorner, pastCorner, 1, R, R), false)
end)

H.test("the bots start on the two pads, far apart, and drive straight at each other", function()
	local ax, az, afx, afz = BowlLayout.spawn("a")
	local bx, bz, bfx, bfz = BowlLayout.spawn("b")
	H.truthy(math.abs(ax - bx) >= 100, "far apart")
	H.near(az, bz, 1e-9)
	H.truthy(afx > 0.99 and afz == 0)
	H.truthy(bfx < -0.99 and bfz == 0)
	local a = Sim.car("RamTruck", ax, az, afx, afz, Sim.bowl())
	local b = Sim.car("SawBuggy", bx, bz, bfx, bfz, Sim.bowl())
	local o = a.brain.step(
		1 / 30,
		{ x = a.x, z = a.z, fx = a.fx, fz = a.fz },
		{ x = b.x, z = b.z, fx = b.fx, fz = b.fz },
		{ ram = false, saw = false }
	)
	H.truthy(o.drive > 0, "gas")
	H.truthy(math.abs(o.turn) < 0.5, "straight at the foe")
end)

type Tally = {
	winsA: number,
	winsB: number,
	draws: number,
	hits: number,
	secs: number,
	wall: number, -- seconds against the wall, all cars, all fights
	base: number, -- seconds on the crusher's base
	maxR: number, -- farthest any car's middle got from the centre
	pinned: number, -- longest stretch in a row against the wall
}

local function tally(idA: string, idB: string, runs: number, seed: number): Tally
	local t: Tally = {
		winsA = 0,
		winsB = 0,
		draws = 0,
		hits = 0,
		secs = 0,
		wall = 0,
		base = 0,
		maxR = 0,
		pinned = 0,
	}
	for i = 1, runs do
		local r = Sim.fight(idA, idB, i % 2 == 0, seed + i, true)
		H.truthy(r.seconds <= BattleConfig.Timing.fightSeconds + 0.1, "fight ends in time")
		H.truthy(r.a.hp >= 0 and r.b.hp >= 0)
		if r.outcome == "a" then
			t.winsA += 1
		elseif r.outcome == "b" then
			t.winsB += 1
		else
			t.draws += 1
		end
		t.hits += r.a.hits + r.b.hits
		t.secs += r.seconds
		t.wall += r.a.wallTime + r.b.wallTime
		t.base += r.a.baseTime + r.b.baseTime
		t.maxR = math.max(t.maxR, r.a.maxR, r.b.maxR)
		t.pinned = math.max(t.pinned, r.a.wallLongest, r.b.wallLongest)
	end
	return t
end

local function tenth(x: number): number
	return math.floor(x * 10) / 10
end

H.test("bowl fights: all six pairings end, land hits, and never leave the wall", function()
	local pairings = {
		{ "RamTruck", "RamTruck" },
		{ "CannonVan", "CannonVan" },
		{ "SawBuggy", "SawBuggy" },
		{ "RamTruck", "CannonVan" },
		{ "RamTruck", "SawBuggy" },
		{ "CannonVan", "SawBuggy" },
	}
	for _, p in pairings do
		local runs = 20
		local t = tally(p[1], p[2], runs, 4000)
		print(
			`       {p[1]} vs {p[2]}: {t.winsA}-{t.winsB} draws {t.draws}, hits {t.hits}, avg {math.floor(
				t.secs / runs
			)} s, on the wall {tenth(t.wall / runs)} s, on the crusher {tenth(t.base / runs)} s`
		)
		H.truthy(t.hits > 0, "weapons landed something")
		H.truthy(t.maxR <= BowlLayout.wallRadius + 0.01, "never past the wall: " .. t.maxR)
	end
end)

H.test("bots do not sit pinned on the wall or hug the crusher", function()
	for _, a in FIGHTERS do
		for _, b in FIGHTERS do
			local runs = 12
			local t = tally(a, b, runs, 9000)
			-- no car stays against the wall for ever (the server frees a stuck car after 3 s anyway),
			-- and the crusher's base is a landmark to drive round, not a place to sit
			H.truthy(t.pinned < 12, `{a} vs {b}: longest stretch on the wall {t.pinned} s`)
			H.truthy(t.wall / runs < 15, `{a} vs {b}: wall {t.wall / runs} s a fight`)
			H.truthy(t.base / runs < 3, `{a} vs {b}: crusher {t.base / runs} s a fight`)
		end
	end
end)
