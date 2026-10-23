--!strict
-- Car stands at each plot (PlotStands.luau): which cars show, and the stands fit the front area.
local H = require("./harness")
local Kit = require("../src/shared/Plots/Kit")
local P = require("../src/shared/PlotStands")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Plot stands")

test("the owner's cars: known ones only, no repeats, at most 3, a starter when none", function()
	-- rock crawlers were dropped: an old "rock:3" is skipped like any unknown car
	local cars = P.parse("race:2, drift:1,race:2,boat:1,rock:3,race:99,drift:3,race:1", "race")
	eq(#cars, 3)
	eq(cars[1].kind, "race")
	eq(cars[1].index, 2)
	eq(cars[2].kind, "drift")
	eq(cars[3].kind, "drift")
	eq(cars[3].index, 3)
	local starter = P.parse(nil, "drift")
	eq(#starter, 1)
	eq(starter[1].kind, "drift")
	eq(starter[1].index, 1)
end)

test("3 stands in the plot's front area, inside the plot, clear of the driver stand", function()
	eq(#P.SPOTS, 3)
	local s = 0.25
	for _, spot in P.SPOTS do
		truthy(spot.z - P.RADIUS > Kit.FRONT_Z * s, "in front of the low wall")
		truthy(spot.z + P.RADIUS < Kit.DEPTH / 2 * s, "inside the front edge")
		truthy(math.abs(spot.x) + P.RADIUS < Kit.WIDTH / 2 * s, "inside the side walls")
		truthy(spot.x + P.RADIUS < Kit.STAND.x * s - 3.5, "left of the driver stand")
	end
end)

test("every car sits on its stand, not floating or sunk", function()
	local pieces = P.pieces(P.parse("race:1,drift:2,rock:3", "race"))
	local cars = 0
	for _, p in pieces do
		if string.sub(p.group, 1, 3) == "Car" then
			cars += 1
			truthy(p.pos.y - p.size.y / 2 >= P.TOP - 0.05, p.name .. " not sunk")
		end
	end
	truthy(cars > 0)
	-- no owner: empty stands only
	for _, p in P.pieces({}) do
		eq(p.group, "Stands")
	end
end)
