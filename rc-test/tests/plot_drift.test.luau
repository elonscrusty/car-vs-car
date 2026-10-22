--!strict
-- Tests for the drift plot only (Plots/Drift.luau). The shared rules are in plots.test.
local H = require("./harness")
local Plot = require("../src/shared/Plots/Drift")

local test, truthy = H.test, H.truthy

print("Plot: drift")

test("drift plot loads", function()
	truthy(Plot.id == "drift")
end)
