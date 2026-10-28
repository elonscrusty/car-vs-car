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
	color: Color3
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
	part(parent, name, Vector3.new(y1 - y0, lp, lq), cf, color, true, "WedgePart")
end

-- A convex polygon (picture points) as a solid flat-topped block from y0 to y1, built from
-- wedges (each fan triangle split at its foot into two right triangles): low-poly facets.
local function prism(
	parent: Instance,
	name: string,
	poly: { Pt },
	y0: number,
	y1: number,
	color: Color3
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
		rightPrism(parent, name, foot, c, a, y0, y1, color)
		rightPrism(parent, name, foot, c, b, y0, y1, color)
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
	prism(folder, "Step", ArenaData.STEP, 0, ArenaData.STEP_H, PURPLE_STEP)
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
		prism(folder, h.name, h.poly, 0, h.h, PINK)
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
		local stick = part(
			folder,
			"TreeStick",
			Vector3.new(h, 3, 3),
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

-- The arena model, built big at the origin (no scaling, not placed): tests and renders read it.
function ArenaBuilder.buildBig(): Model
	local model = Instance.new("Model")
	model.Name = "SmashArena"
	buildFloor(model)
	buildRoad(model)
	buildSand(model)
	buildHills(model)
	buildCover(model)
	buildTrees(model)
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
