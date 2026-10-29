--!strict
-- The match camera (carter 10-29 11:33: "it's hard to tell what's going on with this camera
-- angle"). A Smash Karts style chase cam: still behind your kart and turning with it (carter
-- 10-19: a fixed overhead view is boring), but higher, further back and tilted down, so your
-- kart sits in the lower third and the karts and boxes around it show on a phone. Every number
-- lives here; client/ChaseCamera uses them only while you are in a match (InMatch), and the
-- lobby and race cameras stay as they were. Plain maths: Lune tests it.
-- Studs are at the arena's RC size (TrackData.RC_SCALE 0.25: a kart is ~1.4 studs long).

local ArenaCam = {}

ArenaCam.DISTANCE = 9 -- studs from the kart to the camera (~6.5 kart lengths)
ArenaCam.PITCH = 40 -- degrees the camera looks down at the kart (Smash Karts ~35-45)
ArenaCam.FOV = 60 -- vertical field of view, degrees
ArenaCam.FOV_FAST = 5 -- a little wider at top speed
ArenaCam.KART_LOW = 1 / 3 -- the kart sits this far below the screen's middle (lower third)
-- look-ahead: the view leans this many seconds ahead along where the kart is going, up to
-- LEAD_MAX studs (tuned for the arena's lowered top speed, ~19 studs/s)
ArenaCam.LEAD_TIME = 0.12
ArenaCam.LEAD_MAX = 2
ArenaCam.LEAD_EASE = 3 -- 1/s: how fast the lean follows (no jerk on a turn)
ArenaCam.BLEND = 0.6 -- s to ease from the race camera into this one (and back)
ArenaCam.WALL_GAP = 0.3 -- studs kept between the camera and a wall it slid in for
ArenaCam.MIN_REACH = 0.35 -- pulled in closer than this share by a wall: swing up to STEEP
ArenaCam.STEEP = 72 -- degrees: the swung-up pitch, over the kart, when a wall is right behind

-- The camera's spot as an offset from the kart: `back` studs behind it and `up` studs above.
function ArenaCam.offset(distance: number?, pitch: number?): (number, number)
	local d = distance or ArenaCam.DISTANCE
	local p = math.rad(pitch or ArenaCam.PITCH)
	return d * math.cos(p), d * math.sin(p)
end

-- How far ahead of the kart (studs, along the ground) the camera aims, so the kart itself shows
-- `low` of the half-screen below the middle (KART_LOW = lower third).
function ArenaCam.aimAhead(distance: number?, pitch: number?, fov: number?, low: number?): number
	local back, up = ArenaCam.offset(distance, pitch)
	local p = math.rad(pitch or ArenaCam.PITCH)
	local half = math.rad((fov or ArenaCam.FOV) / 2)
	-- the angle between the middle of the screen and the kart, for that screen spot
	local off = math.atan(math.tan(half) * (low or ArenaCam.KART_LOW))
	local look = math.max(p - off, math.rad(5))
	return up / math.tan(look) - back
end

-- The look-ahead lean (studs) for a ground speed (studs/s), capped.
function ArenaCam.lead(speed: number): number
	return math.clamp(speed * ArenaCam.LEAD_TIME, 0, ArenaCam.LEAD_MAX)
end

-- How far (0..1) into the arena camera `t` s after the switch (smoothstep, so no jolt).
function ArenaCam.blend(t: number): number
	local u = math.clamp(t / ArenaCam.BLEND, 0, 1)
	return u * u * (3 - 2 * u)
end

-- Is the match camera on? Only in a match (the server's InMatch), never in the lobby or a race.
function ArenaCam.on(inMatch: unknown, inArena: boolean): boolean
	return inMatch == true and inArena
end

-- The share of the full distance the camera may be out when a wall is `hitAt` studs along the
-- way (nil = nothing in the way): always on this side of the wall, never into the kart.
function ArenaCam.reach(hitAt: number?, distance: number?): number
	if hitAt == nil then
		return 1
	end
	local d = distance or ArenaCam.DISTANCE
	return math.clamp((hitAt - ArenaCam.WALL_GAP) / d, 0.05, 1)
end

return ArenaCam
