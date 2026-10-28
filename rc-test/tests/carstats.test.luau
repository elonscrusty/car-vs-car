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
		local t = if table.find(Stats.STARTERS, id) then "starter" else r
		local b = Stats.base(id)
		eq(sum(b), 3 * Stats.TIERS[t].start, id .. " lean adds up to 0")
		eq(Stats.cap(id), Stats.TIERS[t].cap)
		eq(Stats.rate(id), Stats.TIERS[t].rate)
		truthy(b.speed >= 0 and b.turn >= 0 and b.boost >= 0, id .. " bars in range")
		truthy(math.max(b.speed, b.turn, b.boost) < Stats.cap(id), id .. " starts under its top")
		best[r] = best[r] or id
	end
	local order = table.clone(Cat.RARITY_ORDER)
	table.insert(order, 1, "starter")
	for i = 2, #order do
		local lo, hi = Stats.TIERS[order[i - 1]], Stats.TIERS[order[i]]
		truthy(hi.start > lo.start and hi.cap > lo.cap, "tier " .. i)
		-- (a starter trains like a common: it is low, not slow to grow)
		truthy(if i == 2 then hi.rate >= lo.rate else hi.rate > lo.rate, "tier rate " .. i)
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
	eq(sum(Stats.base("nope")), 66)
	eq(Stats.cap(nil), 70)
	local car: Training.Car = { uid = "u", id = "race_bolt", speed = 0, turn = 0, boost = 0 }
	eq(Stats.total(car), 24)
	local after = Training.gain(car, "treadmill", 1, 600, false, Stats.stats(car.id))
	truthy(Stats.total(after) > 24, "training adds")
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
	eq(v[1].value, 55) -- trained past the top still shows the top
	eq(v[1].fill, 0.55)
	eq(v[2].value, 6)
	eq(v[3].bar, "boost")
end)

test("carter 10-28: starters start low, crate and trained cars are clearly stronger", function()
	local RaceStats = require("../src/shared/RaceStats")
	local function fresh(id: string)
		return { uid = "u", id = id, speed = 0, turn = 0, boost = 0 }
	end
	local function maxed(id: string)
		return { uid = "u", id = id, speed = 999, turn = 999, boost = 999 }
	end
	local common = Stats.total(fresh("race_lime")) -- the plainest crate car
	for _, id in Stats.STARTERS do
		local start = Stats.total(fresh(id))
		truthy(start <= 30, `{id} starts low ({start})`)
		truthy(common >= 2.5 * start, `a crate common ({common}) is way over {id} ({start})`)
		truthy(Stats.total(maxed(id)) >= 5 * start, `training {id} is a big jump`)
		-- in the race: a fully trained starter is at least 15% faster than a fresh one (pillar 2)
		local a = RaceStats.drive(fresh(id), Stats.stats(id))
		local b = RaceStats.drive(maxed(id), Stats.stats(id))
		truthy(b.top >= a.top * 1.15, `{id} top {a.top} -> {b.top}`)
		-- and a fresh crate common is quicker than a fresh starter
		truthy(RaceStats.drive(fresh("race_lime"), Stats.stats("race_lime")).top > a.top)
	end
	-- every rarer kind starts stronger than the one below it
	local last = 0
	for _, id in { "race_bolt", "race_lime", "race_berry", "race_tiger", "gb_gold" } do
		local n = Stats.total(fresh(id))
		truthy(n > last, `{id} {n} over {last}`)
		last = n
	end
end)

local Layout = require("../src/shared/CarTagLayout")

test("car tag: every word is at least 16 px and every bar 8 px on a phone", function()
	truthy(Layout.smallestText() >= Layout.MIN_TEXT, `text row {Layout.smallestText()} px`)
	truthy(Layout.BAR_ROW * 0.76 * Layout.HEIGHT >= Layout.MIN_BAR, "bars thick enough")
	-- the three bar rows, the name and the kind all fit inside the tag and never overlap
	truthy(Layout.NAME.y + Layout.NAME.h <= Layout.KIND.y + 1e-9, "name above kind")
	truthy(Layout.KIND.y + Layout.KIND.h <= Layout.BAR_TOP + 1e-9, "kind above bars")
	truthy(Layout.BAR_ROW <= Layout.BAR_STEP, "bar rows do not overlap")
	truthy(Layout.barY(3) + Layout.BAR_ROW <= 1, "last bar inside the tag")
	-- a phone-wide screen (667 px) still has room for a tag
	truthy(Layout.WIDTH < 667 / 2, "tag under half the phone's width")
	truthy(Layout.TRACK_X + Layout.TRACK_W < Layout.VALUE_X, "bar ends before the number")
end)

test("tag bars: a bar at its car's top is full and gold, like MY GARAGE", function()
	local Lay = require("../src/shared/CarTagLayout")
	local f, full = Lay.barLook(60, 60, 100)
	eq(f, 1)
	eq(full, true)
	f, full = Lay.barLook(30, 60, 100)
	eq(f, 0.3)
	eq(full, false)
end)
