--!strict
-- Breakable junkyard crates in the Smash arena (area 10; carter picked "A Plain wood", 10-29).
-- A crate sits on the yard floor. A kart that touches it, or a bullet / rocket / mine that hits it,
-- breaks it: planks fly and a dust puff rises (client/CrateFx). It is back RESPAWN seconds later.
-- Looks and fun only: a crate never hurts anyone, is never solid, and gives nothing (nothing to
-- farm, nothing to get stuck on). The server decides (CrateServer); no remote lets a client break one.
-- Plain numbers + `vector`, so Lune tests run it. Sizes are big units (a kart is 3 x 5.5 big);
-- the arena is built big then scaled by SCALE.

local BreakCrates = {}

BreakCrates.SCALE = 0.25 -- = TrackData.RC_SCALE (a test checks)
BreakCrates.SIZE = 2.4 -- a crate is this wide and tall (big units)
BreakCrates.TOUCH = 2.6 -- a kart's middle this close (flat) breaks it
BreakCrates.HIT = 2.4 -- a bullet this close to its middle breaks it
BreakCrates.HIT_BOOM = 7 -- a rocket / mine boom this close breaks it
BreakCrates.RESPAWN = 25 -- seconds until it is back
BreakCrates.REACH_UP = 5 -- a kart this far above the floor (big units) is flying over: no touch

-- Where the crates stand, in picture units (the arena's 240 x 240 picture): five pairs spread round
-- the yard. Open, flat, off the starts and "?" boxes; tests/breakcrates.test checks all of it.
BreakCrates.SPOTS = {
	{ 40, 70 },
	{ 50, 80 },
	{ 110, 30 },
	{ 120, 40 },
	{ 220, 90 },
	{ 210, 90 },
	{ 70, 180 },
	{ 80, 190 },
	{ 130, 150 },
	{ 140, 150 },
} :: { { number } }

export type Crate = {
	pos: vector, -- world studs, the crate's foot on the floor
	up: boolean,
	backAt: number?, -- when it is back
}

function BreakCrates.newCrate(pos: vector): Crate
	return { pos = pos, up = true, backAt = nil }
end

-- Break a crate (no-op when it is already down). Returns true the moment it breaks.
function BreakCrates.smash(c: Crate, now: number): boolean
	if not c.up then
		return false
	end
	c.up, c.backAt = false, now + BreakCrates.RESPAWN
	return true
end

-- Back when the time is up. Returns true the moment it is.
function BreakCrates.regrow(c: Crate, now: number): boolean
	local at = c.backAt
	if c.up or at == nil or now < at then
		return false
	end
	c.up, c.backAt = true, nil
	return true
end

-- Every crate at a round's start: up.
function BreakCrates.reset(c: Crate)
	c.up, c.backAt = true, nil
end

export type Kart = { id: any, position: vector, alive: boolean }

-- One step over all crates and karts: crates come back, then a live kart touching a crate
-- breaks it. Returns the indices of the crates that broke this step.
function BreakCrates.step(
	crates: { Crate },
	karts: { Kart },
	now: number,
	scale: number?
): { number }
	local s = scale or BreakCrates.SCALE
	local broke = {}
	for _, c in crates do
		BreakCrates.regrow(c, now)
	end
	for i, c in crates do
		if c.up then
			for _, k in karts do
				if k.alive and math.abs(k.position.y - c.pos.y) / s <= BreakCrates.REACH_UP then
					local dx, dz = k.position.x - c.pos.x, k.position.z - c.pos.z
					if math.sqrt(dx * dx + dz * dz) / s <= BreakCrates.TOUCH then
						BreakCrates.smash(c, now)
						table.insert(broke, i)
						break
					end
				end
			end
		end
	end
	return broke
end

-- Something went off at `at` (world studs): break every crate within `reach` big units.
-- Returns the indices that broke.
function BreakCrates.hitAt(
	crates: { Crate },
	at: vector,
	reach: number,
	now: number,
	scale: number?
): { number }
	local s = scale or BreakCrates.SCALE
	local broke = {}
	for i, c in crates do
		if c.up and vector.magnitude(at - c.pos) / s <= reach then
			if BreakCrates.smash(c, now) then
				table.insert(broke, i)
			end
		end
	end
	return broke
end

-- Flat-ish distance from a point to the segment a..b, 3D.
local function segDist(p: vector, a: vector, b: vector): number
	local ab = b - a
	local len2 = vector.dot(ab, ab)
	local t = if len2 > 1e-9 then math.clamp(vector.dot(p - a, ab) / len2, 0, 1) else 0
	return vector.magnitude(p - (a + ab * t))
end

-- A bullet flew from a to b: break every crate within HIT of its path. Returns the indices.
function BreakCrates.hitSegment(
	crates: { Crate },
	a: vector,
	b: vector,
	now: number,
	scale: number?
): { number }
	local s = scale or BreakCrates.SCALE
	local broke = {}
	for i, c in crates do
		-- (a crate is about SIZE tall: aim at its middle, not the floor)
		local mid = c.pos + vector.create(0, BreakCrates.SIZE / 2 * s, 0)
		if c.up and segDist(mid, a, b) / s <= BreakCrates.HIT then
			if BreakCrates.smash(c, now) then
				table.insert(broke, i)
			end
		end
	end
	return broke
end

-- A weapon announced itself (the WeaponFx kinds WeaponServer sends everyone): GunShot breaks crates
-- on the bullet's path, RocketBoom / MineBoom the crates near the boom (not the silent
-- end-of-match boom). `data` is the fx table (clients never send it). Returns the indices.
function BreakCrates.fromFx(
	crates: { Crate },
	kind: string,
	data: any,
	now: number,
	scale: number?
): { number }
	if type(data) ~= "table" then
		return {}
	end
	if kind == "GunShot" then
		local a, b = data.from, data.to
		if type(a) == "vector" and type(b) == "vector" then
			return BreakCrates.hitSegment(crates, a, b, now, scale)
		end
	elseif kind == "RocketBoom" or kind == "MineBoom" then
		local at = if kind == "RocketBoom" then data.pos else data.position
		if type(at) == "vector" and data.quiet ~= true then
			return BreakCrates.hitAt(crates, at, BreakCrates.HIT_BOOM, now, scale)
		end
	end
	return {}
end

return BreakCrates
