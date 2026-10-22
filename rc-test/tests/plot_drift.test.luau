--!strict
-- Tests for the drift plot only (Plots/Drift.luau). The shared rules are in plots.test.
local H = require("./harness")
local Kit = require("../src/shared/Plots/Kit")
local Plot = require("../src/shared/Plots/Drift")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Plot: drift")

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

test("drift plot is free driving, slidey, no timer", function()
	eq(Plot.id, "drift")
	eq(Plot.mode, "free")
	eq(#Plot.gates, 0)
	truthy(Plot.grip < 0.6, "drift floor should be slidey")
end)

test("road is wide enough for long slides", function()
	truthy(Plot.ROAD >= 48, "road too narrow")
end)

test("drift loop does not touch itself", function()
	truthy(closestApproach(Plot.loop(), 10) > Plot.ROAD + 6, "too close")
end)

test("both road edges stay inside the track area", function()
	local half = Plot.ROAD / 2
	for i, s in Plot.loop() do
		for _, side in { -1, 1 } do
			local x, z = s.x - s.tz * half * side, s.z + s.tx * half * side
			truthy(Kit.inArea(x, z), `road edge at sample {i} ({x}, {z}) is outside`)
		end
	end
end)

test("corners are wide sweepers (no tight hairpins that kill a slide)", function()
	-- turning radius at every sample: step length / change of heading
	local ring = Plot.loop()
	local n = #ring
	local tightest = math.huge
	for i = 1, n do
		local a, b = ring[i], ring[(i % n) + 1]
		local turn = math.acos(math.clamp(a.tx * b.tx + a.tz * b.tz, -1, 1))
		local step = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		if turn > 1e-4 then
			tightest = math.min(tightest, step / turn)
		end
	end
	truthy(tightest >= 30, `tightest corner radius {tightest} is too tight`)
end)

test("drift pad sits inside the loop, clear of the road", function()
	local pad = Plot.PAD
	truthy(Kit.inArea(pad.x - pad.r, pad.z - pad.r) and Kit.inArea(pad.x + pad.r, pad.z + pad.r))
	for i, s in Plot.loop() do
		local d = math.sqrt((s.x - pad.x) ^ 2 + (s.z - pad.z) ^ 2)
		truthy(d > pad.r + Plot.ROAD / 2 + 12, `road sample {i} is too close to the pad`)
	end
	truthy(pad.r >= 45, "pad too small to circle the cone")
end)

test(
	"open floor between the road and the outer walls (room to slide wide, camera space)",
	function()
		local half = Plot.ROAD / 2
		local wx, wz = Kit.WIDTH / 2, Kit.DEPTH / 2
		for i, s in Plot.loop() do
			for _, side in { -1, 1 } do
				local x, z = s.x - s.tz * half * side, s.z + s.tx * half * side
				truthy(wx - math.abs(x) >= 22, `road edge at sample {i} is too near a side wall`)
				truthy(z + wz >= 22, `road edge at sample {i} is too near the back wall`)
				truthy(Kit.FRONT_Z - z >= 20, `road edge at sample {i} is too near the front wall`)
			end
		end
	end
)

test("car starts on the front straight, facing along the road to the right", function()
	local s = Plot.spawn
	truthy(s.z > 60, "spawn should be on the front straight")
	truthy(s.dx > 0.9, "spawn should face right along the front straight")
	eq(s.y, 2.5)
end)
