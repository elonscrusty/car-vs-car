--!strict
-- RACE plot: a twisty lap from the plot picture (plot-race.png). Start / finish on the front
-- straight, a chicane on the right, a big right sweeper, a hairpin at the back, then the long
-- left straight home. Lap timer: gate 1 is the checkered line, then chicane, sweeper, hairpin,
-- left straight, and back over the line = one lap.

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

local ROAD = 30 -- same road width as the race test carter liked
local CURB_WIDTH = 3
local CURB_HEIGHT = 0.4 -- low enough to drive over

-- Colours that tell road, edge and grass apart at a glance.
local function rgb(r: number, g: number, b: number): Color3
	local c: any = Color3
	return if c then c.fromRGB(r, g, b) else nil :: any
end
local ROAD_COLOR = rgb(52, 52, 58)
local GRASS_COLOR = rgb(86, 150, 70)

-- The picture is 120 wide, 160 deep, (0, 0) at the front left. Its numbers become plot spots:
-- picture x 60 is the plot middle, picture y 34 (the start straight) sits near the front.
local K = 2.6
local function spot(px: number, py: number): Kit.Pt
	return { x = (px - 60) * K, z = 115 - (py - 34) * K }
end

-- Driving order (the arrows in the picture).
local PICTURE = {
	{ 28, 34 }, -- front straight, the line is a bit further on
	{ 92, 34 },
	{ 108, 48 },
	{ 100, 64 },
	{ 78, 70 }, -- chicane: hard left
	{ 70, 82 },
	{ 92, 92 }, -- and back right
	{ 108, 108 },
	{ 106, 140 }, -- big right sweeper
	{ 88, 152 },
	{ 70, 140 },
	{ 56, 118 }, -- hairpin
	{ 42, 140 },
	{ 24, 152 },
	{ 12, 134 },
	{ 14, 90 }, -- long left straight home
	{ 20, 58 },
}
local POINTS: { Kit.Pt } = {}
for i, p in PICTURE do
	POINTS[i] = spot(p[1], p[2])
end

local Plot = {}
Plot.id = "race"
Plot.label = "RACE"
Plot.mode = "loop"
Plot.grip = 0.75 -- off the road is slower
Plot.ROAD = ROAD
Plot.CURB_WIDTH = CURB_WIDTH

function Plot.loop(): { Kit.Sample }
	return Kit.loop(POINTS, 8)
end

-- The sample closest to a picture spot.
local function nearest(ring: { Kit.Sample }, px: number, py: number): Kit.Sample
	local p = spot(px, py)
	local best, bestD = ring[1], math.huge
	for _, s in ring do
		local dx, dz = s.x - p.x, s.z - p.z
		local d = dx * dx + dz * dz
		if d < bestD then
			best, bestD = s, d
		end
	end
	return best
end

local ring = Plot.loop()
local line = nearest(ring, 47.5, 34) -- the checkered line
Plot.spawn = Kit.spawnAt(line, 14)
Plot.gates = {
	Kit.gateAt(line, 0, 22, 6),
	Kit.gateAt(nearest(ring, 72, 76), 0, 24, 12), -- chicane
	Kit.gateAt(nearest(ring, 108, 120), 0, 24, 12), -- sweeper
	Kit.gateAt(nearest(ring, 56, 118), 0, 24, 12), -- hairpin
	Kit.gateAt(nearest(ring, 14, 100), 0, 24, 12), -- left straight
}

function Plot.build(parent: Instance, origin: CFrame)
	-- Grass over the whole track area (drivable, just slower), under the road.
	local a = Kit.AREA
	local grass = Kit.part(
		parent,
		"Grass",
		origin,
		Vector3.new(a.maxX - a.minX, 0.04, a.maxZ - a.minZ),
		CFrame.new((a.minX + a.maxX) / 2, 0.02, (a.minZ + a.maxZ) / 2),
		GRASS_COLOR
	)
	grass:SetAttribute("Grip", Plot.grip)
	grass.Material = Enum.Material.Grass

	local loop = Plot.loop()
	Kit.ribbon(parent, origin, loop, ROAD, { grip = 1, color = ROAD_COLOR })

	-- Low red and white curbs on both edges instead of walls.
	local n = #loop
	local off = ROAD / 2 + CURB_WIDTH / 2
	for i = 1, n do
		local p, q = loop[i], loop[(i % n) + 1]
		local color = if i % 2 == 0 then C.white else C.red
		for _, side in { -1, 1 } do
			local o = off * side
			local pa = Vector3.new(p.x - p.tz * o, CURB_HEIGHT / 2, p.z + p.tx * o)
			local pb = Vector3.new(q.x - q.tz * o, CURB_HEIGHT / 2, q.z + q.tx * o)
			local curb =
				Kit.slab(parent, "Curb", origin, pa, pb, CURB_WIDTH, CURB_HEIGHT, 0.5, color)
			curb:SetAttribute("Grip", 1)
		end
	end

	-- Checkered start / finish: two rows of squares across the road.
	local g = Plot.gates[1]
	local rx, rz = -g.dz, g.dx -- across the road
	local cells = 6
	local size = ROAD / cells
	for row = 0, 1 do
		for i = 0, cells - 1 do
			local across = (i + 0.5) * size - ROAD / 2
			local along = (row - 0.5) * 3
			local color = if (i + row) % 2 == 0 then C.white else ROAD_COLOR
			Kit.line(
				parent,
				origin,
				g.x + rx * across + g.dx * along,
				0,
				g.z + rz * across + g.dz * along,
				g.dx,
				g.dz,
				size,
				color
			)
		end
	end
end

return Plot
