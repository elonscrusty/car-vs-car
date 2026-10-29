--!strict
-- Car VS Car Smash's WARM-UP YARD (FINISH-JOBS, GO 22:13, auditor C2): a kid who walks into the
-- SMASH! portal while a round is on waits up to ~2:50 for the next one. They drive here meanwhile:
-- "?" boxes (BoxServer, its own set), live weapons (WeaponServer) and target dummy karts that pop
-- (BOTS), no score and no coins, under a big NEXT MATCH IN m:ss (workspace NextMatchAt, MATCH's).
-- At the start, MatchRunner takes everyone waiting into the arena.
-- A small map like the arena (ArenaData): map-local "big" units, shrunk to RC size
-- (TrackData.RC_SCALE) at RC_X / RC_Z, so the karts drive it the same way (LobbyLayout.yardIndex).
-- Pure (Lune tests it): where it is, its pieces, the spots, and the clock words.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Garage = sibling("Garage")
local TrackData = sibling("TrackData")

type V3 = { x: number, y: number, z: number }
local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

local WarmupYard = {}

WarmupYard.id = "yard"

-- Is Smash on? Features.SMASH, or in Studio the workspace attribute Smash (Main's MatchRunner
-- switch). Lune: just the flag.
function WarmupYard.on(): boolean
	local Features = sibling("Features")
	if not Features.CVC then
		return false
	end
	if Features.SMASH then
		return true
	end
	return script ~= nil
		and game:GetService("RunService"):IsStudio()
		and workspace:GetAttribute("Smash") == true
end
-- World spot (RC studs). Far from everything: the lobby and plots are at z 900+, the old race
-- maps at x +-3000, the arena at z -3000; nothing else is in view while you play here.
WarmupYard.RC_X, WarmupYard.RC_Z, WarmupYard.RC_ANGLE = 0, -2000, 0
-- map-local big units (a kart is 3 x 5.5): about half the arena's 360 across
WarmupYard.W = 200 -- x
WarmupYard.D = 140 -- z
WarmupYard.WALL_H = 8 -- low, so it reads as a play yard; karts bounce off it
WarmupYard.WALL_T = 6

-- low-poly palette (FINISH-JOBS look rule): grass green, sunny yellow, hot pink, dark navy, and
-- the arena's purple wall
local GRASS = { 104, 196, 82 }
local SAND = { 246, 214, 140 }
local PURPLE = { 132, 84, 214 }
local PINK = { 255, 64, 160 }
local NAVY = { 32, 40, 74 }
local YELLOW = { 255, 210, 60 }

-- the arena's dressing colours (ArenaBuilder)
local STICK = { 252, 248, 240 }
local CANDY, CANDY_2 = { 214, 44, 178 }, { 255, 110, 200 }
local ORANGE = { 255, 140, 40 }
local CRATE, CRATE_BAND = { 255, 196, 60 }, { 230, 120, 30 }
local RED, WHITE = { 225, 40, 50 }, { 250, 250, 250 }
local BUSH, BUSH_2 = { 56, 150, 64 }, { 84, 176, 72 }
local GRASS_DARK, GRASS_LIGHT = { 92, 182, 70 }, { 146, 220, 100 }
-- the world outside (ArenaBuilder's buildWorld colours)
local GRASS_FAR, WATER, SHORE = { 104, 178, 86 }, { 96, 186, 236 }, { 240, 214, 150 }
local HILL_FAR, HILL_FAR_2 = { 88, 160, 84 }, { 120, 186, 96 }
local HILL_DARK = { 62, 138, 70 } -- (no grey-lilac cliffs: they read as stand-ins, critic 10-29)
local PETALS = { PINK, YELLOW, WHITE, CANDY_2 }

-- how far the grass runs past the walls (big units)
local APRON = 90

export type Spot = { x: number, y: number, z: number, dx: number, dz: number }

-- start spots (big units), facing +z toward the board: 8, as many as a round takes
WarmupYard.spawns = {} :: { Spot }
for i = 0, 7 do
	local row = i // 4
	table.insert(
		WarmupYard.spawns,
		{ x = -54 + (i % 4) * 36, y = 2.5, z = -52 + row * 18, dx = 0, dz = 1 }
	)
end
-- "?" box spots (big units, y = the floor's top): BoxServer.start, name WarmupBoxes
WarmupYard.boxSpots = {
	v(-70, 0, -8),
	v(0, 0, -18),
	v(70, 0, -8),
	v(-34, 0, 30),
	v(34, 0, 30),
	v(0, 0, 50),
} :: { V3 }
-- target karts (BOTS' ArenaBots.dummy; y = a kart's middle, like the spawns): three still, and one
-- circling slowly round the middle (its loop has a radius of ArenaBots' 12 RC studs = 48 big, so
-- it goes round the centre wall and clear of the side walls and the barrels)
WarmupYard.CIRCLE_R = 48
WarmupYard.DUMMIES = {
	{ at = v(-50, 2.5, 14), mode = "still" },
	{ at = v(50, 2.5, 14), mode = "still" },
	{ at = v(-20, 2.5, 34), mode = "still" },
	{ at = v(0, 2.5, 10), mode = "circle" },
} :: { { at: V3, mode: string } }
-- dressing (big units). Trees { x, z }: in the four corners inside, and a ring outside the walls.
WarmupYard.TREES = {
	{ -88, -58 },
	{ 88, -58 },
	{ -88, 58 },
	{ 88, 58 },
	{ -130, -40 },
	{ -126, 20 },
	{ -140, 70 },
	{ 130, -36 },
	{ 128, 24 },
	{ 142, 68 },
	{ -60, 104 },
	{ 10, 112 },
	{ 70, 100 },
	{ -70, -100 },
	{ 0, -112 },
	{ 64, -104 },
}
-- low cover walls { x, z, length, turn in degrees }
WarmupYard.COVER = { { -70, 36, 26, 0 }, { 70, 36, 26, 0 }, { 0, 12, 22, 90 } }
WarmupYard.CRATES = { { -86, 10 }, { 86, 10 }, { 88, -16 } }
-- barrel rows { x of the first, z, (unused), count }
WarmupYard.BARRELS = { { -40, 62, 0, 5 }, { 20, 62, 0, 5 } }
WarmupYard.BUSHES = { { -92, -30 }, { 92, -30 }, { 90, 44 }, { -118, -6 }, { 118, 4 }, { -30, 96 } }
WarmupYard.FLOWERS =
	{ { -80, -62 }, { 80, -62 }, { -52, 60 }, { 52, 60 }, { -110, 50 }, { 112, -60 } }
WarmupYard.PATCHES = { { -60, -10, 26 }, { 60, -16, 22 }, { -20, 44, 20 }, { 34, -44, 18 } }

-- the NEXT MATCH board: across the far end, facing the spawns (-z)
WarmupYard.BOARD = { at = v(0, 30, WarmupYard.D / 2 - 6), w = 120, h = 28 }

-- The yard as a track (TrackData.Track), so the driving code places karts in it like a map.
-- mode "arena": no lights, no laps (Main.client).
function WarmupYard.track(): any
	local s = WarmupYard.spawns[1]
	return {
		id = WarmupYard.id,
		label = "WARM-UP YARD",
		originX = 0,
		mode = "arena",
		grip = 1,
		spawn = { x = s.x, y = s.y, z = s.z, dx = s.dx, dz = s.dz },
		gates = {},
		rcX = WarmupYard.RC_X,
		rcZ = WarmupYard.RC_Z,
		rcAngle = WarmupYard.RC_ANGLE,
		map = WarmupYard.id,
	}
end

-- World position (RC studs) of a map-local point.
function WarmupYard.world(p: V3): V3
	local x, y, z = TrackData.toWorld(WarmupYard.track(), true, p.x, p.y, p.z)
	return v(x, y, z)
end

-- The yard's parts (Garage.Piece, map-local big units): grass floor, a sand patch in the
-- middle, low purple walls, pink corner posts and the navy board with a yellow rim.
function WarmupYard.parts(): { any }
	local out: { any } = {}
	local function add(
		group: string,
		name: string,
		size: V3,
		pos: V3,
		color: { number },
		opts: any?
	)
		local o = opts or {}
		table.insert(out, {
			group = group,
			name = name,
			shape = o.shape or "Block",
			size = size,
			pos = pos,
			rot = o.rot or v(0, 0, 0),
			color = color,
			material = o.material or "SmoothPlastic",
			collide = if o.collide == nil then true else o.collide,
		})
	end
	local W, D, H, T = WarmupYard.W, WarmupYard.D, WarmupYard.WALL_H, WarmupYard.WALL_T
	-- the grass runs well past the walls (trees out there), so the yard never sits on the void
	add("Ground", "Floor", v(W + 2 * APRON, 4, D + 2 * APRON), v(0, -2, 0), GRASS)
	add("Ground", "Sand", v(110, 0.4, 64), v(0, 0.2, 10), SAND, { collide = false })
	for _, sx in { -1, 1 } do
		add("Walls", "Side", v(T, H, D + 2 * T), v(sx * (W / 2 + T / 2), H / 2, 0), PURPLE)
	end
	for _, sz in { -1, 1 } do
		add("Walls", "End", v(W, H, T), v(0, H / 2, sz * (D / 2 + T / 2)), PURPLE)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			add(
				"Walls",
				"Post",
				v(T + 3, H + 6, T + 3),
				v(sx * (W / 2 + T / 2), (H + 6) / 2, sz * (D / 2 + T / 2)),
				PINK
			)
		end
	end
	local b = WarmupYard.BOARD
	add("Board", "Rim", v(b.w + 4, b.h + 4, 2), v(b.at.x, b.at.y, b.at.z + 1.2), YELLOW)
	add("Board", "Face", v(b.w, b.h, 2), v(b.at.x, b.at.y, b.at.z), NAVY)
	local legH = b.at.y - b.h / 2
	for _, sx in { -1, 1 } do
		add("Board", "Leg", v(4, legH, 4), v(sx * (b.w / 2 - 10), legH / 2, b.at.z + 1.2), NAVY)
	end

	-- ===== dressing, the arena's look (ArenaBuilder): lollipop trees, orange cover walls, red
	-- barrels, crates, bushes, flowers, grass patches. Nothing on a spawn, box or dummy spot. =====
	local function tree(x: number, z: number, i: number)
		local h, r = 26, 10
		add("Trees", "TreeStick", v(h, 2.4, 2.4), v(x, h / 2, z), STICK, {
			shape = "Cylinder",
			rot = v(0, 0, 90),
		})
		local spin = i * 40
		add("Trees", "TreeTop", v(r * 1.5, r * 1.5, r * 1.5), v(x, h + r * 0.6, z), CANDY, {
			rot = v(34, spin, 34),
			collide = false,
		})
		add("Trees", "TreeTop", v(r * 1.3, r * 1.3, r * 1.3), v(x, h + r * 0.6, z), CANDY_2, {
			rot = v(-23, spin + 46, 52),
			collide = false,
		})
	end
	for i, t in WarmupYard.TREES do
		tree(t[1], t[2], i)
	end
	for i, c in WarmupYard.COVER do
		-- low orange cover walls, end on to the spawns
		add("Cover", "Cover", v(c[3], 6, 4), v(c[1], 3, c[2]), ORANGE, { rot = v(0, c[4], 0) })
		add("Cover", "CoverCap", v(c[3] + 0.6, 0.8, 4.6), v(c[1], 6.4, c[2]), YELLOW, {
			rot = v(0, c[4], 0),
			collide = false,
		})
		local _ = i
	end
	for i, c in WarmupYard.CRATES do
		local sz = 8
		add(
			"Props",
			"Crate",
			v(sz, sz, sz),
			v(c[1], sz / 2, c[2]),
			CRATE,
			{ rot = v(0, i * 25, 0) }
		)
		add("Props", "CrateBand", v(sz + 0.2, sz + 0.2, 1.8), v(c[1], sz / 2, c[2]), CRATE_BAND, {
			rot = v(0, i * 25, 0),
			collide = false,
		})
		add("Props", "CrateBand", v(1.8, sz + 0.2, sz + 0.2), v(c[1], sz / 2, c[2]), CRATE_BAND, {
			rot = v(0, i * 25, 0),
			collide = false,
		})
	end
	-- a row of red and white barrels along the back wall's corners
	for _, row in WarmupYard.BARRELS do
		for k = 0, row[4] - 1 do
			local x = row[1] + k * 5
			add("Props", "Barrel", v(4.5, 4.4, 4.4), v(x, 2.25, row[2]), RED, {
				shape = "Cylinder",
				rot = v(0, 0, 90),
			})
			add("Props", "BarrelBand", v(0.8, 4.6, 4.6), v(x, 2.25, row[2]), WHITE, {
				shape = "Cylinder",
				rot = v(0, 0, 90),
				collide = false,
			})
		end
	end
	-- looks only (karts drive through): bushes, flower clumps, two shades of grass patch
	for i, b in WarmupYard.BUSHES do
		add("Decor", "Bush", v(8, 7, 8), v(b[1], 2.6, b[2]), BUSH, {
			rot = v(14, i * 50, 11),
			collide = false,
		})
		add("Decor", "Bush", v(6, 5.5, 6), v(b[1] + 3, 2.4, b[2] - 2), BUSH_2, {
			rot = v(-17, i * 50 + 40, 20),
			collide = false,
		})
	end
	for i, f in WarmupYard.FLOWERS do
		for k = 0, 4 do
			local a = k * 1.3 + i
			local d = 1.2 + k * 0.5
			add(
				"Decor",
				"Flower",
				v(1.6, 1.6, 1.6),
				v(f[1] + math.cos(a) * d, 0.9, f[2] + math.sin(a) * d),
				PETALS[(k + i) % #PETALS + 1],
				{ rot = v(34, math.deg(a), 34), collide = false }
			)
		end
	end
	-- ===== the world outside, like the arena's (looks only, nothing to hit): far grass, a lake
	-- with a sandy shore past the board, a ring of green low-poly hills, and rows of
	-- trees, so no camera in the yard sees empty sky under the horizon =====
	local function hash(n: number): number -- 0..1, the same every build (no Random in tests)
		local x = math.sin(n * 12.9898 + 78.233) * 43758.5453
		return x - math.floor(x)
	end
	local edgeZ = D / 2 + APRON -- where the yard's own grass ends
	add("World", "FarGrass", v(1600, 2, 1600), v(0, -1.4, 0), GRASS_FAR, { collide = false })
	add("World", "Shore", v(1200, 0.4, 80), v(0, -0.2, edgeZ + 60), SHORE, { collide = false })
	add("World", "Lake", v(1200, 0.4, 200), v(0, -0.15, edgeZ + 200), WATER, { collide = false })
	for k = 0, 13 do
		local ang = k / 14 * math.pi * 2 + (hash(k) - 0.5) * 0.3
		local r = 290 + hash(k + 20) * 110 -- close in, so the yard doesn't sit on an empty plain
		local x, z = math.cos(ang) * r, math.sin(ang) * r
		local size = 100 + hash(k + 40) * 80
		if z > edgeZ and z < edgeZ + 300 + size * 0.8 then
			z = edgeZ + 300 + size * 0.8 -- behind the lake, not in it
		end
		local tall = x > 200
		add(
			"World",
			"FarHill",
			v(size, size * (if tall then 0.8 else 0.55), size),
			v(x, -size * 0.18, z),
			if tall then HILL_DARK else HILL_FAR,
			{
				rot = v((hash(k + 60) - 0.5) * 28, math.deg(ang), (hash(k + 80) - 0.5) * 28),
				collide = false,
			}
		)
		add(
			"World",
			"FarHill",
			v(size * 0.7, size * 0.5, size * 0.7),
			v(x + math.cos(ang) * size * 0.4, -size * 0.1, z + math.sin(ang) * size * 0.4), -- (outward)
			HILL_FAR_2,
			{ rot = v(11, math.deg(ang) + 46, -17), collide = false }
		)
	end
	-- rows of trees round the yard's grass (the shore side has its own row)
	local W2 = W / 2 + APRON
	for k = 0, 39 do
		local side = k % 4
		local along = ((k // 4) / 9 - 0.5)
		local out = 30 + hash(k + 100) * 50
		local x, z
		if side == 0 then
			x, z = along * (W + 2 * APRON + 80), -(edgeZ + out)
		elseif side == 1 then
			x, z = W2 + out, along * (D + 2 * APRON + 80)
		elseif side == 2 then
			x, z = -(W2 + out), along * (D + 2 * APRON + 80)
		else
			x, z = along * (W + 2 * APRON + 200), edgeZ + 24 -- on the shore
		end
		local h = 22 + hash(k + 120) * 12
		add("World", "FarTrunk", v(h, 4, 4), v(x, h / 2, z), STICK, {
			shape = "Cylinder",
			rot = v(0, 0, 90),
			collide = false,
		})
		local r = 11 + hash(k + 140) * 6
		add(
			"World",
			"FarTreeTop",
			v(r, r, r),
			v(x, h + r * 0.3, z),
			if k % 3 == 0 then CANDY_2 elseif k % 3 == 1 then BUSH else BUSH_2,
			{ rot = v(34, k * 52, 34), collide = false }
		)
	end
	for i, g in WarmupYard.PATCHES do
		add(
			"Decor",
			"GrassPatch",
			v(g[3], 0.12, g[3] * 0.7),
			v(g[1], 0.06, g[2]),
			if i % 2 == 0 then GRASS_DARK else GRASS_LIGHT,
			{ rot = v(0, i * 37, 0), collide = false }
		)
	end
	return out
end

-- The board's words for `left` seconds until the next round (nil = no round planned yet).
function WarmupYard.clock(left: number?): string
	if left == nil or left ~= left then
		return "WARM UP!"
	end
	if left <= 0.5 then
		return "GET READY!"
	end
	local s = math.ceil(left)
	return string.format("NEXT MATCH IN %d:%02d", s // 60, s % 60)
end

-- Only worth the trip when the round is at least this far off (else wait by the portal: a round
-- with nobody in it starts in ~5 s).
WarmupYard.MIN_WAIT = 12

-- Should this player be in the yard now? Queued, not in a round, and the next round far enough
-- off (a round going on, or one planned more than MIN_WAIT away). Pure.
function WarmupYard.wants(
	queued: boolean,
	inMatch: boolean,
	endsAt: number?,
	nextAt: number?,
	now: number
): boolean
	if not queued or inMatch then
		return false
	end
	if endsAt and endsAt > now then
		return true
	end
	return nextAt ~= nil and nextAt - now > WarmupYard.MIN_WAIT
end

-- Is a world point (RC studs) over the yard's floor? Who is warming up.
function WarmupYard.inside(p: V3): boolean
	local x, y, z = TrackData.toLocal(WarmupYard.track(), true, p.x, p.y, p.z)
	return math.abs(x) <= WarmupYard.W / 2 + WarmupYard.WALL_T
		and math.abs(z) <= WarmupYard.D / 2 + WarmupYard.WALL_T
		and y > -40
		and y < 240
end

-- Build it under `parent` (server), at RC size. The board's Face carries the clock
-- (WarmupYard.client draws on it).
function WarmupYard.build(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "WarmupYard"
	-- (StreamingEnabled: small, and the board's clock must always be there)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	Garage.makeParts(WarmupYard.parts(), model, CFrame.identity)
	model.WorldPivot = CFrame.identity
	model:ScaleTo(TrackData.RC_SCALE)
	model:PivotTo(
		CFrame.new(WarmupYard.RC_X, 0, WarmupYard.RC_Z) * CFrame.Angles(0, WarmupYard.RC_ANGLE, 0)
	)
	model.Parent = parent
	return model
end

return WarmupYard
