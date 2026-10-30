--!strict
-- Rolling barrels in the Smash arena (carter picked "3 Toxic Drum", 10-30). A drum lies on its side
-- on the yard floor. A kart that drives into it shoves it: it rolls away, slows down by itself,
-- bounces off walls and things that stand up, and clonks into other drums. No damage: just fun.
-- The server alone moves them (no remote lets a client push anything). Plain numbers + `vector`,
-- so Lune tests run it. Sizes are big units (a kart is 3 x 5.5 big); the arena is built big then
-- scaled by SCALE. Positions are world studs on the floor (y is kept, drums stay on flat ground).

local RollBarrels = {}

RollBarrels.SCALE = 0.25 -- = TrackData.RC_SCALE (a test checks)
RollBarrels.KART_R = 2.9 -- a kart's middle this close (plus the drum's radius) shoves a drum
RollBarrels.DRUM_R = 2 -- the drum's flat radius (it is 4.2 long, 3.4 across; this is the roll circle)
RollBarrels.LENGTH = 4.2
RollBarrels.RADIUS_3D = 1.7 -- the drum's round radius: spin = distance / this
RollBarrels.PUSH = 1.25 -- a drum leaves at this times the kart's speed into it
RollBarrels.NUDGE = 3 -- a kart touching it always gives at least this much (big units/s)
RollBarrels.FRICTION = 5 -- big units/s of speed lost every second
RollBarrels.BOUNCE = 0.55 -- speed kept when it hits a wall or something solid
RollBarrels.MAX_SPEED = 26 -- big units/s (an RC kart tops out near 24 studs/s)
RollBarrels.REACH_UP = 6 -- a kart this far above the floor (big units) is flying over: no shove
RollBarrels.TURN = 8 -- how fast the drum turns to roll the way it moves (per second)
RollBarrels.REST = 0.6 -- slower than this (big units/s) a drum counts as stopped
RollBarrels.NAME = "Drum"

-- Where the drums wait, in picture units (the arena's 240 x 240 picture). tests/rollbarrels.test
-- checks they are open, flat, and far from start spots, "?" boxes and the dynamite kegs.
RollBarrels.SPOTS = {
	{ 60, 105 },
	{ 100, 165 },
	{ 145, 115 },
	{ 50, 165 }, -- (batch 10-30: the last three moved off the fire pits and crates)
	{ 100, 105 },
	{ 30, 120 },
} :: { { number } }

export type Drum = {
	home: vector, -- world studs where it starts each round
	pos: vector,
	vel: vector, -- studs/s on the floor (y stays 0)
	head: number, -- radians: the way it rolls (atan2 of z, x)
	spin: number, -- radians rolled so far (the look turns by this)
	moving: boolean,
}

export type Kart = { id: any, position: vector, velocity: vector, alive: boolean }

-- nil = free. Something solid in the way at this world spot: the server answers with ArenaData.
export type Blocked = (pos: vector) -> boolean

function RollBarrels.newDrum(pos: vector): Drum
	return { home = pos, pos = pos, vel = vector.zero, head = 0, spin = 0, moving = false }
end

function RollBarrels.reset(d: Drum)
	d.pos, d.vel, d.head, d.spin, d.moving = d.home, vector.zero, 0, 0, false
end

local function flat(v: vector): vector
	return vector.create(v.x, 0, v.z)
end

-- Move one drum a step: friction, then the move, bouncing off anything `blocked` says is solid.
local function slide(d: Drum, dt: number, s: number, blocked: Blocked?)
	local sp = vector.magnitude(d.vel) / s
	if sp > 1e-6 then
		local ns = math.max(0, sp - RollBarrels.FRICTION * dt)
		d.vel = d.vel * (ns / sp)
	end
	if vector.magnitude(d.vel) / s < RollBarrels.REST * 0.5 then
		d.vel = vector.zero
	end
	if d.vel == vector.zero then
		return
	end
	local to = d.pos + d.vel * dt
	if blocked and blocked(to) then
		-- bounce back off whatever is there (the spot we came from was free)
		d.vel = -d.vel * RollBarrels.BOUNCE
		return
	end
	d.pos = to
end

-- One step of the rules over all drums and karts. `dt` seconds. Returns how many drums moved.
function RollBarrels.step(
	drums: { Drum },
	karts: { Kart },
	dt: number,
	scale: number?,
	blocked: Blocked?
): number
	local s = scale or RollBarrels.SCALE
	local touch = RollBarrels.KART_R + RollBarrels.DRUM_R
	for _, d in drums do
		for _, k in karts do
			if k.alive and math.abs(k.position.y - d.pos.y) / s <= RollBarrels.REACH_UP then
				local away = flat(d.pos - k.position)
				local dist = vector.magnitude(away) / s
				if dist < touch then
					local n = if dist > 1e-3 then away / (dist * s) else vector.create(1, 0, 0)
					-- lift the drum out of the kart, never into something solid
					local out = d.pos + n * ((touch - dist) * s)
					if not (blocked and blocked(out)) then
						d.pos = out
					end
					-- the push: the kart's speed into the drum
					local rel = vector.dot(flat(k.velocity), n) / s
					local gain = math.max(RollBarrels.NUDGE, rel * RollBarrels.PUSH)
					local v = d.vel + n * (gain * s)
					local cap = RollBarrels.MAX_SPEED * s
					if vector.magnitude(v) > cap then
						v = v / vector.magnitude(v) * cap
					end
					d.vel = v
				end
			end
		end
	end
	-- drum against drum: swap the speed along the line between them
	for i = 1, #drums do
		for j = i + 1, #drums do
			local a, b = drums[i], drums[j]
			local dx = flat(b.pos - a.pos)
			local dist = vector.magnitude(dx) / s
			local min = RollBarrels.DRUM_R * 2
			if dist < min then
				local n = if dist > 1e-3 then dx / (dist * s) else vector.create(1, 0, 0)
				local half = n * ((min - dist) * s / 2)
				a.pos -= half
				b.pos += half
				local rel = vector.dot(a.vel - b.vel, n)
				if rel > 0 then
					a.vel -= n * rel
					b.vel += n * rel
				end
			end
		end
	end
	local moved = 0
	for _, d in drums do
		slide(d, dt, s, blocked)
		local sp = vector.magnitude(d.vel) / s
		d.moving = sp > RollBarrels.REST
		if d.moving then
			moved += 1
			-- turn to roll the way it goes, along the shortest way round
			local want = math.atan2(d.vel.z, d.vel.x)
			local dh = (want - d.head + math.pi) % (2 * math.pi) - math.pi
			d.head += dh * math.min(1, dt * RollBarrels.TURN)
			d.spin += sp * dt / RollBarrels.RADIUS_3D
		end
	end
	return moved
end

return RollBarrels
