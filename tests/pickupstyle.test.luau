--!strict
local Harness = require("./harness")
local PickupStyle = require("../src/shared/PickupStyle")
local PickupsConfig = require("../src/shared/PickupsConfig")

local test, eq, near, truthy = Harness.test, Harness.eq, Harness.near, Harness.truthy

print("PickupStyle")

test("every pickup kind has a name, a color and an icon within the part budget", function()
	for _, kind in PickupsConfig.kinds do
		truthy((PickupsConfig.names :: any)[kind], kind .. " name")
		local c = (PickupsConfig.colors :: any)[kind]
		truthy(c and #c == 3, kind .. " color")
		local parts = PickupStyle.iconParts(kind, c)
		truthy(#parts >= 2, kind .. " is more than one blob")
		truthy(#parts <= PickupStyle.maxIconParts, kind .. " over budget")
		for _, p in parts do
			eq(#p.size, 3)
			eq(#p.offset, 3)
			eq(#p.color, 3)
		end
	end
end)

test("the name pill grows with the text", function()
	truthy(PickupStyle.pillWidth("SHIELD") > PickupStyle.pillWidth("SPEED"))
	truthy(PickupStyle.pillWidth("BIG HIT") > PickupStyle.pillWidth("HIT"))
end)

test("the bob stays between rest and twice the bob height", function()
	near(PickupStyle.bobOffset(0), 0, 1e-9)
	near(PickupStyle.bobOffset(PickupStyle.bobSeconds / 2), 2 * PickupStyle.bobHeight, 1e-9)
	for i = 0, 40 do
		local o = PickupStyle.bobOffset(i * 0.37)
		truthy(o >= -1e-9 and o <= 2 * PickupStyle.bobHeight + 1e-9)
	end
end)

test("the spin wraps below 360 degrees", function()
	eq(PickupStyle.spinDeg(0), 0)
	truthy(PickupStyle.spinDeg(1000) < 360)
end)
