--!strict
-- Plot looks by stars (PlotLooks.luau): the tier edges, nothing on the driving line, the walk
-- to the stand stays open, and the phone budget for lights.
local H = require("./harness")
local L = require("../src/shared/PlotLooks")
local P = require("../src/shared/PlotDecor")

local test, truthy, eq = H.test, H.truthy, H.eq

print("Plot looks")

test("every look builds something", function()
	for _, id in L.IDS do
		truthy(#L.parts("race", id) > 0, id)
	end
	eq(table.concat(L.fromStars(30), ","), "night,snow")
end)

test("tiers: day, night at 10, snow at 25, lights + fans at 50", function()
	for _, c in
		{ { 0, 0 }, { 9, 0 }, { 10, 1 }, { 24, 1 }, { 25, 2 }, { 49, 2 }, { 50, 3 }, { 400, 3 } }
	do
		eq(L.tier(c[1]), c[2])
	end
end)

for _, kind in { "race", "drift", "rock" } do
	test(kind .. ": nothing low on the track, everything over the plot", function()
		local W, D = P.HALF_W, P.HALF_D
		for _, t in L.IDS do
			for _, p in L.parts(kind, t) do
				local x0, x1 = p.pos.x - p.size.x / 2, p.pos.x + p.size.x / 2
				local z0, z1 = p.pos.z - p.size.z / 2, p.pos.z + p.size.z / 2
				local y0 = p.pos.y - p.size.y / 2
				local name = t .. "/" .. p.name
				truthy(
					math.abs(p.pos.x) <= W + 1 and math.abs(p.pos.z) <= D + 1,
					name .. " over the plot"
				)
				local onWall = x0 >= W - 1 or x1 <= -W + 1 or z1 <= -D + 1 or z0 >= D - 1
				local front = z0 >= P.FRONT_Z + 0.3
				truthy(y0 >= 1.4 or onWall or front, name .. " not on the track")
			end
		end
	end)

	test(kind .. ": the walk to the stand stays open", function()
		local lane = P.LANE
		for _, p in L.allParts(kind, L.IDS) do
			local hit = p.collide
				and p.pos.x + p.size.x / 2 > lane.minX
				and p.pos.x - p.size.x / 2 < lane.maxX
				and p.pos.z + p.size.z / 2 > lane.minZ
				and p.pos.z - p.size.z / 2 < lane.maxZ
			truthy(not hit, p.name)
		end
	end)

	test(
		kind .. ": lights within the phone budget (with the decor's lanterns and booth)",
		function()
			local n = 5 -- PlotDecor: 4 lanterns lit at night + the booth light
			for _, p in L.allParts(kind, L.IDS) do
				if p.light then
					n += 1
				end
			end
			truthy(n <= L.MAX_LIGHTS, tostring(n))
		end
	)
end
