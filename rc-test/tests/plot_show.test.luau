--!strict
-- Tests for the show plot only (Plots/Show.luau). The shared rules are in plots.test.
local H = require("./harness")
local Plot = require("../src/shared/Plots/Show")

local test, truthy = H.test, H.truthy

print("Plot: show")

test("show plot loads", function()
	truthy(Plot.id == "show")
end)
