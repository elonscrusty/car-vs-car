--!strict
-- Builds the Smash arena from ArenaData (arena-topdown-v2.png): grass floor, the winding road with
-- red/white curbs and crosswalks, the sand patch and its red bumper wall, the two pink hills with
-- ramps, the purple step, orange cover walls, lollipop trees and the purple outer wall.
-- LOOK RULE: clean low-poly, flat colours, SmoothPlastic only, faceted shapes (the hills are
-- wedge-built prisms, the tree tops two turned cubes). No studs, bricks, text or logos.
-- Built big (map-local big units) and shrunk to RC size like the race maps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaData = require(ReplicatedStorage.Shared.ArenaData)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local MapKit = require(ReplicatedStorage.Shared.Maps.MapKit)

local ArenaBuilder = {}

type Pt = ArenaData.Pt

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- palette (LOOK RULE: grass green, sky blue, sunny yellow, cherry red, hot pink, dark navy)
local GRASS = rgb(116, 204, 84)
local ROAD = rgb(92, 98, 118)
local CURB_RED, CURB_WHITE = rgb(225, 40, 50), rgb(250, 250, 250)
local SAND = rgb(250, 190, 96)
local BUMPER = rgb(225, 40, 50)
local PINK, PINK_RAMP = rgb(240, 96, 200), rgb(255, 160, 225)
local PURPLE, PURPLE_STEP = rgb(136, 60, 196), rgb(176, 96, 220)
local ORANGE = rgb(255, 140, 40)
local CANDY, CANDY_2 = rgb(214, 44, 178), rgb(255, 110, 200)
local STICK = rgb(252, 248, 240)
local TRIM, NAVY = rgb(196, 128, 246), rgb(34, 40, 78)
local YELLOW, SKY = rgb(255, 214, 40), rgb(80, 180, 255)
local GRASS_DARK, GRASS_LIGHT = rgb(92, 182, 70), rgb(146, 220, 100)
local BUSH, BUSH_2 = rgb(56, 150, 64), rgb(84, 176, 72)
local ROCK, ROCK_2 = rgb(172, 168, 196), rgb(146, 142, 176)
local CRATE, CRATE_BAND = rgb(255, 196, 60), rgb(230, 120, 30)
local FLAGS = { CURB_RED, YELLOW, PINK, SKY }
local PETALS = { PINK, YELLOW, CURB_WHITE, CANDY_2 }

local K = ArenaData.K

-- picture point -> map-local Vector3 at height y
local function v(p: Pt, y: number): Vector3
	local x, z = ArenaData.at(p)
	return Vector3.new(x, y, z)
end

-- every part: anchored, no touch events; solid = karts bump it and the wheels and camera see it
local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	solid: boolean,
	class: string?
): BasePart
	local p = Instance.new((class or "Part") :: any) :: BasePart
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	p.CanCollide = solid
	p.CanQuery = solid
	p.CastShadow = solid
	p.Parent = parent
	return p
end

-- a flat strip from a to b (map-local), top at `top`
local function strip(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	top: number,
	color: Color3,
	extra: number
)
	local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local mid = Vector3.new((a.X + b.X) / 2, top - 0.05, (a.Z + b.Z) / 2)
	return part(
		parent,
		name,
		Vector3.new(width, 0.1, d.Magnitude + extra),
		CFrame.lookAt(mid, mid + d),
		color,
		true
	)
end

-- a solid upright wall from a to b (map-local, y ignored)
local function wall(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	thick: number,
	h: number,
	color: Color3
)
	local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local mid = Vector3.new((a.X + b.X) / 2, h / 2, (a.Z + b.Z) / 2)
	return part(
		parent,
		name,
		Vector3.new(thick, h, d.Magnitude + thick),
		CFrame.lookAt(mid, mid + d),
		color,
		true
	)
end

-- A right-triangle prism standing from y0 to y1: right angle at d, the other corners p and q.
local function rightPrism(
	parent: Instance,
	name: string,
	d: Vector3,
	p: Vector3,
	q: Vector3,
	y0: number,
	y1: number,
	color: Color3,
	solid: boolean?
)
	local lp, lq = (p - d).Magnitude, (q - d).Magnitude
	if lp < 0.05 or lq < 0.05 then
		return
	end
	-- a WedgePart's cross-section (local Y-Z) has its right angle at (-Y/2, +Z/2); stand it on
	-- its X axis so that triangle lies flat
	local uy, uz = (p - d).Unit, -(q - d).Unit
	local ux = uy:Cross(uz)
	if ux.Y < 0 then
		uy, uz = (q - d).Unit, -(p - d).Unit
		lp, lq = lq, lp
		ux = uy:Cross(uz)
	end
	local c = d + uy * (lp / 2) - uz * (lq / 2)
	local cf = CFrame.fromMatrix(Vector3.new(c.X, (y0 + y1) / 2, c.Z), ux, uy, uz)
	part(parent, name, Vector3.new(y1 - y0, lp, lq), cf, color, solid ~= false, "WedgePart")
end

-- A convex polygon (picture points) as a solid flat-topped block from y0 to y1, built from
-- wedges (each fan triangle split at its foot into two right triangles): low-poly facets.
local function prism(
	parent: Instance,
	name: string,
	poly: { Pt },
	y0: number,
	y1: number,
	color: Color3,
	solid: boolean?
)
	local pts: { Vector3 } = {}
	for _, p in poly do
		table.insert(pts, v(p, 0))
	end
	for i = 2, #pts - 1 do
		local tri = { pts[1], pts[i], pts[i + 1] }
		-- base = the longest side, apex = the corner across from it
		local best, bi = -1, 1
		for k = 1, 3 do
			local len = (tri[k % 3 + 1] - tri[k]).Magnitude
			if len > best then
				best, bi = len, k
			end
		end
		local a, b, c = tri[bi], tri[bi % 3 + 1], tri[(bi + 1) % 3 + 1]
		local ab = (b - a).Unit
		local foot = a + ab * (c - a):Dot(ab)
		rightPrism(parent, name, foot, c, a, y0, y1, color, solid)
		rightPrism(parent, name, foot, c, b, y0, y1, color, solid)
	end
end

-- A solid triangle a-b-c (map-local) as two wedges `thick` deep, its face on the triangle and its
-- back toward -out (out: any direction on the face's outer side). The low-poly facet.
local function tri(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	out: Vector3,
	thick: number,
	color: Color3
)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	if ac:Cross(ab).Magnitude < 1e-4 then
		return
	end
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local n = if right:Dot(out) >= 0 then right else -right
	local sink = -n * (thick / 2)
	part(
		parent,
		name,
		Vector3.new(thick, height, math.abs(ab:Dot(back))),
		CFrame.fromMatrix((a + b) / 2 + sink, right, up, back),
		color,
		true,
		"WedgePart"
	)
	part(
		parent,
		name,
		Vector3.new(thick, height, math.abs(ac:Dot(back))),
		CFrame.fromMatrix((a + c) / 2 + sink, -right, up, -back),
		color,
		true,
		"WedgePart"
	)
end

-- A flat-topped hill with faceted sloped sides: the top is poly moved in by `inset` on `sides`
-- (ArenaData.insetPoly), each side a two-triangle facet from the foot up to the top edge.
local function mesa(
	parent: Instance,
	name: string,
	poly: { Pt },
	h: number,
	inset: number,
	sides: { number }?,
	top: Color3,
	side: Color3
)
	local inner = ArenaData.insetPoly(poly, inset, sides)
	local n = #poly
	local tops: { Vector3 } = {}
	for i = 1, n do
		tops[i] = v(inner[i], h)
	end
	for i = 2, n - 1 do
		tri(parent, name, tops[1], tops[i], tops[i + 1], Vector3.yAxis, 1, top)
	end
	local mid = Vector3.zero
	for _, p in tops do
		mid += p / n
	end
	for i = 1, n do
		local j = i % n + 1
		if sides == nil or table.find(sides, i) then
			local a, b = v(poly[i], 0), v(poly[j], 0)
			local out = (a + b) / 2 - mid
			out = Vector3.new(out.X, 0, out.Z)
			tri(parent, name, a, b, tops[j], out, 1, side)
			tri(parent, name, a, tops[j], tops[i], out, 1, side)
		end
	end
end

-- the winding road's centre line (closed Catmull-Rom through ArenaData.ROAD), map-local
local function roadLine(perSeg: number): { Vector3 }
	local pts = ArenaData.ROAD
	local n = #pts
	local out: { Vector3 } = {}
	for i = 1, n do
		local p0, p1, p2, p3 = pts[(i - 2) % n + 1], pts[i], pts[i % n + 1], pts[(i + 1) % n + 1]
		for s = 0, perSeg - 1 do
			local t = s / perSeg
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
			table.insert(
				out,
				v({ cr(p0[1], p1[1], p2[1], p3[1]), cr(p0[2], p1[2], p2[2], p3[2]) }, 0)
			)
		end
	end
	return out
end

local function buildFloor(folder: Instance)
	local s = ArenaData.SIZE
	part(folder, "Grass", Vector3.new(s, 4, s), CFrame.new(0, -2, 0), GRASS, true)
	-- the purple outer wall, all round
	local w, h = ArenaData.WALL * K, ArenaData.WALL_H
	for _, side in { -1, 1 } do
		part(
			folder,
			"OuterWall",
			Vector3.new(s, h, w),
			CFrame.new(0, h / 2, side * (s - w) / 2),
			PURPLE,
			true
		)
		part(
			folder,
			"OuterWall",
			Vector3.new(w, h, s),
			CFrame.new(side * (s - w) / 2, h / 2, 0),
			PURPLE,
			true
		)
	end
	-- an unseen guard on top, as tall as the race maps' edge: no blast throws a kart out
	local guard = MapKit.WALL_H - h
	for _, side in { -1, 1 } do
		for _, size in { Vector3.new(s, guard, w), Vector3.new(w, guard, s) } do
			local at = if size.X > size.Z
				then Vector3.new(0, h + guard / 2, side * (s - w) / 2)
				else Vector3.new(side * (s - w) / 2, h + guard / 2, 0)
			local g = part(folder, "WallGuard", size, CFrame.new(at), PURPLE, true)
			g.Transparency = 1
			g.CanQuery = false
			g.CastShadow = false
		end
	end
	-- a lighter trim along the top, a pillar every so often on the inside face, and on each pillar
	-- a post with a bright pennant (looks only: up out of the way)
	local inner = s / 2 - w
	for _, side in { -1, 1 } do
		part(
			folder,
			"WallTrim",
			Vector3.new(s, 1.2, w + 1),
			CFrame.new(0, h + 0.6, side * (s - w) / 2),
			TRIM,
			true
		)
		part(
			folder,
			"WallTrim",
			Vector3.new(w + 1, 1.2, s),
			CFrame.new(side * (s - w) / 2, h + 0.6, 0),
			TRIM,
			true
		)
	end
	local GAP = 36
	local k = 0
	for along = -s / 2 + GAP, s / 2 - GAP / 2, GAP do
		for _, face in { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } } do
			k += 1
			local nx, nz = face[1], face[2] -- the wall's side of the arena
			local tx, tz = -nz, nx -- along the wall
			local base = Vector3.new(nx * inner + tx * along, 0, nz * inner + tz * along)
			local into = Vector3.new(-nx, 0, -nz)
			part(
				folder,
				"WallPillar",
				Vector3.new(3, h + 1.6, 3),
				CFrame.lookAt(base - into * 0.7, base) + Vector3.new(0, (h + 1.6) / 2, 0),
				TRIM,
				true
			)
			local post = part(
				folder,
				"FlagPost",
				Vector3.new(8, 0.5, 0.5),
				CFrame.new(base + Vector3.new(0, h + 5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				NAVY,
				false
			) :: Part
			post.Shape = Enum.PartType.Cylinder
			-- the pennant: a thin wedge, its point flying along the wall
			local top = base + Vector3.new(0, h + 7.5, 0)
			part(
				folder,
				"Pennant",
				Vector3.new(0.2, 2.6, 4.5),
				CFrame.fromMatrix(
					top + Vector3.new(tx, 0, tz) * 2.25,
					into,
					Vector3.yAxis,
					Vector3.new(tx, 0, tz)
				),
				FLAGS[k % #FLAGS + 1],
				false,
				"WedgePart"
			)
		end
	end
	mesa(
		folder,
		"Platform",
		ArenaData.STEP,
		ArenaData.STEP_H,
		ArenaData.STEP_SLOPE,
		ArenaData.STEP_SIDES,
		PURPLE_STEP,
		PURPLE
	)
end

local function buildRoad(folder: Instance)
	local line = roadLine(10)
	local n = #line
	local rw, cw = ArenaData.ROAD_W * K, ArenaData.CURB * K
	for i = 1, n do
		local a, b = line[i], line[i % n + 1]
		strip(folder, "Road", a, b, rw, 0.1, ROAD, 2)
		-- a round patch at each joint fills the wedge on the outside of a bend
		local patch = part(
			folder,
			"Road",
			Vector3.new(0.1, rw, rw),
			CFrame.new(a.X, 0.05, a.Z) * CFrame.Angles(0, 0, math.pi / 2),
			ROAD,
			true
		) :: Part
		patch.Shape = Enum.PartType.Cylinder
		local d = (b - a)
		local right = Vector3.new(-d.Z, 0, d.X).Unit
		for _, side in { -1, 1 } do
			local off = right * side * (rw / 2 + cw / 2)
			strip(
				folder,
				"Curb",
				a + off,
				b + off,
				cw,
				0.12,
				if i % 2 == 0 then CURB_RED else CURB_WHITE,
				0.4
			)
		end
	end
	-- crosswalks: white bars across the road
	for _, c in ArenaData.CROSSWALKS do
		local mid = v(c.at, 0)
		for k = -3, 3 do
			local along = if c.across
				then Vector3.new(k * 3 * K, 0, 0)
				else Vector3.new(0, 0, k * 3 * K)
			local size = if c.across
				then Vector3.new(2 * K, 0.1, 16 * K)
				else Vector3.new(16 * K, 0.1, 2 * K)
			part(
				folder,
				"Crosswalk",
				size,
				CFrame.new(mid + along + Vector3.new(0, 0.11, 0)),
				CURB_WHITE,
				true
			)
		end
	end
end

local function buildSand(folder: Instance)
	local sand = ArenaData.SAND
	prism(folder, "Sand", sand, -0.1, 0.25, SAND)
	for _, p in folder:GetChildren() do
		if p.Name == "Sand" then
			-- soft sand: a bit less grip and a little drag (grass and road are both normal)
			p:SetAttribute("Grip", 0.85)
			p:SetAttribute("Drag", 0.3)
		end
	end
	-- the red bumper wall round it, open where SAND_GAPS says
	local n = #sand
	for i = 1, n do
		local a, b = v(sand[i], 0), v(sand[i % n + 1], 0)
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
			wall(
				folder,
				"Bumper",
				a:Lerp(b, u0),
				a:Lerp(b, u1),
				ArenaData.BUMPER_W * K,
				ArenaData.BUMPER_H,
				BUMPER
			)
		end
	end
end

local function buildHills(folder: Instance)
	for _, h in ArenaData.HILLS do
		mesa(folder, h.name, h.poly, h.h, h.slope, nil, PINK, CANDY)
	end
	for i, r in ArenaData.RAMPS do
		local a, b = v(r.from, 0), v(r.to, 0)
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		-- a WedgePart rises from its front (-Z) to its back (+Z): face it back down the ramp. It
		-- ends a hair inside the cliff, so it is built a touch taller: no lip at the hill's edge
		local h = r.h * 1.04
		local mid = (a + b) / 2 + Vector3.new(0, h / 2, 0)
		part(
			folder,
			"Ramp" .. i,
			Vector3.new(r.width * K, h, len),
			CFrame.lookAt(mid, mid - dir),
			PINK_RAMP,
			true,
			"WedgePart"
		)
		-- the flat deck from the ramp's top over the hill's sloped edge
		local deck = ArenaData.RAMP_DECK * K
		local dm = b + dir * (deck / 2) + Vector3.new(0, r.h - 0.5, 0)
		part(
			folder,
			"RampDeck" .. i,
			Vector3.new(r.width * K, 1, deck),
			CFrame.lookAt(dm, dm + dir),
			PINK_RAMP,
			true
		)
	end
end

local function buildCover(folder: Instance)
	for _, seg in ArenaData.COVER do
		wall(
			folder,
			"Cover",
			v(seg[1], 0),
			v(seg[2], 0),
			ArenaData.COVER_W * K,
			ArenaData.COVER_H,
			ORANGE
		)
	end
end

local function buildTrees(folder: Instance)
	for i, t in ArenaData.TREES do
		local base = v(t, 0)
		local h = 26
		local tk = ArenaData.TRUNK
		local stick = part(
			folder,
			"TreeStick",
			Vector3.new(h, tk, tk),
			CFrame.new(base + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			STICK,
			true
		) :: Part
		stick.Shape = Enum.PartType.Cylinder
		-- the candy top: two turned cubes make a faceted gem, up out of the karts' way
		local r = ArenaData.TREE_R * K
		local top = base + Vector3.new(0, h + r * 0.6, 0)
		local spin = i * 0.7
		part(
			folder,
			"TreeTop",
			Vector3.new(r * 1.5, r * 1.5, r * 1.5),
			CFrame.new(top) * CFrame.Angles(0.6, spin, 0.6),
			CANDY,
			false
		)
		part(
			folder,
			"TreeTop",
			Vector3.new(r * 1.3, r * 1.3, r * 1.3),
			CFrame.new(top) * CFrame.Angles(-0.4, spin + 0.8, 0.9),
			CANDY_2,
			false
		)
	end
end

-- a low-poly lump: two turned blocks (rocks, bushes)
local function lump(
	parent: Instance,
	name: string,
	at: Vector3,
	r: number,
	h: number,
	spin: number,
	c1: Color3,
	c2: Color3,
	solid: boolean
)
	part(
		parent,
		name,
		Vector3.new(r * 1.6, h, r * 1.6),
		CFrame.new(at + Vector3.new(0, h * 0.35, 0)) * CFrame.Angles(0.25, spin, 0.2),
		c1,
		solid
	)
	part(
		parent,
		name,
		Vector3.new(r * 1.2, h * 0.8, r * 1.2),
		CFrame.new(at + Vector3.new(r * 0.35, h * 0.5, -r * 0.2))
			* CFrame.Angles(-0.3, spin + 0.7, 0.35),
		c2,
		solid
	)
end

local function buildCoverExtras(folder: Instance)
	for i, r in ArenaData.ROCKS do
		local rad = r[3] * K
		lump(folder, "Rock", v({ r[1], r[2] }, 0), rad, rad * 1.3, i * 1.3, ROCK, ROCK_2, true)
	end
	local c = ArenaData.CRATE * K
	for i, p in ArenaData.CRATES do
		local cf = CFrame.new(v(p, c / 2)) * CFrame.Angles(0, i * 0.5, 0)
		part(folder, "Crate", Vector3.new(c, c, c), cf, CRATE, true)
		-- two bands round it
		part(folder, "CrateBand", Vector3.new(c + 0.2, c + 0.2, c * 0.22), cf, CRATE_BAND, false)
		part(folder, "CrateBand", Vector3.new(c * 0.22, c + 0.2, c + 0.2), cf, CRATE_BAND, false)
	end
	local br = ArenaData.BARREL_R * K
	for _, seg in ArenaData.BARRELS do
		local a, b = v(seg[1], 0), v(seg[2], 0)
		local count = math.max(2, math.floor((b - a).Magnitude / (br * 2.1)) + 1)
		for k = 0, count - 1 do
			local at = a:Lerp(b, k / (count - 1))
			local bh = 4.5
			local barrel = part(
				folder,
				"Barrel",
				Vector3.new(bh, br * 2, br * 2),
				CFrame.new(at + Vector3.new(0, bh / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
				CURB_RED,
				true
			) :: Part
			barrel.Shape = Enum.PartType.Cylinder
			local band = part(
				folder,
				"BarrelBand",
				Vector3.new(0.8, br * 2 + 0.15, br * 2 + 0.15),
				barrel.CFrame,
				CURB_WHITE,
				false
			) :: Part
			band.Shape = Enum.PartType.Cylinder
		end
	end
end

local function buildArch(folder: Instance)
	local a = ArenaData.ARCH
	local pts = ArenaData.archPillars()
	local p1, p2 = v(pts[1], 0), v(pts[2], 0)
	local pw = a.pillar * K
	for _, p in { p1, p2 } do
		part(
			folder,
			"ArchPillar",
			Vector3.new(pw, a.h, pw),
			CFrame.new(p + Vector3.new(0, a.h / 2, 0)),
			NAVY,
			true
		)
		part(
			folder,
			"ArchCap",
			Vector3.new(pw + 1, 1.5, pw + 1),
			CFrame.new(p + Vector3.new(0, a.h + 0.75, 0)) * CFrame.Angles(0, math.pi / 4, 0),
			YELLOW,
			false
		)
	end
	-- the beam: a two-row checker between the pillars (looks only: it never stops the camera)
	local span = p2 - p1
	local len = span.Magnitude
	local dir = span.Unit
	local cells = 12
	local cl = len / cells
	for row = 0, 1 do
		for k = 0, cells - 1 do
			local at = p1 + dir * (cl * (k + 0.5)) + Vector3.new(0, a.h - 1.25 - row * 2.5, 0)
			part(
				folder,
				"ArchBeam",
				Vector3.new(2, 2.5, cl),
				CFrame.lookAt(at, at + dir),
				if (k + row) % 2 == 0 then YELLOW else NAVY,
				false
			)
		end
	end
	-- pennants hanging under the beam
	for k = 1, 5 do
		local at = p1 + dir * (len * k / 6) + Vector3.new(0, a.h - 4.3, 0)
		part(
			folder,
			"ArchFlag",
			Vector3.new(0.2, 2.6, 2.2),
			CFrame.fromMatrix(at, dir, -Vector3.yAxis, Vector3.new(-dir.Z, 0, dir.X)),
			FLAGS[k % #FLAGS + 1],
			false,
			"WedgePart"
		)
	end
end

-- looks only: grass patches in two shades, bushes, flower clumps (karts drive through them)
local function buildDecor(folder: Instance)
	for i, g in ArenaData.PATCHES do
		local poly = {}
		for k = 0, 6 do
			local ang = k * math.pi * 2 / 7 + i
			local r = g[3] * (0.8 + 0.2 * math.sin(k * 2.3 + i))
			table.insert(poly, { g[1] + math.cos(ang) * r, g[2] + math.sin(ang) * r })
		end
		prism(
			folder,
			"GrassPatch",
			poly,
			-0.05,
			0.03,
			if g[4] == 1 then GRASS_DARK else GRASS_LIGHT,
			false
		)
	end
	for i, b in ArenaData.BUSHES do
		lump(folder, "Bush", v(b, 0), 6, 5, i * 0.9, BUSH, BUSH_2, false)
		lump(folder, "Bush", v(b, 0) + Vector3.new(4, 0, 3), 4, 3.5, i * 1.7, BUSH_2, BUSH, false)
	end
	for i, f in ArenaData.FLOWERS do
		local at = v(f, 0)
		for k = 0, 4 do
			local ang = k * 1.3 + i
			local off = Vector3.new(math.cos(ang), 0, math.sin(ang)) * (1.2 + k * 0.5)
			part(
				folder,
				"Flower",
				Vector3.new(1.6, 1.6, 1.6),
				CFrame.new(at + off + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0.6, ang, 0.6),
				PETALS[(k + i) % #PETALS + 1],
				false
			)
		end
	end
end

-- The arena model, built big at the origin (no scaling, not placed): tests and renders read it.
function ArenaBuilder.buildBig(): Model
	local model = Instance.new("Model")
	model.Name = "SmashArena"
	buildFloor(model)
	buildRoad(model)
	buildSand(model)
	buildHills(model)
	buildCover(model)
	buildCoverExtras(model)
	buildArch(model)
	buildTrees(model)
	buildDecor(model)
	return model
end

-- Build it, shrink it to RC size and put it where ArenaData says (workspace.SmashArena).
function ArenaBuilder.build(): Model
	local old = workspace:FindFirstChild("SmashArena")
	if old then
		old:Destroy()
	end
	local model = ArenaBuilder.buildBig()
	model.WorldPivot = CFrame.identity
	model:ScaleTo(TrackData.RC_SCALE)
	model:PivotTo(
		CFrame.new(ArenaData.RC_X, 0, ArenaData.RC_Z) * CFrame.Angles(0, ArenaData.RC_ANGLE, 0)
	)
	model.Parent = workspace
	return model
end

return ArenaBuilder
