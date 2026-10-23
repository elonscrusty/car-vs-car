--!strict
-- Low-poly hills that close the lobby in on its three dry sides (left, right and the spawn end),
-- in three rising rows (near: low and bright, far: tall and hazy), with trees on the near two.
-- The lake is on the LobbyLayout.LAKE_SIDE end; the side hills run on past it a little so the
-- lake sits in a valley. Nothing stands inside LobbyLayout.ground().
-- Pure placement (plain numbers, Lune tests load this); LobbyHillsBuilder turns it into parts.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local LobbyLayout = sibling("LobbyLayout")

export type Hill = {
	x: number, -- middle of its foot
	z: number,
	w: number, -- size: across (along its side), up, deep (away from the lobby)
	h: number,
	d: number,
	turn: number, -- degrees about y
	row: number, -- 1 near, 2 middle, 3 far
	r: number, -- colour 0-255
	g: number,
	b: number,
}
export type Tree = { mesh: string, x: number, y: number, z: number, height: number, turn: number }

local LobbyHills = {}

-- per row: gap from the ground edge to the hill's foot middle, hill size ranges, colour
LobbyHills.ROWS = {
	{ out = 14, w = { 34, 46 }, h = { 12, 18 }, d = { 26, 34 }, color = { 112, 190, 86 } },
	{ out = 40, w = { 52, 70 }, h = { 26, 38 }, d = { 40, 52 }, color = { 92, 166, 90 } },
	{ out = 76, w = { 80, 110 }, h = { 46, 64 }, d = { 60, 76 }, color = { 116, 156, 130 } },
}
LobbyHills.PAST_LAKE = 70 -- the side hills reach this far past the lake end of ground()
LobbyHills.MAX_HILLS = 160
LobbyHills.MAX_TREES = 200

local function rng(seed: number): (number, number) -> number
	local state = seed
	return function(lo: number, hi: number): number
		state = (state * 1103515245 + 12345) % 2147483648
		return lo + (hi - lo) * (state / 2147483648)
	end
end

-- Height of a hill's top surface at (x, z), or nil off it (a dome: high in the middle).
function LobbyHills.surface(hill: Hill, x: number, z: number): number?
	local a = math.rad(hill.turn)
	local c, s = math.cos(a), math.sin(a)
	local dx, dz = x - hill.x, z - hill.z
	-- into the hill's own axes (same turn as CFrame.Angles(0, turn, 0))
	local u = dx * c - dz * s
	local v = dx * s + dz * c
	local r2 = (u / (hill.w / 2)) ^ 2 + (v / (hill.d / 2)) ^ 2
	if r2 >= 1 then
		return nil
	end
	return hill.h * (1 - r2)
end

function LobbyHills.layout(): ({ Hill }, { Tree })
	local hills: { Hill } = {}
	local trees: { Tree } = {}
	local rand = rng(20261023 + 17)
	local g = LobbyLayout.ground()
	local lake = LobbyLayout.LAKE_SIDE or 1
	-- the dry end is the one away from the lake
	local endZ = if lake > 0 then g.minZ else g.maxZ
	local farZ = if lake > 0 then g.maxZ + LobbyHills.PAST_LAKE else g.minZ - LobbyHills.PAST_LAKE
	local inward = if lake > 0 then 1 else -1 -- from the dry end toward the lake

	for row, spec in LobbyHills.ROWS do
		local function hill(x: number, z: number, turn: number)
			local h: Hill = {
				x = x,
				z = z,
				w = rand(spec.w[1], spec.w[2]),
				h = rand(spec.h[1], spec.h[2]),
				d = rand(spec.d[1], spec.d[2]),
				turn = turn + rand(-12, 12),
				row = row,
				r = spec.color[1] + rand(-8, 8),
				g = spec.color[2] + rand(-8, 8),
				b = spec.color[3] + rand(-6, 6),
			}
			table.insert(hills, h)
		end
		local step = (spec.w[1] + spec.w[2]) / 2 * 0.62 -- overlap so there are no gaps
		local wobble = step * 0.15
		-- left and right sides: from behind the dry end to past the lake
		for _, side in { -1, 1 } do
			local x = if side < 0 then g.minX - spec.out else g.maxX + spec.out
			local z = endZ - inward * spec.out
			while (z - farZ) * inward < 0 do
				hill(x + rand(-wobble, wobble), z + rand(-wobble, wobble), 90)
				z += inward * step
			end
		end
		-- the dry end: across, corner to corner
		local zEnd = endZ - inward * spec.out
		local x = g.minX - spec.out + step
		while x < g.maxX + spec.out - step / 2 do
			hill(x + rand(-wobble, wobble), zEnd + rand(-wobble, wobble), 0)
			x += step
		end
	end

	-- trees on the near two rows: a few on each hill's lobby-facing slope and top
	local mid = { x = (g.minX + g.maxX) / 2, z = (g.minZ + g.maxZ) / 2 }
	for _, h in hills do
		if h.row <= 2 then
			local n = if h.row == 1 then math.floor(rand(1, 2.99)) else math.floor(rand(1, 3.99))
			for _ = 1, n do
				-- a spot on the hill, pulled toward the lobby side so it shows
				local a = rand(0, math.pi * 2)
				local rr = rand(0.1, 0.6)
				local tx = h.x + math.cos(a) * h.w / 2 * rr
				local tz = h.z + math.sin(a) * h.d / 2 * rr
				local dx, dz = mid.x - h.x, mid.z - h.z
				local len = math.sqrt(dx * dx + dz * dz)
				tx += dx / len * h.d * 0.12
				tz += dz / len * h.d * 0.12
				local y = LobbyHills.surface(h, tx, tz)
				-- stay off the lobby grass and only on this hill
				local onGround = tx > g.minX and tx < g.maxX and tz > g.minZ and tz < g.maxZ
				if y and not onGround then
					local s = if h.row == 1 then rand(0.9, 1.25) else rand(1.2, 1.6)
					local pine = rand(0, 1) < 0.55
					table.insert(trees, {
						mesh = if pine then "PineTree" else "LeafyTree",
						x = tx,
						y = y - 0.6,
						z = tz,
						height = (if pine then 13 else 12) * s,
						turn = rand(0, 360),
					})
				end
			end
		end
	end
	return hills, trees
end

return LobbyHills
