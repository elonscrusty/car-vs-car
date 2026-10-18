--!strict
-- Pure lobby geometry (no Roblox types). All numbers are studs, relative to the lobby origin.
-- x = right, z = toward the player's start (+z), floor top is y = 0. The spawn looks toward -z.

export type Rect = { x: number, z: number, w: number, d: number } -- centre + full size

local LobbyLayout = {}

-- The lobby is a huge race HQ warehouse: a wide open bay door at the front (+z) and the spawn on a
-- cyan pad, a cyan-lined lane up the middle to the hero truck on its round stage under the big
-- sign on the back wall, the 4 fight pads as 2 x 2 (two each side of the lane), a garage for
-- every player down both side walls (A1-A4 left, B1-B4 right) at the back, the store at the front
-- left, the paint / customize booth at the front right and the claw machine in the front right corner.
-- The hall is `room.halfW` * 2 wide and `room.halfL` * 2 long (inside the walls); the roof is
-- `room.wallHeight + room.upper` high.
LobbyLayout.room = { halfW = 90, halfL = 70, wallHeight = 9, upper = 30, wall = 2 }

LobbyLayout.gate = { z = 68, halfOpening = 24 } -- open bay door: the way in
LobbyLayout.spawn = { x = 0, z = 58, size = 6 }
LobbyLayout.lane = { halfWidth = 7, fromZ = 52, toZ = -20 } -- cyan lines from the spawn to the stage
LobbyLayout.padSize = 18
-- Pads 01 (left back), 02 (left front), 03 (right back), 04 (right front).
LobbyLayout.pads = {
	{ x = -27, z = -4 },
	{ x = -27, z = 20 },
	{ x = 27, z = -4 },
	{ x = 27, z = 20 },
}
LobbyLayout.showcase = { x = 0, z = -40, radius = 14, footprint = 34 } -- hero truck stage
-- Booths on the side walls. They are built facing +z, then turned `yaw` degrees (90 turns the
-- front toward +x). w / d are the size before turning.
LobbyLayout.store = { x = -72, z = 40, w = 20, d = 12, yaw = 90 } -- front left
LobbyLayout.paint = { x = 72, z = 40, w = 20, d = 12, yaw = -90 } -- front right
LobbyLayout.gacha = { x = 82, z = 62, w = 10, d = 12 } -- the claw machine (front right corner)
-- Garages: one open bay per player, 4 down each side wall on the floor. `face` is the way the
-- bay opens (+1 = toward +x, the left wall bays; -1 = toward -x). Index = bay number
-- (1-4 = A1-A4, 5-8 = B1-B4).
LobbyLayout.bay = { w = 20, d = 18 } -- w = depth from the wall (x), d = width along the wall (z)
LobbyLayout.bays = {
	{ x = -66, z = -58, face = 1 },
	{ x = -66, z = -38, face = 1 },
	{ x = -66, z = -18, face = 1 },
	{ x = -66, z = 2, face = 1 },
	{ x = 66, z = -58, face = -1 },
	{ x = 66, z = -38, face = -1 },
	{ x = 66, z = -18, face = -1 },
	{ x = 66, z = 2, face = -1 },
}

-- "A1".."A4" for the left garages, "B1".."B4" for the right ones.
function LobbyLayout.bayName(i: number): string
	return if i <= 4 then "A" .. i else "B" .. (i - 4)
end

-- A booth's footprint after it is turned (a quarter turn swaps width and depth).
local function turned(b: { x: number, z: number, w: number, d: number, yaw: number }): Rect
	if math.abs(b.yaw) == 90 then
		return { x = b.x, z = b.z, w = b.d, d = b.w }
	end
	return { x = b.x, z = b.z, w = b.w, d = b.d }
end

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
		store = turned(LobbyLayout.store),
		paint = turned(LobbyLayout.paint),
	}
	for i, b in LobbyLayout.bays do
		out["bay" .. i] = { x = b.x, z = b.z, w = LobbyLayout.bay.w, d = LobbyLayout.bay.d }
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

-- Unit direction (x, z) the spawn faces: straight up the lane at the hero stage.
function LobbyLayout.spawnFacing(): (number, number)
	local dx = LobbyLayout.showcase.x - LobbyLayout.spawn.x
	local dz = LobbyLayout.showcase.z - LobbyLayout.spawn.z
	local len = math.sqrt(dx * dx + dz * dz)
	return dx / len, dz / len
end

return LobbyLayout
