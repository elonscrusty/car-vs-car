--!strict
-- The arena's hazards and props were placed by different pieces (kegs, rolling drums, fire pits,
-- crates, the crane ball's lane). None may sit on another: a drum parked in a fire pit or a crate
-- inside one looks broken. Distances are in arena picture units.
local H = require("./harness")
local Barrels = require("../src/shared/Barrels")
local RollBarrels = require("../src/shared/RollBarrels")
local FirePits = require("../src/shared/FirePits")
local BreakCrates = require("../src/shared/BreakCrates")
local Crane = require("../src/shared/Crane")

local test, truthy = H.test, H.truthy

print("Hazard spacing")

local function dist(a: { number }, b: { number }): number
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
end

local SETS: { [string]: { { number } } } = {
	keg = Barrels.SPOTS,
	drum = RollBarrels.SPOTS,
	pit = FirePits.SPOTS,
	crate = BreakCrates.SPOTS,
	crane = { Crane.SPOT },
}
-- the least gap between two kinds (a fire pit's ring is wide, so it keeps the most room)
local GAP = {
	["keg/drum"] = 20,
	["keg/pit"] = 20,
	["keg/crate"] = 18,
	["keg/crane"] = 18,
	["drum/pit"] = 20,
	["drum/crate"] = 14,
	["drum/crane"] = 18,
	["pit/crate"] = 18,
	["pit/crane"] = 22,
	["crate/crane"] = 10,
}

test("no hazard or crate sits on another one", function()
	for pair, need in GAP do
		local a, b = string.match(pair, "^(%w+)/(%w+)$")
		for i, p in SETS[a :: string] do
			for j, q in SETS[b :: string] do
				local d = dist(p, q)
				truthy(d >= need, `{a} {i} and {b} {j} are {math.floor(d)} apart (need {need})`)
			end
		end
	end
end)

return nil
