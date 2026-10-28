--!strict
-- Car VS Car Smash's warm-up yard (WarmupYard.luau): everything sits inside its walls and apart,
-- it's far from the lobby, and the clock words read right.
local H = require("./harness")
local Y = require("../src/shared/WarmupYard")

local test, truthy, eq = H.test, H.truthy, H.eq

print("Warm-up yard")

local function within(p: any, margin: number): boolean
	return math.abs(p.x) <= Y.W / 2 - margin and math.abs(p.z) <= Y.D / 2 - margin
end

test("yard: spawns, boxes and dummies all inside the walls, and apart", function()
	local all = {}
	for _, s in Y.SPAWNS do
		truthy(within(s, 4), "spawn by a wall")
		table.insert(all, s)
	end
	eq(#Y.SPAWNS, 8)
	for _, b in Y.BOXES do
		truthy(within(b, 4), "box by a wall")
		table.insert(all, b)
	end
	for _, d in Y.DUMMIES do
		truthy(within(d.at, 6), "dummy by a wall")
		truthy(d.mode == "still" or d.mode == "circle", d.mode)
		table.insert(all, d.at)
	end
	for i, a in all do
		for j = i + 1, #all do
			local b = all[j]
			local gap = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
			truthy(gap >= 6, `spots {i} and {j} only {gap} apart`)
		end
	end
end)

test("yard: far from the lobby, plots and old race maps; inside() knows who's in", function()
	truthy(Y.ORIGIN.z <= -1500, "too close to the lobby")
	truthy(Y.inside(Y.world(Y.SPAWNS[1])))
	truthy(not Y.inside({ x = 0, y = 0, z = 1000 }))
	truthy(not Y.inside(Y.world({ x = Y.W, y = 0, z = 0 })))
end)

test("yard: parts are low-poly (SmoothPlastic or Neon only) and the walls close it", function()
	local walls = 0
	for _, p in Y.parts() do
		truthy(p.material == "SmoothPlastic" or p.material == "Neon", p.material)
		if p.group == "Walls" and p.name ~= "Post" then
			walls += 1
		end
	end
	eq(walls, 4)
end)

test("yard: the clock reads NEXT MATCH IN m:ss, GET READY! at 0, WARM UP! with no round", function()
	eq(Y.clock(102), "NEXT MATCH IN 1:42")
	eq(Y.clock(101.2), "NEXT MATCH IN 1:42")
	eq(Y.clock(9), "NEXT MATCH IN 0:09")
	eq(Y.clock(0.2), "GET READY!")
	eq(Y.clock(-3), "GET READY!")
	eq(Y.clock(nil), "WARM UP!")
	eq(Y.clock(0 / 0), "WARM UP!")
end)
