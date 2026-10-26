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

test("bots finish 3 laps on every map, inside the map's time limit", function()
	for _, m in RaceMaps.list() do
		for _, skill in { RaceBots.SKILL_MIN, RaceBots.SKILL_MAX } do
			local route, bot = setup(m, skill, 2)
			local took = drive(route, bot, ServerRace.MAP_TIME_LIMIT + 60, nil)
			truthy(took ~= nil, `{m.id} skill {skill} never finished`)
			truthy(
				(took :: number) < ServerRace.MAP_TIME_LIMIT,
				`{m.id} skill {skill}: {took} s is too slow`
			)
			truthy((took :: number) > 60, `{m.id} skill {skill}: {took} s is too fast`)
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
		eq(RaceBots.laps(r1, slow), 3)
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
	truthy(last >= 3 * (gates + 1) - 2, "three laps is about 3 * (gates + 1)")
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
