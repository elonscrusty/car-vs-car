--!strict
-- Pure lobby geometry (no Roblox types). All numbers are studs, relative to the lobby origin.
-- x = right, z = toward the player's start (+z), floor top is y = 0. The showcase and wall sign
-- are at the back (-z); the spawn is at the front (+z) and looks toward -z.

export type Rect = { x: number, z: number, w: number, d: number } -- centre + full size

local LobbyLayout = {}

LobbyLayout.room = { halfW = 62, halfD = 46, height = 30, wall = 2 }

LobbyLayout.showcase = { x = 0, z = -10, radius = 8, footprint = 22 } -- glowing round platform
LobbyLayout.spawn = { x = 0, z = 34, size = 6 }
LobbyLayout.gacha = { x = -46, z = -22, w = 12, d = 12 }
LobbyLayout.store = { x = -46, z = 12, w = 8, d = 24 }
LobbyLayout.padSize = 14
LobbyLayout.pads = {
	{ x = 44, z = -26 },
	{ x = 44, z = 0 },
	{ x = 44, z = 26 },
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
	}
	for i, p in LobbyLayout.pads do
		out["pad" .. i] = { x = p.x, z = p.z, w = LobbyLayout.padSize, d = LobbyLayout.padSize }
	end
	return out
end

function LobbyLayout.overlaps(a: Rect, b: Rect): boolean
	return math.abs(a.x - b.x) < (a.w + b.w) / 2 and math.abs(a.z - b.z) < (a.d + b.d) / 2
end

function LobbyLayout.insideRoom(r: Rect): boolean
	local room = LobbyLayout.room
	return math.abs(r.x) + r.w / 2 <= room.halfW and math.abs(r.z) + r.d / 2 <= room.halfD
end

-- Unit direction (x, z) the spawn faces: straight at the showcase.
function LobbyLayout.spawnFacing(): (number, number)
	local dx = LobbyLayout.showcase.x - LobbyLayout.spawn.x
	local dz = LobbyLayout.showcase.z - LobbyLayout.spawn.z
	local len = math.sqrt(dx * dx + dz * dz)
	return dx / len, dz / len
end

return LobbyLayout
