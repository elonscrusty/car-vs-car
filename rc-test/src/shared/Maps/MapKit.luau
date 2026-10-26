--!strict
-- Shared maths for the big race maps (Backyard, Kitchen): tiny RC cars in a giant world.
-- Each map is plain numbers (Lune tests it): the main loop, side roads (shortcuts and the hidden
-- secret), pads, jumps and props. make() turns those numbers into what the race runner wants
-- (/mnt/project-files/rc-game/tycoon/race-map-api.md): loop(), lineSample(), track().
-- The parts are built by server/RaceMapBuilder, at BIG size, then shrunk to RC size (0.25).
--
-- Map-local space, big units: (0, 0, 0) is the middle of the map on the floor. +Z is the front
-- (the start straight), -Z the back. Scale: 5.5 big units = 1 real inch (the car is 5.5 long,
-- so it's an inch-long toy and a sneaker is 12 car lengths).

-- Loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function kitModule(): any
	if script then
		return require((script :: any).Parent.Parent.Plots.Kit)
	end
	local luneRequire: any = require
	return luneRequire("../Plots/Kit")
end

local Kit = kitModule()

export type Pt = { x: number, z: number }
export type Sample = { x: number, z: number, tx: number, tz: number }

-- A side road off the main loop: a shortcut you can see, or the hidden secret.
export type Path = {
	kind: string, -- "shortcut" or "secret"
	look: string, -- "dirt", "mown" (looks like lawn, but fast), "tunnel" (inside a cabinet)
	width: number,
	points: { Pt }, -- starts and ends on the main road
}

-- A flat patch on a road: "boost" (push), "puddle" / "milk" (slippy), "mud" / "sand" (slow).
export type Pad = { kind: string, path: number, at: Pt, len: number }
-- A jump ridge across a road (path 0 = the main loop), like the JUMP tile.
export type Jump = { path: number, at: Pt }

-- Giant things standing in the world. yaw: 0 = front looks to -Z.
export type Prop = {
	kind: string,
	x: number,
	z: number,
	yaw: number,
	h: number, -- height, big units
	w: number?, -- footprint across (x before yaw)
	d: number?, -- footprint deep (z before yaw)
	solid: boolean, -- can the car bump it?
}

-- A long thin thing lying on the floor along points (the garden hose).
export type Line = { kind: string, width: number, points: { Pt } }

export type Def = {
	id: string,
	label: string,
	theme: string, -- "yard" or "kitchen": which builder dresses it
	road: number, -- road width
	minX: number, -- the map floor (walls / fence round it)
	maxX: number,
	minZ: number,
	maxZ: number,
	main: { Pt }, -- the main loop, in driving order
	line: Pt, -- near the start line (front straight)
	gates: { Pt }, -- lap checks after the line, in driving order (never on a skipped bit)
	paths: { Path },
	pads: { Pad },
	jumps: { Jump },
	props: { Prop },
	lines: { Line },
	rcX: number, -- where the map's middle sits in the world (RC studs)
	rcZ: number,
	rcAngle: number,
}

local MapKit = {}

-- Squeeze every spot of a map towards its middle by k (sizes stay: the props keep their real
-- giant size, only the spacing shrinks). Used to tune the lap length.
function MapKit.scale(def: Def, k: number): Def
	local function pt(p: Pt): Pt
		return { x = p.x * k, z = p.z * k }
	end
	local function pts(list: { Pt }): { Pt }
		local out = {}
		for i, p in list do
			out[i] = pt(p)
		end
		return out
	end
	local d = table.clone(def)
	d.minX, d.maxX, d.minZ, d.maxZ = def.minX * k, def.maxX * k, def.minZ * k, def.maxZ * k
	d.main = pts(def.main)
	d.line = pt(def.line)
	d.gates = pts(def.gates)
	d.paths = {}
	for i, p in def.paths do
		local c = table.clone(p)
		c.points = pts(p.points)
		d.paths[i] = c
	end
	d.pads = {}
	for i, p in def.pads do
		local c = table.clone(p)
		c.at = pt(p.at)
		d.pads[i] = c
	end
	d.jumps = {}
	for i, j in def.jumps do
		d.jumps[i] = { path = j.path, at = pt(j.at) }
	end
	d.props = {}
	for i, p in def.props do
		local c = table.clone(p)
		c.x, c.z = p.x * k, p.z * k
		d.props[i] = c
	end
	d.lines = {}
	for i, l in def.lines do
		d.lines[i] = { kind = l.kind, width = l.width, points = pts(l.points) }
	end
	return d
end

MapKit.PER = 16 -- loop samples per main point (samples land ~5 to 15 apart)
MapKit.CURB_WIDTH = 3
MapKit.CURB_HEIGHT = 0.4
MapKit.GATE_DEPTH = 12
MapKit.GRASS_GRIP = 0.75 -- off the road: same as the race plot's grass
MapKit.GRASS_DRAG = 0.5
MapKit.JUMP_H = 14 -- same ridge as the JUMP tile (Studio-tested: ~0.6 s of air)
MapKit.JUMP_LEN = 58
MapKit.WALL_H = 60 -- the edge of the map (a fence, a kitchen wall): taller than any jump
MapKit.TOY_OFF = 60 -- kitchen toys by the road stand this far from its centre line
MapKit.TOY_CLEAR = 28 -- and at least this far past any curb (a brick is 44 x 22)
MapKit.BACK = 14 -- the pole sits this far behind the line (same as ServerRace.BACK)

-- What each pad does to the car (the car reads Grip / Drag / Boost off the part under a wheel).
MapKit.PADS = {
	boost = { grip = 1, drag = nil, boost = true },
	puddle = { grip = 0.5, drag = nil, boost = false },
	milk = { grip = 0.5, drag = nil, boost = false },
	mud = { grip = 0.6, drag = 0.8, boost = false },
	sand = { grip = 0.8, drag = 1.2, boost = false },
}

-- The sample closest to a spot.
function MapKit.nearest(ring: { Sample }, p: Pt): (Sample, number)
	local best, bestI, bestD = ring[1], 1, math.huge
	for i, s in ring do
		local dx, dz = s.x - p.x, s.z - p.z
		local d = dx * dx + dz * dz
		if d < bestD then
			best, bestI, bestD = s, i, d
		end
	end
	return best, bestI
end

-- Distance from a spot to the nearest sample of a ring.
function MapKit.distTo(ring: { Sample }, x: number, z: number): number
	local s = MapKit.nearest(ring, { x = x, z = z })
	return math.sqrt((s.x - x) ^ 2 + (s.z - z) ^ 2)
end

-- Length of a run of samples (closed = round the loop back to the first).
function MapKit.length(ring: { Sample }, closed: boolean): number
	local n, len = #ring, 0
	for i = 1, if closed then n else n - 1 do
		local a, b = ring[i], ring[(i % n) + 1]
		len += math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
	end
	return len
end

-- Spots just off both sides of the main road, every `spacing` along it, `off` from the centre
-- line (scenery that lines the road: giant grass, toys). Leaves out spots on or next to any road
-- (a side road crossing, the other side of a hairpin), on a jump, or under a prop.
export type EdgeSpot = { x: number, z: number, yaw: number, side: number, i: number }
function MapKit.edgeSpots(map: any, spacing: number, off: number, clear: number): { EdgeSpot }
	local def: Def = map.def
	local loop: { Sample } = map.loop()
	local rings = { loop }
	for i = 1, #def.paths do
		table.insert(rings, map.path(i))
	end
	local out = {}
	local run = 0
	local k = 0
	for i = 1, #loop do
		local a, b = loop[i], loop[(i % #loop) + 1]
		run += math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		if run >= spacing then
			run = 0
			k += 1
			for _, side in { -1, 1 } do
				local o = off * side
				local x, z = a.x - a.tz * o, a.z + a.tx * o
				local ok = x > def.minX + 20
					and x < def.maxX - 20
					and z > def.minZ + 20
					and z < def.maxZ - 20
				for r, ring in rings do
					local w = if r == 1 then def.road else def.paths[r - 1].width
					if ok and MapKit.distTo(ring, x, z) < w / 2 + MapKit.CURB_WIDTH + clear then
						ok = false
					end
				end
				for _, j in def.jumps do
					if ok and math.sqrt((j.at.x - x) ^ 2 + (j.at.z - z) ^ 2) < MapKit.JUMP_LEN then
						ok = false
					end
				end
				for _, p in def.props do
					local r = math.max(p.w or p.h * 0.6, p.d or p.h * 0.6) / 2 + clear
					if ok and p.h > 2 and math.sqrt((p.x - x) ^ 2 + (p.z - z) ^ 2) < r then
						ok = false
					end
				end
				if ok then
					table.insert(
						out,
						{ x = x, z = z, yaw = math.atan2(-a.tx, -a.tz), side = side, i = k }
					)
				end
			end
		end
	end
	return out
end

export type Map = {
	id: string,
	label: string,
	theme: string,
	def: Def,
	ROAD: number,
	mode: string,
	grip: number,
	spawn: Kit.Spawn,
	gates: { Kit.Gate },
	loop: () -> { Sample },
	lineSample: () -> number,
	path: (i: number) -> { Sample },
	ring: (i: number) -> { Sample },
	track: () -> any,
}

function MapKit.make(def: Def): Map
	local loop = Kit.loop(def.main, MapKit.PER)
	local paths: { { Sample } } = {}
	for i, p in def.paths do
		paths[i] = Kit.path(p.points, MapKit.PER)
	end
	local line, lineI = MapKit.nearest(loop, def.line)
	local half = def.road / 2 + MapKit.CURB_WIDTH + 8
	local gates = { Kit.gateAt(line, 0, half, MapKit.GATE_DEPTH) }
	for _, g in def.gates do
		table.insert(gates, Kit.gateAt((MapKit.nearest(loop, g)), 0, half, MapKit.GATE_DEPTH))
	end
	local spawn = Kit.spawnAt(line, MapKit.BACK)

	local map = {}
	map.id = def.id
	map.label = def.label
	map.theme = def.theme
	map.def = def
	map.ROAD = def.road
	map.mode = "loop"
	map.grip = 1
	map.spawn = spawn
	map.gates = gates
	function map.loop(): { Sample }
		return loop
	end
	function map.lineSample(): number
		return lineI
	end
	-- side road i, as samples from its start to its end
	function map.path(i: number): { Sample }
		return paths[i]
	end
	-- 0 = the main loop, else side road i
	function map.ring(i: number): { Sample }
		return if i == 0 then loop else paths[i]
	end
	-- The TrackData.Track the race runner drives (map-local, big units; rcX / rcZ in RC studs).
	function map.track(): any
		return {
			id = def.id,
			label = def.label,
			originX = 0,
			mode = "loop",
			grip = 1,
			spawn = spawn,
			gates = gates,
			rcX = def.rcX,
			rcZ = def.rcZ,
			rcAngle = def.rcAngle,
		}
	end
	return map :: any
end

return MapKit
