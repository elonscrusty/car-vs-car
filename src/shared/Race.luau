--!strict
-- Crazy Race rules (no Roblox calls): checkpoints, laps, finishing, positions.
-- Every car must pass the waypoints in order; passing waypoint 1 again after the last one
-- finishes a lap. First car to finish the last lap wins. Unit tested.

local Race = {}

export type Car = {
	next: number, -- the waypoint it must reach next (starts at 2)
	lap: number, -- 1 .. laps
	passed: number, -- waypoints passed in total (progress)
	finishedAt: number?, -- seconds, once it has crossed the line on the last lap
}

export type State = { cars: { Car }, laps: number, count: number, order: { number } }

function Race.new(cars: number, laps: number, waypoints: number): State
	local list: { Car } = {}
	for i = 1, cars do
		list[i] = { next = 2, lap = 1, passed = 0, finishedAt = nil }
	end
	return { cars = list, laps = laps, count = waypoints, order = {} }
end

-- Car `i` is at flat (x, z); `tx, tz` is the waypoint it must reach, `radius` how close counts.
-- Returns true when it just passed a waypoint. Finishing sets finishedAt and adds it to `order`.
function Race.reach(
	s: State,
	i: number,
	x: number,
	z: number,
	tx: number,
	tz: number,
	radius: number,
	now: number
): boolean
	local c = s.cars[i]
	if c == nil or c.finishedAt ~= nil then
		return false
	end
	if (x - tx) ^ 2 + (z - tz) ^ 2 > radius * radius then
		return false
	end
	c.passed += 1
	if c.next == 1 then
		-- The line, after the last waypoint: a lap is done.
		if c.lap >= s.laps then
			c.finishedAt = now
			table.insert(s.order, i)
		else
			c.lap += 1
		end
	end
	c.next = c.next % s.count + 1
	return true
end

-- The waypoint car `i` last passed (it goes back there after a fall). 1 at the start.
function Race.lastPassed(s: State, i: number): number
	local c = s.cars[i]
	return (c.next - 2) % s.count + 1
end

-- Positions 1..n. `toNext[i]` = studs from car i to its next waypoint. Finished cars first (in
-- order), then most waypoints passed, then closest to the next one.
function Race.positions(s: State, toNext: { number }): { number }
	local ids: { number } = {}
	for i = 1, #s.cars do
		ids[i] = i
	end
	local function rank(i: number): number
		local c = s.cars[i]
		if c.finishedAt ~= nil then
			return 1e9 - (table.find(s.order, i) or 0)
		end
		return c.passed * 10000 - (toNext[i] or 0)
	end
	table.sort(ids, function(a, b)
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then
			return ra > rb
		end
		return a < b
	end)
	local pos: { number } = {}
	for place, id in ids do
		pos[id] = place
	end
	return pos
end

-- Time up: the car in 1st place (0 if nobody has any progress).
function Race.leader(s: State, toNext: { number }): number
	local pos = Race.positions(s, toNext)
	for i, p in pos do
		if p == 1 then
			return if s.cars[i].passed > 0 or s.cars[i].finishedAt ~= nil then i else 0
		end
	end
	return 0
end

----------------------------------------------------------------------------------------------
-- Progress (stuck cars), checkpoint messages, placing rewards

export type Progress = { passed: number, best: number, since: number }

function Race.progressNew(now: number): Progress
	return { passed = 0, best = math.huge, since = now }
end

-- One frame. Progress = a new gate passed, or `minGain` studs closer to the next gate than ever
-- since the last progress. Returns the seconds without progress.
function Race.progressStep(
	p: Progress,
	passed: number,
	toNext: number,
	now: number,
	minGain: number
): number
	if passed ~= p.passed or toNext < p.best - minGain then
		p.passed = passed
		p.best = toNext
		p.since = now
	end
	return now - p.since
end

-- Put a car back at its last gate (auto): bots after `botSeconds`, humans after `humanSeconds`.
function Race.shouldReset(
	noProgress: number,
	isHuman: boolean,
	botSeconds: number,
	humanSeconds: number
): boolean
	return noProgress >= (if isHuman then humanSeconds else botSeconds)
end

-- The RESET button works once a car has made no progress for `minStuck` seconds, and not twice
-- within `cooldown` seconds (the client may ask any time; the server decides).
function Race.canManualReset(
	noProgress: number,
	sinceLastReset: number,
	minStuck: number,
	cooldown: number
): boolean
	return noProgress >= minStuck and sinceLastReset >= cooldown
end

-- The flash after passing waypoint `wp` (1 = the line). Gates are 2..count, shown as 1..count-1.
function Race.checkpointText(wp: number, count: number, lap: number, laps: number): string
	if wp == 1 then
		return string.format("LAP %d/%d", math.min(lap, laps), laps)
	end
	return string.format("CHECKPOINT %d/%d", wp - 1, count - 1)
end

-- Coins for a finishing place: the table value, but never less than `base` (the normal reward
-- already paid). Returns the EXTRA coins on top of `base`.
function Race.placeBonus(place: number, coinsByPlace: { number }, base: number): number
	local want = coinsByPlace[place] or coinsByPlace[#coinsByPlace] or base
	return math.max(0, want - base)
end

function Race.ordinal(n: number): string
	if n == 1 then
		return "1st"
	elseif n == 2 then
		return "2nd"
	elseif n == 3 then
		return "3rd"
	end
	return tostring(n) .. "th"
end

return Race
