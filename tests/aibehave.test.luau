--!strict
-- Bot brain behaviours: rim guard, nose-to-nose, orbit breaking, boost / ability choices.
local Harness = require("./harness")
local Ai = require("../src/shared/Ai")
local GameConfig = require("../src/shared/GameConfig")

local test, eq, truthy = Harness.test, Harness.eq, Harness.truthy

print("Ai behaviour")

local P = GameConfig.Ai
local C = { x = 0, z = 0 }
local me = { x = 0, z = 0 }
local enemy = { x = 0, z = -50 }

test("rim guard: fast and heading out near the edge = brake with the nose kept", function()
	local mem = Ai.newMemory("Direct", 1)
	mem.vx, mem.vz = 0, -100 -- going out along -Z
	mem.fx, mem.fz = 0, -1
	local c = Ai.decide("Direct", { x = 0, z = -60 }, { x = 0, z = -80 }, mem, 0.016, P, C)
	eq(c.throttle, -1, "reverse gas against the motion")
	truthy(c.tz < -60, "keeps the nose where it is")
	-- backwards-rolling car (nose against the motion) brakes with forward gas instead
	mem.fx, mem.fz = 0, 1
	c = Ai.decide("Direct", { x = 0, z = -60 }, { x = 0, z = -80 }, mem, 0.016, P, C)
	eq(c.throttle, 1)
end)

test("rim guard: coming inward is left alone; outside the ring it turns for the middle", function()
	local mem = Ai.newMemory("Direct", 1)
	mem.vx, mem.vz = 0, 60 -- coming in
	mem.fx, mem.fz = 0, 1
	local c = Ai.decide("Direct", { x = 0, z = -70 }, { x = 0, z = -80 }, mem, 0.016, P, C)
	eq(c.tz, -80, "still chasing")
	mem.vx, mem.vz = 0, 0
	c = Ai.decide("Direct", { x = 0, z = -78 }, { x = 0, z = -84 }, mem, 0.016, P, C)
	eq(c.tz, 0, "target pulls out past the ring: aims at the middle instead")
	eq(c.throttle, 1)
end)

test("rim guard never fires in the middle of the bowl", function()
	local mem = Ai.newMemory("Direct", 1)
	mem.vx, mem.vz = 0, -20
	mem.fx, mem.fz = 0, -1
	local c = Ai.decide("Direct", { x = 0, z = -10 }, { x = 0, z = -40 }, mem, 0.016, P, C)
	eq(c.tz, -40)
end)

test("nose-to-nose with no hit triggers a run-up, sooner for a higher runUp", function()
	local mem = Ai.newMemory("Direct", 1)
	for _ = 1, 8 do
		Ai.decide("Direct", me, { x = 0, z = -6 }, mem, 0.1, P, C)
	end
	eq(mem.retreatT, 0, "not yet")
	local backed = false
	for _ = 1, 8 do
		Ai.decide("Direct", me, { x = 0, z = -6 }, mem, 0.1, P, C)
		backed = backed or mem.retreatT > 0
	end
	truthy(backed, "backed off after closeSeconds")
	local quick = Ai.newMemory("Direct", 1)
	quick.runUp = 3
	local fired = false
	for _ = 1, 6 do
		Ai.decide("Direct", me, { x = 0, z = -6 }, quick, 0.1, P, C)
		fired = fired or quick.retreatT > 0
	end
	truthy(fired, "a high runUp level backs off within 0.6 s")
end)

test("a circler stops circling after commitAfter seconds with no hit", function()
	local mem = Ai.newMemory("CircleDive", 1)
	mem.phase = "circle"
	mem.idle = P.commitAfter + 1
	local c = Ai.decide("CircleDive", me, enemy, mem, 0.016, P, C)
	eq(mem.phase, "dive")
	eq(c.tz, -50, "dives straight at the enemy")
end)

test("turnIn: brakes when the enemy is off to the side inside the turn circle", function()
	local mem = Ai.newMemory("Direct", 1)
	mem.fx, mem.fz = 0, -1
	mem.turnRate = 2.2
	mem.vx, mem.vz = 0, -70
	eq(Ai.turnIn({ x = 0, z = 0 }, { x = 25, z = 0 }, mem, P), -1, "enemy abeam, too fast to turn")
	eq(Ai.turnIn({ x = 0, z = 0 }, { x = 0, z = -40 }, mem, P), 1, "enemy dead ahead")
	mem.vx, mem.vz = 0, -15
	eq(Ai.turnIn({ x = 0, z = 0 }, { x = 25, z = 0 }, mem, P), 1, "slow enough to turn")
end)

test("lead aiming: a long chase with no hit aims ahead of a moving enemy", function()
	local mem = Ai.newMemory("Direct", 1)
	mem.lead = 0.5
	mem.evx, mem.evz = 40, 0
	eq(Ai.decide("Direct", me, enemy, mem, 0.016, P, C).tx, 0, "no lead early on")
	mem.idle = P.leadAfter + 1
	truthy(Ai.decide("Direct", me, enemy, mem, 0.016, P, C).tx > 0, "leads after a while")
end)

test("an orbit gets broken: one car waits in the middle, the other keeps chasing", function()
	local waiter = Ai.newMemory("Direct", 1)
	waiter.idle = P.ambushAfter + 1
	local c = Ai.decide("Direct", { x = 5, z = 5 }, { x = 30, z = 0 }, waiter, 0.016, P, C)
	eq(c.tx, 0)
	eq(c.tz, 0)
	local chaser = Ai.newMemory("Direct", -1)
	chaser.idle = P.ambushAfter + 1
	c = Ai.decide("Direct", { x = 5, z = 5 }, { x = 30, z = 0 }, chaser, 0.016, P, C)
	eq(c.tx, 30)
end)

local function view(over: { [string]: any }): any
	local v: any = {
		now = 10,
		seed = 1,
		dist = 60,
		angle = 0,
		me = { x = 0, z = 30 },
		fx = 0,
		fz = -1,
		center = { x = 0, z = 0 },
		hpShare = 1,
		speed = 40,
		maxSpeed = 72,
		accel = 125,
		dashForward = 70,
		boostReady = true,
		specialReady = true,
		kind = "slam",
		radius = 22,
		moveUse = 1,
	}
	for k, x in over do
		v[k] = x
	end
	return v
end

test(
	"wantMoves: boosts at a far enemy straight ahead, not off to the side, close, cooling or flying",
	function()
		truthy((Ai.wantMoves(view({}), P)), "far enemy dead ahead")
		truthy(not (Ai.wantMoves(view({ angle = 1.2 }), P)), "pointing the wrong way")
		truthy(not (Ai.wantMoves(view({ dist = 8 }), P)), "already close")
		truthy(not (Ai.wantMoves(view({ boostReady = false }), P)), "cooling down")
		truthy(not (Ai.wantMoves(view({ speed = 100 }), P)), "already flying")
	end
)

test("wantMoves: never boosts or dashes toward the rim", function()
	local boost, special =
		Ai.wantMoves(view({ me = { x = 0, z = 70 }, fz = 1, kind = "dash", dist = 40 }), P)
	truthy(not boost, "no boost out of the bowl")
	truthy(not special, "no dash out of the bowl")
	boost, special = Ai.wantMoves(view({ kind = "dash", dist = 40, speed = 30 }), P)
	truthy(boost and special, "the same moves are fine heading in")
end)

test("wantMoves: ability fits its kind, panics when low", function()
	local _, slam = Ai.wantMoves(view({ kind = "slam", dist = 12 }), P)
	truthy(slam, "slam up close")
	_, slam = Ai.wantMoves(view({ kind = "slam", dist = 50 }), P)
	truthy(not slam, "slam from far away")
	local _, magnet = Ai.wantMoves(view({ kind = "magnet", radius = 40, dist = 25 }), P)
	truthy(magnet, "magnet at mid range")
	local _, ram = Ai.wantMoves(view({ kind = "ram", dist = 30 }), P)
	truthy(ram, "ram when close and aimed")
	local _, jump = Ai.wantMoves(view({ kind = "jump", dist = 10 }), P)
	truthy(not jump, "jump kept for emergencies")
	_, jump = Ai.wantMoves(view({ kind = "jump", dist = 10, hpShare = 0.2 }), P)
	truthy(jump, "...which this is")
	local _, shield = Ai.wantMoves(view({ kind = "shield", dist = 28 }), P)
	truthy(shield)
	local _, none = Ai.wantMoves(view({ kind = "", dist = 10 }), P)
	truthy(not none, "no ability, nothing to press")
	_, slam = Ai.wantMoves(view({ kind = "slam", dist = 12, specialReady = false }), P)
	truthy(not slam, "cooling down")
end)

test("wantMoves: moveUse 0 never acts, higher moveUse acts more often", function()
	local acts = { 0, 0, 0 }
	for i, use in { 0, 0.3, 1 } do
		for t = 1, 200 do
			local b = Ai.wantMoves(view({ now = t * 0.25, moveUse = use }), P)
			if b then
				acts[i] += 1
			end
		end
	end
	eq(acts[1], 0)
	truthy(acts[2] > 20 and acts[2] < acts[3], "more skill, more boosts")
	eq(acts[3], 200)
end)
