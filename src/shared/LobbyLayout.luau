--!strict
-- Pure lobby geometry (no Roblox types). All numbers are studs, relative to the lobby origin.
-- x = right, z = toward the player's start (+z), floor top is y = 0. The spawn looks toward -z.

export type Rect = { x: number, z: number, w: number, d: number } -- centre + full size

local LobbyLayout = {}

-- The lobby is a wide garage showroom: you walk in through the roller door at the front (+z), the
-- 4 fight pads stand in a row right ahead like a starting grid, the hero truck turns on a stage
-- in the middle, and the shops line the back and side walls.
-- The hall is `room.halfW` * 2 wide and `room.halfL` * 2 long (inside the walls).
LobbyLayout.room = { halfW = 60, halfL = 46, wallHeight = 9, wall = 2 }

LobbyLayout.showcase = { x = 0, z = -14, radius = 10, footprint = 24 } -- raised truck stage (middle)
LobbyLayout.spawn = { x = 0, z = 34, size = 6 }
LobbyLayout.gate = { z = 44, halfOpening = 11 } -- roller door opening + checkered start line
LobbyLayout.gacha = { x = 53, z = -24, w = 10, d = 12 } -- the claw machine (right wall)
LobbyLayout.store = { x = -44, z = -40, w = 20, d = 12 } -- back wall, left
LobbyLayout.lift = { x = -50, z = 6, w = 18, d = 16 } -- car lift with a car (left wall)
LobbyLayout.padSize = 15
LobbyLayout.pads = {
	{ x = -27, z = 16 },
	{ x = -9, z = 16 },
	{ x = 9, z = 16 },
	{ x = 27, z = 16 },
}

-- Footprints that must not overlap each other (floor level things only).
function LobbyLayout.footprints(): { [string]: Rect }
	local s = LobbyLayout.showcase
	local sp = LobbyLayout.spawn
	local out: { [string]: Rect } = {
		showcase = { x = s.x, z = s.z, w = s.footprint, d = s.footprint },
		spawn = { x = sp.x, z = sp.z, w = sp.size, d = sp.size },
		gacha = {
			x = LobbyLayout.gacha.x,
			z = LobbyLayout.gacha.z,
			w = LobbyLayout.gacha.w,
			d = LobbyLayout.gacha.d,
		},
		store = {
			x = LobbyLayout.store.x,
			z = LobbyLayout.store.z,
			w = LobbyLayout.store.w,
			d = LobbyLayout.store.d,
		},
		lift = {
			x = LobbyLayout.lift.x,
			z = LobbyLayout.lift.z,
			w = LobbyLayout.lift.w,
			d = LobbyLayout.lift.d,
		},
	}
	for i, p in LobbyLayout.pads do
		out["pad" .. i] = { x = p.x, z = p.z, w = LobbyLayout.padSize, d = LobbyLayout.padSize }
	end
	return out
end

function LobbyLayout.overlaps(a: Rect, b: Rect): boolean
	return math.abs(a.x - b.x) < (a.w + b.w) / 2 and math.abs(a.z - b.z) < (a.d + b.d) / 2
end

-- All four corners must be inside the hall walls.
function LobbyLayout.insideRoom(r: Rect): boolean
	local room = LobbyLayout.room
	return math.abs(r.x) + r.w / 2 <= room.halfW and math.abs(r.z) + r.d / 2 <= room.halfL
end

-- Unit direction (x, z) the spawn faces: straight at the middle of the row of pads.
function LobbyLayout.spawnFacing(): (number, number)
	local dx = 0 - LobbyLayout.spawn.x
	local dz = LobbyLayout.pads[1].z - LobbyLayout.spawn.z
	local len = math.sqrt(dx * dx + dz * dz)
	return dx / len, dz / len
end

return LobbyLayout
