--!strict
local H = require("./harness")
local CarCatalog = require("../src/shared/CarCatalog")
local CarConfig = require("../src/shared/CarConfig")
local Progress = require("../src/shared/Progress")
local ProgressConfig = require("../src/shared/ProgressConfig")

local test, eq, near, truthy = H.test, H.eq, H.near, H.truthy

print("Audit fixes: cars")

test("rarity style: every rarity has colors, only Legendary has the look moment", function()
	for _, rarity in CarConfig.Rarities do
		local s = CarCatalog.styleFor(rarity)
		eq(#s.trailRgb, 3)
		eq(#s.effectRgb, 3)
		eq(s.moment, rarity == "Legendary")
	end
	eq(CarCatalog.styleFor("Nope"), CarCatalog.RarityStyle.Common)
	eq(CarCatalog.styleFor(5), CarCatalog.RarityStyle.Common)
end)

test("rarity style: rarities look different from each other", function()
	local seen: { [string]: boolean } = {}
	for _, rarity in { "Common", "Rare", "Epic", "Legendary" } do
		local key = table.concat(CarCatalog.styleFor(rarity).effectRgb, ",")
		truthy(not seen[key], rarity .. " shares a color")
		seen[key] = true
	end
end)

test("mode stars: every catalog car gets 1-3 stars in each mode", function()
	for _, e in CarCatalog.Entries do
		local s = CarCatalog.modeStars(e.id)
		truthy(s ~= nil)
		for _, mode in CarCatalog.StarModes do
			local n = (s :: any)[mode]
			truthy(n >= 1 and n <= 3, e.id .. " " .. mode)
		end
	end
	eq(CarCatalog.modeStars("Nope"), nil)
	eq(CarCatalog.modeStars(7), nil)
end)

test("mode stars: light cars suit soccer and race, heavy cars suit tag", function()
	local compact = CarCatalog.modeStars("Compact") :: any
	local box = CarCatalog.modeStars("BoxTruck") :: any
	truthy(compact.SOCCER > box.SOCCER)
	truthy(compact.RACE > box.RACE)
	truthy(box.TAG > compact.TAG)
	local sedan = CarCatalog.modeStars("Sedan") :: any
	eq(sedan.SOCCER, 2)
	eq(sedan.TAG, 2)
	eq(sedan.RACE, 2)
end)

test("mode stars: the neutral car is 2 stars everywhere and stars follow the stats", function()
	local neutral = CarCatalog.modeStarsFromStats({})
	eq(neutral.SOCCER, 2)
	eq(neutral.TAG, 2)
	eq(neutral.RACE, 2)
	local fast = CarCatalog.modeStarsFromStats({ maxSpeed = 140, accel = 200 })
	eq(fast.RACE, 3)
end)

test("level bonus is tiny and levels unlock cosmetics", function()
	near(ProgressConfig.LevelStatBonus, 0.01)
	near(Progress.statMult(1), 1)
	near(Progress.statMult(10), 1.09)
	eq(#CarCatalog.cosmeticsAt(1), 0)
	eq(CarCatalog.cosmeticsAt(2)[1], "StripeWhite")
	eq(#CarCatalog.cosmeticsAt("x"), 0)
	eq(#CarCatalog.cosmeticsUpTo(1), 0)
	eq(#CarCatalog.cosmeticsUpTo(10), 9)
	eq(#CarCatalog.cosmeticsUpTo(0 / 0), 0)
	local ids: { [string]: boolean } = {}
	for level = 2, Progress.maxLevel() do
		local row = CarCatalog.LevelCosmetics[level]
		truthy(row ~= nil, "level " .. level)
		truthy(row.kind == "stripe" or row.kind == "wheel")
		truthy(not ids[row.id], "duplicate " .. row.id)
		ids[row.id] = true
	end
end)

test("steer smoothing: normal cars instant, small cars slower, never below minRate", function()
	local c = CarConfig.SteerSmooth
	eq(CarConfig.steerSmoothRate(3.4), c.offRate)
	eq(CarConfig.steerSmoothRate(3.6), c.offRate)
	truthy(CarConfig.steerSmoothRate(4.4) < c.startRate)
	truthy(CarConfig.steerSmoothRate(4.4) > c.minRate)
	near(CarConfig.steerSmoothRate(5.0), c.minRate)
	near(CarConfig.steerSmoothRate(9), c.minRate)
	eq(CarConfig.steerSmoothRate(0 / 0), c.offRate)
	eq(CarConfig.steerSmoothRate(4.8, { enabled = false, offRate = 77 }), 77)
	-- monotonic: a quicker-turning car never smooths less
	truthy(CarConfig.steerSmoothRate(4.0) >= CarConfig.steerSmoothRate(4.6))
end)
