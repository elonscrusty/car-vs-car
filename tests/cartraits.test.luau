--!strict
local H = require("./harness")
local CarConfig = require("../src/shared/CarConfig")
local CarTraits = require("../src/shared/CarTraits")
local CarTraitsConfig = require("../src/shared/CarTraitsConfig")

local test, eq, truthy, near = H.test, H.eq, H.truthy, H.near

print("CarTraits")

test("resolve fills defaults, clamps wild values and ignores junk", function()
	local d = CarTraits.resolve(nil, nil)
	eq(d.grip, 1)
	eq(d.punch, 0)
	eq(d.sizeScale, 1)
	local wild = CarTraits.resolve({ grip = 99, drift = -4, punch = 9, highTurn = 0 }, nil)
	eq(wild.grip, CarTraitsConfig.Limits.grip[2])
	eq(wild.drift, 0)
	eq(wild.punch, CarTraitsConfig.Limits.punch[2])
	eq(wild.highTurn, CarTraitsConfig.Limits.highTurn[1])
	local junk = CarTraits.resolve({ grip = 0 / 0 }, nil)
	eq(junk.grip, 1)
	-- hand-written size gives the scale (11 long vs 8)
	near(CarTraits.resolve({}, { 7, 3, 11 }).sizeScale, 11 / 8)
end)

test("every car has traits inside the limits", function()
	for _, id in CarConfig.FullOrder do
		local t = CarTraits.of(CarConfig.Cars[id])
		for key, lim in CarTraitsConfig.Limits do
			local v = (t :: any)[key]
			truthy(v >= lim[1] and v <= lim[2], `{id}.{key}={v}`)
		end
	end
end)

test("the driving curves behave", function()
	local light = CarTraits.of(CarConfig.Cars.Compact)
	local heavy = CarTraits.of(CarConfig.Cars.BoxTruck)
	-- punch: strong launch fades; negative punch starts slow and keeps pulling
	truthy(CarTraits.accelFactor(light, 0) > 1)
	truthy(CarTraits.accelFactor(light, 1) < 1)
	truthy(CarTraits.accelFactor(heavy, 0) < 1)
	truthy(CarTraits.accelFactor(heavy, 1) > 1)
	-- drift: hard steering at speed loosens a drifty car, not when going straight or slow
	local drifter = CarTraits.of(CarConfig.Cars.DriftKing)
	truthy(CarTraits.gripFactor(drifter, 1, 1) < CarTraits.gripFactor(drifter, 0, 1))
	near(CarTraits.gripFactor(drifter, 1, 0), drifter.grip)
	truthy(CarTraits.gripFactor(drifter, 1, 1) >= CarTraitsConfig.minGrip)
	-- turn: standing still is always 1, top speed is the trait
	near(CarTraits.turnFactor(heavy, 0), 1)
	near(CarTraits.turnFactor(heavy, 1), heavy.highTurn)
	-- a light car grips less than a heavy one, and a heavy car turns wider at speed
	truthy(light.grip < heavy.grip)
	truthy(CarTraits.turnFactor(heavy, 1) < CarTraits.turnFactor(light, 1))
	-- default traits change nothing
	local plain = CarTraits.resolve(nil, nil)
	near(CarTraits.accelFactor(plain, 0.5), 1)
	near(CarTraits.gripFactor(plain, 1, 1), 1)
	near(CarTraits.turnFactor(plain, 1), 1)
	eq(CarTraits.speedFrac(5, 0), 0)
	eq(CarTraits.speedFrac(-200, 100), 1)
end)

test("bars are 0..1 and order cars sensibly", function()
	for _, id in CarConfig.FullOrder do
		for name, v in CarTraits.bars(CarConfig.Cars[id]) do
			truthy(v >= 0 and v <= 1, `{id} {name}`)
		end
	end
	local rocket = CarTraits.bars(CarConfig.Cars.SuperCar)
	local tank = CarTraits.bars(CarConfig.Cars.ArmoredTruck)
	truthy(rocket.speed > tank.speed)
	truthy(tank.weight > rocket.weight)
	truthy(tank.hp > rocket.hp)
	truthy(rocket.turn > tank.turn)
end)

test("describe gives short kid text", function()
	eq(CarTraits.describe(CarConfig.Cars.SuperCar), "Fast, fragile")
	eq(CarTraits.describe({ maxSpeed = 75, mass = 70, turnRate = 3.5, hp = 150 }), "Balanced")
	for _, id in CarConfig.LaunchRoster do
		local text = CarTraits.describe(CarConfig.Cars[id])
		truthy(#text > 3 and #text <= 30, `{id}: {text}`)
	end
	-- slippery cars say so, grippy heavy ones too
	truthy(string.find(CarTraits.describe(CarConfig.Cars.DriftKing), "lippery", 1, true) ~= nil)
	truthy(string.find(CarTraits.describe(CarConfig.Cars.Muscle), "eavy", 1, true) ~= nil)
end)

test("every launch car differs from every other in at least 2 traits", function()
	local roster = CarConfig.LaunchRoster
	for i = 1, #roster do
		for j = i + 1, #roster do
			local a = CarTraits.of(CarConfig.Cars[roster[i]])
			local b = CarTraits.of(CarConfig.Cars[roster[j]])
			local n = CarTraits.differences(a, b)
			truthy(n >= 2, `{roster[i]} vs {roster[j]} differ in only {n} traits`)
		end
	end
end)

test("pack car body size follows the sizeScale trait; mass is untouched", function()
	local mt = CarConfig.Cars.MonsterTruck
	near(mt.size[3], 8 * 1.35)
	near(mt.traits.sizeScale, 1.35)
	eq(mt.mass, 130)
	eq(CarConfig.Cars.Sedan.size[3], 8)
end)
