--!strict
-- Tests for the show plot only (Plots/Show.luau). The shared rules are in plots.test.
local H = require("./harness")
local Kit = require("../src/shared/Plots/Kit")
local Plot = require("../src/shared/Plots/Show")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Plot: show")

test("show plot loads, free drive, normal grip", function()
	eq(Plot.id, "show")
	eq(Plot.mode, "free")
	eq(Plot.grip, 1)
	eq(#Plot.gates, 0)
end)

-- smallest distance from (x, z) to the middle of the loop
local function toLoop(x: number, z: number): number
	local best = math.huge
	for _, s in Plot.loop() do
		best = math.min(best, math.sqrt((s.x - x) ^ 2 + (s.z - z) ^ 2))
	end
	return best
end

test("cruise loop stays inside the area, road edges too", function()
	local half = Plot.ROAD / 2
	for _, s in Plot.loop() do
		truthy(Kit.inArea(s.x - s.tz * half, s.z + s.tx * half), `edge at {s.x}, {s.z}`)
		truthy(Kit.inArea(s.x + s.tz * half, s.z - s.tx * half), `edge at {s.x}, {s.z}`)
	end
end)

test("cruise loop does not touch itself", function()
	local ring = Plot.loop()
	local n = #ring
	local best = math.huge
	for i = 1, n do
		for j = i + 1, n do
			if math.min(j - i, n - (j - i)) > 10 then
				best = math.min(
					best,
					math.sqrt((ring[i].x - ring[j].x) ^ 2 + (ring[i].z - ring[j].z) ^ 2)
				)
			end
		end
	end
	truthy(best > Plot.ROAD + 6, "too close")
end)

test("car starts on the loop, on the front straight", function()
	truthy(toLoop(Plot.spawn.x, Plot.spawn.z) < 1, "spawn is off the road")
	truthy(
		math.abs(Plot.spawn.x) < 10 and Plot.spawn.z > 100,
		"spawn is not in front of the player"
	)
	truthy(Plot.spawn.dx > 0.9, "spawn should face along the front straight")
end)

test("stage sits inside the loop, clear of the road", function()
	local st = Plot.STAGE
	truthy(toLoop(st.x, st.z) - (st.radius + 2) > Plot.ROAD / 2 + 10, "stage too close to the road")
	truthy(st.radius > 5.5, "stage must fit a car")
	truthy(Plot.SPIN_SECONDS >= 8, "stage should spin slowly")
end)

test("8 parked spots, clear of the road, the stage and each other", function()
	eq(#Plot.spots, 8)
	local w, d = Plot.SPOT.w, Plot.SPOT.d
	truthy(w > 3 + 2 and d > 5.5 + 2, "a car must fit in a spot")
	local reach = math.sqrt((w / 2) ^ 2 + (d / 2) ^ 2)
	local st = Plot.STAGE
	for i, p in Plot.spots do
		truthy(toLoop(p.x, p.z) - reach > Plot.ROAD / 2 + 10, `spot {i} too close to the road`)
		truthy(
			math.sqrt((p.x - st.x) ^ 2 + (p.z - st.z) ^ 2) > st.radius + 2 + reach,
			`spot {i} hits the stage`
		)
		for j = i + 1, #Plot.spots do
			local q = Plot.spots[j]
			truthy(
				math.abs(p.x - q.x) >= w or math.abs(p.z - q.z) >= d,
				`spots {i} and {j} overlap`
			)
		end
	end
end)
