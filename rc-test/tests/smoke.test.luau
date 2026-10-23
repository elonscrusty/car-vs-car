--!strict
local H = require("./harness")
local SmokeColors = require("../src/shared/SmokeColors")

local test, eq, truthy = H.test, H.eq, H.truthy

print("SmokeColors")

test("white is free and first; prices go up", function()
	eq(SmokeColors.LIST[1].name, "WHITE")
	eq(SmokeColors.LIST[1].stars, 0)
	for i = 2, #SmokeColors.LIST do
		truthy(SmokeColors.LIST[i].stars > SmokeColors.LIST[i - 1].stars)
	end
end)

test("cycling skips locked colours and wraps to white", function()
	eq(SmokeColors.nextOpen(1, 0), 1) -- only white open
	eq(SmokeColors.nextOpen(1, 6), 2)
	eq(SmokeColors.nextOpen(2, 6), 3)
	eq(SmokeColors.nextOpen(3, 6), 1)
	eq(SmokeColors.nextOpen(#SmokeColors.LIST, 0, true), 1)
	eq(SmokeColors.nextOpen(1, 0, true), 2)
end)

test("next locked colour", function()
	eq((SmokeColors.nextLocked(0) :: any).name, "RED")
	eq((SmokeColors.nextLocked(3) :: any).name, "BLUE")
	eq(SmokeColors.nextLocked(1000), nil)
end)
