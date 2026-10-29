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

-- LOOK-BIBLE palette (review/LOOK-BIBLE.md): grass green, sunny yellow, cherry red, hot pink,
-- purple, dark navy, sand; each big area with a second, darker tone
local GRASS, GRASS_DARK, GRASS_LIGHT = { 91, 209, 91 }, { 76, 190, 80 }, { 120, 222, 104 }
local SAND = { 242, 217, 166 }
local PURPLE, PURPLE_TOP = { 142, 68, 255 }, { 176, 128, 255 }
local PINK = { 255, 95, 180 }
local NAVY = { 30, 42, 90 }
local YELLOW = { 255, 210, 63 }
local ORANGE = { 255, 140, 40 }
local CRATE, CRATE_BAND = { 255, 196, 60 }, { 230, 120, 30 }
local RED, WHITE = { 242, 64, 74 }, { 250, 250, 250 }
-- the world outside
local GRASS_FAR, WATER, SHORE = { 70, 182, 78 }, { 90, 200, 250 }, { 242, 217, 166 }
-- the valley's hills by row: green near, deeper green, then pink and purple far away
WarmupYard.HILL_TONES = {
	{ { 91, 209, 91 }, { 76, 190, 80 } },
	{ { 62, 172, 86 }, { 52, 156, 92 } },
	{ { 255, 150, 206 }, { 176, 128, 255 } },
}

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
	-- mowed stripes (LOOK-BIBLE rule 5: a second tone on the big floor)
	for k = -4, 4 do
		if k % 2 == 0 then
			add("Ground", "Stripe", v(20, 0.1, D + 2 * APRON), v(k * 20, 0.05, 0), GRASS_DARK, {
				collide = false,
			})
		end
	end
	for _, sx in { -1, 1 } do
		add("Walls", "Side", v(T, H, D + 2 * T), v(sx * (W / 2 + T / 2), H / 2, 0), PURPLE)
	end
	for _, sz in { -1, 1 } do
		add("Walls", "End", v(W, H, T), v(0, H / 2, sz * (D / 2 + T / 2)), PURPLE)
	end
	-- round, lighter tops on the walls (rule 1: rounded, never razor-sharp)
	for _, sx in { -1, 1 } do
		add(
			"Walls",
			"Top",
			v(D + 2 * T, T + 0.6, T + 0.6),
			v(sx * (W / 2 + T / 2), H, 0),
			PURPLE_TOP,
			{
				shape = "Cylinder",
				rot = v(0, 90, 0),
				collide = false,
			}
		)
	end
	for _, sz in { -1, 1 } do
		add("Walls", "Top", v(W, T + 0.6, T + 0.6), v(0, H, sz * (D / 2 + T / 2)), PURPLE_TOP, {
			shape = "Cylinder",
			collide = false,
		})
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			add(
				"Walls",
				"Post",
				v(H + 6, T + 3, T + 3),
				v(sx * (W / 2 + T / 2), (H + 6) / 2, sz * (D / 2 + T / 2)),
				PINK,
				{ shape = "Cylinder", rot = v(0, 0, 90) }
			)
			add(
				"Walls",
				"PostCap",
				v(T + 4, T + 4, T + 4),
				v(sx * (W / 2 + T / 2), H + 6, sz * (D / 2 + T / 2)),
				YELLOW,
				{ shape = "Ball", collide = false }
			)
		end
	end
	local b = WarmupYard.BOARD
	add("Board", "Rim", v(b.w + 2, b.h + 2, 2), v(b.at.x, b.at.y, b.at.z + 1.2), YELLOW)
	add("Board", "Face", v(b.w, b.h, 2), v(b.at.x, b.at.y, b.at.z), NAVY)
	-- fat round yellow edges (rule 1)
	for _, sy in { -1, 1 } do
		add(
			"Board",
			"Edge",
			v(b.w + 6, 4, 4),
			v(b.at.x, b.at.y + sy * (b.h / 2 + 1), b.at.z + 1.2),
			YELLOW,
			{
				shape = "Cylinder",
			}
		)
	end
	for _, sx in { -1, 1 } do
		add(
			"Board",
			"Edge",
			v(b.h + 2, 4, 4),
			v(b.at.x + sx * (b.w / 2 + 1), b.at.y, b.at.z + 1.2),
			YELLOW,
			{
				shape = "Cylinder",
				rot = v(0, 0, 90),
			}
		)
	end
	local legH = b.at.y - b.h / 2
	for _, sx in { -1, 1 } do
		add(
			"Board",
			"Leg",
			v(legH, 4.4, 4.4),
			v(sx * (b.w / 2 - 10), legH / 2, b.at.z + 1.2),
			NAVY,
			{
				shape = "Cylinder",
				rot = v(0, 0, 90),
			}
		)
	end

	-- ===== dressing, the arena's look: orange cover walls with round ends, red barrels, crates,
	-- grass patches. Trees and bushes are ARENA's PropKit ones (build()). Nothing on a spawn,
	-- box or dummy spot. =====
	for i, c in WarmupYard.COVER do
		-- low orange cover walls, end on to the spawns, round at both ends (rule 1)
		add("Cover", "Cover", v(c[3], 6, 4), v(c[1], 3, c[2]), ORANGE, { rot = v(0, c[4], 0) })
		local a = math.rad(c[4])
		for _, e in { -1, 1 } do
			local ex, ez = c[1] + e * math.cos(a) * c[3] / 2, c[2] - e * math.sin(a) * c[3] / 2
			add("Cover", "CoverEnd", v(6.8, 4.6, 4.6), v(ex, 3.4, ez), YELLOW, {
				shape = "Cylinder",
				rot = v(0, 0, 90),
				collide = false,
			})
		end
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
	-- ===== the ground outside: grass to the valley's hills, a lake with a sandy shore past the
	-- board. The hills round it (a valley, so the yard sits in a real place, not on a plate) and
	-- their trees are WarmupYard.valley(), built in build(). =====
	local edgeZ = D / 2 + APRON -- where the yard's own grass ends
	add("World", "FarGrass", v(1300, 2, 1200), v(0, -1.4, 0), GRASS_FAR, { collide = false })
	add("World", "Shore", v(560, 0.4, 50), v(0, -0.2, edgeZ + 45), SHORE, { collide = false })
	add("World", "Lake", v(560, 0.4, 150), v(0, -0.15, edgeZ + 145), WATER, { collide = false })
	-- looks only (karts drive through): two shades of grass patch (bushes: PropKit, build())
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

-- The valley round the yard (big units, looks only): three rows of round hills hugging the
-- yard's grass on every side but the lake's (there they stand behind the water), and PropKit
-- trees on the near ones, so the yard sits in a place, not on a plate (audit looks round 1).
export type Dome = {
	x: number,
	z: number,
	w: number,
	h: number,
	d: number,
	turn: number,
	row: number,
	color: { number },
}
export type TreeSpot = { x: number, z: number, h: number, style: string, seed: number }
WarmupYard.VALLEY_ROWS = {
	{ out = 40, step = 60, w = 80, h = 34, d = 70 },
	{ out = 110, step = 90, w = 120, h = 62, d = 100 },
	{ out = 210, step = 140, w = 190, h = 110, d = 150 },
}
function WarmupYard.valley(): ({ Dome }, { TreeSpot })
	local function hash(n: number): number -- 0..1, the same every build
		local x = math.sin(n * 12.9898 + 78.233) * 43758.5453
		return x - math.floor(x)
	end
	local hx, hz = WarmupYard.W / 2 + APRON, WarmupYard.D / 2 + APRON -- the yard's grass edge
	local lakeEnd = hz + 195 -- the lake's far shore (parts(): Lake)
	local domes: { Dome } = {}
	local trees: { TreeSpot } = {}
	local n = 0
	for row, rw in WarmupYard.VALLEY_ROWS do
		-- walk round a rounded box (a superellipse) just outside the grass
		local ax, az = (hx + rw.out) / 0.84, (hz + rw.out) / 0.84
		local perim = 2 * math.pi * math.sqrt((ax * ax + az * az) / 2)
		local count = math.floor(perim / rw.step)
		for k = 0, count - 1 do
			n += 1
			local t = (k + hash(n) * 0.4) / count * 2 * math.pi
			local c, sn = math.cos(t), math.sin(t)
			local x = ax * (if c < 0 then -1 else 1) * math.sqrt(math.abs(c))
			local z = az * (if sn < 0 then -1 else 1) * math.sqrt(math.abs(sn))
			local w = rw.w * (0.8 + hash(n + 50) * 0.4)
			local d = rw.d * (0.8 + hash(n + 130) * 0.4)
			if z > hz - 10 and math.abs(x) < 300 then
				if row == 1 then
					continue -- the lake side stays open
				end
				z = math.max(z, lakeEnd + d / 2 + 5) -- behind the water, not in it
			end
			local tones = WarmupYard.HILL_TONES[row]
			table.insert(domes, {
				x = x,
				z = z,
				w = w,
				h = rw.h * (0.8 + hash(n + 90) * 0.4),
				d = d,
				turn = math.deg(t) + 90,
				row = row,
				color = tones[k % 2 + 1],
			})
			if row == 1 and k % 2 == 0 then
				-- at the hill's foot on the yard side, on the grass (not buried in the hill)
				local fx, fz = (hx + 6) / 0.84, (hz + 6) / 0.84
				table.insert(trees, {
					x = fx * (if c < 0 then -1 else 1) * math.sqrt(math.abs(c)),
					z = fz * (if sn < 0 then -1 else 1) * math.sqrt(math.abs(sn)),
					h = 26 + hash(n + 170) * 10,
					style = if k % 6 == 0 then "pink" elseif k % 6 == 2 then "yellow" else "green",
					seed = 400 + n,
				})
			end
		end
	end
	return domes, trees
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
	-- the valley's round hills: an ellipsoid each (a Part with a sphere mesh), half sunk
	local valley = Instance.new("Folder")
	valley.Name = "Valley"
	local domes, spots = WarmupYard.valley()
	for _, d in domes do
		local p = Instance.new("Part")
		p.Name = "Hill"
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.Size = Vector3.new(d.w, d.h * 2, d.d)
		p.CFrame = CFrame.new(d.x, -1, d.z) * CFrame.Angles(0, math.rad(d.turn), 0)
		p.Color = Color3.fromRGB(d.color[1], d.color[2], d.color[3])
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
		p.Parent = valley
	end
	valley.Parent = model
	-- ARENA's PropKit: round trees inside the yard and on the near hills, bushes (looks only)
	local m = script and (script :: any).Parent:FindFirstChild("PropKit")
	local ok, kit = pcall(function()
		return require(m)
	end)
	if ok and type(kit) == "table" then
		local dress = Instance.new("Folder")
		dress.Name = "Dressing"
		for i, t in WarmupYard.TREES do
			pcall(
				kit.tree,
				dress,
				Vector3.new(t[1], 0, t[2]),
				28,
				if i % 3 == 0 then "pink" else "green",
				i,
				true
			)
		end
		for _, t in spots do
			pcall(kit.tree, dress, Vector3.new(t.x, 0, t.z), t.h, t.style, t.seed, false)
		end
		for i, b in WarmupYard.BUSHES do
			pcall(kit.bush, dress, Vector3.new(b[1], 0, b[2]), 7, 60 + i, false)
		end
		dress.Parent = model
	end
	model.WorldPivot = CFrame.identity
	model:ScaleTo(TrackData.RC_SCALE)
	model:PivotTo(
		CFrame.new(WarmupYard.RC_X, 0, WarmupYard.RC_Z) * CFrame.Angles(0, WarmupYard.RC_ANGLE, 0)
	)
	model.Parent = parent
	return model
end

return WarmupYard
