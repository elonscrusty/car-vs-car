--!strict
-- Car VS Car SMASH (carter 10-28, plans/smash/MASTER-PLAN.md: "Plot = your garage: show karts,
-- open crates", no training): with Features.SMASH on, your plot is a walk-in showroom. The kart
-- you play with turns slowly on the big pink turntable in the middle, your other karts wait on
-- low stands down both sides and at the back (only as many stands as you have karts: never an
-- empty one), and the crate sits on its pedestal at the back, in line with the gate. Walk up to a
-- kart: PICK THIS KART; walk up to the crate: OPEN CRATE (the crate window, with its odds); walk
-- up to the turntable: CUSTOMIZE (WINDOWS' kart window).
-- Low-poly look (FINISH-JOBS LOOK RULE): flat octagons, SmoothPlastic only, no Neon, no words on
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
-- warm grey paving, like the lobby's sandy streets (Lead 10-29: the near-white read as snow)
local FLOOR = { 206, 190, 166 }
local NAVY = { 35, 45, 80 }
local SKY = { 90, 180, 255 }
local PINK = { 255, 90, 170 }
local WHITE = { 245, 245, 250 }
local YELLOW = { 255, 205, 50 }
local RED = { 230, 50, 60 }

PlotShowroom.FLOOR = { x0 = -34, x1 = 34, z0 = -50, z1 = 32, border = 1 }
-- the turntable: an octagon w across, its top at `top`; the kart on it is this much bigger
PlotShowroom.TURNTABLE = { x = 0, z = 6, w = 14, top = 1.3, car = 2.4, spin = 20 }
-- each stand: an octagon w across, its top at `top`
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

-- A flat octagon (four boxes turned 0, 45, 90 and 135 degrees), w across, h tall, its top at `top`
-- (`solid`: you can stand on it; low enough to walk up)
local function octagon(
	add: Garage.Add,
	group: string,
	name: string,
	x: number,
	z: number,
	w: number,
	h: number,
	top: number,
	color: { number },
	solid: boolean
)
	local side = w * math.tan(math.rad(22.5))
	for k = 0, 3 do
		add(group, name, v(w, h, side), v(x, top - h / 2, z), color, {
			rot = v(0, k * 45, 0),
			collide = solid,
		})
	end
end

-- Everything in the showroom with `stands` stands (PlotShowroom.standCount).
function PlotShowroom.pieces(stands: number): { Piece }
	local out: { Piece } = {}
	local add = Garage.adder(out)
	local F = PlotShowroom.FLOOR
	local fx, fz = (F.x0 + F.x1) / 2, (F.z0 + F.z1) / 2
	local fw, fd = F.x1 - F.x0, F.z1 - F.z0
	-- a warm grey floor with a navy edge
	add("Floor", "Border", v(fw + 2 * F.border, 0.16, fd + 2 * F.border), v(fx, 0.08, fz), NAVY, {
		collide = false,
	})
	add("Floor", "Floor", v(fw, 0.2, fd), v(fx, 0.1, fz), FLOOR, { collide = false })
	-- the turntable: navy skirt, pink deck, white top
	local T = PlotShowroom.TURNTABLE
	octagon(add, "Turntable", "TableSkirt", T.x, T.z, T.w + 1, 0.5, 0.6, NAVY, true)
	octagon(add, "Turntable", "TableDeck", T.x, T.z, T.w, 0.7, T.top - 0.2, PINK, true)
	octagon(add, "Turntable", "TableTop", T.x, T.z, T.w - 1.6, 0.2, T.top, WHITE, false)
	-- the stands
	local S = PlotShowroom.STAND
	for i = 1, math.clamp(stands, 0, #SPOTS) do
		local p = SPOTS[i]
		local group = "Stand" .. i
		octagon(add, group, "StandBase", p.x, p.z, S.w, S.top - 0.2, S.top - 0.2, NAVY, true)
		octagon(add, group, "StandTop", p.x, p.z, S.w - 0.8, 0.2, S.top, SKY, false)
	end
	-- the crate on its pedestal: yellow, two navy bands, a red lid
	local C = PlotShowroom.CRATE
	local cs = C.size
	octagon(add, "Crate", "CratePedestal", C.x, C.z, C.w, 1, 1, NAVY, true)
	add("Crate", "CrateBody", v(cs, cs * 0.8, cs), v(C.x, 1 + cs * 0.4, C.z), YELLOW, {
		collide = true,
	})
	for _, y in { 0.3, 0.6 } do
		add("Crate", "CrateBand", v(cs + 0.2, 0.5, cs + 0.2), v(C.x, 1 + cs * 0.8 * y, C.z), NAVY, {
			collide = false,
		})
	end
	add("Crate", "CrateLid", v(cs + 0.6, 0.8, cs + 0.6), v(C.x, 1 + cs * 0.8 + 0.4, C.z), RED, {
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
