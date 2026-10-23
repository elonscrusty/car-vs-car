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

-- ===== Looks =====

local function nearestRoad(x: number, z: number): number
	local best = math.huge
	for _, s in Plot.loop() do
		best = math.min(best, math.sqrt((s.x - x) ^ 2 + (s.z - z) ^ 2))
	end
	return best
end

test("curbs line every corner and the straights get edge lines", function()
	local curbs, lines = Plot.paint()
	truthy(#curbs >= 60, `only {#curbs} curb stripes`)
	truthy(#lines >= 4, `only {#lines} edge lines`)
	local reds = 0
	for _, s in curbs do
		truthy(Kit.inArea(s.x, s.z), "curb outside the area")
		truthy(math.abs(s.tx * s.tx + s.tz * s.tz - 1) < 1e-6)
		if s.red then
			reds += 1
		end
	end
	truthy(reds > #curbs / 3 and reds < #curbs * 2 / 3, "curbs should alternate red and white")
end)

test("tyre walls sit on the outside of the corners, clear of the road", function()
	local tires = Plot.tires()
	truthy(#tires >= 12, `only {#tires} tyre stacks`)
	for i, t in tires do
		truthy(Kit.inArea(t.x, t.z), `tyre {i} is outside the area`)
		truthy(nearestRoad(t.x, t.z) >= Plot.ROAD / 2 + 8, `tyre {i} is too near the road`)
		truthy(
			math.sqrt((t.x - Plot.PAD.x) ^ 2 + (t.z - Plot.PAD.z) ^ 2) > Plot.PAD.r + 8,
			`tyre {i} is on the pad`
		)
	end
end)

test("lamps, pit and bleachers stay off the road and the pad", function()
	local keep = Plot.ROAD / 2 + 10
	for i, l in Plot.LAMPS do
		truthy(nearestRoad(l.x, l.z) >= keep, `lamp {i} is too near the road`)
		truthy(
			math.abs(l.x) < Kit.WIDTH / 2 and math.abs(l.z) < Kit.DEPTH / 2,
			`lamp {i} is off the plot`
		)
	end
	-- every corner of the pit (with its roof) and of the bleachers
	local p, b = Plot.PIT, Plot.BLEACHERS
	for _, box in { { p.x, p.z, p.w + 4, p.d + 6 }, { b.x, b.z, b.w, b.d } } do
		for _, sx in { -1, 0, 1 } do
			for _, sz in { -1, 0, 1 } do
				local x, z = box[1] + sx * box[3] / 2, box[2] + sz * box[4] / 2
				truthy(
					nearestRoad(x, z) >= Plot.ROAD / 2 + 6,
					`box corner {x}, {z} is too near the road`
				)
				truthy(
					math.sqrt((x - Plot.PAD.x) ^ 2 + (z - Plot.PAD.z) ^ 2) > Plot.PAD.r + 6,
					`box corner {x}, {z} is on the pad`
				)
				truthy(
					math.abs(x) < Kit.WIDTH / 2 - 2 and z > -Kit.DEPTH / 2 + 2,
					"box is off the plot"
				)
			end
		end
	end
	for _, pr in Plot.PIT_PROPS do
		truthy(
			math.abs(pr.x - p.x) < p.w / 2 and math.abs(pr.z - p.z) < p.d / 2,
			`{pr.name} is outside the pit`
		)
	end
end)

test("road pieces close the gap on the outside of every bend", function()
	local pieces = Plot.roadPieces()
	local n = #pieces
	for i = 1, n do
		local a, b = pieces[i], pieces[(i % n) + 1]
		-- heading change between this piece and the next
		local ax, az = a.bx - a.ax, a.bz - a.az
		local bx, bz = b.bx - b.ax, b.bz - b.az
		local la, lb = math.sqrt(ax * ax + az * az), math.sqrt(bx * bx + bz * bz)
		local turn = math.acos(math.clamp((ax * bx + az * bz) / (la * lb), -1, 1))
		-- each piece reaches extra / 2 past the joint; the outside gap needs half width * tan
		local need = (Plot.ROAD / 2) * math.tan(turn / 2)
		truthy(a.extra / 2 >= need and b.extra / 2 >= need, `gap at joint {i}`)
		truthy(a.bx == b.ax and a.bz == b.az, "pieces must join end to start")
	end
end)

test("lamps face the middle of the track", function()
	local m = Plot.TRACK_MIDDLE
	for i, l in Plot.LAMPS do
		local lx, lz = -math.sin(l.yaw), -math.cos(l.yaw)
		local dx, dz = m.x - l.x, m.z - l.z
		local d = math.sqrt(dx * dx + dz * dz)
		truthy((lx * dx + lz * dz) / d > 0.99, `lamp {i} does not face the track`)
	end
end)
