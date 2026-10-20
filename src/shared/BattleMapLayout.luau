--!strict
-- The 1v1 battle map "Toy Room Showdown" as pure data (unit tested, drawn as a top-down picture).
-- Arena-local studs: x runs between the two spawns, z across, y up from the floor. The server
-- builds it in `BattleMap`; every number lives here so the tests and the picture read the same data.
--
-- The idea: the cars race on a giant play-mat laid on a kid's bedroom floor.
--   * center PLATEAU (a toy stage) with a ramp from each spawn side, a spinner arm on top and a
--     sheer drop on the north/south faces
--   * a HIGHWAY overpass along each long side: ramps up at both ends, a raised deck in the middle
--     with sliding blocks that shove cars toward the edge (10 studs drop to the road)
--   * a BUNKER in front of each spawn (cover from the opening cannon shot), four alphabet-block
--     covers and four toy soldiers; four corner bumpers so nobody gets pinned
--   * walls are furniture: a bed (north), a bookshelf (south), a toy chest (west), a window wall (east)

local Layout = {}

Layout.halfX = 120
Layout.halfZ = 80
Layout.wallHeight = 18
Layout.wallThickness = 4
Layout.spawnX = 100 -- spawn A at -spawnX facing +x, spawn B at +spawnX facing -x
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
	kind: string, -- "plateau" | "highway" | "bunker" | "block" | "bumper" | "soldier": how the builder dresses it
	letter: string?, -- alphabet block letter
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

export type Slider = {
	name: string,
	x: number, -- middle of its travel
	z: number,
	amplitude: number, -- studs either side of the middle (it slides along z, across the deck)
	periodSeconds: number,
	size: { number }, -- x, y, z of the block
	baseY: number, -- the deck top it rides on
	phase: number, -- 0..1 of the period, so neighbours are out of step
}

Layout.colors = {
	grass = { 96, 196, 104 },
	road = { 78, 84, 102 },
	dash = { 255, 232, 120 },
	wood = { 214, 160, 96 },
	wall = { 52, 62, 112 },
	stripes = { { 235, 72, 72 }, { 255, 205, 50 }, { 60, 140, 235 } },
	plateau = { 255, 205, 50 },
	ring = { 235, 72, 72 },
	ramp = { 255, 126, 60 },
	highway = { 120, 126, 150 },
	bunker = { 150, 92, 220 },
	blocks = { { 255, 150, 40 }, { 80, 200, 110 } },
	bumper = { 235, 72, 72 },
	padA = { 235, 72, 72 },
	padB = { 60, 140, 235 },
	white = { 250, 250, 255 },
	chevron = { 255, 205, 50 },
	skirt = { 214, 160, 20 }, -- darker plateau base
	cap = { 255, 232, 120 }, -- lighter plateau lip
	skin = { 255, 214, 170 },
	hat = { 40, 46, 80 },
	brown = { 176, 118, 70 },
	crayons = {
		{ 235, 72, 72 },
		{ 255, 205, 50 },
		{ 60, 140, 235 },
		{ 80, 200, 110 },
		{ 150, 92, 220 },
		{ 255, 150, 40 },
	},
}

Layout.plateau = { hx = 20, hz = 24, height = 7 }
Layout.plateauRamp = { length = 28, width = 32 }
Layout.highway = { z = 58, width = 18, height = 10, rampLength = 40, deckHalf = 48 } -- deck from -deckHalf to +deckHalf
Layout.bunker = { x = 80, z = 20, sx = 6, sy = 11, sz = 14 } -- off the straight lane: spawn to middle stays open
Layout.block = { x = 60, z = 31, sx = 10, sy = 9, sz = 10 }
Layout.bumper = { x = 110, z = 70, sx = 20, sy = 8, sz = 6 }
Layout.soldier = { x = 100, z = 32, size = 10, height = 26 } -- toy soldiers guard each start, a landmark and cover
-- Hazard one: a slow spinner arm over the plateau that sweeps cars toward the drop.
Layout.spinner =
	{ radius = 15, clearance = 1.2, height = 4, width = 3.5, speed = 0.9, hubRadius = 3.5 }
-- Hazard two: blocks that slide across the highway decks and shove cars off their edge.
Layout.slider = { x = 26, amplitude = 5.5, periodSeconds = 5, size = { 5, 8, 5 } }
Layout.studSize = { diameter = 3.4, height = 0.8 } -- toy-brick studs on bunkers and blocks
Layout.startLineX = 80 -- white start line in front of each pad
-- The play-mat road: a loop around the plateau (strips are centered on these lines).
Layout.road = { z = 38, x = 92, width = 20 }
Layout.panelWidth = 20 -- quilt / wallpaper panels

-- Cars start here (arena-local), facing each other down the middle.
function Layout.spawn(side: string): (number, number, number, number)
	if side == "a" then
		return -Layout.spawnX, 0, 1, 0
	end
	return Layout.spawnX, 0, -1, 0
end

-- Solid chunky pieces (things a car can hit).
function Layout.boxes(): { Box }
	local c = Layout.colors
	local p, hw, bk, bl, bu, so =
		Layout.plateau, Layout.highway, Layout.bunker, Layout.block, Layout.bumper, Layout.soldier
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
		kind = "plateau",
	})
	for i, sz in { -1, 1 } do
		table.insert(list, {
			name = "HighwayDeck" .. i,
			x = 0,
			z = sz * hw.z,
			sx = hw.deckHalf * 2,
			sy = hw.height,
			sz = hw.width,
			yawDeg = 0,
			color = c.highway,
			solid = true,
			kind = "highway",
		})
	end
	local bn = 0
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			bn += 1
			table.insert(list, {
				name = "Bunker" .. bn,
				x = sx * bk.x,
				z = sz * bk.z,
				sx = bk.sx,
				sy = bk.sy,
				sz = bk.sz,
				yawDeg = 0,
				color = c.bunker,
				solid = true,
				kind = "bunker",
			})
		end
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
				kind = "block",
				letter = ({ "A", "B", "C", "D" })[n],
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
				kind = "bumper",
			})
			table.insert(list, {
				name = "Soldier" .. n,
				x = sx * so.x,
				z = sz * so.z,
				sx = so.size,
				sy = so.height,
				sz = so.size,
				yawDeg = if sx < 0 then -90 else 90, -- faces the middle of the map
				color = if sx < 0 then c.padA else c.padB,
				solid = true,
				kind = "soldier",
			})
		end
	end
	return list
end

-- Ramps: two plateau ramps and four highway ramps (all rise toward the middle of the map).
function Layout.ramps(): { Ramp }
	local c = Layout.colors
	local p, pr, hw = Layout.plateau, Layout.plateauRamp, Layout.highway
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
	for _, sz in { -1, 1 } do
		for _, sx in { -1, 1 } do
			n += 1
			table.insert(list, {
				name = "HighwayRamp" .. n,
				x = sx * (hw.deckHalf + hw.rampLength / 2),
				z = sz * hw.z,
				length = hw.rampLength,
				width = hw.width,
				height = hw.height,
				dx = -sx, -- the low end is out by the spawn side
				dz = 0,
				color = c.ramp,
			})
		end
	end
	return list
end

-- Blocks that slide across the highway decks (four, two per deck, out of step).
function Layout.sliders(): { Slider }
	local sl, hw = Layout.slider, Layout.highway
	local out: { Slider } = {}
	local n = 0
	for _, sz in { -1, 1 } do
		for _, sx in { -1, 1 } do
			n += 1
			table.insert(out, {
				name = "Slider" .. n,
				x = sx * sl.x,
				z = sz * hw.z,
				amplitude = sl.amplitude,
				periodSeconds = sl.periodSeconds,
				size = sl.size,
				baseY = hw.height,
				phase = (n - 1) / 4,
			})
		end
	end
	return out
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

export type Strip = { x: number, z: number, sx: number, sz: number }

-- The play-mat road loop (flat strips on the grass) around the plateau.
function Layout.roadStrips(): { Strip }
	local r = Layout.road
	local len = r.x * 2 + r.width
	local out: { Strip } = {}
	for _, sz in { -1, 1 } do
		table.insert(out, { x = 0, z = sz * r.z, sx = len, sz = r.width })
	end
	for _, sx in { -1, 1 } do
		table.insert(out, { x = sx * r.x, z = 0, sx = r.width, sz = r.z * 2 })
	end
	return out
end

-- Dashed center line of the road: small flat pieces (x, z, along-x?).
function Layout.roadDashes(): { { x: number, z: number, alongX: boolean } }
	local r = Layout.road
	local out = {}
	local x = -r.x + 6
	while x <= r.x - 6 do
		for _, sz in { -1, 1 } do
			table.insert(out, { x = x, z = sz * r.z, alongX = true })
		end
		x += 14
	end
	local z = -r.z + 8
	while z <= r.z - 8 do
		for _, sx in { -1, 1 } do
			table.insert(out, { x = sx * r.x, z = z, alongX = false })
		end
		z += 14
	end
	return out
end

-- Floor arrows that point up the plateau ramps: center x, z and the way they point (+1 = toward +x).
function Layout.chevrons(): { { x: number, z: number, dir: number } }
	local out = {}
	for _, sx in { -1, 1 } do
		for _, x in { 52, 57 } do
			table.insert(out, { x = sx * x, z = 0, dir = -sx })
		end
	end
	return out
end

-- Pennants hung along the two long walls: x, color index.
function Layout.bunting(): { { x: number, i: number } }
	local out = {}
	for i = 0, 11 do
		table.insert(out, { x = -110 + i * 20, i = i })
	end
	return out
end

-- Giant toys outside the walls (looks only, no collision).
export type Prop = { kind: string, x: number, z: number, size: number, i: number, yawDeg: number }
function Layout.scenery(): { Prop }
	local out: { Prop } = {}
	local function add(kind: string, x: number, z: number, size: number, i: number, yaw: number)
		table.insert(out, { kind = kind, x = x, z = z, size = size, i = i, yawDeg = yaw })
	end
	local hx, hz = Layout.halfX, Layout.halfZ
	add("teddy", -34, hz + 58, 52, 1, 0) -- sits behind the bookshelf
	add("duck", 70, hz + 52, 38, 2, 0)
	add("rocket", -hx - 50, -28, 64, 3, 0)
	add("ferris", hx + 62, 0, 78, 4, 0)
	add("lamp", -hx - 40, hz - 8, 70, 5, 0)
	for k, x in { -86, -52, -14, 24, 60, 96 } do
		add("crayon", x, -hz - 24 - (k % 2) * 12, 34 + (k * 9) % 20, k, 0)
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			add("tower", sx * (hx + 22), sz * (hz + 18), 16, (sx + 3) + (sz + 3), sx * 23 + sz * 11)
			add("pole", sx * (hx + 4), sz * (hz + 4), 38, (sx + 3) + (sz + 3), 0)
		end
	end
	add("ball", hx + 30, -hz + 20, 34, 2, 0)
	add("ball", -hx - 24, 50, 30, 5, 0)
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
