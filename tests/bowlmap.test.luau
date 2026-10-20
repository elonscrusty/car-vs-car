--!strict
local Harness = require("./harness")
local L = require("../src/shared/BowlLayout")

local test, eq, near, truthy = Harness.test, Harness.eq, Harness.near, Harness.truthy

print("BowlLayout")

local CAR_LENGTH, CAR_WIDTH = 16, 8

local function dist(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

test("medium size: a round bowl 200 to 260 studs across, not a square", function()
	truthy(L.rimRadius * 2 >= 200 and L.rimRadius * 2 <= 260, "rim " .. L.rimRadius * 2)
	truthy(L.floorRadius * 2 >= CAR_LENGTH * 10, "room to chase on the flat floor")
	near(L.rimRadius, L.floorRadius + L.slopeRun)
	truthy(L.wallRadius > L.rimRadius and L.wallRadius - L.rimRadius <= 2)
	truthy(L.groundRadius > L.wallRadius + L.tire.diameter, "floor runs out under the tires")
	truthy(L.groundRadius * 2 < L.groundSize, "the floor fits its slot")
end)

test("the slope is gentle enough to drive (ground ray needs 12 degrees or less)", function()
	local deg = math.deg(math.atan2(L.slopeRise, L.slopeRun))
	truthy(deg <= 12 and deg >= 8, "slope " .. deg)
end)

test("slope wedges ring the floor, rise straight outward and meet at the outer edge", function()
	local list = L.facets()
	eq(#list, L.facetCount)
	for i, f in list do
		near(math.sqrt(f.dx * f.dx + f.dz * f.dz), 1, 1e-6)
		-- the wedge points straight away from the middle
		local r = math.sqrt(f.x * f.x + f.z * f.z)
		near(f.x / r, f.dx, 1e-6)
		near(f.z / r, f.dz, 1e-6)
		-- foot on the flat floor, top at the rim
		near(r - f.length / 2, L.floorRadius, 1e-6)
		truthy(r + f.length / 2 >= L.rimRadius)
		-- the same slope for every wedge, a bit more than the rise because the wedge runs past the rim
		near(f.height / f.length, L.slopeRise / L.slopeRun, 1e-6)
		-- neighbours meet at the outer edge: width is at least the gap between outer corners
		local outer = r + f.length / 2
		truthy(f.width >= 2 * outer * math.tan(math.pi / L.facetCount) - 1e-6, "wedge " .. i)
		-- and never bulge past the tire wall
		truthy(math.sqrt(outer ^ 2 + (f.width / 2) ^ 2) < L.wallRadius + 0.5)
	end
end)

test("the invisible wall closes the circle at the rim and faces the middle", function()
	local list = L.wallSegments()
	eq(#list, L.wallCount)
	local chord = 2 * L.wallRadius * math.tan(math.pi / L.wallCount)
	for _, w in list do
		near(math.sqrt(w.nx * w.nx + w.nz * w.nz), 1, 1e-6)
		truthy(w.nx * w.x + w.nz * w.z < 0, w.name .. " faces the middle")
		truthy(w.length >= chord, w.name .. " long enough to meet its neighbour")
		-- the inner face passes through the wall radius
		local r = math.sqrt(w.x * w.x + w.z * w.z)
		near(r - w.thickness / 2, L.wallRadius, 1e-6)
	end
end)

test("the tire stacks stand shoulder to shoulder against the wall", function()
	local list = L.tires()
	truthy(#list >= 40 and #list <= 70, "count " .. #list)
	local r = L.wallRadius + L.tire.diameter / 2
	for i, t in list do
		near(math.sqrt(t.x * t.x + t.z * t.z), r, 1e-6)
		local nxt = list[i % #list + 1]
		-- neighbours overlap a little, so no light shows between them (and not much more than that)
		local gap = dist(t.x, t.z, nxt.x, nxt.z) - L.tire.diameter
		truthy(gap <= 0 and gap >= -1, "gap " .. gap)
	end
	truthy(L.slopeRise + L.wallAboveRim >= CAR_LENGTH * 0.8, "a wall a car cannot see over")
end)

test("the starts face each other far apart on the lane, on the flat floor", function()
	local ax, az, afx, afz = L.spawn("a")
	local bx, bz, bfx, bfz = L.spawn("b")
	near(ax, -bx)
	near(az, bz)
	near(az, L.laneZ)
	near(afx, 1)
	near(bfx, -1)
	near(afz, 0)
	near(bfz, 0)
	truthy(bx - ax >= CAR_LENGTH * 7, "far apart: " .. (bx - ax))
	-- the whole pad is on the flat floor
	for _, sx in { -1, 1 } do
		for _, dx in { -L.pad.sx / 2, L.pad.sx / 2 } do
			for _, dz in { -L.pad.sz / 2, L.pad.sz / 2 } do
				local x = sx * L.spawnX + dx
				local z = L.laneZ + dz
				truthy(
					math.sqrt(x * x + z * z) <= L.floorRadius - 2,
					"pad corner " .. x .. "," .. z
				)
			end
		end
	end
	truthy(L.pad.sz >= CAR_WIDTH * 1.5)
end)

test("the lane runs beside the crusher, outside its shock ring", function()
	local C = L.crusher
	truthy(L.laneZ - L.laneHalf - C.shockRadius >= 4, "lane edge to shock ring")
	truthy(L.laneZ - CAR_LENGTH / 2 > C.shockRadius, "a car on the lane is never caught")
	for _, d in L.laneDashes() do
		near(d.z, L.laneZ)
		truthy(math.abs(d.x) < L.spawnX)
	end
end)

test("nothing stands in the lane: no prop, no hump", function()
	for _, p in L.breakables() do
		truthy(
			math.abs(p.z - L.laneZ) >= L.laneClear or math.abs(p.x) > L.spawnX + L.pad.sx / 2,
			p.kind .. " in the lane at " .. p.x .. "," .. p.z
		)
	end
	for _, k in L.kickers() do
		truthy(k.z + k.width / 2 + 5 < L.laneZ - L.laneHalf, k.name .. " off the lane")
	end
end)

test("fewer ramps than Wreck City's five, and low: no big jump", function()
	local list = L.kickers()
	truthy(#list >= 1 and #list < 5)
	for _, k in list do
		truthy(k.height <= 3.5, "low")
		local deg = math.deg(math.atan2(k.height, k.length / 2))
		truthy(deg <= 14, k.name .. " slope " .. deg)
		truthy(k.width >= CAR_WIDTH * 2)
		-- inside the flat floor with room round it
		truthy(math.sqrt(k.x ^ 2 + k.z ^ 2) + k.length / 2 + 5 < L.floorRadius)
		truthy(math.sqrt(k.x ^ 2 + k.z ^ 2) - k.length / 2 > L.crusher.shockRadius + 4)
	end
	-- mirrored
	near(list[1].x, -list[2].x)
	near(list[1].z, list[2].z)
end)

test("the crusher clock: idle, then a warning, a slam, a ring, a lift, and again", function()
	local C = L.crusher
	eq(L.crusherState(0).phase, "idle")
	eq(L.crusherState(C.first - C.warn - 0.01).phase, "idle")
	local w = L.crusherState(C.first - C.warn + 0.01)
	eq(w.phase, "warn")
	eq(w.index, 0)
	-- the warning is long enough to see (carter: a clear warning)
	truthy(C.warn >= 1.5)
	-- the slam lands exactly `first` seconds after GO
	eq(L.crusherState(C.first + 0.01).phase, "drop")
	eq(L.crusherState(C.first + C.drop + 0.01).phase, "wave")
	eq(L.crusherState(C.first + C.drop + C.wave + 0.01).phase, "lift")
	eq(L.crusherState(C.first + C.drop + C.wave + C.lift + 0.01).phase, "rest")
	-- and the next one a period later
	local second = L.crusherState(C.first - C.warn + C.period + 0.01)
	eq(second.phase, "warn")
	eq(second.index, 1)
	-- slams happen now and then, not all the time
	truthy(C.period >= 8)
	truthy(C.first >= 5, "nothing hits a car in the first seconds of a round")
	-- a 60 second round sees 4 to 6 slams
	local slams = 0
	for i = 0, 5 do
		if C.first + i * C.period < 60 then
			slams += 1
		end
	end
	truthy(slams >= 4 and slams <= 6, "slams in a round: " .. slams)
end)

test("the press falls from its warning height to the base and back, smoothly", function()
	local C = L.crusher
	near(L.crusherLift({ phase = "idle", u = 0, index = 0 }), C.restLift)
	local top = L.crusherLift({ phase = "warn", u = 1, index = 0 })
	near(top, C.warnLift)
	near(L.crusherLift({ phase = "drop", u = 0, index = 0 }), C.warnLift)
	near(L.crusherLift({ phase = "drop", u = 1, index = 0 }), C.slamLift)
	near(L.crusherLift({ phase = "wave", u = 0.5, index = 0 }), C.slamLift)
	near(L.crusherLift({ phase = "lift", u = 0, index = 0 }), C.slamLift)
	near(L.crusherLift({ phase = "lift", u = 1, index = 0 }), C.restLift)
	truthy(C.slamLift >= C.baseHeight, "the head lands on the base, not in it")
	truthy(C.slamLift <= C.baseHeight + 1)
end)

test("the shock ring spreads from the base to its full reach and only during the wave", function()
	local C = L.crusher
	eq(L.shockFront({ phase = "warn", u = 0.5, index = 0 }), 0)
	eq(L.shockFront({ phase = "drop", u = 0.5, index = 0 }), 0)
	near(L.shockFront({ phase = "wave", u = 0, index = 0 }), C.baseRadius)
	near(L.shockFront({ phase = "wave", u = 1, index = 0 }), C.shockRadius)
	local last = 0
	for i = 0, 10 do
		local f = L.shockFront({ phase = "wave", u = i / 10, index = 0 })
		truthy(f >= last)
		last = f
	end
	truthy(C.damageFrac > 0 and C.damageFrac <= 0.1, "small damage")
	truthy(L.boom.damageFrac > 0 and L.boom.damageFrac <= 0.1, "small damage")
	truthy(L.boom.knockSpeed > C.knockSpeed, "boom pushes harder than it hurts")
end)

test("breakables: the same 71 as Wreck City, mostly crates and barrels", function()
	local list = L.breakables()
	eq(#list, 71)
	local kinds: { [string]: number } = {}
	for _, p in list do
		kinds[p.kind] = (kinds[p.kind] or 0) + 1
	end
	eq(kinds.boom, 8)
	eq(kinds.barrel, 18)
	eq(kinds.crate, 26)
	eq(kinds.cone, 8)
	eq(kinds.sign, 5)
	eq(kinds.fence, 6)
	-- carter M13: crates and barrels break most
	truthy(
		(kinds.boom + kinds.barrel + kinds.crate) / #list >= 0.7,
		"crates and barrels are the most"
	)
end)

test("breakables stand on open floor and keep their distance", function()
	local list = L.breakables()
	for _, p in list do
		truthy(L.clear(p.x, p.z, 0), p.kind .. " at " .. p.x .. "," .. p.z)
	end
	for i, a in list do
		for j, b in list do
			if i < j then
				local need = L.propSpacing - 0.01
				if a.kind == "boom" and b.kind == "boom" then
					need = L.boomSpacing - 0.01
				end
				truthy(
					dist(a.x, a.z, b.x, b.z) >= need,
					a.kind .. " and " .. b.kind .. " too close at " .. a.x .. "," .. a.z
				)
			end
		end
	end
end)

test("fences are clear at both ends", function()
	for _, p in L.breakables() do
		if p.kind == "fence" then
			local ca, sa = math.cos(math.rad(p.yawDeg)), -math.sin(math.rad(p.yawDeg))
			for _, e in { -6, 6 } do
				truthy(L.clear(p.x + ca * e, p.z + sa * e, 0), "fence end at " .. p.x .. "," .. p.z)
			end
		end
	end
end)

test("breakables are mirrored left to right, so neither start has the better side", function()
	local list = L.breakables()
	local axis = 0
	for _, p in list do
		if math.abs(p.x) < 0.01 then
			axis += 1
			continue
		end
		local found = false
		for _, q in list do
			if
				q.kind == p.kind
				and math.abs(q.x + p.x) < 1e-6
				and math.abs(q.z - p.z) < 1e-6
				and q.variant == p.variant
			then
				found = true
				break
			end
		end
		truthy(found, p.kind .. " at " .. p.x .. "," .. p.z .. " has no mirror")
	end
	eq(axis, 1)
	local lane = 0
	for _, p in list do
		if p.z > L.laneZ then
			lane += 1
		end
	end
	truthy(lane >= 4, "some junk on the far side of the lane too")
end)

test("breakables are the same every time", function()
	local a, b = L.breakables(), L.breakables()
	eq(#a, #b)
	for i = 1, #a do
		near(a[i].x, b[i].x)
		near(a[i].z, b[i].z)
	end
end)

test("every barrel and crate colour is a rainbow colour, never red", function()
	for _, p in L.breakables() do
		if p.kind == "barrel" or p.kind == "crate" then
			truthy(p.variant >= 1 and p.variant <= #L.colors.rainbow)
		end
	end
	for _, c in L.colors.rainbow do
		truthy(not (c[1] > 190 and c[2] < 90 and c[3] < 90), "no red in the rainbow")
	end
end)

test("rescue points are on open floor, away from the crusher, facing along the circle", function()
	local list = L.rescuePoints()
	eq(#list, 12)
	for _, p in list do
		local r = math.sqrt(p.x * p.x + p.z * p.z)
		truthy(r > L.crusher.shockRadius + CAR_LENGTH and r < L.floorRadius - CAR_LENGTH)
		near(p.fx * p.fx + p.fz * p.fz, 1, 1e-6)
		-- along the circle: at right angles to the line to the middle
		near(p.fx * p.x + p.fz * p.z, 0, 1e-6)
		for _, k in L.kickers() do
			truthy(
				math.abs(p.x - k.x) > k.length / 2 + CAR_LENGTH / 2 + 2
					or math.abs(p.z - k.z) > k.width / 2 + CAR_LENGTH / 2 + 2,
				"rescue point on " .. k.name
			)
		end
	end
end)

test("the bots are told about the crusher's base", function()
	local c = L.circles()
	eq(#c, 1)
	near(c[1].r, L.crusher.baseRadius)
end)

test("junk patches are mirrored and sit on the flat floor", function()
	local patches = L.patches()
	truthy(#patches >= 5)
	for _, p in patches do
		truthy(
			math.sqrt(p.x ^ 2 + p.z ^ 2) + p.radius < L.floorRadius + 1,
			p.name .. " on the floor"
		)
		truthy(math.sqrt(p.x ^ 2 + p.z ^ 2) - p.radius > L.crusher.baseRadius, p.name)
	end
end)
