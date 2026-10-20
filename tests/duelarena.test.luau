--!strict
local Harness = require("./harness")
local L = require("../src/shared/DuelArenaLayout")

local test, eq, near, truthy = Harness.test, Harness.eq, Harness.near, Harness.truthy

print("DuelArenaLayout")

local CAR_SPEED = 45 -- studs per second, about what the cars cruise at

test("a car crosses the long way in about four seconds", function()
	local seconds = (L.halfX * 2) / CAR_SPEED
	truthy(seconds >= 3.4 and seconds <= 4.4, "crossing takes " .. seconds)
end)

test("the whole scene fits the 240 x 200 sheet", function()
	eq(L.totalX, 240)
	eq(L.totalZ, 200)
	truthy((L.halfX + L.wallThickness) * 2 <= L.totalX)
	truthy((L.halfZ + L.wallThickness) * 2 <= L.totalZ)
	local g = L.garages()[1]
	truthy(math.abs(g.z) + L.garage.sz / 2 <= L.totalZ / 2, "garage inside the footprint")
	truthy(L.wallHeight <= 8, "walls are car height")
end)

test("the starts face each other on the same line, inside the floor", function()
	local ax, az, afx, afz = L.spawn("a")
	local bx, bz, bfx, bfz = L.spawn("b")
	near(ax, -bx)
	near(az, bz)
	near(afx, 1)
	near(bfx, -1)
	near(afz, 0)
	near(bfz, 0)
	truthy(math.abs(bx) + L.pad.sx / 2 < L.halfX - 4)
	truthy(math.abs(bz) + L.pad.sz / 2 < L.halfZ - 4)
end)

test("the lane between the starts is clear of cover", function()
	local ax, az = L.spawn("a")
	local bx = -ax
	local blocks = L.blocks()
	eq(#blocks, 4)
	for _, b in blocks do
		local hx, hz = L.blockHalf(b.yawDeg)
		local overlapsLane = b.z + hz > az - L.lane and b.z - hz < az + L.lane
		local betweenPads = b.x + hx > ax and b.x - hx < bx
		truthy(not (overlapsLane and betweenPads), b.name .. " blocks the start lane")
	end
end)

test("cover is mirrored left to right and stays away from the walls", function()
	local seen: { [string]: boolean } = {}
	for _, b in L.blocks() do
		seen[string.format("%.1f,%.1f", b.x, b.z)] = true
	end
	for _, b in L.blocks() do
		truthy(seen[string.format("%.1f,%.1f", -b.x, b.z)], b.name .. " has no mirror")
		local hx, hz = L.blockHalf(b.yawDeg)
		truthy(L.halfX - (math.abs(b.x) + hx) >= 14)
		truthy(L.halfZ - (math.abs(b.z) + hz) >= 14)
	end
end)

test("cover keeps a car-wide gap to every other block", function()
	local list = L.blocks()
	for i = 1, #list do
		for j = i + 1, #list do
			local a, b = list[i], list[j]
			local ax, az = L.blockHalf(a.yawDeg)
			local bx, bz = L.blockHalf(b.yawDeg)
			local dx = math.max(math.abs(a.x - b.x) - ax - bx, 0)
			local dz = math.max(math.abs(a.z - b.z) - az - bz, 0)
			truthy(math.sqrt(dx * dx + dz * dz) >= 12, a.name .. " and " .. b.name .. " too close")
		end
	end
end)

test("the walls close the rounded rectangle with no gap and no piece inside the floor", function()
	local walls = L.walls()
	eq(#walls, 6 * 2 + 4 * 2 + 16)
	for _, w in walls do
		-- inner face point lies on the rounded rectangle: inside (or on) it, never beyond
		truthy(math.abs(w.x) <= L.halfX + 0.01 and math.abs(w.z) <= L.halfZ + 0.01, w.name)
		near(math.sqrt(w.nx * w.nx + w.nz * w.nz), 1, 1e-6)
	end
	-- consecutive pieces along a straight touch end to end
	local north = {}
	for _, w in walls do
		if w.name:find("^WallN") then
			table.insert(north, w)
		end
	end
	table.sort(north, function(a, b)
		return a.x < b.x
	end)
	for i = 2, #north do
		near(north[i].x - north[i - 1].x, north[i].length, 1e-6)
	end
end)

test("corner pieces follow the arc: right distance from the corner center", function()
	local cx, cz = L.halfX - L.corner, L.halfZ - L.corner
	for _, w in L.walls() do
		if w.arc then
			local dx = math.abs(w.x) - cx
			local dz = math.abs(w.z) - cz
			truthy(dx >= -0.01 and dz >= -0.01, w.name .. " off its corner")
			local dist = math.sqrt(dx * dx + dz * dz)
			truthy(dist <= L.corner and dist >= L.corner - 1.5, w.name .. " at " .. dist)
		end
	end
end)

test("walls are orange on the red side and blue on the blue side", function()
	for _, w in L.walls() do
		eq(w.team, if w.x < 0 then "orange" else "blue")
	end
end)

test("trees and rocks stand outside the walls and the garages", function()
	local g = L.garage
	local items = L.scenery()
	truthy(#items >= 40, "enough greenery")
	for _, s in items do
		truthy(
			math.abs(s.x) > L.halfX + L.wallThickness + 6
				or math.abs(s.z) > L.halfZ + L.wallThickness + 6,
			s.kind .. " inside the arena"
		)
		truthy(math.abs(s.x) <= L.totalX / 2 and math.abs(s.z) <= L.totalZ / 2)
		for _, gar in L.garages() do
			local inX = math.abs(s.x - gar.x) < g.sx / 2 + 2
			local inZ = math.abs(s.z - gar.z) < g.sz / 2 + 2
			truthy(not (inX and inZ), s.kind .. " in a garage")
		end
	end
end)

test("the dashed line and chevrons stay on the floor", function()
	for _, d in L.dashes() do
		truthy(math.abs(d.x) < L.halfX - 6 and math.abs(d.z) < L.halfZ - 6)
	end
	eq(#L.chevrons(), 2)
	eq(#L.garages(), 2)
	eq(#L.tireStacks(), 7 * 2 + 5 * 2)
end)

test("walls bounce a car back (not a dead stop) and tires are a stack of three", function()
	truthy(L.wallBounce >= 0.6 and L.wallBounce <= 1)
	eq(L.tire.stack, 3)
	truthy(L.tire.diameter > L.tire.height * 2, "wide, flat tires")
end)
