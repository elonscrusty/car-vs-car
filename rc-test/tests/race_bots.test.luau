--!strict
local H = require("./harness")
local RaceBots = require("../src/shared/RaceBots")
local RaceMaps = require("../src/shared/RaceMaps")
local ServerRace = require("../src/shared/ServerRace")

local test, eq, truthy = H.test, H.eq, H.truthy

local DT = 1 / 30

-- a map's route and a bot of that skill on grid spot `k`
local function setup(
	m: any,
	skill: number,
	k: number,
	lane: number?
): (RaceBots.Route, RaceBots.Bot)
	local t = m.track()
	local route = RaceBots.route(m.loop(), m.lineSample(), t.gates)
	local row = (k - 1) // 2
	local side = if k % 2 == 1 then -1 else 1
	local bot = RaceBots.new(
		route,
		"b",
		skill,
		lane or 0,
		side * ServerRace.GRID_SIDE,
		0,
		0.2,
		ServerRace.BACK + row * ServerRace.GRID_ROW,
		{ 255, 255, 255 }
	)
	return route, bot
end

-- run a bot for `secs` after GO (no players to chase); returns the time it finished or nil
local function drive(
	route: RaceBots.Route,
	bot: RaceBots.Bot,
	secs: number,
	check: ((RaceBots.Pose) -> ())?
)
	local since = -3
	while since < secs do
		RaceBots.step(route, bot, DT, since, 0)
		since += DT
		if check then
			check(RaceBots.pose(route, bot))
		end
	end
	return bot.time
end

-- distance from a point to the closed centre line
local function offRoad(m: any, x: number, z: number): number
	local loop = m.loop()
	local best = math.huge
	for i, p in loop do
		local q = loop[i % #loop + 1]
		local ex, ez = q.x - p.x, q.z - p.z
		local len2 = ex * ex + ez * ez
		local u = if len2 > 0 then math.clamp(((x - p.x) * ex + (z - p.z) * ez) / len2, 0, 1) else 0
		best = math.min(best, math.sqrt((x - p.x - ex * u) ^ 2 + (z - p.z - ez * u) ^ 2))
	end
	return best
end

test("a race fills up to 4 cars with bots, none when nobody is there", function()
	eq(RaceBots.count(0, 8), 0)
	eq(RaceBots.count(1, 8), 3)
	eq(RaceBots.count(3, 8), 1)
	eq(RaceBots.count(4, 8), 0)
	eq(RaceBots.count(8, 8), 0)
	eq(RaceBots.count(1, 2), 1) -- never past the grid
end)

test("bots finish all the laps on every map, inside the map's time limit", function()
	for _, m in RaceMaps.list() do
		for _, skill in { RaceBots.SKILL_MIN, RaceBots.SKILL_MAX } do
			local route, bot = setup(m, skill, 2)
			local took = drive(route, bot, ServerRace.MAP_TIME_LIMIT + 60, nil)
			truthy(took ~= nil, `{m.id} skill {skill} never finished`)
			truthy(
				(took :: number) < ServerRace.MAP_TIME_LIMIT,
				`{m.id} skill {skill}: {took} s is too slow`
			)
			truthy(
				(took :: number) > ServerRace.LAPS * 15,
				`{m.id} skill {skill}: {took} s is too fast`
			)
		end
	end
end)

test("a better bot is quicker, and every lap counts", function()
	for _, m in RaceMaps.list() do
		local r1, slow = setup(m, 0.7, 1)
		local r2, fast = setup(m, 0.9, 1)
		local a = drive(r1, slow, 400, nil) :: number
		local b = drive(r2, fast, 400, nil) :: number
		truthy(b < a, `{m.id}: fast {b} should beat slow {a}`)
		eq(RaceBots.laps(r1, slow), ServerRace.LAPS)
	end
end)

test("bots stay on the road all the way round (lane and sway included)", function()
	for _, m in RaceMaps.list() do
		local worst = 0
		for k = 1, 3 do
			local route, bot = setup(m, 0.9, k, RaceBots.laneFor(k))
			drive(route, bot, 140, function(p: RaceBots.Pose)
				worst = math.max(worst, offRoad(m, p.x, p.z))
			end)
		end
		truthy(worst <= (m.ROAD or 30) / 2 - 3, `{m.id}: a bot was {worst} off the centre line`)
	end
end)

test("bots start on the grid spots the players' grid uses", function()
	for _, m in RaceMaps.list() do
		local t = m.track()
		for k = 1, 4 do
			local route, bot = setup(m, 0.8, k)
			local want = ServerRace.gridOn(m, k, t.spawn.y)
			local p = RaceBots.pose(route, bot)
			truthy(math.abs(p.x - want.x) < 2.5 and math.abs(p.z - want.z) < 2.5, `{m.id} spot {k}`)
		end
	end
end)

test("bots slow for the bends and speed up on the straights", function()
	local m = RaceMaps.list()[1]
	local route, bot = setup(m, 0.9, 1)
	local lo, hi = math.huge, 0
	local since = -3
	while since < 80 do
		RaceBots.step(route, bot, DT, since, 0)
		since += DT
		if since > 10 then
			lo, hi = math.min(lo, bot.speed), math.max(hi, bot.speed)
		end
	end
	truthy(hi > lo + 15, `speed barely changes: {lo}..{hi}`)
	truthy(hi <= RaceBots.TOP * 0.9 + 0.01, "never over its own top speed")
end)

test("bots wait for GO and for their reaction time", function()
	local m = RaceMaps.list()[1]
	local route, bot = setup(m, 0.9, 1)
	for _ = 1, 100 do
		RaceBots.step(route, bot, DT, -1, 0)
	end
	eq(bot.speed, 0)
	eq(bot.dist < 0, true)
	RaceBots.step(route, bot, DT, 0.05, 0) -- GO, but not yet reacted (delay 0.2)
	eq(bot.speed, 0)
	RaceBots.step(route, bot, DT, 0.3, 0)
	truthy(bot.speed > 0)
end)

test(
	"catch-up: a bot far ahead of the players eases off, far behind speeds up, within the limit",
	function()
		local m = RaceMaps.list()[1]
		local function run(catchUp: number): number
			local route, bot = setup(m, 0.8, 1)
			drive(route, bot, 30, nil)
			local d0 = bot.dist
			local since = 30
			for _ = 1, 90 do
				RaceBots.step(route, bot, DT, since, catchUp)
				since += DT
			end
			return bot.dist - d0
		end
		local plain, ahead, behind = run(0), run(1), run(-1)
		truthy(ahead < plain and plain < behind, "ahead slows, behind speeds up")
		truthy(behind < plain * (1 + RaceBots.CATCH_UP * 2 + 0.05), "within the catch-up limit")
	end
)

test("live progress rises round the lap and ranks like a player's would", function()
	local m = RaceMaps.list()[1]
	local route, bot = setup(m, 0.9, 1)
	local last = RaceBots.progress(route, bot)
	local since = -3
	local steps = 0
	while since < 130 and bot.time == nil do
		RaceBots.step(route, bot, DT, since, 0)
		since += DT
		steps += 1
		if steps % 15 == 0 then
			local now = RaceBots.progress(route, bot)
			truthy(now >= last - 1e-6, `progress went back: {last} -> {now}`)
			last = now
		end
	end
	local gates = #route.gateAt
	truthy(last >= ServerRace.LAPS * (gates + 1) - 2, "all the laps is about LAPS * (gates + 1)")
	-- a bot on lap 2 is ahead of a player on lap 1 and behind one on lap 3
	truthy(ServerRace.progress(1, gates, gates, 0) < 2 * (gates + 1) + 1)
	truthy(ServerRace.progress(3, 1, gates, 5) > 3 * (gates + 1))
end)

test("the spread of skills: a quick one, a slow one, all inside the limits", function()
	local lo, hi = 1, 0
	for i = 1, 3 do
		local s = RaceBots.skillFor(i, 3, 0.5)
		truthy(s >= RaceBots.SKILL_MIN and s <= RaceBots.SKILL_MAX)
		lo, hi = math.min(lo, s), math.max(hi, s)
	end
	truthy(hi - lo > 0.1, "bots should differ")
	eq(#RaceBots.NAMES >= 7, true)
	eq(#RaceBots.COLORS >= 3, true)
end)

test("Car VS Car: bots fill the grid to 8, and the league sets how good they are", function()
	eq(RaceBots.count(1, 8, 8), 7)
	eq(RaceBots.count(5, 8, 8), 3)
	eq(RaceBots.count(8, 8, 8), 0)
	eq(RaceBots.count(0, 8, 8), 0)
	eq(RaceBots.count(1, 8), 3) -- the old fill is unchanged
	local lastLo, lastHi = 0, 0
	for league = 1, 4 do
		local lo, hi = RaceBots.skillRange(league, false)
		truthy(lo < hi, "a range")
		truthy(lo > lastLo and hi > lastHi, "each league is better than the one below")
		lastLo, lastHi = lo, hi
	end
	local elo, ehi = RaceBots.skillRange(4, true)
	local blo, _ = RaceBots.skillRange(1, false)
	truthy(ehi < blo + 0.05 and elo < blo, "easy bots are slower than Bronze's")
	local ol, oh = RaceBots.skillRange(nil, false)
	eq(ol, RaceBots.SKILL_MIN)
	eq(oh, RaceBots.SKILL_MAX)
	-- a league's bots spread across its range (7 of them, names and lanes enough)
	local lo, hi = RaceBots.skillRange(3, false)
	for i = 1, 7 do
		local s = RaceBots.skillFor(i, 7, 0.5, lo, hi)
		truthy(s >= lo and s <= hi, "inside the league's range")
	end
	truthy(#RaceBots.NAMES >= 7)
end)

test("Car VS Car: league bots finish on both maps inside the time limit", function()
	for _, m in RaceMaps.list() do
		for league = 1, 4 do
			local lo, _ = RaceBots.skillRange(league, false)
			local route, bot = setup(m, lo, 1)
			local took = drive(route, bot, ServerRace.MAP_TIME_LIMIT + 120, nil)
			truthy(took ~= nil, `{m.id} league {league} slowest never finished`)
		end
		-- the first-race easy bots may be slow, but they still finish
		local elo, _ = RaceBots.skillRange(1, true)
		local route, bot = setup(m, elo, 1)
		truthy(drive(route, bot, 600, nil) ~= nil, `{m.id} easy bot never finished`)
	end
end)

test(
	"bot strength follows the league: only the car gain RaceStats gives, never a different car",
	function()
		local League = require("../src/shared/League")
		local RaceStats = require("../src/shared/RaceStats")
		-- Bronze bots match a low starter car's pace (carter 10-28): a bit under today's car
		eq(RaceBots.leagueGain(1), RaceStats.topAt(League.NEED[2].strength / 2 / 3))
		truthy(RaceBots.leagueGain(1) < 1)
		local last = RaceBots.leagueGain(1)
		for l = 2, #League.NAMES do
			local g = RaceBots.leagueGain(l)
			truthy(g > last, "each league's bots are a bit quicker")
			truthy(g <= RaceStats.TOP_MIN + RaceStats.TOP, "never more than a full Speed bar gives")
			last = g
		end
		-- bad leagues clamp instead of breaking
		eq(RaceBots.leagueGain(0), RaceBots.leagueGain(1))
		eq(RaceBots.leagueGain(99), RaceBots.leagueGain(#League.NAMES))
		-- the slowest Diamond bot is no faster than the quickest Bronze one (the spread, not the league, is the big part)
		local _, bronzeHi = RaceBots.skillRange(1, false)
		local diamondLo, _ = RaceBots.skillRange(#League.NAMES, false)
		truthy(diamondLo < bronzeHi + 0.05)
		-- ... and the quickest Diamond bot stays a believable pace (never past the player's own top)
		local _, diamondHi = RaceBots.skillRange(#League.NAMES, false)
		truthy(diamondHi <= 1.1)
	end
)

test("easy bots are for a first race only: no league, easy off, gives the normal range", function()
	local elo, ehi = RaceBots.skillRange(3, true)
	local nlo, nhi = RaceBots.skillRange(3, false)
	truthy(ehi < nlo, "an easy race is slower than the same league's normal race")
	truthy(nlo < nhi)
end)

test("Car VS Car: a big race takes a good driver about 1 min (50 to 75 s) on both maps", function()
	-- (cvc-plan: a race is about 1 min. A good driver = the top of a league's bots, who match the
	-- cars' bars there. A first race's easy bots are slower on purpose: a new kid can win it.)
	for _, m in RaceMaps.list() do
		for league = 1, 4 do
			local _, hi = RaceBots.skillRange(league, false)
			local route, bot = setup(m, hi, 1)
			local took = drive(route, bot, ServerRace.MAP_TIME_LIMIT, nil)
			truthy(took ~= nil, `{m.id} league {league} never finished`)
			local t = took :: number
			truthy(t >= 50 and t <= 75, `{m.id} league {league}: {t} s for {ServerRace.LAPS} laps`)
		end
	end
end)

test("Car VS Car: a first race (easy bots) is 1 lap, so it's over in about 1 min", function()
	-- (carter 10-27: 2 laps with easy bots took 1.5 to 2 min. The bots still finish slower than a
	-- good driver, so the new kid still wins it.)
	eq(ServerRace.lapsFor(true), ServerRace.FIRST_LAPS)
	eq(ServerRace.lapsFor(false), ServerRace.LAPS)
	eq(ServerRace.lapsFor(nil), ServerRace.LAPS)
	truthy(ServerRace.FIRST_LAPS < ServerRace.LAPS)
	for _, m in RaceMaps.list() do
		local lo, hi = RaceBots.skillRange(1, true)
		local _, good = RaceBots.skillRange(1, false)
		local times = {}
		for _, skill in { lo, hi, good } do
			local route, bot = setup(m, skill, 2)
			route.laps = ServerRace.FIRST_LAPS
			local took = drive(route, bot, ServerRace.MAP_TIME_LIMIT, nil)
			truthy(took ~= nil, `{m.id} skill {skill} never finished 1 lap`)
			eq(RaceBots.laps(route, bot), ServerRace.FIRST_LAPS)
			table.insert(times, took :: number)
		end
		local slowest, quickest, goodTime = times[1], times[2], times[3]
		print(
			string.format(
				"       %s: easy bots %.0f to %.0f s, a good driver %.0f s",
				m.id,
				quickest,
				slowest,
				goodTime
			)
		)
		-- the last easy bot is in within about 1 min (+ the wait at GO; the race ends a little
		-- after the kid is in anyway)
		truthy(slowest + RaceBots.EASY_DELAY <= 80, `{m.id}: the slowest easy bot took {slowest} s`)
		truthy(goodTime < quickest, `{m.id}: a good driver still beats the easy bots`)
	end
end)

-- An easy race the way the server runs it: `kidMove(kid, since, dt)` moves the new kid (a Bot
-- used as a plain car), the 7 easy bots follow them (progress read 4 times a second, like the
-- server). Returns the kid's time and the bots, and checks no bot ever gets in front.
local function easyRace(
	m: any,
	kidMove: (RaceBots.Bot, number, number) -> ()
): (number?, { RaceBots.Bot })
	local route, kid = setup(m, 0.5, 1)
	route.laps = ServerRace.FIRST_LAPS
	local lo, hi = RaceBots.skillRange(1, true)
	local bots = {}
	for i = 1, ServerRace.MAX - 1 do
		local _, b = setup(m, lo + (hi - lo) * (i - 1) / (ServerRace.MAX - 2), i + 1)
		b.delay = 0.2 + RaceBots.EASY_DELAY
		table.insert(bots, b)
	end
	local follow = RaceBots.newFollow()
	local since, readAt = -3, -3
	local kidAt: number? = nil
	while since < ServerRace.MAP_TIME_LIMIT and kid.time == nil do
		if since >= readAt then
			readAt = since + 0.25
			local pose = RaceBots.pose(route, kid)
			kidAt = RaceBots.roadAt(route, RaceBots.progress(route, kid), pose.x, pose.z)
		end
		RaceBots.follow(follow, kidAt, since)
		kidMove(kid, since, DT)
		if kid.time == nil and kid.dist >= route.total * route.laps then
			kid.time = since
		end
		for _, b in bots do
			-- (no catch-up in an easy race: catchUp 0)
			local was = b.speed
			RaceBots.step(route, b, DT, since, 0, RaceBots.followCap(follow, b))
			truthy(b.time == nil, `{m.id}: a bot (skill {b.skill}) finished before the kid`)
			-- never past the kid; only a put-back can leave one in front (the server reads the
			-- kid 4 times a second), and then it doesn't speed up and isn't far in front
			if b.dist > kid.dist + 1 and kid.dist > -1 then
				local seen = follow.at
				truthy(
					seen == nil or b.dist < seen or b.speed <= was + 1e-6,
					`{m.id}: a bot in front of the kid sped up`
				)
				truthy(b.dist < kid.dist + 60, `{m.id}: a bot got well in front of the kid`)
			end
		end
		since += DT
	end
	return kid.time, bots
end

test(
	"Car VS Car (audit B1): a slow kid in the starter car wins the first race on both maps",
	function()
		-- a slow kid = 10% under the slowest untrained driver (BRONZE_SKILL), 1 s late at GO
		local kidSkill = RaceBots.BRONZE_SKILL[1] * 0.9
		for _, m in RaceMaps.list() do
			local route, pacer = setup(m, kidSkill, 1)
			route.laps = ServerRace.FIRST_LAPS
			pacer.delay = 1
			local took, bots = easyRace(m, function(kid, since, dt)
				RaceBots.step(route, pacer, dt, since, 0)
				kid.dist, kid.speed = pacer.dist, pacer.speed
			end)
			truthy(took ~= nil, `{m.id}: the slow kid never finished`)
			-- the easy bots are at least 20% slower on their own (they're not just held back)
			local lo, hi = RaceBots.skillRange(1, true)
			local _, quick = setup(m, hi, 2)
			local r2 = route
			local since = -3
			while since < 300 and quick.time == nil do
				RaceBots.step(r2, quick, DT, since, 0)
				since += DT
			end
			truthy(
				(quick.time :: number) >= (took :: number) * 1.2,
				`{m.id}: quickest easy bot under 20% slower`
			)
			truthy(lo < hi)
			print(
				string.format(
					"       %s: slow kid %.0f s, quickest easy bot alone %.0f s",
					m.id,
					took :: number,
					quick.time :: number
				)
			)
			eq(#bots, ServerRace.MAX - 1)
		end
	end
)

test("Car VS Car (audit B1): a kid who never steers (AUTO GAS into walls) still wins", function()
	-- (Studio live 3: AUTO GAS, no steering, came last.) Gas for 8 s, hit a wall, sit still 3 s,
	-- get put back 50 behind, again and again.
	for _, m in RaceMaps.list() do
		local took, bots = easyRace(m, function(kid, since, dt)
			if since < 1 then
				return
			end
			local t = (since - 1) % 11
			if t < 8 then
				kid.speed = math.min(40, kid.speed + RaceBots.ACCEL * dt)
				kid.dist += kid.speed * dt
			elseif t < 8 + dt * 1.5 and kid.speed > 0 then
				kid.speed = 0
				kid.dist -= 50 -- put back
			else
				kid.speed = 0
			end
		end)
		truthy(took ~= nil, `{m.id}: the never-steer kid didn't finish in the time limit`)
		local behind = 0
		for _, b in bots do
			if b.dist > 0 then
				behind += 1
			end
		end
		truthy(behind > 0, `{m.id}: the bots never left the grid`)
		print(string.format("       %s: never-steer kid 1st in %.0f s", m.id, took :: number))
	end
end)

test("Car VS Car (audit B1): the bots know where the kid is on the road, from progress", function()
	for _, m in RaceMaps.list() do
		local route, bot = setup(m, 0.6, 1)
		for _, d in { -10, 5, route.total * 0.3, route.total * 0.71, route.total - 20 } do
			bot.dist = d
			bot.seg = 1
			local p = RaceBots.progress(route, bot)
			truthy(math.abs(RaceBots.distOf(route, p) - d) < 1, `{m.id}: distOf at {d}`)
			local pose = RaceBots.pose(route, bot)
			truthy(
				math.abs(RaceBots.roadAt(route, p, pose.x, pose.z) - d) < 15 or d < 0,
				`{m.id}: roadAt at {d}`
			)
		end
		-- the cap: none without a kid, under the kid's pace when close, 0 when level with them
		local f = RaceBots.newFollow()
		eq(RaceBots.followCap(f, bot), nil)
		RaceBots.follow(f, 100, 0)
		RaceBots.follow(f, 110, 0.25) -- 40/s
		bot.dist = 100 - RaceBots.FOLLOW_GAP
		local cap = RaceBots.followCap(f, bot) :: number
		truthy(cap > 0 and cap < 40, "just under the kid's pace at the gap")
		bot.dist = 110
		eq(RaceBots.followCap(f, bot), RaceBots.FOLLOW_MIN)
		RaceBots.follow(f, 60, 0.5) -- put back: wait
		eq(f.speed, 0)
		RaceBots.follow(f, nil, 0.75) -- no new kid racing: let go
		eq(RaceBots.followCap(f, bot), nil)
	end
	-- and the server wires it: no catch-up, the cap, the furthest new kid's road spot
	local fs = require("@lune/fs")
	local src = fs.readFile("src/server/RaceBotCars.luau")
	truthy(string.find(src, "if lead and not fleet.easy then", 1, true), "easy bots still catch up")
	truthy(string.find(src, "then RaceBots.followCap(", 1, true), "no follow cap")
	truthy(string.find(src, "if car.rival then -RaceBots.RIVAL_LEAD else nil", 1, true), "no rival")
	truthy(string.find(src, "local rival = easy and i == 1", 1, true), "no rival picked")
	truthy(string.find(src, "then RaceBots.RIVAL_SKILL", 1, true), "rival too slow")
	local run = fs.readFile("src/server/ServerRaceRunner.luau")
	truthy(
		string.find(
			run,
			"RaceBotCars.step(bots, clock, goAt, lead, if held then kidLead else nil)",
			1,
			true
		)
	)
	truthy(string.find(run, "RaceBots.roadAt(bots.route, progress, lx, lz)", 1, true))
	truthy(string.find(run, "new = solo[i],", 1, true), "racers don't know who is new")
end)

test("Car VS Car: the easy race's rival rides in view, in front of the kid, and loses", function()
	for _, m in RaceMaps.list() do
		local route, bot = setup(m, RaceBots.RIVAL_SKILL, 1)
		route.laps = 1
		local line = route.total
		local f = RaceBots.newFollow()
		local kid, since, seen, samples = 0, 0, 0, 0
		while since < 200 and kid < line + 40 do
			kid += 55 * DT -- a new kid, not flat out
			since += DT
			local k = if kid < line then kid else nil
			RaceBots.follow(f, k, since)
			local cap = RaceBots.followCap(f, bot, -RaceBots.RIVAL_LEAD)
			local lc = RaceBots.lineCap(route, bot, k)
			if lc then
				cap = math.min(cap or lc, lc)
			end
			RaceBots.step(route, bot, DT, since, 0, cap)
			if since > 8 and kid < line - 120 then
				samples += 1
				local ahead = bot.dist - kid
				if ahead > 0 and ahead < RaceBots.RIVAL_LEAD + 15 then
					seen += 1
				end
			end
			if bot.time ~= nil then
				truthy(kid >= line, `{m.id}: the rival beat the new kid`)
			end
		end
		truthy(samples > 0 and seen / samples > 0.8, `{m.id}: rival in view {seen}/{samples}`)
		-- and a rival in front of a stopped kid waits there
		RaceBots.follow(f, 500, since + 1)
		RaceBots.follow(f, 500, since + 2)
		bot.time = nil
		bot.dist = 500 + RaceBots.RIVAL_LEAD + 1
		eq(RaceBots.followCap(f, bot, -RaceBots.RIVAL_LEAD), RaceBots.FOLLOW_MIN)
	end
end)

test(
	"Car VS Car: a kid stuck far behind does not freeze the easy bots for the whole race",
	function()
		local m = RaceMaps.list()[1]
		local route, bot = setup(m, 0.42, 2)
		local f = RaceBots.newFollow()
		-- the kid drove into a wall and was put back on the start line: 3000 units behind the bot
		bot.dist = 3000
		RaceBots.follow(f, 0, 0)
		RaceBots.follow(f, 0, 0.25)
		local cap = RaceBots.followCap(f, bot) :: number
		eq(cap, RaceBots.FOLLOW_CRAWL, "creeps on instead of freezing at 0")
		truthy(cap > 0)
		-- the bot really moves under that cap, and not faster than it
		bot.speed = 0
		local since, start = 10, bot.dist
		for _ = 1, 90 do
			RaceBots.step(route, bot, DT, since, 0, RaceBots.followCap(f, bot))
			since += DT
		end
		truthy(bot.dist - start > 15, "rolled on")
		truthy(bot.speed <= RaceBots.FOLLOW_CRAWL + 0.01, "never over the crawl")
		-- a kid only just behind (a put-back a few cars back) is still waited for
		bot.dist = 1000
		RaceBots.follow(f, 1000 - RaceBots.FOLLOW_WAIT + 10, 0.5)
		eq(RaceBots.followCap(f, bot), RaceBots.FOLLOW_MIN)
	end
)

test(
	"Car VS Car (Studio after-810): a kid stuck on the first bend still ranks 1st, bots never finish first",
	function()
		-- AUTO GAS, no steering: straight into the first bend's wall, stuck (the stuck clock), put back
		-- where BackOnTrack.roadSpot says with AUTO GAS still on, into the same wall again. The race
		-- runs out of time; the kid must still be ahead of every bot.
		local BackOnTrack = require("../src/shared/BackOnTrack")
		local Tuning = require("../src/shared/Tuning")
		for _, m in RaceMaps.list() do
			local t = m.track()
			local loop = m.loop()
			local route, kid = setup(m, 0.5, 1)
			route.laps = ServerRace.FIRST_LAPS
			-- where a car that doesn't steer meets the first bend
			local wallAt = route.total
			for k = 1, route.n do
				if route.cum[k] > 30 and route.kappa[k] > 0.01 then
					wallAt = route.cum[k] + 10
					break
				end
			end
			local lo, hi = RaceBots.skillRange(1, true)
			local bots = {}
			for i = 1, ServerRace.MAX - 1 do
				local _, b = setup(m, lo + (hi - lo) * (i - 1) / (ServerRace.MAX - 2), i + 1)
				b.delay = 0.2 + RaceBots.EASY_DELAY
				table.insert(bots, b)
			end
			local follow = RaceBots.newFollow()
			local stuckFor, putBacks, leastBack = 0, 0, math.huge
			local since, readAt = -3, -3
			local kidAt: number? = nil
			while since < ServerRace.MAP_TIME_LIMIT do
				if since >= readAt then
					readAt = since + 0.25
					local pose = RaceBots.pose(route, kid)
					kidAt = RaceBots.roadAt(route, RaceBots.progress(route, kid), pose.x, pose.z)
				end
				RaceBots.follow(follow, kidAt, since)
				if since >= 1 then
					if kid.dist < wallAt then
						kid.speed = math.min(40, kid.speed + RaceBots.ACCEL * DT)
						kid.dist = math.min(wallAt, kid.dist + kid.speed * DT)
					else
						kid.speed = 0
						stuckFor += DT
						-- the stuck clock (pedal held, not moving) plus its half-second average
						if BackOnTrack.stuck(stuckFor - 0.5, Tuning.stuckWait, t.id) then
							local pose = RaceBots.pose(route, kid)
							-- (the lap timer waits for the gate after the last one it passed)
							local passed = 1
							for g = 2, #route.gateAt do
								if route.gateAt[g] <= kid.dist then
									passed = g
								end
							end
							local s = BackOnTrack.roadSpot(
								t,
								loop,
								t.gates,
								passed + 1,
								pose.x,
								pose.z
							) :: BackOnTrack.Spot
							-- back on the route where that spot is
							local best, at = math.huge, 0
							for k = 1, route.n do
								local d = (route.x[k] - s.x) ^ 2 + (route.z[k] - s.z) ^ 2
								if d < best then
									best, at = d, route.cum[k]
								end
							end
							leastBack = math.min(leastBack, at)
							kid.dist, stuckFor, putBacks = at, 0, putBacks + 1
						end
					end
				end
				for _, b in bots do
					local cap = RaceBots.followCap(follow, b)
					local line = RaceBots.lineCap(route, b, kidAt)
					if line then
						cap = math.min(cap or line, line)
					end
					RaceBots.step(route, b, DT, since, 0, cap)
					truthy(b.time == nil, `{m.id}: a bot finished while the kid was stuck`)
				end
				since += DT
			end
			truthy(putBacks >= 3, `{m.id}: only {putBacks} put-backs`)
			truthy(leastBack > 40, `{m.id}: put back on the start line`)
			truthy(wallAt - leastBack < 80, `{m.id}: put back far from where it got stuck`)
			-- the time limit: the kid (laps 0, a new kid) ranks ahead of every bot
			local entries: { ServerRace.Entry } =
				{ { name = "zz kid", uid = 1, laps = 0, kid = true } }
			for i, b in bots do
				table.insert(
					entries,
					{ name = `a bot {i}`, laps = RaceBots.laps(route, b), time = b.time }
				)
			end
			eq(ServerRace.rank(entries)[1].uid, 1)
			print(
				string.format(
					"       %s: stuck at %.0f, put back at %.0f, %d times",
					m.id,
					wallAt,
					leastBack,
					putBacks
				)
			)
		end
	end
)

test("Car VS Car (Studio after-810): a held easy bot eases off and never stops dead", function()
	local m = RaceMaps.list()[1]
	local route, bot = setup(m, 0.45, 2)
	local f = RaceBots.newFollow()
	-- following a kid at 40, then the kid hits a wall and stops
	bot.dist, bot.speed = 500, 40
	RaceBots.follow(f, 500 + RaceBots.FOLLOW_GAP, 0)
	RaceBots.follow(f, 510 + RaceBots.FOLLOW_GAP, 0.25)
	RaceBots.follow(f, 510 + RaceBots.FOLLOW_GAP, 0.5)
	RaceBots.follow(f, 509 + RaceBots.FOLLOW_GAP, 0.75) -- (backing off the wall: stopped)
	local since = 10
	local slowest = math.huge
	for _ = 1, 30 * 8 do
		local was = bot.speed
		RaceBots.step(route, bot, DT, since, 0, RaceBots.followCap(f, bot))
		truthy(was - bot.speed <= RaceBots.FOLLOW_BRAKE * DT + 1e-6, "braked hard")
		slowest = math.min(slowest, bot.speed)
		since += DT
	end
	truthy(slowest >= RaceBots.FOLLOW_MIN - 1e-6, `stopped dead ({slowest})`)
	truthy(bot.speed <= RaceBots.FOLLOW_MIN + 1e-6, "eased right down to a crawl")
end)

test("Car VS Car (Studio after-818): a put-back doesn't flip the new kid to 8TH", function()
	for _, m in RaceMaps.list() do
		local route = setup(m, 0.42, 1)
		route.laps = 2
		local function at(d: number, skill: number?): RaceBots.Bot
			local _, b = setup(m, skill or 0.42, 2)
			b.dist = d
			b.seg = 1
			return b
		end
		-- the kid was 1ST mid-lap, the held bots 10-30 behind; then put back 45 along the road
		local mid = route.total * 0.55
		local kidAt = mid - 45
		local kid = RaceBots.progress(route, at(kidAt))
		local runs: { ServerRace.Run } = { { time = nil, progress = kid } }
		for k = 1, 6 do
			local b = at(mid - 5 * k)
			local real = RaceBots.progress(route, b)
			table.insert(runs, {
				time = nil,
				progress = RaceBots.placeProgress(b, real, kidAt, kid, false),
			})
		end
		eq(ServerRace.places(runs)[1], 1, `{m.id}: the kid stays 1ST over bots waiting for them`)
		-- the rival in front still counts (2ND), and so does a bot far ahead of a stuck kid
		local rival = at(kidAt + RaceBots.RIVAL_LEAD)
		table.insert(runs, {
			time = nil,
			progress = RaceBots.placeProgress(
				rival,
				RaceBots.progress(route, rival),
				kidAt,
				kid,
				true
			),
		})
		eq(ServerRace.places(runs)[1], 2, `{m.id}: behind the rival`)
		local far = at(kidAt + RaceBots.FOLLOW_WAIT + 50)
		local real = RaceBots.progress(route, far)
		eq(RaceBots.placeProgress(far, real, kidAt, kid, false), real)
	end
	local fs = require("@lune/fs")
	local run = fs.readFile("src/server/ServerRaceRunner.luau")
	truthy(string.find(run, "then RaceBots.placeProgress(", 1, true), "places not wired")
end)
