--!strict
-- DRIFT plot: one wide loop with long sweeping corners (Tokyo-drift style held slides), an
-- S-shaped "big sweeper" on the right, and a big round drift pad in the middle with a cone to
-- circle around. Everything is flat and level so a slide never gets broken by a bump.
-- Dressed like a real drift track: grass, red and white curbs, tyre walls, lamps, a pit
-- garage, bleachers, a safety fence and a striped gantry over the start line. carter's Meshy
-- models are used when imported (ServerStorage.LobbyMeshes), else block stand-ins.
-- Layout: /mnt/project-files/car-vs-car/rc-plot/drift-look/drift-look-top.png.

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

local ROAD = 52 -- wide, so a car can hold a long slide without running off
local TOP = 0.1 -- road and pad top: both level, so crossing from one to the other is smooth

-- The centre line is drawn like a turtle: drive straight, or turn through an angle on a set
-- radius. Driven order: front straight to the right, the right-hand sweeper, the "big sweeper"
-- S-bend on the right, across the back, then the long slide down the left. Plot-local big
-- units, +Z is the front. Every corner has a big radius so a slide can be held all the way.
-- The loop keeps about 25 of open floor to the outer walls on every side: room to run wide in
-- a slide, and the chase camera sits over open floor instead of up against a wall.
local START = { x = -32, z = 100 }
local R_RIGHT = 56 -- right-hand corners
local R_LEFT = 76 -- left-hand corners: the long slide
local R_S = 56 -- the S-bend
local S_ANGLE = math.acos(0.8) -- S-bend goes in 22 and back out (2 * R_S * (1 - 0.8))
local SIDE = 156 - 4 * R_S * math.sin(S_ANGLE) -- straight left over on the right side

type Step = { straight: number?, turn: number?, radius: number? }
local STEPS: { Step } = {
	{ straight = 84 },
	{ turn = -90, radius = R_RIGHT },
	{ straight = SIDE / 2 },
	{ turn = -math.deg(S_ANGLE), radius = R_S },
	{ turn = 2 * math.deg(S_ANGLE), radius = R_S },
	{ turn = -math.deg(S_ANGLE), radius = R_S },
	{ straight = SIDE / 2 },
	{ turn = -90, radius = R_RIGHT },
	{ straight = 84 },
	{ turn = -90, radius = R_LEFT },
	{ straight = 116 },
	{ turn = -90, radius = R_LEFT },
}
local SPACING = 12

-- Points along the steps, about SPACING apart (the last one, back at the start, is left off).
local function turtle(): { Kit.Pt }
	local pts: { Kit.Pt } = {}
	local x, z, h = START.x, START.z, 0
	for _, step in STEPS do
		local straight, turnDeg, radius = step.straight, step.turn, step.radius
		if straight then
			local n = math.max(1, math.round(straight / SPACING))
			local d = straight / n
			for _ = 1, n do
				pts[#pts + 1] = { x = x, z = z }
				x += math.cos(h) * d
				z += math.sin(h) * d
			end
		elseif turnDeg and radius then
			local turn = math.rad(turnDeg)
			local n = math.max(1, math.round(math.abs(turn) * radius / SPACING))
			local side = if turn < 0 then -1 else 1
			-- centre of the turn sits to that side of the heading
			local cx = x - math.sin(h) * radius * side
			local cz = z + math.cos(h) * radius * side
			for _ = 1, n do
				pts[#pts + 1] = { x = x, z = z }
				h += turn / n
				x = cx + math.sin(h) * radius * side
				z = cz - math.cos(h) * radius * side
			end
		end
	end
	return pts
end
local POINTS = turtle()

local Plot = {}
Plot.id = "drift"
Plot.label = "DRIFT"
Plot.mode = "free"
Plot.grip = 0.45
Plot.ROAD = ROAD
Plot.POINTS = POINTS
-- The round drift pad in the middle, and the cone you circle around.
Plot.PAD = { x = -12, z = -34, r = 46 }
Plot.CONE = { r = 3, h = 8 }

function Plot.loop()
	return Kit.loop(POINTS, 2)
end

local start = Plot.loop()[1]
Plot.start = start
Plot.spawn = Kit.spawnAt(start, 14)
Plot.gates = {}

-- ===== Looks (pure data, so the tests can check nothing sits on the road) =====
-- Only looks: grip, speed and the road shape are not touched. Paint (curbs, lines) lies flat
-- and nothing can hit it or stand on it, so a slide is never broken.

-- Colour helper that also loads in Lune (tests have no Color3).
local function rgb(r: number, g: number, b: number): Color3
	local c: any = Color3
	return if c then c.fromRGB(r, g, b) else nil :: any
end

Plot.LOOK = {
	grass = rgb(96, 168, 82),
	asphalt = rgb(104, 104, 110), -- mid grey: the dark skid marks still show on it
	tire = rgb(32, 32, 34),
	concrete = rgb(200, 196, 188),
	metal = rgb(70, 74, 82),
	roof = rgb(200, 60, 50),
	wood = rgb(150, 110, 70),
	yellow = rgb(240, 200, 60),
} :: { [string]: Color3 }
Plot.CURB_W = 6 -- red/white curb stripes just outside the road edge in every corner
Plot.CORNER_TURN = 0.02 -- heading change per sample (radians) that counts as a corner
Plot.RUNOFF = 12 -- tyre walls stand this far out from the road edge

export type Stripe = { x: number, z: number, tx: number, tz: number, len: number, red: boolean }
export type Spot = { x: number, z: number, yaw: number }

-- Is this sample in a corner?
local function cornerFlags(ring: { Kit.Sample }): { boolean }
	local n = #ring
	local out = {}
	for i = 1, n do
		local a, b = ring[i], ring[(i % n) + 1]
		local turn = math.acos(math.clamp(a.tx * b.tx + a.tz * b.tz, -1, 1))
		out[i] = turn > Plot.CORNER_TURN
	end
	-- widen each corner by one sample both ways so the curbs start before the turn-in
	local wide = table.clone(out)
	for i = 1, n do
		if out[i] then
			wide[((i - 2) % n) + 1] = true
			wide[(i % n) + 1] = true
		end
	end
	return wide
end

-- Curb stripes (both edges of every corner) and the white edge lines (straights, one long
-- piece per straight run).
function Plot.paint(): ({ Stripe }, { Stripe })
	local ring = Plot.loop()
	local n = #ring
	local corner = cornerFlags(ring)
	local curbs: { Stripe } = {}
	local lines: { Stripe } = {}
	local off = ROAD / 2 + Plot.CURB_W / 2
	for i = 1, n do
		local a, b = ring[i], ring[(i % n) + 1]
		if corner[i] then
			local mx, mz = (a.x + b.x) / 2, (a.z + b.z) / 2
			local dx, dz = b.x - a.x, b.z - a.z
			local len = math.sqrt(dx * dx + dz * dz)
			for _, side in { -1, 1 } do
				curbs[#curbs + 1] = {
					x = mx - (dz / len) * off * side,
					z = mz + (dx / len) * off * side,
					tx = dx / len,
					tz = dz / len,
					len = len + 0.6,
					red = i % 2 == 0,
				}
			end
		end
	end
	-- straight runs: from the first non-corner sample to the last
	local start = 1
	while corner[start] and start < n do
		start += 1
	end
	local i = start
	local count = 0
	while count < n do
		if not corner[i] then
			local j = i
			local steps = 0
			while not corner[(j % n) + 1] and steps < n do
				j = (j % n) + 1
				steps += 1
			end
			local a, b = ring[i], ring[(j % n) + 1]
			local dx, dz = b.x - a.x, b.z - a.z
			local len = math.sqrt(dx * dx + dz * dz)
			if len > 1 then
				for _, side in { -1, 1 } do
					local o = ROAD / 2 - 2
					lines[#lines + 1] = {
						x = (a.x + b.x) / 2 - (dz / len) * o * side,
						z = (a.z + b.z) / 2 + (dx / len) * o * side,
						tx = dx / len,
						tz = dz / len,
						len = len,
						red = false,
					}
				end
			end
			count += steps + 1
			i = (j % n) + 1
		else
			count += 1
			i = (i % n) + 1
		end
	end
	return curbs, lines
end

-- Road pieces, one per sample to the next. `extra` is the total length added past the two
-- ends: enough that on the outside of a bend each piece covers the wedge to the next one.
export type Piece = { ax: number, az: number, bx: number, bz: number, extra: number }
function Plot.roadPieces(): { Piece }
	local ring = Plot.loop()
	local n = #ring
	local out: { Piece } = {}
	local function turnAt(i: number): number
		local p, q = ring[((i - 2) % n) + 1], ring[i]
		return math.acos(math.clamp(p.tx * q.tx + p.tz * q.tz, -1, 1))
	end
	for i = 1, n do
		local a, b = ring[i], ring[(i % n) + 1]
		local worst = math.max(turnAt(i), turnAt((i % n) + 1))
		out[i] = {
			ax = a.x,
			az = a.z,
			bx = b.x,
			bz = b.z,
			extra = 1.5 + 2 * (ROAD / 2) * math.tan(worst / 2),
		}
	end
	return out
end

-- Tyre stacks along the outside of each corner, RUNOFF out from the road edge, one about every
-- 14 along the corner.
function Plot.tires(): { Spot }
	local ring = Plot.loop()
	local n = #ring
	local corner = cornerFlags(ring)
	local out: { Spot } = {}
	local walked = 0
	for i = 1, n do
		local a, b = ring[i], ring[(i % n) + 1]
		if corner[i] then
			-- outside of the turn: the side the heading turns away from
			local cross = a.tx * b.tz - a.tz * b.tx
			local side = if cross < 0 then 1 else -1
			local d = ROAD / 2 + Plot.RUNOFF
			walked += math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
			if walked >= 14 and math.abs(cross) > Plot.CORNER_TURN then
				walked = 0
				local x, z = a.x - a.tz * d * side, a.z + a.tx * d * side
				if Kit.inArea(x, z) then
					out[#out + 1] = { x = x, z = z, yaw = math.atan2(a.tx, a.tz) }
				end
			end
		else
			walked = 14
		end
	end
	return out
end

-- Tyre smoke: a slow grey puff where each corner lets out, on the outside half of the road
-- (where a held slide ends up). Looks only: no part you can hit.
Plot.SMOKE_IN = 10 -- this far in from the outer road edge

function Plot.smoke(): { Spot }
	local ring = Plot.loop()
	local n = #ring
	local corner = cornerFlags(ring)
	local out: { Spot } = {}
	local side = 1
	for i = 1, n do
		local a, b = ring[i], ring[(i % n) + 1]
		local cross = a.tx * b.tz - a.tz * b.tx
		if math.abs(cross) > Plot.CORNER_TURN then
			side = if cross < 0 then 1 else -1
		end
		if corner[i] and not corner[(i % n) + 1] then
			local d = ROAD / 2 - Plot.SMOKE_IN
			out[#out + 1] = {
				x = a.x - a.tz * d * side,
				z = a.z + a.tx * d * side,
				yaw = math.atan2(a.tx, a.tz),
			}
		end
	end
	return out
end

-- Rubber donut rings burnt into the drift pad: { x, z, r } each, inside the pad.
Plot.DONUTS = {
	{ x = -26, z = -44, r = 12 },
	{ x = 6, z = -24, r = 14 },
	{ x = -12, z = -58, r = 10 },
}

-- Light poles on the open floor outside the loop, and the start gantry over the line.
-- Each one turns to face the middle of the track (yaw: the look direction is
-- (-sin yaw, -cos yaw), like CFrame.Angles(0, yaw, 0).LookVector).
Plot.TRACK_MIDDLE = { x = -12, z = -34 } -- the pad
Plot.LAMPS = {} :: { Spot }
for _, p in
	{ { -148, 130 }, { 148, 130 }, { 148, -40 }, { 148, -204 }, { -148, -204 }, { -148, -40 } }
do
	local dx, dz = Plot.TRACK_MIDDLE.x - p[1], Plot.TRACK_MIDDLE.z - p[2]
	table.insert(Plot.LAMPS, { x = p[1], z = p[2], yaw = math.atan2(-dx, -dz) })
end
Plot.LAMP_H = 34
-- carter's FloodLight model shines out of its -Z side (in Studio it faced away from the track
-- when its +Z was turned inward), so it gets an extra half turn
Plot.FLOODLIGHT_FLIP = math.pi

-- Pit garage in the infield behind the pad, open toward the stand: a concrete floor, three
-- walls and a red roof, with a workbench, toolbox, tyre rack, gas cans and a jack inside.
Plot.PIT = { x = 2, z = -117, w = 70, d = 28, h = 20 }
Plot.PIT_APRON = 3 -- concrete in front of the doors
Plot.PIT_PROPS = {
	{ name = "Workbench", x = -14, z = -127, yaw = 0, h = 7, size = { 18, 7, 7 }, color = "wood" },
	{ name = "Toolbox", x = 2, z = -128, yaw = 0, h = 6, size = { 8, 6, 5 }, color = "roof" },
	{
		name = "WheelRack",
		x = 24,
		z = -127,
		yaw = 0,
		h = 10,
		size = { 14, 10, 6 },
		color = "metal",
	},
	{ name = "GasCan", x = 28, z = -125, yaw = 0.4, h = 4, size = { 3, 4, 2 }, color = "roof" },
	{ name = "OilCan", x = 32, z = -121, yaw = -0.3, h = 3, size = { 2, 3, 2 }, color = "metal" },
	{
		name = "FloorJack",
		x = -26,
		z = -111,
		yaw = 0.6,
		h = 2.5,
		size = { 4, 2.5, 9 },
		color = "metal",
	},
	{ name = "TireStack", x = -30, z = -125, yaw = 0, h = 6, size = { 7, 6, 7 }, color = "tire" },
}

-- Bleachers in the infield between the pad and the front straight, facing the front straight
-- and the street. The strip behind the back straight is only about 20 deep and carter's model is
-- about 1.4 times wider than deep, so there it came out tiny (Studio: 6 x 4 studs). Here it gets
-- a 46 x 32 footprint, kept to 24 tall so it does not hide the pad from the stand.
Plot.BLEACHERS = { x = 2, z = 52, w = 46, d = 32, h = 24, rows = 3, rowH = 5 }

Plot.GRANDSTAND_YAW = 0 -- turns carter's Grandstand model to face the track

-- Low red and white safety fence just inside the side and back walls.
Plot.FENCE = { inset = 6, h = 5, post = 40 }

-- Start gantry over the start line: two posts beyond the road edges and a striped beam.
Plot.GANTRY = { h = 28, beam = 4 }

-- Marker cones round the drift pad edge (paint-like: the car drives through them).
Plot.PAD_CONES = 8

-- A copy of carter's Meshy prop `name` (ServerStorage.LobbyMeshes, imported in Studio, so it
-- can be missing: then nil and the caller builds a block stand-in), `height` tall, standing at
-- `at` (plot local). Import 3D brings models in huge with the front at +Z.
local function meshProp(
	parent: Instance,
	origin: CFrame,
	name: string,
	at: CFrame,
	height: number,
	w: number?,
	d: number?
): Model?
	local folder = game:GetService("ServerStorage"):FindFirstChild("LobbyMeshes")
	local t = folder and folder:FindFirstChild(name)
	if not t or not (t:IsA("Model") or t:IsA("BasePart")) then
		return nil
	end
	local m: Model
	if t:IsA("Model") then
		m = t:Clone()
	else
		m = Instance.new("Model")
		m.Name = name
		local part = (t :: BasePart):Clone()
		part.Parent = m
		m.PrimaryPart = part
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	-- `height` tall, or (with a footprint) as big as fits in w x d and at most `height` tall
	local _, size = m:GetBoundingBox()
	if size.Y > 0 then
		local k = height / size.Y
		if w and d and size.X > 0 and size.Z > 0 then
			k = math.min(k, w / size.X, d / size.Z)
		end
		m:ScaleTo(m:GetScale() * k)
	end
	local box, sized = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(box.Position - Vector3.new(0, sized.Y / 2, 0))
		* CFrame.Angles(0, math.pi, 0)
	m:PivotTo(origin * at)
	m.Parent = parent
	return m
end

-- Paint: flat, and nothing can hit it, stand on it or ray-cast it (the car's wheels look
-- straight through it to the road or the ground below).
local function paint(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

local function stripe(parent: Instance, origin: CFrame, s: Stripe, width: number, color: Color3)
	local pos = Vector3.new(s.x, TOP + 0.06, s.z)
	local p = Kit.part(
		parent,
		"Paint",
		origin,
		Vector3.new(width, 0.1, s.len),
		CFrame.lookAt(pos, pos + Vector3.new(s.tx, 0, s.tz)),
		color
	)
	paint(p)
end

-- A tyre stack: carter's Meshy one, or three black rings.
local function tireStack(parent: Instance, origin: CFrame, x: number, z: number, yaw: number)
	local at = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	if meshProp(parent, origin, "TireStack", at, 6) then
		return
	end
	local L = Plot.LOOK
	for k = 0, 2 do
		local ring = Kit.disc(parent, "Tire", origin, x, 1 + k * 2, z, 3.2, 2, L.tire)
		ring.Material = Enum.Material.Rubber
		if k == 1 then
			ring.Color = C.white
		end
	end
end

local function lamp(parent: Instance, origin: CFrame, spot: Spot)
	local h = Plot.LAMP_H
	local at = CFrame.new(spot.x, 0, spot.z) * CFrame.Angles(0, spot.yaw, 0)
	-- carter's Meshy floodlight if imported, else his street lamp, else blocks
	if
		meshProp(parent, origin, "FloodLight", at * CFrame.Angles(0, Plot.FLOODLIGHT_FLIP, 0), h)
		or meshProp(parent, origin, "StreetLamp", at, h)
	then
		return
	end
	local L = Plot.LOOK
	Kit.part(
		parent,
		"Lamp",
		origin,
		Vector3.new(2, h, 2),
		CFrame.new(spot.x, h / 2, spot.z),
		L.metal
	)
	Kit.part(
		parent,
		"Lamp",
		origin,
		Vector3.new(8, 2, 5),
		CFrame.new(spot.x, h + 1, spot.z),
		L.metal
	)
	local glow = Kit.part(
		parent,
		"LampGlow",
		origin,
		Vector3.new(7, 0.4, 4),
		CFrame.new(spot.x, h - 0.2, spot.z),
		rgb(255, 244, 200)
	)
	glow.Material = Enum.Material.Neon
	paint(glow)
end

-- A little two-bay garage, open toward the stand: concrete floor and apron, walls with side
-- windows, a pillar between the bays with half-open roll-up doors, a chequered header, and a
-- pitched red roof with yellow trim.
local function pit(parent: Instance, origin: CFrame)
	local L = Plot.LOOK
	local p = Plot.PIT
	local glass = rgb(150, 200, 230)
	local function box(name: string, size: Vector3, cf: CFrame, color: Color3): Part
		return Kit.part(parent, name, origin, size, cf, color)
	end
	local front, back = p.z + p.d / 2, p.z - p.d / 2

	-- floor and a short apron in front (flush with the road, same grip)
	local floor = box(
		"PitFloor",
		Vector3.new(p.w, TOP, p.d + Plot.PIT_APRON),
		CFrame.new(p.x, TOP / 2, p.z + Plot.PIT_APRON / 2),
		L.concrete
	)
	floor:SetAttribute("Grip", Plot.grip)

	-- walls
	box("PitWall", Vector3.new(p.w, p.h, 1.5), CFrame.new(p.x, p.h / 2, back), L.concrete)
	for _, side in { -1, 1 } do
		local x = p.x + side * p.w / 2
		box("PitWall", Vector3.new(1.5, p.h, p.d), CFrame.new(x, p.h / 2, p.z), L.concrete)
		-- a window in each side wall (a glass pane standing a little proud of the wall)
		local win = box(
			"PitWindow",
			Vector3.new(1.8, p.h * 0.3, p.d * 0.45),
			CFrame.new(x, p.h * 0.55, p.z),
			glass
		)
		win.Material = Enum.Material.Glass
		win.Transparency = 0.3
		-- corner posts at the front, in red
		box("PitPost", Vector3.new(2.5, p.h, 2.5), CFrame.new(x, p.h / 2, front), L.roof)
	end
	-- pillar between the two bays
	box("PitPost", Vector3.new(2.5, p.h, 2.5), CFrame.new(p.x, p.h / 2, front), L.roof)

	-- header over the doors: concrete with a black and white chequer strip (no words)
	local headerH = p.h * 0.28
	box(
		"PitHeader",
		Vector3.new(p.w, headerH, 1.5),
		CFrame.new(p.x, p.h - headerH / 2, front),
		L.concrete
	)
	local squares = 14
	local sq = p.w / squares
	for k = 1, squares do
		local c = box(
			"PitChequer",
			Vector3.new(sq, headerH * 0.35, 0.4),
			CFrame.new(p.x - p.w / 2 + (k - 0.5) * sq, p.h - headerH / 2, front + 0.9),
			if k % 2 == 0 then C.white else L.tire
		)
		c.CastShadow = false
	end
	-- roll-up doors, half open: a ribbed metal panel hanging under the header in each bay
	local bay = p.w / 2 - 2.5
	for _, side in { -1, 1 } do
		local door = box(
			"PitDoor",
			Vector3.new(bay, p.h * 0.18, 0.6),
			CFrame.new(p.x + side * p.w / 4, p.h - headerH - p.h * 0.09, front - 0.6),
			rgb(170, 175, 182)
		)
		door.Material = Enum.Material.DiamondPlate
	end

	-- pitched roof: two red slopes meeting over the middle, with yellow trim along the eaves
	local rise = p.h * 0.3
	local half = p.d / 2 + 2.5
	local slope = math.atan2(rise, half)
	local len = math.sqrt(half * half + rise * rise)
	for _, side in { -1, 1 } do
		box(
			"PitRoof",
			Vector3.new(p.w + 5, 1.2, len),
			CFrame.new(p.x, p.h + rise / 2, p.z + side * half / 2)
				* CFrame.Angles(side * slope, 0, 0),
			L.roof
		)
		box(
			"PitTrim",
			Vector3.new(p.w + 5.4, 1.2, 1.2),
			CFrame.new(p.x, p.h, p.z + side * half),
			L.yellow
		)
	end
	-- gable ends: a triangle under each end of the roof (two wedges)
	for _, side in { -1, 1 } do
		local x = p.x + side * p.w / 2
		for _, f in { -1, 1 } do
			local w = Instance.new("WedgePart")
			w.Name = "PitGable"
			w.Anchored = true
			w.Size = Vector3.new(1.5, rise, p.d / 2)
			w.Color = L.concrete
			w.Material = Enum.Material.SmoothPlastic
			-- a wedge is full height at its +Z end and slopes down to -Z: turn each half so
			-- its tall end is at the ridge (the middle) and it slopes down to the eaves
			w.CFrame = origin
				* CFrame.new(x, p.h + rise / 2, p.z + f * p.d / 4)
				* CFrame.Angles(0, if f > 0 then math.pi else 0, 0)
			w.Parent = parent
		end
	end

	for _, pr in Plot.PIT_PROPS do
		local at = CFrame.new(pr.x, TOP, pr.z) * CFrame.Angles(0, pr.yaw, 0)
		if not meshProp(parent, origin, pr.name, at, pr.h) then
			local sz = Vector3.new(pr.size[1], pr.size[2], pr.size[3])
			Kit.part(parent, pr.name, origin, sz, at * CFrame.new(0, sz.Y / 2, 0), L[pr.color])
		end
	end
end

local function bleachers(parent: Instance, origin: CFrame)
	local L = Plot.LOOK
	local b = Plot.BLEACHERS
	-- carter's Meshy grandstand (shared with the race plot) if imported, else block steps. At
	-- yaw pi it showed its back to the track in Studio, so the model's seats face its -Z.
	local at = CFrame.new(b.x, 0, b.z) * CFrame.Angles(0, Plot.GRANDSTAND_YAW, 0)
	if meshProp(parent, origin, "Grandstand", at, b.h, b.w, b.d) then
		return
	end
	local rowD = b.d / b.rows
	for r = 1, b.rows do
		local h = r * b.rowH
		-- each row a step higher and further back (away from the front straight)
		local z = b.z + b.d / 2 - (r - 0.5) * rowD
		Kit.part(
			parent,
			"Bleacher",
			origin,
			Vector3.new(b.w, h, rowD),
			CFrame.new(b.x, h / 2, z),
			if r % 2 == 1 then L.roof else C.white
		)
	end
end

local function smokePuff(parent: Instance, origin: CFrame, spot: Spot)
	local p = Kit.part(
		parent,
		"TyreSmoke",
		origin,
		Vector3.new(4, 1, 4),
		CFrame.new(spot.x, TOP + 0.5, spot.z),
		C.white
	)
	p.Transparency = 1
	paint(p)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(225, 225, 230), Color3.fromRGB(170, 170, 178))
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 5),
		NumberSequenceKeypoint.new(1, 16),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(3, 5)
	e.Rate = 2
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(40, 40)
	e.Acceleration = Vector3.new(0, 1.5, 0)
	e.Drag = 1
	e.RotSpeed = NumberRange.new(-20, 20)
	e.Rotation = NumberRange.new(0, 360)
	e.LightInfluence = 1
	e.Parent = p
end

-- A thin dark rubber ring painted on the pad.
local function donut(parent: Instance, origin: CFrame, d: { x: number, z: number, r: number })
	local bits = 24
	local seg = 2 * math.pi * d.r / bits + 0.6
	for i = 1, bits do
		local a = (i - 0.5) / bits * 2 * math.pi
		local pos = Vector3.new(d.x + math.cos(a) * d.r, TOP + 0.08, d.z + math.sin(a) * d.r)
		-- length along the ring: look across it (outward), the part's X then runs along it
		local p = Kit.part(
			parent,
			"Rubber",
			origin,
			Vector3.new(seg, 0.1, 3.5),
			CFrame.lookAt(pos, pos + Vector3.new(math.cos(a), 0, math.sin(a))),
			Plot.LOOK.tire
		)
		p.Transparency = 0.45
		paint(p)
	end
end

local function fence(parent: Instance, origin: CFrame)
	local f = Plot.FENCE
	local a = Kit.AREA
	local x0, x1 = a.minX + f.inset - 8, a.maxX - f.inset + 8
	local z0, z1 = a.minZ + f.inset - 8, a.maxZ + 8
	local runs = {
		{ Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0) },
		{ Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1) },
		{ Vector3.new(x1, 0, z0), Vector3.new(x1, 0, z1) },
	}
	for _, run in runs do
		local from, to = run[1], run[2]
		local len = (to - from).Magnitude
		local n = math.max(1, math.round(len / f.post))
		for k = 0, n do
			local p = from:Lerp(to, k / n)
			Kit.part(
				parent,
				"FencePost",
				origin,
				Vector3.new(1.2, f.h, 1.2),
				CFrame.new(p.X, f.h / 2, p.Z),
				C.white
			)
		end
		for r, y in { f.h - 0.6, f.h * 0.5 } do
			Kit.slab(
				parent,
				"FenceRail",
				origin,
				from + Vector3.new(0, y, 0),
				to + Vector3.new(0, y, 0),
				0.6,
				0.8,
				0,
				if r == 1 then C.red else C.white
			)
		end
	end
end

local function gantry(parent: Instance, origin: CFrame)
	local L = Plot.LOOK
	local g = Plot.GANTRY
	local s = start
	local rx, rz = -s.tz, s.tx -- across the road
	local half = ROAD / 2 + 10 -- posts well out, where a wide slide won't reach
	for _, side in { -1, 1 } do
		Kit.part(
			parent,
			"Gantry",
			origin,
			Vector3.new(2.5, g.h, 2.5),
			CFrame.new(s.x + rx * half * side, g.h / 2, s.z + rz * half * side),
			L.metal
		)
	end
	local mid = Vector3.new(s.x, g.h - g.beam / 2, s.z)
	-- lookAt's right vector runs across the road, so the beam's length (X) spans it
	local beamCF = CFrame.lookAt(mid, mid + Vector3.new(s.tx, 0, s.tz))
	Kit.part(parent, "Gantry", origin, Vector3.new(half * 2 + 2.5, g.beam, 2), beamCF, L.tire)
	-- no words (carter's rule): black and yellow blocks along the beam instead
	local blocks = 6
	local seg = (half * 2 + 2.5) / blocks
	for k = 1, blocks do
		if k % 2 == 0 then
			local p = Kit.part(
				parent,
				"GantryStripe",
				origin,
				Vector3.new(seg, g.beam + 0.2, 2.2),
				beamCF * CFrame.new(-half - 1.25 + (k - 0.5) * seg, 0, 0),
				L.yellow
			)
			p.CastShadow = false
		end
	end
	meshProp(
		parent,
		origin,
		"StartLight",
		CFrame.new(s.x, g.h, s.z) * CFrame.Angles(0, math.atan2(s.tx, s.tz), 0),
		6
	)
end

local function padCones(parent: Instance, origin: CFrame)
	local pad = Plot.PAD
	for k = 1, Plot.PAD_CONES do
		local a = (k - 1) / Plot.PAD_CONES * 2 * math.pi
		local x, z = pad.x + math.cos(a) * (pad.r + 4), pad.z + math.sin(a) * (pad.r + 4)
		local at = CFrame.new(x, TOP, z)
		local m = meshProp(parent, origin, "Cone", at, 4)
		if m then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					paint(d)
				end
			end
		else
			local base = Kit.part(
				parent,
				"PadCone",
				origin,
				Vector3.new(3, 0.4, 3),
				at * CFrame.new(0, 0.2, 0),
				C.orange
			)
			local top = Kit.disc(parent, "PadCone", origin, x, TOP + 2, z, 0.9, 3.6, C.orange)
			top.Size = Vector3.new(3.6, 1.8, 1.8)
			top.CFrame = origin * CFrame.new(x, TOP + 2.2, z) * CFrame.Angles(0, 0, math.rad(90))
			paint(base)
			paint(top)
		end
	end
end

function Plot.build(parent: Instance, origin: CFrame)
	local L = Plot.LOOK

	-- grass on the plot floor (the base built it grey; same grip, only the look changes)
	local ground = parent:FindFirstChild("Ground")
	if ground and ground:IsA("BasePart") then
		ground.Color = L.grass
		ground.Material = Enum.Material.Grass
	end

	-- the road: asphalt, same shape and grip as before
	local road = Instance.new("Folder")
	road.Name = "DriftRoad"
	road.Parent = parent
	-- each piece reaches far enough past its ends to close the wedge gap on the outside of a
	-- bend (no grass streaks). Smooth plastic, so where pieces overlap nothing flickers.
	for _, seg in Plot.roadPieces() do
		local piece = Kit.slab(
			road,
			"Road",
			origin,
			Vector3.new(seg.ax, TOP / 2, seg.az),
			Vector3.new(seg.bx, TOP / 2, seg.bz),
			ROAD,
			TOP,
			seg.extra,
			L.asphalt
		)
		piece:SetAttribute("Grip", Plot.grip)
	end

	local curbs, lines = Plot.paint()
	for _, s in curbs do
		stripe(parent, origin, s, Plot.CURB_W, if s.red then C.red else C.white)
	end
	for _, s in lines do
		stripe(parent, origin, s, 1.6, C.white)
	end

	-- Start line across the road (painted, no bump) and the gantry over it.
	Kit.line(parent, origin, start.x, TOP, start.z, start.tx, start.tz, ROAD, C.white)
	gantry(parent, origin)

	-- Drift pad: flush with the road, same grip, a painted white ring, and the cone.
	local pad = Plot.PAD
	local disc = Kit.disc(parent, "DriftPad", origin, pad.x, TOP / 2, pad.z, pad.r, TOP, L.asphalt)
	disc:SetAttribute("Grip", Plot.grip)
	local bits = 40
	local seg = 2 * math.pi * pad.r / bits + 1
	for i = 1, bits do
		local a = (i - 0.5) / bits * 2 * math.pi
		local x, z = pad.x + math.cos(a) * pad.r, pad.z + math.sin(a) * pad.r
		-- Kit.line runs its length across (dx, dz), so face it outward to lay it along the ring.
		local ring = Kit.line(
			parent,
			origin,
			x,
			TOP,
			z,
			math.cos(a),
			math.sin(a),
			seg,
			if i % 2 == 0 then C.red else C.white
		)
		paint(ring)
	end
	local cone = Plot.CONE
	Kit.disc(parent, "Cone", origin, pad.x, cone.h / 2, pad.z, cone.r, cone.h, C.orange)
	padCones(parent, origin)
	for _, d in Plot.DONUTS do
		donut(parent, origin, d)
	end
	for _, spot in Plot.smoke() do
		smokePuff(parent, origin, spot)
	end

	for _, t in Plot.tires() do
		tireStack(parent, origin, t.x, t.z, t.yaw)
	end
	for _, spot in Plot.LAMPS do
		lamp(parent, origin, spot)
	end
	pit(parent, origin)
	bleachers(parent, origin)
	fence(parent, origin)
end

return Plot
