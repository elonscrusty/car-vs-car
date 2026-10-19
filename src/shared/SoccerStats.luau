--!strict
-- Pure car soccer bookkeeping (no Roblox calls): ball touches, goals credited to the car that last
-- touched the ball, own goals, idle time, and the sudden-death rule. Used by GroupMatch for the end
-- result (goals per player), the goal message and one log line per match. Numbers: ModesConfig.Soccer. Unit tested.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local Modes = sibling("Modes")

local SoccerStats = {}

export type Stats = {
	touches: { [number]: number },
	goals: { [number]: number },
	ownGoals: { [number]: number },
	pads: { [number]: number },
	idle: { [number]: number }, -- total seconds below the idle speed
	idleRun: { [number]: number }, -- the current idle stretch
	idleMax: { [number]: number }, -- longest idle stretch
	touchedAt: { [number]: number },
	lastTouch: number, -- car that touched the ball last (0 = nobody since the last goal)
}

function SoccerStats.new(): Stats
	return {
		touches = {},
		goals = {},
		ownGoals = {},
		pads = {},
		idle = {},
		idleRun = {},
		idleMax = {},
		touchedAt = {},
		lastTouch = 0,
	}
end

local function bump(t: { [number]: number }, i: number, by: number)
	t[i] = (t[i] or 0) + by
end

-- Car `i` is at the ball. Always the last toucher; counts as a new touch only after `cooldown`.
function SoccerStats.touch(s: Stats, i: number, now: number, cooldown: number): boolean
	s.lastTouch = i
	local before = s.touchedAt[i]
	s.touchedAt[i] = now
	if before ~= nil and now - before < cooldown then
		return false
	end
	bump(s.touches, i, 1)
	return true
end

-- Is a car (flat+height offset dx, dy, dz from the ball middle) touching the ball?
-- `ballRadius` + the car's half length + `slack`.
function SoccerStats.isTouching(
	dx: number,
	dy: number,
	dz: number,
	ballRadius: number,
	carHalf: number,
	slack: number
): boolean
	local reach = ballRadius + carHalf + slack
	return dx * dx + dy * dy + dz * dz <= reach * reach
end

-- A goal. `conceded` = the team whose goal the ball went into. Returns (credited, own):
-- credited = the car whose goal count went up (0 = nobody touched the ball, or it was an own goal);
-- own = the car that put it into its own goal (0 = not an own goal). Own goals never credit anyone.
function SoccerStats.goal(s: Stats, conceded: number, teamSize: number): (number, number)
	local t = s.lastTouch
	s.lastTouch = 0
	if t == 0 then
		return 0, 0
	end
	if Modes.teamOf(t, teamSize) == conceded then
		bump(s.ownGoals, t, 1)
		return 0, t
	end
	bump(s.goals, t, 1)
	return t, 0
end

-- Text for the goal pop-up. `viewerTeam` sees it; `scorerTeam` = the team that got the point.
function SoccerStats.goalText(viewerTeam: number, scorerTeam: number, ownGoal: boolean): string
	if ownGoal then
		return if viewerTeam == scorerTeam then "GOAL! (OWN GOAL)" else "OWN GOAL!"
	end
	return if viewerTeam == scorerTeam then "GOAL!" else "THEY SCORED!"
end

-- Car `i` picked up a boost pad.
function SoccerStats.pad(s: Stats, i: number)
	bump(s.pads, i, 1)
end

-- One frame of a car: slower than `idleSpeed` adds to its idle time (stats only, no behaviour).
function SoccerStats.idleStep(s: Stats, i: number, speed: number, dt: number, idleSpeed: number)
	if speed < idleSpeed then
		local run = (s.idleRun[i] or 0) + dt
		s.idleRun[i] = run
		bump(s.idle, i, dt)
		if run > (s.idleMax[i] or 0) then
			s.idleMax[i] = run
		end
	else
		s.idleRun[i] = 0
	end
end

-- Coins a car earns for its goals, on top of the normal reward. Never negative.
function SoccerStats.goalBonus(goals: number, coinsPerGoal: number): number
	return math.max(0, math.floor(goals)) * math.max(0, coinsPerGoal)
end

-- Sudden death: the match is still 0-0 once `at` seconds are played (0 or less = never).
function SoccerStats.suddenDeathNow(
	goals1: number,
	goals2: number,
	elapsed: number,
	at: number,
	already: boolean
): boolean
	return not already and at > 0 and elapsed >= at and goals1 == 0 and goals2 == 0
end

-- One log line: "#1H g1 o0 t12 p2 idle3.2/1.1 | #4B ..." (H = human, B = bot).
function SoccerStats.summary(s: Stats, humans: { boolean }, cars: number): string
	local parts: { string } = {}
	for i = 1, cars do
		table.insert(
			parts,
			string.format(
				"#%d%s g%d o%d t%d p%d idle%.1f/%.1f",
				i,
				if humans[i] then "H" else "B",
				s.goals[i] or 0,
				s.ownGoals[i] or 0,
				s.touches[i] or 0,
				s.pads[i] or 0,
				s.idle[i] or 0,
				s.idleMax[i] or 0
			)
		)
	end
	return "[soccer-stats] " .. table.concat(parts, " | ")
end

return SoccerStats
