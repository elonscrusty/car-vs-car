--!strict
-- Pure lobby geometry (no Roblox types). All numbers are studs, relative to the lobby origin.
-- x = right, z = toward the player's start (+z), floor top is y = 0. The spawn looks toward -z.

export type Rect = { x: number, z: number, w: number, d: number } -- centre + full size

local LobbyLayout = {}

-- The lobby is a huge race HQ warehouse: a wide open bay door at the front (+z), the 4 fight pads
-- in a row just inside (a starting grid), the hero truck turning on a big stage in the middle,
-- a raised walkway (mezzanine) with the giant sign along the back wall, a garage bay for every player down both side walls, the claw machine and a lounge on the right wall, the store at the back left.
-- The hall is `room.halfW` * 2 wide and `room.halfL` * 2 long (inside the walls); the roof is
-- `room.wallHeight + room.upper` high.
LobbyLayout.room = { halfW = 90, halfL = 70, wallHeight = 9, upper = 30, wall = 2 }

LobbyLayout.gate = { z = 68, halfOpening = 24 } -- open bay door: the way in
LobbyLayout.spawn = { x = 0, z = 54, size = 6 }
LobbyLayout.padSize = 18
LobbyLayout.pads = {
	{ x = -36, z = 28 },
	{ x = -12, z = 28 },
	{ x = 12, z = 28 },
	{ x = 36, z = 28 },
}
LobbyLayout.showcase = { x = 0, z = -16, radius = 14, footprint = 34 } -- hero truck stage
LobbyLayout.store = { x = -68, z = -64, w = 20, d = 12 } -- back wall, left
LobbyLayout.gacha = { x = 84, z = -30, w = 10, d = 12 } -- the claw machine (right wall)
-- Garage bays: one open bay per player, 4 down each side wall on the floor. `face` is the way the
-- bay opens (+1 = toward +x, the left wall bays; -1 = toward -x). Index = bay number.
LobbyLayout.bay = { w = 20, d = 18 } -- w = depth from the wall (x), d = width along the wall (z)
LobbyLayout.bays = {
	{ x = -66, z = -44, face = 1 },
	{ x = -66, z = -24, face = 1 },
	{ x = -66, z = -4, face = 1 },
	{ x = -66, z = 16, face = 1 },
	{ x = 66, z = -44, face = -1 },
	{ x = 66, z = -24, face = -1 },
	{ x = 66, z = -4, face = -1 },
	{ x = 66, z = 16, face = -1 },
}
-- Raised walkway along the back wall (look from above at the stage), reached by two ramps.
LobbyLayout.mezzanine = { x = 0, z = -64, w = 106, d = 10, height = 12 }
LobbyLayout.ramps = {} -- none: the walkway is only for looking at; the floor is for the bays

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
	}
	for i, b in LobbyLayout.bays do
		out["bay" .. i] = { x = b.x, z = b.z, w = LobbyLayout.bay.w, d = LobbyLayout.bay.d }
	end
	for i, r in LobbyLayout.ramps do
		out["ramp" .. i] = { x = r.x, z = r.z, w = r.w, d = r.d }
	end
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
