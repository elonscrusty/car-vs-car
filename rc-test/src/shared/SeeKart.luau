--!strict
-- See your kart (auditor R7-5, Studio round 6 shot 3): when an arena prop (a post, a cover wall,
-- a tree, a crate) sits between the camera and your kart, it fades to see-through on your screen
-- and comes back once it is out of the way. Pure rules here so Lune can test them;
-- client/SeeKart.client plays them. Driving and the chase camera stay LOCKED.
--   * Only named arena props ever fade (PROPS): never the floor, road, hills, ramps, the outer
--     wall, karts or people. Many prop pieces (tree crowns, crate bands) can't be hit by rays,
--     so the check is box maths on each prop, no ray at all: a quick ball test first, then the
--     exact box.
local SeeKart = {}

SeeKart.FADE = 0.7 -- LocalTransparencyModifier while in the way
SeeKart.HOLD = 0.25 -- seconds it stays faded after it stops blocking (no flicker)
SeeKart.MAX_FADED = 12 -- never more at once (phones)
SeeKart.PAD = 0.15 -- studs added round a prop (the arena is built at RC size, 1/4)
-- the line stops this far short of the kart's centre, so a prop just past the kart never fades
-- (Studio round 8 shot 3: a bush behind the kart)
SeeKart.KART_MARGIN = 0.9
-- a prop this close to the camera fades even off the line: it fills the screen edge (round 8,
-- 13 s: a white tree stick beside the camera)
SeeKart.NEAR_CAM = 0.7 -- (the chase camera is only ~2.6 studs from the kart at RC size)

-- ArenaBuilder part names that may fade (workspace.SmashArena). Not the low red Bumper: the kart
-- sits taller than it, so it would fade a long strip for nothing.
SeeKart.PROPS = {
	Cover = true,
	CoverCap = true,
	TreeStick = true,
	TreeTop = true,
	Crate = true,
	CrateBand = true,
	Barrel = true,
	BarrelBand = true,
	Rock = true,
	Bush = true,
	WallPillar = true,
	ArchPillar = true,
	ArchCap = true,
	ArchBeam = true,
	ArchFlag = true,
} :: { [string]: boolean }

-- Is a point within `r` of the line from a to b? (the quick ball test)
function SeeKart.near(
	ax: number,
	ay: number,
	az: number,
	bx: number,
	by: number,
	bz: number,
	cx: number,
	cy: number,
	cz: number,
	r: number
): boolean
	local dx, dy, dz = bx - ax, by - ay, bz - az
	local len2 = dx * dx + dy * dy + dz * dz
	local t = 0
	if len2 > 1e-12 then
		t = math.clamp(((cx - ax) * dx + (cy - ay) * dy + (cz - az) * dz) / len2, 0, 1)
	end
	local px, py, pz = ax + dx * t - cx, ay + dy * t - cy, az + dz * t - cz
	return px * px + py * py + pz * pz <= r * r
end

local function slab(s: number, e: number, h: number, t0: number, t1: number): (number, number)
	local d = e - s
	if math.abs(d) < 1e-9 then
		if s < -h or s > h then
			return 1, 0
		end
		return t0, t1
	end
	local u0, u1 = (-h - s) / d, (h - s) / d
	if u0 > u1 then
		u0, u1 = u1, u0
	end
	return math.max(t0, u0), math.min(t1, u1)
end

-- Does the line from a to b (both in the part's own space) pass through its box (half sizes
-- hx, hy, hz, padded by PAD)?
function SeeKart.segmentHitsBox(
	ax: number,
	ay: number,
	az: number,
	bx: number,
	by: number,
	bz: number,
	hx: number,
	hy: number,
	hz: number
): boolean
	local p = SeeKart.PAD
	local t0, t1 = slab(ax, bx, hx + p, 0, 1)
	if t0 > t1 then
		return false
	end
	t0, t1 = slab(ay, by, hy + p, t0, t1)
	if t0 > t1 then
		return false
	end
	t0, t1 = slab(az, bz, hz + p, t0, t1)
	return t0 <= t1
end

-- Is the point a (in the part's own space) within `d` studs of its box?
function SeeKart.pointNearBox(
	ax: number,
	ay: number,
	az: number,
	hx: number,
	hy: number,
	hz: number,
	d: number
): boolean
	return math.abs(ax) <= hx + d and math.abs(ay) <= hy + d and math.abs(az) <= hz + d
end

-- Does this prop get in the way? a = the camera, b = the kart's centre, both in the part's own
-- space; hx, hy, hz = its half size. Either it sits on the line from the camera to KART_MARGIN
-- short of the kart, or it is right beside the camera.
function SeeKart.blocks(
	ax: number,
	ay: number,
	az: number,
	bx: number,
	by: number,
	bz: number,
	hx: number,
	hy: number,
	hz: number
): boolean
	if SeeKart.pointNearBox(ax, ay, az, hx, hy, hz, SeeKart.NEAR_CAM) then
		return true
	end
	local dx, dy, dz = bx - ax, by - ay, bz - az
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	if len <= SeeKart.KART_MARGIN then
		return false
	end
	local k = (len - SeeKart.KART_MARGIN) / len
	return SeeKart.segmentHitsBox(ax, ay, az, ax + dx * k, ay + dy * k, az + dz * k, hx, hy, hz)
end

-- Should a part we faded be put back to what it was? Only if it still shows our fade (the
-- property is a float32, so 0.7 reads back as 0.69999...: compare loosely).
function SeeKart.ours(modifier: number): boolean
	return math.abs(modifier - SeeKart.FADE) < 1e-3
end

-- Leave alone a part another script already hid more than we would (e.g. TopViewClear sets 1).
function SeeKart.hiddenAlready(modifier: number): boolean
	return modifier >= SeeKart.FADE + 1e-3
end

-- What's faded right now, and when each last blocked the view.
export type Fader<K> = {
	seen: { [K]: number },
	count: number,
	add: (self: Fader<K>, key: K, now: number) -> boolean,
	keep: (self: Fader<K>, key: K, now: number) -> (),
	drop: (self: Fader<K>, key: K) -> (),
	due: (self: Fader<K>, now: number) -> { K },
}

local Fader = {}
Fader.__index = Fader

local NONE = table.freeze({})

-- start fading `key`; false when it's already faded or the list is full
function Fader.add<K>(self: Fader<K>, key: K, now: number): boolean
	if self.seen[key] ~= nil or self.count >= SeeKart.MAX_FADED then
		return false
	end
	self.seen[key] = now
	self.count += 1
	return true
end

-- it still blocks the view
function Fader.keep<K>(self: Fader<K>, key: K, now: number)
	if self.seen[key] ~= nil then
		self.seen[key] = now
	end
end

function Fader.drop<K>(self: Fader<K>, key: K)
	if self.seen[key] ~= nil then
		self.seen[key] = nil
		self.count -= 1
	end
end

-- the ones that stopped blocking HOLD seconds ago: taken off the list, to be shown again
function Fader.due<K>(self: Fader<K>, now: number): { K }
	if self.count == 0 then
		return NONE :: any
	end
	local out = {}
	for key, at in self.seen do
		if now - at >= SeeKart.HOLD then
			table.insert(out, key)
		end
	end
	for _, key in out do
		self:drop(key)
	end
	return out
end

function SeeKart.fader<K>(): Fader<K>
	return setmetatable({ seen = {}, count = 0 }, Fader) :: any
end

return SeeKart
