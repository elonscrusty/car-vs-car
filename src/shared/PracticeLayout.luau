--!strict
-- The practice yard of the first-time tutorial (carter's L4, L6, L13, L56, L57): a small flat
-- Wreck City junkyard far from the lobby where a new player drives the Ram Truck and smashes 3
-- boxes. Pure data, so the tests can check every number. The client builds it (PracticeYard).
--
-- Studs from the yard origin. x = right, z = toward the car's start (the car starts at +z and drives
-- toward -z), y = up, the floor top is y = 0. NO ramps (L56): the ground is flat.

local PracticeLayout = {}

export type Spot = { x: number, z: number }
export type Block = { x: number, z: number, w: number, d: number, h: number, yawDeg: number }

-- Far from the lobby (0, 500), the old fight arenas and the battle arena (6000, 40, 0).
PracticeLayout.origin = { x = -6000, y = 40, z = 0 }

-- The playable floor, from the middle to the inner face of the walls. The Ram Truck is 16 studs long
-- and tops out at 42 studs a second, so this takes about three seconds to cross.
PracticeLayout.half = { x = 66, z = 50 }
PracticeLayout.wall = { thickness = 4, height = 7 }

-- Where the car starts: near the south wall, nose toward -z (yawDeg 0 = looking toward -z).
PracticeLayout.spawn = { x = 0, z = 38, yawDeg = 0 }

-- The boxes to smash. Big (the car is 16 long) and not in the straight line ahead, so a player has to
-- steer. Seven stand here and three are needed (TutorialConfig.boxesNeeded), so a miss never traps
-- anyone. They do not collide: the car drives through them and they burst.
PracticeLayout.crateSize = 7
PracticeLayout.crates = {
	{ x = -34, z = 12 },
	{ x = 36, z = 6 },
	{ x = -6, z = -18 },
	{ x = 38, z = -28 },
	{ x = -42, z = -26 },
	{ x = 14, z = -38 },
	{ x = -52, z = 30 },
} :: { Spot }

-- Low concrete blocks (solid, Bouncy: a car that hits one is thrown back, never stuck).
PracticeLayout.barriers = {
	{ x = 0, z = 8, w = 20, d = 4, h = 4, yawDeg = 0 },
	{ x = 24, z = -10, w = 4, d = 18, h = 4, yawDeg = 0 },
	{ x = -26, z = -8, w = 4, d = 16, h = 4, yawDeg = 0 },
} :: { Block }

-- The most the car may be from a wall or a barrier edge when a crate stands (the tests keep the
-- boxes clear of everything so each one can be reached from every side).
PracticeLayout.crateClearance = 8

-- Flat floor marks: oil stains (x, z, diameter), tire skids (x, z, length, yawDeg) and the start line.
PracticeLayout.stains = {
	{ x = -12, z = 28, d = 9 },
	{ x = 20, z = 18, d = 7 },
	{ x = -30, z = -2, d = 11 },
	{ x = 8, z = -26, d = 8 },
	{ x = 44, z = -12, d = 10 },
	{ x = -46, z = 8, d = 7 },
}
PracticeLayout.skids = {
	{ x = -4, z = 22, len = 14, yawDeg = 6 },
	{ x = 6, z = 20, len = 12, yawDeg = -4 },
	{ x = 26, z = 2, len = 16, yawDeg = 62 },
	{ x = -18, z = -14, len = 15, yawDeg = 110 },
	{ x = 30, z = -34, len = 14, yawDeg = 24 },
	{ x = -36, z = 20, len = 12, yawDeg = 80 },
	{ x = 0, z = -8, len = 18, yawDeg = 94 },
}
PracticeLayout.startLine = { z = 30, w = 28 }

-- The scrapyard behind the walls (looks only): crushed cars, tire stacks, oil drums, containers,
-- scrap heaps. The same bright toy colors as the lobby's rainbow cones and tires (L22, L29).
export type Junk = { x: number, z: number, yawDeg: number, color: number, seed: number }

-- A crushed car every `step` studs along each wall, `out` studs beyond the wall; every second one
-- has another car stacked on top.
PracticeLayout.junkCarStep = 24
PracticeLayout.junkCarOut = 15

local function aroundWalls(step: number, out: number, kind: number): { Junk }
	local list: { Junk } = {}
	local hx = PracticeLayout.half.x + PracticeLayout.wall.thickness + out
	local hz = PracticeLayout.half.z + PracticeLayout.wall.thickness + out
	local n = 0
	local x = -hx + step / 2
	while x < hx do
		for _, side in { -1, 1 } do
			n += 1
			table.insert(list, {
				x = x,
				z = side * hz,
				yawDeg = if side < 0 then 90 else -90,
				color = (n + kind) % 8 + 1,
				seed = n * 7 + kind,
			})
		end
		x += step
	end
	local z = -hz + step / 2
	while z < hz do
		for _, side in { -1, 1 } do
			n += 1
			table.insert(list, {
				x = side * hx,
				z = z,
				yawDeg = if side < 0 then 0 else 180,
				color = (n + kind) % 8 + 1,
				seed = n * 7 + kind,
			})
		end
		z += step
	end
	return list
end

-- Crushed cars (a flat body, a squashed cabin, two tires).
function PracticeLayout.junkCars(): { Junk }
	return aroundWalls(PracticeLayout.junkCarStep, PracticeLayout.junkCarOut, 0)
end

-- Tire stacks, between the cars and a little further out.
function PracticeLayout.tireStacks(): { Junk }
	local list = aroundWalls(48, PracticeLayout.junkCarOut + 14, 3)
	return list
end

-- Oil drums in pairs near the corners of the yard (inside the walls' shadow, outside the floor).
function PracticeLayout.drums(): { Junk }
	local list: { Junk } = {}
	local hx = PracticeLayout.half.x + PracticeLayout.wall.thickness + 6
	local hz = PracticeLayout.half.z + PracticeLayout.wall.thickness + 6
	local n = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			for k = 0, 2 do
				n += 1
				table.insert(list, {
					x = sx * (hx - 4 - k * 4.2),
					z = sz * (hz - (k % 2) * 4.2),
					yawDeg = 0,
					color = n % 4 + 1,
					seed = n,
				})
			end
		end
	end
	return list
end

-- Big shipping containers far behind the walls: a skyline for the junkyard.
PracticeLayout.containers =
	{
		{ x = -40, z = -92, w = 24, d = 9, h = 9, yawDeg = 0, color = 1 },
		{ x = 20, z = -96, w = 24, d = 9, h = 9, yawDeg = 6, color = 3 },
		{ x = 80, z = -94, w = 24, d = 9, h = 9, yawDeg = -8, color = 5 },
		{ x = -96, z = 20, w = 24, d = 9, h = 9, yawDeg = 90, color = 6 },
		{ x = 100, z = 8, w = 24, d = 9, h = 9, yawDeg = 94, color = 2 },
		{ x = -20, z = 100, w = 24, d = 9, h = 9, yawDeg = 4, color = 4 },
	} :: { { x: number, z: number, w: number, d: number, h: number, yawDeg: number, color: number } }

-- Heaps of scrap in the four corners.
function PracticeLayout.heaps(): { Junk }
	local list: { Junk } = {}
	local hx = PracticeLayout.half.x + PracticeLayout.wall.thickness + 34
	local hz = PracticeLayout.half.z + PracticeLayout.wall.thickness + 30
	local n = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			n += 1
			table.insert(
				list,
				{ x = sx * hx, z = sz * hz, yawDeg = n * 53, color = n, seed = n * 13 }
			)
		end
	end
	return list
end

-- The ground plate under everything: one big plain slab so the camera never sees the world's edge.
PracticeLayout.ground = { half = 520 }

-- The floor room of everything solid or standing, for the "nothing overlaps" tests (centre + size +
-- yaw, like LobbyLayout.Rect). The backdrop's sizes are the ones PracticeYard builds.
export type Rect = { x: number, z: number, w: number, d: number, yawDeg: number }
PracticeLayout.junkCarSize = { w = 6.6, d = 14.2 }
PracticeLayout.tireStackDiameter = 5.4
PracticeLayout.drumDiameter = 3.2
PracticeLayout.heapSize = 16

function PracticeLayout.footprints(): { [string]: Rect }
	local out: { [string]: Rect } = {}
	for i, b in PracticeLayout.barriers do
		out["barrier" .. i] = { x = b.x, z = b.z, w = b.w, d = b.d, yawDeg = b.yawDeg }
	end
	local c = PracticeLayout.crateSize
	for i, k in PracticeLayout.crates do
		out["crate" .. i] = { x = k.x, z = k.z, w = c, d = c, yawDeg = 0 }
	end
	for i, j in PracticeLayout.junkCars() do
		local size = PracticeLayout.junkCarSize
		out["car" .. i] = { x = j.x, z = j.z, w = size.w, d = size.d, yawDeg = j.yawDeg }
	end
	for i, j in PracticeLayout.tireStacks() do
		local d = PracticeLayout.tireStackDiameter
		out["tires" .. i] = { x = j.x, z = j.z, w = d, d = d, yawDeg = 0 }
	end
	for i, j in PracticeLayout.drums() do
		local d = PracticeLayout.drumDiameter
		out["drum" .. i] = { x = j.x, z = j.z, w = d, d = d, yawDeg = 0 }
	end
	for i, k in PracticeLayout.containers do
		out["container" .. i] = { x = k.x, z = k.z, w = k.w, d = k.d, yawDeg = k.yawDeg }
	end
	for i, j in PracticeLayout.heaps() do
		local d = PracticeLayout.heapSize
		out["heap" .. i] = { x = j.x, z = j.z, w = d, d = d, yawDeg = 0 }
	end
	return out
end

-- Where a world position inside the yard stands, in yard coordinates (`x`, `z` from the origin).
function PracticeLayout.inside(x: number, z: number, margin: number): boolean
	return math.abs(x) <= PracticeLayout.half.x - margin
		and math.abs(z) <= PracticeLayout.half.z - margin
end

return PracticeLayout
