--!strict
-- Carter's stars loop, phase 2: a plot grows with its owner's stars (his picks, 2026-10-23).
-- 10 stars = night (the plot goes dark blue and lamp posts light up), 25 = snow (white wall
-- tops, snow patches, falling snow), 50 = party (string lights, fans on the walls, two
-- searchlights). Each look keeps the ones below it. Looks only: nothing here is solid or can be
-- hit by the car's rays (the builder makes every piece CanCollide/CanQuery off), so driving
-- never changes. The sky is shared, so "night" is the plot's own tint and lamps.
-- Plot-local, real RC size, like PlotDecor: (0, 0, 0) = middle of the plot on the floor, +Z =
-- front (the road), x -40..40, z -55..55. Plain numbers (Lune tests load it).

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
local PlotDecor = sibling("PlotDecor")

type Piece = Garage.Piece

local PlotLooks = {}

PlotLooks.TIERS = { 10, 25, 50 } -- stars for night, snow, party
PlotLooks.NAMES = { "NIGHT", "SNOW", "PARTY" }
PlotLooks.NIGHT_TINT = { 20, 28, 60 } -- the plot's colours go this way at night
PlotLooks.NIGHT_AMOUNT = 0.45
PlotLooks.MAX_LIGHTS = 12 -- PointLights + SpotLights per plot (phones)

-- 0 = day, 1 = night, 2 = snow, 3 = party
function PlotLooks.tier(stars: number): number
	local t = 0
	for i, need in PlotLooks.TIERS do
		if stars >= need then
			t = i
		end
	end
	return t
end

-- a colour toward the night tint (plain 0..255 numbers)
function PlotLooks.nightColor(c: { number }): { number }
	local a = PlotLooks.NIGHT_AMOUNT
	local out = {}
	for i = 1, 3 do
		out[i] = math.floor(c[i] + (PlotLooks.NIGHT_TINT[i] - c[i]) * a + 0.5)
	end
	return out
end

local function v(x: number, y: number, z: number): Garage.V3
	return { x = x, y = y, z = z }
end

local W, D = PlotDecor.HALF_W, PlotDecor.HALF_D -- 40, 55
local TOP = PlotDecor.WALL_H + 0.3 -- top of the wall caps

local BULBS = {
	{ 255, 80, 80 },
	{ 255, 210, 70 },
	{ 90, 220, 120 },
	{ 80, 170, 255 },
	{ 230, 110, 255 },
}
local SHIRTS = {
	{ 230, 70, 60 },
	{ 60, 130, 230 },
	{ 250, 200, 60 },
	{ 80, 190, 110 },
	{ 240, 240, 240 },
	{ 170, 90, 220 },
}
local SKIN = { { 255, 214, 170 }, { 205, 150, 110 }, { 140, 95, 65 } }

local function night(add: Garage.Add)
	-- lamp posts on the side walls (3 a side): pole + warm glowing head with a light
	for _, sx in { -1, 1 } do
		for _, z in { -35, -5, 25 } do
			add("Night", "LampPole", v(0.3, 4.5, 0.3), v(sx * W, TOP + 2.25, z), { 50, 52, 58 }, {
				collide = false,
			})
			add(
				"Night",
				"LampHead",
				v(0.8, 0.5, 0.8),
				v(sx * W, TOP + 4.7, z),
				{ 255, 226, 160 },
				{ collide = false, material = "Neon", light = 16 }
			)
		end
	end
end

local function snow(add: Garage.Add)
	local white = { 245, 248, 255 }
	local opts = { collide = false, material = "Snow" }
	-- snow on every wall top
	for _, sx in { -1, 1 } do
		add("Snow", "WallSnow", v(1.1, 0.25, 2 * D + 1), v(sx * W, TOP + 0.12, 0), white, opts)
	end
	add("Snow", "WallSnow", v(2 * W, 0.25, 1.1), v(0, TOP + 0.12, -D), white, opts)
	-- drifts piled against the inside of the walls (thin, flat, low)
	local drifts = {
		{ -W + 2, -40, 3, 14 },
		{ W - 2, -20, 3, 18 },
		{ -W + 2, 10, 3, 12 },
		{ W - 2, 22, 3, 10 },
		{ -20, -D + 2, 16, 3 },
		{ 18, -D + 2, 12, 3 },
	}
	for _, d in drifts do
		add("Snow", "Drift", v(d[3], 0.3, d[4]), v(d[1], 0.15, d[2]), white, opts)
	end
	-- the falling snow comes from this (the builder adds the particles)
	add("Snow", "SnowCloud", v(2 * W, 0.2, 2 * D), v(0, 22, 0), white, {
		collide = false,
		material = "SmoothPlastic",
	})
end

local function party(add: Garage.Add)
	-- string lights along both side walls, just over the lamp poles' feet
	local n = 0
	for _, sx in { -1, 1 } do
		for z = -D + 3, D - 3, 4 do
			n += 1
			add(
				"Party",
				"Bulb",
				v(0.35, 0.35, 0.35),
				v(sx * W, TOP + 1.6 + 0.25 * math.sin(z * 0.8), z),
				BULBS[(n % #BULBS) + 1],
				{ collide = false, material = "Neon", shape = "Ball" }
			)
		end
		add("Party", "Wire", v(0.06, 0.06, 2 * D - 4), v(sx * W, TOP + 1.75, 0), { 30, 30, 30 }, {
			collide = false,
		})
	end
	-- fans sitting on the side walls, looking in at the track
	local k = 0
	for _, sx in { -1, 1 } do
		for _, z in { -42, -30, -14, 2, 14, 30 } do
			k += 1
			local shirt = SHIRTS[(k % #SHIRTS) + 1]
			local skin = SKIN[(k % #SKIN) + 1]
			local x = sx * W
			add(
				"Party",
				"FanBody",
				v(0.9, 1.1, 0.6),
				v(x, TOP + 0.55, z),
				shirt,
				{ collide = false }
			)
			add(
				"Party",
				"FanHead",
				v(0.7, 0.7, 0.7),
				v(x, TOP + 1.45, z),
				skin,
				{ collide = false }
			)
			-- arms up: cheering
			for _, side in { -1, 1 } do
				add(
					"Party",
					"FanArm",
					v(0.25, 0.8, 0.25),
					v(x, TOP + 1.4, z + side * 0.6),
					shirt,
					{ collide = false, rot = v(side * 25, 0, 0) }
				)
			end
		end
	end
	-- two searchlights at the back corners
	for _, sx in { -1, 1 } do
		add("Party", "SearchBase", v(1.6, 1.2, 1.6), v(sx * (W - 3), 0.6, -D + 3), { 60, 62, 70 }, {
			collide = false,
		})
		add(
			"Party",
			"SearchLamp",
			v(1.2, 1.2, 1.6),
			v(sx * (W - 3), 1.9, -D + 3),
			{ 255, 250, 220 },
			{ collide = false, material = "Neon" }
		)
	end
end

-- Every extra piece for this tier (0 = none).
function PlotLooks.pieces(tier: number): { Piece }
	local out: { Piece } = {}
	local add = Garage.adder(out)
	if tier >= 1 then
		night(add)
	end
	if tier >= 2 then
		snow(add)
	end
	if tier >= 3 then
		party(add)
	end
	return out
end

-- How many lights a tier makes (PointLights on pieces + the 2 searchlights' SpotLights).
function PlotLooks.lightCount(tier: number): number
	local n = 0
	for _, p in PlotLooks.pieces(tier) do
		if p.light then
			n += 1
		end
		if p.name == "SearchLamp" then
			n += 1
		end
	end
	return n
end

return PlotLooks
