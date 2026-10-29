--!strict
-- The arena bots' brain (Smash, MASTER-PLAN phase 1): where a bot kart drives, how fast, and when
-- it fires. Pure (no Roblox), so Lune tests and the bot sim (LOOPTEST) run it as is; the server
-- (ArenaBots) moves the real karts by the pose it returns and fires through WeaponServer.
--
-- A bot with no weapon drives to the nearest "?" box (or rams a kart that's right there: bumps
-- hurt); with one it picks a target and closes in,
-- fires only when the target is in range, in front and in sight, after a short "saw you" delay,
-- and with a little aim error (both shrink with skill). It backs up and turns away when stuck.
-- Fair to a new kid: at most one bot hunts each player at a time (TOKENS), and on an easy match
-- bots would rather fight each other and aim worse at players.
--
-- Plan coordinates are the arena's (map-local big units, 0,0 at the middle; ArenaData). yaw is Roblox's: forward is
-- (-sin yaw, -cos yaw), so the server's pose is CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0).

local ArenaBrain = {}

ArenaBrain.TOP_SPEED = 65 -- big units/s (a player's top is 95), before skill and easy
ArenaBrain.ACCEL = 60 -- big units/s²
ArenaBrain.TURN = 2.6 -- rad/s at full lock
ArenaBrain.RADIUS = 3 -- a kart's size, for bumping into things
ArenaBrain.THINK = 0.2 -- s between decisions (5 Hz); moving runs every step
-- A rookie (a player's first 3 matches, MatchRunner): bots chase them less, see them later, wait
-- longer between shots and hold some shots on purpose, so a new kid gets their smashes in.
-- `calm`: s from the match start that bots leave a rookie alone (ArenaBots: they see them
-- shielded). After it, some chaos: a rookie should be smashed now and then (Lead: 1-3 a match),
-- but once they've been smashed `most` times bots leave them be.
ArenaBrain.ROOKIE =
	{ matches = 3, chase = 1.8, react = 1.2, gap = 1.2, spare = 0.15, calm = 30, most = 2 }
-- The weapons' aim help (Weapons.ROCKET seekDeg / seekRange, in big units): a shot locks onto the
-- nearest kart within this cone, so a bot shooting past a rookie would hit the rookie.
ArenaBrain.LOCK = { deg = 35, range = 110 }
-- A rookie with a shot to fire gets a target: one easy bot (the feeder) cruises slowly across
-- the ground ahead of them, weaving, and doesn't shoot. `ahead`/`side`: big units in front of
-- the rookie and the weave either side; `speed`: throttle; `gap`: s after a feeder is smashed
-- (or let go) before the next one comes; `upTo`: only while the rookie has fewer smashes. Bots also leave a rookie's kill (a kart a rookie just
-- hurt, Match.ROOKIE_HIT) and the box a rookie is going for.
ArenaBrain.FEED = { ahead = 55, side = 25, speed = 0.45, gap = 6, upTo = 4 }
-- Each boom's splash in big units (Weapons' splash studs / its SCALE): no shot whose boom would
-- catch a rookie.
ArenaBrain.SPLASH = { Rockets = 11, Nuke = 44 } :: { [string]: number }
-- An easy match (a rookie is in it): every bot is a bit slower to shoot and to drive, at anyone,
-- so the rookie's smashes count for more of the board.
ArenaBrain.EASY = { gap = 0.8, react = 0.3, speed = 0.8 }
ArenaBrain.LINE_UP = 0.7 -- armed and this far into the weapon's range: slow down to aim
ArenaBrain.SAW_KEEP = 0.6 -- s a target can slip out of a fair shot and still count as seen
ArenaBrain.TOKENS = 1 -- bots allowed to hunt the same player at once
ArenaBrain.FIRE_GAP = 0.6 -- s between a bot's shots (WeaponServer has the real cooldown)
ArenaBrain.STUCK_CHECK = 0.5 -- s: how often progress is checked
ArenaBrain.STUCK_MOVE = 1.5 -- big units: less than this in a check while driving = no progress
ArenaBrain.BACK_TIME = 0.8 -- s of backing up once stuck
ArenaBrain.ORBIT_MOVE = 5 -- big units: less than this in 2 s while driving = going round in loops
ArenaBrain.FREE_AFTER = 2.5 -- s without progress: lift the kart clear (never stuck 3 s)
ArenaBrain.RAM = 22 -- big units: with no weapon, a kart this close gets rammed (bumps hurt, carter 10-28)

-- How each weapon is used: range, the cone (radians either side of the nose) the target must
-- be in, and whether it drops behind (mine).
export type Use = { range: number, cone: number, behind: boolean? }
ArenaBrain.USE = {
	Rockets = { range = 90, cone = 0.7 },
	Gun = { range = 45, cone = 0.45 },
	Mine = { range = 30, cone = 0.8, behind = true },
} :: { [string]: Use }
local DEFAULT_USE: Use = { range = 60, cone = 0.45 }
ArenaBrain.MINE_HOLD = 5 -- s: a mine nobody chased over gets dropped anyway (by a box: karts come by)

-- Any random source with :NextNumber() (Roblox's Random, or ArenaBrain.rng in Lune, which has none).
export type Rng = { NextNumber: (any) -> number }

-- A small seeded random source (same numbers every run for a seed).
function ArenaBrain.rng(seed: number): Rng
	local state = math.floor(math.abs(seed)) % 2147483647
	if state == 0 then
		state = 1
	end
	return {
		NextNumber = function(_self: any): number
			state = (state * 48271) % 2147483647
			return state / 2147483647
		end,
	}
end

export type Solid = { x: number, z: number, r: number } -- a round thing karts can't drive through
export type Target = {
	id: number,
	x: number,
	z: number,
	alive: boolean,
	shield: boolean?,
	human: boolean?,
	rookie: boolean?, -- a player in their first ROOKIE.matches matches: bots go easy on them
	rookieHit: boolean?, -- a rookie just hurt it: bots leave the kill to them
	fx: number?, -- a rookie's facing (FEED)
	fz: number?,
	armed: boolean?, -- a rookie holds a shot (FEED)
	smashes: number?, -- this round's
	deaths: number?,
}
-- A rookie's feeder (FEED): the bot on it, and when the next may come.
export type Feed = { bot: number?, nextAt: number }
-- A place walled all round but at its doors: a hill (cliff sides, its door is the ramp) or the
-- sand (bumper wall, its doors are the gaps). To get in or out a bot drives through a door, from
-- its `out` spot to its `inn` spot (or back). poly in arena units.
export type Door = { out: { x: number, z: number }, inn: { x: number, z: number } }
export type Zone = { poly: { { number } }, doors: { Door } }
export type World = {
	half: number, -- the arena is a square, -half..half on x and z (inside the walls)
	solids: { Solid },
	zones: { Zone }?,
	boxes: { { x: number, z: number } }, -- live "?" boxes
	karts: { Target }, -- everyone in the match, bots too
	feed: { [number]: Feed }?, -- by rookie id (ArenaBrain.feeders)
	-- (filled by ArenaBrain.near: solids by grid cell, so a check only looks at the ones close by)
	grid: { [number]: { Solid } }?,
	gridOf: { Solid }?,
	gridPad: number?,
	scratch: { Solid }?,
}
export type Opts = { skill: number?, easy: boolean? }
export type Bot = {
	id: number,
	x: number,
	z: number,
	yaw: number,
	speed: number,
	skill: number, -- 0 (new-kid easy) .. 1 (sharp)
	easy: boolean,
	rng: Rng,
	-- decisions
	think: number, -- next decision time
	goalX: number,
	goalZ: number,
	throttle: number,
	target: number?, -- kart id being hunted
	sawAt: number, -- when the target came into a fair shot
	fairAt: number, -- the last time it had a fair shot (a blink out of the cone keeps sawAt)
	fireAt: number, -- next time it may fire
	armedSince: number, -- when it got the weapon it holds (math.huge = none)
	weapon: string?, -- the one it held at its last decision
	feeding: number?, -- the rookie it's a target for (FEED)
	-- stuck
	checkAt: number,
	checkX: number,
	checkZ: number,
	stuckFor: number,
	lostFor: number, -- s of stuck or looping since it last got anywhere
	trail: { { x: number, z: number } }, -- where it was at each check, the last 2 s
	backUntil: number,
	backSteer: number,
	detour: { x: number, z: number, untilT: number }?,
}
export type Step = { x: number, z: number, yaw: number, fire: { x: number, z: number }? }

local function clamp(v: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, v))
end

-- angle from a to b, wrapped to -pi..pi
local function wrap(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

local function yawTo(dx: number, dz: number): number
	return math.atan2(-dx, -dz)
end

function ArenaBrain.forward(yaw: number): (number, number)
	return -math.sin(yaw), -math.cos(yaw)
end

function ArenaBrain.new(id: number, x: number, z: number, yaw: number, opts: Opts?, rng: Rng?): Bot
	local o = opts or {}
	local r = rng or ArenaBrain.rng(id * 7919 + 17)
	return {
		id = id,
		x = x,
		z = z,
		yaw = yaw,
		speed = 0,
		skill = clamp(o.skill or 0.5, 0, 1),
		easy = o.easy == true,
		rng = r,
		think = 0,
		goalX = x,
		goalZ = z,
		throttle = 0,
		target = nil,
		sawAt = math.huge,
		fairAt = -math.huge,
		fireAt = 0,
		armedSince = math.huge,
		checkAt = 0,
		checkX = x,
		checkZ = z,
		stuckFor = 0,
		lostFor = 0,
		trail = {},
		weapon = nil,
		backUntil = 0,
		backSteer = 1,
		detour = nil,
	}
end

local CELL = 16 -- big units: the solids' grid
local function cellKey(cx: number, cz: number): number
	return (cx + 512) * 1024 + (cz + 512)
end

-- The solids that may touch the box x0..x1, z0..z1 (a reused list: use it before the next call).
-- The grid is built on first use and again whenever world.solids is a new table.
function ArenaBrain.near(world: World, x0: number, z0: number, x1: number, z1: number): { Solid }
	if world.gridOf ~= world.solids or not world.grid then
		local grid: { [number]: { Solid } } = {}
		local pad = 0
		for _, sol in world.solids do
			local key = cellKey(math.floor(sol.x / CELL), math.floor(sol.z / CELL))
			local list = grid[key]
			if not list then
				list = {}
				grid[key] = list
			end
			table.insert(list, sol)
			pad = math.max(pad, sol.r)
		end
		world.grid, world.gridOf, world.gridPad = grid, world.solids, pad + ArenaBrain.RADIUS + 3 -- (wantYaw looks this far to the side)
	end
	local grid = world.grid :: { [number]: { Solid } }
	local pad = world.gridPad :: number
	local out = world.scratch or {}
	world.scratch = out
	table.clear(out)
	for cx = math.floor((math.min(x0, x1) - pad) / CELL), math.floor((math.max(x0, x1) + pad) / CELL) do
		for cz = math.floor((math.min(z0, z1) - pad) / CELL), math.floor((math.max(z0, z1) + pad) / CELL) do
			local list = grid[cellKey(cx, cz)]
			if list then
				table.move(list, 1, #list, #out + 1, out)
			end
		end
	end
	return out
end

-- Is a kart at (x, z) inside a wall or a solid?
function ArenaBrain.blocked(world: World, x: number, z: number): boolean
	local lim = world.half - ArenaBrain.RADIUS
	if math.abs(x) > lim or math.abs(z) > lim then
		return true
	end
	for _, s in ArenaBrain.near(world, x, z, x, z) do
		local dx, dz = x - s.x, z - s.z
		local rr = s.r + ArenaBrain.RADIUS
		if dx * dx + dz * dz < rr * rr then
			return true
		end
	end
	return false
end

-- Nothing solid between a and b (rockets and bullets fly flat over the floor).
function ArenaBrain.sight(world: World, ax: number, az: number, bx: number, bz: number): boolean
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	for _, s in ArenaBrain.near(world, ax, az, bx, bz) do
		local t = if len2 > 0 then clamp(((s.x - ax) * dx + (s.z - az) * dz) / len2, 0, 1) else 0
		local px, pz = ax + dx * t - s.x, az + dz * t - s.z
		if px * px + pz * pz < s.r * s.r then
			return false
		end
	end
	return true
end

local function kartById(world: World, id: number?): Target?
	if id == nil then
		return nil
	end
	for _, k in world.karts do
		if k.id == id then
			return k
		end
	end
	return nil
end

-- Hunters per kart id among `bots` (for TOKENS).
function ArenaBrain.hunters(bots: { Bot }): { [number]: number }
	local out: { [number]: number } = {}
	for _, b in bots do
		if b.target then
			out[b.target] = (out[b.target] or 0) + 1
		end
	end
	return out
end

-- Left alone: a kart a rookie just hurt (their kill), and a rookie smashed ROOKIE.most times.
local function spared(k: Target): boolean
	return k.rookieHit == true or (k.rookie == true and (k.deaths or 0) >= ArenaBrain.ROOKIE.most)
end

-- Pick and keep each armed rookie's feeder (FEED): the nearest easy bot that isn't one yet.
-- A rookie with nothing to fire, or smashed, lets theirs go; a smashed feeder (gone from `bots`)
-- is replaced FEED.gap s later. Call once a frame, before stepping the bots.
function ArenaBrain.feeders(bots: { Bot }, world: World, now: number)
	local feed = world.feed or {}
	world.feed = feed
	local byId: { [number]: Bot } = {}
	for _, b in bots do
		byId[b.id] = b
	end
	local seen: { [number]: boolean } = {}
	for _, k in world.karts do
		if k.rookie then
			seen[k.id] = true
			local f = feed[k.id] or { bot = nil, nextAt = now + ArenaBrain.FEED.gap }
			feed[k.id] = f
			local cur = f.bot and byId[f.bot]
			if cur and cur.feeding ~= k.id then
				cur = nil -- (back from a smash: a new bot)
			end
			if f.bot and not cur then
				f.bot, f.nextAt = nil, now + ArenaBrain.FEED.gap -- (smashed)
			end
			if not (k.alive and k.armed and (k.smashes or 0) < ArenaBrain.FEED.upTo) then
				if cur then
					cur.feeding = nil
					f.bot, f.nextAt = nil, math.max(f.nextAt, now + ArenaBrain.FEED.gap * 0.5)
				end
			elseif not f.bot and now >= f.nextAt then
				local best, bestD = nil, math.huge
				for _, b in bots do
					if b.easy and not b.feeding then
						local d = (b.x - k.x) ^ 2 + (b.z - k.z) ^ 2
						if d < bestD then
							best, bestD = b, d
						end
					end
				end
				if best then
					best.feeding, f.bot = k.id, best.id
					best.think = 0
				end
			end
		end
	end
	-- (a rookie who left: let their feeder go)
	for id in feed do
		if not seen[id] then
			feed[id] = nil
		end
	end
	for _, b in bots do
		if b.feeding and not (feed[b.feeding] and feed[b.feeding].bot == b.id) then
			b.feeding = nil
		end
	end
end

-- Who to hunt: the nearest fair target. Players already hunted by TOKENS bots are left alone;
-- on an easy match players count as farther away, so bots mostly fight each other.
local function pickTarget(bot: Bot, world: World, hunters: { [number]: number }): Target?
	local best: Target? = nil
	local bestScore = math.huge
	for _, k in world.karts do
		if k.id ~= bot.id and k.alive and not k.shield and not spared(k) then
			local busy = k.human
				and k.id ~= bot.target
				and (hunters[k.id] or 0) >= ArenaBrain.TOKENS
			if not busy then
				local d = math.sqrt((k.x - bot.x) ^ 2 + (k.z - bot.z) ^ 2)
				local score = d
					* (
						if k.rookie
							then ArenaBrain.ROOKIE.chase
							elseif k.human and bot.easy then 1.8
							else 1
					)
				if k.id == bot.target then
					score *= 0.7 -- stick with the one you're after
				end
				if score < bestScore then
					best, bestScore = k, score
				end
			end
		end
	end
	return best
end

-- The box nearest each rookie with nothing to fire (but `me`): theirs (bots leave it).
local function rookieBoxes(world: World, me: number): { [any]: boolean }
	local out = {}
	for _, k in world.karts do
		if k.rookie and k.alive and not k.armed and k.id ~= me then
			local best, bestD = nil, math.huge
			for _, b in world.boxes do
				local d = (b.x - k.x) ^ 2 + (b.z - k.z) ^ 2
				if d < bestD then
					best, bestD = b, d
				end
			end
			if best then
				out[best] = true
			end
		end
	end
	return out
end

local function nearestBox(bot: Bot, world: World): { x: number, z: number }?
	local best, bestD = nil, math.huge
	local fx, fz = ArenaBrain.forward(bot.yaw)
	local theirs = rookieBoxes(world, bot.id)
	for _, b in world.boxes do
		if theirs[b] and #world.boxes > 1 then
			continue
		end
		local dx, dz = b.x - bot.x, b.z - bot.z
		local d = math.sqrt(dx * dx + dz * dz)
		-- a box behind costs a turn: count it a bit farther
		local ahead = if d > 0 then (dx * fx + dz * fz) / d else 1
		local cost = d * (1.25 - 0.25 * ahead)
		if cost < bestD then
			best, bestD = b, cost
		end
	end
	return best
end

local function inPoly(poly: { { number } }, x: number, z: number): boolean
	local inside = false
	local j = #poly
	for i = 1, #poly do
		local a, b = poly[i], poly[j]
		if (a[2] > z) ~= (b[2] > z) then
			if x < (b[1] - a[1]) * (z - a[2]) / (b[2] - a[2]) + a[1] then
				inside = not inside
			end
		end
		j = i
	end
	return inside
end
ArenaBrain.inPoly = inPoly

-- The way to (gx, gz): straight, or through a door when the goal is in a zone and the bot isn't
-- (or the other way round). Near the door or in it: along its line; else to its near side.
function ArenaBrain.via(
	world: World,
	x: number,
	z: number,
	gx: number,
	gz: number
): (number, number)
	for _, zone in world.zones or {} do
		local gIn, bIn = inPoly(zone.poly, gx, gz), inPoly(zone.poly, x, z)
		if gIn ~= bIn then
			local bestA, bestB, bestD = nil, nil, math.huge
			for _, door in zone.doors do
				local a, b = door.out, door.inn
				if bIn then
					a, b = door.inn, door.out
				end
				local d = math.sqrt((a.x - x) ^ 2 + (a.z - z) ^ 2)
					+ math.sqrt((b.x - gx) ^ 2 + (b.z - gz) ^ 2)
				if d < bestD then
					bestA, bestB, bestD = a, b, d
				end
			end
			if not bestA or not bestB then
				return gx, gz
			end
			local a, b = bestA, bestB
			local ax, az = b.x - a.x, b.z - a.z
			local len2 = math.max(ax * ax + az * az, 1e-6)
			local u = ((x - a.x) * ax + (z - a.z) * az) / len2
			local off = math.abs((x - a.x) * az - (z - a.z) * ax) / math.sqrt(len2)
			local near = (x - a.x) ^ 2 + (z - a.z) ^ 2 < 144
			if near or (u > -0.2 and u < 1 and off < 10) then
				-- follow the door's line: a point on it a bit ahead pulls the kart onto it
				local k = math.min(math.max(u, 0) + 0.4, 1)
				return a.x + ax * k, a.z + az * k
			end
			return a.x, a.z
		end
	end
	return gx, gz
end

-- The decision (5 Hz): where to go, how hard, who to hunt.
local function decide(
	bot: Bot,
	world: World,
	now: number,
	weapon: string?,
	ammo: number,
	hunters: { [number]: number }
)
	local armed = weapon ~= nil and ammo > 0
	if not armed then
		bot.armedSince = math.huge
	elseif bot.armedSince == math.huge or weapon ~= bot.weapon then
		bot.armedSince = now
	end
	bot.weapon = if armed then weapon else nil
	local fed = bot.feeding and kartById(world, bot.feeding)
	if fed and fed.alive then
		-- a target for a rookie: cruise across the ground ahead of them, weaving (FEED)
		if bot.target then
			hunters[bot.target] = math.max((hunters[bot.target] or 1) - 1, 0)
			bot.target, bot.sawAt = nil, math.huge
		end
		local F = ArenaBrain.FEED
		local fx, fz = fed.fx or 0, fed.fz or -1
		local weave = math.sin(now * 0.9 + bot.id) * F.side
		bot.goalX = fed.x + fx * F.ahead - fz * weave
		bot.goalZ = fed.z + fz * F.ahead + fx * weave
		bot.throttle = F.speed
		bot.detour = nil
		return
	end
	local target = pickTarget(bot, world, hunters)
	-- no weapon: bumps hurt too, so ram one that's close, else go and get a box
	if
		target
		and not armed
		and (target.x - bot.x) ^ 2 + (target.z - bot.z) ^ 2 > ArenaBrain.RAM ^ 2
	then
		target = nil
	end
	if (target and target.id) ~= bot.target then
		-- keep the count right for the bots deciding after this one in the same frame (TOKENS)
		if bot.target then
			hunters[bot.target] = math.max((hunters[bot.target] or 1) - 1, 0)
		end
		if target then
			hunters[target.id] = (hunters[target.id] or 0) + 1
		end
		bot.target = target and target.id
		bot.sawAt = math.huge
	end
	if bot.detour and now < bot.detour.untilT then
		bot.goalX, bot.goalZ, bot.throttle = bot.detour.x, bot.detour.z, 1
		return
	end
	bot.detour = nil
	if target then
		local use = ArenaBrain.USE[weapon :: string] or DEFAULT_USE
		local dx, dz = target.x - bot.x, target.z - bot.z
		local d = math.sqrt(dx * dx + dz * dz)
		bot.throttle = 1
		if d < 10 and not armed then
			-- bumper to bumper: drive on through and come round again, don't sit on it
			local fx, fz = ArenaBrain.forward(bot.yaw)
			bot.goalX, bot.goalZ = bot.x + fx * 30, bot.z + fz * 30
		elseif not armed then
			bot.goalX, bot.goalZ = target.x, target.z
		elseif use.behind then
			-- a mine: drive away from the target so it chases over the drop
			bot.goalX, bot.goalZ = bot.x - dx, bot.z - dz
		else
			-- in range: ease off and line up the shot, don't fly past and circle it
			bot.goalX, bot.goalZ = target.x, target.z
			if d < use.range * ArenaBrain.LINE_UP then
				bot.throttle = 0.5
			end
		end
		return
	end
	local box = nearestBox(bot, world)
	if box then
		bot.goalX, bot.goalZ, bot.throttle = box.x, box.z, 1
	else
		-- nothing to grab: cruise round the middle
		local a = now * 0.3 + bot.id
		bot.goalX, bot.goalZ, bot.throttle =
			math.cos(a) * world.half * 0.4, math.sin(a) * world.half * 0.4, 0.7
	end
end

-- Is a rookie inside the weapons' lock-on cone along (dx, dz), nearer than the target `d` away?
local function rookieInLock(bot: Bot, world: World, dx: number, dz: number, d: number): boolean
	local n = math.max(d, 1e-3)
	local ux, uz = dx / n, dz / n
	local cosMax = math.cos(math.rad(ArenaBrain.LOCK.deg))
	for _, k in world.karts do
		if k.rookie and k.alive and not k.shield and k.id ~= bot.id then
			local ox, oz = k.x - bot.x, k.z - bot.z
			local kd = math.sqrt(ox * ox + oz * oz)
			if kd > 1e-3 and kd < math.min(ArenaBrain.LOCK.range, d + 6) then
				if (ox * ux + oz * uz) / kd >= cosMax then
					return true
				end
			end
		end
	end
	return false
end

ArenaBrain.rookieInLock = rookieInLock

-- A shot, if the target is a fair one right now.
local function aimAt(
	bot: Bot,
	world: World,
	now: number,
	weapon: string?,
	ammo: number
): { x: number, z: number }?
	if weapon == nil or ammo <= 0 or now < bot.fireAt or bot.feeding then
		return nil
	end
	local use = ArenaBrain.USE[weapon] or DEFAULT_USE
	if use.behind then
		-- a mine: drop it when anyone is close behind, or after holding it a while
		local bx, bz = ArenaBrain.forward(bot.yaw)
		local leave = false -- a rookie the bots leave alone is close behind: hold it
		local chaser = false
		for _, k in world.karts do
			if k.id ~= bot.id and k.alive then
				local dx, dz = k.x - bot.x, k.z - bot.z
				local d = math.sqrt(dx * dx + dz * dz)
				if d <= use.range and d > 0 and -(dx * bx + dz * bz) / d >= math.cos(use.cone) then
					if k.rookie and (k.shield or spared(k)) then
						leave = true
					else
						chaser = true
					end
				end
			end
		end
		if leave then
			return nil
		end
		if chaser then
			bot.fireAt = now + ArenaBrain.FIRE_GAP + (if bot.easy then ArenaBrain.EASY.gap else 0)
			return { x = bot.x, z = bot.z }
		end
		if now - bot.armedSince >= ArenaBrain.MINE_HOLD then
			bot.fireAt = now + ArenaBrain.FIRE_GAP + (if bot.easy then ArenaBrain.EASY.gap else 0)
			return { x = bot.x, z = bot.z }
		end
		return nil
	end
	local target = kartById(world, bot.target)
	if not target or not target.alive or target.shield or spared(target) then
		return nil
	end
	local dx, dz = target.x - bot.x, target.z - bot.z
	local d = math.sqrt(dx * dx + dz * dz)
	-- (point blank counts as in front: bumper to bumper the angle means nothing)
	local off = if d < 8 then 0 else math.abs(wrap(yawTo(dx, dz) - bot.yaw))
	local fair = d <= use.range
		and off <= use.cone
		and ArenaBrain.sight(world, bot.x, bot.z, target.x, target.z)
	if not fair then
		if now - bot.fairAt > ArenaBrain.SAW_KEEP then
			bot.sawAt = math.huge
		end
		return nil
	end
	bot.fairAt = now
	if bot.sawAt == math.huge then
		bot.sawAt = now
	end
	-- the "saw you" delay: slower for easy bots and when the target is a player
	local react = 1.1
		- 0.65 * bot.skill
		+ (
			if target.rookie
				then ArenaBrain.ROOKIE.react
				elseif target.human and bot.easy then 0.6 + ArenaBrain.EASY.react
				elseif bot.easy then ArenaBrain.EASY.react
				else 0
		)
	if now - bot.sawAt < react then
		return nil
	end
	bot.fireAt = now
		+ ArenaBrain.FIRE_GAP
		+ (if target.rookie then ArenaBrain.ROOKIE.gap else 0)
		+ (if bot.easy then ArenaBrain.EASY.gap else 0)
	-- (the weapons' aim help locks a shot onto the nearest kart in its cone, so a shot sent wide
	-- would still find a rookie: a bot spares one by holding the shot instead. The rest still
	-- go: a rookie is hit less often, not never)
	if target.rookie and bot.rng:NextNumber() < ArenaBrain.ROOKIE.spare then
		return nil
	end
	local miss = (1 - bot.skill) * 6 + (if target.human and bot.easy then 4 else 0)
	local a = bot.rng:NextNumber() * 2 * math.pi
	local m = bot.rng:NextNumber() * miss
	local shot = { x = target.x + math.cos(a) * m, z = target.z + math.sin(a) * m }
	if not target.rookie then
		-- the way the shot really goes (miss and all), and the boom where it lands
		local sx, sz = shot.x - bot.x, shot.z - bot.z
		local sd = math.sqrt(sx * sx + sz * sz)
		if rookieInLock(bot, world, sx, sz, sd) then
			return nil -- it would lock onto the rookie in front of the target
		end
		local splash = ArenaBrain.SPLASH[weapon :: string] or 0
		for _, k in world.karts do
			if
				k.rookie
				and k.alive
				and (k.x - shot.x) ^ 2 + (k.z - shot.z) ^ 2 < splash * splash
			then
				return nil -- the boom would catch the rookie
			end
		end
	end
	return shot
end

-- Steering: toward the goal, bending away from a solid just ahead.
local function wantYaw(bot: Bot, world: World): number
	local dx, dz = bot.goalX - bot.x, bot.goalZ - bot.z
	local fx, fz = ArenaBrain.forward(bot.yaw)
	-- (nothing past the goal matters: don't shy off it for a wall behind it)
	local look = math.min(10 + bot.speed * 0.35, math.sqrt(dx * dx + dz * dz) + 2)
	local sx, sz = 0, 0
	local ex, ez = bot.x + fx * look, bot.z + fz * look
	for _, s in ArenaBrain.near(world, bot.x, bot.z, ex, ez) do
		local ox, oz = s.x - bot.x, s.z - bot.z
		local along = ox * fx + oz * fz
		if along > 0 and along < look + s.r then
			local side = ox * -fz + oz * fx -- + = the solid is on the right
			local clear = s.r + ArenaBrain.RADIUS + 2
			if math.abs(side) < clear then
				local push = (clear - math.abs(side)) / clear * (1 - along / (look + s.r))
				local dir = if side >= 0 then -1 else 1
				sx += -fz * dir * push * 6
				sz += fx * dir * push * 6
			end
		end
	end
	-- the walls push back in too
	local lim = world.half - 12
	if bot.x + fx * look > lim then
		sx -= 1
	elseif bot.x + fx * look < -lim then
		sx += 1
	end
	if bot.z + fz * look > lim then
		sz -= 1
	elseif bot.z + fz * look < -lim then
		sz += 1
	end
	local d = math.sqrt(dx * dx + dz * dz)
	if d > 0 then
		dx, dz = dx / d, dz / d
	end
	return yawTo(dx + sx, dz + sz)
end

-- Out of a solid or a wall, to the nearest free spot round it (the last-resort unstick).
local function free(bot: Bot, world: World)
	for ring = 1, 8 do
		for k = 0, 11 do
			local a = k * math.pi / 6
			local x, z = bot.x + math.cos(a) * ring * 3, bot.z + math.sin(a) * ring * 3
			if not ArenaBrain.blocked(world, x, z) then
				bot.x, bot.z = x, z
				bot.yaw = yawTo(-bot.x, -bot.z) -- face the middle
				return
			end
		end
	end
end

-- One tick: decide (every THINK s), move, maybe fire. `weapon`/`ammo` are the kart's now;
-- `hunters` is ArenaBrain.hunters(all bots) (TOKENS), or nil for none.
function ArenaBrain.step(
	bot: Bot,
	world: World,
	dt: number,
	now: number,
	weapon: string?,
	ammo: number?,
	hunters: { [number]: number }?
): Step
	local n = ammo or 0
	if now >= bot.think then
		decide(bot, world, now, weapon, n, hunters or {})
		local lim = world.half - 14
		bot.goalX, bot.goalZ = clamp(bot.goalX, -lim, lim), clamp(bot.goalZ, -lim, lim)
		bot.goalX, bot.goalZ = ArenaBrain.via(world, bot.x, bot.z, bot.goalX, bot.goalZ)
		bot.think = now + ArenaBrain.THINK
	end
	local top = ArenaBrain.TOP_SPEED
		* (0.8 + 0.2 * bot.skill)
		* (if bot.easy then ArenaBrain.EASY.speed else 1)
	local backing = now < bot.backUntil
	local want: number
	if backing then
		bot.yaw = wrap(bot.yaw + bot.backSteer * ArenaBrain.TURN * dt)
		want = -top * 0.5
	else
		local turn = wrap(wantYaw(bot, world) - bot.yaw)
		local step = ArenaBrain.TURN * dt
		bot.yaw = wrap(bot.yaw + clamp(turn, -step, step))
		-- ease off in a tight turn so it doesn't run wide, and crawl round when the goal is
		-- inside the turning circle (else it would loop round it forever)
		local gd = math.sqrt((bot.goalX - bot.x) ^ 2 + (bot.goalZ - bot.z) ^ 2)
		local circle = math.max(bot.speed, 10) / ArenaBrain.TURN
		local ease = if math.abs(turn) > 0.8 and gd < circle * 2
			then 0.15
			elseif math.abs(turn) > 1.2 then 0.45
			else 1
		want = top * bot.throttle * ease
	end
	local acc = ArenaBrain.ACCEL * dt
	bot.speed += clamp(want - bot.speed, -acc * 2, acc)
	local fx, fz = ArenaBrain.forward(bot.yaw)
	local nx, nz = bot.x + fx * bot.speed * dt, bot.z + fz * bot.speed * dt
	if not ArenaBrain.blocked(world, nx, nz) then
		bot.x, bot.z = nx, nz
	elseif not ArenaBrain.blocked(world, nx, bot.z) then
		-- scrape along whatever it hit, a bit slower
		bot.x, bot.speed = nx, bot.speed * 0.9
	elseif not ArenaBrain.blocked(world, bot.x, nz) then
		bot.z, bot.speed = nz, bot.speed * 0.9
	else
		bot.speed = 0
	end

	-- stuck: no progress while trying to drive. Short check: nose on something (1 s). Long check:
	-- going round in little loops (under ORBIT_MOVE in 2 s). Either way: back up and go round by a
	-- point off to the side; still stuck after FREE_AFTER: lift it clear.
	if now >= bot.checkAt then
		local moved = math.sqrt((bot.x - bot.checkX) ^ 2 + (bot.z - bot.checkZ) ^ 2)
		-- (lining up a shot at half throttle still counts: it moves faster than STUCK_MOVE)
		local trying = bot.throttle > 0.4 and not backing
		if moved < ArenaBrain.STUCK_MOVE and trying then
			bot.stuckFor += ArenaBrain.STUCK_CHECK
		else
			bot.stuckFor = 0
		end
		bot.checkAt, bot.checkX, bot.checkZ = now + ArenaBrain.STUCK_CHECK, bot.x, bot.z
		table.insert(bot.trail, { x = bot.x, z = bot.z })
		if #bot.trail > 5 then
			table.remove(bot.trail, 1)
		end
		local old = bot.trail[1]
		local looping = trying
			and #bot.trail == 5
			and (bot.x - old.x) ^ 2 + (bot.z - old.z) ^ 2 < ArenaBrain.ORBIT_MOVE ^ 2
		if bot.stuckFor >= 1 or looping then
			bot.lostFor += ArenaBrain.STUCK_CHECK
		elseif moved >= ArenaBrain.STUCK_MOVE * 2 then
			bot.lostFor = 0
		end
		if bot.lostFor >= ArenaBrain.FREE_AFTER or ArenaBrain.blocked(world, bot.x, bot.z) then
			free(bot, world)
			bot.stuckFor, bot.lostFor, bot.backUntil, bot.speed = 0, 0, 0, 0
			table.clear(bot.trail)
		elseif (bot.stuckFor >= 1 or looping) and not backing then
			bot.backSteer = if bot.rng:NextNumber() < 0.5 then -1 else 1
			bot.backUntil = now + ArenaBrain.BACK_TIME
			local sx, sz = -fz * bot.backSteer, fx * bot.backSteer
			local lim = world.half - 14
			local dx = clamp(bot.x + sx * 25 - fx * 10, -lim, lim)
			local dz = clamp(bot.z + sz * 25 - fz * 10, -lim, lim)
			bot.detour = { x = dx, z = dz, untilT = now + ArenaBrain.BACK_TIME + 1.5 }
			bot.think = 0
			bot.stuckFor = 0
			table.clear(bot.trail)
		end
	end

	local fire = if backing then nil else aimAt(bot, world, now, weapon, n)
	return { x = bot.x, z = bot.z, yaw = bot.yaw, fire = fire }
end

-- ===== the real arena (shared/ArenaData, passed in so this file stays pure) =====

-- The bots' view of the arena, in its map-local big units: the walls, trees, cover walls, the
-- sand's bumper wall (open at its gaps) and the hills' cliffs (open where the ramp tops in), and
-- each hill as a zone reached by its ramp.
function ArenaBrain.fromArena(A: any): World
	local K = A.K
	local solids: { Solid } = {}
	local function at(p: { number }): (number, number)
		return A.at(p)
	end
	-- a line of small circles from a to b (picture points), thickness w (picture units), except
	-- where skip(x, z) (arena units) says there's a way through
	local function line(
		a: { number },
		b: { number },
		w: number,
		skip: ((number, number) -> boolean)?
	)
		local ax, az = at(a)
		local bx, bz = at(b)
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local r = math.max(w * K / 2, 1.5)
		local n = math.max(1, math.ceil(len / r))
		for k = 0, n do
			local x, z = ax + (bx - ax) * k / n, az + (bz - az) * k / n
			if not (skip and skip(x, z)) then
				table.insert(solids, { x = x, z = z, r = r })
			end
		end
	end
	for _, t in A.TREES do
		local x, z = at(t)
		table.insert(solids, { x = x, z = z, r = 2 * K }) -- the stick (the candy top is up high)
	end
	for _, c in A.COVER do
		line(c[1], c[2], A.COVER_W)
	end
	local zones: { Zone } = {}
	-- the sand's bumper wall, open at its gaps (each gap a door in and out)
	local sand = A.SAND
	local sandPoly, sandDoors = {}, {}
	local cx, cz = 0, 0
	for _, p in sand do
		local x, z = at(p)
		table.insert(sandPoly, { x, z })
		cx, cz = cx + x / #sand, cz + z / #sand
	end
	for i = 1, #sand do
		local a, b = sand[i], sand[i % #sand + 1]
		local gaps = {}
		for _, g in A.SAND_GAPS do
			if g[1] == i then
				table.insert(gaps, g)
			end
		end
		local ax, az = at(a)
		local bx, bz = at(b)
		local len2 = (bx - ax) ^ 2 + (bz - az) ^ 2
		line(a, b, A.BUMPER_W, function(x: number, z: number): boolean
			local along = ((x - ax) * (bx - ax) + (z - az) * (bz - az)) / len2
			for _, g in gaps do
				if along >= g[2] - 0.02 and along <= g[3] + 0.02 then
					return true
				end
			end
			return false
		end)
		for _, g in gaps do
			local u = (g[2] + g[3]) / 2
			local mx, mz = ax + (bx - ax) * u, az + (bz - az) * u
			local ex, ez = bx - ax, bz - az
			local el = math.sqrt(ex * ex + ez * ez)
			local nx, nz = -ez / el, ex / el -- square to the wall; turned to point in
			if (cx - mx) * nx + (cz - mz) * nz < 0 then
				nx, nz = -nx, -nz
			end
			table.insert(sandDoors, {
				out = { x = mx - nx * 10, z = mz - nz * 10 },
				inn = { x = mx + nx * 10, z = mz + nz * 10 },
			})
		end
	end
	if #sandDoors > 0 then
		table.insert(zones, { poly = sandPoly, doors = sandDoors })
	end
	-- hills: cliffs all round but where the ramp comes in
	for _, h in A.HILLS do
		local ramp = nil
		for _, r in A.RAMPS do
			if A.inside(h.poly, r.to) then
				ramp = r
			end
		end
		local poly = {}
		for _, p in h.poly do
			local x, z = at(p)
			table.insert(poly, { x, z })
		end
		local tx, tz, fx, fz, half = 0, 0, 0, 0, 0
		if ramp then
			tx, tz = at(ramp.to)
			fx, fz = at(ramp.from)
			half = ramp.width * K / 2 + 3
		end
		for i = 1, #h.poly do
			line(h.poly[i], h.poly[i % #h.poly + 1], 2, function(x: number, z: number): boolean
				return ramp ~= nil and (x - tx) ^ 2 + (z - tz) ^ 2 < half * half
			end)
		end
		if ramp then
			-- the way up: from a bit out past the foot to a bit in past the top
			local dx, dz = tx - fx, tz - fz
			local d = math.sqrt(dx * dx + dz * dz)
			table.insert(zones, {
				poly = poly,
				doors = {
					{
						out = { x = fx - dx / d * 10, z = fz - dz / d * 10 },
						inn = { x = tx + dx / d * 10, z = tz + dz / d * 10 },
					},
				},
			})
		end
	end
	return {
		half = (A.PIC / 2 - A.WALL) * K,
		solids = solids,
		zones = zones,
		boxes = {},
		karts = {},
	}
end

-- Picture point of an arena spot (for ArenaData.groundAt).
function ArenaBrain.toPic(A: any, x: number, z: number): { number }
	return { x / A.K + A.PIC / 2, z / A.K + A.PIC / 2 }
end

return ArenaBrain
