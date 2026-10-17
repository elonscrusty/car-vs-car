--!strict
local Harness = require("./harness")
local CarConfig = require("../src/shared/CarConfig")

local test, eq, truthy = Harness.test, Harness.eq, Harness.truthy

print("CarConfig")

test("4 cars exist with sane numbers", function()
	eq(#CarConfig.Order, 4)
	for _, id in CarConfig.Order do
		local s = CarConfig.Cars[id]
		truthy(s ~= nil, id .. " missing")
		truthy(s.hp > 0 and s.mass > 0 and s.maxSpeed > 0 and s.accel > 0, id .. " bad numbers")
		truthy(s.damageMult > 0 and s.turnRate > 0, id .. " bad mults")
		eq(#s.rgb, 3, id .. " rgb")
		eq(#s.size, 3, id .. " size")
	end
end)

test("get() only accepts real ids", function()
	truthy(CarConfig.get("Heavy") ~= nil)
	eq(CarConfig.get("Nope"), nil)
	eq(CarConfig.get(5), nil)
	eq(CarConfig.get(nil), nil)
	eq(CarConfig.get({}), nil)
	eq(CarConfig.get("__index"), nil)
end)

test("Spike hits hardest, Heavy has most HP, Light is fastest", function()
	local c = CarConfig.Cars
	for _, id in CarConfig.Order do
		truthy(c.Spike.damageMult >= c[id].damageMult)
		truthy(c.Heavy.hp >= c[id].hp)
		truthy(c.Light.maxSpeed >= c[id].maxSpeed)
	end
	truthy(c.Ramp.hitLift > 0)
end)
