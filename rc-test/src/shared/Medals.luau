--!strict
-- Bronze / silver / gold targets for each kind of plot (carter's stars loop, phase 1).
-- Race = one lap's time and rocks = the climb's time (lower wins); drift = the points of one slide
-- (higher wins). Medal = stars: bronze 1, silver 2, gold 3.
-- First guesses, not timed yet: race from the loop (~1230 studs at top speed 95), rocks from the
-- Rock plot thread (trail ~349 RC studs at ~4/s), drift from the Drift plot thread (gold = most
-- of a lap in one linked slide). The server prints every run ("[Stars] race 0:18.3 ..."): tune
-- from those.

export type Target = {
	kind: string, -- "time" (lower wins) or "score" (higher wins)
	bronze: number,
	silver: number,
	gold: number,
	limit: number, -- faster (time) or bigger (score) than this can't be real: thrown out
}

local Medals = {}

Medals.NAMES = { "BRONZE", "SILVER", "GOLD" }

Medals.TARGETS = {
	race = { kind = "time", bronze = 26, silver = 20, gold = 17, limit = 8 },
	rock = { kind = "time", bronze = 210, silver = 150, gold = 110, limit = 40 },
	drift = { kind = "score", bronze = 500, silver = 1500, gold = 4000, limit = 100000 },
} :: { [string]: Target }

-- `scale` stretches the time targets for a track of another length (a built track: see
-- Medals.loopScale). nil or 1 = the plot's own targets.
function Medals.target(mode: string, scale: number?): Target?
	local t = Medals.TARGETS[mode]
	if t == nil or scale == nil or scale == 1 or t.kind ~= "time" then
		return t
	end
	return {
		kind = t.kind,
		bronze = t.bronze * scale,
		silver = t.silver * scale,
		gold = t.gold * scale,
		limit = t.limit * scale,
	}
end

-- How long a loop is (gates in order, back to the first), flat distance.
function Medals.loopLength(gates: { { x: number, z: number } }): number
	local n = #gates
	local len = 0
	for i = 1, n do
		local a, b = gates[i], gates[(i % n) + 1]
		len += math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
	end
	return len
end

-- A built track's time targets next to the race plot's: its loop length over the race plot's
-- (clamped, so a broken track can't give silly targets).
Medals.MIN_SCALE = 0.3
Medals.MAX_SCALE = 3
function Medals.loopScale(
	gates: { { x: number, z: number } },
	raceGates: { { x: number, z: number } }
): number
	local ref = Medals.loopLength(raceGates)
	if #gates < 2 or ref <= 0 then
		return 1
	end
	return math.clamp(Medals.loopLength(gates) / ref, Medals.MIN_SCALE, Medals.MAX_SCALE)
end

-- A run worth looking at: a real number, not too good to be true.
function Medals.valid(mode: string, value: number, scale: number?): boolean
	local t = Medals.target(mode, scale)
	if t == nil or value ~= value or value <= 0 or value == math.huge then
		return false
	end
	if t.kind == "time" then
		return value >= t.limit
	end
	return value <= t.limit
end

local function reaches(t: Target, value: number, goal: number): boolean
	if t.kind == "time" then
		return value <= goal
	end
	return value >= goal
end

-- 0 = no medal, 1 = bronze, 2 = silver, 3 = gold.
function Medals.medal(mode: string, value: number, scale: number?): number
	local t = Medals.target(mode, scale)
	if t == nil or not Medals.valid(mode, value, scale) then
		return 0
	end
	if reaches(t, value, t.gold) then
		return 3
	elseif reaches(t, value, t.silver) then
		return 2
	elseif reaches(t, value, t.bronze) then
		return 1
	end
	return 0
end

-- Is `value` a better run than `old` (nil = no run yet)?
function Medals.better(mode: string, value: number, old: number?, scale: number?): boolean
	local t = Medals.target(mode, scale)
	if t == nil or not Medals.valid(mode, value, scale) then
		return false
	end
	if old == nil then
		return true
	end
	if t.kind == "time" then
		return value < old
	end
	return value > old
end

-- "0:41.2" for times, "1520" for drift points.
function Medals.format(mode: string, value: number): string
	local t = Medals.TARGETS[mode]
	if t and t.kind == "score" then
		return tostring(math.floor(value))
	end
	local s = math.max(value, 0)
	local m = math.floor(s / 60)
	return string.format("%d:%04.1f", m, s - m * 60)
end

-- The next medal to go for when you already have `have` (0..3): its number and the value to
-- reach. nil when you have gold.
function Medals.nextGoal(mode: string, have: number, scale: number?): (number?, number?)
	local t = Medals.target(mode, scale)
	if t == nil or have >= 3 then
		return nil, nil
	end
	local m = math.max(math.floor(have), 0) + 1
	return m, if m == 1 then t.bronze elseif m == 2 then t.silver else t.gold
end

-- A plot's board: the best run of each player, best first, at most TOP rows.
export type Run = { value: number, name: string, userId: number }
Medals.TOP = 3

-- Put `run` on the board `list` (changed in place) if it is that player's best. Returns the
-- place it got (1..TOP), or nil when it is not on the board (or not better than their own row).
function Medals.addTop(mode: string, list: { Run }, run: Run, scale: number?): number?
	if not Medals.valid(mode, run.value, scale) then
		return nil
	end
	for i, r in list do
		if r.userId == run.userId then
			if not Medals.better(mode, run.value, r.value, scale) then
				return nil
			end
			table.remove(list, i)
			break
		end
	end
	local at = #list + 1
	for i, r in list do
		if Medals.better(mode, run.value, r.value, scale) then
			at = i
			break
		end
	end
	table.insert(list, at, { value = run.value, name = run.name, userId = run.userId })
	while #list > Medals.TOP do
		table.remove(list)
	end
	return if at <= Medals.TOP then at else nil
end

return Medals
