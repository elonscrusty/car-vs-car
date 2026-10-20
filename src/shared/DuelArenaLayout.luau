--!strict
-- "Duel Car Arena": the 1v1 battle map from carter's reference sheet, dressed up to his picks
-- (docs/DUEL_ARENA_SPEC.md). Pure data, no Roblox objects, so the tests can check every number.
-- The server builds it in DuelArena.
--
-- Arena-local studs: x runs along the long side (between the two start pads), z across, y up; the
-- floor top is y = 0. The playable floor is a rounded rectangle (170 x 120): a car at about 45
-- studs per second crosses the long way in about 4 seconds. The garages stand behind the two end
-- walls, their doors look into the arena; trees, rocks, paths, hills and light towers fill the
-- grass round it.

local Layout = {}

Layout.halfX = 85 -- playable floor, inner face of the walls
Layout.halfZ = 60
Layout.corner = 24 -- radius of the rounded corners
Layout.wallHeight = 7 -- car height: a car bounces off it, nothing more
Layout.wallThickness = 4
Layout.totalX = 240 -- footprint of the sheet (floor, garages, a strip of grass)
Layout.totalZ = 200
Layout.groundX = 460 -- the whole grass plate
Layout.groundZ = 420
Layout.spawnX = 60
Layout.spawnZ = 0 -- both starts on the middle line, each in front of its garage

Layout.colors = {
	asphalt = { 72, 83, 99 }, -- #485363 on the sheet
	asphaltDark = { 58, 66, 80 },
	orange = { 245, 130, 32 }, -- #F58220
	blue = { 37, 141, 221 }, -- #258DDA
	tire = { 36, 39, 43 }, -- #24272B
	grass = { 127, 186, 66 }, -- #7FBA42
	hill = { 142, 200, 84 },
	marking = { 237, 240, 234 }, -- #EDF0EA
	red = { 214, 58, 52 },
	light = { 255, 168, 60 }, -- glowing lights, steady
	metal = { 128, 134, 146 },
	metalDark = { 70, 76, 88 },
	trunk = { 120, 82, 52 },
	leaf = { 86, 160, 58 },
	leafLight = { 118, 190, 70 },
	pine = { 52, 128, 78 },
	pineLight = { 72, 152, 92 },
	rock = { 138, 142, 150 },
	rockDark = { 108, 112, 122 },
	crate = { 176, 128, 76 },
	dirt = { 168, 128, 86 },
	skid = { 38, 43, 54 },
	bush = { 70, 150, 64 },
	flowers = { { 255, 214, 64 }, { 255, 120, 150 }, { 255, 255, 255 }, { 176, 120, 255 } },
}

Layout.pad = { sx = 26, sz = 18 } -- start pad size, along the driving direction and across
Layout.lane = 14 -- nothing but floor markings within this far of the middle line, between the pads
Layout.block = { sx = 16, sy = 6, sz = 7 } -- cover barrier size
Layout.tire = { diameter = 5.4, height = 1.9, stack = 3 }
Layout.wallBounce = 0.9 -- how much speed a car keeps when it hits a wall or cover
-- Garage: width across the mouth (z), depth into the grass (x), height. Two cars wide.
Layout.garage = { w = 40, d = 26, h = 15, mouth = 36, door = 12 }
Layout.circle = 15 -- radius of the painted center circle
Layout.tower = { x = 96, z = 70, height = 36 } -- stadium light towers, one per corner outside the walls
Layout.sign = { z = -92, width = 56, height = 11, y = 24 } -- "CAR VS CAR" over the north wall

export type Wall = {
	name: string,
	x: number,
	z: number,
	length: number,
	yawDeg: number, -- the long side runs along this heading (0 = along x)
	team: string, -- "orange" or "blue", mixed all the way round
	arc: boolean,
	nx: number, -- unit vector pointing to the middle of the arena (the inner face looks this way)
	nz: number,
}

function Layout.spawn(side: string): (number, number, number, number)
	if side == "a" then
		return -Layout.spawnX, Layout.spawnZ, 1, 0
	end
	return Layout.spawnX, Layout.spawnZ, -1, 0
end

-- Corner centers of the rounded rectangle.
local function cornerCenters(): { { number } }
	local cx, cz = Layout.halfX - Layout.corner, Layout.halfZ - Layout.corner
	return { { -cx, -cz, -1, -1 }, { cx, -cz, 1, -1 }, { cx, cz, 1, 1 }, { -cx, cz, -1, 1 } }
end

local function teamOf(n: number): string
	return if n % 2 == 0 then "orange" else "blue"
end

-- The wall pieces. Each is a box `length` long and wallThickness thick; its INNER face passes
-- through (x, z) and the box sits wallThickness / 2 behind that, away from the middle. The two end
-- walls have an opening where the garage mouths are.
function Layout.walls(): { Wall }
	local list: { Wall } = {}
	local hx, hz, r = Layout.halfX, Layout.halfZ, Layout.corner
	local runX = (hx - r) * 2 -- straight stretch of the north and south walls
	local runZ = (hz - r) * 2
	local nX, nZ = 6, 4 -- modules along each straight
	local n = 0
	for i = 1, nX do
		local x = -(hx - r) + (i - 0.5) * runX / nX
		for _, sz in { -1, 1 } do
			n += 1
			table.insert(list, {
				name = (if sz < 0 then "WallN" else "WallS") .. i,
				x = x,
				z = sz * hz,
				length = runX / nX,
				yawDeg = 0,
				team = teamOf(i + (if sz < 0 then 0 else 1)),
				arc = false,
				nx = 0,
				nz = -sz,
			})
		end
	end
	for i = 1, nZ do
		local z = -(hz - r) + (i - 0.5) * runZ / nZ
		if math.abs(z) > Layout.garage.mouth / 2 then -- the middle modules are the garage openings
			for _, sx in { -1, 1 } do
				table.insert(list, {
					name = (if sx < 0 then "WallW" else "WallE") .. i,
					x = sx * hx,
					z = z,
					length = runZ / nZ,
					yawDeg = -90,
					team = teamOf(i + (if sx < 0 then 0 else 1)),
					arc = false,
					nx = -sx,
					nz = 0,
				})
			end
		end
	end
	local steps = 4
	local chord = 2 * r * math.sin(math.pi / (4 * steps))
	for ci, c in cornerCenters() do
		for k = 1, steps do
			-- angle measured from the x axis toward the corner direction
			local a0 = (k - 1) * (math.pi / 2) / steps
			local a1 = k * (math.pi / 2) / steps
			local am = (a0 + a1) / 2
			local dx, dz = c[3] * math.cos(am), c[4] * math.sin(am)
			-- the chord's midpoint is a little inside the circle
			local mid = r * math.cos(math.pi / (4 * steps))
			table.insert(list, {
				name = "WallCorner" .. ci .. "_" .. k,
				x = c[1] + dx * mid,
				z = c[2] + dz * mid,
				length = chord,
				yawDeg = math.deg(math.atan2(-dx, -dz)), -- along the tangent, square to the radius
				team = teamOf(ci + k),
				arc = true,
				nx = -dx,
				nz = -dz,
			})
		end
	end
	return list
end

-- Tire stacks stand where two straight wall modules meet (not in a garage opening).
function Layout.tireStacks(): { { x: number, z: number, nx: number, nz: number } }
	local list = {}
	local hx, hz, r = Layout.halfX, Layout.halfZ, Layout.corner
	for i = 0, 6 do
		local x = -(hx - r) + i * (hx - r) * 2 / 6
		for _, sz in { -1, 1 } do
			table.insert(list, { x = x, z = sz * hz, nx = 0, nz = -sz })
		end
	end
	for i = 0, 4 do
		local z = -(hz - r) + i * (hz - r) * 2 / 4
		if math.abs(z) < 1 then
			continue
		end
		for _, sx in { -1, 1 } do
			table.insert(list, { x = sx * hx, z = z, nx = -sx, nz = 0 })
		end
	end
	return list
end

-- Four orange-striped cover barriers on the floor, mirrored left to right and top to bottom, out of
-- the lane between the starts.
function Layout.blocks(): { { name: string, x: number, z: number, yawDeg: number } }
	local list = {}
	local n = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			n += 1
			table.insert(
				list,
				{ name = "Cover" .. n, x = sx * 24, z = sz * 31, yawDeg = sx * sz * 28 }
			)
		end
	end
	return list
end

-- Rotated footprint of a block: half extent along x and z.
function Layout.blockHalf(yawDeg: number): (number, number)
	local b = Layout.block
	local c, s = math.abs(math.cos(math.rad(yawDeg))), math.abs(math.sin(math.rad(yawDeg)))
	return (b.sx / 2) * c + (b.sz / 2) * s, (b.sx / 2) * s + (b.sz / 2) * c
end

-- The white dashed line that runs round the floor, as short bars: x, z, length, yaw (degrees).
function Layout.dashes(): { { x: number, z: number, length: number, yawDeg: number } }
	local inset = 10
	local hx, hz = Layout.halfX - inset, Layout.halfZ - inset
	local r = Layout.corner - inset
	local pts: { { number } } = {}
	local function arc(cx: number, cz: number, a0: number, a1: number)
		local steps = 5
		for k = 0, steps do
			local a = a0 + (a1 - a0) * k / steps
			table.insert(pts, { cx + r * math.cos(a), cz + r * math.sin(a) })
		end
	end
	arc(-(hx - r), -(hz - r), math.pi, 1.5 * math.pi) -- north west
	arc(hx - r, -(hz - r), 1.5 * math.pi, 2 * math.pi) -- north east
	arc(hx - r, hz - r, 0, 0.5 * math.pi) -- south east
	arc(-(hx - r), hz - r, 0.5 * math.pi, math.pi) -- south west
	local list = {}
	local n = #pts
	local seg = 0
	for i = 1, n do
		local a, b = pts[i], pts[i % n + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local pieces = math.max(1, math.floor(len / 14))
		for k = 1, pieces do
			seg += 1
			if seg % 2 == 1 or len < 14 then
				local t = (k - 0.5) / pieces
				table.insert(list, {
					x = a[1] + dx * t,
					z = a[2] + dz * t,
					length = math.min(len / pieces * 0.62, 8),
					yawDeg = -math.deg(math.atan2(dz, dx)),
				})
			end
		end
	end
	return list
end

-- Lane lines through the middle: a dashed line along x and one along z, with a gap for the circle.
function Layout.laneLines(): { { x: number, z: number, length: number, yawDeg: number } }
	local list = {}
	local gap = Layout.circle + 4
	local x = gap
	while x < Layout.halfX - 22 do
		for _, sx in { -1, 1 } do
			table.insert(list, { x = sx * (x + 3), z = 0, length = 6, yawDeg = 0 })
		end
		x += 12
	end
	local z = gap
	while z < Layout.halfZ - 14 do
		for _, sz in { -1, 1 } do
			table.insert(list, { x = 0, z = sz * (z + 3), length = 6, yawDeg = 90 })
		end
		z += 12
	end
	return list
end

-- Big painted arrows by the garages, pointing from the garage toward the middle: orange at the
-- left garage, blue at the right one. yawDeg is the pointing direction (0 = +x, 180 = -x).
function Layout.arrows(): { { x: number, z: number, yawDeg: number, team: string } }
	local list = {}
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			table.insert(list, {
				x = sx * 76,
				z = sz * 22,
				yawDeg = if sx < 0 then 0 else 180,
				team = if sx < 0 then "orange" else "blue",
			})
		end
	end
	return list
end

-- Old skid marks: short dark bars laid along arcs, always the same.
function Layout.skids(): { { x: number, z: number, length: number, yawDeg: number } }
	local list = {}
	local sets = {
		{ -30, -34, 0.3, 5 }, -- cx, cz of the arc start, heading, curve
		{ 34, 38, 2.9, -5 },
		{ -8, 18, 1.2, 4 },
		{ 18, -16, 4.4, -6 },
		{ 46, -4, 3.5, 5 },
		{ -50, 20, 5.2, -4 },
	}
	for _, s in sets do
		for lane = 0, 1 do
			local x, z, h =
				s[1] + lane * 2.2 * math.cos(s[3] + 1.57),
				s[2] + lane * 2.2 * math.sin(s[3] + 1.57),
				s[3]
			for _ = 1, 7 do
				table.insert(list, { x = x, z = z, length = 4, yawDeg = -math.deg(h) })
				x += 4 * math.cos(h)
				z += 4 * math.sin(h)
				h += s[4] * 0.02
			end
		end
	end
	return list
end

-- Where the garages stand: side a (red or blue each match) behind the west wall, side b behind the east.
function Layout.garages(): { { side: string, x: number, z: number, dir: number } }
	local g = Layout.garage
	local xc = Layout.halfX + Layout.wallThickness + g.d / 2
	return { { side = "a", x = -xc, z = 0, dir = -1 }, { side = "b", x = xc, z = 0, dir = 1 } }
end

-- Four stadium light towers outside the corners.
function Layout.towers(): { { x: number, z: number } }
	local t = Layout.tower
	return {
		{ x = -t.x, z = -t.z },
		{ x = t.x, z = -t.z },
		{ x = t.x, z = t.z },
		{ x = -t.x, z = t.z },
	}
end

-- Dirt paths from each garage back out onto the grass: rectangles (x, z, size x, size z, yaw).
function Layout.paths(): { { x: number, z: number, sx: number, sz: number, yawDeg: number } }
	local list = {}
	local g = Layout.garage
	local back = Layout.halfX + Layout.wallThickness + g.d
	for _, s in { -1, 1 } do
		table.insert(list, { x = s * (back + 22), z = 0, sx = 44, sz = 9, yawDeg = 0 })
		table.insert(list, { x = s * (back + 56), z = s * 14, sx = 36, sz = 9, yawDeg = s * -22 })
		table.insert(list, { x = s * (back + 88), z = s * 36, sx = 36, sz = 9, yawDeg = s * -40 })
	end
	return list
end

-- Soft green hills far away: x, z, diameter.
function Layout.hills(): { { x: number, z: number, d: number } }
	return {
		{ x = -190, z = -170, d = 190 },
		{ x = 20, z = -200, d = 230 },
		{ x = 210, z = -160, d = 200 },
		{ x = 250, z = 20, d = 170 },
		{ x = 200, z = 180, d = 210 },
		{ x = -30, z = 210, d = 220 },
		{ x = -220, z = 170, d = 190 },
		{ x = -260, z = -10, d = 180 },
	}
end

export type Scenery = {
	kind: string, -- "tree" "pine" "rock" "bush" "flower"
	x: number,
	z: number,
	yawDeg: number,
	scale: number,
	far: boolean, -- far away: the first thing to cut if phones lag
	pick: number, -- which flower color
}

-- Trees, rocks, bushes and flowers on the grass, always the same ones. Nothing stands inside the
-- walls, in a garage, on a path or under a tower or the sign.
function Layout.scenery(): { Scenery }
	local list: { Scenery } = {}
	local seed = 20261020
	local function rnd(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local g = Layout.garage
	local keepX = Layout.halfX + Layout.wallThickness + 8
	local keepZ = Layout.halfZ + Layout.wallThickness + 8
	local paths = Layout.paths()
	local towers = Layout.towers()
	local function blocked(x: number, z: number, r: number): boolean
		if math.abs(x) < keepX + r and math.abs(z) < keepZ + r then
			return true
		end
		-- garages and their doorways, with a margin
		if math.abs(x) < keepX + g.d + r and math.abs(z) < g.w / 2 + 5 + r then
			return true
		end
		for _, p in paths do
			local c, s = math.cos(math.rad(p.yawDeg)), math.sin(math.rad(p.yawDeg))
			local dx, dz = x - p.x, z - p.z
			local lx = math.abs(dx * c - dz * s)
			local lz = math.abs(dx * s + dz * c)
			if lx < p.sx / 2 + r and lz < p.sz / 2 + r + 1 then
				return true
			end
		end
		for _, t in towers do
			if (t.x - x) ^ 2 + (t.z - z) ^ 2 < (9 + r) ^ 2 then
				return true
			end
		end
		local sg = Layout.sign
		if math.abs(x) < sg.width / 2 + 6 + r and math.abs(z - sg.z) < 10 + r then
			return true
		end
		return false
	end
	local want = { tree = 56, pine = 40, rock = 46, bush = 50, flower = 36 }
	local made: { [string]: number } = { tree = 0, pine = 0, rock = 0, bush = 0, flower = 0 }
	local order = { "tree", "pine", "rock", "bush", "flower" }
	local radius = { tree = 7, pine = 6, rock = 4, bush = 3, flower = 1.5 }
	local tries = 0
	local done = false
	while not done and tries < 30000 do
		tries += 1
		local kind = order[tries % #order + 1]
		if made[kind] < want[kind] then
			local x = (rnd() * 2 - 1) * (Layout.groundX / 2 - 30)
			local z = (rnd() * 2 - 1) * (Layout.groundZ / 2 - 30)
			-- thicker near the arena: skip a share of the far picks
			local far = math.abs(x) > 150 or math.abs(z) > 140
			if (not far or rnd() < 0.45) and not blocked(x, z, radius[kind]) then
				local close = false
				for _, o in list do
					local rr = radius[kind] + radius[o.kind]
					if (o.x - x) ^ 2 + (o.z - z) ^ 2 < rr * rr then
						close = true
						break
					end
				end
				if not close then
					made[kind] += 1
					table.insert(list, {
						kind = kind,
						x = x,
						z = z,
						yawDeg = rnd() * 360,
						scale = 0.75 + rnd() * 0.75,
						far = far,
						pick = math.floor(rnd() * 4) + 1,
					})
				end
			end
		end
		done = true
		for k, n in want do
			if made[k] < n then
				done = false
			end
		end
	end
	return list
end

return Layout
