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
}

local ServerRace = {}

ServerRace.BREAK = 5 * 60 -- the break between races (build, shop, drive your own plot)
ServerRace.CALL = 10 -- the plot is picked and named this long before the start
ServerRace.LAPS = 3
ServerRace.MAX = 8 -- cars on the grid
ServerRace.TIME_LIMIT = 240 -- seconds from GO: the race ends even if nobody finished
ServerRace.AFTER_WIN = 30 -- the others get this long to finish after the winner
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
	return "BUILD YOUR TRACK!\nRACE IN " .. ServerRace.clock(left) -- tells a new player what the break is for
end

-- Which plot the round is on: a random one of the race-ready player plots (`owned`), else a
-- random one of the rest (`spare`, the street's own race plots). r = a random number 0..1.
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
ServerRace.PAY_FINISH = 30 -- finished all the laps, 4th or later
ServerRace.PAY_TRY = 10 -- raced but didn't finish
ServerRace.PAY_OWNER = 40 -- the plot's owner: "your track was picked!"
function ServerRace.payFor(place: number, finished: boolean): number
	if not finished then
		return ServerRace.PAY_TRY
	end
	return ServerRace.PAY[place] or ServerRace.PAY_FINISH
end

-- Is the race over? (`since` = seconds from GO, `firstAt` = when the winner finished)
function ServerRace.over(entries: { Entry }, since: number, firstAt: number?): boolean
	if since >= ServerRace.TIME_LIMIT then
		return true
	end
	if firstAt and since - firstAt >= ServerRace.AFTER_WIN then
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

return ServerRace
