--!strict
-- What the client draws for the Junkyard Bowl, worked out in plain numbers (pure, unit tested): the
-- crusher's press, lamps and shock ring from the server clock, where a car scrapes the wall for
-- sparks, when it leaves skid marks, the camera flyover, the camera's radial clamp and how far ahead
-- the chase camera looks when a wall pushes it in. Positions are arena-local (the middle of the bowl
-- is 0, 0; x east, z south).

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local Layout = sibling("BowlLayout")

local BowlView = {}

local function clamp(v: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, v))
end

local function smooth(t: number): number
	t = clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- ---------------------------------------------------------------------------------------------
-- The crusher. `since` is the seconds since GO by the server clock; nil = resting (no round).

export type CrusherLook = {
	lift: number, -- bottom of the press above the floor
	warn: number, -- 0..1 how strongly the red warning shows on the floor
	lamps: boolean, -- the lamps and the beacon are lit (they flash while it warns)
	ring: number, -- diameter of the shock ring (0 = no ring)
	ringFade: number, -- transparency of the ring: 0 solid, 1 gone
	shake: number, -- camera shake (studs) for a car right beside it
	slam: number, -- the number of the slam whose ring is out right now (0 = first), -1 = none
}

function BowlView.crusher(since: number?): CrusherLook
	local C = Layout.crusher
	if since == nil or since < 0 then
		return {
			lift = C.restLift,
			warn = 0,
			lamps = true,
			ring = 0,
			ringFade = 1,
			shake = 0,
			slam = -1,
		}
	end
	local state = Layout.crusherState(since)
	local look: CrusherLook = {
		lift = Layout.crusherLift(state),
		warn = 0,
		lamps = true,
		ring = 0,
		ringFade = 1,
		shake = 0,
		slam = -1,
	}
	local phase = state.phase
	if phase == "warn" then
		-- red floor pulsing faster and stronger toward the slam; the lamps flash
		local secs = state.u * C.warn
		local pulse = 0.5 + 0.5 * math.sin(secs * 2 * math.pi * (2 + 3 * state.u))
		look.warn = (0.3 + 0.7 * state.u) * (0.55 + 0.45 * pulse)
		look.lamps = math.floor(secs * 8) % 2 == 0
	elseif phase == "drop" then
		look.warn = 1
	elseif phase == "wave" then
		look.warn = 0.5 * (1 - state.u)
		look.ring = 2 * Layout.shockFront(state)
		look.ringFade = 0.2 + 0.8 * state.u
		look.shake = 3 * (1 - state.u)
		look.slam = state.index
	elseif phase == "lift" then
		look.shake = 0.6 * (1 - state.u)
	end
	return look
end

-- ---------------------------------------------------------------------------------------------
-- Sparks: a car pressed against the tire wall or the crusher's base while it is moving.

export type Scrape = {
	x: number, -- where it touches
	z: number,
	nx: number, -- the way the sparks fly (away from the surface)
	nz: number,
}

-- A car never gets closer to the wall than the bounce lets it: BattleDrive.wallBounce throws it back
-- once its nose is about 3 studs from the tires (4 at 30 frames a second), so "touching" means
-- within this reach (a driven Studio test saw 0 sparks in 14 hits when this was 0.9).
local TOUCH = 6 -- closer than this counts as touching (studs)
local MIN_SPEED = 8 -- slower than this just rests against it

function BowlView.scrape(
	x: number,
	z: number,
	fx: number,
	fz: number,
	speed: number,
	halfLen: number,
	halfWid: number
): Scrape?
	if speed < MIN_SPEED then
		return nil
	end
	local d = math.sqrt(x * x + z * z)
	if d < 1e-3 then
		return nil
	end
	-- from the middle of the bowl toward the car
	local ux, uz = x / d, z / d
	-- how far the car's body reaches along that line
	local along = math.abs(ux * fx + uz * fz)
	local across = math.abs(ux * -fz + uz * fx)
	local reach = along * halfLen + across * halfWid
	-- the tire wall
	if d + reach >= Layout.wallRadius - TOUCH then
		return {
			x = ux * Layout.wallRadius,
			z = uz * Layout.wallRadius,
			nx = -ux,
			nz = -uz,
		}
	end
	-- the crusher's base
	local r = Layout.crusher.baseRadius
	if d - reach <= r + TOUCH then
		return { x = ux * r, z = uz * r, nx = ux, nz = uz }
	end
	return nil
end

-- ---------------------------------------------------------------------------------------------
-- Skid marks: how hard a car is sliding sideways, 0 (none) .. 1 (full). `cruise` is the top speed.

function BowlView.skid(
	vx: number,
	vz: number,
	fx: number,
	fz: number,
	cruise: number,
	drifting: boolean
): number
	local speed = math.sqrt(vx * vx + vz * vz)
	if speed < 0.3 * cruise then
		return 0
	end
	-- the speed sideways to the nose
	local side = math.abs(-fz * vx + fx * vz)
	local amount = clamp((side - 0.2 * cruise) / (0.2 * cruise), 0, 1)
	if drifting then
		amount = math.max(amount, 0.6)
	end
	return amount
end

-- ---------------------------------------------------------------------------------------------
-- The camera.

-- Keeps a point inside a circle round the middle (x, z are arena-local).
function BowlView.keepInside(x: number, z: number, maxR: number): (number, number)
	local d = math.sqrt(x * x + z * z)
	if d <= maxR or d < 1e-6 then
		return x, z
	end
	local k = maxR / d
	return x * k, z * k
end

-- How far ahead of my car the chase camera looks. `ahead` is the usual look-ahead, `have` how far
-- behind the car the camera really is and `want` how far it wants to be (both flat). A camera that
-- a wall pushed in (a car backed against the tires) would look past the car and lose it under the
-- bottom of the screen, so it looks less far ahead, down to `least` (never exactly at the car: a
-- camera straight above a point would have no side to put at the top of the screen).
function BowlView.lookAhead(ahead: number, have: number, want: number, least: number): number
	if want <= 1e-3 then
		return ahead
	end
	return clamp(ahead * clamp(have / want, 0, 1), math.min(least, ahead), ahead)
end

-- The flyover at the start of a round. `k` runs 0..1 through it and `dir` is +1 when my car starts
-- at the west end (facing east) or -1 at the east end. It starts high over the far end, sweeps along
-- the lane over the crusher and ends low behind my car. Returns the camera position, the point it
-- looks at (both from the middle of the bowl) and how much of the real chase camera to blend in
-- (0 at the start, 1 at the end).
function BowlView.fly(
	k: number,
	dir: number
): (number, number, number, number, number, number, number)
	local s = smooth(k)
	local px = dir * (140 - 225 * s)
	local py = 105 - 62 * s
	local pz = 70 - 28 * s
	local lx = -dir * 24 * s
	local ly = 2
	local lz = Layout.laneZ * s
	local blend = smooth((clamp(k, 0, 1) - 0.5) / 0.5)
	return px, py, pz, lx, ly, lz, blend
end

return BowlView
