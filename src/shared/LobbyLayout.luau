--!strict
-- Pure lobby geometry (no Roblox types). All numbers are studs, relative to the lobby origin.
-- x = right, z = toward the player's start (+z), floor top is y = 0. The lobby is a round arena
-- (radius `room.radius`): big sign and "stand to play" board at the back (-z), store back-left,
-- truck stage back-right, claw machine on the right wall, 4 pads (2x2) in the middle, and the
-- entrance gate at the front (+z) where the spawn is. The spawn looks toward -z.

export type Rect = { x: number, z: number, w: number, d: number } -- centre + full size

local LobbyLayout = {}

LobbyLayout.room = { radius = 60, wallHeight = 9, wall = 2 }

LobbyLayout.showcase = { x = 34, z = -24, radius = 8, footprint = 20 } -- raised truck stage
LobbyLayout.spawn = { x = 0, z = 48, size = 6 }
LobbyLayout.gate = { z = 56, halfOpening = 7 } -- opening in the wall + checkered start line
LobbyLayout.gacha = { x = 50, z = 12, w = 10, d = 12 } -- the claw machine
LobbyLayout.store = { x = -38, z = -26, w = 20, d = 12 }
LobbyLayout.padSize = 16
LobbyLayout.pads = {
	{ x = -18, z = -4 },
	{ x = 18, z = -4 },
	{ x = -18, z = 22 },
	{ x = 18, z = 22 },
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

-- All four corners must be inside the round wall.
function LobbyLayout.insideRoom(r: Rect): boolean
	local limit = LobbyLayout.room.radius - LobbyLayout.room.wall
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local cx, cz = r.x + sx * r.w / 2, r.z + sz * r.d / 2
			if math.sqrt(cx * cx + cz * cz) > limit then
				return false
			end
		end
	end
	return true
end

-- Unit direction (x, z) the spawn faces: straight at the middle of the pads.
function LobbyLayout.spawnFacing(): (number, number)
	local dx = 0 - LobbyLayout.spawn.x
	local dz = 0 - LobbyLayout.spawn.z
	local len = math.sqrt(dx * dx + dz * dz)
	return dx / len, dz / len
end

return LobbyLayout
