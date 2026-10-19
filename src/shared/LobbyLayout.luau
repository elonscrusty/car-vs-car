--!strict
-- Pure lobby geometry (no Roblox types). All numbers are studs, relative to the lobby origin.
-- x = right, z = toward the player's start (+z), floor top is y = 0. The spawn looks toward -z.

export type Rect = { x: number, z: number, w: number, d: number } -- centre + full size

local LobbyLayout = {}

-- The lobby is a huge race HQ warehouse (192 long so 8 big open garages fit): a wide open bay door at the front (+z) and the spawn on a
-- cyan pad, a cyan-lined lane up the middle to the hero truck on its round stage under the big
-- sign on the back wall, the 4 fight pads as 2 x 2 (two each side of the lane), a garage for
-- every player down both side walls (A1-A4 left, B1-B4 right) at the back, the store at the front
-- left, the paint / customize booth at the front right and the gumball machine on the back wall in the right corner.
-- The hall is `room.halfW` * 2 wide and `room.halfL` * 2 long (inside the walls); the roof is
-- `room.wallHeight + room.upper` high.
LobbyLayout.room = { halfW = 64, halfL = 96, wallHeight = 18, upper = 22, wall = 2 }

LobbyLayout.gate = { z = 94, halfOpening = 24 } -- open bay door: the way in
LobbyLayout.spawn = { x = 0, z = 76, size = 6 } -- 18 studs from the door, so the camera behind the player stays inside the hall
LobbyLayout.lane = { halfWidth = 7, fromZ = 72, toZ = -20 } -- cyan lines from the spawn to the stage
LobbyLayout.padSize = 18
-- Pads 01 (left back), 02 (left front), 03 (right back), 04 (right front).
LobbyLayout.pads = {
	{ x = -27, z = -4 },
	{ x = -27, z = 20 },
	{ x = 27, z = -4 },
	{ x = 27, z = 20 },
}
LobbyLayout.showcase = { x = 0, z = -40, radius = 16, footprint = 40 } -- hero truck stage
-- Booths on the side walls. They are built facing +z, then turned `yaw` degrees (90 turns the
-- front toward +x). w / d are the size before turning.
LobbyLayout.store = { x = -50, z = 80, w = 20, d = 12, yaw = 90 } -- front left
LobbyLayout.paint = { x = 50, z = 80, w = 20, d = 12, yaw = -90 } -- front right
LobbyLayout.gacha = { x = 50, z = -89, w = 14, d = 12 } -- the gumball machine: on the back wall, right corner
-- Garages: one per player, built INTO the side walls: each is a big recessed room with an OPEN front
-- (a low wall with a wide gap in the middle, so players just walk in). 4 down each side
-- (1-4 = A1-A4 on the left, 5-8 = B1-B4 on the right). `face` is the way a garage opens
-- (+1 = toward +x, the left wall; -1 = toward -x). x is the garage centre, outside the hall.
LobbyLayout.bay = { w = 30, d = 40, gap = 14, wallHeight = 1.8 } -- w = depth into the wall (x), d = width along the wall (z), gap = the walk-in opening in the low front wall
LobbyLayout.bays = {
	{ x = -79, z = -66, face = 1 },
	{ x = -79, z = -26, face = 1 },
	{ x = -79, z = 14, face = 1 },
	{ x = -79, z = 54, face = 1 },
	{ x = 79, z = -66, face = -1 },
	{ x = 79, z = -26, face = -1 },
	{ x = 79, z = 14, face = -1 },
	{ x = 79, z = 54, face = -1 },
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
