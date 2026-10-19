--!strict
local H = require("./harness")
local Fight = require("../src/shared/Fight")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Fight")

test("ring-out only past rim + margin", function()
	eq(Fight.isRingOut(60, 62, 3), false)
	eq(Fight.isRingOut(65, 62, 3), false)
	truthy(Fight.isRingOut(65.1, 62, 3))
end)

test("edge distance: round = straight line, square = biggest of |x| and |z|", function()
	eq(Fight.edgeDistance(30, 40, false), 50)
	eq(Fight.edgeDistance(30, -40, true), 40)
	eq(Fight.edgeDistance(-55, 10, true), 55)
	-- a square corner is not extra safe floor
	truthy(Fight.isRingOut(Fight.edgeDistance(64, 64, true), 60, 3))
end)
