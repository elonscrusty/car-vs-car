--!strict
-- The Smash arena (carter's OK 10-28 22:00: plans/smash/arena-topdown-v2.png, script arena2.py).
-- Everything is copied from the picture in picture units (0..240, 0,0 = top-left, y down), then
-- turned into map-local big units: 0,0 at the arena's middle, K big units per picture unit,
-- picture up = -Z. Built big like the race maps and shrunk to RC size (TrackData.RC_SCALE), so
-- the karts are the same RC karts as before. Pure numbers: Lune tests, bots and the builder all
-- read this.

local ArenaData = {}

export type Pt = { number } -- {x, y} in picture units
export type Spot = { x: number, y: number, z: number, dx: number, dz: number }
export type Hill = { name: string, poly: { Pt }, h: number }
export type Ramp = { from: Pt, to: Pt, width: number, h: number }

ArenaData.id = "arena"
ArenaData.K = 1.5 -- big units per picture unit (a kart is 3 x 5.5 big)
ArenaData.PIC = 240 -- the picture is 240 x 240
ArenaData.SIZE = ArenaData.PIC * ArenaData.K -- 360 big = 90 RC studs, wall to wall outside
ArenaData.WALL = 6 -- purple outer wall thickness (picture units)
ArenaData.WALL_H = 14 -- big units: far over a kart, so nothing leaves the arena
-- where the arena sits at RC size (the middle, in RC studs) and its turn
ArenaData.RC_X, ArenaData.RC_Z, ArenaData.RC_ANGLE = 0, -3000, 0

-- picture point -> map-local big units (x, z)
function ArenaData.at(p: Pt): (number, number)
	local k = ArenaData.K
	return (p[1] - ArenaData.PIC / 2) * k, (p[2] - ArenaData.PIC / 2) * k
end

-- the winding S road (a closed Catmull-Rom loop through these), red/white curb both sides
ArenaData.ROAD = {
	{ 40, 60 },
	{ 70, 35 },
	{ 150, 32 },
	{ 195, 45 },
	{ 210, 85 },
	{ 185, 120 },
	{ 150, 128 },
	{ 130, 150 },
	{ 150, 180 },
	{ 200, 190 },
	{ 205, 215 },
	{ 150, 222 },
	{ 70, 215 },
	{ 35, 185 },
	{ 30, 120 },
} :: { Pt }
ArenaData.ROAD_W = 20 -- picture units, curb not counted
ArenaData.CURB = 2 -- each side
-- crosswalks: middle and which way the stripes run (true = the road runs left-right there)
ArenaData.CROSSWALKS = {
	{ at = { 110, 33 }, across = true },
	{ at = { 31, 120 }, across = false },
	{ at = { 110, 220 }, across = true },
} :: { { at: Pt, across: boolean } }

-- the sand patch inside the west loop: a low red bumper wall round it, open on the road sides
ArenaData.SAND =
	{ { 60, 80 }, { 95, 70 }, { 115, 95 }, { 100, 170 }, { 70, 190 }, { 55, 160 } } :: { Pt }
-- the gaps in the bumper wall: {edge index (from SAND[i] to SAND[i+1]), start, end} along it 0..1
ArenaData.SAND_GAPS = { { 3, 0.3, 0.55 }, { 6, 0.3, 0.6 } } :: { { number } }
ArenaData.BUMPER_H = 2.4 -- big: a kart can't climb it, so the gaps are the way in
ArenaData.BUMPER_W = 2 -- picture units

-- the pink hills (flat-topped, cliff sides), heights in big units
ArenaData.HILLS = {
	{
		name = "HighPink",
		poly = { { 150, 60 }, { 185, 62 }, { 190, 95 }, { 160, 108 }, { 140, 95 } },
		h = 8,
	},
	{ name = "LowPink", poly = { { 160, 140 }, { 215, 140 }, { 220, 175 }, { 170, 172 } }, h = 4 },
} :: { Hill }
-- ramps up onto them (picture units, from the low end to the top end), gentle: under 18 degrees
ArenaData.RAMPS = {
	-- each runs square to its hill's cliff edge and ends just inside it, so there is no gap
	{ from = { 126.2, 81.3 }, to = { 143.1, 86.1 }, width = 12, h = 8 },
	{ from = { 152.1, 160 }, to = { 165.5, 155.9 }, width = 12, h = 4 },
} :: { Ramp }

-- the purple step in the north-west corner (start spot 1 is on it)
ArenaData.STEP = { { 10, 10 }, { 45, 10 }, { 25, 40 }, { 10, 40 } } :: { Pt }
ArenaData.STEP_H = 1.5

-- orange cover walls (segments, picture units)
ArenaData.COVER = {
	{ { 120, 115 }, { 140, 112 } },
	{ { 110, 190 }, { 135, 200 } },
	{ { 175, 30 }, { 195, 38 } },
} :: { { Pt } }
ArenaData.COVER_W, ArenaData.COVER_H = 4, 6 -- picture units thick, big units tall

-- lollipop trees: a solid stick, a candy top up high
ArenaData.TREES =
	{ { 120, 62 }, { 226, 125 }, { 122, 170 }, { 18, 220 }, { 226, 18 }, { 170, 205 } } :: { Pt }
ArenaData.TREE_R = 7 -- the candy top's radius in the picture

-- the 12 start spots (picture), numbered like the picture
ArenaData.START = {
	{ 20, 20 },
	{ 120, 15 },
	{ 225, 60 },
	{ 225, 225 },
	{ 120, 229 }, -- the picture has it on the wall: nudged in
	{ 15, 150 },
	{ 80, 48 },
	{ 200, 105 },
	{ 100, 205 },
	{ 55, 200 },
	{ 175, 125 },
	{ 15, 80 },
} :: { Pt }

-- "?" box spots: the picture's 17, then 5 more in the corners and gaps it left farthest from a box
ArenaData.BOXES = {
	{ 55, 45 },
	{ 150, 35 },
	{ 205, 70 },
	{ 200, 125 },
	{ 140, 130 },
	{ 165, 85 },
	{ 190, 200 },
	{ 140, 215 },
	{ 80, 218 },
	{ 35, 165 },
	{ 33, 95 },
	{ 85, 105 },
	{ 85, 160 },
	{ 115, 140 },
	{ 190, 160 },
	{ 225, 170 },
	{ 20, 50 },
	{ 30, 228 },
	{ 212, 12 },
	{ 100, 12 },
	{ 106, 60 },
	{ 214, 228 },
} :: { Pt }

-- Is picture point p inside polygon poly?
function ArenaData.inside(poly: { Pt }, p: Pt): boolean
	local inside = false
	local j = #poly
	for i = 1, #poly do
		local a, b = poly[i], poly[j]
		if (a[2] > p[2]) ~= (b[2] > p[2]) then
			local x = (b[1] - a[1]) * (p[2] - a[2]) / (b[2] - a[2]) + a[1]
			if p[1] < x then
				inside = not inside
			end
		end
		j = i
	end
	return inside
end

-- The floor's top (big units) at a picture point: a hill, the step, a ramp, else 0.
function ArenaData.groundAt(p: Pt): number
	for _, h in ArenaData.HILLS do
		if ArenaData.inside(h.poly, p) then
			return h.h
		end
	end
	if ArenaData.inside(ArenaData.STEP, p) then
		return ArenaData.STEP_H
	end
	for _, r in ArenaData.RAMPS do
		local ax, ay = r.to[1] - r.from[1], r.to[2] - r.from[2]
		local len = math.sqrt(ax * ax + ay * ay)
		local u = ((p[1] - r.from[1]) * ax + (p[2] - r.from[2]) * ay) / (len * len)
		local side = math.abs((p[1] - r.from[1]) * ay - (p[2] - r.from[2]) * ax) / len
		if u >= 0 and u <= 1 and side <= r.width / 2 then
			return r.h * u
		end
	end
	return 0
end

-- start spots (map-local big units), each facing the arena's middle
ArenaData.spawns = {} :: { Spot }
for _, p in ArenaData.START do
	local x, z = ArenaData.at(p)
	local n = math.max(math.sqrt(x * x + z * z), 1e-6)
	table.insert(
		ArenaData.spawns,
		{ x = x, y = ArenaData.groundAt(p) + 2.5, z = z, dx = -x / n, dz = -z / n }
	)
end

-- box spots (map-local big units, y = the floor's top there). Plain {x, y, z} so Lune can test
-- it; turn one into a world spot with TrackData.toWorld(ArenaData.track(), true, s.x, s.y, s.z).
export type Pos = { x: number, y: number, z: number }
ArenaData.boxSpots = {} :: { Pos }
for _, p in ArenaData.BOXES do
	local x, z = ArenaData.at(p)
	table.insert(ArenaData.boxSpots, { x = x, y = ArenaData.groundAt(p), z = z })
end

-- The arena as a track (TrackData.Track), so the driving code places karts in it like a map.
function ArenaData.track(): any -- a TrackData.Track (Lune can't load the type here)
	local s = ArenaData.spawns[1]
	return {
		id = ArenaData.id,
		label = "ARENA",
		originX = 0,
		mode = "arena",
		grip = 1,
		spawn = { x = s.x, y = s.y, z = s.z, dx = s.dx, dz = s.dz },
		gates = {},
		rcX = ArenaData.RC_X,
		rcZ = ArenaData.RC_Z,
		rcAngle = ArenaData.RC_ANGLE,
		map = ArenaData.id,
	}
end

-- The arena's light (LOOK RULE: warm sun, bloom), put on while the camera is in the arena.
ArenaData.lighting = {
	ClockTime = 14,
	GeographicLatitude = 25,
	Brightness = 3,
	ExposureCompensation = 0.15,
	ShadowSoftness = 0.3,
	EnvironmentDiffuseScale = 0.7,
	EnvironmentSpecularScale = 0.3,
}
ArenaData.ambient = { 140, 130, 150 }
ArenaData.outdoorAmbient = { 170, 160, 175 }
ArenaData.colorCorrection =
	{ Brightness = 0.03, Contrast = 0.08, Saturation = 0.2, tint = { 255, 246, 232 } }
ArenaData.bloom = { Intensity = 0.4, Size = 24, Threshold = 1.4 }

return ArenaData
