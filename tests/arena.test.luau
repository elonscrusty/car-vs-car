--!strict
local Harness = require("./harness")
local ArenaMath = require("../src/shared/ArenaMath")
local GameConfig = require("../src/shared/GameConfig")

local test, eq, near, truthy = Harness.test, Harness.eq, Harness.near, Harness.truthy

print("ArenaMath")

local A = GameConfig.Arena

test("bowl is flat in the middle and rises to the rim", function()
	eq(ArenaMath.surfaceHeight(0, A.flatRadius, A.rimRadius, A.tiltDeg), 0)
	eq(ArenaMath.surfaceHeight(A.flatRadius, A.flatRadius, A.rimRadius, A.tiltDeg), 0)
	local rim = ArenaMath.surfaceHeight(A.rimRadius, A.flatRadius, A.rimRadius, A.tiltDeg)
	near(rim, (A.rimRadius - A.flatRadius) * math.tan(math.rad(A.tiltDeg)), 1e-9)
	truthy(rim > 10)
	-- clamped outside rim
	near(ArenaMath.surfaceHeight(999, A.flatRadius, A.rimRadius, A.tiltDeg), rim)
end)

test("bowl is about 120 studs across", function()
	truthy(A.rimRadius * 2 >= 110 and A.rimRadius * 2 <= 130)
end)

test("slope slab is longer than horizontal run", function()
	local len = ArenaMath.slopeLength(A.flatRadius, A.rimRadius, A.tiltDeg)
	truthy(len > A.rimRadius - A.flatRadius)
	near(len * math.cos(math.rad(A.tiltDeg)), A.rimRadius - A.flatRadius, 1e-9)
end)

test("slabs overlap at the rim", function()
	local circumference = 2 * math.pi * A.rimRadius
	truthy(ArenaMath.slabWidth(A.rimRadius, A.segments) * A.segments > circumference)
end)

test("spawn spots are on the slope, inside the rim", function()
	truthy(A.spawnRadius > A.flatRadius and A.spawnRadius < A.rimRadius)
end)
