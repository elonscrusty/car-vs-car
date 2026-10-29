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

-- Phone-shaped screens (auditor round 12b #4: on a phone your kart was ~4% of the screen's width,
-- "can't see my kart"): closer, a little lower and narrower, so your kart is at least MIN_SHARE of
-- the width, while still seeing PHONE_AHEAD_MIN kart lengths of the fight ahead of you.
ArenaCam.PHONE_SHORT = 500 -- px: a screen whose short side is this or less is a phone
ArenaCam.PHONE_DISTANCE = 4
ArenaCam.PHONE_PITCH = 30
ArenaCam.PHONE_FOV = 44
ArenaCam.PHONE_FOV_FAST = 2
ArenaCam.MIN_SHARE = 0.1 -- your kart's width, of the screen's width (phone)
ArenaCam.KART_LONG = 5.5 * 0.25 -- studs (Weapons.KART)
ArenaCam.KART_WIDE = 0.55 * ArenaCam.KART_LONG -- studs (a kart is 1 x 0.55 KART)
ArenaCam.PHONE_AHEAD_MIN = 8 -- kart lengths still seen ahead of your kart (the fight round you)
-- Lead 10-29 (Studio: the close camera put the back wheels on the bottom edge, under the thumbs):
-- on a phone the kart's middle sits 70% down the screen, and the look-ahead leans much less (a
-- full 2-stud lean at 4 studs away pushed the kart down to ~85%).
ArenaCam.PHONE_LOW = 0.4 -- of the half screen below the middle: 70% down
ArenaCam.PHONE_LEAN = 0.2 -- of the big camera's lean

export type Fit = {
	distance: number,
	pitch: number,
	fov: number,
	fast: number,
	low: number, -- the kart's middle, this far below the screen's middle (of the half screen)
	lean: number, -- the look-ahead lean, as a share of LEAD_MAX
}

-- A touch screen with no keyboard up to this short side is a phone too (a big phone that reports
-- more points than an iPhone); a tablet (768+) keeps the big camera.
ArenaCam.TOUCH_SHORT = 700
-- Studio only: workspace TestPhoneCam = true forces the phone camera on any screen (Studio's
-- view is 1914 x 604, never phone-shaped), so the auditor can see the phone view.
ArenaCam.TEST_ATTR = "TestPhoneCam"

-- Is this screen a phone (the close camera)? `forced`: the Studio test switch.
function ArenaCam.isPhone(
	w: number,
	h: number,
	touch: boolean?,
	keyboard: boolean?,
	forced: boolean?
): boolean
	local short = math.min(w, h)
	return forced == true
		or short <= ArenaCam.PHONE_SHORT
		or (touch == true and keyboard ~= true and short <= ArenaCam.TOUCH_SHORT)
end

-- The Studio test switch: on only in Studio and only when the attribute is exactly true.
function ArenaCam.forced(isStudio: boolean, attr: unknown): boolean
	return isStudio and attr == true
end

-- The camera for a screen `w` x `h` px: a phone's close one, or the big screen's. `phone` (from
-- isPhone) wins when given; without it the screen's size decides.
function ArenaCam.fit(w: number, h: number, phone: boolean?): Fit
	local isPhone = if phone == nil then math.min(w, h) <= ArenaCam.PHONE_SHORT else phone
	if isPhone then
		return {
			distance = ArenaCam.PHONE_DISTANCE,
			pitch = ArenaCam.PHONE_PITCH,
			fov = ArenaCam.PHONE_FOV,
			fast = ArenaCam.PHONE_FOV_FAST,
			low = ArenaCam.PHONE_LOW,
			lean = ArenaCam.PHONE_LEAN,
		}
	end
	return {
		distance = ArenaCam.DISTANCE,
		pitch = ArenaCam.PITCH,
		fov = ArenaCam.FOV,
		fast = ArenaCam.FOV_FAST,
		low = ArenaCam.KART_LOW,
		lean = 1,
	}
end

-- How much (0..1) of a `w` x `h` screen's width your kart fills, seen from behind at `distance`
-- studs with a vertical field of view of `fov` degrees.
function ArenaCam.share(w: number, h: number, distance: number, fov: number): number
	local seen = 2 * distance * math.tan(math.rad(fov) / 2) * (w / math.max(h, 1))
	return ArenaCam.KART_WIDE / seen
end

-- How far ahead of the kart (studs, along the ground) the top of the screen reaches, with the
-- kart in the lower third (math.huge: up to the sky).
function ArenaCam.seeAhead(
	distance: number,
	pitch: number,
	fov: number,
	low: number?,
	drop: number?
): number
	local back, up = ArenaCam.offset(distance, pitch)
	-- the screen's top edge: the view's middle (tipped up by the lower-third aim, at the kart's
	-- middle `drop` below the followed spot), then half the field of view above it
	local half = math.rad(fov) / 2
	local look = math.atan2(up + (drop or 0), back)
		- math.atan(math.tan(half) * (low or ArenaCam.KART_LOW))
		- half
	if look <= 0 then
		return math.huge
	end
	return up / math.tan(look) - back
end

-- The camera's spot as an offset from the kart: `back` studs behind it and `up` studs above.
function ArenaCam.offset(distance: number?, pitch: number?): (number, number)
	local d = distance or ArenaCam.DISTANCE
	local p = math.rad(pitch or ArenaCam.PITCH)
	return d * math.cos(p), d * math.sin(p)
end

-- How far ahead of the kart (studs, along the ground) the camera aims, so the kart itself shows
-- `low` of the half-screen below the middle (KART_LOW = lower third). `drop`: studs the kart's
-- middle sits below the point the camera follows (ChaseCamera follows a spot above the body).
function ArenaCam.aimAhead(
	distance: number?,
	pitch: number?,
	fov: number?,
	low: number?,
	drop: number?
): number
	local back, up = ArenaCam.offset(distance, pitch)
	local p = math.atan2(up + (drop or 0), back) -- down to the kart's middle
	local half = math.rad((fov or ArenaCam.FOV) / 2)
	-- the angle between the middle of the screen and the kart, for that screen spot
	local off = math.atan(math.tan(half) * (low or ArenaCam.KART_LOW))
	local look = math.max(p - off, math.rad(5))
	return up / math.tan(look) - back
end

-- Where the kart's middle lands, as a share of the screen's height from the top (0.5 = the
-- middle), for a camera `distance`/`pitch`/`fov` aiming `ahead` + `lean` studs past the followed
-- point, with the kart's middle `drop` studs below it.
function ArenaCam.kartDown(
	distance: number,
	pitch: number,
	fov: number,
	ahead: number,
	lean: number,
	drop: number
): number
	local back, up = ArenaCam.offset(distance, pitch)
	local look = math.atan2(up, back + ahead + lean)
	local below = math.atan2(up + drop, back) - look
	return 0.5 + 0.5 * math.tan(below) / math.tan(math.rad(fov) / 2)
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
