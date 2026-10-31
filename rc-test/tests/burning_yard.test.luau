--!strict
-- The Burning Yard look (shared/BurningYard): the burning piles and their barrier rows sit open,
-- flat and far from every start spot, box, hazard and crate; the towers stand outside the wall;
-- nothing in this look glows.
local H = require("./harness")
local B = require("../src/shared/BurningYard")
local A = require("../src/shared/ArenaData")
local Barrels = require("../src/shared/Barrels")
local RollBarrels = require("../src/shared/RollBarrels")
local FirePits = require("../src/shared/FirePits")
local BreakCrates = require("../src/shared/BreakCrates")
local Crane = require("../src/shared/Crane")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Burning Yard")

local function dist(a: { number }, b: { number }): number
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
end

-- every spot of a pile and its barrier row (picture units)
local function spotsOf(p: { x: number, y: number, along: { number } }): { { number } }
	return {
		{ p.x, p.y },
		{ p.x + p.along[1] * B.BARRIER_GAP, p.y + p.along[2] * B.BARRIER_GAP },
		{ p.x + p.along[1] * (B.BARRIER_GAP + 6), p.y + p.along[2] * (B.BARRIER_GAP + 6) },
	}
end

test("piles and barrier rows are open and flat", function()
	for i, p in B.PILES do
		for j, s in spotsOf(p) do
			truthy(A.clear(s[1], s[2], 4), `pile {i} spot {j} is not open`)
			eq(A.groundAt(s :: any), 0, `pile {i} spot {j} is not on flat ground`)
		end
	end
end)

test("piles keep clear of starts, boxes, hazards and crates", function()
	local sets: { [string]: { { number } } } = {
		start = A.START :: any,
		box = A.BOXES :: any,
		keg = Barrels.SPOTS,
		drum = RollBarrels.SPOTS,
		pit = FirePits.SPOTS,
		crate = BreakCrates.SPOTS,
		crane = { Crane.SPOT },
	}
	local need: { [string]: number } = {
		start = 20,
		box = 14,
		keg = 20,
		drum = 16,
		pit = 24,
		crate = 16,
		crane = 24,
	}
	for kind, list in sets do
		for i, p in B.PILES do
			for j, s in list do
				local d = dist({ p.x, p.y }, s)
				truthy(d >= need[kind], `pile {i} and {kind} {j} are {math.floor(d)} apart`)
			end
		end
	end
end)

test("barrier rows stay off starts and boxes", function()
	for i, p in B.PILES do
		for _, s in spotsOf(p) do
			for _, st in A.START do
				truthy(dist(s, st :: any) >= 12, `pile {i} barriers sit on a start spot`)
			end
			for _, bx in A.BOXES do
				truthy(dist(s, bx :: any) >= 10, `pile {i} barriers sit on a box`)
			end
		end
	end
end)

test("piles are spread apart", function()
	for i = 1, #B.PILES do
		for j = i + 1, #B.PILES do
			local a, b = B.PILES[i], B.PILES[j]
			truthy(dist({ a.x, a.y }, { b.x, b.y }) >= 60, `piles {i} and {j} are close`)
		end
	end
end)

test("towers stand outside the wall, one at each corner", function()
	eq(#B.TOWERS, 4)
	for i, t in B.TOWERS do
		truthy(t[1] < 0 or t[1] > A.PIC, `tower {i} x is inside the wall`)
		truthy(t[2] < 0 or t[2] > A.PIC, `tower {i} y is inside the wall`)
	end
end)

return nil
