--!strict
-- Car VS Car SMASH weapons (plans/smash): the list of weapons, the fire gate (ammo, cooldown, a
-- rate limit on the fire remote), aim checks, and the rocket's flight. The server decides every
-- hit (server/WeaponServer, server/weapons/*); clients only ask to fire and draw what the server
-- says. Plain math with the built-in `vector` (a Vector3 in Roblox), so Lune tests run it too.
-- Each weapon adds itself here: DEFS[name] (server/weapons/<name>.luau does the firing).

local Weapons = {}

Weapons.REMOTE = "WeaponFire" -- client -> server: FireServer(aim: Vector3?)
Weapons.FX_REMOTE = "WeaponFx" -- server -> clients: FireAllClients(kind, ...) for drawing only

export type Def = {
	ammo: number, -- shots per pickup
	cooldown: number, -- seconds between shots
	word: string, -- on the FIRE button
	icon: string,
}

Weapons.DEFS = {
	Rockets = { ammo = 3, cooldown = 0.6, word = "ROCKETS", icon = "rocket" },
	Nuke = { ammo = 1, cooldown = 1, word = "NUKE", icon = "nuke" },
	-- GUNMINE row (server/weapons/Gun, Mine, Freeze keep the same numbers; a test checks)
	Gun = { ammo = 4, cooldown = 0.5, word = "GUN", icon = "gun" },
	Mine = { ammo = 3, cooldown = 0.6, word = "MINES", icon = "mine" },
	Freeze = { ammo = 2, cooldown = 0.8, word = "FREEZE", icon = "freeze" },
} :: { [string]: Def }
-- the order boxes and screens list them in (GUNMINE adds Gun, Mine, Freeze)
Weapons.NAMES = { "Rockets", "Nuke", "Gun", "Mine", "Freeze" }

-- aim: at most this far (degrees) from where the kart faces; more is turned back to the edge
Weapons.MAX_AIM_DEG = 30
-- the fire remote: a bucket of asks (a burst of 6, refilled 8 a second); more are dropped
Weapons.BURST = 6
Weapons.REFILL = 8

function Weapons.isName(x: any): boolean
	return type(x) == "string" and Weapons.DEFS[x] ~= nil
end

function Weapons.get(name: any): Def?
	return if Weapons.isName(name) then Weapons.DEFS[name] else nil
end

-- The word MatchRunner's smash words use ("smashed by X's rocket"): lowercase, one of a kind.
Weapons.FEED = {
	Rockets = "rocket",
	Nuke = "nuke",
	Gun = "machine gun",
	Mine = "mine",
	Freeze = "freeze ray",
} :: { [string]: string }
function Weapons.feedWord(name: string): string
	return Weapons.FEED[name] or string.lower(name)
end

local function finite(n: number): boolean
	return n == n and n > -math.huge and n < math.huge
end

-- A Vector3 as the built-in vector (the same thing in Roblox; Lune's pretend Roblox has its own
-- Vector3 type). Anything else: nil.
function Weapons.vec(x: any): Vector3?
	if type(x) == "vector" then
		return x
	end
	if typeof(x) == "Vector3" then
		return vector.create(x.X, x.Y, x.Z)
	end
	return nil
end

local function flat(v: Vector3): Vector3?
	local f = vector.create(v.x, 0, v.z)
	local m = vector.magnitude(f)
	if not finite(m) or m < 1e-4 then
		return nil
	end
	return f / m
end

-- The direction a shot goes: `raw` (anything a client sent) flattened and kept within
-- MAX_AIM_DEG of `facing`; junk (not a vector, NaN, zero) means straight ahead.
function Weapons.aim(raw: any, facing: Vector3): Vector3
	local f = Weapons.vec(facing)
	local ahead = f and flat(f) or vector.create(0, 0, -1)
	local v = Weapons.vec(raw)
	if not v then
		return ahead
	end
	if not (finite(v.x) and finite(v.y) and finite(v.z)) then
		return ahead
	end
	local want = flat(v)
	if not want then
		return ahead
	end
	local maxRad = math.rad(Weapons.MAX_AIM_DEG)
	local cosA = math.clamp(vector.dot(ahead, want), -1, 1)
	if math.acos(cosA) <= maxRad then
		return want
	end
	-- turn `ahead` toward `want` by exactly the limit (around the up axis)
	local side = if ahead.x * want.z - ahead.z * want.x >= 0 then 1 else -1
	local a = maxRad * side
	local c, s = math.cos(a), math.sin(a)
	return vector.create(ahead.x * c - ahead.z * s, 0, ahead.x * s + ahead.z * c)
end

-- ===== what one kart holds =====

export type Held = { name: string, ammo: number, readyAt: number }

function Weapons.held(): Held
	return { name = "", ammo = 0, readyAt = 0 }
end

-- A pickup: the new weapon replaces the old one, full ammo. False for a name that isn't a weapon.
function Weapons.give(h: Held, name: any): boolean
	if not Weapons.isName(name) then
		return false
	end
	h.name = name
	h.ammo = Weapons.DEFS[name].ammo
	h.readyAt = 0
	return true
end

-- Take one shot if the kart has ammo and the cooldown is over; returns the weapon's name. The
-- last shot empties the hands.
function Weapons.take(h: Held, now: number): string?
	local def = Weapons.DEFS[h.name]
	if not def or h.ammo <= 0 or now < h.readyAt then
		return nil
	end
	local name = h.name
	h.ammo -= 1
	h.readyAt = now + def.cooldown
	if h.ammo <= 0 then
		h.name = ""
		h.ammo = 0
	end
	return name
end

-- ===== the fire remote's rate limit (one bucket per player) =====

export type Bucket = { tokens: number, at: number }

function Weapons.bucket(now: number): Bucket
	return { tokens = Weapons.BURST, at = now }
end

function Weapons.allow(b: Bucket, now: number): boolean
	local dt = math.max(0, now - b.at)
	b.at = math.max(b.at, now)
	b.tokens = math.min(Weapons.BURST, b.tokens + dt * Weapons.REFILL)
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

-- ===== flying weapons (rockets, nuke): fly, bend a little toward a kart ahead, boom on a hit =====

-- ===== sizes: the arena is RC-scale (FINISH-JOBS SCALE rule) =====
-- Every distance below is in kart lengths (KART studs): a kart is 5.5 big units long, shrunk to RC
-- size by TrackData.RC_SCALE (about 1.4 studs). The arena is about 65 karts wall to wall, and a
-- kart's top speed in the arena (Tuning.topSpeed 95 big units/s at Match.SPEED_SCALE 0.8) is about
-- 14 karts a second.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent:WaitForChild(name))
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

Weapons.SCALE = sibling("TrackData").RC_SCALE :: number
Weapons.KART = 5.5 * Weapons.SCALE

export type Flight = {
	speed: number, -- studs a second
	life: number, -- seconds, then it blows up where it is
	seekDeg: number, -- only karts within this cone ahead are chased (0 = flies straight)
	seekRange: number,
	turnDeg: number, -- degrees a second it can bend toward its target
	hitRadius: number, -- from a kart's middle (a kart is 1 x 0.55 KART)
	damage: number, -- a direct hit (health 100)
	splash: number, -- studs around the boom
	splashDamage: number, -- at the middle of the boom; half at its edge
	ahead: number, -- starts this far in front of the kart middle: its tail at the kart's nose (0.5 KART)
	up: number, -- and this high above its middle
}

local KART = Weapons.KART

-- ROCKETS: fast (about 1.7x a kart's top speed). Aim help (a phone kid can't aim): on fire they
-- lock onto the nearest live, unshielded kart within 35 degrees and 20 karts, leave straight at
-- it and curve after it; with no kart in that cone they fly straight.
-- 3 direct hits smash (health 100).
Weapons.ROCKET = {
	speed = 29 * KART,
	life = 2.4, -- about 70 karts: across the arena
	seekDeg = 35,
	seekRange = 20 * KART,
	turnDeg = 150, -- a kart dodging at full speed across its path is still caught from 6 karts
	hitRadius = 0.8 * KART,
	damage = 34,
	splash = 2 * KART,
	splashDamage = 20,
	ahead = 0.8 * KART,
	up = 0.15 * KART,
} :: Flight

-- NUKE: one slow, big rocket (a bit slower than a kart: you can run from it) that barely bends;
-- its boom is huge (8 karts around, an eighth of the arena) and smashes a crowd. A direct hit
-- always smashes; the middle of the boom too.
Weapons.NUKE = {
	speed = 12 * KART, -- (under the arena's top speed, about 14 karts a second)
	life = 4.5, -- about 54 karts
	seekDeg = 25,
	seekRange = 16 * KART,
	turnDeg = 25,
	hitRadius = 1 * KART,
	damage = 100,
	splash = 8 * KART,
	splashDamage = 100,
	ahead = 1.2 * KART,
	up = 0.2 * KART,
} :: Flight

-- the flight of each flying weapon, by name
Weapons.FLIGHTS = { Rockets = Weapons.ROCKET, Nuke = Weapons.NUKE } :: { [string]: Flight }

export type Target = { id: any, pos: Vector3, alive: boolean?, shield: boolean? }
export type Rocket = {
	pos: Vector3,
	dir: Vector3,
	age: number,
	owner: any,
	target: any?,
	spec: Flight,
}

-- Aim help, shared by every weapon (rockets, nuke, GUNMINE's gun): the nearest target that is
-- alive, not shielded and not `ignoreId`, within `range` studs and within `deg` of `dir` (flat,
-- seen from above). nil = nobody there: fire straight.
function Weapons.cone(
	from: Vector3,
	dir: Vector3,
	targets: { Target },
	deg: number,
	range: number,
	ignoreId: any?
): Target?
	local ahead = flat(Weapons.vec(dir) or vector.zero)
	local at = Weapons.vec(from)
	if not ahead or not at or deg <= 0 or range <= 0 then
		return nil
	end
	local cosMax = math.cos(math.rad(deg))
	local best, bestD = nil, math.huge
	for _, t in targets do
		local pos = Weapons.vec(t.pos)
		if pos and t.id ~= ignoreId and t.alive ~= false and t.shield ~= true then
			local to = pos - at
			local d = vector.magnitude(to)
			local side = flat(to)
			if d <= range and d < bestD and side and vector.dot(side, ahead) >= cosMax then
				best, bestD = t, d
			end
		end
	end
	return best
end

-- A new shot from a kart at `from` (its middle) aimed along `dir`. With `targets` it locks onto
-- the kart in its cone (Weapons.cone) and leaves straight at it, but never more than
-- MAX_AIM_DEG off `facing` (the kart's nose), so a cheat aiming at the edge can't lock sideways.
function Weapons.rocket(
	owner: any,
	from: Vector3,
	dir: Vector3,
	spec: Flight?,
	targets: { Target }?,
	facing: Vector3?
): Rocket
	local R = spec or Weapons.ROCKET
	local d = flat(Weapons.vec(dir) or vector.create(0, 0, -1)) or vector.create(0, 0, -1)
	from = Weapons.vec(from) or vector.zero
	local lock = if targets
		then Weapons.cone(from, d, targets, R.seekDeg, R.seekRange, owner)
		else nil
	local lockAt = lock and Weapons.vec(lock.pos)
	if lockAt then
		d = Weapons.aim(lockAt - from, facing or d)
	end
	return {
		pos = from + d * R.ahead + vector.create(0, R.up, 0),
		dir = d,
		age = 0,
		owner = owner,
		target = if lock then lock.id else nil,
		spec = R,
	}
end

-- The kart a flying rocket chases: the one it locked onto while it's still fair game, else the
-- nearest one in its cone from where it is now.
function Weapons.seek(r: Rocket, targets: { Target }): any?
	local R = r.spec
	if R.seekDeg <= 0 then
		return nil
	end
	if r.target ~= nil then
		for _, t in targets do
			local pos = Weapons.vec(t.pos)
			if t.id == r.target and pos and t.alive ~= false and t.shield ~= true then
				local d = vector.magnitude(pos - r.pos)
				if d <= R.seekRange * 1.5 then
					return t.id
				end
			end
		end
	end
	local t = Weapons.cone(r.pos, r.dir, targets, R.seekDeg, R.seekRange, r.owner)
	return if t then t.id else nil
end

-- the closest a segment a -> b comes to point p
local function segDist(a: Vector3, b: Vector3, p: Vector3): number
	local ab = b - a
	local len2 = vector.dot(ab, ab)
	local t = if len2 > 0 then math.clamp(vector.dot(p - a, ab) / len2, 0, 1) else 0
	return vector.magnitude(a + ab * t - p)
end

-- Move a rocket by dt. `blocked(from, to)` says where a wall stops it (or nil). Returns:
-- "hit", kartId | "wall", nil | "gone", nil (out of time) | nil (still flying). On "hit" and
-- "wall", r.pos is the boom spot.
function Weapons.step(
	r: Rocket,
	dt: number,
	targets: { Target },
	blocked: ((from: Vector3, to: Vector3) -> Vector3?)?
): (string?, any?)
	local R = r.spec
	r.target = Weapons.seek(r, targets)
	if r.target ~= nil then
		for _, t in targets do
			if t.id == r.target then
				local want = t.pos - r.pos
				local m = vector.magnitude(want)
				if m > 1e-3 then
					want /= m
					local cosA = math.clamp(vector.dot(r.dir, want), -1, 1)
					local ang = math.acos(cosA)
					local most = math.rad(R.turnDeg) * dt
					if ang <= most then
						r.dir = want
					else
						local mix = r.dir + (want - r.dir) * (most / ang)
						r.dir = vector.normalize(mix)
					end
				end
			end
		end
	end
	local from = r.pos
	local to = from + r.dir * R.speed * dt
	-- the nearest kart the path passes through (not the owner)
	local hitId, hitAt = nil, math.huge
	for _, t in targets do
		if t.id ~= r.owner and segDist(from, to, t.pos) <= R.hitRadius then
			local d = vector.magnitude(t.pos - from)
			if d < hitAt then
				hitId, hitAt = t.id, d
			end
		end
	end
	local wall = if blocked then blocked(from, to) else nil
	if wall and vector.magnitude(wall - from) < hitAt then
		r.pos = wall
		return "wall", nil
	end
	if hitId ~= nil then
		local t = to - from
		local len = vector.magnitude(t)
		r.pos = if len > 0 then from + t * (math.min(hitAt, len) / len) else from
		return "hit", hitId
	end
	r.pos = to
	r.age += dt
	if r.age >= R.life then
		return "gone", nil
	end
	return nil, nil
end

-- Who a boom at `at` hurts and how much: the kart hit takes `damage`, others in `splash` take
-- splashDamage (half at the edge). Never the owner. One entry per kart.
function Weapons.boom(
	at: Vector3,
	targets: { Target },
	owner: any,
	direct: any?,
	spec: Flight?
): { { id: any, damage: number } }
	local R = spec or Weapons.ROCKET
	local out = {}
	for _, t in targets do
		if t.id ~= owner then
			if t.id == direct then
				table.insert(out, { id = t.id, damage = R.damage })
			else
				local d = vector.magnitude(t.pos - at)
				if d <= R.splash then
					local dmg = math.floor(R.splashDamage * (1 - 0.5 * d / R.splash) + 0.5)
					table.insert(out, { id = t.id, damage = dmg })
				end
			end
		end
	end
	return out
end

return Weapons
