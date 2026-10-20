--!strict
-- Where every prop of the Car Battle Lobby stands (pure data, no Roblox objects, so the tests can
-- check every number). server/LobbyProps.luau builds them; the picks behind them are carter's
-- L21-L40 in docs/LOBBY_POLISH.md: wooden benches, rainbow cones, tire stacks, junk piles, big
-- tip billboards, tool props at the customize garage, a chain fence round the edge, puffy clouds.
-- NO lamps, flowers, bushes, gas station, flags, banners or statue (L27, L32, L35, L37, L38).
--
-- Same coordinates as LobbyLayout: studs from the lobby origin, x right, z toward the spawn,
-- the asphalt top is y = 0. A prop's color follows the garage nearest to it (L40: orange for the
-- workshop and the customize garage, blue for the shop); cones stay rainbow (L22).

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local Layout = sibling("LobbyLayout")

local Props = {}

export type Rect = Layout.Rect

-- ---------------------------------------------------------------------------------------------
-- helpers

local function yawRad(deg: number): number
	return math.rad(deg)
end

-- Which garage color is nearest to a point: "orange" (workshop, customize) or "blue" (shop).
function Props.accentAt(x: number, z: number): string
	local best, bestD = "orange", math.huge
	for _, entry in
		{
			{ Layout.workshop, "orange" },
			{ Layout.customize, "orange" },
			{ Layout.shop, "blue" },
		}
	do
		local b = entry[1]
		local d = (b.x - x) ^ 2 + (b.z - z) ^ 2
		if d < bestD then
			best, bestD = entry[2], d
		end
	end
	return best
end

-- A point `out` studs in front of a garage's mouth and `across` studs along it (positive = to the
-- viewer's right when looking at the garage from the front). Returns x, z, and the yaw (degrees)
-- that makes a prop drawn facing +z look away from the garage.
function Props.garagePoint(b: Layout.Rect, out: number, across: number): (number, number, number)
	local c, s = math.cos(yawRad(b.yawDeg)), math.sin(yawRad(b.yawDeg))
	local v = b.d / 2 + out
	-- the garage's local +u is world (c, -s), its local +v (toward the mouth) is world (s, c)
	return b.x + c * across + s * v, b.z - s * across + c * v, b.yawDeg
end

-- ---------------------------------------------------------------------------------------------
-- benches (L21 wooden, L49 nobody sits: they are plain parts, never seats)

export type Bench = { x: number, z: number, yawDeg: number, accent: string }

-- yaw 0: the long side runs along z and the sitter faces +x; 180 faces -x.
function Props.benches(): { Bench }
	local list: { Bench } = {}
	for _, b in
		{
			{ -30, 48, 0 }, -- near the front path, facing it
			{ 30, 48, 180 },
			{ -32, 12, 0 }, -- by the ring, watching the pads
			{ 32, 12, 180 },
			{ -78, 29.5, 0 }, -- by the side walls
			{ 78, 29.5, 180 },
		}
	do
		table.insert(
			list,
			{ x = b[1], z = b[2], yawDeg = b[3], accent = Props.accentAt(b[1], b[2]) }
		)
	end
	return list
end

-- ---------------------------------------------------------------------------------------------
-- cones (L22 rainbow, none orange; L8 never kickable: the builder makes them look-only)

export type Cone = { x: number, z: number, color: number } -- color = index into colors.rainbow

function Props.cones(): { Cone }
	local spots = {
		-- two lines along the front path
		{ -10, 50 },
		{ 10, 50 },
		{ -10, 44 },
		{ 10, 44 },
		-- round the ring
		{ -30, 24 },
		{ 30, 24 },
		{ -30, -12 },
		{ 30, -12 },
		{ -20, -20 },
		{ 20, -20 },
		-- by the garages and the workshop mouth
		{ -13, -32 },
		{ 13, -32 },
		{ -66, -8 },
		{ 66, -8 },
		-- by the side walls and the parking lots
		{ -76, 52 },
		{ 76, 52 },
		{ -76, 8 },
		{ 76, 8 },
		{ -40, 3 },
		{ 40, 3 },
	}
	local list: { Cone } = {}
	for i, p in spots do
		table.insert(list, { x = p[1], z = p[2], color = (i - 1) % #Layout.colors.rainbow + 1 })
	end
	return list
end

-- ---------------------------------------------------------------------------------------------
-- stacks of bright tires (L29)

export type TireStack = { x: number, z: number, count: number, seed: number }

function Props.tireStacks(): { TireStack }
	local list: { TireStack } = {}
	for i, p in
		{
			{ -80, 50, 3 },
			{ 80, 50, 4 },
			{ -80, 7, 4 },
			{ 80, 7, 3 },
			{ -33, -62, 3 },
			{ 33, -62, 4 },
			{ -60, 3, 2 },
			{ 60, 3, 2 },
		}
	do
		table.insert(list, { x = p[1], z = p[2], count = p[3], seed = i })
	end
	return list
end

-- ---------------------------------------------------------------------------------------------
-- junk piles of old car parts, colorful, at the edges (L28)

export type JunkPile = { x: number, z: number, yawDeg: number, seed: number }

function Props.junkPiles(): { JunkPile }
	return {
		{ x = -79, z = 40, yawDeg = 10, seed = 1 },
		{ x = 79, z = 40, yawDeg = -10, seed = 2 },
		{ x = -79, z = 19, yawDeg = -10, seed = 3 },
		{ x = 79, z = 19, yawDeg = 10, seed = 4 },
	}
end

-- ---------------------------------------------------------------------------------------------
-- big bright billboards with a short game tip (L25, L26)

export type Billboard = {
	x: number,
	z: number,
	yawDeg: number, -- turns a board drawn facing +z
	w: number,
	h: number,
	bottom: number, -- height of the board's lower edge
	line1: string,
	line2: string,
	color: string, -- key into Props.billboardColors
}

-- Board background (bright), trim and letter colors by name.
Props.billboardColors = {
	blue = { bg = { 64, 112, 140 }, trim = { 200, 160, 72 } },
	yellow = { bg = { 196, 156, 64 }, trim = { 64, 112, 140 } },
	green = { bg = { 84, 120, 84 }, trim = { 236, 230, 214 } },
	pink = { bg = { 150, 84, 110 }, trim = { 236, 230, 214 } },
} :: { [string]: { bg: { number }, trim: { number } } }

-- Tips must be true: they come from docs and the fight rules (a harder crash hurts more, walls
-- only bounce, your weapon, coins buy gumball pulls). Each line is at most 20 characters.
-- The boards stand back past the fence, so seen from above they do not cover the parked cars.
local BOARD_OUT = 17

function Props.billboards(): { Billboard }
	local p = Layout.plaza
	return {
		{
			x = -(p.halfX + BOARD_OUT),
			z = -44,
			yawDeg = 90,
			w = 24,
			h = 9,
			bottom = 9,
			line1 = "HIT FROM THE SIDE",
			line2 = "DODGE THEIR FRONT",
			color = "blue",
		},
		{
			x = p.halfX + BOARD_OUT,
			z = -44,
			yawDeg = -90,
			w = 24,
			h = 9,
			bottom = 9,
			line1 = "BIG CRASH = BIG HIT",
			line2 = "GO FAST, THEN HIT",
			color = "yellow",
		},
		{
			x = -(p.halfX + BOARD_OUT),
			z = 38,
			yawDeg = 90,
			w = 24,
			h = 9,
			bottom = 9,
			line1 = "WALLS BOUNCE YOU",
			line2 = "THEY DO NO DAMAGE",
			color = "green",
		},
		{
			x = p.halfX + BOARD_OUT,
			z = 38,
			yawDeg = -90,
			w = 24,
			h = 9,
			bottom = 9,
			line1 = "WIN COINS, PULL",
			line2 = "THE GUMBALL MACHINE",
			color = "pink",
		},
	}
end

-- The two posts of a board, as footprints (the board itself is high over everyone's head).
function Props.billboardPosts(b: Billboard): { Rect }
	local c, s = math.cos(yawRad(b.yawDeg)), math.sin(yawRad(b.yawDeg))
	local out: { Rect } = {}
	for _, side in { -1, 1 } do
		local u = side * (b.w / 2 - 2)
		table.insert(
			out,
			{ x = b.x + c * u, z = b.z - s * u, w = 1.8, d = 1.8, yawDeg = b.yawDeg } :: Rect
		)
	end
	return out
end

-- ---------------------------------------------------------------------------------------------
-- tool props by the Customize garage (L36): toolboxes, car jacks, wrench racks, a tool cart

export type ToolProp = { kind: string, x: number, z: number, yawDeg: number, accent: string }

function Props.toolProps(): { ToolProp }
	local b = Layout.customize
	local list: { ToolProp } = {}
	-- across: + is to the viewer's right looking at the garage; out = studs in front of the mouth
	for _, t in
		{
			{ "rack", 1.5, -10.5 }, -- against the wall, left of the door path
			{ "toolbox", 2, 11.5 },
			{ "jack", 2.5, 16.5 },
			{ "cart", 5, -10 },
			{ "toolbox", 6.5, 13 },
			{ "jack", 10.5, 14.5 },
		}
	do
		local x, z, yaw = Props.garagePoint(b, t[2], t[3])
		table.insert(list, { kind = t[1], x = x, z = z, yawDeg = yaw, accent = "orange" })
	end
	return list
end

-- Floor size (w across, d deep) of each tool prop kind, before it is turned.
Props.toolSize = {
	toolbox = { w = 4.4, d = 2.6 },
	rack = { w = 6.4, d = 1.6 },
	jack = { w = 3.6, d = 3.6 },
	cart = { w = 6, d = 4 },
} :: { [string]: { w: number, d: number } }

-- ---------------------------------------------------------------------------------------------
-- the chain fence round the edge (L30)

export type FenceBay = { ax: number, az: number, bx: number, bz: number }

Props.fenceBayLength = 9
Props.fenceHeight = 6.4

-- Gaps are where the dirt paths leave the lobby: they line up with the tire wall entrances.
local function fenceGaps(): { { axis: string, from: number, to: number } }
	local gaps = {}
	for _, e in Layout.entrances do
		table.insert(gaps, { axis = e.axis, from = e.from - 3, to = e.to + 3 })
	end
	return gaps
end

-- The straight bays between two posts, all round the plaza `Layout.fenceGap` studs outside the
-- tire wall. Bays whose middle is in an entrance gap are left out, so the paths stay open.
function Props.fence(): { FenceBay }
	local p = Layout.plaza
	local g = Layout.fenceGap
	local left, right, front, back = -(p.halfX + g), p.halfX + g, p.frontZ + g, p.backZ - g
	local gaps = fenceGaps()
	local bays: { FenceBay } = {}
	local function run(ax: number, az: number, bx: number, bz: number, axis: string)
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local n = math.max(1, math.ceil(len / Props.fenceBayLength))
		for i = 0, n - 1 do
			local x0, z0 = ax + (bx - ax) * i / n, az + (bz - az) * i / n
			local x1, z1 = ax + (bx - ax) * (i + 1) / n, az + (bz - az) * (i + 1) / n
			local midAlong = if axis == "z" then (x0 + x1) / 2 else (z0 + z1) / 2
			local inGap = false
			for _, gap in gaps do
				if gap.axis == axis and midAlong > gap.from and midAlong < gap.to then
					inGap = true
				end
			end
			if not inGap then
				table.insert(bays, { ax = x0, az = z0, bx = x1, bz = z1 })
			end
		end
	end
	run(left, back, right, back, "z") -- back wall (no entrance)
	run(left, front, right, front, "z") -- front, gap for the spawn path
	run(left, back, left, front, "x") -- left side, gap for the left entrance
	run(right, back, right, front, "x")
	return bays
end

-- ---------------------------------------------------------------------------------------------
-- puffy cartoon clouds (L48)

export type Cloud = { x: number, y: number, z: number, scale: number, seed: number }

function Props.clouds(): { Cloud }
	local list: { Cloud } = {}
	local seed = 48
	local function rnd(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	-- two rings round the lobby at different heights, so some drift over the plaza and some sit
	-- on the horizon
	for i = 0, 13 do
		local a = i / 14 * math.pi * 2 + rnd() * 0.3
		local r = 120 + rnd() * 220
		table.insert(list, {
			x = math.cos(a) * r,
			y = 70 + rnd() * 50,
			z = math.sin(a) * r - 10,
			scale = 0.8 + rnd() * 0.9,
			seed = i + 1,
		})
	end
	return list
end

-- ---------------------------------------------------------------------------------------------
-- ground paint: dark skid patches, black tire skid marks (L34), bright painted lines (L33)

export type Patch = { x: number, z: number, w: number, d: number, yawDeg: number }

function Props.patches(): { Patch }
	return {
		{ x = -66, z = 2, w = 20, d = 14, yawDeg = 10 },
		{ x = 66, z = -4, w = 18, d = 16, yawDeg = -15 },
		{ x = -28, z = 52, w = 14, d = 8, yawDeg = 5 },
		{ x = 30, z = 30, w = 10, d = 14, yawDeg = 25 },
		{ x = -2, z = -34, w = 12, d = 8, yawDeg = 0 },
		{ x = 74, z = 30, w = 10, d = 12, yawDeg = 12 },
		{ x = -74, z = 4, w = 10, d = 10, yawDeg = 0 },
	}
end

export type Skid = { x: number, z: number, len: number, yawDeg: number }

-- A pair of thin black strips each (the two tires).
function Props.skids(): { Skid }
	return {
		{ x = -16, z = 28, len = 16, yawDeg = 12 },
		{ x = 20, z = 40, len = 14, yawDeg = -10 },
		{ x = 34, z = -2, len = 18, yawDeg = 70 },
		{ x = -38, z = 4, len = 20, yawDeg = 110 },
		{ x = -52, z = -26, len = 12, yawDeg = 35 },
		{ x = 50, z = -26, len = 14, yawDeg = -40 },
		{ x = 0, z = 24, len = 10, yawDeg = 0 },
	}
end

export type Line = { x: number, z: number, w: number, d: number, yawDeg: number, color: string }

-- Bright painted lines: a yellow dashed line down the middle of the front path and the ring road
-- to the workshop, and yellow/black hazard stripes in front of each garage mouth.
function Props.lines(): { Line }
	local list: { Line } = {}
	-- dashed yellow centre line, front path (spawn side)
	for z = 33, 53, 4 do
		table.insert(list, { x = 0, z = z, w = 0.6, d = 2, yawDeg = 0, color = "yellow" })
	end
	-- and the way to the workshop
	for z = -18, -34, -4 do
		table.insert(list, { x = 0, z = z, w = 0.6, d = 2, yawDeg = 0, color = "yellow" })
	end
	-- hazard stripes across each garage mouth, 2.4 studs out
	for _, b in { Layout.workshop, Layout.customize, Layout.shop } do
		local n = 6
		for i = 1, n do
			local across = (i - (n + 1) / 2) * ((b.w - 8) / n)
			local x, z, yaw = Props.garagePoint(b, 2.6, across)
			table.insert(list, {
				x = x,
				z = z,
				w = 2,
				d = 2.4,
				yawDeg = yaw,
				color = if i % 2 == 1 then "yellow" else "black",
			})
		end
	end
	return list
end

-- ---------------------------------------------------------------------------------------------
-- floor room taken by solid props, for the "nothing overlaps" tests

function Props.footprints(): { [string]: Rect }
	local out: { [string]: Rect } = {}
	for i, b in Props.benches() do
		out["bench" .. i] = { x = b.x, z = b.z, w = 3.4, d = 8.4, yawDeg = b.yawDeg + 0 } :: Rect
	end
	for i, t in Props.tireStacks() do
		out["tires" .. i] = { x = t.x, z = t.z, w = 5.2, d = 5.2, yawDeg = 0 } :: Rect
	end
	for i, j in Props.junkPiles() do
		out["junk" .. i] = { x = j.x, z = j.z, w = 11, d = 9, yawDeg = j.yawDeg } :: Rect
	end
	for i, b in Props.billboards() do
		for k, post in Props.billboardPosts(b) do
			out["billboard" .. i .. "_" .. k] = post
		end
	end
	for i, t in Props.toolProps() do
		local size = Props.toolSize[t.kind]
		out["tool" .. i] =
			{ x = t.x, z = t.z, w = size.w + 0.4, d = size.d + 0.4, yawDeg = t.yawDeg } :: Rect
	end
	return out
end

return Props
