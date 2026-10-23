--!strict
-- Tests for the race plot only (Plots/Race.luau). The shared rules are in plots.test.
local H = require("./harness")
local Plot = require("../src/shared/Plots/Race")
local Kit = require("../src/shared/Plots/Kit")
local LapTimer = require("../src/shared/LapTimer")

local test, eq, truthy = H.test, H.eq, H.truthy

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

test("whole road and its curbs stay inside the track area", function()
	local edge = Plot.ROAD / 2 + Plot.CURB_WIDTH
	for i, s in Plot.loop() do
		for _, side in { -1, 1 } do
			local x, z = s.x - s.tz * edge * side, s.z + s.tx * edge * side
			truthy(Kit.inArea(x, z), `road sample {i} pokes out at {x}, {z}`)
		end
	end
end)

test("start line is on the front straight, the car starts behind it", function()
	local g = Plot.gates[1]
	truthy(math.abs(g.dx - 1) < 0.05, "line faces along the straight (driving right)")
	truthy(g.z > 100, "line is near the front")
	truthy(Plot.spawn.x < g.x - 10, "car starts behind the line")
end)

test("driving the loop once = start, every checkpoint in order, then a lap", function()
	local ring = Plot.loop()
	local n = #ring
	local first = 1
	for i, s in ring do
		if s.x == Plot.gates[1].x and s.z == Plot.gates[1].z then
			first = i
		end
	end
	local timer = LapTimer.new(Plot.gates, Plot.mode)
	local events = {}
	local now = 0
	-- go a bit past one full lap, in small steps
	for k = -3, n + 3 do
		local a = ring[((first + k - 1) % n) + 1]
		local b = ring[((first + k) % n) + 1]
		for t = 0, 0.9, 0.1 do
			now += 0.01
			local e = LapTimer.update(timer, now, a.x + (b.x - a.x) * t, 0, a.z + (b.z - a.z) * t)
			if e then
				table.insert(events, e)
			end
		end
	end
	eq(table.concat(events, ","), "start," .. string.rep("checkpoint,", #Plot.gates - 1) .. "lap")
end)

test("a short cut across the middle doesn't count", function()
	local timer = LapTimer.new(Plot.gates, Plot.mode)
	local g = Plot.gates
	LapTimer.update(timer, 0, g[1].x, 0, g[1].z)
	-- jump straight to the hairpin and back over the line
	eq(LapTimer.update(timer, 1, g[4].x, 0, g[4].z), nil)
	eq(LapTimer.update(timer, 2, g[1].x, 0, g[1].z), nil)
end)

local function distToRoad(x: number, z: number): number
	local best = math.huge
	for _, s in Plot.loop() do
		local dx, dz = s.x - x, s.z - z
		best = math.min(best, math.sqrt(dx * dx + dz * dz))
	end
	return best
end

test("scenery you can bump stays well off the road (runoff stays grass)", function()
	for _, e in Plot.DECOR do
		if e.solid then
			local hw, hd = (e.w or e.h * 0.6) / 2, (e.d or e.h * 0.6) / 2
			for _, c in { { 0, 0 }, { -hw, -hd }, { hw, -hd }, { -hw, hd }, { hw, hd } } do
				local x, z = e.x + c[1], e.z + c[2]
				local gap = distToRoad(x, z)
				truthy(gap >= Plot.DECOR_CLEAR, `{e.kind} at {e.x}, {e.z} is {gap} from the road`)
				truthy(Kit.inArea(x, z), `{e.kind} at {e.x}, {e.z} is outside the track area`)
			end
		end
	end
end)

test("start arch posts stand outside the curbs", function()
	truthy(Plot.archPostInner() >= Plot.ROAD / 2 + Plot.CURB_WIDTH + 3, "posts on the curb")
	truthy(Plot.ARCH_HEIGHT >= 20, "arch too low")
end)

test("every scenery kind has a Meshy name or is a block-only kind", function()
	for _, e in Plot.DECOR do
		truthy(Plot.DECOR_MESH[e.kind] ~= nil, `no mesh name for {e.kind}`)
	end
end)
