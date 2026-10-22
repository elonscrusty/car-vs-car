--!strict
-- Tests for the race plot only (Plots/Race.luau). The shared rules are in plots.test.
local H = require("./harness")
local Plot = require("../src/shared/Plots/Race")

local test, truthy = H.test, H.truthy

print("Plot: race")

test("race plot loads", function()
	truthy(Plot.id == "race")
end)

local function closestApproach(ring: { any }, step: number): number
	-- smallest distance between two parts of the loop that are far apart along the loop
	local best = math.huge
	local n = #ring
	for i = 1, n do
		for j = i + 1, n do
			local gap = math.min(j - i, n - (j - i))
			if gap > step then
				local dx, dz = ring[i].x - ring[j].x, ring[i].z - ring[j].z
				best = math.min(best, math.sqrt(dx * dx + dz * dz))
			end
		end
	end
	return best
end

test("race loop does not touch itself (road width fits)", function()
	truthy(closestApproach(Plot.loop(), 10) > Plot.ROAD + 6, "too close")
end)
