--!strict
-- Economy check (Car VS Car, carter 10-26): his biggest worry is "too slow to earn". This plays a
-- new kid second by second through the real rules (CvcRules, Training, League, Crates and
-- Economy's numbers), the way cvc_flow does: pick a starter, train with COACH tapped every
-- minute, race (the first on a tap after a minute, then every 3 min) and spend coins on the
-- cheapest useful thing: a station upgrade, a plot level when a car waits for a station, or a
-- basic crate. Daily gift, jobs and bring-a-friend coins are left out (they only help).
local H = require("./harness")
local CarStats = require("../src/shared/CarStats")
local CvcRules = require("../src/shared/CvcRules")
local Crates = require("../src/shared/Crates")
local Economy = require("../src/shared/Economy")
local League = require("../src/shared/League")
local Profile = require("../src/shared/Profile")
local Training = require("../src/shared/Training")

local test, truthy = H.test, H.truthy

print("Economy")

type Player = { name: string, places: { number } }
type Thing = { t: number, what: string }
type Result = {
	things: { Thing },
	firstPaid: number?,
	league: { number }, -- league at 10, 30 and 60 min
	strength: number,
	stations: number,
	cars: number,
}

local function minutes(t: number): string
	return string.format("%4.1f", t / 60)
end

-- a repeatable roll (the crate picks its car from this)
local function seeded(seed: number): Crates.Rng
	local s = seed
	return {
		NextNumber = function(_: any): number
			s = (s * 1103515245 + 12345) % 2147483648
			return s / 2147483648
		end,
	} :: any
end

local function run(p: Player, mins: number): Result
	local rng = seeded(7)
	local data = Profile.new()
	CvcRules.setUp(data)
	assert(CvcRules.pick(data, CarStats.STARTERS[1]), "pick")
	local things: { Thing } = {}
	local firstPaid: number? = nil
	local snap: { number } = {}
	local now = 1_000_000
	local coachAt = 0
	local bits = 0
	local races = 0

	local function note(sec: number, what: string, paid: boolean)
		table.insert(things, { t = sec, what = what })
		if paid and firstPaid == nil then
			firstPaid = sec
		end
	end
	-- a new car goes on a station that has none
	local function seat()
		for _, c in data.garage do
			local seated = false
			for _, st in data.stations do
				seated = seated or st.uid == c.uid
			end
			if not seated then
				for i, st in data.stations do
					if st.uid == "" then
						CvcRules.station(data, i, c.uid)
						break
					end
				end
			end
		end
	end
	local function tryBuy(sec: number)
		local waiting = #data.garage > #data.stations
		local lowest = 0
		for i, st in data.stations do
			if st.uid ~= "" and st.level < Training.MAX_STATION_LEVEL then
				if lowest == 0 or st.level < data.stations[lowest].level then
					lowest = i
				end
			end
		end
		local options: { { cost: number, buy: () -> string? } } = {}
		if lowest > 0 then
			table.insert(options, {
				cost = Training.upgradeCost(data.stations[lowest].level) or math.huge,
				buy = function(): string?
					return if CvcRules.upgrade(data, lowest)
						then `station upgrade to {data.stations[lowest].level}`
						else nil
				end,
			})
		end
		if waiting then
			table.insert(options, {
				cost = Training.plotCost(data.plotLevel) or math.huge,
				buy = function(): string?
					return if CvcRules.levelUp(data) then `plot level {data.plotLevel}` else nil
				end,
			})
		else
			table.insert(options, {
				cost = Crates.price("basic") or math.huge,
				buy = function(): string?
					local id = CvcRules.buy(data, "basic", rng)
					return if id then `crate: {id}` else nil
				end,
			})
		end
		table.sort(options, function(a, b)
			return a.cost < b.cost
		end)
		for _, o in options do
			if data.coins >= o.cost then
				local what = o.buy()
				if what then
					note(sec, `{what} ({o.cost})`, true)
					seat()
				end
				return
			end
		end
	end

	for sec = 1, mins * 60 do
		now += 1
		if Training.coachReady(coachAt, now) then
			coachAt = now
		end
		bits = CvcRules.tick(data, 1, Training.coaching(coachAt, now), now, bits)
		if sec == 60 or (sec > 60 and (sec - 60) % Economy.RACE_EVERY == 0) then
			races += 1
			local got = CvcRules.raceDone(data, p.places[(races - 1) % #p.places + 1], now)
			if got.firstCrate then
				Profile.raiseStage(data, Profile.STAGE.RACED)
				local id = CvcRules.open(data, rng)
				note(sec, `FREE crate: {id}`, false)
				seat()
			end
		end
		tryBuy(sec)
		if sec == 10 * 60 or sec == 30 * 60 or sec == 60 * 60 then
			table.insert(snap, data.league)
		end
	end
	return {
		things = things,
		firstPaid = firstPaid,
		league = snap,
		strength = CvcRules.best(data),
		stations = #data.stations,
		cars = #data.garage,
	}
end

local TOP: Player = { name = "wins every race", places = { 1 } }
local MID: Player = { name = "mid (2nd, 1st, 3rd)", places = { 2, 1, 3 } }
local NEW: Player = { name = "new kid (2nd, 3rd, 2nd, 4th)", places = { 2, 3, 2, 4 } }
local LAST: Player = { name = "always last (8th)", places = { 8 } }

local function show(p: Player, r: Result, listing: boolean)
	print(
		`  {p.name}: {#r.things} things, {r.cars} cars, {r.stations} stations,`
			.. ` strength {math.floor(r.strength)}, league {table.concat(r.league, "/")} at 10/30/60 min`
	)
	if listing then
		for _, th in r.things do
			print(`    {minutes(th.t)} min  {th.what}`)
		end
	end
end

local function things(r: Result, within: number): number
	local n = 0
	for _, th in r.things do
		if th.t <= within * 60 then
			n += 1
		end
	end
	return n
end

local function longestGap(r: Result, to: number): number
	local last, gap = 0, 0
	for _, th in r.things do
		if th.t <= to * 60 then
			gap = math.max(gap, th.t - last)
			last = th.t
		end
	end
	return math.max(gap, to * 60 - last)
end

test("economy: the first 10 min, a paid thing inside 5 min even when always last", function()
	for _, p in { TOP, MID, NEW, LAST } do
		local r = run(p, 60)
		show(p, r, p == NEW)
		truthy((r.firstPaid or math.huge) <= 5 * 60, `{p.name}: first paid thing at {r.firstPaid}`)
		truthy(things(r, 10) >= 3, `{p.name}: only {things(r, 10)} things in 10 min`)
	end
end)

test("economy: the first hour never goes quiet for long and reaches Silver and Gold", function()
	for _, case in { { TOP, 9 }, { MID, 9 }, { NEW, 12 }, { LAST, 14 } } do
		local p, gap = case[1] :: Player, case[2] :: number
		local r = run(p, 60)
		truthy(
			longestGap(r, 60) <= gap * 60,
			`{p.name}: {minutes(longestGap(r, 60))} min with nothing new`
		)
	end
	truthy(run(MID, 60).league[2] >= 2, "a mid kid reaches Silver inside 30 min")
	truthy(run(TOP, 60).league[3] >= 3, "a kid who wins everything reaches Gold inside an hour")
end)

test("economy: Diamond stays a long goal (not in the first hour)", function()
	truthy(run(TOP, 60).league[3] <= 3, "Diamond inside an hour is too fast")
end)

test(
	"economy: a higher league pays more and not finishing still pays a little, but less than finishing",
	function()
		for lgi = 1, 3 do
			truthy(League.prize(lgi + 1, 1) > League.prize(lgi, 1), "the next league pays more")
		end
		truthy(
			League.prize(1, 0) > 0 and League.prize(1, 0) < League.prize(1, 8),
			"a try pays less"
		)
		truthy(League.prize(1, 8) >= Economy.FINISH_PAY, "finishing last still pays")
	end
)
