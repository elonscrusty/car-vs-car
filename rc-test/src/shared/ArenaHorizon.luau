--!strict
-- The far edge of the arena's world (looks only, nothing to hit), in BIG units (the arena is built
-- big, then scaled to 0.25). Three jobs:
--   1. far ground: a ring of tiles round the middle one (a part is at most 2048 long)
--   2. a haze wall round the far edge, in the sky's haze colour, so the sky's dark lower half never
--      shows past the ground (carter 10-29: "dark blue band")
--   3. a far junkyard skyline: factory blocks, chimneys, cranes (carter picked "cranes and factory city")
-- ArenaBuilder turns the list into parts. Pure data, so the tests can check it.

local ArenaHorizon = {}

export type Piece = {
	name: string,
	shape: string, -- "Block" or "Cylinder" (a cylinder stands up, height = size.Y)
	size: { number },
	pos: { number },
	yaw: number,
	color: { number },
	neon: boolean?, -- glows (lit windows, lamps, flares)
}

ArenaHorizon.MAX_PART = 2048 -- Roblox's longest part side
ArenaHorizon.TILE = 2048
ArenaHorizon.RING = 2 -- tiles out from the middle one: ground reaches RING + 0.5 tiles
ArenaHorizon.EDGE = (ArenaHorizon.RING + 0.5) * ArenaHorizon.TILE -- 5120 big = 1280 RC studs
ArenaHorizon.HAZE_TOP = 240 -- the haze wall stands this high (60 RC studs), above the eye, so no sky gap
ArenaHorizon.GROUND = { 110, 92, 74 } -- dirt; the arena's own ground should match this (the night light darkens it)

-- a small fixed random so the skyline is the same every build
local function lcg(seed: number): () -> number
	local s = seed
	return function()
		s = (s * 16807) % 2147483647
		return s / 2147483647
	end
end

local CITY = { { 142, 138, 134 }, { 154, 142, 130 }, { 126, 122, 120 }, { 164, 154, 140 } }
local CRANE, CRANE_DARK, CHIMNEY = { 216, 160, 32 }, { 85, 85, 92 }, { 168, 106, 80 }

function ArenaHorizon.pieces(hazeColor: { number }): { Piece }
	local out: { Piece } = {}
	local rnd = lcg(5)
	local function add(
		name: string,
		shape: string,
		size: { number },
		pos: { number },
		yaw: number,
		color: { number },
		neon: boolean?
	)
		table.insert(out, {
			name = name,
			shape = shape,
			size = size,
			pos = pos,
			yaw = yaw,
			color = color,
			neon = neon,
		})
	end

	-- 1. far ground tiles (the middle one is the existing far ground)
	local T, R = ArenaHorizon.TILE, ArenaHorizon.RING
	for i = -R, R do
		for j = -R, R do
			if i ~= 0 or j ~= 0 then
				add(
					"FarGround",
					"Block",
					{ T, 2, T },
					{ i * T, -2.6, j * T },
					0,
					ArenaHorizon.GROUND
				)
			end
		end
	end

	-- 2. haze wall: five panels per side, just inside the ground's far edge
	local E = ArenaHorizon.EDGE - 20
	local H = ArenaHorizon.HAZE_TOP
	for k = -2, 2 do
		local c = k * T
		add("HazeWall", "Block", { T, H + 8, 24 }, { c, (H - 8) / 2, -E }, 0, hazeColor)
		add("HazeWall", "Block", { T, H + 8, 24 }, { c, (H - 8) / 2, E }, 0, hazeColor)
		add("HazeWall", "Block", { 24, H + 8, T }, { -E, (H - 8) / 2, c }, 0, hazeColor)
		add("HazeWall", "Block", { 24, H + 8, T }, { E, (H - 8) / 2, c }, 0, hazeColor)
	end

	-- 3. skyline: factory blocks, tall chimneys, cranes (ring radii 2200..2800 big)
	local WINDOW, WINDOW_2 = { 255, 176, 64 }, { 255, 216, 144 }
	for k = 0, 109 do
		local a = k / 110 * math.pi * 2
		local d = 2560 + rnd() * 240
		local w, h = 200 + rnd() * 320, 160 + rnd() * 440
		local x, z = math.cos(a) * d, math.sin(a) * d
		local face = math.atan2(-math.cos(a), -math.sin(a)) -- local Z points at the arena
		add("FarFactory", "Block", { w, h, w }, { x, h / 2, z }, face, CITY[k % 4 + 1])
		if k % 4 ~= 3 then -- a few lit windows on the face toward the arena
			local nx, nz = -math.cos(a), -math.sin(a)
			for _ = 1, 2 + k % 3 do
				local off, wy = (rnd() - 0.5) * w * 0.7, 30 + rnd() * (h - 60)
				add(
					"FarWindow",
					"Block",
					{ 13, 16, 3 },
					{ x + nx * (w / 2 + 1) - nz * off, wy, z + nz * (w / 2 + 1) + nx * off },
					face,
					if rnd() > 0.25 then WINDOW else WINDOW_2,
					true
				)
			end
		end
	end
	for k = 0, 13 do
		local a, d, h = rnd() * math.pi * 2, 2480 + rnd() * 320, 680 + rnd() * 640
		local x, z = math.cos(a) * d, math.sin(a) * d
		add(
			"FarChimney",
			"Cylinder",
			{ 56, h, 56 },
			{ x, h / 2, z },
			0,
			if k % 3 == 0 then CITY[1] else CHIMNEY
		)
		if k % 3 == 0 then -- a flare burning on top
			add("FarFlare", "Block", { 64, 120, 64 }, { x, h + 60, z }, 0, { 255, 122, 26 }, true)
			add("FarFlare", "Block", { 36, 104, 36 }, { x, h + 140, z }, 0, { 255, 208, 112 }, true)
		end
	end
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2 + rnd() * 0.4
		local d, h = 2240 + rnd() * 240, 600 + rnd() * 280
		local x, z = math.cos(a) * d, math.sin(a) * d
		add("FarCrane", "Block", { 32, h, 32 }, { x, h / 2, z }, 0, CRANE)
		add("FarCrane", "Block", { 32, 32, 32 }, { x, h, z }, 0, CRANE_DARK)
		add("FarCrane", "Block", { 520, 32, 32 }, { x + rnd() * 120, h + 16, z }, a + 0.4, CRANE)
		add("FarCrane", "Block", { 12, 240, 12 }, { x + 220, h - 120, z }, 0, { 68, 68, 72 })
		add("FarCraneLamp", "Block", { 20, 20, 20 }, { x, h + 44, z }, 0, { 255, 42, 42 }, true)
	end
	return out
end

return ArenaHorizon
