--!strict
-- Dynamite kegs in the Smash arena (arena hazard 1; carter picked "3 Dynamite Keg", 10-29).
-- A keg sits on the yard floor. A kart that touches it, or a rocket / mine / bullet that hits it,
-- lights the fuse; FUSE seconds later it goes off and hurts every live kart within RADIUS (more
-- in the middle, less at the edge) and shoves them away. It grows back RESPAWN seconds later.
-- Fair on purpose: a glowing ring on the floor shows the whole danger zone, the fuse spark
-- blinks, and the fuse gives you a moment to drive away. The server decides everything (no
-- remote from a client can light, hurt or shove). Plain numbers + `vector`, so Lune tests run it.
-- Sizes are big units (a kart is 3 x 5.5 big); the arena is built big then scaled by SCALE.

local Barrels = {}

Barrels.SCALE = 0.25 -- = TrackData.RC_SCALE (a test checks)
Barrels.TOUCH = 3.4 -- a kart's middle this close to the keg's middle lights it
Barrels.HIT = 3 -- a bullet this close, or a boom this close (HIT_BOOM), lights it
Barrels.HIT_BOOM = 8
Barrels.RADIUS = 12 -- the danger zone (the ring on the floor)
Barrels.FUSE = 0.6 -- seconds from lit to boom
Barrels.CHAIN_FUSE = 0.3 -- a keg lit by another keg's boom
Barrels.RESPAWN = 20
Barrels.DAMAGE_MAX = 40 -- health at the keg's middle (a kart has 100: three in a row smash it)
Barrels.DAMAGE_MIN = 14 -- health at the edge of the ring
Barrels.KNOCK = 17 -- studs/s of shove at the middle (an RC kart tops out near 24)
Barrels.KNOCK_UP = 7 -- studs/s of lift at the middle
Barrels.KNOCK_MAX = 30 -- the client never takes a bigger shove than this (checked there too)
Barrels.NAME = "Keg" -- the word the match shows when a keg smashes a kart

-- Where the kegs stand, in picture units (the arena's 240 x 240 picture). Chosen open, flat,
-- far from every start spot and box, spread round the yard; tests/barrels.test checks all of it.
Barrels.SPOTS = {
	{ 120, 120 },
	{ 155, 175 },
	{ 125, 185 },
	{ 55, 140 },
	{ 80, 80 },
	{ 175, 50 },
} :: { { number } }

-- Health a kart `dist` big units from the keg loses (0 outside the ring): straight line from
-- DAMAGE_MAX in the middle to DAMAGE_MIN at the edge.
function Barrels.damage(dist: number): number
	if dist ~= dist or dist > Barrels.RADIUS then
		return 0
	end
	local f = math.clamp(dist / Barrels.RADIUS, 0, 1)
	-- Flat-ish distance (big units) from keg to the segment a..b, 3D.
	local function segDist(p: vector, a: vector, b: vector): number
		local ab = b - a
		local len2 = vector.dot(ab, ab)
		local t = if len2 > 1e-9 then math.clamp(vector.dot(p - a, ab) / len2, 0, 1) else 0
		return vector.magnitude(p - (a + ab * t))
	end

	-- A bullet flew from a to b: light every keg within HIT of its path. Returns how many it lit.
	function Barrels.hitSegment(
		kegs: { Keg },
		a: vector,
		b: vector,
		now: number,
		owner: any?,
		scale: number?
	): number
		local s = scale or Barrels.SCALE
		local n = 0
		for _, k in kegs do
			-- (a keg is about 5 big tall: aim at its middle, not the floor)
			local mid = k.pos + vector.create(0, 2.5 * s, 0)
			if k.up and segDist(mid, a, b) / s <= Barrels.HIT then
				if Barrels.light(k, now, owner) then
					n += 1
				end
			end
		end
		return n
	end

	-- A weapon announced itself (the WeaponFx kinds WeaponServer sends everyone): which ones light a
	-- keg? GunShot lights kegs on the bullet's path, RocketBoom / MineBoom the kegs near the boom
	-- (not the silent end-of-match boom). `data` is the fx table (clients never send it).
	function Barrels.lightFromFx(
		kegs: { Keg },
		kind: string,
		data: any,
		now: number,
		scale: number?
	): number
		if type(data) ~= "table" then
			return 0
		end
		if kind == "GunShot" then
			local a, b = data.from, data.to
			if type(a) == "vector" and type(b) == "vector" then
				return Barrels.hitSegment(kegs, a, b, now, data.owner, scale)
			end
		elseif kind == "RocketBoom" or kind == "MineBoom" then
			local at = if kind == "RocketBoom" then data.pos else data.position
			if type(at) == "vector" and data.quiet ~= true then
				return Barrels.hitAt(kegs, at, Barrels.HIT_BOOM, now, data.owner, scale)
			end
		end
		return 0
	end

	return Barrels.DAMAGE_MAX + (Barrels.DAMAGE_MIN - Barrels.DAMAGE_MAX) * f
end

-- The shove for a kart at `kart` from a keg at `keg` (world studs): away from the keg along the
-- floor plus a little lift, strongest in the middle, none outside the ring. Returns a vector
-- (zero when out of range). RADIUS is in big units, positions in studs: `scale` joins them.
function Barrels.shove(keg: vector, kart: vector, scale: number?): vector
	local s = scale or Barrels.SCALE
	local away = vector.create(kart.x - keg.x, 0, kart.z - keg.z)
	local d = vector.magnitude(away) / s -- big units
	if d > Barrels.RADIUS then
		return vector.zero
	end
	local dir = if d > 1e-3 then away / (d * s) else vector.create(0, 0, 1)
	local f = 1 - math.clamp(d / Barrels.RADIUS, 0, 1)
	local push = math.min(Barrels.KNOCK * (0.35 + 0.65 * f), Barrels.KNOCK_MAX)
	return dir * push + vector.create(0, Barrels.KNOCK_UP * f, 0)
end

export type Keg = {
	pos: vector, -- world studs, the keg's middle on the floor
	up: boolean,
	litAt: number?, -- seconds; boom at litAt + fuse
	fuse: number,
	owner: any?, -- who lit it (credit for the smash); nil = the arena
	backAt: number?, -- when it grows back
}

function Barrels.newKeg(pos: vector): Keg
	return { pos = pos, up = true, litAt = nil, fuse = Barrels.FUSE, owner = nil, backAt = nil }
end

-- Light a keg (no-op when down or already lit: the first spark's owner keeps the credit).
function Barrels.light(k: Keg, now: number, owner: any?, fuse: number?): boolean
	if not k.up or k.litAt ~= nil then
		return false
	end
	k.litAt, k.owner, k.fuse = now, owner, fuse or Barrels.FUSE
	return true
end

-- Is this keg's boom due?
function Barrels.due(k: Keg, now: number): boolean
	local at = k.litAt
	return k.up and at ~= nil and now >= at + k.fuse
end

-- The keg goes off: it's down until RESPAWN passes. Returns who lit it.
function Barrels.explode(k: Keg, now: number): any?
	local owner = k.owner
	k.up, k.litAt, k.owner, k.backAt = false, nil, nil, now + Barrels.RESPAWN
	return owner
end

-- Grow back when the time is up. Returns true the moment it does.
function Barrels.regrow(k: Keg, now: number): boolean
	local at = k.backAt
	if k.up or at == nil or now < at then
		return false
	end
	k.up, k.backAt = true, nil
	return true
end

-- Every keg at a round's start: up, no fuse.
function Barrels.reset(k: Keg)
	k.up, k.litAt, k.owner, k.backAt = true, nil, nil, nil
end

export type Kart = { id: any, position: vector, alive: boolean }

Barrels.REACH_UP = 6 -- a kart this far above the floor (big units) is flying over: it doesn't touch
Barrels.BLAST_UP = 10 -- ... and a boom doesn't reach it above this

-- Flat distance in big units from keg to kart; nil when the kart is too high above the keg.
local function flat(keg: vector, kart: vector, s: number, up: number): number?
	if math.abs(kart.y - keg.y) / s > up then
		return nil
	end
	local dx, dz = kart.x - keg.x, kart.z - keg.z
	return math.sqrt(dx * dx + dz * dz) / s
end

-- One step of the rules over all kegs and karts. `now` is seconds. Returns the booms of this
-- step: { keg = index, owner, hurt = { { id, damage, shove } } } (the caller does the damage and
-- the fx, so the same rules run in tests with no Roblox). A boom lights the kegs beside it with
-- the short chain fuse, so a cluster rolls on. Touching lights a keg for the kart that touched
-- it.
function Barrels.step(kegs: { Keg }, karts: { Kart }, now: number, scale: number?): { any }
	local s = scale or Barrels.SCALE
	local booms = {}
	for _, k in kegs do
		Barrels.regrow(k, now)
	end
	for _, k in kegs do
		if k.up and k.litAt == nil then
			for _, c in karts do
				if c.alive then
					local d = flat(k.pos, c.position, s, Barrels.REACH_UP)
					if d and d <= Barrels.TOUCH then
						Barrels.light(k, now, c.id)
						break
					end
				end
			end
		end
	end
	for i, k in kegs do
		if Barrels.due(k, now) then
			local owner = Barrels.explode(k, now)
			local hurt = {}
			for _, c in karts do
				if c.alive then
					local d = flat(k.pos, c.position, s, Barrels.BLAST_UP)
					local dmg = if d then Barrels.damage(d) else 0
					if dmg > 0 then
						table.insert(
							hurt,
							{ id = c.id, damage = dmg, shove = Barrels.shove(k.pos, c.position, s) }
						)
					end
				end
			end
			-- the kegs beside it catch the chain fuse (they go off a moment later, not this step)
			for _, o in kegs do
				if o.up and o.litAt == nil then
					if vector.magnitude(o.pos - k.pos) / s <= Barrels.RADIUS then
						Barrels.light(o, now, owner, Barrels.CHAIN_FUSE)
					end
				end
			end
			table.insert(booms, { keg = i, owner = owner, hurt = hurt })
		end
	end
	return booms
end

-- A weapon went off or hit at `at` (world studs): light every keg within `reach` big units.
-- Returns how many it lit.
function Barrels.hitAt(
	kegs: { Keg },
	at: vector,
	reach: number,
	now: number,
	owner: any?,
	scale: number?
): number
	local s = scale or Barrels.SCALE
	local n = 0
	for _, k in kegs do
		if k.up and vector.magnitude(at - k.pos) / s <= reach then
			if Barrels.light(k, now, owner) then
				n += 1
			end
		end
	end
	return n
end

return Barrels
