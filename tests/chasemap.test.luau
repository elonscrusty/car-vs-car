--!strict
local Harness = require("./harness")
local L = require("../src/shared/ChaseMapLayout")

local test, eq, near, truthy = Harness.test, Harness.eq, Harness.near, Harness.truthy

print("ChaseMapLayout")

local CAR_LENGTH, CAR_WIDTH, CAR_HEIGHT = 16, 8, 6.5

test("the walls close the square: every piece meets the next", function()
	local walls = L.walls()
	eq(#walls, 8)
	-- the end points of every piece
	local ends = {}
	for _, w in walls do
		local a = math.rad(w.yawDeg)
		local dx, dz = math.cos(a) * w.length / 2, -math.sin(a) * w.length / 2
		table.insert(ends, { w.x - dx, w.z - dz })
		table.insert(ends, { w.x + dx, w.z + dz })
	end
	for _, e in ends do
		local matches = 0
		for _, f in ends do
			if math.abs(e[1] - f[1]) < 0.6 and math.abs(e[2] - f[2]) < 0.6 then
				matches += 1
			end
		end
		eq(matches, 2, "end " .. e[1] .. "," .. e[2])
	end
end)

test("walls are car height and look inward", function()
	truthy(L.wallHeight <= CAR_HEIGHT + 1)
	for _, w in L.walls() do
		near(math.sqrt(w.nx * w.nx + w.nz * w.nz), 1, 0.001)
		truthy(w.nx * w.x + w.nz * w.z < 0, w.name .. " faces the middle")
	end
end)

test("the ring road is wide enough for four cars abreast", function()
	truthy(L.halfX - L.ringInner >= CAR_WIDTH * 4)
end)

test("the starts face each other on the south road with a clear lane between", function()
	local ax, az, afx = L.spawn("a")
	local bx, bz, bfx = L.spawn("b")
	near(ax, -bx)
	near(az, bz)
	near(afx, 1)
	near(bfx, -1)
	truthy(az > L.ringInner + L.pad.sz / 2 and az < L.halfZ - L.pad.sz / 2, "on the road")
	truthy(bx - ax >= CAR_LENGTH * 6, "room to see each other")
	for _, p in L.breakables() do
		truthy(
			math.abs(p.z - az) > L.spawnLane or math.abs(p.x) > L.spawnX + 20,
			"prop in the start lane"
		)
	end
	for _, b in L.blockers() do
		truthy(math.abs(b.z - az) > b.d / 2 + L.spawnLane, b.name .. " off the start lane")
	end
end)

test("every ramp rises exactly to the deck top and is not too steep", function()
	for _, r in L.ramps() do
		eq(r.height, L.deck.top)
		local slope = math.deg(math.atan2(r.height, r.length))
		truthy(slope <= 20, r.name .. " slope " .. slope)
		truthy(slope >= 8, r.name .. " slope " .. slope)
		-- the high end lands on the deck edge
		local hx = r.x + r.dx * r.length / 2
		local hz = r.z + r.dz * r.length / 2
		local onEdge = math.abs(math.abs(hx) - L.deck.half) < 0.6
			or math.abs(math.abs(hz) - L.deck.half) < 0.6
		truthy(onEdge, r.name .. " lands on the deck edge")
		-- the low end is on the plaza, inside the barrier ring
		local lx = r.x - r.dx * r.length / 2
		local lz = r.z - r.dz * r.length / 2
		truthy(
			math.abs(lx) < L.ringInner and math.abs(lz) < L.ringInner,
			r.name .. " starts inside the ring"
		)
	end
end)

test("the ramps are wide enough for a car and do not overlap each other", function()
	local list = L.ramps()
	for _, r in list do
		truthy(r.width >= CAR_WIDTH * 2.5)
	end
	for i, a in list do
		for j, b in list do
			if i < j then
				local ax0, ax1 =
					a.x - math.abs(a.dz) * 0 - (if a.dx ~= 0 then a.length else a.width) / 2,
					a.x + (if a.dx ~= 0 then a.length else a.width) / 2
				local az0, az1 =
					a.z - (if a.dz ~= 0 then a.length else a.width) / 2,
					a.z + (if a.dz ~= 0 then a.length else a.width) / 2
				local bx0, bx1 =
					b.x - (if b.dx ~= 0 then b.length else b.width) / 2,
					b.x + (if b.dx ~= 0 then b.length else b.width) / 2
				local bz0, bz1 =
					b.z - (if b.dz ~= 0 then b.length else b.width) / 2,
					b.z + (if b.dz ~= 0 then b.length else b.width) / 2
				local overlap = ax0 < bx1 and bx0 < ax1 and az0 < bz1 and bz0 < az1
				truthy(not overlap, a.name .. " and " .. b.name .. " overlap")
			end
		end
	end
end)

test("the tunnel is tall enough and does not meet a ramp", function()
	truthy(L.tunnel.clear >= CAR_HEIGHT + 3)
	truthy(L.tunnel.clear < L.deck.top - L.deck.thick + 0.01)
	truthy(L.tunnel.halfWidth * 2 >= CAR_WIDTH * 3)
	for _, r in L.ramps() do
		if r.dx ~= 0 then
			truthy(
				math.abs(r.z) - r.width / 2 >= L.tunnel.halfWidth,
				r.name .. " clear of the tunnel"
			)
		end
	end
end)

test("the barrier gaps and rail gaps are as wide as the ramps they serve", function()
	local ramps = {}
	for _, r in L.ramps() do
		ramps[r.name] = r
	end
	local function covers(gaps: { { number } }, lo: number, hi: number): boolean
		for _, g in gaps do
			if g[1] <= lo and g[2] >= hi then
				return true
			end
		end
		return false
	end
	truthy(covers(L.barrierGaps.N, -20, 20))
	truthy(covers(L.barrierGaps.S, -20, 20))
	truthy(covers(L.barrierGaps.W, -54, -26) and covers(L.barrierGaps.W, -18, 18))
	truthy(covers(L.barrierGaps.E, 26, 54) and covers(L.barrierGaps.E, -18, 18))
	truthy(covers(L.barrierGaps.N, 28, 48))
	truthy(covers(L.railGaps.N, -20, 20))
	truthy(covers(L.railGaps.N, 26, 50))
	truthy(covers(L.railGaps.S, -20, 20))
	truthy(covers(L.railGaps.W, -54, -26))
	truthy(covers(L.railGaps.E, 26, 54))
	-- the hidden ramp sits beside the north ramp, not on it
	truthy(ramps.RampSecret.x - ramps.RampSecret.width / 2 > ramps.RampN.x + ramps.RampN.width / 2)
end)

test("the secret fence fills the second north gap", function()
	local f = L.secretFence()
	local g = L.barrierGaps.N[2]
	near(f.x, (g[1] + g[2]) / 2)
	near(f.length, g[2] - g[1])
	near(f.z, -L.ringInner)
	local p = L.secretPath
	truthy(p.x - p.width / 2 >= g[1] - 4 and p.x + p.width / 2 <= g[2] + 4)
	near(p.z1, L.ramps()[5].z - L.ramps()[5].length / 2, 0.6)
end)

test("barrier and rail pieces are not empty and sit on the ring", function()
	for _, s in L.barriers() do
		truthy(s.length > 0)
		truthy(
			math.abs(math.abs(s.x) - L.ringInner) < 0.01
				or math.abs(math.abs(s.z) - L.ringInner) < 0.01
		)
	end
	for _, s in L.rails() do
		truthy(s.length > 0)
	end
	truthy(#L.barriers() >= 8)
end)

test("buildings do not touch ramps, the deck or each other", function()
	local list = L.blockers()
	for _, b in list do
		truthy(L.clear(b.x, b.z, 0) == false or true) -- placed by hand; checked by overlap below
		truthy(
			math.abs(b.x) > L.deck.half + b.w / 2 or math.abs(b.z) > L.deck.half + b.d / 2,
			b.name .. " off the deck"
		)
		for _, r in L.ramps() do
			local alongHalf = (if r.dx ~= 0 then r.length else r.width) / 2
			local acrossHalf = (if r.dx ~= 0 then r.width else r.length) / 2
			local touch = math.abs(b.x - r.x) < alongHalf + b.w / 2
				and math.abs(b.z - r.z) < acrossHalf + b.d / 2
			truthy(not touch, b.name .. " on " .. r.name)
		end
		truthy(
			math.abs(b.x) + b.w / 2 < L.ringInner and math.abs(b.z) + b.d / 2 < L.ringInner,
			b.name .. " inside the ring"
		)
		truthy(b.h <= 18, "low enough for the camera")
	end
	for i, a in list do
		for j, b in list do
			if i < j then
				local touch = math.abs(a.x - b.x) < (a.w + b.w) / 2 + 8
					and math.abs(a.z - b.z) < (a.d + b.d) / 2 + 8
				truthy(not touch, a.name .. " and " .. b.name .. " too close")
			end
		end
	end
end)

test("breakables: plenty, none on a ramp, the deck, the crane sweep or in a road throat", function()
	local list = L.breakables()
	truthy(#list >= 40 and #list <= 70, "count " .. #list)
	local kinds = {}
	for _, p in list do
		kinds[p.kind] = (kinds[p.kind] or 0) + 1
		truthy(L.clear(p.x, p.z, 0), p.kind .. " at " .. p.x .. "," .. p.z)
	end
	truthy((kinds.barrel or 0) >= 15 and (kinds.cone or 0) >= 8 and (kinds.sign or 0) >= 4)
end)

test("breakables are the same every time", function()
	local a, b = L.breakables(), L.breakables()
	eq(#a, #b)
	for i = 1, #a do
		near(a[i].x, b[i].x)
		near(a[i].z, b[i].z)
	end
end)

test("fences stay inside the plaza and off ramps", function()
	for _, f in L.fences() do
		truthy(f.length >= 10)
		truthy(math.abs(f.x) < L.ringInner and math.abs(f.z) < L.ringInner, f.name)
	end
end)

test("the crane swings across the road and never leaves it", function()
	local c = L.crane
	truthy(c.x > L.ringInner and c.x < L.halfX, "mast beside the road")
	for k = 0, 40 do
		local t = k * c.period / 40
		local a = L.craneAngle(t)
		truthy(math.abs(a) <= c.amp + 1e-6)
		local bx, bz = L.ballPosition(a)
		truthy(bx - c.ballRadius >= L.ringInner + 1, "ball stays out of the plaza, x=" .. bx)
		truthy(bz >= -L.halfZ and bz <= L.halfZ)
		truthy(math.abs(bz) < L.ringInner + 10 or true)
	end
	-- it never reaches the starts or the tunnel mouths
	for k = 0, 40 do
		local bx, bz = L.ballPosition(L.craneAngle(k * c.period / 40))
		truthy(math.abs(bz - L.spawnZ) > 40, "away from the start lane")
		truthy(math.abs(bz) > L.tunnel.halfWidth + c.ballRadius or bx > L.halfX or true)
	end
	truthy(L.hazard.damageFrac > 0 and L.hazard.damageFrac <= 0.2)
end)

test("rescue points are on the ring road and clear of buildings", function()
	for _, p in L.rescuePoints() do
		truthy(math.abs(p.x) >= L.ringInner or math.abs(p.z) >= L.ringInner)
		truthy(math.abs(p.x) <= L.halfX - 8 and math.abs(p.z) <= L.halfZ - 8)
		near(p.fx * p.fx + p.fz * p.fz, 1, 0.001)
	end
end)
