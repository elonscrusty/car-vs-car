--!strict
-- Street decorations for the walking lobby (LobbyLayout): what makes the street feel alive.
-- Bunting strung across the road between the lamps, flower planters and street bits (hydrant,
-- bin, mailbox) on the footpaths, a flag and a flower bed in each grass gap between plots, a
-- zebra crossing at each gap and a checker start line where the road leaves the spawn lobby (not in Smash),
-- and a big RC corner on each side of the spawn lobby (a giant remote and a giant battery with
-- tyres and cones round them). Butterflies and birds (life()) fly on each player's own screen
-- (client LobbyLife). No benches or tables, no text or logos. Low-poly flat colours.
--
-- World space (the street's own numbers). Plain numbers only (Lune tests load this).

-- Loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Features = sibling("Features")
local Garage = sibling("Garage")
local LobbyLayout = sibling("LobbyLayout")
local LobbyWater = sibling("LobbyWater")
-- Smash (no racing): no checker start line and no checkered Meshy flags on the street
local SMASH = sibling("SpawnLobby").SMASH

type V3 = Garage.V3
type Piece = Garage.Piece
type Mesh = Garage.Mesh

-- A Meshy prop that must look one way (MeshProps.place turns its front to `face`), standing
-- `height` tall on `at`; it takes the place of its group's block stand-ins, but `keep`.
export type Faced = {
	model: string,
	group: string,
	at: V3,
	height: number,
	face: V3,
	keep: { string },
	collide: boolean,
	turn: number, -- extra turn (degrees about y) after facing, see FRONT_TURN
}

export type Flyer = {
	kind: string, -- "Butterfly" or "Bird"
	x: number, -- middle of its loop
	y: number,
	z: number,
	r: number, -- loop size
	speed: number, -- turns a second (birds) or wander speed (butterflies)
	phase: number,
	color: { number },
}

local LobbyDecor = {}

local L = LobbyLayout
local EDGE = L.EDGE -- plot fronts / outer footpath edge (x)
local ROW_Z: { number } = {}
for row = 1, L.ROWS do
	ROW_Z[row] = L.FIRST_Z + (row - 1) * L.STEP
end
-- the grass gaps between plots on the same side (also where the lamps stand)
local GAP_Z: { number } = {}
for row = 1, L.ROWS - 1 do
	GAP_Z[row] = ROW_Z[row] + L.STEP / 2
end
LobbyDecor.ROW_Z = ROW_Z
LobbyDecor.GAP_Z = GAP_Z

-- where the string ties on: on a short mast over each lamp post (9 studs), so the walking camera
-- passes under the flags (phone playtest u29: at 9.2 with 3-stud flags they filled the top half
-- of the screen)
LobbyDecor.BUNTING_Y = 12.5
LobbyDecor.PLANTER_DZ = 24 -- planters: this far down the street from a plot's middle
LobbyDecor.BIT_DZ = -30 -- hydrant / bin / mailbox: this far up the street
LobbyDecor.PATH_X = EDGE - 1.2 -- footpath things stand by the outer edge
LobbyDecor.FLAG_X = EDGE + 5 -- flags and flower beds in the gaps
LobbyDecor.CORNER = { x = 94, z = L.PLAZA.minZ + 40 } -- the RC corners (x mirrored)
-- Small lived-in props (carter's Meshy ones, a plain block until imported), each facing the
-- road or the spawn: { model, x, z, height, faceX, faceZ, block size, block colour, solid }.
export type Extra = {
	model: string,
	x: number,
	z: number,
	h: number,
	fx: number,
	fz: number,
	size: { number },
	color: { number },
	solid: boolean,
	turn: number?,
}
-- Spawn lobby music: a looped Creator Store track, played quietly from the two speakers (only
-- near them). Empty = no music (an id must be checked to load in Studio before it goes in).
-- "Citrus Daydream" (DistrokidOfficial, free, 166 s), checked to load in Studio 10-23.
LobbyDecor.MUSIC = "rbxassetid://84797666595507"
LobbyDecor.MUSIC_VOLUME = sibling("SoundLevels").MUSIC
-- in the gap between the two shops on each side of the spawn lobby (SpawnLobby.BUILDINGS, whose
-- fronts are at x ±42), facing the middle. Spawn lobby z 0 = PLAZA.maxZ - 36.
LobbyDecor.SPEAKERS = if Features.CVC
	then {
		-- Car VS Car: no drift shop, so the left one stood alone by the crate shop (Studio score
		-- shot 28); the crate shop's sign post stands there now
		{ x = 45, z = L.PLAZA.maxZ - 36 - 6.5 },
	}
	else {
		{ x = -45, z = L.PLAZA.maxZ - 36 - 3.5 }, -- between the drift and race shops
		{ x = 45, z = L.PLAZA.maxZ - 36 - 6.5 }, -- between the rock shop and the garage
	}
LobbyDecor.CORNER_CONES = { { -17, 14 }, { -12, 17 }, { 15, -15 } } -- round a corner (x mirrored)

local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

local C = {
	rope = { 70, 64, 58 },
	white = { 245, 245, 245 },
	wood = { 150, 104, 62 },
	soil = { 96, 66, 44 },
	stem = { 70, 150, 60 },
	pole = { 210, 210, 214 },
	red = { 226, 72, 64 },
	hydrant = { 222, 56, 48 },
	bin = { 72, 128, 88 },
	mail = { 60, 104, 190 },
	dark = { 40, 40, 46 },
	tire = { 34, 34, 38 },
	cone = { 245, 128, 40 },
	remote = { 52, 56, 66 },
	remote2 = { 230, 70, 60 },
	stick = { 30, 30, 34 },
	cell = { 250, 196, 40 },
	cell2 = { 40, 42, 48 },
	cap = { 200, 200, 206 },
}
-- bright pennant and flower colours, in turn
LobbyDecor.BRIGHT = {
	{ 238, 70, 70 },
	{ 255, 190, 50 },
	{ 70, 170, 240 },
	{ 110, 200, 80 },
	{ 240, 120, 200 },
	{ 255, 140, 50 },
}
local BRIGHT = LobbyDecor.BRIGHT

-- Bunting across the road: one rope and 11 big pennants.
local function bunting(add: Garage.Add, z: number, n: number)
	local g = "Bunting" .. n
	local half = L.EDGE - 1 -- the lamps stand here (LobbyLayout.lamps)
	local top = LobbyDecor.BUNTING_Y
	add(g, "Rope", v(2 * half, 0.2, 0.2), v(0, top, z), C.rope, { collide = false })
	for _, sx in { -1, 1 } do
		add(g, "Mast", v(0.3, top - 8.4, 0.3), v(sx * half, (top + 8.4) / 2, z), C.rope, {
			collide = false,
		})
	end
	local flags = 11
	for i = 1, flags do
		local x = -half + i * (2 * half / (flags + 1))
		-- a wedge pointing down: its slope faces -z, the point at the bottom
		add(g, "Pennant", v(0.08, 2, 1.5), v(x, top - 1, z), BRIGHT[(i + n) % #BRIGHT + 1], {
			shape = "Wedge",
			rot = v(180, 90, 0),
			collide = false,
		})
	end
end

-- A wooden planter box with flowers, long side along the street.
local function planter(add: Garage.Add, g: string, x: number, z: number, n: number)
	add(g, "Box", v(1.6, 1, 4.6), v(x, 0.6, z), C.wood)
	add(g, "Soil", v(1.3, 0.2, 4.3), v(x, 1.15, z), C.soil, { collide = false })
	for i = -1, 1 do
		local col = BRIGHT[(n + i + 1) % #BRIGHT + 1]
		add(g, "Flower", v(0.9, 0.7, 0.9), v(x, 1.55, z + i * 1.4), col, {
			rot = v(0, 45, 0),
			collide = false,
		})
	end
end

-- A low flower bed: dark soil, a green bush and five bright flowers.
local function flowerBed(add: Garage.Add, g: string, x: number, z: number, n: number)
	add(g, "Bed", v(4, 0.3, 6), v(x, 0.1, z), C.soil, { collide = false })
	local spots = { { -1.3, -2.2 }, { 1.3, -1.8 }, { -1.2, 1 }, { 1.2, 1.5 }, { 0, 2.4 } }
	add(g, "Bush", v(2, 1.4, 2), v(x, 0.9, z - 0.6), C.stem, { rot = v(0, 30, 0), collide = false })
	for i, s in spots do
		add(
			g,
			"Flower",
			v(0.8, 0.8, 0.8),
			v(x + s[1], 0.6, z + s[2]),
			BRIGHT[(n + i) % #BRIGHT + 1],
			{
				rot = v(0, 45, 0),
				collide = false,
			}
		)
	end
end

-- A tall white pole with a bright flag pointing away from the road.
local function flag(add: Garage.Add, g: string, x: number, z: number, n: number)
	local out = if x < 0 then -1 else 1
	add(g, "Foot", v(1, 0.4, 1), v(x, 0.2, z), C.pole)
	add(g, "Pole", v(0.3, 11, 0.3), v(x, 5.5, z), C.pole)
	add(g, "Ball", v(0.5, 0.5, 0.5), v(x, 11.2, z), C.cell, { shape = "Ball" })
	add(g, "Flag", v(3.4, 2, 0.1), v(x + out * 1.85, 9.8, z), BRIGHT[n % #BRIGHT + 1], {
		collide = false,
	})
end

local function hydrant(add: Garage.Add, g: string, x: number, z: number)
	add(g, "Body", v(1.6, 1, 1), v(x, 0.9, z), C.hydrant, { shape = "Cylinder", rot = v(0, 0, 90) })
	add(g, "Top", v(0.9, 0.5, 0.9), v(x, 1.9, z), C.hydrant, { shape = "Ball" })
	add(g, "Arms", v(1.6, 0.35, 0.35), v(x, 1.2, z), C.hydrant, { shape = "Cylinder" })
end

local function bin(add: Garage.Add, g: string, x: number, z: number)
	add(g, "Can", v(2.4, 1.4, 1.4), v(x, 1.2, z), C.bin, { shape = "Cylinder", rot = v(0, 0, 90) })
	add(g, "Lid", v(0.2, 1.6, 1.6), v(x, 2.5, z), C.dark, { shape = "Cylinder", rot = v(0, 0, 90) })
end

local function mailbox(add: Garage.Add, g: string, x: number, z: number)
	add(g, "Post", v(0.3, 2.4, 0.3), v(x, 1.2, z), C.wood)
	add(g, "Box", v(1.2, 0.9, 1.6), v(x, 2.8, z), C.mail)
	add(g, "Flag", v(0.08, 0.6, 0.2), v(x + 0.65, 3.1, z + 0.4), C.red, { collide = false })
end

local function tireStack(add: Garage.Add, g: string, x: number, z: number, high: number)
	for i = 0, high - 1 do
		add(g, "Tire", v(0.8, 2.4, 2.4), v(x, 0.4 + i * 0.8, z), C.tire, {
			shape = "Cylinder",
			rot = v(0, 0, 90),
		})
	end
end

local function cone(add: Garage.Add, g: string, x: number, z: number)
	add(g, "Base", v(1.2, 0.2, 1.2), v(x, 0.1, z), C.dark, { collide = false })
	add(g, "Cone", v(0.7, 1.2, 0.7), v(x, 0.8, z), C.cone, { collide = false })
end

-- Adds pieces `k` times bigger round (x, z): offsets and sizes both scale.
local function scaled(add: Garage.Add, k: number, x: number, z: number): Garage.Add
	return function(
		group: string,
		name: string,
		size: V3,
		pos: V3,
		color: { number },
		opts: Garage.Opts?
	)
		add(
			group,
			name,
			v(size.x * k, size.y * k, size.z * k),
			v(x + pos.x * k, pos.y * k, z + pos.z * k),
			color,
			opts
		)
	end
end

LobbyDecor.GIANT = 2.2 -- how much bigger than the stand-in sizes below the giant props are

-- A giant RC remote lying back on a slope, two sticks up, antenna up.
local function giantRemote(add0: Garage.Add, g: string, x: number, z: number)
	local add = scaled(add0, LobbyDecor.GIANT, x, z)
	local tilt = v(-20, 0, 0)
	add(g, "Body", v(10, 2.4, 6), v(0, 3.2, 0), C.remote, { rot = tilt })
	add(g, "Grip", v(2.6, 3.6, 2.6), v(-4, 1.8, 1.6), C.remote, { rot = tilt })
	add(g, "Grip", v(2.6, 3.6, 2.6), v(4, 1.8, 1.6), C.remote, { rot = tilt })
	for _, sx in { -2.5, 2.5 } do
		add(g, "Stick", v(0.5, 2.4, 0.5), v(sx, 5.2, -0.4), C.stick, { rot = tilt })
		add(g, "Knob", v(0.6, 1.1, 1.1), v(sx, 6.4, -0.8), C.remote2, {
			shape = "Cylinder",
			rot = v(0, 0, 90),
		})
	end
	add(g, "Antenna", v(0.3, 7, 0.3), v(-3.6, 7.6, -2), C.cap, { rot = tilt })
	add(g, "Tip", v(0.6, 0.6, 0.6), v(-3.6, 11.1, -3.2), C.remote2, { shape = "Ball" })
end

-- A giant AA battery lying on its side.
local function giantBattery(add0: Garage.Add, g: string, x: number, z: number)
	local add = scaled(add0, LobbyDecor.GIANT, x, z)
	add(g, "Cell", v(11, 4.4, 4.4), v(0, 2.2, 0), C.cell, { shape = "Cylinder" })
	add(g, "Band", v(4, 4.5, 4.5), v(-3.5, 2.2, 0), C.cell2, { shape = "Cylinder" })
	add(g, "Nub", v(0.8, 1.6, 1.6), v(5.9, 2.2, 0), C.cap, { shape = "Cylinder" })
end

-- A wooden jump ramp (rising toward +x), for looks.
local function ramp(add: Garage.Add, g: string, x: number, z: number)
	add(g, "Ramp", v(10, 4, 14), v(x, 2, z), C.wood, { shape = "Wedge", rot = v(0, -90, 0) })
end

-- MeshProps.place turns a prop's +Z side to the look direction, but these props have their
-- real front (door, latch) at -Z (props/HANDOFF.md "FRONT DIRECTION"), so they turn round.
LobbyDecor.FRONT_TURN = { Mailbox = 180, Toolbox = 180, Speaker = 180 } :: { [string]: number }

local function extras(): { Extra }
	local out: { Extra } = {}
	local function put(
		model: string,
		x: number,
		z: number,
		h: number,
		fx: number,
		fz: number,
		size: { number },
		color: { number },
		solid: boolean,
		turn: number?
	)
		table.insert(out, {
			model = model,
			x = x,
			z = z,
			h = h,
			fx = fx,
			fz = fz,
			size = size,
			color = color,
			solid = solid,
			turn = turn,
		})
	end
	local n = 0
	for row, z in ROW_Z do
		for _, side in { -1, 1 } do
			n += 1
			-- bags by every bin
			if n % 3 == 1 then
				put(
					"TrashBags",
					side * LobbyDecor.PATH_X,
					z + LobbyDecor.BIT_DZ + 2.2,
					1.2,
					-side,
					0,
					{ 1.4, 1.2, 1.4 },
					C.dark,
					false
				)
			end
			-- a drain grate in the road's edge, every other plot
			if (row + (if side > 0 then 1 else 0)) % 2 == 0 then
				put(
					"DrainGrate",
					side * (L.ROAD_W / 2 - 0.8),
					z - 8,
					0.15,
					-side,
					0,
					{ 1.2, 0.1, 2 },
					C.dark,
					false
				)
			end
		end
	end
	-- where the street leaves the spawn lobby: a traffic barrel and an arrow sign each side
	local mouth = L.road().minZ
	for _, side in { -1, 1 } do
		put(
			"TrafficBarrel",
			side * (L.EDGE + 2.5),
			mouth + 4,
			2.4,
			-side,
			0,
			{ 1.5, 2.4, 1.5 },
			C.cone,
			true
		)
		-- its face to the road; its arrow (the mesh's -X) points down the street, which on the
		-- right side needs it turned round (it is flat, so both sides show)
		put(
			"ArrowSign",
			side * (L.EDGE + 4.5),
			mouth + 5,
			4,
			-side,
			0,
			{ 0.3, 4, 2.4 },
			C.white,
			true,
			if side > 0 then 180 else 0
		)
	end
	-- music speakers between the shops, facing in (the music itself: MUSIC)
	for _, sp in LobbyDecor.SPEAKERS do
		local side = if sp.x < 0 then -1 else 1
		put("Speaker", sp.x, sp.z, 4.5, -side, 0, { 2, 4.5, 1.6 }, C.dark, true)
	end
	-- RC workshop bits round the giant corners
	local cx, cz = LobbyDecor.CORNER.x, LobbyDecor.CORNER.z
	put("GasCan", -cx + 12, cz + 6, 1.6, 1, 0, { 1.2, 1.6, 0.8 }, C.red, false)
	put("OilCan", -cx + 14, cz + 5, 1.2, 1, 0, { 0.7, 1.2, 0.7 }, C.cell, false)
	put("ToolCart", cx - 14, cz + 12, 3.5, -1, 0, { 2.4, 3.5, 1.6 }, C.red, true)
	put("Toolbox", cx - 17, cz + 14, 1.4, -1, 0, { 1.8, 1.2, 1 }, C.red, false)
	return out
end
LobbyDecor.extras = extras

-- Is a thing at (x, z), reaching hx / hz each way, on the road or its footpaths (where the
-- pads are too)? Things there are looks only: nothing a kid can get stuck on or behind.
function LobbyDecor.onWalk(x: number, z: number, hx: number, hz: number): boolean
	local w = L.walks()
	return x + hx > w.minX and x - hx < w.maxX and z + hz > w.minZ and z - hz < w.maxZ
end
LobbyDecor.WALK_TOP = 4 -- above this a thing is over your head (bunting, banners): it can stay

-- The block pieces (world space). The meshes in MESHES take the place of some groups.
function LobbyDecor.parts(): { Piece }
	local out: { Piece } = {}
	local add = Garage.adder(out)
	local road = L.road()

	-- bunting at every lamp pair
	for i, l in L.lamps() do
		if l.x < 0 then
			bunting(add, l.z, i)
		end
	end

	-- road paint: a checker start line by the spawn lobby, zebra crossings at the gaps
	local startZ = road.minZ + 6.25 -- past where cars wait (LobbyLayout.parkSpot)
	local w = L.ROAD_W
	for i = 0, if SMASH then -1 else w - 1 do
		for r = 0, 1 do
			if (i + r) % 2 == 0 then
				add(
					"StartLine",
					"Check",
					v(1, 0.05, 1),
					v(-w / 2 + i + 0.5, 0.13, startZ + r),
					C.white,
					{
						collide = false,
					}
				)
			end
		end
	end
	for n, z in GAP_Z do
		for i = 0, 5 do
			add(
				"Crossing" .. n,
				"Stripe",
				v(1.2, 0.05, 5),
				v(-w / 2 + 1.5 + i * 2.2, 0.13, z),
				C.white,
				{
					collide = false,
				}
			)
		end
	end

	-- footpath: a planter down from each plot's middle, a hydrant / bin / mailbox up from it
	local n = 0
	for _, z in ROW_Z do
		for _, side in { -1, 1 } do
			n += 1
			local x = side * LobbyDecor.PATH_X
			planter(add, "Planter" .. n, x, z + LobbyDecor.PLANTER_DZ, n)
			local kind = n % 3
			if kind == 0 then
				hydrant(add, "Hydrant" .. n, x, z + LobbyDecor.BIT_DZ)
			elseif kind == 1 then
				bin(add, "TrashCan" .. n, x, z + LobbyDecor.BIT_DZ)
			else
				mailbox(add, "Mailbox" .. n, x, z + LobbyDecor.BIT_DZ)
			end
		end
	end

	-- the grass gaps between plots: a flag and a flower bed each side
	n = 0
	for _, z in GAP_Z do
		for _, side in { -1, 1 } do
			n += 1
			local x = side * LobbyDecor.FLAG_X
			flag(add, "Flag" .. n, x, z - 2, n)
			flowerBed(add, "FlowerBed" .. n, side * (LobbyDecor.FLAG_X + 5), z, n)
		end
	end

	-- the RC corners beside the spawn lobby: a giant remote (left), a giant battery (right)
	local cx, cz = LobbyDecor.CORNER.x, LobbyDecor.CORNER.z
	giantRemote(add, "GiantRemote", -cx, cz)
	giantBattery(add, "GiantBattery", cx, cz)
	ramp(add, "Ramp", -cx + 2, cz + 20)
	for _, side in { -1, 1 } do
		tireStack(add, "CornerTires" .. side, side * (cx + 17), cz - 11, 3)
		tireStack(add, "CornerTires2" .. side, side * (cx + 19.5), cz - 8.5, 2)
		tireStack(add, "CornerTires3" .. side, side * (cx - 17), cz + 11, 2)
		for i, d in LobbyDecor.CORNER_CONES do
			cone(add, "CornerCone" .. side .. "_" .. i, side * (cx + d[1]), cz + d[2])
		end
	end
	-- the small lived-in props' stand-ins
	for i, e in extras() do
		local sz = e.size
		add("Extra" .. i, e.model, v(sz[1], sz[2], sz[3]), v(e.x, sz[2] / 2, e.z), e.color, {
			collide = e.solid,
		})
	end
	-- the walk lanes stay clear: what stands on them you walk through
	for _, p in out do
		local half = math.max(p.size.x, p.size.z) / 2 -- turned pieces: their widest reach
		if
			p.collide
			and p.pos.y - p.size.y / 2 < LobbyDecor.WALK_TOP
			and LobbyDecor.onWalk(p.pos.x, p.pos.z, half, half)
		then
			p.collide = false
		end
	end
	return out
end

-- carter's Meshy models in place of some stand-ins (see Garage.Mesh). No model, blocks stay.
LobbyDecor.MESHES = {} :: { Mesh }
do
	local M = LobbyDecor.MESHES
	local function mesh(model: string, group: string, at: V3, fit: V3, collide: boolean)
		table.insert(M, {
			model = model,
			group = group,
			at = at,
			fit = fit,
			long = if fit.z > fit.x then "z" else "x",
			keep = {},
			collide = collide,
		})
	end
	local cx, cz = LobbyDecor.CORNER.x, LobbyDecor.CORNER.z
	mesh("RCRemote", "GiantRemote", v(-cx, 0, cz), v(24, 28, 16), true)
	mesh("Battery", "GiantBattery", v(cx, 0, cz), v(34, 15, 15), true) -- as big as the remote
	mesh("WoodRamp", "Ramp", v(-cx + 2, 0, cz + 20), v(14, 4.5, 10), true)
	for _, side in { -1, 1 } do
		for _, g in { "CornerTires", "CornerTires2", "CornerTires3" } do
			local tall = if g == "CornerTires" then 2.4 else 1.6
			local dx = if g == "CornerTires" then 17 elseif g == "CornerTires2" then 19.5 else -17
			local dz = if g == "CornerTires" then -11 elseif g == "CornerTires2" then -8.5 else 11
			mesh("TireStack", g .. side, v(side * (cx + dx), 0, cz + dz), v(2.6, tall, 2.6), true)
		end
		for i, d in LobbyDecor.CORNER_CONES do
			mesh(
				"Cone",
				"CornerCone" .. side .. "_" .. i,
				v(side * (cx + d[1]), 0, cz + d[2]),
				v(1.3, 1.4, 1.3),
				false
			)
		end
	end
end

-- Meshy props that face the road: flower boxes, hydrant / bin / mailbox, the gap flags, and flower pots and a
-- bush on each gap's flower bed.
LobbyDecor.FACED = {} :: { Faced }
do
	local F = LobbyDecor.FACED
	local function faced(
		model: string,
		group: string,
		at: V3,
		height: number,
		face: V3,
		keep: { string }?,
		collide: boolean?,
		turn: number?
	)
		table.insert(F, {
			model = model,
			group = group,
			at = at,
			height = height,
			face = face,
			keep = keep or {},
			-- on the walk lanes: looks only (a mesh's bumpy hull is easy to get stuck on)
			collide = collide ~= false
				and not LobbyDecor.onWalk(at.x, at.z, height * 0.4, height * 0.4),
			turn = (turn or 0) + (LobbyDecor.FRONT_TURN[model] or 0),
		})
	end
	local n = 0
	for _, z in ROW_Z do
		for _, side in { -1, 1 } do
			n += 1
			local road = v(-side, 0, 0)
			local at = v(side * LobbyDecor.PATH_X, 0, z + LobbyDecor.BIT_DZ)
			-- FlowerBox (carter's Meshy planter): its front to the road, so its long side runs
			-- along the street
			faced(
				"FlowerBox",
				"Planter" .. n,
				v(side * LobbyDecor.PATH_X, 0, z + LobbyDecor.PLANTER_DZ),
				2.4,
				road
			)
			local kind = n % 3
			if kind == 0 then
				faced("Hydrant", "Hydrant" .. n, at, 2.2, road)
			elseif kind == 1 then
				faced("TrashCan", "TrashCan" .. n, at, 3, road)
			else
				faced("Mailbox", "Mailbox" .. n, at, 3.4, road)
			end
		end
	end
	n = 0
	for _, z in GAP_Z do
		for _, side in { -1, 1 } do
			n += 1
			local road = v(-side, 0, 0)
			local model = if n % 2 == 0 or SMASH then "BlueFlag" else "Flag" -- (Flag: checkered)
			faced(model, "Flag" .. n, v(side * LobbyDecor.FLAG_X, 0, z - 2), 11.5, road)
			local bx = side * (LobbyDecor.FLAG_X + 5)
			local bed = "FlowerBed" .. n
			faced("Bush", bed, v(bx + side * 0.6, 0.2, z - 0.6), 2.2, road, { "Bed" }, false)
			faced("FlowerPot", bed, v(bx - side * 0.8, 0.2, z - 2.2), 1.8, road, { "Bed" }, false)
			faced("FlowerPot", bed, v(bx - side * 0.8, 0.2, z + 1.8), 1.8, road, { "Bed" }, false)
		end
	end
	for i, e in extras() do
		faced(e.model, "Extra" .. i, v(e.x, 0, e.z), e.h, v(e.fx, 0, e.fz), {}, e.solid, e.turn)
	end
end

-- Butterflies over the flower beds in the gaps, birds circling high over the street, seagulls
-- over the lake (low enough to see, above the sailboat's mast). None over the planters by the
-- plot fronts: they drifted onto the plot floor and looked like a stray pink cube on a phone.
function LobbyDecor.life(): { Flyer }
	local out: { Flyer } = {}
	local n = 0
	for _, z in GAP_Z do
		for _, side in { -1, 1 } do
			n += 1
			for k = 0, 1 do
				table.insert(out, {
					kind = "Butterfly",
					x = side * (LobbyDecor.FLAG_X + 5),
					y = 2.6 + k * 0.8,
					z = z + (k - 0.5) * 2,
					r = 3,
					speed = 0.6 + 0.15 * k,
					phase = n * 1.7 + k * 3.1,
					color = BRIGHT[(n + k * 2) % #BRIGHT + 1],
				})
			end
		end
	end
	local mid = (L.road().minZ + L.road().maxZ) / 2
	for i = 1, 5 do
		table.insert(out, {
			kind = "Bird",
			x = (i - 3) * 14,
			y = 42 + i * 4,
			z = mid + (i - 3) * 60,
			r = 26 + i * 5,
			speed = 0.035 + i * 0.006,
			phase = i * 1.3,
			color = { 245, 245, 245 },
		})
	end
	local lake = LobbyWater.lakeBox()
	local lx, lz = (lake.minX + lake.maxX) / 2, (lake.minZ + lake.maxZ) / 2
	local reach = (lake.maxZ - lake.minZ) / 2
	for i = 1, 3 do
		table.insert(out, {
			kind = "Bird",
			x = lx + (i - 2) * (lake.maxX - lake.minX) * 0.25,
			y = 20 + i * 3,
			z = lz + (i - 2) * 8,
			r = reach * (0.45 + 0.1 * i),
			speed = 0.05 + i * 0.008,
			phase = i * 2.1,
			color = { 250, 250, 250 },
		})
	end
	return out
end

return LobbyDecor
