--!strict
local H = require("./harness")
local Build = require("../src/shared/Build")
local BuildConfig = require("../src/shared/BuildConfig")
local CarConfig = require("../src/shared/CarConfig")
local Inventory = require("../src/shared/Inventory")

print("Build")

H.test("every part is complete and belongs to exactly one slot", function()
	local seen: { [string]: boolean } = {}
	for _, slot in BuildConfig.Slots do
		H.truthy(#BuildConfig.Order[slot] >= 2, slot)
		H.truthy(BuildConfig.LevelBonus[slot] ~= nil, slot)
		for _, id in BuildConfig.Order[slot] do
			H.truthy(BuildConfig.Parts[id] ~= nil, id)
			H.eq(BuildConfig.Parts[id].id, id)
			H.eq(BuildConfig.slotOf(id), slot, id)
			H.truthy(not seen[id], "duplicate " .. id)
			seen[id] = true
		end
		local starter = BuildConfig.Starter[slot]
		H.eq(BuildConfig.slotOf(starter), slot)
		H.eq(BuildConfig.Parts[starter].cost, 0, "starter is free")
	end
	H.eq(#BuildConfig.LevelCost, BuildConfig.MaxLevel - 1)
	H.eq(BuildConfig.slotOf("nope"), nil)
	H.eq(BuildConfig.slotOf(3), nil)
end)

H.test("new profiles have a starter build and keep it through migrate", function()
	local p = Inventory.default()
	H.eq(p.build.carId, "Sedan")
	for _, slot in BuildConfig.Slots do
		H.eq(p.build.parts[slot], BuildConfig.Starter[slot])
		H.eq(p.build.levels[slot], 1)
	end
	local again = Inventory.migrate(p)
	H.eq(again.build.parts.engine, "basic")
	local old = Inventory.migrate({ coins = 5 }) -- an old save with no build
	H.eq(old.build.parts.wheels, "street")
end)

H.test("clean throws out junk", function()
	local b = Build.clean({
		carId = "Nope",
		owned = { turbo = true, bogus = true, plates = "yes" },
		parts = { engine = "turbo", wheels = "plates", armor = "plates" },
		levels = { wheels = 99, engine = -4, armor = 0 / 0 },
	})
	H.eq(b.carId, "Sedan")
	H.eq(b.owned.turbo, true)
	H.eq(b.owned.bogus, nil)
	H.eq(b.owned.plates, nil)
	H.eq(b.parts.engine, "turbo")
	H.eq(b.parts.wheels, "street", "a part in the wrong slot is ignored")
	H.eq(b.parts.armor, "none", "a part you do not own is ignored")
	H.eq(b.levels.wheels, BuildConfig.MaxLevel)
	H.eq(b.levels.engine, 1)
	H.eq(b.levels.armor, 1)
	H.eq(Build.clean("junk").carId, "Sedan")
end)

H.test("buying a part takes coins once and checks everything", function()
	local p = Inventory.default()
	local ok, why = Build.buyPart(p, "turbo")
	H.eq(ok, false)
	H.eq(why, "coins")
	p.coins = 1000
	ok = Build.buyPart(p, "turbo")
	H.eq(ok, true)
	H.eq(p.coins, 1000 - BuildConfig.Parts.turbo.cost)
	ok, why = Build.buyPart(p, "turbo")
	H.eq(ok, false)
	H.eq(why, "owned")
	ok, why = Build.buyPart(p, "gold")
	H.eq(why, "unknown")
	H.eq(p.coins, 1000 - BuildConfig.Parts.turbo.cost, "failed buys cost nothing")
end)

H.test("you can only wear parts you own", function()
	local p = Inventory.default()
	local ok, why = Build.equipPart(p, "racing")
	H.eq(ok, false)
	H.eq(why, "notowned")
	H.eq(p.build.parts.wheels, "street")
	p.build.owned.racing = true
	ok = Build.equipPart(p, "racing")
	H.eq(ok, true)
	H.eq(p.build.parts.wheels, "racing")
	ok = Build.equipPart(p, "street") -- going back is free
	H.eq(ok, true)
	H.eq(p.build.parts.wheels, "street")
end)

H.test("choosing the body needs a car you own", function()
	local p = Inventory.default()
	local ok, why = Build.setCar(p, "SuperCar")
	H.eq(ok, false)
	H.eq(why, "notowned")
	H.eq(Build.setCar(p, "Banana"), false)
	p.owned.SuperCar = true
	ok = Build.setCar(p, "SuperCar")
	H.eq(ok, true)
	H.eq(p.build.carId, "SuperCar")
	-- If the car is gone, the build falls back to one you own.
	H.eq(Build.carFor(p.build, { Compact = true }), "Compact")
	H.eq(Build.carFor(p.build, { SuperCar = true, Compact = true }), "SuperCar")
end)

H.test("upgrades cost coins, stop at the top level", function()
	local p = Inventory.default()
	p.coins = 100000
	for level = 1, BuildConfig.MaxLevel - 1 do
		local before = p.coins
		H.eq(Build.upgradeCost(p.build, "armor"), BuildConfig.LevelCost[level])
		local ok = Build.upgrade(p, "armor")
		H.eq(ok, true)
		H.eq(p.coins, before - BuildConfig.LevelCost[level])
		H.eq(p.build.levels.armor, level + 1)
	end
	local ok, why = Build.upgrade(p, "armor")
	H.eq(ok, false)
	H.eq(why, "max")
	H.eq(Build.upgradeCost(p.build, "armor"), nil)
	p.coins = 0
	ok, why = Build.upgrade(p, "engine")
	H.eq(why, "coins")
	H.eq(Build.upgrade(p, "doors"), false)
end)

H.test("stats: starter build is the plain car, parts and levels add up", function()
	local base = CarConfig.Cars.Sedan
	local plain = Build.stats(base, Build.default())
	for _, key in { "hp", "mass", "maxSpeed", "accel", "turnRate", "damageMult", "hitLift" } do
		H.near((plain :: any)[key], (base :: any)[key], 0.51, key)
	end
	H.truthy(plain ~= base, "returns a copy")

	local b = Build.default()
	b.parts.armor = "plates"
	b.parts.engine = "turbo"
	local s = Build.stats(base, b)
	H.truthy(s.hp > base.hp, "plates add health")
	H.truthy(s.mass > base.mass)
	H.truthy(s.accel > base.accel, "turbo speeds up")
	H.eq(base.hp, CarConfig.Cars.Sedan.hp, "the base car is never changed")

	local lv = Build.copy(b)
	lv.levels.armor = BuildConfig.MaxLevel
	H.truthy(Build.stats(base, lv).hp > s.hp, "levels add health")

	local ram = Build.default()
	ram.parts.armor = "ram"
	H.near(Build.stats(base, ram).hitLift, base.hitLift + 10)
end)

H.test("a better build is a stronger car", function()
	local base = CarConfig.Cars.Compact
	local plain = Build.default()
	local strong = Build.copy(plain)
	strong.parts.armor = "spikes"
	strong.levels.armor = 3
	strong.levels.engine = 3
	H.truthy(Build.power(base, strong) > Build.power(base, plain))
end)

H.test("bot builds are valid and close to the player's level", function()
	local seq = 0
	local rng = function(): number
		seq += 1
		return ((seq * 0.37) % 1)
	end
	for level = 1, BuildConfig.MaxLevel do
		local b = Build.botBuild(rng, level)
		for _, slot in BuildConfig.Slots do
			H.eq(BuildConfig.slotOf(b.parts[slot]), slot)
			H.truthy(b.owned[b.parts[slot]])
			H.truthy(math.abs(b.levels[slot] - level) <= 1)
			H.truthy(b.levels[slot] >= 1 and b.levels[slot] <= BuildConfig.MaxLevel)
		end
	end
	local b = Build.default()
	b.levels.wheels, b.levels.engine, b.levels.armor = 5, 4, 4
	H.eq(Build.averageLevel(b), 4)
	H.eq(Build.averageLevel(Build.default()), 1)
end)
