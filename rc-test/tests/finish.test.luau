--!strict
-- Decor finishes (Finish.luau): looks only, never on anything the car drives on.
local H = require("./harness")
local F = require("../src/shared/Finish")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Finish")

test("a finish only replaces plain SmoothPlastic", function()
	local list = F.apply({
		{ name = "Bush", material = "SmoothPlastic" },
		{ name = "Bush", material = "Neon" },
		{ name = "Road", material = "SmoothPlastic" },
	})
	eq(list[1].material, "Grass")
	eq(list[2].material, "Neon")
	eq(list[3].material, "SmoothPlastic")
end)

test("no finish for road, curb or paint parts", function()
	for name in F.BY_NAME do
		truthy(not string.find(name, "Road") and not string.find(name, "Curb"), name)
	end
end)
