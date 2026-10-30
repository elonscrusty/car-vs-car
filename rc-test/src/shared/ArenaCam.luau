--!strict
-- The match camera (carter 10-29 11:33: "it's hard to tell what's going on with this camera
-- angle"). A Smash Karts style chase cam: still behind your kart and turning with it (carter
-- 10-19: a fixed overhead view is boring), but higher, further back and tilted down, so your
-- kart sits in the lower third and the karts and boxes around it show on a phone. Every number
-- lives here; client/ChaseCamera uses them only while you are in a match (InMatch), and the
-- lobby and race cameras stay as they were. Plain maths: Lune tests it.
-- Studs are at the arena's RC size (TrackData.RC_SCALE 0.25: a kart is ~1.4 studs long).

local ArenaCam = {}

-- carter 10-30 (batch 1, Studio on PC): 9 studs at 40 deg was "way too close and way too high":
-- further back and lower, so you see what is ahead of you
ArenaCam.DISTANCE = 11.5 -- studs from the kart to the camera (~8 kart lengths; fits ArenaData.CAM_BACK)
ArenaCam.PITCH = 30 -- degrees the camera looks down at the kart
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

-- Phone-shaped screens. carter 10-29 15:56: the close phone camera (4 studs back, 30 deg down)
-- was "terrible", you couldn't see the fight. He picked try A of three real match pictures
-- (/mnt/project-files/car-vs-car/camera/camera-tries-1.jpg): back and up, Smash Karts style, so
-- the road, walls, ? boxes and karts round you show, and your kart is still easy to find.
ArenaCam.PHONE_SHORT = 500 -- px: a screen whose short side is this or less is a phone
ArenaCam.PHONE_DISTANCE = 8
ArenaCam.PHONE_PITCH = 45
ArenaCam.PHONE_FOV = 50
ArenaCam.PHONE_FOV_FAST = 4
-- Speed zoom (carter 10-29, try A of 4 on camera/speed-zoom.html): at top speed the camera slides
-- this share further back (18%), and the view is PHONE_FOV_FAST wider. It eases out slowly and
-- back in at once, the same as the wall check does (ChaseCamera).
ArenaCam.PHONE_BACK_FAST = 0.18
-- your kart's width, of the screen's width (phone): try A shows it ~4.7% wide, small but clear
ArenaCam.MIN_SHARE = 0.04
-- (at top speed, pulled back and wider: carter picked A knowing the kart is a little smaller)
ArenaCam.MIN_SHARE_FAST = 0.034
ArenaCam.KART_LONG = 5.5 * 0.25 -- studs (Weapons.KART)
ArenaCam.KART_WIDE = 0.55 * ArenaCam.KART_LONG -- studs (a kart is 1 x 0.55 KART)
ArenaCam.PHONE_AHEAD_MIN = 8 -- kart lengths still seen ahead of your kart (the fight round you)
-- No look-ahead lean on a phone, so the kart stays put on the screen, standing or at speed.
-- Studio r57 (#1016): aim at the kart you SEE (CarSkin's skin, down to the ground), not the
-- smaller physics box above it: ChaseCamera passes the skin's middle as drop/fwd.
ArenaCam.PHONE_LOW = 0.35 -- of the half screen below the middle: ~68% down (try A)
ArenaCam.PHONE_LEAN = 0 -- of the big camera's lean

-- carter 10-30 (batch 1 play): "it needs to be further behind the car so I can see more in front
-- of me". Two tries over the normal fit, on every screen: press T in a match to go 1 -> 2 -> off.
-- Try 1 is on from the start. After his pick, the numbers move into the fit and this goes.
ArenaCam.TRIES = {
	-- (round 2, carter: 13 studs was "way too far back, scoot in a little")
	{ distance = 10, pitch = 32, low = 0.5 },
	{ distance = 11.5, pitch = 29, low = 0.5 },
} :: { { distance: number, pitch: number, low: number } }
ArenaCam.TRY_START = 1

export type Fit = {
	distance: number,
	pitch: number,
	fov: number,
	fast: number, -- degrees wider at top speed
	back: number, -- share further back at top speed
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

-- Come-back camera (carter 10-29, try C "whoosh" of 4 on camera/comeback.html): when you respawn
-- in a match the camera starts wide, high and spun round your new kart, and spirals in to the
-- chase spot, the view narrowing as it lands. Looks only: the camera ends exactly where the
-- match camera always sits.
ArenaCam.COMEBACK_SECONDS = 1.25
ArenaCam.COMEBACK_RADIUS = 14 -- studs out from the kart at the start
ArenaCam.COMEBACK_HEIGHT = 11 -- studs above it at the start
ArenaCam.COMEBACK_TURN = 1.35 * math.pi -- radians still to turn round the kart at the start
ArenaCam.COMEBACK_FOV = 28 -- degrees wider at the start (falls off as k squared)

-- The whoosh `t` s after the respawn, for a match camera `flatBack` studs behind the kart and
-- `up` above it: (turn left to go round the kart in radians, distance out along the ground,
-- height, extra degrees of field of view). At COMEBACK_SECONDS and after: (0, flatBack, up, 0).
function ArenaCam.comeBack(
	t: number,
	flatBack: number,
	up: number
): (number, number, number, number)
	local u = math.clamp(t / ArenaCam.COMEBACK_SECONDS, 0, 1)
	local k = 1 - (1 - u) ^ 3 -- fast at first, settles slowly
	return (1 - k) * ArenaCam.COMEBACK_TURN,
		(1 - k) * ArenaCam.COMEBACK_RADIUS + k * flatBack,
		(1 - k) * ArenaCam.COMEBACK_HEIGHT + k * up,
		(1 - k) * (1 - k) * ArenaCam.COMEBACK_FOV
end

-- Match start fly-in (carter 10-29, try C "orbit down" of 4 on camera/match-fly-in.html): the
-- match opens high over the arena, circling it, and spirals down onto your kart. It lands
-- exactly on the match camera. A kart that starts driving speeds it up (a 3 s swoop never
-- keeps you from driving: ChaseCamera runs its clock FLYIN_RUSH times faster while you move).
ArenaCam.FLYIN_SECONDS = 3
ArenaCam.FLYIN_RADIUS = 44 -- studs out from the middle of the arena at the start
ArenaCam.FLYIN_HEIGHT = 40 -- studs up at the start
ArenaCam.FLYIN_TURN = 1.5 * math.pi -- radians still to turn at the start
ArenaCam.FLYIN_FOV = 10 -- degrees wider at the start
ArenaCam.FLYIN_RUSH = 3
ArenaCam.FLYIN_WALLS = 0.85 -- from this far in the wall check holds the camera off the walls

-- The fly-in `t` s after the match began, for a match camera `flatBack` studs behind the kart and
-- `up` above it: (k 0..1 = how far down and in, turn left in radians, distance out along the
-- ground, height, extra degrees of view). The caller circles a point k of the way from the
-- arena's middle to your kart. At FLYIN_SECONDS and after: (1, 0, flatBack, up, 0).
function ArenaCam.flyIn(
	t: number,
	flatBack: number,
	up: number
): (number, number, number, number, number)
	local u = math.clamp(t / ArenaCam.FLYIN_SECONDS, 0, 1)
	local k = 1 - (1 - u) ^ 3 -- fast at first, settles slowly
	return k,
		(1 - k) * ArenaCam.FLYIN_TURN,
		(1 - k) * ArenaCam.FLYIN_RADIUS + k * flatBack,
		(1 - k) * ArenaCam.FLYIN_HEIGHT + k * up,
		(1 - k) * ArenaCam.FLYIN_FOV
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
			back = ArenaCam.PHONE_BACK_FAST,
			low = ArenaCam.PHONE_LOW,
			lean = ArenaCam.PHONE_LEAN,
		}
	end
	return {
		distance = ArenaCam.DISTANCE,
		pitch = ArenaCam.PITCH,
		fov = ArenaCam.FOV,
		fast = ArenaCam.FOV_FAST,
		back = 0, -- (the big screen keeps its camera: carter's speed zoom pick was a phone one)
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
	drop: number?,
	fwd: number?
): number
	local back, up = ArenaCam.offset(distance, pitch)
	-- the screen's top edge: the view's middle (tipped up by the lower-third aim, at the kart's
	-- middle `drop` below and `fwd` ahead of the followed spot), then half the field of view above
	local half = math.rad(fov) / 2
	local look = math.atan2(up + (drop or 0), back + (fwd or 0))
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
-- middle sits below the point the camera follows (ChaseCamera follows a spot above the body);
-- `fwd`: studs it sits ahead of that point (behind when below 0).
function ArenaCam.aimAhead(
	distance: number?,
	pitch: number?,
	fov: number?,
	low: number?,
	drop: number?,
	fwd: number?
): number
	local back, up = ArenaCam.offset(distance, pitch)
	local p = math.atan2(up + (drop or 0), back + (fwd or 0)) -- down to the kart's middle
	local half = math.rad((fov or ArenaCam.FOV) / 2)
	-- the angle between the middle of the screen and the kart, for that screen spot
	local off = math.atan(math.tan(half) * (low or ArenaCam.KART_LOW))
	local look = math.max(p - off, math.rad(5))
	return up / math.tan(look) - back
end

-- Where the kart's middle lands, as a share of the screen's height from the top (0.5 = the
-- middle), for a camera `distance`/`pitch`/`fov` aiming `ahead` + `lean` studs past the followed
-- point, with the kart's middle `drop` studs below it and `fwd` studs ahead of it.
function ArenaCam.kartDown(
	distance: number,
	pitch: number,
	fov: number,
	ahead: number,
	lean: number,
	drop: number,
	fwd: number?
): number
	local back, up = ArenaCam.offset(distance, pitch)
	local look = math.atan2(up, back + ahead + lean)
	local below = math.atan2(up + drop, back + (fwd or 0)) - look
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
