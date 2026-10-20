--!strict
-- The 1v1 battle map "Toy Box Showdown" as pure data (unit tested, drawn as a top-down picture).
-- Arena-local studs: x runs between the two spawns, z across, y up from the floor. The server
-- builds it in `BattleMap`; every number lives here so the tests and the picture read the same data.
--
-- Plan (top-down, spawn A left, spawn B right):
--   * central PLATEAU with a ramp from each spawn side and a sheer drop on the north/south faces
--   * a BUNKER in front of each spawn: free cover from the opening cannon shot
--   * four COVER BLOCKS and four KICKER ramps in the outer lanes for flank jumps
--   * four corner BUMPERS so nobody gets pinned; walls all round, nothing to fall out of

local Layout = {}

Layout.halfX = 100
Layout.halfZ = 70
Layout.wallHeight = 16
Layout.wallThickness = 4
Layout.spawnX = 84 -- spawn A at -spawnX facing +x, spawn B at +spawnX facing -x
Layout.carLength = 16 -- the biggest fighter body (studs): used for the clearance rules

export type Box = {
	name: string,
	x: number,
	z: number,
	sx: number, -- full size along x (before yaw)
	sy: number,
	sz: number,
	yawDeg: number,
	color: { number },
	solid: boolean, -- true = a car can hit it (and shells stop at it)
}

export type Ramp = {
	name: string,
	x: number, -- middle of the footprint
	z: number,
	length: number, -- along the rise
	width: number,
	height: number,
	dx: number, -- unit direction the ramp RISES toward (arena-local x, z)
	dz: number,
	color: { number },
}

Layout.colors = {
	tileA = { 232, 238, 246 },
	tileB = { 190, 206, 230 },
	wall = { 52, 62, 112 },
	stripes = { { 235, 72, 72 }, { 255, 205, 50 }, { 60, 140, 235 } },
	plateau = { 255, 205, 50 },
	ring = { 235, 72, 72 },
	ramp = { 255, 126, 60 },
	bunker = { 150, 92, 220 },
	blocks = { { 255, 150, 40 }, { 80, 200, 110 } },
	kicker = { 70, 200, 120 },
	bumper = { 235, 72, 72 },
	padA = { 235, 72, 72 },
	padB = { 60, 140, 235 },
}

Layout.plateau = { hx = 18, hz = 22, height = 7 }
Layout.plateauRamp = { length = 28, width = 30 }
Layout.bunker = { x = 64, sx = 6, sy = 11, sz = 22 }
Layout.block = { x = 44, z = 40, sx = 10, sy = 9, sz = 10 }
Layout.kicker = { x = 16, z = 56, length = 16, width = 14, height = 4 } -- middle of the footprint
Layout.bumper = { x = 88, z = 58, sx = 24, sy = 8, sz = 6 }
Layout.tileSize = 20
Layout.panelWidth = 20 -- wall stripe panels

-- Cars start here (arena-local), facing each other down the middle.
function Layout.spawn(side: string): (number, number, number, number)
	if side == "a" then
		return -Layout.spawnX, 0, 1, 0
	end
	return Layout.spawnX, 0, -1, 0
end

-- Solid chunky pieces (things a car can hit). Four-way symmetric except where noted.
function Layout.boxes(): { Box }
	local c = Layout.colors
	local p, bk, bl, bu = Layout.plateau, Layout.bunker, Layout.block, Layout.bumper
	local list: { Box } = {}
	table.insert(list, {
		name = "Plateau",
		x = 0,
		z = 0,
		sx = p.hx * 2,
		sy = p.height,
		sz = p.hz * 2,
		yawDeg = 0,
		color = c.plateau,
		solid = true,
	})
	for i, sx in { -1, 1 } do
		table.insert(list, {
			name = "Bunker" .. i,
			x = sx * bk.x,
			z = 0,
			sx = bk.sx,
			sy = bk.sy,
			sz = bk.sz,
			yawDeg = 0,
			color = c.bunker,
			solid = true,
		})
	end
	local n = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			n += 1
			table.insert(list, {
				name = "Block" .. n,
				x = sx * bl.x,
				z = sz * bl.z,
				sx = bl.sx,
				sy = bl.sy,
				sz = bl.sz,
				yawDeg = 0,
				color = c.blocks[(n - 1) % #c.blocks + 1],
				solid = true,
			})
			table.insert(list, {
				name = "Bumper" .. n,
				x = sx * bu.x,
				z = sz * bu.z,
				sx = bu.sx,
				sy = bu.sy,
				sz = bu.sz,
				yawDeg = if sx * sz > 0 then 45 else -45, -- long side across the corner
				color = c.bumper,
				solid = true,
			})
		end
	end
	return list
end

-- Ramps: two plateau ramps and four kickers (all rise toward the middle of their lane).
function Layout.ramps(): { Ramp }
	local c = Layout.colors
	local p, pr, k = Layout.plateau, Layout.plateauRamp, Layout.kicker
	local list: { Ramp } = {}
	for i, sx in { -1, 1 } do
		table.insert(list, {
			name = "PlateauRamp" .. i,
			x = sx * (p.hx + pr.length / 2),
			z = 0,
			length = pr.length,
			width = pr.width,
			height = p.height,
			dx = -sx, -- rises toward the plateau
			dz = 0,
			color = c.ramp,
		})
	end
	local n = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			n += 1
			table.insert(list, {
				name = "Kicker" .. n,
				x = sx * k.x,
				z = sz * k.z,
				length = k.length,
				width = k.width,
				height = k.height,
				dx = -sx, -- the low end faces the spawn side, the lip launches toward the middle
				dz = 0,
				color = c.kicker,
			})
		end
	end
	return list
end

-- Axis-aligned rectangles (x, z, half sizes) the old auto-battle AI avoids: the pieces that are
-- not rotated, with the plateau's rectangle widened to cover its ramps.
function Layout.obstacleRects(): { { x: number, z: number, hx: number, hz: number } }
	local out = {}
	for _, b in Layout.boxes() do
		if b.yawDeg == 0 then
			local hx = b.sx / 2
			if b.name == "Plateau" then
				hx += Layout.plateauRamp.length
			end
			table.insert(out, { x = b.x, z = b.z, hx = hx, hz = b.sz / 2 })
		end
	end
	return out
end

-- Floor tiles that get the second checker color (centers, arena-local).
function Layout.tiles(): { { x: number, z: number } }
	local out = {}
	local s = Layout.tileSize
	local nx, nz = math.floor(Layout.halfX * 2 / s), math.floor(Layout.halfZ * 2 / s)
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			if (i + j) % 2 == 0 then
				table.insert(
					out,
					{ x = -Layout.halfX + (i + 0.5) * s, z = -Layout.halfZ + (j + 0.5) * s }
				)
			end
		end
	end
	return out
end

-- Slope of a ramp in degrees.
function Layout.slopeDeg(r: Ramp): number
	return math.deg(math.atan2(r.height, r.length))
end

-- Footprint corners of a box after its yaw (arena-local), for the tests.
function Layout.corners(b: Box): { { number } }
	local a = math.rad(b.yawDeg)
	local ca, sa = math.cos(a), math.sin(a)
	local out = {}
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			local lx, lz = cx * b.sx / 2, cz * b.sz / 2
			table.insert(out, { b.x + lx * ca + lz * sa, b.z - lx * sa + lz * ca })
		end
	end
	return out
end

return Layout
