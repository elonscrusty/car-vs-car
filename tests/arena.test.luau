--!strict
local Harness = require("./harness")
local ArenaMath = require("../src/shared/ArenaMath")
local GameConfig = require("../src/shared/GameConfig")

local test, eq, near, truthy = Harness.test, Harness.eq, Harness.near, Harness.truthy

print("ArenaMath")

local A = GameConfig.Arena

test("the middle is flat and the bowl rises toward the rim", function()
	eq(ArenaMath.surfaceHeight(0, A.flatRadius, A.rimRadius, A.tiltDeg), 0)
	eq(ArenaMath.surfaceHeight(A.flatRadius, A.flatRadius, A.rimRadius, A.tiltDeg), 0)
	local rim = ArenaMath.surfaceHeight(A.rimRadius, A.flatRadius, A.rimRadius, A.tiltDeg)
	truthy(if A.tiltDeg > 0 then rim > 0 else rim == 0)
	eq(ArenaMath.surfaceHeight(999, A.flatRadius, A.rimRadius, A.tiltDeg), rim)
end)

test("arena is 100 to 140 studs across", function()
	truthy(A.rimRadius * 2 >= 180 and A.rimRadius * 2 <= 260)
end)

test("a sloped bowl still gets a longer slab than its run", function()
	local len = ArenaMath.slopeLength(25, 62, 20)
	truthy(len > 62 - 25)
	near(len * math.cos(math.rad(20)), 62 - 25, 1e-9)
end)

test("slabs overlap at the rim", function()
	local circumference = 2 * math.pi * A.rimRadius
	truthy(ArenaMath.slabWidth(A.rimRadius, A.segments) * A.segments > circumference)
end)

test("spawn spots are inside the walls", function()
	truthy(A.spawnRadius < A.rimRadius)
end)

test("obstacles stay inside the walls and are mirrored", function()
	for _, o in A.obstacles do
		truthy(math.sqrt(o.x * o.x + o.z * o.z) < A.rimRadius - 6)
		local mirrored = false
		for _, m in A.obstacles do
			if m.kind == o.kind and m.x == -o.x and m.z == -o.z then
				mirrored = true
			end
		end
		truthy(mirrored, "obstacle has a mirror twin")
	end
end)
