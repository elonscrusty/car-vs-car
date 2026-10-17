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
