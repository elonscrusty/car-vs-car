--!strict
-- See your kart (auditor R7-5, Studio round 6 shot 3): when an arena prop (a post, a wall, a
-- tree) sits between the camera and your kart, it fades to see-through and comes back once it
-- is out of the way. Pure rules here so Lune can test them; client/SeeKart.client plays them.
-- Driving and the chase camera stay LOCKED: this only changes what you can see through.
local SeeKart = {}

SeeKart.FADE = 0.7 -- LocalTransparencyModifier while in the way
SeeKart.HOLD = 0.25 -- seconds it stays faded after it stops blocking (no flicker)
SeeKart.MAX_FADED = 8 -- never more at once (phones)
SeeKart.BIG = 60 -- a part this wide (studs, flat) is ground or a hill, never faded
SeeKart.PAD = 0.5 -- studs added round a faded part when checking it still blocks

export type Hit = {
	normalY: number, -- the hit face's normal, Y part
	hitY: number, -- where the ray hit, height
	kartY: number, -- your kart's height
	size: { x: number, y: number, z: number },
	kart: boolean, -- part of any kart (or a character)
	terrain: boolean,
	transparency: number,
}

-- Should this hit be left alone? Floors, ground, hills, karts and things already see-through.
function SeeKart.skip(h: Hit): boolean
	if h.kart or h.terrain or h.transparency >= 0.95 then
		return true
	end
	-- the floor (a top face at or below the kart)
	if h.normalY > 0.7 and h.hitY <= h.kartY + 1 then
		return true
	end
	-- big flat pieces: the ground, a hill, a ramp
	local wide = math.max(h.size.x, h.size.z)
	if wide >= SeeKart.BIG and h.size.y < wide then
		return true
	end
	return false
end

export type V3 = { x: number, y: number, z: number }

-- Does the line from a to b (both in the part's own space) pass through its box (half sizes,
-- padded by PAD)? The slab test.
function SeeKart.segmentHitsBox(a: V3, b: V3, half: V3): boolean
	local t0, t1 = 0, 1
	for _, axis in { "x", "y", "z" } do
		local s, e, h = (a :: any)[axis], (b :: any)[axis], (half :: any)[axis] + SeeKart.PAD
		local d = e - s
		if math.abs(d) < 1e-9 then
			if s < -h or s > h then
				return false
			end
		else
			local u0, u1 = (-h - s) / d, (h - s) / d
			if u0 > u1 then
				u0, u1 = u1, u0
			end
			t0 = math.max(t0, u0)
			t1 = math.min(t1, u1)
			if t0 > t1 then
				return false
			end
		end
	end
	return true
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
