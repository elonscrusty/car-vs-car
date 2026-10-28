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
export type Jump = { path: number, at: Pt, h: number?, len: number? } -- h / len: a gentler ridge

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
	stand: Stand?, -- the driver stand (Car VS Car): racers stand on it with their remotes
}

-- A raised deck by the track. x / z is its middle (moves with the squeeze), the sizes stay real.
-- It faces -z (towards the front straight); its 8 spots run along x.
export type Stand = { x: number, z: number, w: number, d: number, h: number }

-- one spot on top of the stand: where an avatar stands (map-local, big units), facing -z
export type StandSpot = { x: number, y: number, z: number }

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
		d.jumps[i] = { path = j.path, at = pt(j.at), h = j.h, len = j.len }
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
	if def.stand then
		local st = table.clone(def.stand)
		st.x, st.z = def.stand.x * k, def.stand.z * k
		d.stand = st
	end
	return d
end

MapKit.STAND_SPOTS = 8 -- racers on the driver stand, side by side
-- 40 x 8 RC studs, 10 up. Not higher, and the racers stand near its front: from the stand
-- camera (above and behind you) a taller or deeper deck hides the road right in front of it.
MapKit.STAND_W, MapKit.STAND_D, MapKit.STAND_H = 160, 32, 40
MapKit.STAND_FRONT = 8 -- the spots stand this far back from the deck's front edge
MapKit.STAND_STAIRS = 80 -- the stairs run this far out past the stand's left end (-x)
MapKit.STAND_STEP = 8 -- the most each stair climbs
MapKit.PER = 16 -- loop samples per main point (samples land ~5 to 15 apart)
MapKit.CURB_WIDTH = 3
MapKit.CURB_HEIGHT = 0.4
MapKit.GATE_DEPTH = 12
MapKit.GRASS_GRIP = 0.75 -- off the road: same as the race plot's grass
MapKit.GRASS_DRAG = 0.5
-- the jump ridge: low and long. The JUMP tile's 14 x 58 put a full-speed car on its roof
-- (Studio, 10-26), so the maps use a flatter one.
MapKit.JUMP_H = 10
MapKit.JUMP_LEN = 90 -- the run up is half of this (12.5 degrees)
-- A long, gentle landing. It is a bump, not a flying jump: a 22-degree landing (25 long) tipped
-- cars nose-first onto their roofs in 7 of 8 Studio runs (10-26 13:44), so keep this long.
MapKit.JUMP_DOWN = 80
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

-- Is a spot on the floor free for scenery: inside the walls, `clear` past every road's curb, off
-- the jumps, out from under the props and clear of the driver stand and its stairs?
local function spotFree(
	map: any,
	rings: { { Sample } },
	x: number,
	z: number,
	clear: number
): boolean
	local def: Def = map.def
	if x < def.minX + 20 or x > def.maxX - 20 or z < def.minZ + 20 or z > def.maxZ - 20 then
		return false
	end
	for r, ring in rings do
		local w = if r == 1 then def.road else def.paths[r - 1].width
		if MapKit.distTo(ring, x, z) < w / 2 + MapKit.CURB_WIDTH + clear then
			return false
		end
	end
	for _, j in def.jumps do
		if math.sqrt((j.at.x - x) ^ 2 + (j.at.z - z) ^ 2) < (j.len or MapKit.JUMP_LEN) then
			return false
		end
	end
	for _, p in def.props do
		local r = math.max(p.w or p.h * 0.6, p.d or p.h * 0.6) / 2 + clear
		if p.h > 2 and math.sqrt((p.x - x) ^ 2 + (p.z - z) ^ 2) < r then
			return false
		end
	end
	local st = def.stand
	if
		st
		and x > st.x - st.w / 2 - MapKit.STAND_STAIRS - clear
		and x < st.x + st.w / 2 + clear
		and z > st.z - st.d / 2 - clear
		and z < st.z + st.d / 2 + clear
	then
		return false -- keep the driver stand (and its stairs) clear
	end
	return true
end

local function allRings(map: any): { { Sample } }
	local rings = { map.loop() }
	for i = 1, #map.def.paths do
		table.insert(rings, map.path(i))
	end
	return rings
end

-- Spots just off both sides of the main road, every `spacing` along it, `off` from the centre
-- line (scenery that lines the road: giant grass, toys). Leaves out spots on or next to any road
-- (a side road crossing, the other side of a hairpin), on a jump, or under a prop.
export type EdgeSpot = { x: number, z: number, yaw: number, side: number, i: number }
function MapKit.edgeSpots(map: any, spacing: number, off: number, clear: number): { EdgeSpot }
	local loop: { Sample } = map.loop()
	local rings = allRings(map)
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
				if spotFree(map, rings, x, z, clear) then
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

-- Where the kitchen's giant toys stand by the road (RaceMapBuilder puts one on each).
function MapKit.toySpots(map: any): { EdgeSpot }
	return MapKit.edgeSpots(map, 130, MapKit.TOY_OFF, MapKit.TOY_CLEAR)
end

-- The bends of the main loop a kid can run wide on: runs of samples where the road turns more
-- than TURN_MIN over the next TURN_LOOK of road. dir 1 = a right-hand bend, -1 = left.
-- (A first-time kid on a low chase cam lost the road at every bend, 10-28.)
MapKit.TURN_LOOK = 100
MapKit.TURN_MIN = 0.55 -- radians (about 32 degrees)
export type Turn = { from: number, to: number, dir: number }
function MapKit.turns(map: any): { Turn }
	local loop: { Sample } = map.loop()
	local n = #loop
	local function bend(i: number): number
		local run, k = 0, i
		while run < MapKit.TURN_LOOK and k < i + n do
			local a, b = loop[(k - 1) % n + 1], loop[k % n + 1]
			run += math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
			k += 1
		end
		local a, b = loop[i], loop[(k - 1) % n + 1]
		-- signed angle from a's heading to b's (+ = toward the driver's right)
		return math.atan2(a.tx * b.tz - a.tz * b.tx, a.tx * b.tx + a.tz * b.tz)
	end
	local out: { Turn } = {}
	local cur: Turn? = nil
	for i = 1, n do
		local t = bend(i)
		local dir = if t > 0 then 1 else -1
		if math.abs(t) > MapKit.TURN_MIN then
			if cur and cur.dir == dir then
				cur.to = i
			else
				cur = { from = i, to = i, dir = dir }
				table.insert(out, cur :: Turn)
			end
		else
			cur = nil
		end
	end
	-- a bend that runs over the end of the loop is one bend
	if #out > 1 and out[1].from == 1 and out[#out].to == n and out[1].dir == out[#out].dir then
		out[1].from = out[#out].from - n
		table.remove(out)
	end
	return out
end

-- Chevron boards round the outside of every bend (yellow, black arrows pointing the way), facing
-- the car as it comes in: on a low chase cam they show which way the road goes long before the
-- painted arrows do. Looks only (you drive through them), on the floor clear of everything else.
MapKit.SIGN_OFF = 14 -- past the curb
MapKit.SIGN_GAP = 30 -- along the bend
MapKit.SIGN_W = 24
export type Sign = { x: number, z: number, yaw: number, dir: number }
function MapKit.turnSigns(map: any): { Sign }
	local def: Def = map.def
	local loop: { Sample } = map.loop()
	local n = #loop
	local rings = allRings(map)
	local edge = def.road / 2 + MapKit.CURB_WIDTH
	-- kitchen toys by the road (a brick reaches 25 from its middle) and the counter fronts
	local toys = if def.theme == "kitchen" then MapKit.toySpots(map) else {}
	-- is the floor free `reach` round (x, z), `clear` past every curb?
	local function free(x: number, z: number, clear: number, reach: number): boolean
		if not spotFree(map, rings, x, z, clear) then
			return false
		end
		for _, p in def.props do
			-- out of the prop's box (turned like CFrame.Angles(0, yaw, 0)), `reach` round it
			local pw, pd = p.w or p.h * 0.6, p.d or p.h * 0.6
			local c, s = math.cos(p.yaw), math.sin(p.yaw)
			local dx, dz = x - p.x, z - p.z
			local lx, lz = dx * c - dz * s, dx * s + dz * c
			if p.h > 2 and math.abs(lx) < pw / 2 + reach and math.abs(lz) < pd / 2 + reach then
				return false
			end
		end
		for _, e in toys do
			if math.sqrt((e.x - x) ^ 2 + (e.z - z) ^ 2) < 25 + reach then
				return false
			end
		end
		return not (map.COUNTER_FRONT and z < map.COUNTER_FRONT + reach)
	end
	local half = MapKit.SIGN_W / 2
	local out: { Sign } = {}
	for _, t in MapKit.turns(map) do
		local run = MapKit.SIGN_GAP -- the first board at the bend's start
		for i = t.from - 4, t.to do
			local a, b = loop[(i - 1) % n + 1], loop[i % n + 1]
			if run >= MapKit.SIGN_GAP then
				-- outside of the bend: the driver's left on a right-hand bend
				local ox, oz = a.tz * t.dir, -a.tx * t.dir
				local x, z =
					a.x + ox * (edge + MapKit.SIGN_OFF), a.z + oz * (edge + MapKit.SIGN_OFF)
				local nx, nz
				if free(x, z, MapKit.SIGN_OFF - 2, half + 4) then
					-- out on the floor: face back down the road, turned a little toward it
					nx, nz = -a.tx - ox * 0.5, -a.tz - oz * 0.5
				else
					-- no room (a counter, the fridge, a table leg is right there): close to the curb,
					-- side on to the road like a board on a wall, so it fits in a thin gap
					x, z = a.x + ox * (edge + 6), a.z + oz * (edge + 6)
					local ends = 0
					for _, along in { -half, 0, half } do
						if free(x + a.tx * along, z + a.tz * along, 4, 3) then
							ends += 1
						end
					end
					if ends == 3 then
						nx, nz = -ox - a.tx * 0.35, -oz - a.tz * 0.35
					end
				end
				if nx then
					run = 0
					table.insert(out, { x = x, z = z, yaw = math.atan2(nx, nz), dir = t.dir })
				end
			end
			run += math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		end
	end
	return out
end

-- The way a side road runs at a spot (yaw for CFrame.Angles(0, yaw, 0) whose +Z runs along it):
-- turns a drive-through prop (the dog house) to the road through it.
function MapKit.pathYaw(map: any, x: number, z: number): number
	local best, bestD = nil :: Sample?, math.huge
	for i = 1, #map.def.paths do
		local s = MapKit.nearest(map.path(i), { x = x, z = z })
		local d = (s.x - x) ^ 2 + (s.z - z) ^ 2
		if d < bestD then
			best, bestD = s, d
		end
	end
	local s = best :: Sample
	return math.atan2(s.tx, s.tz)
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
	standSpots: () -> { StandSpot },
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
	-- The 8 driver spots on top of the stand, left to right as you face the track (empty if the
	-- map has no stand). Avatars stand here facing -z.
	function map.standSpots(): { StandSpot }
		local st = def.stand
		local out: { StandSpot } = {}
		if not st then
			return out
		end
		local n = MapKit.STAND_SPOTS
		for i = 1, n do
			local x = st.x - st.w / 2 + st.w * (i - 0.5) / n
			table.insert(out, { x = x, y = st.h, z = st.z - st.d / 2 + MapKit.STAND_FRONT })
		end
		return out
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
