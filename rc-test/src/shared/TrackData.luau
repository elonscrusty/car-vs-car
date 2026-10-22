--!strict
-- The three grey tracks as plain numbers (no Roblox objects, so Lune can test them).
-- All positions are local to the track; add `originX` to X to get the world spot.

export type Gate = {
	x: number,
	y: number,
	z: number,
	dx: number,
	dz: number,
	halfWidth: number,
	depth: number,
}
export type Pt = { x: number, z: number }
export type Sample = { x: number, z: number, tx: number, tz: number }
export type Rock = { x: number, y: number, z: number, r: number }
export type Spawn = { x: number, y: number, z: number, dx: number, dz: number }

export type Track = {
	id: string,
	label: string,
	originX: number,
	mode: string, -- "free", "loop" or "oneway"
	grip: number, -- ground grip multiplier (1 = normal)
	spawn: Spawn,
	gates: { Gate },
}

local TrackData = {}

TrackData.order = { "drift", "race", "rock" }
TrackData.ROAD_DRIFT = 56
TrackData.ROAD_RACE = 30
TrackData.ROCK_HALF_WIDTH = 35

local DRIFT_POINTS: { Pt } = {
	{ x = -120, z = -140 },
	{ x = 40, z = -170 },
	{ x = 170, z = -100 },
	{ x = 200, z = 20 },
	{ x = 120, z = 110 },
	{ x = 0, z = 60 },
	{ x = -110, z = 120 },
	{ x = -190, z = 40 },
	{ x = -200, z = -70 },
}

local RACE_POINTS: { Pt } = {
	{ x = -110, z = -110 },
	{ x = 0, z = -120 },
	{ x = 90, z = -130 },
	{ x = 170, z = -90 },
	{ x = 190, z = -20 },
	{ x = 140, z = 40 },
	{ x = 60, z = 30 },
	{ x = 30, z = 90 },
	{ x = 80, z = 150 },
	{ x = 10, z = 190 },
	{ x = -90, z = 170 },
	{ x = -150, z = 100 },
	{ x = -130, z = 20 },
	{ x = -170, z = -50 },
}

-- Rock climb: ground height along the course. { z, y } from the start (z high) up to the top.
TrackData.rockProfile = {
	{ z = 150, y = 0 },
	{ z = 110, y = 0 },
	{ z = 60, y = 14 },
	{ z = 30, y = 14 },
	{ z = -10, y = 38 },
	{ z = -50, y = 38 },
	{ z = -90, y = 60 },
	{ z = -140, y = 60 },
}

-- Smooth closed loop through the points (Catmull-Rom). Returns evenly-ish spaced samples with
-- the unit direction of travel.
function TrackData.loop(points: { Pt }, perSegment: number): { Sample }
	local n = #points
	local out: { Sample } = {}
	for i = 1, n do
		local p0 = points[((i - 2) % n) + 1]
		local p1 = points[i]
		local p2 = points[(i % n) + 1]
		local p3 = points[((i + 1) % n) + 1]
		for s = 0, perSegment - 1 do
			local t = s / perSegment
			local t2, t3 = t * t, t * t * t
			local function cr(a: number, b: number, c: number, d: number): number
				return 0.5
					* (
						2 * b
						+ (-a + c) * t
						+ (2 * a - 5 * b + 4 * c - d) * t2
						+ (-a + 3 * b - 3 * c + d) * t3
					)
			end
			out[#out + 1] =
				{ x = cr(p0.x, p1.x, p2.x, p3.x), z = cr(p0.z, p1.z, p2.z, p3.z), tx = 0, tz = 0 }
		end
	end
	local count = #out
	for i = 1, count do
		local a, b = out[i], out[(i % count) + 1]
		local dx, dz = b.x - a.x, b.z - a.z
		local len = math.sqrt(dx * dx + dz * dz)
		a.tx, a.tz = dx / len, dz / len
	end
	return out
end

function TrackData.driftLoop(): { Sample }
	return TrackData.loop(DRIFT_POINTS, 8)
end

function TrackData.raceLoop(): { Sample }
	return TrackData.loop(RACE_POINTS, 6)
end

-- Ground height on the rock course at this z.
function TrackData.rockHeight(z: number): number
	local p = TrackData.rockProfile
	if z >= p[1].z then
		return p[1].y
	end
	for i = 2, #p do
		if z >= p[i].z then
			local a, b = p[i - 1], p[i]
			local t = (a.z - z) / (a.z - b.z)
			return a.y + (b.y - a.y) * t
		end
	end
	return p[#p].y
end

-- Slope (rise over run, positive uphill going forward) at this z.
function TrackData.rockSlope(z: number): number
	return (TrackData.rockHeight(z - 1) - TrackData.rockHeight(z + 1)) / 2
end

-- Rocks, the same every time (tiny seeded random).
function TrackData.rocks(): { Rock }
	local seed = 12345
	local function rand(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local out: { Rock } = {}
	local half = TrackData.ROCK_HALF_WIDTH - 4
	local tries = 0
	while #out < 70 and tries < 4000 do
		tries += 1
		local z = 100 - rand() * 185
		local x = (rand() * 2 - 1) * half
		local steep = math.abs(TrackData.rockSlope(z)) > 0.4
		local r = 1.2 + rand() * (steep and 1.0 or 2.2)
		if rand() < 0.1 and not steep then
			r = 4 + rand() * 1.5
		end
		local ok = true
		for _, o in out do
			local dx, dz = o.x - x, o.z - z
			local gap = o.r + r + 4.5
			if dx * dx + dz * dz < gap * gap then
				ok = false
				break
			end
		end
		if ok then
			out[#out + 1] = { x = x, y = TrackData.rockHeight(z) - r * 0.35, z = z, r = r }
		end
	end
	return out
end

local function gateAt(s: Sample, y: number, halfWidth: number, depth: number): Gate
	return { x = s.x, y = y, z = s.z, dx = s.tx, dz = s.tz, halfWidth = halfWidth, depth = depth }
end

function TrackData.get(id: string): Track
	if id == "drift" then
		local ring = TrackData.driftLoop()
		local s = ring[1]
		return {
			id = id,
			label = "DRIFT",
			originX = 0,
			mode = "free",
			grip = 0.45,
			spawn = { x = s.x - s.tx * 14, y = 2.5, z = s.z - s.tz * 14, dx = s.tx, dz = s.tz },
			gates = {},
		}
	elseif id == "race" then
		local ring = TrackData.raceLoop()
		local count = #ring
		local s = ring[1]
		local gates = {
			gateAt(ring[1], 0, 22, 6),
			gateAt(ring[count // 4 + 1], 0, 24, 12),
			gateAt(ring[count // 2 + 1], 0, 24, 12),
			gateAt(ring[(count * 3) // 4 + 1], 0, 24, 12),
		}
		return {
			id = id,
			label = "RACE",
			originX = 700,
			mode = "loop",
			grip = 0.75,
			spawn = { x = s.x - s.tx * 14, y = 2.5, z = s.z - s.tz * 14, dx = s.tx, dz = s.tz },
			gates = gates,
		}
	end
	local half = TrackData.ROCK_HALF_WIDTH
	return {
		id = "rock",
		label = "ROCKS",
		originX = 1400,
		mode = "oneway",
		grip = 1,
		spawn = { x = 0, y = 2.5, z = 140, dx = 0, dz = -1 },
		gates = {
			{ x = 0, y = 0, z = 128, dx = 0, dz = -1, halfWidth = half, depth = 4 },
			{ x = 0, y = 60, z = -115, dx = 0, dz = -1, halfWidth = half, depth = 25 },
		},
	}
end

return TrackData
