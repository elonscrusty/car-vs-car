--!strict
-- Car VS Car SMASH (carter 10-28, plans/smash/MASTER-PLAN.md: "Plot = your garage: show karts,
-- open crates", no training): with Features.SMASH on, your plot is a walk-in showroom. The kart
-- you play with turns slowly on the big pink turntable in the middle, your other karts wait on
-- low stands down both sides and at the back (only as many stands as you have karts: never an
-- empty one), and the crate sits on its pedestal at the back, in line with the gate. Walk up to a
-- kart: PICK THIS KART; walk up to the crate: OPEN CRATE (the crate window, with its odds); walk
-- up to the turntable: CUSTOMIZE (WINDOWS' kart window).
-- Look (review/LOOK-BIBLE.md): round discs, the palette, a two-tone sand floor, a pink carpet to
-- the hero kart; SmoothPlastic, Neon only for the glow ring, lamp bulbs and sign frame; words
-- only on the MY GARAGE sign and the bay numbers.
-- Plain numbers and Garage pieces (Lune tests load this): PlotGarageBuilder (server) builds the
-- floor, the stands and the crate; PlotShowroom.client puts the karts on and adds the prompts.
--
-- Plot-local, RC size (studs): x across the plot (±40), +z toward the road (the gate is in the
-- front wall at z 37), y up. A kart's nose is toward -z at yaw 0.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Garage = sibling("Garage")
local CarCatalog = sibling("CarCatalog")

type Piece = Garage.Piece
type V3 = Garage.V3

local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

local PlotShowroom = {}

-- the palette (LOOK RULE)
-- warm sand in two tones, like the lobby's sandy streets (LOOK-BIBLE: no near-white floors)
local FLOOR = { 236, 206, 152 }
local BAND = { 214, 184, 132 }
local NAVY = { 30, 42, 90 }
local NAVY_DARK = { 22, 30, 66 }
local SKY = { 90, 200, 250 }
local PINK = { 255, 95, 180 }
local YELLOW = { 255, 210, 63 }
local RED = { 242, 64, 74 }
local GOLD = { 255, 196, 40 }
local DOOR = { 74, 96, 156 } -- the roller doors, a lighter navy

PlotShowroom.FLOOR = { x0 = -34, x1 = 34, z0 = -50, z1 = 35, border = 1.5 }
PlotShowroom.CARPET = 5 -- the pink carpet's width, gate end to turntable
-- the turntable: a disc w across, its top at `top`; the kart on it is this much bigger
PlotShowroom.TURNTABLE = { x = 0, z = 6, w = 16, top = 2.2, car = 3.2, spin = 20, step = 6 }
-- the spotlight ring round it: chunky lamp posts this far out, the front pair either side of the
-- carpet (Lead 10-29: the kart is the hero, a raised turntable with a spotlight ring)
PlotShowroom.LAMPS = { r = 13, n = 8, h = 3, ball = 1.4 }
-- each stand: a disc w across, its top at `top`
PlotShowroom.STAND = { w = 7, top = 1, car = 1.55 }
-- each stand's painted parking box (turned with its kart): w across, l long, lines this wide
PlotShowroom.BAY = { w = 8, l = 9, line = 0.5 }
PlotShowroom.CRATE = { x = 0, z = -42, w = 10, size = 5.5 }
-- the back of the showroom: a big banner on two posts over the crate (its words go on its gate
-- side, PlotGarageBuilder) and a gold trophy on a plinth either side of the crate
PlotShowroom.BANNER = { w = 30, h = 5, y = 12 } -- (high: seen over the hero kart from the gate)
PlotShowroom.BACK_WALL = { z = -53.6, w = 66, h = 15 }
-- a roller door either side of the sign, and a yellow stripe along the wall's top
PlotShowroom.ROLLER_DOORS = { x = 23.2, w = 14, h = 10, slats = 6 }
PlotShowroom.BANNER_TEXT = "MY GARAGE"
PlotShowroom.TROPHIES = { { x = -6, z = -48 }, { x = 6, z = -48 } }
-- two little "?" crates either side of the carpet at the gate end (the mid-ground)
PlotShowroom.MINI_CRATES = { { x = -8, z = 27 }, { x = 8, z = 27 } }
-- garage dressing that fills the floor even with one kart (Lead 10-29): a tool wall down each
-- side on the grass margin, a kart lift in the right front corner, a workbench in the left one,
-- and PropKit tyre stacks and barrels (PlotGarageBuilder builds those: `PROPS`)
PlotShowroom.TOOL_WALL = { x = 37, z0 = -44, z1 = 16, h = 4.5 }
PlotShowroom.LIFT = { x = 24, z = 31 }
PlotShowroom.BENCH = { x = -24, z = 31 }
PlotShowroom.CART = { x = -14, z = 19 } -- a toolbox cart in the front middle cluster
PlotShowroom.PROPS = {
	{ kind = "tyres", x = 31, z = 28, h = 2.4 },
	{ kind = "tyres", x = -31, z = 28, h = 2.4 },
	{ kind = "tyres", x = 30, z = -47, h = 2.4 },
	{ kind = "tyres", x = -30, z = -47, h = 2.4 },
	{ kind = "barrel", x = -31.5, z = 33, h = 2.6 },
	{ kind = "barrel", x = 31.5, z = -43, h = 2.6 },
	-- the back middle, off the gate-to-crate line
	{ kind = "tyres", x = -12, z = -21, h = 2.4 },
	{ kind = "tyres", x = -14.6, z = -23, h = 1.6 },
	{ kind = "barrel", x = 11, z = -23, h = 2.6 },
	{ kind = "barrel", x = 13.6, z = -25, h = 2.6 },
	-- the front middle cluster (seen from the gate): the cart, tyres and drums either side of
	-- the carpet, between the bays and the turntable's lamps
	{ kind = "tyres", x = -15.5, z = 25, h = 2.4 },
	{ kind = "tyres", x = -18.2, z = 22.8, h = 1.6 },
	{ kind = "barrel", x = 14, z = 20, h = 2.6 },
	{ kind = "barrel", x = 16.6, z = 22.2, h = 2.6 },
	{ kind = "tyres", x = 15, z = 25.5, h = 1.6 },
} :: { { kind: string, x: number, z: number, h: number } }
-- walk-up prompts: in reach this close (studs). Stands are 12 apart, so two are never both in
-- reach (vault Lobby and Hub Design: prompt points at least twice the range apart).
PlotShowroom.PICK_RANGE = 6
PlotShowroom.CRATE_RANGE = 7
PlotShowroom.TABLE_RANGE = 8 -- the turntable's CUSTOMIZE prompt (WINDOWS' OpenCustomize)
PlotShowroom.NEAR = 220 -- studs: a plot farther from the camera than this stops turning its kart

-- The stands, in the order they fill: down both sides from the gate end (left, right), then the
-- two at the back beside the crate. Each kart faces the middle, turned a little to the gate.
export type Spot = { x: number, z: number, yaw: number }
local SPOTS: { Spot } = {}
for _, z in { 22, 10, -2, -14, -26, -38 } do
	table.insert(SPOTS, { x = -26, z = z, yaw = -121 })
	table.insert(SPOTS, { x = 26, z = z, yaw = 121 })
end
table.insert(SPOTS, { x = -13, z = -44, yaw = 180 })
table.insert(SPOTS, { x = 13, z = -44, yaw = 180 })
PlotShowroom.SPOTS = SPOTS

-- Stands to draw for this many karts (one of them on the turntable when `hasRacer`).
function PlotShowroom.standCount(karts: number, hasRacer: boolean): number
	local n = math.floor(karts) - (if hasRacer then 1 else 0)
	return math.clamp(n, 0, #SPOTS)
end

export type Entry = { id: string, uid: string? }

local function rank(id: string): number
	local r = CarCatalog.rarity(id).id
	return table.find(CarCatalog.RARITY_ORDER, r) or 0
end

-- Who goes where: the kart you play with on the turntable (`racer`: a uid on your own plot, a car
-- id on anyone else's), the rest on the stands, rarest first, as many as there are stands.
function PlotShowroom.order(cars: { Entry }, racer: string?): (Entry?, { Entry })
	local top: Entry? = nil
	local rest: { Entry } = {}
	for _, e in cars do
		if
			top == nil
			and racer ~= nil
			and racer ~= ""
			and (e.uid == racer or (e.uid == nil and e.id == racer))
		then
			top = e
		else
			table.insert(rest, e)
		end
	end
	table.sort(rest, function(a: Entry, b: Entry): boolean
		local ra, rb = rank(a.id), rank(b.id)
		if ra ~= rb then
			return ra > rb
		end
		if a.id ~= b.id then
			return a.id < b.id
		end
		return (a.uid or "") < (b.uid or "")
	end)
	while #rest > #SPOTS do
		table.remove(rest)
	end
	return top, rest
end

-- A flat round disc (a standing cylinder), w across, h tall, its top at `top` (`solid`: you can
-- stand on it; low enough to walk up)
local function disc(
	add: Garage.Add,
	group: string,
	name: string,
	x: number,
	z: number,
	w: number,
	h: number,
	top: number,
	color: { number },
	solid: boolean,
	material: string?
)
	add(group, name, v(h, w, w), v(x, top - h / 2, z), color, {
		shape = "Cylinder",
		rot = v(0, 0, 90),
		collide = solid,
		material = material,
	})
end

-- Everything in the showroom with `stands` stands (PlotShowroom.standCount).
function PlotShowroom.pieces(stands: number): { Piece }
	local out: { Piece } = {}
	local add = Garage.adder(out)
	local F = PlotShowroom.FLOOR
	local fx, fz = (F.x0 + F.x1) / 2, (F.z0 + F.z1) / 2
	local fw, fd = F.x1 - F.x0, F.z1 - F.z0
	-- a warm sand floor in two tones (wide darker bands across it) on a navy lip
	add("Floor", "Border", v(fw + 2 * F.border, 0.24, fd + 2 * F.border), v(fx, 0.12, fz), NAVY, {
		collide = false,
	})
	add("Floor", "Floor", v(fw, 0.36, fd), v(fx, 0.18, fz), FLOOR, { collide = false })
	local bands = 7
	local bw = fd / bands
	for k = 2, bands, 2 do
		add("Floor", "FloorBand", v(fw, 0.38, bw), v(fx, 0.19, F.z0 + (k - 0.5) * bw), BAND, {
			collide = false,
		})
	end
	-- a darker edge band all round the floor's rim
	local E = 1.5
	for _, sz in { -1, 1 } do
		add("Floor", "FloorEdge", v(fw, 0.4, E), v(fx, 0.2, fz + sz * (fd - E) / 2), BAND, {
			collide = false,
		})
	end
	for _, sx in { -1, 1 } do
		add("Floor", "FloorEdge", v(E, 0.4, fd - 2 * E), v(fx + sx * (fw - E) / 2, 0.2, fz), BAND, {
			collide = false,
		})
	end
	-- the hero: a pink carpet from the gate end to the turntable, yellow edges
	local T = PlotShowroom.TURNTABLE
	local c0, c1 = T.z + (T.w + T.step) / 2, F.z1
	local C = PlotShowroom.CARPET
	add(
		"Floor",
		"Carpet",
		v(C, 0.42, c1 - c0),
		v(T.x, 0.21, (c0 + c1) / 2),
		PINK,
		{ collide = false }
	)
	for _, sx in { -1, 1 } do
		add(
			"Floor",
			"CarpetEdge",
			v(0.6, 0.44, c1 - c0),
			v(T.x + sx * (C / 2 + 0.3), 0.22, (c0 + c1) / 2),
			YELLOW,
			{ collide = false }
		)
	end
	-- the turntable, raised on a wide step: navy step and skirt, a pink glow ring, pink deck,
	-- yellow top
	disc(add, "Turntable", "TableBay", T.x, T.z, T.w + T.step + 2, 0.06, 0.41, YELLOW, false)
	disc(add, "Turntable", "TableStep", T.x, T.z, T.w + T.step, 0.8, 0.8, NAVY_DARK, true)
	disc(add, "Turntable", "TableSkirt", T.x, T.z, T.w + 2, 0.6, 1.4, NAVY, true)
	disc(add, "Turntable", "TableGlow", T.x, T.z, T.w + 1.2, 0.2, 1.6, PINK, false, "Neon")
	disc(add, "Turntable", "TableDeck", T.x, T.z, T.w, 0.6, T.top - 0.2, PINK, true)
	disc(add, "Turntable", "TableTop", T.x, T.z, T.w - 1.6, 0.2, T.top, YELLOW, false)
	-- the spotlight ring: chunky navy lamp posts with glowing yellow bulbs
	local L = PlotShowroom.LAMPS
	for k = 0, L.n - 1 do
		local a = math.rad((k + 0.5) * 360 / L.n)
		local x, z = T.x + L.r * math.sin(a), T.z + L.r * math.cos(a)
		disc(add, "Lamps", "LampPost", x, z, 0.9, L.h, L.h, NAVY, false)
		-- (not Neon: it bloomed into blobs up close; PlotGarageBuilder gives each a soft light)
		add("Lamps", "LampBulb", v(L.ball, L.ball, L.ball), v(x, L.h + L.ball * 0.4, z), YELLOW, {
			shape = "Ball",
			collide = false,
		})
	end
	-- the stands, each in a painted yellow bay (every bay is painted, the empty ones too: room
	-- for more karts)
	local S = PlotShowroom.STAND
	local BA = PlotShowroom.BAY
	for i, p in SPOTS do
		-- a parking box turned with the kart: two long lines, two short ones, and the bay's
		-- number on a navy tile in front of its nose (PlotGarageBuilder writes the number)
		local yaw = math.rad(p.yaw)
		local function at(lx: number, lz: number): (number, number)
			return p.x + lx * math.cos(yaw) + lz * math.sin(yaw),
				p.z - lx * math.sin(yaw) + lz * math.cos(yaw)
		end
		local turn = v(0, p.yaw, 0)
		for _, sx in { -1, 1 } do
			local x, z = at(sx * BA.w / 2, 0)
			add(
				"Bays",
				"BayLine",
				v(BA.line, 0.06, BA.l),
				v(x, 0.41, z),
				YELLOW,
				{ rot = turn, collide = false }
			)
			x, z = at(0, sx * BA.l / 2)
			add("Bays", "BayLine", v(BA.w + BA.line, 0.06, BA.line), v(x, 0.41, z), YELLOW, {
				rot = turn,
				collide = false,
			})
		end
		local nx, nz = at(0, -BA.l / 2 - 1.5)
		add(
			"Bays",
			"BayNumber" .. i,
			v(2.4, 0.08, 2.4),
			v(nx, 0.42, nz),
			NAVY,
			-- turned a quarter: a Top-face SurfaceGui's up is the part's -X (Studio), so the
			-- number's top points into the bay and it reads upright from the aisle
			{ rot = v(0, p.yaw + 90, 0), collide = false }
		)
	end
	for i = 1, math.clamp(stands, 0, #SPOTS) do
		local p = SPOTS[i]
		local group = "Stand" .. i
		disc(add, group, "StandBase", p.x, p.z, S.w, S.top - 0.2, S.top - 0.2, NAVY, true)
		disc(add, group, "StandTop", p.x, p.z, S.w - 0.8, 0.2, S.top, SKY, false)
	end
	-- the crate on its round pedestal: yellow, two navy bands, round navy corners, a red lid
	local K = PlotShowroom.CRATE
	local cs = K.size
	disc(add, "Crate", "CratePedestal", K.x, K.z, K.w, 1, 1, NAVY, true)
	add("Crate", "CrateBody", v(cs, cs * 0.8, cs), v(K.x, 1 + cs * 0.4, K.z), YELLOW, {
		collide = true,
	})
	for _, y in { 0.3, 0.6 } do
		add("Crate", "CrateBand", v(cs + 0.2, 0.5, cs + 0.2), v(K.x, 1 + cs * 0.8 * y, K.z), NAVY, {
			collide = false,
		})
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			add(
				"Crate",
				"CrateCorner",
				v(cs * 0.8, 0.9, 0.9),
				v(K.x + sx * cs / 2, 1 + cs * 0.4, K.z + sz * cs / 2),
				NAVY,
				{ shape = "Cylinder", rot = v(0, 0, 90), collide = false }
			)
		end
	end
	add("Crate", "CrateLid", v(cs + 0.6, 0.8, cs + 0.6), v(K.x, 1 + cs * 0.8 + 0.4, K.z), RED, {
		collide = false,
	})
	-- the back wall: a tall dark wall across the back with a pink rail, and the neon sign on it
	-- (carter's kit Plot.png: a dark wall with a glowing MY GARAGE sign)
	local B = PlotShowroom.BANNER
	local BW = PlotShowroom.BACK_WALL
	add("Banner", "BackWall", v(BW.w, BW.h, 1.2), v(0, BW.h / 2, BW.z), NAVY_DARK)
	add("Banner", "BackWallRail", v(BW.w + 1, 1, 1), v(0, BW.h + 0.4, BW.z), PINK, {
		shape = "Cylinder",
		collide = false,
	})
	local face = BW.z + 0.6
	-- panels: roller doors with navy slats, posts at the ends, a yellow stripe up top
	local RD = PlotShowroom.ROLLER_DOORS
	for _, sx in { -1, 1 } do
		local dx = sx * RD.x
		add("Banner", "RollerDoor", v(RD.w, RD.h, 0.3), v(dx, RD.h / 2, face + 0.15), DOOR, {
			collide = false,
		})
		for k = 1, RD.slats do
			local y = RD.h * k / (RD.slats + 1)
			add("Banner", "DoorSlat", v(RD.w, 0.25, 0.2), v(dx, y, face + 0.4), NAVY, {
				collide = false,
			})
		end
		add(
			"Banner",
			"DoorHeader",
			v(RD.w + 1.2, 0.9, 0.6),
			v(dx, RD.h + 0.45, face + 0.3),
			YELLOW,
			{
				collide = false,
			}
		)
		add(
			"Banner",
			"WallPost",
			v(1.4, BW.h, 0.6),
			v(sx * (BW.w / 2 - 0.7), BW.h / 2, face + 0.3),
			NAVY,
			{
				collide = false,
			}
		)
		add(
			"Banner",
			"WallStripe",
			v(BW.w / 2 - B.w / 2 - 2.4, 0.7, 0.3),
			v(sx * (BW.w / 4 + B.w / 4 - 0.5), BW.h - 1.6, face + 0.15),
			YELLOW,
			{
				collide = false,
			}
		)
	end
	add("Banner", "BannerBoard", v(B.w, B.h, 0.4), v(0, B.y, face + 0.2), NAVY, { collide = false })
	for _, sy in { -1, 1 } do
		add(
			"Banner",
			"SignGlow",
			v(B.w + 1, 0.5, 0.5),
			v(0, B.y + sy * (B.h / 2 + 0.25), face + 0.3),
			PINK,
			{
				material = "Neon",
				collide = false,
			}
		)
	end
	for _, sx in { -1, 1 } do
		add(
			"Banner",
			"SignGlow",
			v(0.5, B.h, 0.5),
			v(sx * (B.w / 2 + 0.25), B.y, face + 0.3),
			PINK,
			{
				material = "Neon",
				collide = false,
			}
		)
	end
	-- gold trophies on navy plinths
	for i, t in PlotShowroom.TROPHIES do
		local g = "Trophy" .. i
		disc(add, g, "TrophyPlinth", t.x, t.z, 4.4, 2, 2, NAVY, true)
		disc(add, g, "TrophyBase", t.x, t.z, 3, 0.8, 2.8, GOLD, false)
		disc(add, g, "TrophyStem", t.x, t.z, 1.2, 1.8, 4.6, GOLD, false)
		add(g, "TrophyCup", v(4, 4, 4), v(t.x, 6.4, t.z), GOLD, { shape = "Ball", collide = false })
		for _, sx in { -1, 1 } do
			add(g, "TrophyHandle", v(1.3, 1.3, 1.3), v(t.x + sx * 2.2, 6.8, t.z), GOLD, {
				shape = "Ball",
				collide = false,
			})
		end
	end
	-- the tool walls: navy, a pink rail, sky pegboards with chunky tools on them
	local TW = PlotShowroom.TOOL_WALL
	local len = TW.z1 - TW.z0
	local mid = (TW.z0 + TW.z1) / 2
	local TOOLS = { RED, YELLOW, PINK }
	for _, sx in { -1, 1 } do
		local x = sx * TW.x
		add("ToolWall", "ToolWall", v(1.2, TW.h, len), v(x, TW.h / 2, mid), NAVY)
		add("ToolWall", "ToolWallRail", v(len + 1, 1, 1), v(x, TW.h + 0.3, mid), PINK, {
			shape = "Cylinder",
			rot = v(0, 90, 0),
			collide = false,
		})
		for k = 0, 2 do
			local pz = TW.z0 + (k + 0.5) * len / 3
			local face = x - sx * 0.7
			add(
				"ToolWall",
				"Pegboard",
				v(0.3, 2.6, len / 3 - 2),
				v(face, 2.5, pz),
				SKY,
				{ collide = false }
			)
			for t = -1, 1 do
				local c = TOOLS[(k + t + 1) % 3 + 1]
				local tz = pz + t * 4.5
				add("ToolWall", "Tool", v(2, 0.55, 0.55), v(face - sx * 0.3, 2.3, tz), c, {
					shape = "Cylinder",
					rot = v(0, 0, 90),
					collide = false,
				})
				add("ToolWall", "ToolHead", v(1, 1, 1), v(face - sx * 0.3, 3.4, tz), c, {
					shape = "Ball",
					collide = false,
				})
			end
		end
	end
	-- the kart lift: navy base, two yellow posts, a navy top beam, red arms
	local LI = PlotShowroom.LIFT
	add("Lift", "LiftBase", v(9, 0.5, 5), v(LI.x, 0.25, LI.z), NAVY_DARK)
	for _, sx in { -1, 1 } do
		disc(add, "Lift", "LiftPost", LI.x + sx * 4, LI.z - 1.8, 1.2, 5.5, 5.5, YELLOW, true)
		add(
			"Lift",
			"LiftArm",
			v(1.2, 0.5, 4),
			v(LI.x + sx * 3.2, 2.2, LI.z + 0.2), -- (from the post, swung out toward the gate)
			RED,
			{ collide = false }
		)
	end
	add("Lift", "LiftBeam", v(9.2, 0.9, 0.9), v(LI.x, 5.7, LI.z - 1.8), NAVY, {
		shape = "Cylinder",
		collide = false,
	})
	-- the workbench: a navy cabinet, a red top, yellow drawer fronts, a toolbox on top
	local BE = PlotShowroom.BENCH
	add("Bench", "BenchCabinet", v(8, 2.4, 2.6), v(BE.x, 1.2, BE.z), NAVY)
	add("Bench", "BenchTop", v(8.4, 0.5, 3), v(BE.x, 2.65, BE.z), RED, { collide = false })
	for _, dx in { -2.5, 0, 2.5 } do
		add("Bench", "BenchDrawer", v(2, 0.7, 0.2), v(BE.x + dx, 1.6, BE.z + 1.35), YELLOW, {
			collide = false,
		})
	end
	add("Bench", "Toolbox", v(2.4, 1.3, 1.3), v(BE.x - 1.8, 3.55, BE.z), RED, { collide = false })
	add(
		"Bench",
		"ToolboxLid",
		v(2.5, 0.35, 1.4),
		v(BE.x - 1.8, 4.35, BE.z),
		YELLOW,
		{ collide = false }
	)
	-- the toolbox cart: a red box of drawers on a navy base with four round wheels
	local CA = PlotShowroom.CART
	add("Cart", "CartBase", v(3.4, 0.5, 2.2), v(CA.x, 0.75, CA.z), NAVY)
	add("Cart", "CartBox", v(3, 2.6, 2), v(CA.x, 2.3, CA.z), RED)
	for _, y in { 1.6, 2.4, 3.2 } do
		add(
			"Cart",
			"CartDrawer",
			v(2.4, 0.4, 0.15),
			v(CA.x, y, CA.z + 1.05),
			YELLOW,
			{ collide = false }
		)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			add(
				"Cart",
				"CartWheel",
				v(0.8, 0.8, 0.8),
				v(CA.x + sx * 1.3, 0.4, CA.z + sz * 0.8),
				NAVY_DARK,
				{
					shape = "Ball",
					collide = false,
				}
			)
		end
	end
	-- the little "?" crates: yellow, a red lid, navy corner bands
	for i, m in PlotShowroom.MINI_CRATES do
		local g = "MiniCrate" .. i
		add(
			g,
			"MiniCrateBody",
			v(2.6, 2.2, 2.6),
			v(m.x, 1.1, m.z),
			YELLOW,
			{ rot = v(0, 20 * (2 * i - 3), 0) }
		)
		add(g, "MiniCrateLid", v(2.9, 0.5, 2.9), v(m.x, 2.45, m.z), RED, {
			rot = v(0, 20 * (2 * i - 3), 0),
			collide = false,
		})
		add(g, "MiniCrateBand", v(2.75, 0.4, 2.75), v(m.x, 0.9, m.z), NAVY, {
			rot = v(0, 20 * (2 * i - 3), 0),
			collide = false,
		})
	end
	return out
end

-- The prompt's spot over a stand / the turntable / the crate (chest high), plot-local.
function PlotShowroom.standPrompt(i: number): V3
	local p = SPOTS[i]
	return v(p.x, PlotShowroom.STAND.top + 2.5, p.z)
end
function PlotShowroom.turntablePrompt(): V3
	local T = PlotShowroom.TURNTABLE
	return v(T.x, T.top + 3, T.z + T.w / 2)
end
function PlotShowroom.cratePrompt(): V3
	local C = PlotShowroom.CRATE
	return v(C.x, 1 + C.size * 0.8 + 1, C.z + C.size / 2)
end

return PlotShowroom
