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
-- a flat-topped hill: its sides slope in `slope` picture units from the foot to the top edge
export type Hill = { name: string, poly: { Pt }, h: number, slope: number }
export type Ramp = { from: Pt, to: Pt, width: number, h: number }

ArenaData.id = "arena"
ArenaData.K = 1.5 -- big units per picture unit (a kart is 3 x 5.5 big)
ArenaData.PIC = 240 -- the picture is 240 x 240
ArenaData.SIZE = ArenaData.PIC * ArenaData.K -- 360 big = 90 RC studs, wall to wall outside
ArenaData.WALL = 6 -- purple outer wall thickness (picture units)
ArenaData.WALL_H = 10 -- big units: well over a kart, low enough for the chase cam to see over
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
ArenaData.BUMPER_W = 3 -- picture units

-- the pink hills (flat-topped, steep faceted sides a kart can't climb), heights in big units
ArenaData.HILLS = {
	{
		name = "HighPink",
		poly = { { 150, 60 }, { 185, 62 }, { 190, 95 }, { 160, 108 }, { 140, 95 } },
		h = 11,
		slope = 3,
	},
	{
		name = "LowPink",
		poly = { { 160, 140 }, { 215, 140 }, { 220, 175 }, { 170, 172 } },
		h = 8,
		slope = 1.8,
	},
} :: { Hill }
-- ramps up onto them (picture units, from the low end to the top end), gentle: under 18 degrees
ArenaData.RAMPS = {
	-- each runs square to its hill's cliff edge and ends just inside it, so there is no gap
	{ from = { 120.3, 79.6 }, to = { 143.1, 86.1 }, width = 14, h = 11 },
	{ from = { 149.4, 159.1 }, to = { 166.1, 154.0 }, width = 14, h = 8 },
} :: { Ramp }
-- each ramp's top runs on as a flat deck this far (picture units) over the hill's sloped edge
ArenaData.RAMP_DECK = 5

-- the purple platform in the north-west corner (start spot 1 is on it): against the outer wall on
-- two sides, gentle slopes a kart drives down (and up) on the other two (STEP_SIDES: edge numbers)
ArenaData.STEP = { { 6, 6 }, { 52, 6 }, { 30, 44 }, { 6, 44 } } :: { Pt }
ArenaData.STEP_H = 3
ArenaData.STEP_SLOPE = 7
ArenaData.STEP_SIDES = { 2, 3 }

-- orange cover walls (segments, picture units)
ArenaData.COVER = {
	{ { 120, 115 }, { 140, 112 } },
	{ { 110, 190 }, { 135, 200 } },
	{ { 175, 30 }, { 195, 38 } },
} :: { { Pt } }
ArenaData.COVER_W, ArenaData.COVER_H = 5, 10 -- picture units thick, big units tall

-- lollipop trees: a solid trunk, a candy top up high
ArenaData.TREES =
	{ { 120, 62 }, { 226, 125 }, { 122, 170 }, { 18, 220 }, { 226, 18 }, { 170, 205 } } :: { Pt }
ArenaData.TREE_R = 7 -- the candy top's radius in the picture
ArenaData.TRUNK = 5 -- the trunk's thickness, big units

-- extra cover on the open grass (picture units): low-poly rocks {x, y, radius}, crates (a 4 x 4
-- block each), red barrel rows (from, to)
ArenaData.ROCKS = {
	{ 60, 63, 3 },
	{ 228, 36, 2.5 },
	{ 12, 192, 2.5 },
	{ 75, 135, 3 },
	{ 148, 108, 2.5 },
	{ 230, 150, 2.5 },
} :: { { number } }
ArenaData.CRATES = { { 88, 62 }, { 122, 104 }, { 224, 110 } } :: { Pt }
ArenaData.CRATE = 4
ArenaData.BARRELS = {
	{ { 112, 154 }, { 112, 166 } },
	{ { 92, 88 }, { 100, 96 } },
} :: { { Pt } }
ArenaData.BARREL_R = 1.5

-- the start arch over the west crosswalk (the road runs north-south there): two solid pillars
-- just off the road, a beam up high
ArenaData.ARCH = { at = { 31, 120 }, pillarOff = 15, pillar = 3, h = 24 }

-- looks only (karts drive through): bushes, flower clumps, grass patches {x, y, radius} in two
-- shades
ArenaData.BUSHES = {
	{ 12, 105 },
	{ 229, 95 },
	{ 229, 190 },
	{ 80, 13 },
	{ 170, 13 },
	{ 229, 140 },
	{ 148, 200 },
	{ 100, 190 },
	{ 195, 135 },
	{ 52, 100 },
} :: { Pt }
ArenaData.FLOWERS = {
	{ 128, 126 },
	{ 48, 140 },
	{ 24, 212 },
	{ 190, 110 },
} :: { Pt }
ArenaData.PATCHES = {
	{ 124, 128, 12, 1 },
	{ 24, 212, 13, 2 },
	{ 216, 22, 13, 1 },
	{ 118, 182, 12, 2 },
	{ 200, 112, 12, 1 },
	{ 80, 58, 12, 2 },
	{ 228, 165, 9, 2 },
	{ 14, 135, 9, 1 },
	{ 85, 200, 12, 1 },
	{ 50, 118, 9, 2 },
	{ 200, 132, 8, 2 },
	{ 140, 168, 9, 1 },
	{ 229, 62, 8, 1 },
	{ 14, 70, 8, 2 },
} :: { { number } }

-- the 12 start spots (picture), numbered like the picture
ArenaData.START = {
	{ 28, 28 }, -- the corners are moved in so the chase cam behind fits inside the wall
	{ 140, 50 }, -- off the north wall (the picture has it on the wall: the wall filled the view)
	{ 225, 60 },
	{ 210, 210 },
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

-- A convex polygon's corners moved in by inset on the edges listed in sides (nil = all edges):
-- the top of a hill whose sides slope.
function ArenaData.insetPoly(poly: { Pt }, inset: number, sides: { number }?): { Pt }
	local n = #poly
	local area = 0
	for i = 1, n do
		local a, b = poly[i], poly[i % n + 1]
		area += a[1] * b[2] - b[1] * a[2]
	end
	local turn = if area > 0 then 1 else -1
	-- each edge's line, moved in: a point on it and its direction
	local lines = {}
	for i = 1, n do
		local a, b = poly[i], poly[i % n + 1]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local len = math.sqrt(dx * dx + dy * dy)
		local nx, ny = -dy / len * turn, dx / len * turn -- points inside
		local d = if sides == nil or table.find(sides, i) then inset else 0
		lines[i] = { a[1] + nx * d, a[2] + ny * d, dx, dy }
	end
	local out = {}
	for i = 1, n do
		local l1, l2 = lines[(i - 2) % n + 1], lines[i]
		local den = l1[3] * l2[4] - l1[4] * l2[3]
		local t = ((l2[1] - l1[1]) * l2[4] - (l2[2] - l1[2]) * l2[3]) / den
		out[i] = { l1[1] + l1[3] * t, l1[2] + l1[4] * t }
	end
	return out
end

-- The top of a sloped-side hill at p (0 outside it): full height inset from the sloped edges.
local function hillAt(poly: { Pt }, h: number, slope: number, sides: { number }?, p: Pt): number
	if not ArenaData.inside(poly, p) then
		return 0
	end
	local n = #poly
	local near = math.huge
	for i = 1, n do
		if sides == nil or table.find(sides, i) then
			local a, b = poly[i], poly[i % n + 1]
			local dx, dy = b[1] - a[1], b[2] - a[2]
			local d = math.abs((p[1] - a[1]) * dy - (p[2] - a[2]) * dx)
				/ math.sqrt(dx * dx + dy * dy)
			near = math.min(near, d)
		end
	end
	return h * math.min(1, near / slope)
end

-- The floor's top (big units) at a picture point: the highest of a hill, the platform, a ramp
-- (and its deck), else 0.
function ArenaData.groundAt(p: Pt): number
	local top = 0
	for _, h in ArenaData.HILLS do
		top = math.max(top, hillAt(h.poly, h.h, h.slope, nil, p))
	end
	top = math.max(
		top,
		hillAt(ArenaData.STEP, ArenaData.STEP_H, ArenaData.STEP_SLOPE, ArenaData.STEP_SIDES, p)
	)
	for _, r in ArenaData.RAMPS do
		local ax, ay = r.to[1] - r.from[1], r.to[2] - r.from[2]
		local len = math.sqrt(ax * ax + ay * ay)
		local u = ((p[1] - r.from[1]) * ax + (p[2] - r.from[2]) * ay) / (len * len)
		local side = math.abs((p[1] - r.from[1]) * ay - (p[2] - r.from[2]) * ax) / len
		if u >= 0 and u <= 1 + ArenaData.RAMP_DECK / len and side <= r.width / 2 then
			top = math.max(top, r.h * math.min(u, 1))
		end
	end
	return top
end

local function segDist(px: number, py: number, a: Pt, b: Pt): number
	local ax, ay = b[1] - a[1], b[2] - a[2]
	local l2 = ax * ax + ay * ay
	local u = if l2 > 0 then math.clamp(((px - a[1]) * ax + (py - a[2]) * ay) / l2, 0, 1) else 0
	local x, y = a[1] + ax * u, a[2] + ay * u
	return math.sqrt((px - x) ^ 2 + (py - y) ^ 2)
end

-- the bumper wall's solid pieces (the sand's edges, minus the gaps)
local function bumperPieces(): { { Pt } }
	local out = {}
	local n = #ArenaData.SAND
	for i = 1, n do
		local a, b = ArenaData.SAND[i], ArenaData.SAND[i % n + 1]
		local cuts = { 0 }
		for _, g in ArenaData.SAND_GAPS do
			if g[1] == i then
				table.insert(cuts, g[2])
				table.insert(cuts, g[3])
			end
		end
		table.insert(cuts, 1)
		for k = 1, #cuts - 1, 2 do
			local u0, u1 = cuts[k], cuts[k + 1]
			table.insert(out, {
				{ a[1] + (b[1] - a[1]) * u0, a[2] + (b[2] - a[2]) * u0 },
				{ a[1] + (b[1] - a[1]) * u1, a[2] + (b[2] - a[2]) * u1 },
			})
		end
	end
	return out
end
ArenaData.bumperPieces = bumperPieces()

-- the start arch's two pillar spots (picture units)
function ArenaData.archPillars(): { Pt }
	local a = ArenaData.ARCH
	return { { a.at[1] - a.pillarOff, a.at[2] }, { a.at[1] + a.pillarOff, a.at[2] } }
end

-- Is there room for a kart's middle at picture point (x, y), `room` picture units from anything
-- solid that stands up (walls, trees, cover, bumpers, rocks, crates, barrels, the arch)? Hills and
-- ramps are floor: groundAt covers them. Bots and the tests use this.
function ArenaData.clear(x: number, y: number, room: number): boolean
	local lo, hi = ArenaData.WALL + room, ArenaData.PIC - ArenaData.WALL - room
	if x < lo or x > hi or y < lo or y > hi then
		return false
	end
	local trunk = ArenaData.TRUNK / ArenaData.K / 2
	for _, t in ArenaData.TREES do
		if math.sqrt((x - t[1]) ^ 2 + (y - t[2]) ^ 2) < trunk + room then
			return false
		end
	end
	for _, r in ArenaData.ROCKS do
		if math.sqrt((x - r[1]) ^ 2 + (y - r[2]) ^ 2) < r[3] * 1.4 + room then -- turned blocks
			return false
		end
	end
	local crate = ArenaData.CRATE * 0.75
	for _, c in ArenaData.CRATES do
		if math.sqrt((x - c[1]) ^ 2 + (y - c[2]) ^ 2) < crate + room then
			return false
		end
	end
	local pillar = ArenaData.ARCH.pillar * 0.75
	for _, c in ArenaData.archPillars() do
		if math.sqrt((x - c[1]) ^ 2 + (y - c[2]) ^ 2) < pillar + room then
			return false
		end
	end
	for _, seg in ArenaData.BARRELS do
		if segDist(x, y, seg[1], seg[2]) < ArenaData.BARREL_R + room then
			return false
		end
	end
	for _, seg in ArenaData.COVER do
		if segDist(x, y, seg[1], seg[2]) < ArenaData.COVER_W / 2 + room then
			return false
		end
	end
	for _, seg in ArenaData.bumperPieces do
		if segDist(x, y, seg[1], seg[2]) < ArenaData.BUMPER_W / 2 + room then
			return false
		end
	end
	return true
end

-- The chase cam hangs this far behind a kart (big units, Tuning camDistance at RC size); a start
-- spot must leave room for it inside the wall, and a kart must not start nose to the wall.
ArenaData.CAM_BACK, ArenaData.NOSE_ROOM = 40, 20
local MARGIN = ArenaData.WALL + 2 -- picture units from the outside edge

-- Is the view ahead of a kart at p (facing dx, dy) open: no wall, cover, rock or rise (a hill
-- side) in the first VIEW big units?
ArenaData.VIEW = 48
function ArenaData.viewOpen(p: Pt, dx: number, dy: number): boolean
	local g0 = ArenaData.groundAt(p)
	local step = 1.5 -- picture units: fine enough to catch a bumper or a trunk
	for k = 1, math.floor(ArenaData.VIEW / ArenaData.K / step) do
		local q = { p[1] + dx * step * k, p[2] + dy * step * k }
		if ArenaData.groundAt(q) > g0 + 1 or not ArenaData.clear(q[1], q[2], 1) then
			return false
		end
	end
	return true
end

-- The way a start spot faces: the arena's middle, else the nearest turn (15 degree steps) that
-- keeps the chase cam and the kart's nose inside the walls (spots near a wall face along it).
function ArenaData.facing(p: Pt): (number?, number?)
	local back, front = ArenaData.CAM_BACK / ArenaData.K, ArenaData.NOSE_ROOM / ArenaData.K
	local lo, hi = MARGIN, ArenaData.PIC - MARGIN
	local base = math.atan2(ArenaData.PIC / 2 - p[2], ArenaData.PIC / 2 - p[1])
	local best = math.huge
	local bx: number?, by: number? = nil, nil
	for k = 0, 23 do
		local a = k * math.pi / 12
		local dx, dy = math.cos(a), math.sin(a)
		local cx, cy = p[1] - dx * back, p[2] - dy * back
		local fx, fy = p[1] + dx * front, p[2] + dy * front
		if
			cx >= lo
			and cx <= hi
			and cy >= lo
			and cy <= hi
			and fx >= lo
			and fx <= hi
			and fy >= lo
			and fy <= hi
		then
			local diff = math.abs((a - base + math.pi) % (2 * math.pi) - math.pi)
			-- never away from the middle; an open first look (nothing solid or higher close
			-- ahead) beats a blocked one
			if diff > math.pi / 2 then
				diff = math.huge
			elseif not ArenaData.viewOpen(p, dx, dy) then
				diff += math.pi
			end
			if diff < best then
				best, bx, by = diff, dx, dy
			end
		end
	end
	if bx == nil or by == nil then
		return nil
	end
	return bx, by
end

-- start spots (map-local big units)
ArenaData.spawns = {} :: { Spot }
for _, p in ArenaData.START do
	local x, z = ArenaData.at(p)
	local dx, dz = ArenaData.facing(p)
	if dx == nil or dz == nil then
		-- no room anywhere (the test catches this): face the middle
		local n = math.max(math.sqrt(x * x + z * z), 1e-6)
		dx, dz = -x / n, -z / n
	end
	table.insert(ArenaData.spawns, {
		x = x,
		y = ArenaData.groundAt(p) + 2.5,
		z = z,
		dx = dx :: number,
		dz = dz :: number,
	})
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
-- soft: no neon wash on phones
ArenaData.colorCorrection =
	{ Brightness = 0.02, Contrast = 0.06, Saturation = 0.04, tint = { 255, 248, 238 } }
ArenaData.bloom = { Intensity = 0.2, Size = 20, Threshold = 2 }

return ArenaData
