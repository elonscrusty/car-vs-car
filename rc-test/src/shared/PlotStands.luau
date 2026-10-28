--!strict
-- Your cars on show at your plot (carter's loop: build, race, earn coins, buy cars, SHOW OFF
-- cars). The left half of each plot's front area is a car show anyone walking the street sees:
-- your best car turns on a podium, every other car you own stands on a three-step shelf
-- behind it (best ones in front), and a board over the shelf says whose cars they are and how
-- many of all the cars there are. Empty spots stay dark, so a kid sees what is still missing.
-- Plain numbers (Lune tests load this); PlotStandsBuilder makes the parts.
--
-- Plot-local, RC size (studs): x across the plot, +z toward the road, y up. The cars are toy
-- cars (Garage.toyCar) in each car's own colour and style.

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

local CarCatalog = sibling("CarCatalog")
local Garage = sibling("Garage")
local ToyCars = sibling("ToyCars")
local Finish = sibling("Finish")

local PlotStands = {}

type Car = CarCatalog.Car
type V3 = { x: number, y: number, z: number }
local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

-- Every car there is, in catalog order (shops by mode, then the gumball cars).
PlotStands.ALL = {} :: { Car }
local chanceOf: { [string]: number } = {}
for _, mode in CarCatalog.MODES do
	for _, c in CarCatalog.SHOP[mode] do
		table.insert(PlotStands.ALL, c)
	end
end
for _, g in CarCatalog.GUMBALL do
	table.insert(PlotStands.ALL, g.car)
	chanceOf[g.car.id] = g.chance
end
local order: { [string]: number } = {}
for i, c in PlotStands.ALL do
	order[c.id] = i
end

-- How much a car is worth, for "best car first": its shop price, or for a gumball car what it
-- costs on average to spin it (rarer = worth more: Gold Rush beats every shop car).
function PlotStands.value(c: Car): number
	local chance = chanceOf[c.id]
	if chance then
		return CarCatalog.GUMBALL_PRICE * 100 / chance
	end
	return c.price
end

-- The cars someone has, from their "CarIds" attribute ("race_bolt,gb_gold"): known cars only,
-- no repeats, best first (rare first on a tie, then catalog order).
function PlotStands.parse(list: string?): { Car }
	local out: { Car } = {}
	local seen: { [string]: boolean } = {}
	for _, item in string.split(list or "", ",") do
		local id = string.match(item, "^%s*([%w_]+)%s*$")
		local c = if id then CarCatalog.get(id) else nil
		if c and not seen[c.id] then
			seen[c.id] = true
			table.insert(out, c)
		end
	end
	table.sort(out, function(a: Car, b: Car): boolean
		local va, vb = PlotStands.value(a), PlotStands.value(b)
		if va ~= vb then
			return va > vb
		end
		if a.rare ~= b.rare then
			return a.rare
		end
		return order[a.id] < order[b.id]
	end)
	return out
end

-- ===== Layout (plot-local RC studs) =====

PlotStands.X0, PlotStands.X1 = -31, -11 -- the show's width: canopy on the left, gate on the right
local MID = (PlotStands.X0 + PlotStands.X1) / 2
local STEP_D = 2.6 -- each shelf step's depth
local STEP_H = 0.8 -- each step up
local BACK_Z = 37.6 -- just in front of the low wall
PlotStands.SHELF_CAR = 0.65 -- shelf car size (times a 3.6-stud car)
PlotStands.HERO_CAR = 1.1
PlotStands.HERO = { x = MID, z = 50, r = 3.2, top = 1.2 } -- the turning podium
-- The board over the shelf (PlotStandsBuilder puts the words on its road side).
PlotStands.BOARD =
	{ x = MID, y = 5.5, z = BACK_Z + 0.4, w = PlotStands.X1 - PlotStands.X0, h = 3.2 }

-- Spots on the shelf, front row first (the best cars stand nearest the road): every car but the
-- hero has one, so owning them all fills the shelf exactly.
PlotStands.SLOTS = {} :: { { x: number, y: number, z: number } }
PlotStands.ROWS = {} :: { number }
do
	local total = #PlotStands.ALL - 1
	local width = PlotStands.X1 - PlotStands.X0
	for row = 1, 3 do
		local n = math.floor(total / 3) + (if row <= total % 3 then 1 else 0)
		PlotStands.ROWS[row] = n
		local gap = width / n
		local z = BACK_Z + (3 - row + 0.5) * STEP_D
		for i = 1, n do
			table.insert(PlotStands.SLOTS, {
				x = PlotStands.X0 + (i - 0.5) * gap,
				y = row * STEP_H,
				z = z,
			})
		end
	end
end

local STEP = { 222, 224, 230 } -- light showroom steps, so every colour and black tyre shows
local PLATE = { 120, 122, 132 } -- an empty spot: a dark square that wants a car
local BOARD = { 30, 34, 50 }
local PODIUM = { 36, 52, 100 } -- deep blue: a white or yellow car still stands out on it
local GOLD = { 255, 200, 50 }

-- A low-detail toy car for the shelf (phone speed): body, cab and one long tyre per axle, 4
-- parts instead of Garage.toyCar's 16. Same size and colours, nose to the road (+z).
PlotStands.SHELF_PARTS = 4
local TIRE = { 28, 28, 30 }
local GLASS = { 40, 50, 66 }
function PlotStands.shelfCar(add: Garage.Add, at: V3, c: Car)
	local s = PlotStands.SHELF_CAR
	local wheels = ToyCars.wheels(c.style)
	local wd, ww = wheels.wd, wheels.ww
	local track = 2 * (1 + ww / 2) + ww -- outside to outside of the two tyres
	local noHit = { collide = false }
	add("Shelf", "Body", v(2 * s, 0.7 * s, 3.6 * s), v(at.x, at.y + 0.85 * s, at.z), c.color, noHit)
	add(
		"Shelf",
		"Cab",
		v(1.6 * s, 0.6 * s, 1.5 * s),
		v(at.x, at.y + 1.5 * s, at.z - 0.25 * s),
		GLASS,
		noHit
	)
	for _, wz in { -1.2, 1.2 } do
		add(
			"Shelf",
			"Wheel",
			v(track * s, wd * s, wd * s),
			v(at.x, at.y + wd / 2 * s, at.z + wz * s),
			TIRE,
			{ shape = "Cylinder", collide = false }
		)
	end
end

-- The show (always) and the cars in it, as Garage pieces. `cars` best first (parse). Groups:
-- "Show" (shelf, podium, board: solid where you can stand), "Hero" (the turning car, its model
-- pivot is the podium's top middle) and "Shelf" (the other cars).
function PlotStands.pieces(cars: { Car }): { Garage.Piece }
	local out: { Garage.Piece } = {}
	local add = Garage.adder(out)
	local width = PlotStands.X1 - PlotStands.X0
	-- three steps, back one highest, each with a gold glow line on its front edge
	for row = 1, 3 do
		local top = row * STEP_H
		local z0 = BACK_Z + (3 - row) * STEP_D
		add("Show", "Step", v(width, top, STEP_D), v(MID, top / 2, z0 + STEP_D / 2), STEP)
		add(
			"Show",
			"Glow",
			v(width, 0.12, 0.08),
			v(MID, top - 0.08, z0 + STEP_D + 0.03),
			GOLD,
			{ material = "Neon", collide = false }
		)
	end
	for i, s in PlotStands.SLOTS do
		local c = cars[i + 1]
		local kind = if c and c.rarity ~= "common" then CarCatalog.RARITY[c.rarity] else nil
		add(
			"Show",
			"Plate" .. i,
			v(2.3, 0.06, 2.45),
			v(s.x, s.y + 0.03, s.z),
			if kind then kind.color else PLATE,
			{ material = if kind then "Neon" else nil, collide = false }
		)
		if c then
			PlotStands.shelfCar(add, v(s.x, s.y + 0.06, s.z), c)
		end
	end
	-- the board over the shelf on two posts
	local b = PlotStands.BOARD
	for _, sx in { -1, 1 } do
		local px = b.x + sx * (b.w / 2 + 0.2)
		add("Show", "Post", v(0.4, b.y, 0.4), v(px, b.y / 2, b.z), BOARD)
	end
	add("Show", "Board", v(b.w, b.h, 0.3), v(b.x, b.y, b.z), BOARD, { collide = false })
	add(
		"Show",
		"BoardTrim",
		v(b.w + 0.2, 0.15, 0.36),
		v(b.x, b.y - b.h / 2, b.z),
		GOLD,
		{ material = "Neon", collide = false }
	)
	add(
		"Show",
		"BoardTop",
		v(b.w + 0.2, 0.15, 0.36),
		v(b.x, b.y + b.h / 2, b.z),
		GOLD,
		{ material = "Neon", collide = false }
	)
	-- the podium: a round step with a gold glow ring and a light
	local h = PlotStands.HERO
	local d = h.r * 2
	add(
		"Show",
		"Podium",
		v(h.top, d, d),
		v(h.x, h.top / 2, h.z),
		PODIUM,
		{ shape = "Cylinder", rot = v(0, 0, 90) }
	)
	add(
		"Show",
		"Ring",
		v(0.14, d + 0.25, d + 0.25),
		v(h.x, h.top - 0.12, h.z),
		GOLD,
		{ shape = "Cylinder", rot = v(0, 0, 90), material = "Neon", collide = false, light = 14 }
	)
	local hero = cars[1]
	if hero then
		Garage.toyCar(
			add,
			"Hero",
			v(h.x, h.top, h.z),
			150,
			hero.color,
			PlotStands.HERO_CAR,
			hero.style
		)
	end
	return Finish.apply(out)
end

-- The cars in `now` that weren't in `before` (both "CarIds" lists): what was just bought or won.
-- No `before` (the first look at someone's cars this session) means nothing is new.
function PlotStands.fresh(before: string?, now: string): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if before == nil then
		return out
	end
	local had: { [string]: boolean } = {}
	for _, c in PlotStands.parse(before) do
		had[c.id] = true
	end
	for _, c in PlotStands.parse(now) do
		if not had[c.id] then
			out[c.id] = true
		end
	end
	return out
end

-- The board's words: "CARTER'S CARS" and "12 / 24".
function PlotStands.words(name: string, count: number): (string, string)
	return string.upper(name) .. "'S CARS", count .. " / " .. #PlotStands.ALL
end

return PlotStands
