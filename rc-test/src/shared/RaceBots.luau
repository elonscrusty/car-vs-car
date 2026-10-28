--!strict
-- Race bots (carter's tycoon plan, 10-26): a map race with fewer than MIN_CARS cars gets filled
-- with simple bot cars, so a lone player still has a race. A bot follows the map's centre line
-- (Map.loop(), big units): slower in the bends, a lane of its own, its own top speed. It never
-- touches the player's car: this is only the bots' own pace. Pure maths (plain tables, Lune
-- tests it); the parts that draw the bots are the server's (RaceBotCars).

-- Loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local League = sibling("League")
local RaceStats = sibling("RaceStats")
local ServerRace = sibling("ServerRace")

export type Sample = { x: number, z: number, tx: number, tz: number }

-- One map's road as the bots see it: the centre line from the start line round, closed.
export type Route = {
	n: number,
	x: { number }, -- sample k (1 = the sample at the start line, driving order)
	z: { number },
	tx: { number },
	tz: { number },
	cum: { number }, -- cum[k] = distance along the line to sample k (cum[1] = 0)
	total: number, -- one lap
	kappa: { number }, -- how sharp the bend is at sample k (1 / radius, big units)
	gateAt: { number }, -- distance from the line of each lap gate (gate 1 = the line = 0)
	bendAt: number, -- distance from the line to the end of the first bend (RaceBots.firstBend)
	laps: number?, -- laps in this race (nil = ServerRace.LAPS)
}

export type Bot = {
	name: string,
	skill: number, -- 0.5..1: top speed and how hard it takes a bend
	lane: number, -- sideways spot on the road, big units (+ = right of travel)
	gridLane: number, -- where it starts, on the grid (same units)
	phase: number, -- where its little sway starts
	delay: number, -- seconds it takes to react to GO
	limit: { number }, -- speed it can carry at each sample (bends and braking in)
	dist: number, -- along the road from the start line (negative = on the grid)
	speed: number,
	seg: number, -- the sample just behind it
	time: number?, -- seconds from GO when it finished
	color: { number },
}

local RaceBots = {}

RaceBots.MIN_CARS = 4 -- fill the race with bots up to this many cars
RaceBots.TOP = 120 -- a skill-1 bot's top speed, big units/s (the player's is ~95, boost pads 1.35x)
RaceBots.ACCEL = 55
RaceBots.BRAKE = 110
RaceBots.GRIP = 200 -- sideways acceleration a skill-1 bot takes a bend at (big units/s^2)
RaceBots.SKILL_MIN = 0.7
RaceBots.SKILL_MAX = 1
RaceBots.LANE = 7 -- most a bot sits off the centre line (roads are 30..40 wide)
RaceBots.CATCH_UP = 0.1 -- most a bot speeds up or slows down to stay near the players
RaceBots.CATCH_GAP = 1 -- gap (in ServerRace.progress units, about one gate) at which it is full
RaceBots.EASE = 150 -- distance after the line it takes to move from its grid spot to its lane

RaceBots.NAMES = {
	"Zoomy",
	"Dash",
	"Pepper",
	"Nitro",
	"Rusty",
	"Sprout",
	"Turbo Tim",
	"Skid",
	"Peanut",
	"Blaze",
}

-- The colours bots drive in (not a shop car's, so a player's pick is never copied).
RaceBots.COLORS = {
	{ 250, 120, 60 },
	{ 60, 190, 140 },
	{ 170, 110, 230 },
	{ 240, 80, 120 },
	{ 70, 160, 240 },
	{ 230, 210, 70 },
}

-- Car VS Car: a race is filled with bots up to the whole grid (8), and how good they are follows
-- the league. A league's players have trained cars (RaceStats: a full Speed bar is only a bit
-- faster, because skill counts as much as the car), so the bots get only that same car gain on
-- top of the untrained spread (BRONZE_SKILL): a Diamond bot is not a different kind of car, just
-- as fast as a car trained that far. The first race of a new player uses EASY_SKILL, so they win it.
RaceBots.BRONZE_SKILL = { 0.62, 0.95 } :: { number }
-- (audit B1: a new kid lost all 3 recorded first races. Easy bots now finish at least 20% slower
-- than a slow kid in the starter car, never speed up to catch them, and wait for them up to the
-- end of the first bend.)
RaceBots.EASY_SKILL = { 0.4, 0.45 } :: { number }
RaceBots.EASY_DELAY = 0.6 -- easy bots also wake up this much later at GO (seconds)
RaceBots.BEND = 0.01 -- a bend is sharper than this (1 / radius, big units): the first bend's start
RaceBots.HOLD = 0.3 -- an easy bot ahead of the kid before the end of the first bend drives this slow

-- The skill range (lowest, highest) for a race in `league` (1..4; nil = the old fixed range),
-- or the easy range.
function RaceBots.skillRange(league: number?, easy: boolean?): (number, number)
	if easy then
		return RaceBots.EASY_SKILL[1], RaceBots.EASY_SKILL[2]
	end
	if league == nil then
		return RaceBots.SKILL_MIN, RaceBots.SKILL_MAX
	end
	local m = RaceBots.leagueGain(league)
	return RaceBots.BRONZE_SKILL[1] * m, RaceBots.BRONZE_SKILL[2] * m
end

-- How much faster a car typical of `league` is than an untrained one (RaceStats' top speed gain
-- at the league's usual bars: halfway between its entry strength and the next league's, spread
-- over the 3 bars). Bronze = 1.
function RaceBots.leagueGain(league: number): number
	local n = #League.NAMES
	local l = League.clamp(league)
	local need = League.NEED[l].strength
	local upper = if l < n then League.NEED[l + 1].strength else need + 60
	local bar = (need + upper) / 2 / 3 -- an average bar, 0..100
	if l == 1 then
		return 1
	end
	return 1 + RaceStats.TOP * math.clamp(bar, 0, 100) / 100
end

-- How many bots a race with `humans` players needs (0 when nobody is there: no race at all).
-- `fill` = how many cars the race is filled up to (default MIN_CARS; Car VS Car fills the grid).
function RaceBots.count(humans: number, max: number, fill: number?): number
	if humans < 1 then
		return 0
	end
	return math.max(0, math.min(fill or RaceBots.MIN_CARS, max) - humans)
end

local function wrap(i: number, n: number): number
	return (i - 1) % n + 1
end

-- The route: the map's centre line starting at `line`, with how sharp each bend is and where
-- each lap gate sits along it (`gates` = LapTimer gates, gate 1 the start line).
-- Where the first bend ends: the first stretch from the line sharper than BEND, to where it
-- straightens again (distance along the lap; 0 = a road with no bend).
function RaceBots.firstBend(route: Route): number
	local k = 1
	while k <= route.n and route.kappa[k] <= RaceBots.BEND do
		k += 1
	end
	if k > route.n then
		return 0
	end
	while k <= route.n and route.kappa[k] > RaceBots.BEND do
		k += 1
	end
	return if k > route.n then route.total else route.cum[k]
end

-- An easy bot waits for the kid: it is still before the end of the first bend (first lap) and
-- ahead of the leading player (`lead` = their ServerRace.progress, nil = none moving yet).
function RaceBots.holds(route: Route, bot: Bot, lead: number?): boolean
	if bot.dist >= route.bendAt then
		return false
	end
	return lead == nil or RaceBots.progress(route, bot) >= lead
end

function RaceBots.route(loop: { Sample }, line: number, gates: { { x: number, z: number } }): Route
	local n = #loop
	local r: Route = {
		n = n,
		x = {},
		z = {},
		tx = {},
		tz = {},
		cum = {},
		total = 0,
		kappa = {},
		gateAt = {},
		bendAt = 0,
	}
	for k = 1, n do
		local s = loop[wrap(line + k - 1, n)]
		r.x[k], r.z[k], r.tx[k], r.tz[k] = s.x, s.z, s.tx, s.tz
	end
	local sum = 0
	for k = 1, n do
		r.cum[k] = sum
		local j = wrap(k + 1, n)
		sum += math.sqrt((r.x[j] - r.x[k]) ^ 2 + (r.z[j] - r.z[k]) ^ 2)
	end
	r.total = sum
	-- bend sharpness: the turn of the heading across 3 samples each side, per distance
	local reach = 3
	for k = 1, n do
		local a, b = wrap(k - reach, n), wrap(k + reach, n)
		local cross = r.tx[a] * r.tz[b] - r.tz[a] * r.tx[b]
		local dot = r.tx[a] * r.tx[b] + r.tz[a] * r.tz[b]
		local turn = math.abs(math.atan2(cross, dot))
		local len = 0
		for q = 0, 2 * reach - 1 do
			local i, j = wrap(k - reach + q, n), wrap(k - reach + q + 1, n)
			len += math.sqrt((r.x[j] - r.x[i]) ^ 2 + (r.z[j] - r.z[i]) ^ 2)
		end
		r.kappa[k] = if len > 0 then turn / len else 0
	end
	-- each gate sits at its nearest sample
	for g, gate in gates do
		local best, at = math.huge, 1
		for k = 1, n do
			local d = (r.x[k] - gate.x) ^ 2 + (r.z[k] - gate.z) ^ 2
			if d < best then
				best, at = d, k
			end
		end
		r.gateAt[g] = if g == 1 then 0 else r.cum[at]
	end
	r.bendAt = RaceBots.firstBend(r)
	return r
end

-- A bot: `skill` 0..1 picks its pace, `lane` its sideways spot, `grid` its row behind the line
-- (distance behind it, big units).
function RaceBots.new(
	route: Route,
	name: string,
	skill: number,
	lane: number,
	gridLane: number,
	phase: number,
	delay: number,
	behind: number,
	color: { number }
): Bot
	local n = route.n
	local vmax = RaceBots.TOP * skill
	local grip = RaceBots.GRIP * skill * skill
	local limit: { number } = table.create(n, vmax)
	for k = 1, n do
		local kap = route.kappa[k]
		if kap > 1e-6 then
			limit[k] = math.min(vmax, math.sqrt(grip / kap))
		end
	end
	-- braking in: look ahead round the lap twice so the line's seam is smooth
	for _ = 1, 2 do
		for k = n * 2, 1, -1 do
			local i, j = wrap(k, n), wrap(k + 1, n)
			local ds = (route.cum[j] - route.cum[i]) % route.total
			local v = limit[j]
			local can = math.sqrt(v * v + 2 * RaceBots.BRAKE * 0.8 * ds)
			if can < limit[i] then
				limit[i] = can
			end
		end
	end
	return {
		name = name,
		skill = skill,
		lane = lane,
		gridLane = gridLane,
		phase = phase,
		delay = delay,
		limit = limit,
		dist = -behind,
		speed = 0,
		seg = n,
		time = nil,
		color = color,
	}
end

-- The sample at or just behind `d` along the lap (d in [0, total)), searching on from `hint`.
local function segAt(route: Route, d: number, hint: number): number
	local n, cum = route.n, route.cum
	local k = math.clamp(hint, 1, n)
	-- (the lap restarts: go back to the start)
	if cum[k] > d then
		k = 1
	end
	while k < n and cum[k + 1] <= d do
		k += 1
	end
	return k
end

local function lapsOf(route: Route): number
	return route.laps or ServerRace.LAPS
end

local function lapPos(d: number, total: number): number
	return d % total
end

-- Move a bot on by `dt` seconds. `since` = seconds since GO (negative before), `catchUp` in
-- -1..1: how far it is ahead (+1) or behind (-1) the players, and so slows or speeds up.
-- `hold` = an easy bot waiting for the kid (RaceBots.holds): it drives at HOLD of its pace.
function RaceBots.step(
	route: Route,
	bot: Bot,
	dt: number,
	since: number,
	catchUp: number,
	hold: boolean?
)
	if since < bot.delay then
		return
	end
	if bot.time ~= nil and bot.dist > route.total * lapsOf(route) + 60 then
		-- past the line and out of the way: coast to a halt
		bot.speed = math.max(0, bot.speed - RaceBots.BRAKE * dt)
		bot.dist += bot.speed * dt
		return
	end
	local d = lapPos(bot.dist, route.total)
	bot.seg = segAt(route, d, bot.seg)
	local k = bot.seg
	local nextK = wrap(k + 1, route.n)
	local span = (route.cum[nextK] - route.cum[k]) % route.total
	local u = if span > 0 then math.clamp((d - route.cum[k]) / span, 0, 1) else 0
	local want = bot.limit[k] + (bot.limit[nextK] - bot.limit[k]) * u
	want *= 1 - catchUp * RaceBots.CATCH_UP
	if hold then
		want *= RaceBots.HOLD
	end
	if bot.speed < want then
		bot.speed = math.min(want, bot.speed + RaceBots.ACCEL * dt)
	else
		bot.speed = math.max(want, bot.speed - RaceBots.BRAKE * dt)
	end
	bot.dist += bot.speed * dt
	if bot.time == nil and bot.dist >= route.total * lapsOf(route) then
		bot.time = since
	end
end

export type Pose = { x: number, z: number, dx: number, dz: number, yaw: number }

-- Where the bot is (big units, map-local), the way it faces, and how fast it is turning (rad/s).
function RaceBots.pose(route: Route, bot: Bot): Pose
	local d = lapPos(bot.dist, route.total)
	local k = segAt(route, d, bot.seg)
	local j = wrap(k + 1, route.n)
	local span = (route.cum[j] - route.cum[k]) % route.total
	local u = if span > 0 then math.clamp((d - route.cum[k]) / span, 0, 1) else 0
	local tx = route.tx[k] + (route.tx[j] - route.tx[k]) * u
	local tz = route.tz[k] + (route.tz[j] - route.tz[k]) * u
	local len = math.sqrt(tx * tx + tz * tz)
	if len < 1e-6 then
		tx, tz, len = route.tx[k], route.tz[k], 1
	end
	tx, tz = tx / len, tz / len
	-- its lane, with a slow sway so the bots do not drive in a row
	local ease = math.clamp(bot.dist / RaceBots.EASE, 0, 1)
	local side = bot.gridLane
		+ (bot.lane + 2.5 * math.sin(bot.dist / 110 + bot.phase) - bot.gridLane) * ease
	side = math.clamp(side, -RaceBots.LANE, RaceBots.LANE)
	local px = route.x[k] + (route.x[j] - route.x[k]) * u
	local pz = route.z[k] + (route.z[j] - route.z[k]) * u
	local kap = route.kappa[k]
	-- (the sign of the bend: left turn = + yaw about y)
	local cross = route.tx[k] * route.tz[j] - route.tz[k] * route.tx[j]
	local yaw = kap * bot.speed * (if cross > 0 then -1 else 1)
	return {
		x = px - tz * side,
		z = pz + tx * side,
		dx = tx,
		dz = tz,
		yaw = yaw,
	}
end

-- Laps finished (0 on the grid).
function RaceBots.laps(route: Route, bot: Bot): number
	return math.clamp(math.floor(bot.dist / route.total), 0, lapsOf(route))
end

-- How far round a bot is, in the same units as ServerRace.progress for a player: the gates it
-- has passed this lap, laps * (gates + 1), a hair for the distance to the next gate.
function RaceBots.progress(route: Route, bot: Bot): number
	local gates = #route.gateAt
	if bot.dist < 0 then
		return -(-bot.dist) / 10000
	end
	local laps = math.floor(bot.dist / route.total)
	local d = bot.dist - laps * route.total
	local passed = 1
	local nextAt = route.total
	for g = 2, gates do
		if route.gateAt[g] <= d then
			passed = g
		else
			nextAt = route.gateAt[g]
			break
		end
	end
	return laps * (gates + 1) + passed - math.clamp(nextAt - d, 0, 9999) / 10000
end

-- Spread of the bots: skill and lane for bot number `i` of `count` (r = a random number 0..1 per
-- bot), so there is a quick one, a slow one and some in the middle.
function RaceBots.skillFor(i: number, count: number, r: number, lo: number?, hi: number?): number
	local low = lo or RaceBots.SKILL_MIN
	local span = (hi or RaceBots.SKILL_MAX) - low
	local slot = if count > 1 then (i - 1) / (count - 1) else 0.5
	return low + span * math.clamp(slot * 0.8 + r * 0.2, 0, 1)
end

function RaceBots.laneFor(i: number): number
	local lanes = { -4.5, 4.5, 0, -2, 2, -6, 6 }
	return lanes[(i - 1) % #lanes + 1]
end

return RaceBots
