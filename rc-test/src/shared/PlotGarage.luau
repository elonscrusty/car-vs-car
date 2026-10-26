--!strict
-- Your plot is your garage (carter's tycoon plan, 2026-10-26: race, earn coins, buy cars, your
-- cars make coins). Behind the front wall a little oval road fills the plot: the cars you
-- parked drive round it slowly, and new ones roll out of the garage door at the back. Coins
-- pile up just inside the front wall (tap the pile to collect), and a LEVEL UP sign beside it
-- buys the next plot level: more spots on the loop and nicer looks.
-- Plain numbers and Garage pieces (Lune tests load this); PlotGarageBuilder (server) builds the
-- yard, PlotGarage.client drives the cars and draws the pile.
--
-- Plot-local, RC size (studs): x across the plot (±40), +z toward the road (the front wall is
-- at z 37, the street wall at 55), y up.

-- Loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		local node: any = (script :: any).Parent
		for _, part in string.split(name, "/") do
			node = node[part]
		end
		return require(node)
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Garage = sibling("Garage")
local Finish = sibling("Finish")

local PlotGarage = {}

type V3 = Garage.V3
type Piece = Garage.Piece
type Mesh = Garage.Mesh
local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

-- The loop: a stadium (two straights along z joined by half circles), measured on its middle
-- line. Its half width is also the bends' radius.
PlotGarage.LOOP = { x = 0, z = -12, halfW = 26, halfL = 32, road = 8 }
PlotGarage.SPEED = 5 -- studs a second: a slow parade, so you can see every car
PlotGarage.CAR = 1 -- toy car size (times a 3.6-stud car)
PlotGarage.MAX_LEVEL = 5
PlotGarage.MAX_CARS = 8 -- spots on the loop at the top level
PlotGarage.PILE = { x = 0, z = 31, r = 4.5 } -- the coin pile, between the loop and the gate
PlotGarage.SIGN = { x = 20, z = 31 } -- the LEVEL UP sign, right of the pile
PlotGarage.DOOR = { x = 0, z = -51.5 } -- the garage the cars come out of, at the back

-- Cars that park and earn at `level` (Tycoon.slots has the real rule; this one draws the
-- empty spots): 3 at level 0, one more each level.
function PlotGarage.slots(level: number): number
	return math.clamp(3 + math.floor(level), 3, PlotGarage.MAX_CARS)
end

-- Length of the loop's middle line.
function PlotGarage.length(): number
	local L = PlotGarage.LOOP
	local straight = 2 * (L.halfL - L.halfW)
	return 2 * straight + 2 * math.pi * L.halfW
end

-- Where on the loop's middle line a car is at `t` (0..1, round the loop once), and which way it
-- faces (yaw in radians, Roblox style: 0 = toward -z). Starts at the right straight's front
-- end, driving toward the back (-z), round the back bend, down the left side, round the front.
function PlotGarage.at(t: number): (number, number, number)
	local L = PlotGarage.LOOP
	local r = L.halfW
	local st = 2 * (L.halfL - r)
	local s = (t % 1) * PlotGarage.length()
	local top, bottom = L.z - (L.halfL - r), L.z + (L.halfL - r) -- the bends' centres (z)
	if s < st then
		return L.x + r, bottom - s, 0
	end
	s -= st
	if s < math.pi * r then
		local a = s / r -- 0..pi, from the right (+x) round the back to the left
		return L.x + r * math.cos(a), top - r * math.sin(a), a
	end
	s -= math.pi * r
	if s < st then
		return L.x - r, top + s, math.pi
	end
	s -= st
	local a = s / r -- from the left round the front to the right
	return L.x - r * math.cos(a), bottom + r * math.sin(a), math.pi + a
end

-- The cars' spots: `count` cars spread evenly, moving along together. `clock` in seconds.
function PlotGarage.spot(i: number, count: number, clock: number): (number, number, number)
	local t = (i - 1) / math.max(1, count) + clock * PlotGarage.SPEED / PlotGarage.length()
	return PlotGarage.at(t)
end

-- Now and then a "+N" floats up off each car on the loop: the coins it made since the last one,
-- so you can see your cars earning. POP_SECS apart per car (staggered), N from its coins a minute.
-- Moves at a set rate: add a frame's time to `acc`; due when a step is owed (and `acc` is what's
-- left). hz >= 60 means every frame.
function PlotGarage.stepDue(acc: number, dt: number, hz: number): (number, boolean)
	if hz >= 60 then
		return 0, true
	end
	acc += dt
	if acc >= 1 / hz then
		return acc % (1 / hz), true
	end
	return acc, false
end

PlotGarage.POP_SECS = 30
function PlotGarage.popCoins(perMin: number): number
	return math.max(1, math.floor(perMin * PlotGarage.POP_SECS / 60 + 0.5))
end

-- The income board in the front left corner (where the old car show stood), facing the road:
-- how many coins a minute the owner's cars make, so a new player sees what the garage is for.
PlotGarage.BOARD = { x = -21, z = 46 }
function PlotGarage.boardPieces(): { Piece }
	local out: { Piece } = {}
	local add = Garage.adder(out)
	local B = PlotGarage.BOARD
	for _, sx in { -6, 6 } do
		-- behind the board, so they never cover its words
		add("Board", "BoardPost", v(0.6, 7, 0.6), v(B.x + sx, 3.5, B.z - 0.6), { 40, 44, 60 })
	end
	add("Board", "IncomeBoard", v(14, 5, 0.5), v(B.x, 5, B.z), { 30, 36, 64 }, { collide = false })
	add(
		"Board",
		"BoardTrim",
		v(14.6, 0.4, 0.7),
		v(B.x, 2.4, B.z),
		{ 255, 200, 50 },
		{ collide = false }
	)
	add(
		"Board",
		"BoardTrim",
		v(14.6, 0.4, 0.7),
		v(B.x, 7.6, B.z),
		{ 255, 200, 50 },
		{ collide = false }
	)
	return Finish.apply(out)
end

-- The income board's two lines: coins a minute (boost included) and from how many cars.
function PlotGarage.incomeWords(perMin: number, cars: number, boosted: boolean): (string, string)
	local top = "+" .. math.floor(perMin) .. " COINS / MIN"
	if boosted then
		return top, "2X BOOST!"
	end
	return top, "FROM " .. cars .. (if cars == 1 then " CAR" else " CARS")
end

-- The gate sign over a garage plot: "MIA'S GARAGE" ("JAMES' GARAGE"), or "GARAGE" when it is
-- nobody's.
function PlotGarage.signText(name: string?): string
	if name == nil or name == "" then
		return "GARAGE"
	end
	local up = string.upper(name)
	return if string.sub(up, -1) == "S" then up .. "' GARAGE" else up .. "'S GARAGE"
end

-- The LEVEL UP sign's two lines at `level`, with `cost` coins to the next (nil at the top): it
-- says what you get, one more car on the loop.
function PlotGarage.levelWords(level: number, cost: number?): (string, string)
	if cost == nil then
		return "LV " .. level, "MAX"
	end
	return "LEVEL UP: +1 CAR", cost .. " COINS"
end

-- The coin pile's look: how many coins to draw for `coins` waiting (a few always show once
-- there is one, the heap grows slower and slower, and stops at PILE_MAX).
PlotGarage.PILE_MAX = 60
function PlotGarage.pileCoins(coins: number): number
	if coins < 1 then
		return 0
	end
	return math.min(PlotGarage.PILE_MAX, math.floor(4 + 9 * math.log10(coins)))
end

-- Coins in a heap: spot k of n (seeded, so the heap never jumps), plot-local.
function PlotGarage.coinSpot(k: number): (number, number, number, number)
	local P = PlotGarage.PILE
	local a = k * 2.399963 -- golden angle: an even spread
	local ring = math.sqrt(k / PlotGarage.PILE_MAX)
	local rr = P.r * ring
	local x, z = P.x + math.cos(a) * rr, P.z + math.sin(a) * rr
	local y = 0.15 + (1 - ring) * 1.6 -- higher in the middle: a heap
	local tilt = (k * 37) % 50 - 25 -- degrees, so they don't all lie flat
	return x, y, z, tilt
end

-- ===== The yard (server builds these; nothing is solid except the sign and the pile base) =====

local ROAD = { 64, 66, 74 }
local LINE = { 240, 240, 240 }
local RED = { 225, 60, 60 }
local WHITE = { 245, 245, 245 }
local GOLD = { 255, 200, 50 }
local PAD = { 120, 122, 132 }
local GRASS = { 104, 172, 80 }
local SIGN = { 60, 190, 90 }

-- a box from (ax, az) to (bx, bz) on the ground, `w` wide, `h` tall, at height `y`
local function slab(
	add: Garage.Add,
	group: string,
	name: string,
	ax: number,
	az: number,
	bx: number,
	bz: number,
	w: number,
	y: number,
	h: number,
	color: { number },
	opts: Garage.Opts?
)
	local dx, dz = bx - ax, bz - az
	local len = math.sqrt(dx * dx + dz * dz)
	local o: Garage.Opts = opts or {}
	o.rot = v(0, math.deg(math.atan2(-dx, -dz)), 0)
	o.collide = false
	add(group, name, v(w, h, len), v((ax + bx) / 2, y, (az + bz) / 2), color, o)
end

-- the loop's middle line as points, `n` per bend
local function ring(n: number, offset: number): { { number } }
	local L = PlotGarage.LOOP
	local r = L.halfW + offset
	local top, bottom = L.z - (L.halfL - L.halfW), L.z + (L.halfL - L.halfW)
	local pts: { { number } } = {}
	table.insert(pts, { L.x + r, bottom })
	for i = 0, n do
		local a = i / n * math.pi
		table.insert(pts, { L.x + r * math.cos(a), top - r * math.sin(a) })
	end
	for i = 0, n do
		local a = i / n * math.pi
		table.insert(pts, { L.x - r * math.cos(a), bottom + r * math.sin(a) })
	end
	return pts
end

PlotGarage.BENDS = 10 -- road pieces per bend

-- Everything the yard has at `level`, as Garage pieces (groups "Loop", "Pile", "Sign", "Level").
function PlotGarage.pieces(level: number): { Piece }
	local out: { Piece } = {}
	local add = Garage.adder(out)
	local L = PlotGarage.LOOP
	local gold = level >= PlotGarage.MAX_LEVEL
	-- grass over the yard, so the grey road stands out (the plot floor is grey too)
	add("Loop", "Grass", v(78, 0.06, 90.5), v(0, 0.02, -8.75), GRASS, {
		material = "Grass",
		collide = false,
	})
	-- the road, a white middle line, red and white curbs on both edges (gold at the top level)
	local mid = ring(PlotGarage.BENDS, 0)
	for i = 1, #mid - 1 do
		local a, b = mid[i], mid[i + 1]
		slab(add, "Loop", "Road", a[1], a[2], b[1], b[2], L.road, 0.05, 0.1, ROAD, {
			material = "Asphalt",
		})
	end
	local a, b = mid[#mid], mid[1]
	slab(add, "Loop", "Road", a[1], a[2], b[1], b[2], L.road, 0.05, 0.1, ROAD, {
		material = "Asphalt",
	})
	for _, side in { -1, 1 } do
		local edge = ring(PlotGarage.BENDS, side * (L.road / 2 + 0.4))
		for i = 1, #edge do
			local p, q = edge[i], edge[i % #edge + 1]
			local col = if gold then GOLD elseif i % 2 == 0 then WHITE else RED
			slab(add, "Loop", "Curb", p[1], p[2], q[1], q[2], 0.8, 0.15, 0.3, col, {
				material = if gold then "Neon" else nil,
			})
		end
	end
	for i = 1, #mid - 1, 2 do
		local p, q = mid[i], mid[i + 1]
		slab(add, "Loop", "Line", p[1], p[2], q[1], q[2], 0.3, 0.11, 0.02, LINE)
	end
	-- the coin pile's base: a low round pad you can step on (the coins are the client's)
	local P = PlotGarage.PILE
	add("Pile", "PileBase", v(0.3, P.r * 2 + 1, P.r * 2 + 1), v(P.x, 0.15, P.z), PAD, {
		shape = "Cylinder",
		rot = v(0, 0, 90),
		collide = false,
	})
	add("Pile", "PileRing", v(0.12, P.r * 2 + 1.4, P.r * 2 + 1.4), v(P.x, 0.08, P.z), GOLD, {
		shape = "Cylinder",
		rot = v(0, 0, 90),
		material = "Neon",
		collide = false,
	})
	-- the LEVEL UP sign: a board on two posts, words on its road side (the builder's)
	local S = PlotGarage.SIGN
	for _, sx in { -1, 1 } do
		add("Sign", "SignPost", v(0.4, 4, 0.4), v(S.x + sx * 4.2, 2, S.z - 0.4), { 40, 44, 60 })
	end
	add("Sign", "SignBoard", v(9, 3, 0.4), v(S.x, 4.5, S.z), SIGN, { collide = false })
	-- level looks: lamps at the corners from level 1, flags along the straights from level 2,
	-- a gold ring round the pile from level 4 (carter's models come in through meshes())
	if level >= 1 then
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local x, z = L.x + sx * (L.halfW + 9), L.z + sz * (L.halfL - 2)
				add(
					"Level",
					"Pole",
					v(0.4, 7, 0.4),
					v(x, 3.5, z),
					{ 40, 44, 60 },
					{ collide = false }
				)
				add("Level", "Lamp", v(1.2, 1.2, 1.2), v(x, 7.4, z), { 255, 230, 160 }, {
					shape = "Ball",
					material = "Neon",
					collide = false,
					light = 16,
				})
			end
		end
	end
	if level >= 2 then
		local cols = { RED, GOLD, { 70, 150, 255 }, { 70, 190, 90 } }
		for _, sx in { -1, 1 } do
			for k = -2, 2 do
				local x, z = L.x + sx * (L.halfW + 6.5), L.z + k * 9
				add("Level", "FlagPole", v(0.3, 5, 0.3), v(x, 2.5, z), WHITE, { collide = false })
				add("Level", "Flag", v(0.1, 1.4, 2), v(x, 4.3, z + 1), cols[(k + 3) % #cols + 1], {
					collide = false,
				})
			end
		end
	end
	if level >= 4 then
		add("Level", "PileCrown", v(0.26, P.r * 2 + 2, P.r * 2 + 2), v(P.x, 0.13, P.z), GOLD, {
			shape = "Cylinder",
			rot = v(0, 0, 90),
			material = "Neon",
			collide = false,
		})
	end
	return Finish.apply(out)
end

-- carter's Meshy models for the yard at `level` (group "Extras": they only show up once
-- imported in ServerStorage.LobbyMeshes).
function PlotGarage.meshes(level: number): { Mesh }
	local L = PlotGarage.LOOP
	local D = PlotGarage.DOOR
	local list: { { any } } = {
		-- { model, at, fit, yaw (degrees), from level }
		{ "GarageDoor", v(D.x, 0, D.z), v(16, 9, 3), 180, 0 }, -- door to the loop
		{ "TireRack", v(L.x - 14, 0, D.z), v(5, 5, 2.5), 180, 0 },
		{ "PaintCans", v(L.x + 13, 0, D.z), v(4, 3, 2), 0, 1 },
		{ "Spotlight", v(L.x + L.halfW + 9, 0, L.z), v(3, 4, 3.1), 90, 1 }, -- lamp to the loop
		{ "TrackCamera", v(L.x - L.halfW - 9, 0, L.z), v(2.4, 4, 2.5), -90, 2 },
		{ "Grandstand", v(L.x, 0, L.z), v(16, 6, 8), 180, 3 }, -- in the loop's middle, seats to the gate
		{ "BalloonArch", v(L.x + L.halfW, 0, L.z + 12), v(12, 9, 3), 0, 4 }, -- the cars drive through
		{ "Fountain", v(L.x, 0, L.z - 18), v(8, 5, 8), 0, 5 },
	}
	local out: { Mesh } = {}
	for _, m in list do
		if level >= m[5] then
			local fit: V3 = m[3]
			table.insert(out, {
				model = m[1],
				group = "Extras",
				at = m[2],
				fit = fit,
				long = if fit.z > fit.x then "z" else "x",
				keep = {},
				collide = false,
				yaw = m[4],
			})
		end
	end
	return out
end

return PlotGarage
