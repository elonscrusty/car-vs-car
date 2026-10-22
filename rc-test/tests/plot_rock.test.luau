--!strict
-- Tests for the rock plot only (Plots/Rock.luau). The shared rules are in plots.test.
local H = require("./harness")
local Plot = require("../src/shared/Plots/Rock")

local test, truthy = H.test, H.truthy

print("Plot: rock")

test("rock plot loads", function()
	truthy(Plot.id == "rock")
end)

test("rock course: heights climb, rocks stay on the course and apart", function()
	truthy(Plot.height(200) == 0)
	truthy(Plot.height(-200) == 60)
	truthy(Plot.height(0) > Plot.height(50))
	local rocks = Plot.rocks()
	truthy(#rocks >= 40, "too few rocks")
	for _, r in rocks do
		truthy(math.abs(r.x) <= Plot.HALF_WIDTH - 2)
	end
	for i = 1, #rocks do
		for j = i + 1, #rocks do
			local a, b = rocks[i], rocks[j]
			local d = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
			truthy(d > a.r + b.r + 4, "rocks too close")
		end
	end
end)
