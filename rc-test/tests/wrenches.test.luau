--!strict
-- The health wrenches (shared/Wrenches, Match.heal): only a hurt live kart on a wrench takes it, it
-- heals 40%, it is gone 25 s and then back, and the three spots keep clear of everything else.
local H = require("./harness")
local W = require("../src/shared/Wrenches")
local Match = require("../src/shared/Match")
local TrackData = require("../src/shared/TrackData")
local Barrels = require("../src/shared/Barrels")
local RollBarrels = require("../src/shared/RollBarrels")
local FirePits = require("../src/shared/FirePits")
local BreakCrates = require("../src/shared/BreakCrates")
local Crane = require("../src/shared/Crane")
local ArenaData = require("../src/shared/ArenaData")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near

print("Wrenches")

local v = vector.create
local S = W.SCALE
local function new(): W.State
	return W.new({ v(0, 0, 0) })
end
local function kart(id: number, x: number, hurt: boolean?, alive: boolean?): W.Kart
	return { id = id, position = v(x * S, 1 * S, 0), alive = alive ~= false, hurt = hurt ~= false }
end
local function yes(_: any, _: number): boolean
	return true
end

test("scale matches the arena's RC scale", function()
	eq(W.SCALE, TrackData.RC_SCALE)
end)

test("a hurt kart on the wrench takes it; one off the pad does not", function()
	local s = new()
	local taken = W.step(s, { kart(1, W.RADIUS + 3), kart(2, 3) }, 10, yes)
	eq(#taken, 1)
	eq(taken[1].kart, 2)
	eq(s.items[1].up, false)
end)

test("a full-health or smashed kart leaves it", function()
	local s = new()
	eq(#W.step(s, { kart(1, 0, false) }, 10, yes), 0, "full health")
	eq(#W.step(s, { kart(2, 0, true, false) }, 10, yes), 0, "smashed")
	eq(s.items[1].up, true)
end)

test("a kart that can't be mended leaves it for someone else", function()
	local s = new()
	local taken = W.step(s, { kart(1, 0), kart(2, 0) }, 10, function(id: any): boolean
		return id == 2
	end)
	eq(taken[1].kart, 2)
end)

test("a flyer is safe from the pad (too high)", function()
	local s = new()
	local k = kart(1, 0)
	k.position = v(0, 20 * S, 0)
	eq(#W.step(s, { k }, 10, yes), 0)
end)

test("a taken wrench is back after BACK_IN, and shows before it can be taken", function()
	local s = new()
	W.step(s, { kart(1, 0) }, 10, yes)
	eq(#W.step(s, { kart(1, 0) }, 10 + W.BACK_IN - 1, yes), 0, "still gone")
	local t = 10 + W.BACK_IN
	local taken, back = W.step(s, { kart(1, 0) }, t, yes)
	eq(#back, 1)
	eq(#taken, 0, "SHOW_GAP: not taken the moment it is back")
	eq(#W.step(s, { kart(1, 0) }, t + W.SHOW_GAP + 0.01, yes), 1)
end)

test("reset puts every wrench back up", function()
	local s = new()
	W.step(s, { kart(1, 0) }, 10, yes)
	W.reset(s)
	eq(s.items[1].up, true)
	eq(#W.step(s, { kart(1, 0) }, 11, yes), 1)
end)

test("Match.heal gives back 40% of 100 health, never past full", function()
	local m = Match.new(0)
	local k = Match.add(m, 1, "A", true, 0) :: Match.Kart
	eq(Match.heal(m, 1, W.HEAL), 0, "full kart: nothing")
	k.health = 30
	near(Match.heal(m, 1, W.HEAL), 40)
	near(k.health, 70)
	near(Match.heal(m, 1, W.HEAL), 30, 1e-9, "only up to full")
	near(k.health, Match.HEALTH)
end)

test("Match.heal ignores a smashed kart, a stranger and junk", function()
	local m = Match.new(0)
	local k = Match.add(m, 1, "A", true, 0) :: Match.Kart
	k.health, k.alive = 0, false
	eq(Match.heal(m, 1, 0.4), 0)
	eq(Match.heal(m, 99, 0.4), 0)
	k.health, k.alive = 50, true
	eq(Match.heal(m, 1, 0 / 0), 0)
	eq(Match.heal(m, 1, -1), 0)
	eq(k.health, 50)
end)

local function dist(a: { number }, b: { number }): number
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
end

test("the wrench spots keep clear of hazards, crates, boxes and start spots", function()
	truthy(#W.SPOTS >= 2 and #W.SPOTS <= 3, "2 or 3 wrenches")
	local sets: { [string]: { { number } } } = {
		keg = Barrels.SPOTS,
		drum = RollBarrels.SPOTS,
		crate = BreakCrates.SPOTS,
		crane = { Crane.SPOT },
		box = ArenaData.BOXES :: any,
		start = ArenaData.START :: any,
	}
	for i, w in W.SPOTS do
		for name, list in sets do
			local need = if name == "start" then 14 elseif name == "box" then 10 else 16
			for j, p in list do
				truthy(dist(w, p) >= need, `wrench {i} is {math.floor(dist(w, p))} from {name} {j}`)
			end
		end
		for j, p in FirePits.SPOTS do
			truthy(dist(w, p) >= 24, `wrench {i} is too near fire pit {j}`)
		end
		for j, other in W.SPOTS do
			if j > i then
				truthy(dist(w, other) >= 80, `wrench {i} and {j} are too close together`)
			end
		end
	end
end)

return nil
