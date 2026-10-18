--!strict
local Harness = require("./harness")
local ArenaLayout = require("../src/shared/ArenaLayout")
local ArenaLookConfig = require("../src/shared/ArenaLookConfig")
local GameConfig = require("../src/shared/GameConfig")

local test, eq, truthy = Harness.test, Harness.eq, Harness.truthy

print("ArenaLayout")

local L = ArenaLookConfig
local RIM = GameConfig.Arena.rimRadius

type Spot = ArenaLayout.Spot

local function radius(s: Spot): number
	return math.sqrt(s.x * s.x + s.z * s.z)
end

local function dist(a: Spot, b: Spot): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

local function same(a: { Spot }, b: { Spot })
	eq(#a, #b)
	for i, s in a do
		local t = b[i]
		eq(s.x, t.x)
		eq(s.z, t.z)
		eq(s.yawDeg, t.yawDeg)
		eq(s.scale, t.scale)
		eq(s.n, t.n)
	end
end

local lists: { [string]: { Spot } } = {
	towers = ArenaLayout.towerSpots(),
	pads = ArenaLayout.hazardPadSpots(),
	barriers = ArenaLayout.barrierSpots(),
	tires = ArenaLayout.tireStacks(),
	cones = ArenaLayout.coneSpots(),
	hills = ArenaLayout.hillSpots(),
	trees = ArenaLayout.treeSpots(),
	rocks = ArenaLayout.rockSpots(),
	clouds = ArenaLayout.cloudSpots(),
}

test("counts match the config", function()
	eq(#lists.towers, L.towers.count)
	eq(#lists.pads, L.hazardPads.count)
	eq(#lists.barriers, L.barriers.count)
	eq(#lists.tires, L.tires.count)
	eq(#lists.cones, L.cones.count)
	eq(#lists.hills, L.hills.count)
	eq(#lists.trees, L.trees.count)
	eq(#lists.rocks, L.rocks.count)
	eq(#lists.clouds, L.clouds.count)
end)

test("the road starts outside the bowl and the tall stuff stays well clear of it", function()
	truthy(L.curbInner > RIM)
	truthy(L.roadInner > L.curbInner)
	truthy(L.outerMin >= RIM + 30)
	truthy(L.roadOuter < L.outerMin)
	truthy(L.grassOuter > L.maxRadius)
end)

test("road props sit on the road", function()
	for _, name in { "pads", "barriers", "tires", "cones" } do
		for _, s in lists[name] do
			truthy(radius(s) > L.roadInner + 1, name .. " too close to the bowl")
			truthy(radius(s) < L.roadOuter - 1, name .. " off the road")
		end
	end
end)

test("the scenery rim matches the bowl rim", function()
	truthy(L.curbInner == RIM + 2)
end)

test("tall scenery is outside the rim margin and inside the max radius", function()
	for _, name in { "towers", "trees", "rocks", "hills" } do
		for _, s in lists[name] do
			truthy(radius(s) >= L.outerMin, name .. " too close")
			truthy(radius(s) <= L.maxRadius, name .. " too far")
		end
	end
	for _, s in lists.hills do
		truthy(radius(s) - s.scale >= RIM + 30, "hill reaches the bowl")
		truthy(radius(s) + s.scale <= L.maxRadius, "hill goes past the max radius")
	end
	for _, s in lists.clouds do
		truthy(radius(s) <= L.maxRadius)
	end
end)

test("nothing overlaps the hazard pads or the towers", function()
	local padR = ArenaLayout.hazardPadRadius()
	for _, name in { "tires", "cones", "barriers" } do
		for _, s in lists[name] do
			for _, p in lists.pads do
				truthy(dist(s, p) > padR + 1, name .. " on a pad")
			end
		end
	end
	for _, t in lists.towers do
		for _, p in lists.pads do
			truthy(dist(t, p) > padR + ArenaLayout.towerRadius)
		end
		for _, name in { "trees", "rocks" } do
			for _, s in lists[name] do
				truthy(dist(t, s) > ArenaLayout.towerRadius + 2, name .. " in a tower")
			end
		end
	end
	for _, a in lists.tires do
		for _, b in lists.tires do
			if a ~= b then
				truthy(dist(a, b) > 2 * L.tires.radius)
			end
		end
	end
end)

test("trees stay off the hills and apart from each other", function()
	for _, t in lists.trees do
		for _, h in lists.hills do
			truthy(dist(t, h) > h.scale)
		end
		truthy(t.n == 1 or t.n == 2)
		truthy(t.scale >= 0.8 and t.scale <= 1.3)
	end
	for _, a in lists.trees do
		for _, b in lists.trees do
			if a ~= b then
				truthy(dist(a, b) > 6)
			end
		end
	end
end)

test("tire stacks are 2 or 3 high", function()
	for _, s in lists.tires do
		truthy(s.n == 2 or s.n == 3)
	end
end)

test("same config gives the same layout", function()
	same(ArenaLayout.tireStacks(), lists.tires)
	same(ArenaLayout.coneSpots(), lists.cones)
	same(ArenaLayout.hillSpots(), lists.hills)
	same(ArenaLayout.treeSpots(), lists.trees)
	same(ArenaLayout.rockSpots(), lists.rocks)
	same(ArenaLayout.cloudSpots(), lists.clouds)
	same(ArenaLayout.towerSpots(), lists.towers)
	same(ArenaLayout.hazardPadSpots(), lists.pads)
end)

test("the part budget stays phone friendly", function()
	local parts = 1
		+ 32
		+ 32
		+ 2
		+ 2
		+ 4 -- bowl: floor, slopes, walls, line, pads, spinner
		+ 1
		+ L.grassSegments
		+ L.roadSegments
		+ 32
		+ 8 -- ocean, grass, road, curb+skirt, stripes
		+ #lists.pads * 4
		+ #lists.tires * 3
		+ #lists.cones * 2
		+ #lists.barriers * 3
		+ #lists.towers * 4
		+ #lists.hills
		+ #lists.trees * 3
		+ #lists.rocks
		+ #lists.clouds * 3
	truthy(parts < 450, "too many parts: " .. parts)
end)
