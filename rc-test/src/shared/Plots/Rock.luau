--!strict
-- ROCK plot: a slow zigzag dirt trail from the start (front left) up to the flag (back right).
-- Five long straight rows joined by four flat turns. Every climb sits on the straight middle of
-- a row (climbing round a bend made the car swing round and roll back): two gentle ones (rows 1
-- and 4) and two steep ones (rows 3 and 5). The climbs are kept clear; the flat parts are full of
-- things that tip the car one way and the other so the springs flex: offset rocks, half-road
-- ledges, logs across the trail and little ramps of different steepness.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Kit = sibling("Kit")
local C = Kit.COLORS

type Pt = { x: number, z: number }
type Sample = { x: number, z: number, tx: number, tz: number }
type Gate = {
	x: number,
	y: number,
	z: number,
	dx: number,
	dz: number,
	halfWidth: number,
	depth: number,
}

-- Something on the trail. `u` is how far along (1 = start point, 24 = flag point, see POINTS),
-- `side` is across the trail (-1 = left edge, 1 = right edge), `lift` is how high its top sits
-- above the trail.
export type Feature = {
	kind: string, -- "rock", "ledge", "log" or "ramp"
	u: number,
	side: number,
	r: number, -- rock radius, log radius, ledge/ramp length
	lift: number,
}

local ROAD = 34 -- trail width (8.5 studs at RC size)
local HALF = ROAD / 2
local WALL = 6 -- side wall height above the trail: too tall for the wheels to ride up on
local PER = 10 -- samples between two points

local Plot = {}
Plot.id = "rock"
Plot.label = "ROCKS"
Plot.mode = "oneway"
Plot.grip = 1
Plot.ROAD = ROAD
Plot.HALF_WIDTH = HALF
Plot.WALL = WALL
-- Highest bump the car can crawl over (its body clears about 1.9 at rest).
Plot.MAX_LIFT = 1.6

-- The trail, front (start) to back (flag). Each row is 5 points in a line, so the middle of
-- each row is dead straight; the turns bulge out to the sides.
local POINTS: { Pt } = {
	{ x = -125, z = 115 }, -- 1 start
	{ x = -62, z = 115 },
	{ x = 0, z = 115 },
	{ x = 50, z = 115 },
	{ x = 100, z = 115 },
	{ x = 132, z = 80 }, -- 6 turn 1
	{ x = 100, z = 45 },
	{ x = 50, z = 45 },
	{ x = 0, z = 45 },
	{ x = -50, z = 45 },
	{ x = -100, z = 45 },
	{ x = -132, z = 10 }, -- 12 turn 2
	{ x = -100, z = -25 },
	{ x = -50, z = -25 },
	{ x = 0, z = -25 },
	{ x = 50, z = -25 },
	{ x = 100, z = -25 },
	{ x = 132, z = -60 }, -- 18 turn 3
	{ x = 100, z = -95 },
	{ x = 50, z = -95 },
	{ x = 0, z = -95 },
	{ x = -50, z = -95 },
	{ x = -100, z = -95 },
	{ x = -132, z = -130 }, -- 24 turn 4
	{ x = -100, z = -165 },
	{ x = -50, z = -165 },
	{ x = 0, z = -165 },
	{ x = 50, z = -165 },
	{ x = 95, z = -165 }, -- 29 flag
}
Plot.POINTS = POINTS
Plot.LAST_U = #POINTS

-- Trail height along the way: { u, y }. Flat turns; every climb on a straight (see the top).
Plot.profile = {
	{ u = 1, y = 0 },
	{ u = 2.5, y = 0 },
	{ u = 4, y = 10 }, -- climb 1: gentle (row 1)
	{ u = 14, y = 10 },
	{ u = 16, y = 34 }, -- climb 2: steep (row 3)
	{ u = 20, y = 34 },
	{ u = 22, y = 44 }, -- climb 3: gentle (row 4)
	{ u = 26, y = 44 },
	{ u = 28, y = 68 }, -- climb 4: steep (row 5)
	{ u = 29, y = 68 },
}

-- Trail height at u.
function Plot.height(u: number): number
	local p = Plot.profile
	if u <= p[1].u then
		return p[1].y
	end
	for i = 2, #p do
		local a, b = p[i - 1], p[i]
		if u <= b.u then
			local t = (u - a.u) / (b.u - a.u)
			-- ease in and out so the climbs bend smoothly at the top and bottom
			t = t * t * (3 - 2 * t)
			return a.y + (b.y - a.y) * t
		end
	end
	return p[#p].y
end

local cachedPath: { Sample }? = nil

-- The trail centre line, PER samples per point (sample i sits at u = 1 + (i - 1) / PER).
function Plot.path(): { Sample }
	local p = cachedPath
	if p == nil then
		p = Kit.path(POINTS, PER)
		cachedPath = p
	end
	return p :: { Sample }
end

function Plot.uOf(index: number): number
	return 1 + (index - 1) / PER
end

-- Trail spot at u: centre x, z, height, and the forward direction.
function Plot.at(u: number): (number, number, number, number, number)
	local path = Plot.path()
	local f = math.clamp((u - 1) * PER + 1, 1, #path)
	local i = math.min(math.floor(f), #path - 1)
	local t = f - i
	local a, b = path[i], path[i + 1]
	return a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t, Plot.height(u), a.tx, a.tz
end

-- Plot-local spot of something at u, `side` across the trail (-1 left .. 1 right).
function Plot.spot(u: number, side: number): (number, number, number)
	local x, z, h, tx, tz = Plot.at(u)
	local off = side * HALF
	-- right of forward (tx, tz) is (-tz, tx)
	return x - tz * off, z + tx * off, h
end

local function rock(u: number, side: number, r: number, lift: number): Feature
	return { kind = "rock", u = u, side = side, r = r, lift = lift }
end
local function ledge(u: number, side: number, lift: number): Feature
	return { kind = "ledge", u = u, side = side, r = 8, lift = lift }
end
local function log(u: number, r: number): Feature
	return { kind = "log", u = u, side = 0, r = r, lift = r * 1.5 }
end
local function ramp(u: number, length: number, lift: number): Feature
	return { kind = "ramp", u = u, side = 0, r = length, lift = lift }
end

-- Everything on the trail, start to flag. Rocks come in left/right pairs a little apart, so one
-- side of the car climbs while the other drops. A few big rocks (lift over MAX_LIFT) sit near the
-- edges to steer around.
Plot.features = {
	-- row 1: warm up, then climb 1 (clear)
	rock(1.8, -0.35, 2.2, 1.0),
	rock(2.1, 0.3, 2.4, 1.1),
	ledge(2.35, 0.5, 0.9),
	ramp(4.4, 6, 1.0), -- gentle bump
	rock(4.7, -0.4, 2.6, 1.3),
	rock(4.85, 0.8, 3.5, 2.6), -- big, steer around
	-- turn 1
	rock(5.6, -0.6, 2.0, 0.9),
	rock(6.3, 0.55, 2.2, 1.0),
	-- row 2: offset rocks, a log, a ledge
	rock(7.4, -0.4, 2.4, 1.2),
	rock(7.7, 0.35, 2.4, 1.3),
	rock(8.0, -0.8, 3.8, 2.8), -- big, edge
	log(8.5, 0.9),
	rock(9.0, 0.4, 2.8, 1.4),
	rock(9.3, -0.3, 2.6, 1.3),
	ledge(9.9, -0.5, 1.1),
	rock(10.5, 0.4, 2.4, 1.2),
	-- turn 2
	rock(11.9, 0.45, 1.8, 0.8),
	rock(12.3, -0.4, 1.8, 0.8),
	-- row 3: a pair, steep climb 2 (clear), then a rock garden with a steep little ramp
	rock(13.3, -0.4, 2.4, 1.2),
	rock(13.6, 0.4, 2.4, 1.2),
	rock(16.2, -0.8, 3.6, 2.7), -- big, edge
	rock(16.35, 0.4, 2.6, 1.4),
	ramp(16.6, 3, 1.4), -- steep bump
	rock(16.8, -0.45, 2.6, 1.5),
	rock(16.95, 0.45, 2.6, 1.5),
	-- turn 3
	rock(17.6, 0.5, 2.0, 0.9),
	log(18.5, 1.0),
	-- row 4: ledges left and right, climb 3 (clear), more pairs
	ledge(19.4, -0.5, 1.0),
	ledge(19.75, 0.5, 1.2),
	rock(22.2, -0.35, 2.6, 1.4),
	rock(22.4, 0.4, 2.6, 1.5),
	ramp(22.65, 4.5, 1.2), -- middle bump
	rock(22.9, -0.8, 3.8, 2.8), -- big, edge
	-- turn 4
	rock(23.9, -0.45, 1.8, 0.8),
	rock(24.2, 0.45, 1.8, 0.8),
	-- row 5: a pair, steep climb 4 (clear), then a log and the last pair to the flag
	rock(25.3, 0.4, 2.6, 1.5),
	rock(25.6, -0.4, 2.6, 1.5),
	log(28.15, 1.0),
	rock(28.35, -0.35, 2.4, 1.3),
	rock(28.5, 0.35, 2.4, 1.3),
} :: { Feature }

-- Start 10 in front of the first point (so the chase cam clears the wall behind), facing
-- along the trail.
local path = Plot.path()
Plot.spawn = Kit.spawnAt(path[1], -10)
Plot.START_U = 1.5
Plot.FINISH_U = 28.7

local function gate(u: number, depth: number): Gate
	local x, z, h, tx, tz = Plot.at(u)
	return { x = x, y = h, z = z, dx = tx, dz = tz, halfWidth = HALF, depth = depth }
end

-- Start, a checkpoint at the top of climb 2 and one in turn 4, finish just before the flag.
Plot.gates = {
	gate(Plot.START_U, 4),
	gate(16.3, 6),
	gate(24, 6),
	gate(Plot.FINISH_U, 6),
}

-- ===== Building (Roblox only) =====

local function yawCF(x: number, y: number, z: number, tx: number, tz: number): CFrame
	local pos = Vector3.new(x, y, z)
	return CFrame.lookAt(pos, pos + Vector3.new(tx, 0, tz))
end

local function buildTrail(parent: Instance, origin: CFrame)
	local n = #path
	for i = 1, n - 1 do
		local a, b = path[i], path[i + 1]
		local ha, hb = Plot.height(Plot.uOf(i)), Plot.height(Plot.uOf(i + 1))
		local len = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		local sloped = math.abs(hb - ha) > 0.01
		local steep = math.abs(hb - ha) / len > 0.2
		-- the trail top, 1 thick, its top surface on the line a-b. Climbs are dead straight, so
		-- their pieces meet edge to edge with no overlap (overlapping tilted pieces left lips that
		-- tipped the car); flat pieces overlap a little to close the gaps round the bends.
		local road = Kit.slab(
			parent,
			"Road",
			origin,
			Vector3.new(a.x, ha - 0.5, a.z),
			Vector3.new(b.x, hb - 0.5, b.z),
			ROAD,
			1,
			if sloped then 0 else 3,
			if steep then C.orange else C.dirt
		)
		road:SetAttribute("Grip", Plot.grip)
		road.Material = Enum.Material.Ground
		-- solid ground under a raised trail, down to the floor
		local low = math.min(ha, hb) - 1
		if low > 0.5 then
			local mx, mz = (a.x + b.x) / 2, (a.z + b.z) / 2
			Kit.part(
				parent,
				"Fill",
				origin,
				Vector3.new(ROAD + 3, low, len + 3),
				yawCF(mx, low / 2, mz, b.x - a.x, b.z - a.z),
				C.ground
			)
		end
		-- walls on both sides, so nobody tumbles off a high row. A post at every joint closes the
		-- gaps on the outside of the bends.
		for _, side in { -1, 1 } do
			local off = (HALF + 0.75) * side
			local pa = Vector3.new(a.x - a.tz * off, ha + WALL / 2 - 0.5, a.z + a.tx * off)
			local pb = Vector3.new(b.x - b.tz * off, hb + WALL / 2 - 0.5, b.z + b.tx * off)
			Kit.slab(parent, "Wall", origin, pa, pb, 1.5, WALL + 1, 3, C.wall)
			Kit.part(
				parent,
				"Wall",
				origin,
				Vector3.new(2, WALL + 1, 2),
				yawCF(pb.X, pb.Y, pb.Z, b.tx, b.tz),
				C.wall
			)
		end
	end
	-- end caps: behind the start and behind the flag
	for _, e in { { s = path[1], back = -4 }, { s = path[n], back = 4 } } do
		local h = Plot.height(if e.back < 0 then 1 else Plot.LAST_U)
		Kit.part(
			parent,
			"Wall",
			origin,
			Vector3.new(ROAD + 3, h + WALL + 1, 1.5),
			yawCF(
				e.s.x + e.s.tx * e.back,
				(h + WALL + 1) / 2 - 0.5,
				e.s.z + e.s.tz * e.back,
				e.s.tx,
				e.s.tz
			),
			C.wall
		)
	end
end

local function buildFeature(parent: Instance, origin: CFrame, f: Feature)
	local x, z, h = Plot.spot(f.u, f.side)
	local _, _, _, tx, tz = Plot.at(f.u)
	if f.kind == "rock" then
		Kit.rock(parent, origin, x, h + f.lift - f.r, z, f.r)
	elseif f.kind == "ledge" then
		-- a block over half the trail: one side of the car steps up
		local p = Kit.part(
			parent,
			"Ledge",
			origin,
			Vector3.new(HALF, f.lift + 1, f.r),
			yawCF(x, h + (f.lift - 1) / 2, z, tx, tz),
			C.rock
		)
		p.Material = Enum.Material.Slate
	elseif f.kind == "log" then
		-- a round log across the whole trail (a cylinder lies along its X, which points across)
		local p = Kit.part(
			parent,
			"Log",
			origin,
			Vector3.new(ROAD, f.r * 2, f.r * 2),
			yawCF(x, h + f.lift - f.r, z, tx, tz),
			C.ground
		)
		p.Shape = Enum.PartType.Cylinder
		p.Material = Enum.Material.Wood
	elseif f.kind == "ramp" then
		-- up and down: a small wedge bump across the trail
		local half = f.r
		local up = Vector3.new(x - tx * half, h, z - tz * half)
		local top = Vector3.new(x, h + f.lift, z)
		local down = Vector3.new(x + tx * half, h, z + tz * half)
		Kit.ramp(parent, "Bump", origin, up, top, ROAD, C.dirt)
		Kit.ramp(parent, "Bump", origin, down, top, ROAD, C.dirt)
	end
end

function Plot.build(parent: Instance, origin: CFrame)
	buildTrail(parent, origin)
	for _, f in Plot.features do
		buildFeature(parent, origin, f)
	end
	-- the flag at the end, on a light pad
	local fx, fz, top, tx, tz = Plot.at(Plot.LAST_U)
	Kit.part(
		parent,
		"Pad",
		origin,
		Vector3.new(ROAD - 2, 0.2, 10),
		yawCF(fx, top + 0.1, fz, tx, tz),
		C.pad
	).CanCollide =
		false
	local pole = Kit.part(
		parent,
		"Flag",
		origin,
		Vector3.new(0.6, 14, 0.6),
		CFrame.new(fx - tz * (HALF - 3), top + 7, fz + tx * (HALF - 3)),
		C.white
	)
	pole.CanCollide = false
	Kit.part(
		parent,
		"Flag",
		origin,
		Vector3.new(7, 4, 0.3),
		CFrame.new(fx - tz * (HALF - 3) - 3.5 * tx, top + 12, fz + tx * (HALF - 3) - 3.5 * tz),
		C.red
	).CanCollide =
		false
	-- start and finish lines
	for _, u in { Plot.START_U, Plot.FINISH_U } do
		local x, z, h, dx, dz = Plot.at(u)
		Kit.line(parent, origin, x, h, z, dx, dz, ROAD, C.white)
	end
end

return Plot
