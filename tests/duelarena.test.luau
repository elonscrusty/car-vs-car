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
	truthy(math.abs(g.x) + L.garage.d / 2 <= L.totalX / 2, "garage inside the footprint")
	truthy(L.garage.w >= 2 * 16 + 4 and L.garage.mouth >= 32, "two cars wide")
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
	-- each start sits in front of its garage mouth, on the middle line
	for _, g in L.garages() do
		near(g.z, az)
		truthy(math.abs(g.x) > L.halfX)
	end
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
		truthy(math.abs(b.z) - hz >= L.lane, b.name .. " in the middle lane")
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
	eq(#walls, 6 * 2 + 2 * 2 + 16) -- the end walls have their middle modules left out for the garages
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

test("orange and blue modules are mixed all the way round", function()
	local orange, blue = 0, 0
	for _, w in L.walls() do
		if w.team == "orange" then
			orange += 1
		else
			blue += 1
		end
	end
	truthy(math.abs(orange - blue) <= 4, orange .. " orange, " .. blue .. " blue")
	local n = {}
	for _, w in L.walls() do
		if w.name:find("^WallN") then
			table.insert(n, w)
		end
	end
	table.sort(n, function(a, b)
		return a.x < b.x
	end)
	for i = 2, #n do
		truthy(n[i].team ~= n[i - 1].team, "neighbours alternate")
	end
end)

test("no wall piece stands in a garage mouth", function()
	for _, w in L.walls() do
		if math.abs(w.x) > L.halfX - 1 and not w.arc then
			truthy(math.abs(w.z) - w.length / 2 >= L.garage.mouth / 2 - 0.01, w.name)
		end
	end
	for _, t in L.tireStacks() do
		truthy(math.abs(t.x) < L.halfX - 1 or math.abs(t.z) >= L.garage.mouth / 2 - 0.01)
	end
end)

test(
	"trees, rocks and the rest stand on the grass, clear of walls, garages, paths and towers",
	function()
		local g = L.garage
		local items = L.scenery()
		truthy(#items >= 200, "lots of greenery: " .. #items)
		local kinds: { [string]: number } = {}
		local far = 0
		for _, s in items do
			kinds[s.kind] = (kinds[s.kind] or 0) + 1
			if s.far then
				far += 1
			end
			truthy(
				math.abs(s.x) > L.halfX + L.wallThickness + 6
					or math.abs(s.z) > L.halfZ + L.wallThickness + 6,
				s.kind .. " inside the arena"
			)
			truthy(math.abs(s.x) <= L.groundX / 2 and math.abs(s.z) <= L.groundZ / 2)
			for _, gar in L.garages() do
				local inX = math.abs(s.x - gar.x) < g.d / 2 + 2
				local inZ = math.abs(s.z - gar.z) < g.w / 2 + 2
				truthy(not (inX and inZ), s.kind .. " in a garage")
			end
			for _, t in L.towers() do
				truthy((t.x - s.x) ^ 2 + (t.z - s.z) ^ 2 > 36, s.kind .. " under a tower")
			end
		end
		for _, k in { "tree", "pine", "rock", "bush", "flower" } do
			truthy((kinds[k] or 0) >= 30, k .. " count " .. tostring(kinds[k]))
		end
		truthy(far > 0 and far < #items, "some far scenery to cut first")
	end
)

test("paths lead out of each garage, hills and towers stand clear of the arena", function()
	local paths = L.paths()
	eq(#paths, 6)
	for _, p in paths do
		truthy(math.abs(p.x) > L.halfX + L.wallThickness)
	end
	eq(#L.towers(), 4)
	for _, t in L.towers() do
		truthy(math.abs(t.x) > L.halfX + L.wallThickness and math.abs(t.z) > L.halfZ)
	end
	truthy(#L.hills() >= 6)
	for _, h in L.hills() do
		truthy(
			math.abs(h.x) - h.d / 2 > L.halfX or math.abs(h.z) - h.d / 2 > L.halfZ,
			"hill over the arena"
		)
	end
	truthy(L.sign.z < -(L.halfZ + L.wallThickness))
end)

test("the markings stay on the floor", function()
	for _, d in L.dashes() do
		truthy(math.abs(d.x) < L.halfX - 6 and math.abs(d.z) < L.halfZ - 6)
	end
	eq(#L.arrows(), 4)
	eq(#L.garages(), 2)
	eq(#L.tireStacks(), 7 * 2 + 4 * 2)
	truthy(#L.laneLines() > 10 and #L.skids() > 20)
	for _, d in L.laneLines() do
		truthy(d.x * d.x + d.z * d.z > L.circle * L.circle, "line inside the circle")
	end
end)

test("walls bounce a car back (not a dead stop) and tires are a stack of three", function()
	truthy(L.wallBounce >= 0.6 and L.wallBounce <= 1)
	eq(L.tire.stack, 3)
	truthy(L.tire.diameter > L.tire.height * 2, "wide, flat tires")
end)
