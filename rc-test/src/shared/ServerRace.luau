--!strict
-- The server race (carter's loop, /mnt/project-files/rc-game/build-track/PLAN.md): a 5 minute
-- break to build and shop, then the whole server races on one random player's plot, then the
-- next break. Pure maths here (plain tables, Lune tests it): what the street sign says, which
-- plot, the grid spots and the finishing order.

-- Loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local RaceStart = sibling("RaceStart")

export type Spawn = { x: number, y: number, z: number, dx: number, dz: number }
export type Entry = {
	name: string,
	uid: number?, -- the racer's UserId (who gets the coins)
	laps: number, -- laps done
	time: number?, -- seconds from GO to the finish (nil = didn't finish)
	score: number?, -- a drift round: drift points (the server's own count)
}

local ServerRace = {}

ServerRace.BREAK = 5 * 60 -- the break between races (build, shop, drive your own plot)
ServerRace.CALL = 10 -- the plot is picked and named this long before the start
-- the race starts this long after its clock shows 0:00, so a JOIN tapped on 0:00 still gets in
-- (critic run 1: a tap at 0:00 landed 0.4 s late and waited 20 s for the next race)
ServerRace.JOIN_GRACE = 1
ServerRace.LAPS = 2 -- map races: about 1 min (Car VS Car, 10-26)
-- a new player's first race (easy bots) is 1 lap: 2 took them 1.5 to 2 min (carter 10-27: shorter)
ServerRace.FIRST_LAPS = 1
ServerRace.MAX = 8 -- cars on the grid
ServerRace.TIME_LIMIT = 240 -- seconds from GO: the race ends even if nobody finished
ServerRace.AFTER_WIN = 30 -- the others get this long to finish after the winner
-- Car VS Car map races: 15 (critic run 1: a lost kid sat 30 s on FINISH IN, 3 times in 10 min)
ServerRace.MAP_AFTER_WIN = 15
ServerRace.DRIFT_TIME = 90 -- a drift round (the plot's owner picked drift): best score in this long
ServerRace.SHOW = 7 -- seconds the result shows before the racers walk back
-- GO comes when the start lights go green (the player's screen starts them as the car lands)
ServerRace.GO_DELAY = RaceStart.WAIT + 3 * RaceStart.STEP
-- grid: two cars side by side, rows behind the start spot (big plot units, road is 30 wide)
ServerRace.GRID_SIDE = 7
ServerRace.GRID_ROW = 12
ServerRace.BACK = 14 -- the pole's distance behind the line (the plot's own start spot)

-- 754 -> "12:34"
function ServerRace.clock(secs: number): string
	local s = math.max(0, math.ceil(secs))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- Whose track it is, for the sign and the screens: "MIA'S TRACK" ("" = not picked yet).
function ServerRace.trackName(owner: string?): string
	if owner == nil or owner == "" then
		return ""
	end
	return string.upper(owner) .. "'S TRACK"
end

-- What the sign over the street says, `left` seconds before the start (racing = a race is on;
-- where = trackName of the picked plot).
function ServerRace.signText(left: number, racing: boolean, where: string?): string
	local at = if where and where ~= "" then "\n" .. where else ""
	if racing then
		return "RACING NOW!" .. at
	end
	if left <= ServerRace.CALL then
		return "RACE IN " .. ServerRace.clock(left) .. at
	end
	return "NEXT RACE\n" .. ServerRace.clock(left) -- (no tracks to build in the tycoon plan)
end

-- Which plot the round is on: a random one of the race-ready player plots (`owned`), else a
-- random one of the rest (`spare`, the street's own race plots). r = a random number 0..1.
-- The round clock, one tick: what to do now. "wait" (the break) -> "pick" at CALL seconds left
-- (pick the plot, show its name) -> "call" -> at 0: "race" on the picked plot, or "skip" (no
-- plot was ready, or nobody is here: straight into the next break). nil = nothing yet.
-- After a race (or a skip) the runner goes back to "wait" with a new BREAK.
function ServerRace.step(
	phase: string,
	left: number,
	picked: number?,
	players: number
): ("pick" | "race" | "skip")?
	if phase == "wait" and left <= ServerRace.CALL then
		return "pick"
	elseif phase == "call" and left <= -ServerRace.JOIN_GRACE then
		return if picked == nil or players == 0 then "skip" else "race"
	end
	return nil
end

-- The build window (workspace BuildOpen / BuildEndsAt): open all through the break, shut from
-- the moment the plot is picked until the race is over; it closes CALL seconds before the start.
function ServerRace.build(phase: string, startAt: number): (boolean, number)
	return phase == "wait", math.floor(startAt - ServerRace.CALL)
end

function ServerRace.pick(owned: { number }, spare: { number }, r: number): number?
	local list = if #owned > 0 then owned else spare
	if #list == 0 then
		return nil
	end
	return list[math.clamp(math.floor(r * #list) + 1, 1, #list)]
end

-- A point of the road's centre line, with its travel direction (Kit samples are like this).
export type Sample = { x: number, z: number, tx: number, tz: number }

-- Grid spot k (1 = pole), plot-local: two side by side, rows following the road back from
-- `back` behind the start line (`line` = the loop sample at the line, as index into `loop`).
function ServerRace.grid(loop: { Sample }, line: number, back: number, k: number, y: number): Spawn
	local row = (k - 1) // 2
	local side = if k % 2 == 1 then -1 else 1
	local want = back + row * ServerRace.GRID_ROW
	-- walk backwards along the centre line until `want` is used up
	local n = #loop
	local i = line
	local x, z = loop[i].x, loop[i].z
	local tx, tz = loop[i].tx, loop[i].tz
	local left = want
	for _ = 1, n do
		local j = (i - 2) % n + 1 -- the sample before i
		local px, pz = loop[j].x, loop[j].z
		local len = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
		if len >= left then
			local u = left / len
			x, z = x + (px - x) * u, z + (pz - z) * u
			tx, tz = loop[j].tx, loop[j].tz
			left = 0
			break
		end
		left -= len
		x, z, i = px, pz, j
	end
	-- across the road: the travel direction turned a quarter
	local ax, az = -tz, tx
	return {
		x = x + ax * side * ServerRace.GRID_SIDE,
		y = y,
		z = z + az * side * ServerRace.GRID_SIDE,
		dx = tx,
		dz = tz,
	}
end

-- Grid spot k on a race plot (its Plots module): lined up behind the start line, the pole as
-- far back as the plot's own start spot. `y` = the start spot's height.
function ServerRace.gridOn(plot: any, k: number, y: number): Spawn
	return ServerRace.grid(plot.loop(), plot.lineSample(), ServerRace.BACK, k, y)
end

-- Finishing order: finishers by time, then the rest by laps done.
function ServerRace.rank(entries: { Entry }): { Entry }
	local out = table.clone(entries)
	table.sort(out, function(a: Entry, b: Entry): boolean
		local ta, tb = a.time, b.time
		if ta and tb then
			return ta < tb
		elseif ta or tb then
			return ta ~= nil
		elseif a.laps ~= b.laps then
			return a.laps > b.laps
		end
		return a.name < b.name
	end)
	return out
end

-- Coins for a server race (the game's main pay: every race pays, the best pay most). Coin
-- prices are guesses to tune: a win is most of a 150-coin car or tile.
ServerRace.PAY = { 100, 70, 50 } -- 1st, 2nd, 3rd
ServerRace.PAY_FINISH = 40 -- finished all the laps, 4th or later (40: last place still gets somewhere)
ServerRace.PAY_TRY = 10 -- raced but didn't finish
ServerRace.PAY_OWNER = 40 -- the plot's owner: "your track was picked!"
function ServerRace.payFor(place: number, finished: boolean): number
	if not finished then
		return ServerRace.PAY_TRY
	end
	return ServerRace.PAY[place] or ServerRace.PAY_FINISH
end

-- Stars for a server race: 1st 3, 2nd 2, 3rd 1, any other finish 1. Racing alone only gets the
-- finish star (no one to beat).
ServerRace.STARS = { 3, 2, 1 }
function ServerRace.starsFor(place: number, finished: boolean, racers: number): number
	if not finished then
		return 0
	end
	if racers <= 1 then
		return 1
	end
	return ServerRace.STARS[place] or 1
end

-- Is the race over? (`since` = seconds from GO, `firstAt` = when the winner finished)
function ServerRace.over(
	entries: { Entry },
	since: number,
	firstAt: number?,
	limit: number?,
	afterWin: number?
): boolean
	if since >= (limit or ServerRace.TIME_LIMIT) then
		return true
	end
	if firstAt and since - firstAt >= (afterWin or ServerRace.AFTER_WIN) then
		return true
	end
	for _, e in entries do
		if e.time == nil then
			return false
		end
	end
	return #entries > 0
end

-- 1 -> "1ST", 2 -> "2ND", 11 -> "11TH"
function ServerRace.ordinal(n: number): string
	local suffix = "TH"
	local tens = n % 100
	if tens < 11 or tens > 13 then
		local d = n % 10
		suffix = if d == 1 then "ST" elseif d == 2 then "ND" elseif d == 3 then "RD" else "TH"
	end
	return `{n}{suffix}`
end

-- How far round a racer is, for the live places (bigger = further ahead): `laps` done,
-- `passed` gates of this lap (the lap timer's next gate - 1), out of `gates`, and `dist` to the
-- next gate (big units).
function ServerRace.progress(laps: number, passed: number, gates: number, dist: number): number
	return laps * (gates + 1) + passed - math.clamp(dist, 0, 9999) / 10000
end

export type Run = { time: number?, progress: number }

-- Live places: finishers first by time, then the rest by how far round. place[i] for runs[i].
function ServerRace.places(runs: { Run }): { number }
	local order = {}
	for i in runs do
		table.insert(order, i)
	end
	table.sort(order, function(a: number, b: number): boolean
		local ta, tb = runs[a].time, runs[b].time
		if ta and tb then
			return ta < tb
		elseif ta or tb then
			return ta ~= nil
		elseif runs[a].progress ~= runs[b].progress then
			return runs[a].progress > runs[b].progress
		end
		return a < b
	end)
	local place = {}
	for k, i in order do
		place[i] = k
	end
	return place
end

-- Driving the wrong way? The flat velocity (vx, vz) points back, away from the way to the next
-- gate (tx, tz). Slower than `minSpeed` never counts (turning round, bumping a wall).
function ServerRace.wrongWay(
	vx: number,
	vz: number,
	tx: number,
	tz: number,
	minSpeed: number
): boolean
	local speed = math.sqrt(vx * vx + vz * vz)
	local len = math.sqrt(tx * tx + tz * tz)
	if speed < minSpeed or len < 1e-6 then
		return false
	end
	return (vx * tx + vz * tz) / (speed * len) < -0.5
end

-- The medal for a finishing place on the results ("" past 3rd).
function ServerRace.medal(place: number): string
	return if place == 1
		then "🥇"
		elseif place == 2 then "🥈"
		elseif place == 3 then "🥉"
		else ""
end

-- A drift round's order: most points first (a tie by name).
function ServerRace.rankDrift(entries: { Entry }): { Entry }
	local out = table.clone(entries)
	table.sort(out, function(a: Entry, b: Entry): boolean
		local sa, sb = a.score or 0, b.score or 0
		if sa ~= sb then
			return sa > sb
		end
		return a.name < b.name
	end)
	return out
end

-- Did this entry finish (gets finisher pay and stars)? A race: all the laps. A drift round: any
-- points at all (sitting still all round gets the try pay only).
function ServerRace.finished(e: Entry): boolean
	return e.time ~= nil or (e.score or 0) > 0
end

-- The big-map races (carter's tycoon plan, 10-26): a short wait, a map vote, a 2-3 min race.
ServerRace.MAP_BREAK = 45 -- "NEXT RACE 0:45": the wait between map races
ServerRace.VOTE = 15 -- the last this many seconds of the wait: pick a map
ServerRace.MAP_TIME_LIMIT = 180 -- a map race ends by 3 min even if nobody finished
ServerRace.BOOST_TIME = 10 * 60 -- the winner's plot makes extra coins this long

-- Car VS Car (carter 10-26, cvc-plan.md): a big race every 3 min, start to start, the maps take
-- turns (no vote). A new kid's first race starts soon after they tap JOIN.
ServerRace.CVC_EVERY = 3 * 60
ServerRace.CVC_GAP = 30 -- at least this long between a race's end and the next start
-- a first race ever: it starts this soon after the tap (+ JOIN_GRACE: 4 s; audit B8, was 15 s)
ServerRace.CVC_FIRST = 3

-- When the next big race starts: 3 min after the last one started, but never sooner than GAP
-- from now (a long race pushes the next one back a bit).
function ServerRace.nextStart(lastStart: number, now: number): number
	return math.max(lastStart + ServerRace.CVC_EVERY, now + ServerRace.CVC_GAP)
end

-- The next start, fixed the moment every league's race is over (endAt): the result card says
-- it and the race call counts down to it, so the two always agree.
function ServerRace.nextAfterRace(lastStart: number, endAt: number): number
	return ServerRace.nextStart(lastStart, endAt + ServerRace.SHOW)
end

ServerRace.GROUPS = 4 -- big races at once at most (one per league, or two for a full league)

-- Who races with whom (Car VS Car): each league on its own, at most `max` a race, in join order.
-- leagues[i] = racer i's league; returns lists of racer numbers, lowest league first. Friends in
-- the same league land in the same race (a league only splits past `max`).
-- `solo[i]` = racer i has never raced (audit B1): a first race is them and bots only, so each
-- gets a race of their own first. If that would make more than GROUPS races, the new ones share
-- the races that are left (still only new kids together).
-- `friends` = pairs of racer numbers who are Roblox friends (audit C2, MASTER-PROMPT §12.1):
-- friends always race together, in the lowest league among them (and side by side in join
-- order, so a full league splits around them). A new kid with a friend here races with them.
function ServerRace.groups(
	leagues: { number },
	max: number,
	solo: { boolean }?,
	friends: { { number } }?
): { { number } }
	-- friends' circles (a friend of a friend too): root[i] = the circle's first racer
	local root: { number } = {}
	for i in leagues do
		root[i] = i
	end
	local function find(i: number): number
		while root[i] ~= i do
			i = root[i]
		end
		return i
	end
	local paired: { [number]: boolean } = {}
	for _, pair in friends or {} do
		local a, b = pair[1], pair[2]
		if a ~= b and leagues[a] ~= nil and leagues[b] ~= nil then
			local ra, rb = find(a), find(b)
			root[math.max(ra, rb)] = math.min(ra, rb)
			paired[a], paired[b] = true, true
		end
	end
	local low: { [number]: number } = {}
	for i, lg in leagues do
		local r = find(i)
		low[r] = math.min(low[r] or lg, lg)
	end
	local byLeague: { [number]: { number } } = {}
	local order: { number } = {}
	local new: { number } = {}
	for i in leagues do
		if solo and solo[i] and not paired[i] then
			table.insert(new, i)
			continue
		end
		local lg = low[find(i)]
		if not byLeague[lg] then
			byLeague[lg] = {}
			table.insert(order, lg)
		end
		table.insert(byLeague[lg], i)
	end
	-- (a circle together: in the order its first one joined)
	for _, list in byLeague do
		local first: { [number]: number } = {}
		for n, i in list do
			first[find(i)] = first[find(i)] or n
		end
		local at: { [number]: number } = {}
		for n, i in list do
			at[i] = n
		end
		table.sort(list, function(x: number, y: number): boolean
			local fx, fy = first[find(x)], first[find(y)]
			if fx ~= fy then
				return fx < fy
			end
			return at[x] < at[y]
		end)
	end
	table.sort(order)
	local out: { { number } } = {}
	for _, lg in order do
		local cur: { number } = {}
		for _, i in byLeague[lg] do
			if #cur >= max then
				table.insert(out, cur)
				cur = {}
			end
			table.insert(cur, i)
		end
		table.insert(out, cur)
	end
	if #new > 0 then
		local races = math.max(1, math.min(#new, ServerRace.GROUPS - #out))
		local per = math.min(max, math.ceil(#new / races))
		local firsts: { { number } } = {}
		local cur: { number } = {}
		for _, i in new do
			if #cur >= per then
				table.insert(firsts, cur)
				cur = {}
			end
			table.insert(cur, i)
		end
		table.insert(firsts, cur)
		-- (first races go first: a new kid is Bronze)
		table.move(out, 1, #out, #firsts + 1, firsts)
		out = firsts
	end
	return out
end

-- Race number `n` (1, 2, 3...) is on this map: the maps in turn.
function ServerRace.mapTurn(ids: { string }, n: number): string?
	if #ids == 0 then
		return nil
	end
	return ids[((math.max(1, n) - 1) % #ids) + 1]
end

-- The voted map: the most votes (votes = player -> map id), a tie or no votes at all = a random
-- one of the best (r = a random number 0..1). nil when there are no maps.
function ServerRace.tally(votes: { [any]: string }, ids: { string }, r: number): string?
	if #ids == 0 then
		return nil
	end
	local count: { [string]: number } = {}
	for _, id in votes do
		if table.find(ids, id) then
			count[id] = (count[id] or 0) + 1
		end
	end
	local most = 0
	for _, id in ids do
		most = math.max(most, count[id] or 0)
	end
	local best = {}
	for _, id in ids do
		if (count[id] or 0) == most then
			table.insert(best, id)
		end
	end
	return best[math.clamp(math.floor(r * #best) + 1, 1, #best)]
end

-- Laps in a race: a first race (easy bots) is shorter.
function ServerRace.lapsFor(easy: boolean?): number
	return if easy then ServerRace.FIRST_LAPS else ServerRace.LAPS
end

return ServerRace
