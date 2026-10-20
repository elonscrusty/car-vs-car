--!strict
-- The green glow line that walks a new player to the gumball machine and to a PLAY pad (carter's
-- L1, L18, L53). Pure route finding over everything solid in the lobby, so the tests can check that
-- a route never runs into a bench, a stand or a pad. Coordinates are studs from the lobby origin
-- (x right, z toward the spawn), like LobbyLayout.

-- Sibling loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require -- relative string paths only exist in Lune
	return luneRequire("./" .. name)
end

local Layout = sibling("LobbyLayout")
local Props = sibling("LobbyProps")
local Config = sibling("TutorialConfig")

local GuidePath = {}

export type Rect = { x: number, z: number, w: number, d: number, yawDeg: number } -- like LobbyLayout.Rect
export type Point = { x: number, z: number }
export type Mark = { x: number, z: number, dx: number, dz: number } -- dx, dz: unit direction

GuidePath.cell = 2 -- grid step (studs)
GuidePath.clearance = 2.2 -- a route keeps this far from every solid thing (a player is ~2 studs wide)

-- The grid covers the plaza inside its tire wall, plus the front path out to the entrance arch.
local MIN_X, MAX_X = -84, 84
local MIN_Z, MAX_Z = -67, 62
local W = math.ceil((MAX_X - MIN_X) / GuidePath.cell)
local H = math.ceil((MAX_Z - MIN_Z) / GuidePath.cell)

-- True when (x, z) is inside the rectangle (centre + size + yaw) grown by `margin`.
function GuidePath.insideRect(r: Rect, x: number, z: number, margin: number): boolean
	local c, s = math.cos(math.rad(r.yawDeg)), math.sin(math.rad(r.yawDeg))
	local dx, dz = x - r.x, z - r.z
	-- the rectangle's local axes in world space: u = (c, -s), v = (s, c)
	local u = dx * c - dz * s
	local v = dx * s + dz * c
	return math.abs(u) <= r.w / 2 + margin and math.abs(v) <= r.d / 2 + margin
end

local function cellOf(x: number, z: number): (number, number)
	return math.floor((x - MIN_X) / GuidePath.cell), math.floor((z - MIN_Z) / GuidePath.cell)
end

local function centerOf(ix: number, iz: number): (number, number)
	return MIN_X + (ix + 0.5) * GuidePath.cell, MIN_Z + (iz + 0.5) * GuidePath.cell
end

local function indexOf(ix: number, iz: number): number
	return iz * W + ix + 1
end

local function inGrid(ix: number, iz: number): boolean
	return ix >= 0 and ix < W and iz >= 0 and iz < H
end

-- The things a walker cannot cross, built once: `solid[i]` for everything but the pads, `padBits[i]`
-- for the pad circles (bit k set = cell is inside pad k's grown circle), so a route to one pad may
-- still end inside it while every other pad stays closed.
local solid: { boolean }? = nil
local padBits: { number }? = nil

local function build()
	local blocked: { boolean } = table.create(W * H, false)
	local pads: { number } = table.create(W * H, 0)
	local margin = GuidePath.clearance
	local rects: { Rect } = {}
	for name, r in Layout.footprints() do
		if name ~= "ring" then -- the ring is a walkable island; only its pads are closed
			table.insert(rects, r)
		end
	end
	for _, r in Props.footprints() do
		table.insert(rects, r)
	end
	local padList = Layout.pads()
	local padR = Layout.padRadius + Layout.padSlack + margin
	for iz = 0, H - 1 do
		for ix = 0, W - 1 do
			local x, z = centerOf(ix, iz)
			local i = indexOf(ix, iz)
			-- the tire wall, the grass and the world outside the plaza (the entrance path stays open)
			local outside = x < MIN_X + margin or x > MAX_X - margin or z < MIN_Z + margin
			local beyondEntrance = z > 56 and math.abs(x) > Layout.paths[1].w / 2
			if outside or beyondEntrance then
				blocked[i] = true
			end
			if not blocked[i] then
				for _, r in rects do
					if GuidePath.insideRect(r, x, z, margin) then
						blocked[i] = true
						break
					end
				end
			end
			local bits = 0
			for k, p in padList do
				if (p.x - x) ^ 2 + (p.z - z) ^ 2 <= padR * padR then
					bits = bit32.bor(bits, bit32.lshift(1, k - 1))
				end
			end
			pads[i] = bits
		end
	end
	solid, padBits = blocked, pads
end

local function isBlocked(ix: number, iz: number, openPad: number?): boolean
	if not inGrid(ix, iz) then
		return true
	end
	if solid == nil then
		build()
	end
	local i = indexOf(ix, iz)
	if (solid :: { boolean })[i] then
		return true
	end
	local bits = (padBits :: { number })[i]
	if bits ~= 0 then
		local keep = if openPad then bit32.lshift(1, openPad - 1) else 0
		if bit32.band(bits, bit32.bnot(keep)) ~= 0 then
			return true
		end
	end
	return false
end

-- Is the point itself free (not inside anything solid or any pad but `openPad`)?
function GuidePath.free(x: number, z: number, openPad: number?): boolean
	local ix, iz = cellOf(x, z)
	return not isBlocked(ix, iz, openPad)
end

-- The free cell nearest to (x, z), searching outward ring by ring; nil only if the grid is full.
local function nearestFree(x: number, z: number, openPad: number?): (number?, number?)
	local ix, iz = cellOf(x, z)
	ix = math.clamp(ix, 0, W - 1)
	iz = math.clamp(iz, 0, H - 1)
	if not isBlocked(ix, iz, openPad) then
		return ix, iz
	end
	local bestX, bestZ, bestD = nil, nil, math.huge
	for radius = 1, math.max(W, H) do
		for dz = -radius, radius do
			for dx = -radius, radius do
				if math.max(math.abs(dx), math.abs(dz)) == radius then
					local cx, cz = ix + dx, iz + dz
					if not isBlocked(cx, cz, openPad) then
						local d = dx * dx + dz * dz
						if d < bestD then
							bestX, bestZ, bestD = cx, cz, d
						end
					end
				end
			end
		end
		if bestX ~= nil then
			return bestX, bestZ
		end
	end
	return nil, nil
end

-- A minimal binary min-heap of { priority, cell index }.
local function heapPush(heap: { { number } }, item: { number })
	table.insert(heap, item)
	local i = #heap
	while i > 1 do
		local parent = i // 2
		if heap[parent][1] <= heap[i][1] then
			break
		end
		heap[parent], heap[i] = heap[i], heap[parent]
		i = parent
	end
end

local function heapPop(heap: { { number } }): { number }?
	local n = #heap
	if n == 0 then
		return nil
	end
	local top = heap[1]
	heap[1] = heap[n]
	heap[n] = nil
	n -= 1
	local i = 1
	while true do
		local l, r = i * 2, i * 2 + 1
		local smallest = i
		if l <= n and heap[l][1] < heap[smallest][1] then
			smallest = l
		end
		if r <= n and heap[r][1] < heap[smallest][1] then
			smallest = r
		end
		if smallest == i then
			break
		end
		heap[smallest], heap[i] = heap[i], heap[smallest]
		i = smallest
	end
	return top
end

local SQRT2 = math.sqrt(2)
local NEIGHBORS = {
	{ 1, 0, 1 },
	{ -1, 0, 1 },
	{ 0, 1, 1 },
	{ 0, -1, 1 },
	{ 1, 1, SQRT2 },
	{ 1, -1, SQRT2 },
	{ -1, 1, SQRT2 },
	{ -1, -1, SQRT2 },
}

-- A* over the grid: the cells from start to goal (inclusive), or nil.
local function search(sx: number, sz: number, gx: number, gz: number, openPad: number?): { Point }?
	local startI, goalI = indexOf(sx, sz), indexOf(gx, gz)
	local g: { [number]: number } = { [startI] = 0 }
	local from: { [number]: number } = {}
	local closed: { [number]: boolean } = {}
	local heap: { { number } } = {}
	heapPush(heap, { 0, startI })
	while true do
		local item = heapPop(heap)
		if item == nil then
			return nil
		end
		local cur = item[2]
		if cur == goalI then
			break
		end
		if not closed[cur] then
			closed[cur] = true
			local cx, cz = (cur - 1) % W, (cur - 1) // W
			for _, n in NEIGHBORS do
				local nx, nz = cx + n[1], cz + n[2]
				if not isBlocked(nx, nz, openPad) then
					-- no cutting a corner between two blocked cells
					local diagonal = n[1] ~= 0 and n[2] ~= 0
					if
						not diagonal
						or (
							not isBlocked(cx + n[1], cz, openPad)
							and not isBlocked(cx, cz + n[2], openPad)
						)
					then
						local ni = indexOf(nx, nz)
						local cost = (g[cur] :: number) + n[3]
						if g[ni] == nil or cost < g[ni] then
							g[ni] = cost
							from[ni] = cur
							local dx, dz = gx - nx, gz - nz
							heapPush(heap, { cost + math.sqrt(dx * dx + dz * dz), ni })
						end
					end
				end
			end
		end
	end
	local cells: { Point } = {}
	local i: number? = goalI
	while i ~= nil do
		local x, z = centerOf((i - 1) % W, (i - 1) // W)
		table.insert(cells, 1, { x = x, z = z })
		i = from[i]
	end
	return cells
end

-- Is the straight line between two points free all the way (sampled every half cell)?
local function clear(a: Point, b: Point, openPad: number?): boolean
	local dx, dz = b.x - a.x, b.z - a.z
	local len = math.sqrt(dx * dx + dz * dz)
	local steps = math.max(1, math.ceil(len / (GuidePath.cell * 0.5)))
	for k = 1, steps - 1 do
		local t = k / steps
		if not GuidePath.free(a.x + dx * t, a.z + dz * t, openPad) then
			return false
		end
	end
	return true
end

-- Straightens a grid path: from each point jump to the farthest later point that can be seen.
local function pull(cells: { Point }, openPad: number?): { Point }
	local out: { Point } = { cells[1] }
	local at = 1
	while at < #cells do
		local far = at + 1
		for k = #cells, at + 2, -1 do
			if clear(cells[at], cells[k], openPad) then
				far = k
				break
			end
		end
		table.insert(out, cells[far])
		at = far
	end
	return out
end

-- The walking route from (fromX, fromZ) to (toX, toZ): a list of points, first = the start, last =
-- the target. `openPad` (1..4) is the pad the route may end on; every other pad is avoided. The
-- second result is false when no way exists (the player is shut in a pocket): the route is then just
-- the straight line (a green line is better than none).
function GuidePath.route(
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	openPad: number?
): ({ Point }, boolean)
	local start: Point = { x = fromX, z = fromZ }
	local goal: Point = { x = toX, z = toZ }
	local sx, sz = nearestFree(fromX, fromZ, openPad)
	local gx, gz = nearestFree(toX, toZ, openPad)
	if sx == nil or sz == nil or gx == nil or gz == nil then
		return { start, goal }, false
	end
	local cells = search(sx, sz, gx, gz, openPad)
	if cells == nil then
		return { start, goal }, false
	end
	if #cells == 1 then
		return { start, goal }, true
	end
	-- the exact start and goal replace the first and last cell middles
	cells[1] = start
	cells[#cells] = goal
	return pull(cells, openPad), true
end

-- To the front of the gumball machine (TutorialConfig.gumballStop).
function GuidePath.toGumball(fromX: number, fromZ: number): ({ Point }, boolean)
	return GuidePath.route(fromX, fromZ, Config.gumballStop.x, Config.gumballStop.z, nil)
end

-- The pad nearest to a point (straight line), and the route to the middle of it.
function GuidePath.toNearestPad(fromX: number, fromZ: number): (number, { Point }, boolean)
	local best, bestD = 1, math.huge
	for k, p in Layout.pads() do
		local d = (p.x - fromX) ^ 2 + (p.z - fromZ) ^ 2
		if d < bestD - 1e-6 then
			best, bestD = k, d
		end
	end
	local pad = Layout.pads()[best]
	local route, found = GuidePath.route(fromX, fromZ, pad.x, pad.z, best)
	return best, route, found
end

function GuidePath.length(route: { Point }): number
	local total = 0
	for i = 2, #route do
		local a, b = route[i - 1], route[i]
		total += math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
	end
	return total
end

-- Points every `spacing` studs along a route, starting `offset` studs in (0 <= offset < spacing),
-- each with the direction of the walk there. Moving `offset` forward over time makes the chevrons
-- flow toward the target.
function GuidePath.marks(route: { Point }, spacing: number, offset: number): { Mark }
	local out: { Mark } = {}
	local walked = 0 -- distance at the start of the current segment
	local nextAt = offset
	for i = 2, #route do
		local a, b = route[i - 1], route[i]
		local dx, dz = b.x - a.x, b.z - a.z
		local len = math.sqrt(dx * dx + dz * dz)
		if len > 1e-6 then
			local ux, uz = dx / len, dz / len
			while nextAt < walked + len do
				local t = nextAt - walked
				table.insert(out, { x = a.x + ux * t, z = a.z + uz * t, dx = ux, dz = uz })
				nextAt += spacing
			end
			walked += len
		end
	end
	return out
end

return GuidePath
