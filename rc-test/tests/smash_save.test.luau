--!strict
-- Car VS Car SMASH saves (FINISH-JOBS SAVES row): an old save from the racing and training game
-- loads with every car and every coin once training is gone, leagues come from smashes and
-- place, and the daily jobs are smash, play and crates.
local H = require("./harness")
local serde = require("@lune/serde")
local DailyJobs = require("../src/shared/DailyJobs")
local League = require("../src/shared/League")
local Profile = require("../src/shared/Profile")

local test, eq, truthy = H.test, H.eq, H.truthy

print("Car VS Car SMASH: save move, leagues by smashes, daily jobs")

local function stored(record: any): any
	return serde.decode("json", serde.encode("json", record))
end

-- A v16 save as the racing game wrote it: 10 trained cars (one a duplicate id), coins, coins
-- still in the pile, a full plot of stations with cars on them, a built track, a league.
local IDS = {
	"zoomer",
	"mudbug",
	"slide_kid",
	"rocket",
	"tank",
	"zoomer",
	"bolt",
	"comet",
	"banana",
	"ghost",
}
local function oldSave(): any
	local garage = {}
	for i, id in IDS do
		table.insert(
			garage,
			{ uid = tostring(i), id = id, speed = i * 7.5, turn = 20, boost = 33.3 }
		)
	end
	local cars = {}
	for _, id in IDS do
		cars[id] = true
	end
	return stored({
		version = 16,
		coins = 12345,
		pile = 40.7,
		cars = cars,
		garage = garage,
		racer = "3",
		nextUid = 11,
		stations = {
			{ kind = "speed", level = 4, uid = "1" },
			{ kind = "boost", level = 3, uid = "2" },
			{ kind = "turn", level = 2, uid = "" },
		},
		plotLevel = 6,
		parked = { "zoomer", "mudbug", "rocket", "tank", "bolt", "comet" },
		plotRecords = { drift = { value = 900, name = "Mia", userId = 7 } },
		track = { tiles = { { c = 1, r = 1, piece = "straight", rot = 0 } } },
		trackKind = "drift",
		league = 2,
		trophies = 30,
		raceWins = 9,
		crates = 2,
		picked = true,
		dailyDay = 20000,
		dayStreak = 4,
		stage = 3,
	})
end

local function withoutTraining<T>(f: () -> T): T
	Profile.KEEP_TRAINING = false
	local ok, out = pcall(f)
	Profile.KEEP_TRAINING = true
	if not ok then
		error(out, 0)
	end
	return out
end

test(
	"smash save: an old save with 10 cars + coins loads with all 10 cars and every coin",
	function()
		local d = withoutTraining(function()
			return Profile.migrate(oldSave())
		end)
		eq(d.version, Profile.VERSION)
		eq(#d.garage, 10)
		for i, id in IDS do
			eq(d.garage[i].uid, tostring(i))
			eq(d.garage[i].id, id)
		end
		eq(d.coins, 12345 + 41) -- the pile moves in, rounded up
		eq(d.pile, 0)
		eq(d.racer, "3") -- the car you drive stays picked
		for _, id in IDS do
			truthy(d.cars[id], id)
		end
		-- training is gone
		eq(#d.stations, 0)
		eq(d.plotLevel, 0)
		eq(d.track, nil)
		eq(d.trackKind, "race")
		eq(#d.parked, 0)
		eq(next(d.plotRecords), nil)
		for _, c in d.garage do
			eq(c.speed + c.turn + c.boost, 0)
		end
		-- the rest stays
		eq(d.league, 2)
		eq(d.trophies, 30)
		eq(d.crates, 2)
		eq(d.dayStreak, 4)
		truthy(d.picked)
		eq(d.nextUid, 11) -- a new car never gets an old car's uid
		local car = Profile.addCar(d, "zoomer")
		truthy(car ~= nil)
		eq((car :: Profile.GarageCar).uid, "11")
	end
)

test("smash save: loading it again (and again) changes nothing", function()
	withoutTraining(function()
		local once = Profile.migrate(oldSave())
		local twice = Profile.migrate(stored(once))
		eq(serde.encode("json", twice), serde.encode("json", once))
		Profile.dropTraining(twice)
		eq(serde.encode("json", twice), serde.encode("json", once))
		return true
	end)
end)

test("smash save: a save from before the garage (cars only) gets a car for each one", function()
	local d = withoutTraining(function()
		return Profile.migrate(stored({
			version = 15,
			coins = 777,
			cars = { zoomer = true, mudbug = true, rocket = true },
			plotLevel = 4,
			parked = { "zoomer" },
		}))
	end)
	eq(d.coins, 777)
	eq(#d.garage, 3)
	eq(d.plotLevel, 0)
end)

test("smash save: while training is still in the game, nothing is dropped", function()
	eq(Profile.KEEP_TRAINING, true)
	local d = Profile.migrate(oldSave())
	eq(#d.stations, 3)
	eq(d.plotLevel, 6)
	eq(d.garage[2].speed, 15)
	eq(d.coins, 12345)
end)

test("smash save: smashes, matches and wins save, rejoin and merge", function()
	local d = Profile.new()
	eq(d.smashes, 0)
	d.smashes, d.matches, d.matchWins = 41, 12, 3
	local back = Profile.migrate(stored(d))
	eq(back.smashes, 41)
	eq(back.matches, 12)
	eq(back.matchWins, 3)
	-- junk can't break it
	local junk = Profile.migrate(stored({ smashes = -5, matches = "x", matchWins = 1e30 }))
	eq(junk.smashes, 0)
	eq(junk.matches, 0)
	eq(junk.matchWins, Profile.MAX_COINS)
	-- a visit played while the DataStore was down adds what it earned
	local base = Profile.new()
	local visit = Profile.new()
	visit.smashes, visit.matches = 7, 2
	local merged = Profile.mergeVisit(Profile.migrate(stored(d)), visit, base)
	eq(merged.smashes, 48)
	eq(merged.matches, 14)
	eq(merged.matchWins, 3)
end)

local function kid(): League.MatchSave
	return { coins = 0, trophies = 0, league = 1, smashes = 0, matches = 0, matchWins = 0 }
end

test("smash league: trophies from place and smashes, capped per match", function()
	eq(League.matchTrophies(1, 0), 3)
	eq(League.matchTrophies(2, 2), 4)
	eq(League.matchTrophies(3, 1), 2)
	eq(League.matchTrophies(6, 2), 2)
	eq(League.matchTrophies(8, 40), League.SMASH_TROPHY_CAP)
	eq(League.matchTrophies(0, 4), 0) -- left before the end
	eq(League.matchTrophies(-1, 4), 0)
	eq(League.matchTrophies(0 / 0, 0 / 0), 0)
end)

test("smash league: match coins by place and smash, bigger in higher leagues", function()
	eq(League.matchPay(1, 1, 0), 100)
	eq(League.matchPay(1, 5, 2), 25 + 10)
	eq(League.matchPay(3, 1, 4), math.floor((100 + 20) * 2.2))
	eq(League.matchPay(1, 0, 5), 0)
	eq(League.matchPay(1, 4, 1e9), 25 + 5 * League.MAX_SMASHES)
	truthy(League.matchPay(1, 1, 0) > League.matchPay(1, 2, 0))
	truthy(League.matchPay(1, 3, 0) > League.matchPay(1, 4, 0))
end)

test("smash league: matchDone pays, counts and moves the league up, never down", function()
	local d = kid()
	local r = League.matchDone(d, 1, 3)
	eq(r.coins, 115)
	eq(r.trophies, 6)
	eq(d.coins, 115)
	eq(d.smashes, 3)
	eq(d.matches, 1)
	eq(d.matchWins, 1)
	eq(r.from, 1)
	eq(r.to, 1)
	d.trophies = League.SMASH_NEED[2] - 1
	r = League.matchDone(d, 6, 1)
	eq(r.to, 2) -- the league-up moment
	eq(d.league, 2)
	-- the pay was still Bronze's (the match was played there)
	eq(r.coins, League.MATCH_PAY + League.SMASH_PAY)
	-- leaving early: no pay, no trophy, no match, but the smashes count
	r = League.matchDone(d, 0, 2)
	eq(r.coins, 0)
	eq(d.matches, 2)
	eq(d.smashes, 6)
	-- never down
	d.trophies = 0
	League.matchDone(d, 8, 0)
	eq(d.league, 2)
	eq(League.byTrophies(1e9, 1), #League.NAMES)
	eq(League.byTrophies(0 / 0, 3), 3)
end)

-- A normal kid (sim, 20 min a day, ~6 matches): places spread over 1..8, 0-6 smashes.
test(
	"smash league: a normal kid reaches Silver ~35 min, Gold ~1.5 h, Diamond in 10-18 days",
	function()
		local seedState = 12345
		local function rand(n: number): number
			seedState = (seedState * 1103515245 + 12345) % 2147483648
			return seedState % n + 1
		end
		local function minutesTo(league: number): number
			local d = kid()
			local m = 0
			while d.league < league do
				m += 3.5 -- 3:00 match + results and the next start
				League.matchDone(d, rand(8), rand(7) - 1)
			end
			return m
		end
		local silver, gold, diamond = 0, 0, 0
		local runs = 20
		for _ = 1, runs do
			silver += minutesTo(2) / runs
			gold += minutesTo(3) / runs
			diamond += minutesTo(4) / runs
		end
		print(
			`  Silver {math.floor(silver)} min, Gold {math.floor(gold)} min, Diamond day {string.format(
				"%.1f",
				diamond / 20
			)}`
		)
		truthy(silver >= 25 and silver <= 45, `Silver {silver} min`)
		truthy(gold >= 60 and gold <= 120, `Gold {gold} min`)
		truthy(diamond / 20 >= 10 and diamond / 20 <= 18, `Diamond day {diamond / 20}`)
	end
)

test("smash jobs: smash 10 karts, play 3 matches, open a crate (and back)", function()
	DailyJobs.useCvc(true)
	DailyJobs.useSmash()
	local ids = {}
	for _, pool in DailyJobs.POOLS do
		for _, j in pool do
			ids[j.id] = true
			truthy(DailyJobs.EVENTS[j.event] ~= nil, `{j.id}: event {j.event} is not sent`)
			truthy(j.goal >= 1 and j.goal <= 10, `{j.id}: goal {j.goal}`)
			truthy(
				j.event ~= "train" and j.event ~= "coach" and string.sub(j.event, 1, 4) ~= "race",
				j.id
			)
		end
	end
	truthy(ids.smash10 and ids.match3 and ids.crate, "the three jobs are there")
	-- find a kid who gets smash 10 today, and do it
	local uid: number? = nil
	for u = 1, 60 do
		if DailyJobs.list(10, u)[1].id == "smash10" then
			uid = u
			break
		end
	end
	truthy(uid ~= nil)
	local d = { jobs = DailyJobs.new(10), coins = 0 }
	for _ = 1, 9 do
		DailyJobs.add(d, uid :: number, 10, "smash")
	end
	eq(d.coins, 0)
	local done = DailyJobs.add(d, uid :: number, 10, "smash")
	eq(#done, 1)
	eq(d.coins, 50)
	DailyJobs.useCvc(true)
	eq(DailyJobs.POOLS, DailyJobs.CVC_POOLS)
	DailyJobs.useCvc(false)
end)
