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

function Medals.target(mode: string): Target?
	return Medals.TARGETS[mode]
end

-- A run worth looking at: a real number, not too good to be true.
function Medals.valid(mode: string, value: number): boolean
	local t = Medals.TARGETS[mode]
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
function Medals.medal(mode: string, value: number): number
	local t = Medals.TARGETS[mode]
	if t == nil or not Medals.valid(mode, value) then
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
function Medals.better(mode: string, value: number, old: number?): boolean
	local t = Medals.TARGETS[mode]
	if t == nil or not Medals.valid(mode, value) then
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

return Medals
