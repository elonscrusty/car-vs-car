--!strict
-- CarStats.luau: 24 cars, rarer = higher start, higher top, faster training; three common
-- starters; a clean spread of rarities; each car's lean never changes its total.
local H = require("./harness")
local Cat = require("../src/shared/CarCatalog")
local Stats = require("../src/shared/CarStats")
local Training = require("../src/shared/Training")

local test, truthy, eq = H.test, H.truthy, H.eq

print("Car stats")

local function sum(b: any): number
	return b.speed + b.turn + b.boost
end

test("every car in the game has a row (24) and no row is for a stranger", function()
	local ids = Stats.ids()
	eq(#ids, 24)
	for _, id in ids do
		truthy(Cat.get(id) ~= nil, id .. " is a car")
	end
	local n = 0
	for _, list in Cat.SHOP do
		n += #list
	end
	eq(n + #Cat.GUMBALL, 24)
end)

test("rarity spread: 8 common, 8 rare, 5 epic, 3 legend", function()
	local count: { [string]: number } = {}
	for _, id in Stats.ids() do
		local r = Cat.get(id).rarity
		count[r] = (count[r] or 0) + 1
	end
	eq(count.common, 8)
	eq(count.rare, 8)
	eq(count.epic, 5)
	eq(count.legend, 3)
end)

test("a rarer car starts higher, tops out higher and trains faster", function()
	local best: { [string]: any } = {}
	for _, id in Stats.ids() do
		local r = Cat.get(id).rarity
		local b = Stats.base(id)
		eq(sum(b), 3 * Stats.TIERS[r].start, id .. " lean adds up to 0")
		eq(Stats.cap(id), Stats.TIERS[r].cap)
		eq(Stats.rate(id), Stats.TIERS[r].rate)
		truthy(b.speed >= 0 and b.turn >= 0 and b.boost >= 0, id .. " bars in range")
		truthy(math.max(b.speed, b.turn, b.boost) < Stats.cap(id), id .. " starts under its top")
		best[r] = best[r] or id
	end
	for i = 2, #Cat.RARITY_ORDER do
		local lo, hi = Stats.TIERS[Cat.RARITY_ORDER[i - 1]], Stats.TIERS[Cat.RARITY_ORDER[i]]
		truthy(hi.start > lo.start and hi.cap > lo.cap and hi.rate > lo.rate, "tier " .. i)
	end
end)

test("three common starters, each leaning a different way", function()
	eq(#Stats.STARTERS, 3)
	local lean: { [string]: boolean } = {}
	for _, id in Stats.STARTERS do
		eq(Cat.get(id).rarity, "common")
		local b = Stats.base(id)
		local top = if b.speed > b.turn and b.speed > b.boost
			then "speed"
			elseif b.turn > b.boost then "turn"
			else "boost"
		lean[top] = true
	end
	eq(lean.speed and lean.turn and lean.boost, true)
end)

test("unknown ids are a plain common; stats and total work with Training", function()
	eq(sum(Stats.base("nope")), 60)
	eq(Stats.cap(nil), 60)
	local car: Training.Car = { uid = "u", id = "race_bolt", speed = 0, turn = 0, boost = 0 }
	eq(Stats.total(car), 60)
	local after = Training.gain(car, "treadmill", 1, 600, false, Stats.stats(car.id))
	truthy(Stats.total(after) > 60, "training adds")
	local legend = Training.gain(
		{ uid = "u", id = "gb_gold", speed = 0, turn = 0, boost = 0 },
		"treadmill",
		1,
		60,
		false,
		Stats.stats("gb_gold")
	)
	truthy(legend.speed > after.speed / 10, "a legend trains faster per minute")
end)

test("the tag view lists three bars, rounded, never past the top", function()
	local v = Stats.view({ uid = "u", id = "race_bolt", speed = 500, turn = 0, boost = 0 })
	eq(#v, 3)
	eq(v[1].label, "SPD")
	eq(v[1].value, 60) -- trained past the top still shows the top
	eq(v[1].fill, 0.6)
	eq(v[2].value, 18)
	eq(v[3].bar, "boost")
end)
