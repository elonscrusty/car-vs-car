--!strict
-- The Ice Viper's SHOCKWAVE special (carter picked "Ice Rings" 10-29): the Nose Cannon charges, then
-- fires a fan of rings out of its muzzle; every kart the rings reach is shoved away from the
-- cannon and loses a little health. It refills over time (REFILL), one shot at a time.
-- The server decides who is hit and when (server/weapons/Shockwave); clients draw the rings
-- (client/ShockwaveFx). Plain `vector` maths, so Lune tests run it.

local Shockwave = {}

Shockwave.NAME = "Shockwave"
-- The arena is RC size: distances are set in big units (a kart is 3 x 5.5 big) and shrunk by SCALE
-- (= TrackData.RC_SCALE, like server/weapons/Gun), so a kart is about 1.4 studs long.
Shockwave.SCALE = 0.25
local S = Shockwave.SCALE

Shockwave.REFILL = 15 -- seconds until the special is ready again
Shockwave.CHARGE = 0.6 -- seconds the cannon glows before the rings leave it
Shockwave.ARC_DEG = 126 -- the fan: this many degrees wide, centred on where the kart faces
Shockwave.RANGE = 48 * S -- studs from the muzzle (about 9 karts)
Shockwave.SPEED = 60 * S -- studs a second the rings travel (a bit under a kart's top speed)
Shockwave.PUSH = 80 * S -- studs/s added to a kart at the muzzle; half of that at the edge
Shockwave.HOP = 20 * S -- studs/s straight up, so the shove lifts the kart a little
Shockwave.DAMAGE = 12 -- health (100 smashes): the shove is the point, weapons do the real damage
Shockwave.MUZZLE = 4.5 * S -- the cannon's mouth, ahead of the kart's middle
Shockwave.HEIGHT = 1.2 * S -- and above it
Shockwave.NEAR = 0.8 * S -- a kart this close to the muzzle is hit from any side

export type Kart = { id: any, cframe: CFrame, alive: boolean, shield: boolean? }
export type Victim = {
	id: any,
	dist: number, -- studs from the muzzle (flat)
	delay: number, -- seconds from the button until the rings reach it
	push: Vector3, -- the flat velocity to add (already weaker with distance)
	up: number, -- and the hop
}

local function flat(v: Vector3): Vector3?
	local f = vector.create(v.x, 0, v.z)
	local m = vector.magnitude(f)
	if m ~= m or m < 1e-4 or m == math.huge then
		return nil
	end
	return f / m
end

-- Where the rings start: the kart's nose, along its flat facing.
function Shockwave.muzzle(kart: Kart): (Vector3, Vector3)
	local look = flat(kart.cframe.LookVector) or vector.create(0, 0, -1)
	local from = kart.cframe.Position
		+ look * Shockwave.MUZZLE
		+ vector.create(0, Shockwave.HEIGHT, 0)
	return from, look
end

-- Every kart the rings reach from `origin` along `dir` (flat, unit): alive, not shielded, not the
-- owner, within RANGE and inside the fan (or right at the muzzle). Nearest first.
function Shockwave.victims(origin: Vector3, dir: Vector3, karts: { Kart }, ownerId: any): { Victim }
	local out: { Victim } = {}
	local ahead = flat(dir) or vector.create(0, 0, -1)
	local cosHalf = math.cos(math.rad(Shockwave.ARC_DEG / 2))
	for _, k in karts do
		if k.id == ownerId or not k.alive or k.shield == true then
			continue
		end
		local to = k.cframe.Position - origin
		local d = math.sqrt(to.x * to.x + to.z * to.z)
		if d ~= d or d > Shockwave.RANGE then
			continue
		end
		local away = flat(to)
		if d > Shockwave.NEAR then
			if not away or vector.dot(away, ahead) < cosHalf then
				continue
			end
		end
		local pushDir = away or ahead
		local strength = 1 - 0.5 * d / Shockwave.RANGE
		table.insert(out, {
			id = k.id,
			dist = d,
			delay = Shockwave.CHARGE + d / Shockwave.SPEED,
			push = pushDir * (Shockwave.PUSH * strength),
			up = Shockwave.HOP,
		})
	end
	table.sort(out, function(a: Victim, b: Victim): boolean
		return a.dist < b.dist
	end)
	return out
end

-- ===== one kart's special: ready, use, charge bar =====

export type Slot = { readyAt: number }

function Shockwave.slot(): Slot
	return { readyAt = 0 }
end

function Shockwave.ready(slot: Slot, now: number): boolean
	return now >= slot.readyAt
end

-- Spend the special if it is ready; true = it goes.
function Shockwave.use(slot: Slot, now: number): boolean
	if now < slot.readyAt then
		return false
	end
	slot.readyAt = now + Shockwave.REFILL
	return true
end

-- How full the special is, 0..1 (the button's ring).
function Shockwave.charge(slot: Slot, now: number): number
	if now >= slot.readyAt then
		return 1
	end
	return math.clamp(1 - (slot.readyAt - now) / Shockwave.REFILL, 0, 1)
end

return Shockwave
