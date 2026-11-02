--!strict
-- The swinging crane ball in the Smash arena (arena hazard 2; carter picked "2 Spiked Mace", 10-29).
-- A yard crane holds a spiked iron ball on a chain. It swings side to side along a lane on the
-- floor, the same way every time, so you can read it: the ball is only low enough to hit a kart in
-- the middle of the lane, and the lane is drawn on the floor. A kart the ball touches loses
-- health and is shoved the way the ball is going (a short cooldown per kart, so one swing never
-- hits twice). The server decides everything; the client draws the same swing from the same clock.
-- Plain numbers + `vector`, so Lune tests run it. Sizes are big units (a kart is 3 x 5.5 big);
-- the arena is built big then scaled by SCALE.

local Crane = {}

Crane.SCALE = 0.25 -- = TrackData.RC_SCALE (a test checks)
Crane.PIVOT_H = 26 -- height of the boom tip the chain hangs from
Crane.CHAIN = 22 -- from the tip to the ball's middle
Crane.AMP = 1.1 -- swing angle each side, radians (about 63 degrees)
Crane.PERIOD = 4 -- seconds for a full there-and-back
Crane.HIT_R = 5.5 -- ball (3.5) + spikes (2.4), less a little: a kart's middle this close is hit
Crane.DAMAGE = 30 -- a kart has 100: three swings smash it
Crane.COOLDOWN = 1.5 -- seconds before the same kart can be hit again
Crane.KNOCK = 22 -- studs/s of shove at full swing speed (an RC kart tops out near 24)
Crane.KNOCK_UP = 6
Crane.KNOCK_MAX = 30 -- the client never takes a bigger shove than this (checked there too)
Crane.LANE_W = 7 -- the floor lane is this wide each side of the middle line (big units)
Crane.NAME = "Crane" -- the word the match shows when the ball smashes a kart

-- Where the crane stands (the lane's middle, on the floor), in picture units. The lane runs east-west.
-- Chosen open, flat, far from every start spot, box and keg; tests/crane.test checks all of it.
Crane.SPOT = { 120, 155 } :: { number }

-- swing angle at time t (radians, 0 = hanging straight down)
function Crane.angle(t: number): number
	return Crane.AMP * math.sin(2 * math.pi * t / Crane.PERIOD)
end

-- which way the ball is moving along the lane at t: +1 east, -1 west, 0 at the very ends
function Crane.way(t: number): number
	local c = math.cos(2 * math.pi * t / Crane.PERIOD)
	return if c > 1e-6 then 1 elseif c < -1e-6 then -1 else 0
end

-- How far the lane reaches east or west of its middle (big units): the ball's widest swing
-- plus its own size.
function Crane.reach(): number
	return math.sin(Crane.AMP) * Crane.CHAIN + Crane.HIT_R
end

-- The ball's middle at time t, for a crane whose lane middle is at `foot` (world studs, on the floor).
function Crane.ball(foot: vector, t: number, scale: number?): vector
	local s = scale or Crane.SCALE
	local a = Crane.angle(t)
	return foot
		+ vector.create(
			math.sin(a) * Crane.CHAIN * s,
			(Crane.PIVOT_H - math.cos(a) * Crane.CHAIN) * s,
			0
		)
end

export type State = { last: { [any]: number } }

function Crane.newState(): State
	return { last = {} }
end

-- A new round: every kart can be hit again.
function Crane.reset(st: State)
	table.clear(st.last)
end

export type Kart = { id: any, position: vector, alive: boolean }

-- The shove for a kart the ball hit at time t: the way the ball goes, a little lift, harder when
-- the ball is fast (the middle of the swing), never over KNOCK_MAX.
function Crane.shove(t: number): vector
	local fast = math.abs(math.cos(2 * math.pi * t / Crane.PERIOD))
	local w = Crane.way(t)
	local push = math.min(Crane.KNOCK * (0.5 + 0.5 * fast), Crane.KNOCK_MAX)
	return vector.create(w * push, Crane.KNOCK_UP * fast, 0)
end

-- One step of the rules at time `now` (seconds on the swing clock): which karts the ball is on.
-- Returns { { id, damage, shove } }; the caller does the damage and the fx.
function Crane.step(st: State, foot: vector, karts: { Kart }, now: number, scale: number?): { any }
	local s = scale or Crane.SCALE
	local b = Crane.ball(foot, now, s)
	local hits = {}
	for _, c in karts do
		if c.alive then
			local d = vector.magnitude(c.position - b) / s
			local last = st.last[c.id]
			if d == d and d <= Crane.HIT_R and (last == nil or now - last >= Crane.COOLDOWN) then
				st.last[c.id] = now
				table.insert(
					hits,
					{ id = c.id, damage = Crane.DAMAGE, shove = Crane.shove(now), at = b }
				)
			end
		end
	end
	return hits
end

return Crane
