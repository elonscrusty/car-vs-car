--!strict
-- The tiny match goal (carter 10-31 pick 3): the next step above your smashes, calm at the end.
local H = require("./harness")
local MatchGoal = require("../src/shared/MatchGoal")

local test, eq, truthy = H.test, H.eq, H.truthy

print("MatchGoal")

test("match goal: starts at SMASH 1, then 3, 5, 8, then NICE!", function()
	eq(MatchGoal.read(0).words, "SMASH 1")
	eq(MatchGoal.read(1).words, "SMASH 3")
	eq(MatchGoal.read(2).words, "SMASH 3")
	eq(MatchGoal.read(3).words, "SMASH 5")
	eq(MatchGoal.read(7).words, "SMASH 8")
	eq(MatchGoal.read(8).words, "NICE!")
	eq(MatchGoal.read(40).done, true)
end)

test("match goal: the bar fills toward the step and never leaves 0..1", function()
	eq(MatchGoal.read(0).f, 0)
	truthy(math.abs(MatchGoal.read(2).f - 2 / 3) < 1e-9)
	eq(MatchGoal.read(99).f, 1)
end)

test("match goal: junk smashes count as 0", function()
	eq(MatchGoal.read(nil).words, "SMASH 1")
	eq(MatchGoal.read("x").words, "SMASH 1")
	eq(MatchGoal.read(-5).words, "SMASH 1")
	eq(MatchGoal.read(0 / 0).words, "SMASH 1")
end)
