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

return ServerRace
