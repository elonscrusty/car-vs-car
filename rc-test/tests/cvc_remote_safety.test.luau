--!strict
-- The Garage remote (TrainingServer) hands whatever a phone sends straight to CvcRules, so a
-- cheater's junk must change nothing: bad numbers, wrong types, a uid that isn't in your garage,
-- a crate you can't pay for. Nothing may be bought twice with the same coins.
local H = require("./harness")
local CarStats = require("../src/shared/CarStats")
local Crates = require("../src/shared/Crates")
local CvcRules = require("../src/shared/CvcRules")
local Profile = require("../src/shared/Profile")
local Training = require("../src/shared/Training")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Car VS Car: Garage remote safety")

local NAN = 0 / 0
local junk: { any } = {
	NAN,
	math.huge,
	-math.huge,
	-1,
	0,
	0.5,
	1.5,
	99,
	1e308,
	"",
	"nope",
	"1",
	string.rep("x", 5000),
	{},
	{ 1 },
	true,
	false,
}

local function rng(n: number): Crates.Rng
	return {
		NextNumber = function(_: any): number
			return n
		end,
	} :: any
end

-- a player who picked a starter and has coins, a plot level and a crate
local function player(): Profile.Data
	local d = Profile.new()
	CvcRules.setUp(d)
	assert(CvcRules.pick(d, CarStats.STARTERS[1]), "pick")
	d.coins = 5000
	d.crates = 1
	return d
end

-- the save as plain text, to see that nothing moved
local function fingerprint(d: Profile.Data): string
	local parts: { string } = { tostring(d.coins), tostring(d.crates), tostring(d.plotLevel) }
	table.insert(parts, d.racer)
	for _, c in d.garage do
		table.insert(parts, `{c.uid}:{c.id}:{c.speed}:{c.turn}:{c.boost}`)
	end
	for _, st in d.stations do
		table.insert(parts, `{st.kind}:{st.level}:{st.uid}`)
	end
	return table.concat(parts, "|")
end

test("junk station asks change nothing", function()
	local d = player()
	local before = fingerprint(d)
	for _, i in junk do
		for _, uid in junk do
			if not (i == 1 and uid == "") then
				-- (station 1 with "" is a real ask: take the car off)
				local d2 = player()
				local was = fingerprint(d2)
				local ok = CvcRules.station(d2, i, uid)
				if ok then
					-- only a real station and a real uid (or "") may pass
					truthy(type(i) == "number" and d2.stations[i] ~= nil, "bad station accepted")
					truthy(uid == "" or Profile.findCar(d2, uid :: string) ~= nil, "foreign car")
				else
					eq(fingerprint(d2), was)
				end
			end
		end
	end
	eq(fingerprint(d), before)
end)

test("a car that isn't in your garage can't go on a station or race", function()
	local d = player()
	local before = fingerprint(d)
	-- (uids count up from 1: a friend's "7" or "99" is not one of yours)
	for _, uid in { "7", "99", "-1", "0", "garbage" } do
		eq(CvcRules.station(d, 1, uid), false, uid)
		eq(CvcRules.racer(d, uid), false, uid)
	end
	for _, uid in junk do
		if uid ~= "1" then -- ("1" is this player's own first car)
			eq(CvcRules.racer(d, uid), false)
		end
	end
	eq(fingerprint(d), before)
end)

test("one car is on one station at a time", function()
	local d = player()
	d.plotLevel = 2
	CvcRules.fitStations(d)
	local car = d.garage[1].uid
	eq(CvcRules.station(d, 1, car), true)
	eq(CvcRules.station(d, 2, car), true)
	local on = 0
	for _, st in d.stations do
		if st.uid == car then
			on += 1
		end
	end
	eq(on, 1)
end)

test("junk upgrades, levels and picks change nothing", function()
	for _, a in junk do
		local d = player()
		d.picked = false
		d.garage = {}
		d.racer = ""
		d.stations = {}
		CvcRules.setUp(d)
		d.coins = 5000
		local before = fingerprint(d)
		eq(CvcRules.pick(d, a), false, "pick junk")
		eq(fingerprint(d), before)
		d.picked = true
		d.garage = {}
		eq(CvcRules.upgrade(d, a), false, "upgrade junk")
		eq(d.coins, 5000)
	end
	-- a starter pick works once, and only for a starter
	local d = Profile.new()
	CvcRules.setUp(d)
	eq(CvcRules.pick(d, "gb_gold"), false, "a crate car as a starter")
	eq(CvcRules.pick(d, CarStats.STARTERS[1]), true)
	eq(CvcRules.pick(d, CarStats.STARTERS[2] or CarStats.STARTERS[1]), false, "second pick")
	eq(#d.garage, 1)
end)

test("upgrades and plot levels need the coins and stop at the top", function()
	local d = player()
	d.coins = 0
	eq(CvcRules.upgrade(d, 1), false)
	eq(CvcRules.levelUp(d), false)
	eq(d.coins, 0)
	-- exactly enough once: the second ask finds the coins gone
	local cost = Training.upgradeCost(1) :: number
	d.coins = cost
	eq(CvcRules.upgrade(d, 1), true)
	eq(d.coins, 0)
	eq(d.stations[1].level, 2)
	eq(CvcRules.upgrade(d, 1), false)
	eq(d.stations[1].level, 2)
	local plot = Training.plotCost(d.plotLevel) :: number
	d.coins = plot
	eq(CvcRules.levelUp(d), true)
	eq(d.coins, 0)
	eq(CvcRules.levelUp(d), false)
	-- rich: still never past the top
	d.coins = Profile.MAX_COINS
	for _ = 1, 100 do
		CvcRules.levelUp(d)
		CvcRules.upgrade(d, 1)
	end
	eq(d.plotLevel, Training.MAX_PLOT_LEVEL)
	eq(d.stations[1].level, Training.MAX_STATION_LEVEL)
	truthy(d.coins >= 0, "coins below zero")
end)

test("junk crate kinds buy nothing", function()
	for _, kind in junk do
		local d = player()
		local before = fingerprint(d)
		eq(CvcRules.buy(d, kind, rng(0.5)), nil, "buy junk")
		eq(fingerprint(d), before)
	end
	local d = player()
	eq(CvcRules.buy(d, "free", rng(0.5)), nil, "the free crate is not for sale")
	eq(d.coins, 5000)
end)

test("a crate can't be bought without the coins, or twice with them", function()
	for _, kind in Crates.SHOP do
		local price = Crates.price(kind) :: number
		local d = player()
		d.coins = price - 1
		eq(CvcRules.buy(d, kind, rng(0.5)), nil, kind)
		eq(d.coins, price - 1)
		d.coins = price
		local cars = #d.garage
		truthy(CvcRules.buy(d, kind, rng(0.5)) ~= nil, kind)
		eq(d.coins, 0)
		eq(#d.garage, cars + 1)
		eq(CvcRules.buy(d, kind, rng(0.5)), nil, "double spend")
		eq(d.coins, 0)
		eq(#d.garage, cars + 1)
	end
end)

test("a full garage keeps the coins: nothing is paid for a car with no room", function()
	local d = player()
	while #d.garage < Profile.MAX_GARAGE do
		Profile.addCar(d, d.garage[1].id)
	end
	d.coins = 5000
	d.crates = 1
	for _, kind in Crates.SHOP do
		eq(CvcRules.buy(d, kind, rng(0.5)), nil)
	end
	eq(CvcRules.open(d, rng(0.5)), nil)
	eq(d.coins, 5000)
	eq(d.crates, 1)
end)

test("a free crate opens once per crate you own", function()
	local d = player()
	d.crates = 1
	local cars = #d.garage
	truthy(CvcRules.open(d, rng(0.5)) ~= nil)
	eq(d.crates, 0)
	eq(#d.garage, cars + 1)
	for _ = 1, 5 do
		eq(CvcRules.open(d, rng(0.5)), nil)
	end
	eq(d.crates, 0)
	eq(#d.garage, cars + 1)
	-- a junk crate count never opens one
	for _, n in { -1, -1e308, 0 } do
		d.crates = n
		eq(CvcRules.open(d, rng(0.5)), nil)
	end
end)

test("COACH works once a minute, junk never resets it", function()
	local now = 1_000_000
	local at = CvcRules.coach(0, now)
	eq(at, now, "first tap")
	-- spam inside the minute: nothing
	for s = 0, Training.COACH_EVERY - 1 do
		eq(CvcRules.coach(now, now + s), nil, `tap {s} s later`)
	end
	eq(CvcRules.coach(now, now + Training.COACH_EVERY), now + Training.COACH_EVERY)
	-- a wrong CoachAt (never set by a phone, but the rule must not give coach for it)
	for _, bad in { NAN, "0", {}, true } do
		eq(CvcRules.coach(bad, now), nil)
	end
end)

test("the coach double lasts 10 s, so spamming can't keep it on", function()
	local now = 1_000_000
	local at = now
	local on = 0
	for s = 0, 599 do
		local t = now + s
		local tapped = CvcRules.coach(at, t)
		if tapped then
			at = tapped
		end
		if Training.coaching(at, t) then
			on += 1
		end
	end
	-- 10 s of every 60 s
	eq(on, Training.COACH_SECS * 10)
end)
