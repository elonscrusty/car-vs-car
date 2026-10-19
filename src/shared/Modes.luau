--!strict
-- Pure rules for the fight modes (no Roblox calls): the rotation, king of the hill scoring,
-- last-car-standing eliminations, car soccer goals and teams, start spots. Numbers: ModesConfig.
-- The server (Match, GroupMatch) only moves the cars and reads these answers. Unit tested.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local ModesConfig = sibling("ModesConfig")

local Modes = {}

export type Vec = { x: number, z: number }
export type Spot = { x: number, z: number, yaw: number } -- yaw: the way the car faces (radians)

-- Is `name` one of the modes?
function Modes.isMode(name: any): boolean
	return type(name) == "string" and ModesConfig.Names[name] ~= nil
end

-- The mode for the `counter`-th match (0, 1, 2 ...): goes round the list in order.
function Modes.pick(counter: number): string
	local order = ModesConfig.Order
	local n = math.max(0, math.floor(counter))
	return order[n % #order + 1]
end

-- Player's own mode choice: "auto" (rotation) or one of the launch modes.
function Modes.isPick(v: any): boolean
	return v == "auto" or (type(v) == "string" and table.find(ModesConfig.Order, v) ~= nil)
end

-- The tap order of the lobby MODE button: AUTO -> each mode -> AUTO.
function Modes.nextPick(current: string?): string
	local order = ModesConfig.Order
	if current == nil or not Modes.isPick(current) then
		return "auto"
	end
	if current == "auto" then
		return order[1]
	end
	local at = table.find(order, current) or #order
	return order[at + 1] or "auto"
end

-- The mode for a match: the first player who chose a real mode decides, else the rotation.
function Modes.choose(picks: { any }, counter: number): string
	for _, p in picks do
		if p ~= "auto" and Modes.isPick(p) then
			return p
		end
	end
	return Modes.pick(counter)
end

-- Modes played by many cars in GroupMatch (the others are a 1v1 in Match).
function Modes.isGroup(name: string): boolean
	return name == "lastStanding" or name == "soccer" or name == "tag" or name == "race"
end

-- How many cars the mode needs (2 for the 1v1 modes).
function Modes.carCount(name: string): number
	if name == "lastStanding" then
		return ModesConfig.LastStanding.cars
	elseif name == "soccer" then
		return ModesConfig.Soccer.teamSize * 2
	elseif name == "tag" then
		return ModesConfig.Tag.cars
	elseif name == "race" then
		return ModesConfig.Race.cars
	end
	return 2
end

-- Spots on a ring, car i at angle i/count of a turn, every car facing the middle.
function Modes.ringSpots(count: number, radius: number): { Spot }
	local out: { Spot } = {}
	for i = 0, count - 1 do
		local a = i / count * math.pi * 2
		local x, z = math.cos(a) * radius, math.sin(a) * radius
		table.insert(out, { x = x, z = z, yaw = math.atan2(x, z) })
	end
	return out
end

-- Angle the middle of a team's goal sits at (team 1 defends the -X side, team 2 the +X side).
function Modes.goalAngle(team: number): number
	return if team == 1 then math.pi else 0
end

-- Wrap an angle difference into -pi..pi.
local function wrap(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

----------------------------------------------------------------------------------------------
-- King of the hill

export type Hill = { scores: { number }, holder: number }

function Modes.hillNew(cars: number): Hill
	local scores: { number } = {}
	for i = 1, cars do
		scores[i] = 0
	end
	return { scores = scores, holder = 0 }
end

-- Is a car (flat position, relative to the middle) on the circle?
function Modes.onHill(x: number, z: number, radius: number): boolean
	return x * x + z * z <= radius * radius
end

-- One frame. `onHill[i]` = car i is alive and on the circle. Exactly one car there = it scores
-- `dt`; two or more = contested, nobody scores. Returns the car that scored (0 = none).
function Modes.hillStep(h: Hill, onHill: { boolean }, dt: number): number
	local only = 0
	for i = 1, #h.scores do
		if onHill[i] then
			if only ~= 0 then
				h.holder = 0
				return 0
			end
			only = i
		end
	end
	h.holder = only
	if only ~= 0 then
		h.scores[only] += dt
	end
	return only
end

-- The car that has held the circle long enough (0 = nobody yet).
function Modes.hillWinner(h: Hill, holdSeconds: number): number
	for i, s in h.scores do
		if s >= holdSeconds then
			return i
		end
	end
	return 0
end

-- Highest score (0 = nobody scored, or a tie for the top).
function Modes.hillLeader(h: Hill): number
	local best, who, tie = 0, 0, false
	for i, s in h.scores do
		if s > best then
			best, who, tie = s, i, false
		elseif s == best and s > 0 then
			tie = true
		end
	end
	return if tie then 0 else who
end

----------------------------------------------------------------------------------------------
-- Ice

-- Friction and grip when the bowl is ice: the lower of the two, grip scaled down.
function Modes.iceFriction(normal: number, ice: number): number
	return math.min(normal, ice)
end

function Modes.iceGrip(scale: number, iceScale: number): number
	return scale * iceScale
end

----------------------------------------------------------------------------------------------
-- Last car standing

export type Last = { alive: { boolean }, out: { number } } -- `out` = car numbers in the order they fell

function Modes.lastNew(cars: number): Last
	local alive: { boolean } = {}
	for i = 1, cars do
		alive[i] = true
	end
	return { alive = alive, out = {} }
end

-- Car `i` is out. Returns false if it was already out (or not a car).
function Modes.lastEliminate(l: Last, i: number): boolean
	if l.alive[i] ~= true then
		return false
	end
	l.alive[i] = false
	table.insert(l.out, i)
	return true
end

function Modes.lastAliveCount(l: Last): number
	local n = 0
	for _, a in l.alive do
		if a then
			n += 1
		end
	end
	return n
end

-- The winner: the one car left. 0 while 2+ are alive, -1 if everyone is out (a draw).
function Modes.lastWinner(l: Last): number
	local n, who = 0, 0
	for i, a in l.alive do
		if a then
			n += 1
			who = i
		end
	end
	if n == 1 then
		return who
	elseif n == 0 then
		return -1
	end
	return 0
end

-- Time up: the alive car with the most HP wins (0 on a tie for the top).
function Modes.lastTimeoutWinner(l: Last, hp: { number }): number
	local best, who, tie = -1, 0, false
	for i, a in l.alive do
		if a then
			local h = hp[i] or 0
			if h > best then
				best, who, tie = h, i, false
			elseif h == best then
				tie = true
			end
		end
	end
	return if tie then 0 else who
end

-- Place of car `i` (1 = winner). Cars that fell later place higher.
function Modes.lastPlace(l: Last, i: number): number
	if l.alive[i] then
		return 1
	end
	local alive = Modes.lastAliveCount(l)
	local pos = table.find(l.out, i)
	if pos == nil then
		return #l.alive
	end
	-- the last to fall is just behind the survivors
	return alive + (#l.out - pos) + 1
end

----------------------------------------------------------------------------------------------
-- Car tag (hot potato): one car is IT with a fuse. Bump another car to pass IT on. IT at 0 =
-- that car blows up (out). Each new round has a shorter fuse. Last car left wins.

export type Tag = { it: number, fuse: number, round: number, immuneUntil: { [number]: number } }

-- Fuse length for round `round` (1, 2, 3 ...): starts long, shrinks each round, never below min.
function Modes.tagFuse(round: number, start: number, step: number, minimum: number): number
	return math.max(minimum, start - step * (math.max(1, round) - 1))
end

function Modes.tagNew(it: number, fuse: number): Tag
	return { it = it, fuse = fuse, round = 1, immuneUntil = {} }
end

-- Car `from` (IT) bumped car `to`. Passes IT if `from` is IT and `to` is not just-passed-from.
-- The old IT cannot be tagged back for `immuneSeconds`. Returns whether IT changed hands.
function Modes.tagPass(
	t: Tag,
	from: number,
	to: number,
	now: number,
	immuneSeconds: number
): boolean
	if t.it ~= from or to == from then
		return false
	end
	if now < (t.immuneUntil[to] or -math.huge) then
		return false
	end
	t.it = to
	t.immuneUntil[from] = now + immuneSeconds
	return true
end

-- One frame of the fuse. Returns true when it just ran out (the IT car blows up).
function Modes.tagTick(t: Tag, dt: number): boolean
	t.fuse -= dt
	return t.fuse <= 0
end

-- Next IT after a blow-up: one of the alive cars, picked by `r` in 0..1 (0 = none alive).
function Modes.tagNextIt(l: Last, r: number): number
	local alive: { number } = {}
	for i, a in l.alive do
		if a then
			table.insert(alive, i)
		end
	end
	if #alive == 0 then
		return 0
	end
	return alive[math.min(#alive, math.floor(math.clamp(r, 0, 0.9999) * #alive) + 1)]
end

-- A new round: new IT, shorter fuse, nobody immune.
function Modes.tagNextRound(t: Tag, it: number, fuse: number)
	t.it = it
	t.fuse = fuse
	t.round += 1
	table.clear(t.immuneUntil)
end

-- Angle (radians, + = target on the left) from facing (fx, fz) to the direction (dx, dz).
function Modes.signedAngle(fx: number, fz: number, dx: number, dz: number): number
	return math.atan2(fz * dx - fx * dz, fx * dx + fz * dz)
end

-- Where a car running away from IT drives: straight away, bent toward the middle the closer it
-- is to a wall (so it does not pin itself in a corner). Flat x, z; field half sizes hx, hz.
function Modes.tagFleeDir(
	x: number,
	z: number,
	itX: number,
	itZ: number,
	hx: number,
	hz: number
): Vec
	local ax, az = x - itX, z - itZ
	local len = math.sqrt(ax * ax + az * az)
	if len < 0.01 then
		ax, az, len = 1, 0, 1
	end
	ax, az = ax / len, az / len
	local edge = math.max(math.abs(x) / hx, math.abs(z) / hz)
	local k = math.clamp(edge - 0.4, 0, 1) * 2.5
	local cx, cz = -x, -z
	local cl = math.sqrt(cx * cx + cz * cz)
	if cl > 0.01 then
		ax, az = ax + cx / cl * k, az + cz / cl * k
	end
	local l2 = math.sqrt(ax * ax + az * az)
	return { x = ax / l2, z = az / l2 }
end

----------------------------------------------------------------------------------------------
-- Car soccer

export type Soccer = { goals: { number }, last: number } -- goals per team; last = team that scored last

-- Team (1 or 2) of car `i`: the first `teamSize` cars are team 1.
function Modes.teamOf(i: number, teamSize: number): number
	return if i <= teamSize then 1 else 2
end

function Modes.soccerNew(): Soccer
	return { goals = { 0, 0 }, last = 0 }
end

-- Where the ball is (relative flat x, z): the team that CONCEDED (1 or 2), or 0 for no goal.
function Modes.goalConceded(x: number, z: number, goalRadius: number, halfAngle: number): number
	if x * x + z * z < goalRadius * goalRadius then
		return 0
	end
	local a = math.atan2(z, x)
	for team = 1, 2 do
		if math.abs(wrap(a - Modes.goalAngle(team))) <= halfAngle then
			return team
		end
	end
	return 0
end

-- A goal for the team that did NOT concede. Returns the scoring team.
function Modes.soccerGoal(s: Soccer, conceded: number): number
	local scorer = 3 - conceded
	s.goals[scorer] += 1
	s.last = scorer
	return scorer
end

-- The team with `toWin` goals (0 = none yet).
function Modes.soccerWinner(s: Soccer, toWin: number): number
	for team = 1, 2 do
		if s.goals[team] >= toWin then
			return team
		end
	end
	return 0
end

-- Time up: more goals wins; a tie is 0 (play on: the next goal wins).
function Modes.soccerTimeoutWinner(s: Soccer): number
	if s.goals[1] == s.goals[2] then
		return 0
	end
	return if s.goals[1] > s.goals[2] then 1 else 2
end

-- Ball lost: past the rim (plus margin) or fallen out of the bowl.
function Modes.ballLost(x: number, z: number, rim: number, margin: number): boolean
	return x * x + z * z > (rim + margin) ^ 2
end

-- Start spots: each team in a row around its own goal, facing the middle.
function Modes.soccerSpots(teamSize: number, radius: number, spread: number): { Spot }
	local out: { Spot } = {}
	for team = 1, 2 do
		for k = 1, teamSize do
			local a = Modes.goalAngle(team) + (k - (teamSize + 1) / 2) * spread
			local x, z = math.cos(a) * radius, math.sin(a) * radius
			table.insert(out, { x = x, z = z, yaw = math.atan2(x, z) })
		end
	end
	return out
end

-- Where a bot should drive: a point behind the ball, on the far side from the goal it attacks
-- (`attack` = the team it plays for; it attacks the OTHER team's goal). Relative flat x, z.
function Modes.botTarget(ballX: number, ballZ: number, attack: number, offset: number): Vec
	local a = Modes.goalAngle(3 - attack)
	local gx, gz = math.cos(a), math.sin(a)
	return { x = ballX - gx * offset, z = ballZ - gz * offset }
end

-- Who each bot hunts in last-car-standing: the nearest alive car that is not itself (0 = none).
function Modes.nearestAlive(l: Last, xs: { number }, zs: { number }, me: number): number
	local best, who = math.huge, 0
	for i, a in l.alive do
		if a and i ~= me then
			local d = (xs[i] - xs[me]) ^ 2 + (zs[i] - zs[me]) ^ 2
			if d < best then
				best, who = d, i
			end
		end
	end
	return who
end

-- Number of humans' cars + bots needed: how many bots to add to `humans` to reach the mode's cars.
function Modes.botsNeeded(mode: string, humans: number): number
	return math.max(0, Modes.carCount(mode) - humans)
end

return Modes
