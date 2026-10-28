--!strict
-- Car VS Car economy sim (audit C3, MASTER-PROMPT §9 NOW #2 / §10 "Economy sim"): a normal kid
-- played through the real rules, second by second, for days of play. Not a test on its own
-- (tests/cvc_economy.test.luau asserts the bars); tests/cvc_pacing.test.luau is the other kid,
-- the one who loses every race and only trains.
--
-- The normal kid:
--   * picks the quick starter, taps RACE at 0:30 and wins the easy first race (1 lap, §4)
--   * then joins every big race (ServerRace.nextFor: quicker for the first few, then one each
--     CVC_EVERY), about RACE_SECS each
--   * places from the real bot pace: 7 bots with skills from RaceBots.skillRange(league), the
--     kid's pace KID_SKILL (a normal kid's driving next to a skill-1 bot) times what the car's
--     bars give (RaceStats.drive: top speed and turning), with a little luck each race
--   * taps COACH a few seconds after it's ready, except while racing
--   * opens every crate at once (the first one, the daily one), fills the stations (cars that can
--     still train first, rarest first: a full car on a station still earns its coins) and races
--     the strongest
--   * spends on the cheapest thing it can: a station for a car that has none, a station level
--     for a car that can still train, or a CRATE (the cheapest in the shop)
--   * plays SESSION_MIN a day; the daily gift and the 3 daily jobs (DailyJobs, Car VS Car lists)
--     pay as they do in the game. No weekend 2x, no friend coins (they only make it faster).
-- Everything is deterministic for a seed.

local CarCatalog = require("../src/shared/CarCatalog")
local CvcRules = require("../src/shared/CvcRules")
local Crates = require("../src/shared/Crates")
local DailyJobs = require("../src/shared/DailyJobs")
local League = require("../src/shared/League")
local Profile = require("../src/shared/Profile")
local RaceBots = require("../src/shared/RaceBots")
local RaceStats = require("../src/shared/RaceStats")
local ServerRace = require("../src/shared/ServerRace")
local Training = require("../src/shared/Training")

local Sim = {}

Sim.KID_SKILL = 0.72 -- the player's car tops ~95 next to a skill-1 bot's 120 (0.79); a kid drives ~90% of that
Sim.KID_LUCK = 0.06 -- each race the kid's pace is this much better or worse, at random
Sim.BOTS = 7 -- the grid is 8: one kid and 7 bots
Sim.FIRST_JOIN = 30 -- the kid taps RACE (§4: 0:30)
Sim.FIRST_RACE_SECS = 45 -- 1 lap with the easy bots
Sim.RACE_SECS = 75 -- 2 laps and the podium
Sim.NEXT_RACE = 60 -- a later day: the next race starts about this far into the visit
Sim.COACH_LATE = 5 -- seconds after COACH is ready that the kid taps it
Sim.SESSION_MIN = 20 -- minutes a day (§3: a session is 15-25 min)
Sim.USER_ID = 1234 -- whose daily jobs
-- optional: told every event as it happens (seconds played, words), for the first-10 timeline
Sim.log = nil :: ((at: number, what: string) -> ())?

export type Result = {
	crates: { number }, -- minutes played when each crate was opened (shop crates too)
	things: { number }, -- minutes played at each new thing: a crate, a station, a level, a league
	leagues: { number }, -- leagues[n] = minutes played when the kid reached league n (1 = 0)
	coins: number,
	races: number,
	raceAt: { { number } }, -- each big race: { seconds played at its start, at its end }
	top3: number,
	wins: number,
	data: Profile.Data,
}

-- a seeded stand-in for Random (Lune has none): NextNumber in [0, 1)
local function rng(seed: number)
	local s = seed % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	return {
		NextNumber = function(_self: any): number
			s = (s * 48271) % 2147483647
			return (s - 1) / 2147483646
		end,
	}
end
Sim.rng = rng

local function strongest(data: Profile.Data): Profile.GarageCar?
	local best, top = nil, -1
	for _, c in data.garage do
		local n = Training.strength(c, CvcRules.stats(c.id))
		if n > top then
			best, top = c, n
		end
	end
	return best
end

-- The kid's place in a race of its league (1..8).
function Sim.place(data: Profile.Data, r: any): number
	local car = strongest(data)
	local drive = RaceStats.drive(car, car and CvcRules.stats(car.id))
	local luck = 1 + Sim.KID_LUCK * (2 * r:NextNumber() - 1)
	local pace = Sim.KID_SKILL * (drive.top + drive.turn - 1) * luck
	local lo, hi = RaceBots.skillRange(data.league)
	local place = 1
	for _ = 1, Sim.BOTS do
		if lo + (hi - lo) * r:NextNumber() > pace then
			place += 1
		end
	end
	return place
end

-- Cars that can still train go on the stations (rarest, then strongest room first); the
-- strongest car races.
local function arrange(data: Profile.Data)
	local list = {}
	for _, c in data.garage do
		local stats = CvcRules.stats(c.id)
		table.insert(list, { car = c, rate = stats.rate, full = Training.full(c, stats) })
	end
	table.sort(list, function(a, b)
		if a.full ~= b.full then
			return b.full
		end
		if a.rate ~= b.rate then
			return a.rate > b.rate
		end
		return a.car.uid < b.car.uid
	end)
	for i, st in data.stations do
		local want = if list[i] then list[i].car.uid else ""
		if st.uid ~= want then
			CvcRules.station(data, i, want)
		end
	end
	local best = strongest(data)
	if best then
		data.racer = best.uid
	end
end

-- The cheapest crate in the shop.
local function cheapestCrate(): (string, number)
	local kind, cost = "", math.huge
	for _, id in Crates.SHOP do
		local p = Crates.price(id)
		if p and p < cost then
			kind, cost = id, p
		end
	end
	return kind, cost
end

function Sim.run(days: number, seed: number?, session: number?): Result
	local r = rng(seed or 1)
	local data = Profile.new()
	DailyJobs.useCvc(true)
	CvcRules.setUp(data)
	CvcRules.pick(data, "race_bolt")
	local res: Result = {
		crates = {},
		things = {},
		leagues = { 0 },
		coins = 0,
		races = 0,
		raceAt = {},
		top3 = 0,
		wins = 0,
		data = data,
	}
	local played = 0 -- seconds
	local bits = 0
	local coachAt = 0
	local trainSecs = 0
	local raced = false
	local function mark(list: { number })
		table.insert(list, played / 60)
	end
	local function say(what: string)
		local log = Sim.log
		if log then
			log(played, what)
		end
	end
	local function job(day: number, event: string)
		if data.stage >= Profile.STAGE.SHOPPED then
			for _, j in DailyJobs.add(data :: any, Sim.USER_ID, day, event) do
				say(`job done: {j.text} +{j.coins} coins`)
			end
		end
	end
	local function gift(day: number)
		if data.stage >= Profile.STAGE.SHOPPED then
			CvcRules.daily(data, day, 1)
		end
	end
	local function spend(day: number, now: number)
		local opened = false
		while data.crates > 0 do
			local id = CvcRules.open(data, r)
			if not id then
				break
			end
			say(
				`opened a crate: {id} ({CarCatalog.rarity(id).label}), {#data.garage} cars, {#data.stations} stations`
			)
			opened = true
			mark(res.crates)
			mark(res.things)
			job(day, "crate")
			if data.stage < Profile.STAGE.SHOPPED then
				data.stage = Profile.STAGE.SHOPPED -- the first crate (TrainingServer), then the gift
				local c0 = data.coins
				gift(day)
				say(`daily gift +{data.coins - c0} coins and a crate`)
			end
		end
		if opened or now % 60 == 0 then
			arrange(data) -- (a car that got full moves over within a minute)
		end
		while true do
			local cost, what, which = math.huge, "", 0
			local plot = Training.plotCost(data.plotLevel)
			if plot and #data.garage > #data.stations then
				cost, what = plot, "station"
			end
			for i, st in data.stations do
				local up = Training.upgradeCost(st.level)
				local car = st.uid ~= "" and Profile.findCar(data, st.uid)
				local growing = car and not Training.full(car, CvcRules.stats(car.id))
				if growing and up and up < cost then
					cost, what, which = up, "upgrade", i
				end
			end
			local kind, price = cheapestCrate()
			if price < cost then
				cost, what = price, "crate"
			end
			if data.coins < cost then
				break
			end
			local ok = if what == "station"
				then CvcRules.levelUp(data)
				elseif what == "upgrade" then CvcRules.upgrade(data, which)
				else CvcRules.buy(data, kind, r) ~= nil
			if not ok then
				break
			end
			say(`bought {what} for {cost} ({data.coins} left)`)
			mark(res.things)
			if what == "crate" then
				mark(res.crates)
				job(day, "crate")
			else
				job(day, "upgrade")
			end
			arrange(data)
		end
	end
	local secs = math.floor((session or Sim.SESSION_MIN) * 60)
	for d = 1, days do
		local day = 20000 + d
		DailyJobs.today(data :: any, day)
		gift(day)
		-- day 1: the first race on the kid's tap; after that the next big race, then every
		-- CVC_EVERY
		local start = if raced then Sim.NEXT_RACE else Sim.FIRST_JOIN
		local finish = start + (if raced then Sim.RACE_SECS else Sim.FIRST_RACE_SECS)
		for t = 0, secs - 1 do
			local now = d * 86400 + t
			local racing = t >= start and t < finish
			if t == start then
				table.insert(res.raceAt, { played, played + (finish - start) })
			end
			if t == finish then
				local place = if raced then Sim.place(data, r) else 1
				local was = data.league
				local got = CvcRules.raceDone(data, place, now)
				say(`race {res.races + 1} done: place {place}, +{got.coins} coins ({data.coins})`)
				raced = true
				if data.stage < Profile.STAGE.RACED then
					data.stage = Profile.STAGE.RACED
				end
				res.races += 1
				job(day, "raceDone")
				if place <= 3 then
					res.top3 += 1
					job(day, "raceTop3")
				end
				if place == 1 then
					res.wins += 1
					job(day, "raceWin")
				end
				for n = was + 1, data.league do
					res.leagues[n] = played / 60
					mark(res.things)
				end
				-- (the server's rule: a new kid's first few races come quicker, ServerRace.nextFor)
				start = ServerRace.nextFor(start, t, res.races <= ServerRace.EARLY_RACES)
				finish = start + Sim.RACE_SECS
			end
			if not racing and data.picked then
				if coachAt == 0 or now - coachAt >= Training.COACH_EVERY + Sim.COACH_LATE then
					coachAt = now
					job(day, "coach")
				end
			end
			local was = data.league
			local cars
			bits, cars = CvcRules.tick(data, 1, Training.coaching(coachAt, now), now, bits)
			for n = was + 1, data.league do
				res.leagues[n] = played / 60
				mark(res.things)
			end
			local busy = false
			for _, st in data.stations do
				busy = busy or st.uid ~= ""
			end
			if busy then
				trainSecs += 1
				if trainSecs >= 60 then
					trainSecs -= 60
					job(day, "train")
				end
			end
			local _ = cars
			if not racing then
				spend(day, now)
			end
			played += 1
		end
	end
	res.coins = data.coins
	return res
end

-- The longest stretch (minutes) with nothing new, from `from` to `to` minutes played.
function Sim.longestWait(res: Result, from: number, to: number): number
	local last, worst = from, 0
	for _, at in res.things do
		if at > from and at <= to then
			worst = math.max(worst, at - last)
			last = at
		end
	end
	return math.max(worst, to - last)
end

-- The middle of `runs` seeds for a number each run gives (nil counts as never).
function Sim.median(runs: number, days: number, pick: (Result) -> number?): number
	local list = {}
	for seed = 1, runs do
		table.insert(list, pick(Sim.run(days, seed * 7919)) or math.huge)
	end
	table.sort(list)
	return list[math.floor((#list + 1) / 2)]
end

local _ = League
return Sim
