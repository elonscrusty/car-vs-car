--!strict
-- Builds the Smash arena from ArenaData: a destruction-derby junkyard (carter's pick "B night yard",
-- 10-29): one open dirt floor with tyre tracks (no road, curbs or lane lines: not a racetrack), a
-- mud pit, the pink hills with ramps, orange cover walls, a steel outer wall with crushed cars
-- piled against it, grandstands and light towers outside.
-- LOOK RULE: clean low-poly, flat colours, SmoothPlastic only, faceted shapes (the hills are
-- wedge-built prisms, the tree tops turned blocks). No studs, bricks, text or logos.
-- Built big (map-local big units) and shrunk to RC size like the race maps.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaData = require(ReplicatedStorage.Shared.ArenaData)
local ArenaHorizon = require(ReplicatedStorage.Shared.ArenaHorizon)
local TrackData = require(ReplicatedStorage.Shared.TrackData)

local ArenaBuilder = {}

type Pt = ArenaData.Pt

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- palette (LOOK RULE: grass green, sky blue, sunny yellow, cherry red, hot pink, dark navy)
local GRASS, GRASS_CHECK = rgb(150, 108, 70), rgb(134, 96, 62) -- (the dirt floor)
local CURB_RED, CURB_WHITE = rgb(214, 70, 72), rgb(240, 238, 232)
-- the night-yard look: yellow/black hazard wall top, a dark steel wall, crushed cars, grandstands
local HAZARD, HAZARD_DARK = rgb(255, 214, 40), rgb(36, 38, 58)
local WALL_BLUE, SKID = rgb(70, 76, 98), rgb(88, 62, 40)
local STEEL, STAND = rgb(138, 142, 154), rgb(58, 58, 74)
local WRECKS = {
	rgb(168, 74, 42),
	rgb(106, 122, 138),
	rgb(200, 162, 58),
	rgb(138, 58, 58),
	rgb(74, 106, 138),
	rgb(122, 106, 88),
	rgb(200, 200, 192),
}
local SEATS = { rgb(224, 56, 60), rgb(255, 214, 40), rgb(47, 140, 255), rgb(240, 238, 232) }
local SAND = rgb(96, 70, 48) -- (the mud pit)
local BUMPER = rgb(225, 40, 50)
local PINK = rgb(234, 122, 196)
local PURPLE, PURPLE_STEP = rgb(136, 60, 196), rgb(176, 96, 220)
local ORANGE = rgb(255, 140, 40)
local CANDY, CANDY_2 = rgb(214, 44, 178), rgb(255, 110, 200)
local STICK = rgb(252, 248, 240)
local TRIM, NAVY = rgb(196, 128, 246), rgb(34, 40, 78)
local YELLOW, SKY = rgb(255, 214, 40), rgb(80, 180, 255)
local GRASS_DARK, GRASS_LIGHT = rgb(112, 78, 50), rgb(168, 126, 86)
local GRASS_FAR = rgb(116, 88, 62)
local HILL_FAR, HILL_FAR_2 = rgb(124, 96, 70), rgb(146, 114, 82)
local BUSH, BUSH_2 = rgb(56, 150, 64), rgb(84, 176, 72)
local SCRAP, SCRAP_2 = rgb(110, 96, 88), rgb(150, 70, 44)
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

-- flat floor layers throw no shadow worth the phone's time
local FLAT = { Grass = true, Sand = true }

-- upright things a kart bumps: next to no friction, so a kart that hits one at an angle slides
-- along it and off instead of sticking (round 7: karts were stuck half the match)
local SLIP = {
	OuterWall = true,
	WallTrim = true,
	WallCorner = true,
	Cover = true,
	CoverCap = true,
	Bumper = true,
	BumperCap = true,
	HillFoot = true,
	HillFootPost = true,
	Barrel = true,
	ArchPillar = true,
	TreeStick = true,
}
local SLIPPY = PhysicalProperties.new(0.7, 0.02, 0.15, 100, 1)

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
	p.CastShadow = solid and not FLAT[name]
	if SLIP[name] then
		p.CustomPhysicalProperties = SLIPPY
	end
	p.Parent = parent
	return p
end

-- a solid upright wall from a to b (map-local, y ignored)
local function wall(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	thick: number,
	h: number,
	color: Color3,
	exact: boolean? -- true: end exactly at a and b (no square overhang past the ends)
)
	local d = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local mid = Vector3.new((a.X + b.X) / 2, h / 2, (a.Z + b.Z) / 2)
	return part(
		parent,
		name,
		Vector3.new(thick, h, d.Magnitude + (if exact then 0 else thick)),
		CFrame.lookAt(mid, mid + d),
		color,
		true
	)
end

-- a solid upright round post (diameter d, height h) standing at `at` (map-local, y ignored)
local function round(
	parent: Instance,
	name: string,
	at: Vector3,
	d: number,
	h: number,
	color: Color3
)
	local p = part(
		parent,
		name,
		Vector3.new(h, d, d),
		CFrame.new(at.X, h / 2, at.Z) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		true
	) :: Part
	p.Shape = Enum.PartType.Cylinder
	return p
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
	side: Color3 | { Color3 }
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
			local sc: Color3 = if type(side) == "table" then side[(i - 1) % #side + 1] else side
			tri(parent, name, a, b, tops[j], out, 1, sc)
			tri(parent, name, a, tops[j], tops[i], out, 1, sc)
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
	-- the grass in a big two-green checker, so no view across the arena is one flat green
	local tiles = 8
	local tw = s / tiles
	for i = 0, tiles - 1 do
		for j = 0, tiles - 1 do
			part(
				folder,
				"Grass",
				Vector3.new(tw, 4, tw),
				CFrame.new(-s / 2 + tw * (i + 0.5), -2, -s / 2 + tw * (j + 0.5)),
				if (i + j) % 2 == 1 then GRASS_CHECK else GRASS,
				true
			)
		end
	end
	-- the purple outer wall, all round
	local w, h = ArenaData.WALL * K, ArenaData.WALL_H
	for _, side in { -1, 1 } do
		part(
			folder,
			"OuterWall",
			Vector3.new(s, h, w),
			CFrame.new(0, h / 2, side * (s - w) / 2),
			WALL_BLUE,
			true
		)
		part(
			folder,
			"OuterWall",
			Vector3.new(w, h, s),
			CFrame.new(side * (s - w) / 2, h / 2, 0),
			WALL_BLUE,
			true
		)
	end
	-- a yellow and black hazard rail along the top, in blocks
	local inner = s / 2 - w
	local BLOCK = 12
	local nb = math.floor(s / BLOCK)
	for k = 0, nb - 1 do
		local along = -s / 2 + BLOCK * (k + 0.5)
		local col = if k % 2 == 0 then HAZARD else HAZARD_DARK
		for _, side in { -1, 1 } do
			local z = side * (s - w) / 2
			part(
				folder,
				"WallTrim",
				Vector3.new(BLOCK, 2, w + 1),
				CFrame.new(along, h + 1, z),
				col,
				true
			)
			part(
				folder,
				"WallTrim",
				Vector3.new(w + 1, 2, BLOCK),
				CFrame.new(z, h + 1, along),
				col,
				true
			)
		end
	end
	-- crushed cars piled three high against the wall's inside face, each nosed into it so only
	-- its front shows (looks only: the kart still bumps the flat wall)
	local k = 0
	for along = -inner + 4, inner - 4, 8.4 do
		k += 1
		for _, face in { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } } do
			local nx, nz = face[1], face[2] -- the wall's side of the arena
			local tx, tz = -nz, nx -- along the wall
			local pc = {
				ArenaData.PIC / 2 + (nx * inner + tx * along) / K,
				ArenaData.PIC / 2 + (nz * inner + tz * along) / K,
			}
			local r = ArenaData.cornerRadius(pc[1], pc[2])
			-- the curved corners have no straight face to pile against
			if math.abs(along / K) > ArenaData.PIC / 2 - ArenaData.WALL - r - 4 / K then
				continue
			end
			local at =
				Vector3.new(nx * (inner + 0.3) + tx * along, 0, nz * (inner + 0.3) + tz * along)
			for l = 0, 2 do
				local col = WRECKS[(k + l * 2 + (nx + nz + 3)) % #WRECKS + 1]
				local cf = CFrame.new(at.X, l * 2.4, at.Z)
					* CFrame.Angles(0, if nx == 0 then 0 else math.pi / 2, 0)
				part(
					folder,
					"Wreck",
					Vector3.new(7, 1.6, 3.4),
					cf * CFrame.new(0, 0.8, 0),
					col,
					false
				)
				part(
					folder,
					"Wreck",
					Vector3.new(3.4, 1.1, 2.8),
					cf * CFrame.new(-0.4, 2.1, 0),
					col,
					false
				)
			end
			-- a rust-red steel sheet leaning on every third pile
			if k % 3 == 0 then
				part(
					folder,
					"Sheet",
					Vector3.new(8, 5, 0.5),
					CFrame.new(at.X, 9.2, at.Z)
						* CFrame.Angles(0, if nx == 0 then 0 else math.pi / 2, 0),
					rgb(154, 90, 56),
					false
				)
			end
		end
	end
	-- steel posts up the wall, a light tower at each corner and mid-wall, banners and fire pots
	local GAP = 36
	for along = -s / 2 + GAP, s / 2 - GAP / 2, GAP do
		for _, face in { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } } do
			local nx, nz = face[1], face[2]
			local tx, tz = -nz, nx
			local base = Vector3.new(nx * inner + tx * along, 0, nz * inner + tz * along)
			local into = Vector3.new(-nx, 0, -nz)
			part(
				folder,
				"WallPillar",
				Vector3.new(3, h + 1.6, 3),
				CFrame.lookAt(base - into * 0.7, base) + Vector3.new(0, (h + 1.6) / 2, 0),
				STEEL,
				false
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
		STEEL,
		HAZARD_DARK
	)
	-- a dark skirting along the inside foot of the wall
	for _, side in { -1, 1 } do
		part(
			folder,
			"Skirting",
			Vector3.new(s - 2 * w, 1.4, 0.6),
			CFrame.new(0, 0.7, side * inner),
			NAVY,
			false
		)
		part(
			folder,
			"Skirting",
			Vector3.new(0.6, 1.4, s - 2 * w),
			CFrame.new(side * inner, 0.7, 0),
			NAVY,
			false
		)
	end
	-- each inside corner filled out to a curve of flat slabs, so a kart is turned along the wall
	for _, c in ArenaData.cornerCurves do
		for k = 2, #c - 1 do
			prism(folder, "WallCorner", { c[1], c[k], c[k + 1] }, 0, h, WALL_BLUE)
		end
	end
end

-- Looks only, flat and never solid: dark tyre-track pairs scuffed over the dirt, and a white ring
-- painted round each start spot.
local function buildYardPaint(folder: Instance)
	local rng = Random.new(11)
	local lo, hi = ArenaData.WALL + 14, ArenaData.PIC - ArenaData.WALL - 14
	for _ = 1, 40 do
		local p = { rng:NextNumber(lo, hi), rng:NextNumber(lo, hi) }
		if ArenaData.groundAt(p) ~= 0 then
			continue
		end
		local ang = rng:NextNumber(0, math.pi)
		local len = rng:NextNumber(18, 40)
		local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
		local right = Vector3.new(-dir.Z, 0, dir.X)
		for _, w in { -1.3, 1.3 } do
			local mid = v(p, 0.12) + right * w
			part(
				folder,
				"Skid",
				Vector3.new(0.8, 0.04, len),
				CFrame.lookAt(mid, mid + dir),
				SKID,
				false
			)
		end
	end
	for _, p in ArenaData.START do
		local c = v(p, ArenaData.groundAt(p) + 0.14)
		for k = 0, 9 do
			local ang = k * math.pi / 5
			part(
				folder,
				"SpawnRing",
				Vector3.new(3.4, 0.05, 0.9),
				CFrame.new(c) * CFrame.Angles(0, ang, 0) * CFrame.new(0, 0, 6),
				CURB_WHITE,
				false
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
	-- the red bumper wall round it, open where SAND_GAPS says (when it's on)
	local n = if ArenaData.SAND_WALL then #sand else 0
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
				BUMPER,
				true
			)
			-- round ends, so a kart nosing the gap's edge slides round it
			for _, u in { u0, u1 } do
				round(
					folder,
					"BumperCap",
					a:Lerp(b, u),
					ArenaData.BUMPER_W * K,
					ArenaData.BUMPER_H,
					BUMPER
				)
			end
		end
	end
end

-- the junkyard look (carter picked it on the preview page, 10-29): a fence of beat-up corrugated
-- sheets and oil drums; a plank ramp with steel rails. All of it is looks only
-- (not solid): the solid walls, caps and ramps under it keep their old shapes.
local TIN, TIN_2 = rgb(139, 144, 153), rgb(170, 176, 184)
local RUST, RUST_2 = rgb(181, 83, 42), rgb(138, 61, 30)
local OLIVE, FADE_RED, FADE_BLUE = rgb(93, 106, 69), rgb(156, 47, 42), rgb(63, 95, 125)
local STEEL_DARK = rgb(52, 55, 63)
local SHEETS = { RUST, TIN, OLIVE, FADE_BLUE, RUST_2, TIN_2, FADE_RED }
local WOOD, WOOD_2, WOOD_3 = rgb(155, 114, 72), rgb(123, 90, 54), rgb(169, 130, 85)
local DRUM_BLUE, HAZARD = rgb(47, 95, 140), rgb(242, 194, 48)
local BOOST_ORANGE = rgb(255, 176, 46)

-- a steady wobble from a number (0..1), so every build looks the same
local function jitter(i: number): number
	local x = math.sin(i * 127.1 + 3.7) * 43758.5
	return x - math.floor(x)
end

-- a round flat disc (diameter d, thickness t) lying level at cf
local function disc(
	parent: Instance,
	name: string,
	cf: CFrame,
	d: number,
	t: number,
	color: Color3
): Part
	local p = part(
		parent,
		name,
		Vector3.new(t, d, d),
		cf * CFrame.Angles(0, 0, math.pi / 2),
		color,
		false
	) :: Part
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- an oil drum standing at `at` (feet on y 0), a yellow band round its middle
local function drum(parent: Instance, at: Vector3, color: Color3)
	disc(parent, "Drum", CFrame.new(at + Vector3.new(0, 1.6, 0)), 3, 3.2, color)
	disc(parent, "DrumBand", CFrame.new(at + Vector3.new(0, 2.2, 0)), 3.04, 0.4, HAZARD)
end

-- a ramp's paint and trim (looks only): from foot a to top b (map-local, y 0), width w, rise h.
-- Planks laid across it, a steel rail down each edge, rust patches, and oil drums at the foot.
local function rampLooks(folder: Instance, a: Vector3, b: Vector3, w: number, h: number)
	local up = Vector3.new(0, h, 0)
	local run = b - a
	local dir = run.Unit
	local side = Vector3.new(dir.Z, 0, -dir.X)
	local len = (run + up).Magnitude
	-- a flat piece on the slope at u (0 foot .. 1 top), off the middle by x, lifted by lift
	local function onSlope(
		name: string,
		size: Vector3,
		x: number,
		u: number,
		lift: number,
		color: Color3,
		turn: number?
	): BasePart
		local at = a + run * u + up * u + side * x + Vector3.new(0, lift, 0)
		return part(
			folder,
			name,
			size,
			CFrame.lookAt(at, at + run + up) * CFrame.Angles(0, turn or 0, 0),
			color,
			false
		)
	end
	local woods = { WOOD, WOOD_2, WOOD_3 }
	for i = 0, 9 do
		onSlope(
			"RampPlank",
			Vector3.new(w - 0.4, 0.16, len / 10 - 0.35),
			0,
			(i + 0.5) / 10,
			0.08,
			woods[i % 3 + 1]
		)
	end
	-- boost arrows (carter's pick: orange): five pairs of chevrons up the ramp, glowing; the client
	-- pulses them one after the other, bottom to top
	for i = 0, 4 do
		local u = 0.12 + i * 0.17
		for _, sgn in { -1, 1 } do
			local arrow = onSlope(
				"BoostArrow",
				Vector3.new(5.4, 0.16, 1.5),
				sgn * 2.6,
				u,
				0.14,
				BOOST_ORANGE,
				sgn * 0.65
			)
			arrow.Material = Enum.Material.Neon
			arrow:SetAttribute("U", u)
			CollectionService:AddTag(arrow, ArenaData.BOOST_TAG)
		end
	end
	for _, sgn in { -1, 1 } do
		onSlope("RampRail", Vector3.new(0.7, 0.7, len), sgn * (w / 2 - 0.35), 0.5, 0.3, STEEL_DARK)
		for i = 0, 2 do
			onSlope(
				"RampPatch",
				Vector3.new(0.5, 0.18, 2.6),
				sgn * (w / 2 - 1.1),
				0.2 + i * 0.3,
				0.25,
				RUST,
				0.2
			)
		end
		for i = 0, 1 do
			local at = a + side * (sgn * (w / 2 + 2.3)) + dir * (2 + i * 3.4)
			drum(folder, at, if (i + (sgn + 1) / 2) % 2 == 0 then DRUM_BLUE else FADE_RED)
		end
	end
end

-- the junkyard-night hills (carter's pick, 10-29): cracked grey concrete, a yellow/black warning band
-- round the top, broken slabs and rebar lying on the slopes, cones on the corners
local CONC, CONC_FOOT = rgb(138, 140, 150), rgb(92, 94, 106)
local CONC_SIDES = {
	rgb(111, 113, 124),
	rgb(124, 126, 138),
	rgb(103, 105, 117),
	rgb(119, 121, 135),
	rgb(114, 116, 127),
}
local SLABS = { rgb(128, 130, 142), rgb(116, 118, 129), rgb(138, 140, 150) }
local CRACK, CONE_ORANGE, CONE_WHITE = rgb(74, 76, 88), rgb(255, 122, 26), rgb(242, 242, 242)
local BLACK_BAND = rgb(28, 28, 36)

-- Looks only (nothing solid, nothing for the camera or a kart to hit): dress one hill. The solid
-- shape is mesa()'s; everything here lies on it. `ramp` is the ramp that climbs it (kept clear).
local function dressHill(
	folder: Instance,
	poly: { Pt },
	h: number,
	inset: number,
	seed: number,
	ramp: ArenaData.Ramp?
)
	local rng = Random.new(seed)
	local inner = ArenaData.insetPoly(poly, inset, nil)
	local n = #poly
	local feet: { Vector3 }, tops: { Vector3 } = {}, {}
	local mid = Vector3.zero
	for i = 1, n do
		feet[i] = v(poly[i], 0)
		tops[i] = v(inner[i], h)
		mid += tops[i] / n
	end
	local dress = Instance.new("Folder")
	dress.Name = "HillDress"
	dress.Parent = folder
	-- the ramp's top, where the band and cones stay away
	local clearAt: Vector3? = nil
	local clearR = 0
	if ramp then
		local dir = (v(ramp.to, 0) - v(ramp.from, 0)).Unit
		clearAt = v(ramp.to, h) + dir * (ArenaData.RAMP_DECK * K / 2)
		clearR = ramp.width * K / 2 + ArenaData.RAMP_DECK * K
	end
	local function clear(p: Vector3): boolean
		return clearAt ~= nil
			and (Vector3.new(p.X, 0, p.Z) - Vector3.new(clearAt.X, 0, clearAt.Z)).Magnitude
				< clearR
	end
	-- a random spot on the flat top (a random triangle of its fan)
	local function topSpot(): Vector3
		local i = rng:NextInteger(2, n - 1)
		local r1, r2 = rng:NextNumber(), rng:NextNumber()
		if r1 + r2 > 1 then
			r1, r2 = 1 - r1, 1 - r2
		end
		return tops[1] + (tops[i] - tops[1]) * r1 + (tops[i + 1] - tops[1]) * r2
	end
	-- slabs and rebar lying on each sloped side
	for i = 1, n do
		local j = i % n + 1
		local a, b, ta, tb = feet[i], feet[j], tops[i], tops[j]
		local along = b - a
		local out = (a + b) / 2 - mid
		out = Vector3.new(out.X, 0, out.Z)
		local up = along:Cross(ta - a).Unit
		if up:Dot(out) < 0 then
			up = -up
		end
		local right = along.Unit
		local back = right:Cross(up)
		for k = 1, 4 do
			local s, t = 0.12 + rng:NextNumber() * 0.76, 0.15 + rng:NextNumber() * 0.65
			local at = a:Lerp(b, s):Lerp(ta:Lerp(tb, s), t)
			if not clear(at) then
				local lie = CFrame.fromMatrix(at + up * 0.3, right, up, back)
					* CFrame.Angles(0, rng:NextNumber() * math.pi, (rng:NextNumber() - 0.5) * 0.35)
				part(
					dress,
					"HillSlab",
					Vector3.new(4 + rng:NextNumber() * 3, 0.5, 2.6 + rng:NextNumber() * 2),
					lie,
					SLABS[(i + k) % #SLABS + 1],
					false
				)
				if k % 2 == 0 then
					part(
						dress,
						"HillRebar",
						Vector3.new(0.2, 0.2, 2.4),
						CFrame.fromMatrix(at + up * 0.5, right, up, back)
							* CFrame.Angles(0.4, rng:NextNumber() * math.pi, 0),
						RUST,
						false
					)
				end
			end
		end
	end
	-- cracks across the top
	for _ = 1, 9 do
		local p = topSpot()
		if not clear(p) then
			part(
				dress,
				"HillCrack",
				Vector3.new(0.3, 0.06, 3 + rng:NextNumber() * 5),
				CFrame.new(p.X, h + 0.04, p.Z) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0),
				CRACK,
				false
			)
		end
	end
	-- the yellow and black warning band just inside the top edge
	for i = 1, n do
		local j = i % n + 1
		local a, b = tops[i], tops[j]
		local len = (b - a).Magnitude
		local inward = Vector3.new(mid.X - (a.X + b.X) / 2, 0, mid.Z - (a.Z + b.Z) / 2).Unit
		local count = math.max(2, math.floor(len / 3 + 0.5))
		local seg = len / count
		for k = 0, count - 1 do
			local p = a:Lerp(b, (k + 0.5) / count) + inward * 0.9
			if not clear(p) then
				local at = Vector3.new(p.X, h + 0.07, p.Z)
				part(
					dress,
					"HillBand",
					Vector3.new(1.5, 0.1, seg + 0.02),
					CFrame.lookAt(at, at + (b - a)),
					if k % 2 == 0 then HAZARD else BLACK_BAND,
					false
				)
			end
		end
	end
	-- a traffic cone near most corners (a black foot, orange and white rings)
	for i = 1, n do
		local p = tops[i]:Lerp(mid, 0.18)
		if i % 2 == 1 and not clear(p) then
			local base = Vector3.new(p.X, h, p.Z)
			disc(
				dress,
				"HillCone",
				CFrame.new(base + Vector3.new(0, 0.15, 0)),
				2.4,
				0.3,
				BLACK_BAND
			)
			disc(
				dress,
				"HillCone",
				CFrame.new(base + Vector3.new(0, 0.7, 0)),
				1.8,
				0.8,
				CONE_ORANGE
			)
			disc(
				dress,
				"HillCone",
				CFrame.new(base + Vector3.new(0, 1.25, 0)),
				1.4,
				0.4,
				CONE_WHITE
			)
			disc(
				dress,
				"HillCone",
				CFrame.new(base + Vector3.new(0, 1.7, 0)),
				0.9,
				0.6,
				CONE_ORANGE
			)
		end
	end
end

local function buildHills(folder: Instance)
	for hi, h in ArenaData.HILLS do
		mesa(folder, h.name, h.poly, h.h, h.slope, nil, CONC, CONC_SIDES)
		local ramp: ArenaData.Ramp? = nil
		for _, r in ArenaData.RAMPS do
			if ArenaData.inside(h.poly, r.to) then
				ramp = r
			end
		end
		dressHill(folder, h.poly, h.h, h.slope, 100 + hi, ramp)
	end
	-- the soft bumper round each hill's foot (open at the ramp), pushed out so its inside face
	-- is on the foot line, with a round post at every end
	local fw, fh = ArenaData.FOOT_W * K, ArenaData.FOOT_H
	for _, seg in ArenaData.hillFeet do
		local a, b = v(seg[1], 0), v(seg[2], 0)
		local along = (b - a).Unit
		local out = Vector3.new(along.Z, 0, -along.X)
		-- picture axes run the same way as map x and z: step half a unit out and see if that's
		-- still a hill
		local probe =
			{ (seg[1][1] + seg[2][1]) / 2 + out.X * 0.5, (seg[1][2] + seg[2][2]) / 2 + out.Z * 0.5 }
		local inHill = false
		for _, hh in ArenaData.HILLS do
			if ArenaData.inside(hh.poly, probe) then
				inHill = true
			end
		end
		if inHill then
			out = -out
		end
		local push = out * (fw / 2)
		wall(folder, "HillFoot", a + push, b + push, fw, fh, CONC_FOOT, true)
		for _, e in { a, b } do
			round(folder, "HillFootPost", e + push, fw, fh, CONC_FOOT)
		end
	end
	-- a 45 degree fillet each side of each ramp, in the corner of the bumper and the ramp's side
	for _, f in ArenaData.rampFillets do
		rightPrism(folder, "HillFoot", v(f[1], 0), v(f[2], 0), v(f[3], 0), 0, fh, CONC_FOOT)
	end
	for i, r in ArenaData.RAMPS do
		local a, b = v(r.from, 0), v(r.to, 0)
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		-- a WedgePart rises from its front (-Z) to its back (+Z): face it back down the ramp; the
		-- deck carries it on over the hill's sloped edge
		local h = r.h
		local mid = (a + b) / 2 + Vector3.new(0, h / 2, 0)
		part(
			folder,
			"Ramp" .. i,
			Vector3.new(r.width * K, h, len),
			CFrame.lookAt(mid, mid - dir),
			WOOD,
			true,
			"WedgePart"
		)
		-- the flat deck from the ramp's top over the hill's sloped edge
		local deck = ArenaData.RAMP_DECK * K
		local dm = b + dir * (deck / 2) + Vector3.new(0, r.h - 0.46, 0)
		part(
			folder,
			"RampDeck" .. i,
			Vector3.new(r.width * K, 1, deck),
			CFrame.lookAt(dm, dm + dir),
			WOOD,
			true
		)
		-- a sloped flank down each side, so a kart hitting the ramp's side from the grass rides up
		-- onto it or (mostly, it's steep) glances off, never pins against an upright side (round 11)
		local side = Vector3.new(dir.Z, 0, -dir.X)
		local half, flank = r.width * K / 2, ArenaData.RAMP_FLANK * K
		for _, sgn in { -1, 1 } do
			local n = side * sgn
			tri(
				folder,
				"RampFlank",
				a + n * half,
				b + n * half + Vector3.new(0, h, 0),
				b + n * (half + flank),
				Vector3.yAxis + n,
				1,
				STEEL_DARK
			)
			-- close its upright top end, so nothing can nose in under it where the hill isn't there
			tri(
				folder,
				"RampFlank",
				b + n * half,
				b + n * half + Vector3.new(0, h, 0),
				b + n * (half + flank),
				dir,
				1,
				STEEL_DARK
			)
		end
		rampLooks(folder, a, b, r.width * K, h)
	end
end

-- one corrugated sheet standing across the fence: centre `at` (map-local), `along` the wall's
-- length axis, width w, height h, ribs on its outer face (out = +1 or -1 across the wall)
local function sheet(
	parent: Instance,
	look: CFrame,
	across: number,
	along: number,
	w: number,
	h: number,
	color: Color3,
	i: number
)
	local out = if across > 0 then 1 else -1
	local base = look * CFrame.new(across, 0, along) * CFrame.Angles(0, (jitter(i) - 0.5) * 0.15, 0)
	local tilt = CFrame.Angles(0, 0, (jitter(i + 7) - 0.5) * 0.07)
	local cf = base * CFrame.new(0, h / 2, 0) * tilt
	part(parent, "CoverSheet", Vector3.new(0.5, h, w), cf, color, false)
	local n = math.floor(w / 1.1)
	for k = 0, n - 1 do
		local z = -w / 2 + 0.7 + k * (w - 1.4) / (n - 1)
		part(
			parent,
			"CoverRib",
			Vector3.new(0.22, h - 0.4, 0.3),
			cf * CFrame.new(out * 0.3, 0, z),
			color:Lerp(STEEL_DARK, 0.4),
			false
		)
	end
	part(
		parent,
		"CoverSheet",
		Vector3.new(0.7, 0.35, w),
		cf * CFrame.new(0, h / 2 - 0.17, 0),
		STEEL_DARK,
		false
	)
end

-- the cover walls: the solid wall and round end caps stay as they were (karts slide off them),
-- now dressed as a junkyard fence: two rows of mismatched rusty sheets, a big oil drum at each end
local function buildCover(folder: Instance)
	local W, H = ArenaData.COVER_W * K, ArenaData.COVER_H
	for n, seg in ArenaData.COVER do
		local a, b = v(seg[1], 0), v(seg[2], 0)
		-- the sheets go in their own folder; the chase cam fades it with the wall
		local dress = Instance.new("Folder")
		dress.Name = "CoverDress" .. n
		dress.Parent = folder
		local core = wall(folder, "Cover", a, b, W, H, STEEL_DARK, true)
		core:SetAttribute("Dress", dress.Name)
		core.Transparency = 1 -- the sheets below are what you see; this is the solid under them
		for _, e in seg do
			local cap = part(
				folder,
				"CoverCap",
				Vector3.new(H + 1, W, W),
				CFrame.new(v(e, (H + 1) / 2)) * CFrame.Angles(0, 0, math.pi / 2),
				if n % 2 == 1 then FADE_RED else DRUM_BLUE,
				true
			) :: Part
			cap.Shape = Enum.PartType.Cylinder
			-- a big oil drum look: yellow bands round it
			for _, y in { 1.2, 8.8 } do
				disc(dress, "DrumBand", CFrame.new(v(e, y)), W + 0.2, 0.7, HAZARD)
			end
		end
		local mid = (a + b) / 2
		local look = CFrame.lookAt(mid, b)
		local L = (b - a).Magnitude
		-- a steel lid over the hollow top, between the round end caps
		part(
			dress,
			"CoverLid",
			Vector3.new(W - 0.4, 0.4, L),
			look * CFrame.new(0, H - 0.2, 0),
			STEEL_DARK,
			false
		)
		for r, across in { -W / 2 + 0.55, W / 2 - 0.55 } do
			local x, i = -L / 2 + 3.9, 0
			while x < L / 2 - 3.9 do
				local w = math.min(5 + jitter(i + r * 9 + n * 30) * 2.6, L / 2 - 3.9 - x)
				if w < 2 then
					break
				end
				local h = H + 0.4 - jitter(i + 3 + r + n * 30) * 0.8
				sheet(
					dress,
					look,
					across,
					x + w / 2,
					w,
					h,
					SHEETS[(i + r * 3 + n) % #SHEETS + 1],
					i + n * 40 + r * 11
				)
				x += w + 0.1
				i += 1
			end
		end
	end
end

local function buildTrees(folder: Instance)
	for i, t in ArenaData.TREES do
		local base = v(t, 0)
		local h = 24
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
		-- a chunky faceted top: three turned blocks, up out of the karts' way (two trees green)
		local r = ArenaData.TREE_R * K * 1.5
		local top = base + Vector3.new(0, h + r * 0.45, 0)
		local spin = i * 0.7
		local green = i == 2 or i == 5
		local c1, c2 = if green then BUSH else CANDY, if green then BUSH_2 else CANDY_2
		part(
			folder,
			"TreeTop",
			Vector3.new(r * 1.3, r, r * 1.3),
			CFrame.new(top) * CFrame.Angles(0.2, spin, 0.15),
			c1,
			false
		)
		part(
			folder,
			"TreeTop",
			Vector3.new(r * 0.95, r * 0.85, r * 0.95),
			CFrame.new(top + Vector3.new(r * 0.35, r * 0.3, -r * 0.2))
				* CFrame.Angles(-0.25, spin + 0.8, 0.3),
			c2,
			false
		)
		part(
			folder,
			"TreeTop",
			Vector3.new(r * 0.8, r * 0.7, r * 0.8),
			CFrame.new(top + Vector3.new(-r * 0.35, r * 0.2, r * 0.3))
				* CFrame.Angles(0.3, spin + 1.6, -0.2),
			c2,
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
		round(folder, "ArchPillar", p, pw, a.h, NAVY) -- round: a kart brushing it slides past
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
		local at = p1 + dir * (len * k / 6) + Vector3.new(0, a.h - 6.3, 0)
		part(
			folder,
			"ArchFlag",
			Vector3.new(0.2, 2.6, 2.2),
			CFrame.fromMatrix(at, Vector3.new(-dir.Z, 0, dir.X), -Vector3.yAxis),
			FLAGS[k % #FLAGS + 1],
			false,
			"WedgePart"
		)
	end
end

-- looks only: dirt patches in two shades and scrap piles (karts drive through them)
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
			0.06,
			if g[4] == 1 then GRASS_DARK else GRASS_LIGHT,
			false
		)
	end
	for i, b in ArenaData.BUSHES do
		lump(folder, "Bush", v(b, 0), 9, 7, i * 0.9, SCRAP, SCRAP_2, false)
		lump(folder, "Bush", v(b, 0) + Vector3.new(6, 0, 4), 6, 5, i * 1.7, SCRAP_2, SCRAP, false)
	end
end

-- Outside the walls (looks only, nothing to hit): far dirt, rolling
-- low-poly hills, grey cliffs, grandstands and light towers, so every camera sees a world, not empty sky.
local function buildWorld(folder: Instance)
	local s = ArenaData.SIZE
	part(folder, "FarGrass", Vector3.new(2400, 2, 2400), CFrame.new(0, -1.6, 0), GRASS_FAR, false)
	local rng = Random.new(28)
	-- rolling hills: turned blocks sunk in the ground, in a ring well past the walls
	for k = 0, 13 do
		local ang = k / 14 * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local r = rng:NextNumber(430, 620)
		local at = Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
		local size = rng:NextNumber(110, 190)
		if at.Z < -s / 2 - 60 and at.Z > -s / 2 - 440 - size * 0.8 then
			at = Vector3.new(at.X, 0, -s / 2 - 440 - size * 0.8) -- behind the lake, not in it
		end
		local east = at.X > 300
		part(
			folder,
			if east then "Cliff" else "FarHill",
			Vector3.new(size, size * (if east then 0.9 else 0.55), size),
			CFrame.new(at - Vector3.new(0, size * 0.18, 0))
				* CFrame.Angles(rng:NextNumber(-0.25, 0.25), ang, rng:NextNumber(-0.25, 0.25)),
			if east then ROCK_2 else HILL_FAR,
			false
		)
		part(
			folder,
			if east then "Cliff" else "FarHill",
			Vector3.new(size * 0.7, size * 0.5, size * 0.7),
			CFrame.new(at + Vector3.new(size * 0.4, -size * 0.1, size * 0.2))
				* CFrame.Angles(0.2, ang + 0.8, -0.3),
			if east then ROCK else HILL_FAR_2,
			false
		)
	end
	-- grandstands along the north and south walls, five tiers of dark steel with a coloured seat
	-- strip on each (looks only)
	for _, side in { -1, 1 } do
		for i = 0, 4 do
			local hh = 5 + i * 5
			part(
				folder,
				"Stand",
				Vector3.new(s + 20, hh, 7),
				CFrame.new(0, hh / 2, side * (s / 2 + 10 + i * 7)),
				STAND,
				false
			)
			part(
				folder,
				"Stand",
				Vector3.new(s + 20, 0.8, 4),
				CFrame.new(0, hh + 0.4, side * (s / 2 + 10 + i * 7)),
				SEATS[(i + (side + 1) / 2) % #SEATS + 1],
				false
			)
		end
	end
	-- light towers round the outside (a tall steel pole, a white lamp bank)
	for _, p in
		{
			{ -1, -1 },
			{ 1, -1 },
			{ 1, 1 },
			{ -1, 1 },
			{ 0, -1 },
			{ 0, 1 },
		}
	do
		local x, z = p[1] * (s / 2 + 4), p[2] * (s / 2 + 4)
		if p[1] == 0 then
			x = 0
		else
			z = p[2] * (s / 2 - 30)
		end
		part(folder, "LightPole", Vector3.new(1, 34, 1), CFrame.new(x, 17, z), STEEL, false)
		part(
			folder,
			"LightLamp",
			Vector3.new(9, 3, 3),
			CFrame.lookAt(Vector3.new(x, 35, z), Vector3.new(0, 10, 0)),
			CURB_WHITE,
			false
		)
	end
	-- a fire pot every so often on top of the north and south wall (a dark drum, an orange flame)
	for _, side in { -1, 1 } do
		for k = 0, 11 do
			local x, z = -s / 2 + 30 + k * 30, side * (s / 2 - ArenaData.WALL * K / 2)
			part(
				folder,
				"FirePot",
				Vector3.new(3, 3, 3),
				CFrame.new(x, ArenaData.WALL_H + 3.7, z),
				HAZARD_DARK,
				false
			)
			part(
				folder,
				"FireFlame",
				Vector3.new(2, 3.4, 2),
				CFrame.new(x, ArenaData.WALL_H + 6.8, z) * CFrame.Angles(0, k, 0),
				ORANGE,
				false
			)
		end
	end
end

-- The far ground, the haze wall and the far skyline (ArenaHorizon): no dark sky band past the edge.
local function buildHorizon(folder: Instance)
	local haze = ArenaData.atmosphere.color
	for _, d in ArenaHorizon.pieces(haze) do
		local p = part(
			folder,
			d.name,
			Vector3.new(d.size[1], d.size[2], d.size[3]),
			CFrame.new(d.pos[1], d.pos[2], d.pos[3]) * CFrame.Angles(0, d.yaw, 0),
			rgb(d.color[1], d.color[2], d.color[3]),
			false,
			if d.shape == "Cylinder" then "Part" else nil
		) :: Part
		if d.shape == "Cylinder" then
			p.Shape = Enum.PartType.Cylinder
			-- a Roblox cylinder lies along X: stand it up
			p.CFrame = CFrame.new(d.pos[1], d.pos[2], d.pos[3]) * CFrame.Angles(0, 0, math.pi / 2)
			p.Size = Vector3.new(d.size[2], d.size[1], d.size[3])
		end
		p.CastShadow = false
		if d.neon then
			p.Material = Enum.Material.Neon
		end
	end
end

-- Grass tufts scattered over the open grass (looks only): off the road, sand, hills and spots.
local function buildTufts(folder: Instance)
	local line = roadLine(4)
	local rng = Random.new(7)
	local clearOfRoad = (ArenaData.ROAD_W / 2 + ArenaData.CURB + 2) * K
	local spots: { Pt } = {}
	for _, p in ArenaData.START do
		table.insert(spots, p)
	end
	for _, p in ArenaData.BOXES do
		table.insert(spots, p)
	end
	for gx = 14, ArenaData.PIC - 14, 22 do
		for gy = 14, ArenaData.PIC - 14, 22 do
			local p = { gx + rng:NextNumber(-5, 5), gy + rng:NextNumber(-5, 5) }
			local ok = ArenaData.groundAt(p) == 0
				and not ArenaData.inside(ArenaData.SAND, p)
				and ArenaData.clear(p[1], p[2], 2)
			if ok then
				for _, q in spots do
					if math.abs(q[1] - p[1]) < 7 and math.abs(q[2] - p[2]) < 7 then
						ok = false
						break
					end
				end
			end
			local at = v(p, 0)
			if ok then
				-- distance to each road piece (not just its ends: the long legs have far-apart points)
				for k, q in line do
					local q2 = line[k % #line + 1]
					local d = q2 - q
					local u = math.clamp((at - q):Dot(d) / math.max(d:Dot(d), 1e-6), 0, 1)
					if (q + d * u - at).Magnitude < clearOfRoad then
						ok = false
						break
					end
				end
			end
			if ok then
				local spin = rng:NextNumber(0, math.pi * 2)
				for t = 0, 1 do
					part(
						folder,
						"Tuft",
						Vector3.new(2.6, 4 - t * 1, 2.6),
						CFrame.new(at + Vector3.new(t * 1.2, 0.9, t * 0.8))
							* CFrame.Angles(0.3, spin + t, 0.35),
						if t == 0 then GRASS_DARK else SCRAP,
						false
					)
				end
			end
		end
	end
end

-- The arena model, built big at the origin (no scaling, not placed): tests and renders read it.
function ArenaBuilder.buildBig(): Model
	local model = Instance.new("Model")
	model.Name = "SmashArena"
	buildFloor(model)
	buildYardPaint(model)
	buildSand(model)
	buildHills(model)
	buildCover(model)
	buildCoverExtras(model)
	buildArch(model)
	buildTrees(model)
	buildDecor(model)
	buildTufts(model)
	buildWorld(model)
	buildHorizon(model)
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
