--!strict
-- Shared kit for every plot: the plot size, where a track may go, colours, and small helpers
-- for building with plain parts. All numbers are BIG size: the real RC plot is the same plot
-- shrunk to 0.25 by the server, so build big and never think about the small copy.
--
-- Plot-local space: (0, 0, 0) is the middle of the plot on the floor top. +Z is the front
-- (the entrance and the player), -Z is the back. The floor, the outer walls and the front
-- area (stand spot, car show, sign, entrance) are built for you.

export type Pt = { x: number, z: number }
export type Sample = { x: number, z: number, tx: number, tz: number }
export type Spawn = { x: number, y: number, z: number, dx: number, dz: number }
export type Gate = {
	x: number,
	y: number,
	z: number,
	dx: number,
	dz: number,
	halfWidth: number,
	depth: number,
}

-- What every Plots/<Type>.luau returns.
export type Plot = {
	id: string, -- "drift", "race", "rock" or "show"
	label: string, -- shown on the button and the sign
	mode: string, -- lap timer: "free" (no timer), "loop" (laps) or "oneway" (start to finish)
	grip: number, -- floor grip (1 = normal, lower = slidier)
	spawn: Spawn, -- where the car starts, plot-local, facing (dx, dz)
	gates: { Gate }, -- lap timer gates, plot-local (gate 1 = start line)
	build: (parent: Instance, origin: CFrame) -> (),
}

local Kit = {}

-- Plot size (big units; the real RC plot is 1/4 of this: 80 x 110 studs). Change these two to
-- resize every plot.
Kit.WIDTH = 320 -- x
Kit.DEPTH = 440 -- z
local FRONT = 72 -- depth of the front area (stand spot, car show, sign, entrance)
-- Front area (z from FRONT_Z to the front edge) belongs to the base: the player stands here.
Kit.FRONT_Z = Kit.DEPTH / 2 - FRONT
Kit.STAND = { x = 0, z = Kit.DEPTH / 2 - 44 }
-- The driver stand is raised like at a real RC track, so the whole plot is easy to see.
Kit.STAND_H = 48 -- about 12 studs at RC size: high enough to see the back corners of the plot
-- The track must stay inside this box (plot-local x and z, with room for the outer walls).
Kit.AREA = {
	minX = -Kit.WIDTH / 2 + 8,
	maxX = Kit.WIDTH / 2 - 8,
	minZ = -Kit.DEPTH / 2 + 8,
	maxZ = Kit.FRONT_Z - 8,
}

-- Colour helper that also loads in Lune (tests have no Color3).
local function rgb(r: number, g: number, b: number): Color3
	local c: any = Color3
	return if c then c.fromRGB(r, g, b) else nil :: any
end

Kit.COLORS = {
	ground = rgb(88, 88, 92),
	road = rgb(150, 150, 156),
	wall = rgb(190, 190, 195),
	rock = rgb(118, 116, 114),
	dirt = rgb(122, 92, 62),
	white = rgb(245, 245, 245),
	red = rgb(200, 60, 50),
	orange = rgb(224, 138, 58),
	blue = rgb(93, 127, 176),
	pad = rgb(215, 210, 195),
}

-- Smooth closed loop through the points (Catmull-Rom), with the unit direction of travel.
function Kit.loop(points: { Pt }, perSegment: number): { Sample }
	return Kit.curve(points, perSegment, true)
end

-- Smooth open path from the first point to the last.
function Kit.path(points: { Pt }, perSegment: number): { Sample }
	return Kit.curve(points, perSegment, false)
end

function Kit.curve(points: { Pt }, perSegment: number, closed: boolean): { Sample }
	local n = #points
	local function at(i: number): Pt
		if closed then
			return points[((i - 1) % n) + 1]
		end
		return points[math.clamp(i, 1, n)]
	end
	local out: { Sample } = {}
	local last = if closed then n else n - 1
	for i = 1, last do
		local p0, p1, p2, p3 = at(i - 1), at(i), at(i + 1), at(i + 2)
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
	if not closed then
		out[#out + 1] = { x = points[n].x, z = points[n].z, tx = 0, tz = 0 }
	end
	local count = #out
	for i = 1, count do
		local a = out[i]
		local b = if i < count then out[i + 1] elseif closed then out[1] else nil
		local dx, dz
		if b then
			dx, dz = b.x - a.x, b.z - a.z
		else
			local p = out[i - 1]
			dx, dz = a.x - p.x, a.z - p.z
		end
		local len = math.sqrt(dx * dx + dz * dz)
		a.tx, a.tz = dx / len, dz / len
	end
	return out
end

-- A spawn a little behind a sample, facing along the road.
function Kit.spawnAt(s: Sample, back: number): Spawn
	return { x = s.x - s.tx * back, y = 2.5, z = s.z - s.tz * back, dx = s.tx, dz = s.tz }
end

-- A lap gate across the road at a sample.
function Kit.gateAt(s: Sample, y: number, halfWidth: number, depth: number): Gate
	return { x = s.x, y = y, z = s.z, dx = s.tx, dz = s.tz, halfWidth = halfWidth, depth = depth }
end

-- Is this plot-local spot inside the track area?
function Kit.inArea(x: number, z: number): boolean
	local a = Kit.AREA
	return x >= a.minX and x <= a.maxX and z >= a.minZ and z <= a.maxZ
end

-- ===== Building (Roblox only; call these from build) =====

-- An anchored grey part at a plot-local CFrame.
function Kit.part(
	parent: Instance,
	name: string,
	origin: CFrame,
	size: Vector3,
	cf: CFrame,
	color: Color3
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = origin * cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A slab whose centre line runs from a to b (plot-local points, y = centre height).
function Kit.slab(
	parent: Instance,
	name: string,
	origin: CFrame,
	a: Vector3,
	b: Vector3,
	width: number,
	height: number,
	extra: number,
	color: Color3
): Part
	local mid = (a + b) / 2
	local len = (b - a).Magnitude + extra
	return Kit.part(
		parent,
		name,
		origin,
		Vector3.new(width, height, len),
		CFrame.lookAt(mid, b),
		color
	)
end

export type RibbonOpts = {
	grip: number?, -- road grip (default 1)
	color: Color3?,
	closed: boolean?, -- default true (a loop)
	walls: number?, -- wall height on both sides (nil = no walls)
}

-- A flat road along samples (a loop by default). Parts are named "Road" and "Wall".
function Kit.ribbon(
	parent: Instance,
	origin: CFrame,
	ring: { Sample },
	width: number,
	opts: RibbonOpts?
)
	local o: RibbonOpts = opts or {}
	local closed = o.closed ~= false
	local n = #ring
	local top = 0.1
	for i = 1, if closed then n else n - 1 do
		local a, b = ring[i], ring[(i % n) + 1]
		local road = Kit.slab(
			parent,
			"Road",
			origin,
			Vector3.new(a.x, top / 2, a.z),
			Vector3.new(b.x, top / 2, b.z),
			width,
			top,
			1.5,
			o.color or Kit.COLORS.road
		)
		road:SetAttribute("Grip", o.grip or 1)
		local h = o.walls
		if h then
			for _, side in { -1, 1 } do
				local off = (width / 2 + 1) * side
				local pa = Vector3.new(a.x - a.tz * off, h / 2, a.z + a.tx * off)
				local pb = Vector3.new(b.x - b.tz * off, h / 2, b.z + b.tx * off)
				Kit.slab(parent, "Wall", origin, pa, pb, 1.5, h, 1.5, Kit.COLORS.wall)
			end
		end
	end
end

-- A sloped slab from a (low) to b (high), top surface on the line a-b. Drive from a to b.
function Kit.ramp(
	parent: Instance,
	name: string,
	origin: CFrame,
	a: Vector3,
	b: Vector3,
	width: number,
	color: Color3
): Part
	local dir = (b - a).Unit
	local right = dir:Cross(Vector3.yAxis).Unit
	local back = -dir
	local up = back:Cross(right)
	local mid = (a + b) / 2
	return Kit.part(
		parent,
		name,
		origin,
		Vector3.new(width, 1, (b - a).Magnitude),
		CFrame.fromMatrix(mid - up * 0.5, right, up, back),
		color
	)
end

-- A flat round disc lying on the floor (top at y + height / 2).
function Kit.disc(
	parent: Instance,
	name: string,
	origin: CFrame,
	x: number,
	y: number,
	z: number,
	radius: number,
	height: number,
	color: Color3
): Part
	local p = Kit.part(
		parent,
		name,
		origin,
		Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90)),
		color
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A round rock sunk a little into the ground.
function Kit.rock(
	parent: Instance,
	origin: CFrame,
	x: number,
	y: number,
	z: number,
	r: number
): Part
	local p = Kit.part(
		parent,
		"Rock",
		origin,
		Vector3.new(r * 2, r * 2, r * 2),
		CFrame.new(x, y, z),
		Kit.COLORS.rock
	)
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Slate
	return p
end

-- A painted line on the floor (no bump), centred at (x, z), running across direction (dx, dz).
function Kit.line(
	parent: Instance,
	origin: CFrame,
	x: number,
	y: number,
	z: number,
	dx: number,
	dz: number,
	length: number,
	color: Color3
): Part
	local pos = Vector3.new(x, y + 0.16, z)
	local p = Kit.part(
		parent,
		"Line",
		origin,
		Vector3.new(length, 0.1, 3),
		CFrame.lookAt(pos, pos + Vector3.new(dx, 0, dz)),
		color
	)
	p.CanCollide = false
	return p
end

return Kit
