--!strict
-- Car VS Car SMASH (carter 10-28, plans/smash/MASTER-PLAN.md: "Plot = your garage: show karts,
-- open crates", no training): with Features.SMASH on, your plot is a walk-in showroom. The kart
-- you play with turns slowly on the big pink turntable in the middle, your other karts wait on
-- low stands down both sides and at the back (only as many stands as you have karts: never an
-- empty one), and the crate sits on its pedestal at the back, in line with the gate. Walk up to a
-- kart: PICK THIS KART; walk up to the crate: OPEN CRATE (the crate window, with its odds); walk
-- up to the turntable: CUSTOMIZE (WINDOWS' kart window).
-- Look (review/LOOK-BIBLE.md): round discs, the palette, a two-tone sand floor, a pink carpet to
-- the hero kart; SmoothPlastic, Neon only for the turntable's glow ring, no words on
-- the models.
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

PlotShowroom.FLOOR = { x0 = -34, x1 = 34, z0 = -50, z1 = 32, border = 1.5 }
PlotShowroom.CARPET = 5 -- the pink carpet's width, gate end to turntable
-- the turntable: a disc w across, its top at `top`; the kart on it is this much bigger
PlotShowroom.TURNTABLE = { x = 0, z = 6, w = 16, top = 2.2, car = 3.2, spin = 20, step = 6 }
-- the spotlight ring round it: chunky lamp posts this far out, the front pair either side of the
-- carpet (Lead 10-29: the kart is the hero, a raised turntable with a spotlight ring)
PlotShowroom.LAMPS = { r = 13, n = 8, h = 3, ball = 1.4 }
-- each stand: a disc w across, its top at `top`
PlotShowroom.STAND = { w = 7, top = 1, car = 1.55 }
PlotShowroom.CRATE = { x = 0, z = -42, w = 10, size = 5.5 }
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
		add("Lamps", "LampBulb", v(L.ball, L.ball, L.ball), v(x, L.h + L.ball * 0.4, z), YELLOW, {
			shape = "Ball",
			material = "Neon",
			collide = false,
		})
	end
	-- the stands
	local S = PlotShowroom.STAND
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
