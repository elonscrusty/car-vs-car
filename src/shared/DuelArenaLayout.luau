--!strict
-- "Duel Car Arena": the 1v1 battle map from carter's reference sheet. Pure data, no Roblox objects,
-- so the tests can check every number. The server builds it in DuelArena.
--
-- Arena-local studs: x runs along the long side (between the two start pads), z across, y up; the
-- floor top is y = 0. The playable floor is a rounded rectangle (170 x 120): a car at about 45 studs
-- per second crosses the long way in about 4 seconds. Garages, trees and rocks stand outside the
-- walls and fill the overall 240 x 200 footprint of the sheet.

local Layout = {}

Layout.halfX = 85 -- playable floor, inner face of the walls
Layout.halfZ = 60
Layout.corner = 24 -- radius of the rounded corners
Layout.wallHeight = 7 -- car height: a car bounces off it, nothing more
Layout.wallThickness = 4
Layout.totalX = 240 -- footprint of the whole scene (floor, garages, grass outside)
Layout.totalZ = 200
Layout.spawnX = 60
Layout.spawnZ = -34 -- both starts sit in front of their garage on the north side

Layout.colors = {
	asphalt = { 72, 83, 99 }, -- #485363 on the sheet
	orange = { 245, 130, 32 }, -- #F58220
	blue = { 37, 141, 221 }, -- #258DDA
	tire = { 36, 39, 43 }, -- #24272B
	grass = { 127, 186, 66 }, -- #7FBA42
	marking = { 237, 240, 234 }, -- #EDF0EA
	padRed = { 214, 58, 52 },
	padBlue = { 37, 141, 221 },
	light = { 255, 168, 60 }, -- glowing wall lights
	metal = { 128, 134, 146 },
	trunk = { 120, 82, 52 },
	leaf = { 86, 160, 58 },
	leafLight = { 118, 190, 70 },
	rock = { 138, 142, 150 },
	crate = { 176, 128, 76 },
}

Layout.pad = { sx = 26, sz = 18 } -- start pad size, along the driving direction and across
Layout.lane = 14 -- nothing but floor markings within this far of the start line z, between the pads
Layout.block = { sx = 16, sy = 6, sz = 7 } -- cover barrier size
Layout.tire = { diameter = 5.4, height = 1.9, stack = 3 }
Layout.garage = { sx = 44, sy = 13, sz = 24, x = 60 } -- behind the north wall, red at -x and blue at +x

export type Wall = {
	name: string,
	x: number,
	z: number,
	length: number,
	yawDeg: number, -- the long side runs along this heading (0 = along x)
	team: string, -- "orange" or "blue"
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

local function teamAt(x: number): string
	return if x < 0 then "orange" else "blue"
end

-- The wall pieces. Each is a box `length` long and wallThickness thick whose INNER face passes
-- through (x, z) shifted by `wallThickness / 2` away from the middle: callers place it at
-- (x + -nx * t/2, z + -nz * t/2).
function Layout.walls(): { Wall }
	local list: { Wall } = {}
	local hx, hz, r = Layout.halfX, Layout.halfZ, Layout.corner
	local runX = (hx - r) * 2 -- straight stretch of the north and south walls
	local runZ = (hz - r) * 2
	local nX, nZ = 6, 4 -- modules along each straight
	for i = 1, nX do
		local x = -(hx - r) + (i - 0.5) * runX / nX
		for _, sz in { -1, 1 } do
			table.insert(list, {
				name = (if sz < 0 then "WallN" else "WallS") .. i,
				x = x,
				z = sz * hz,
				length = runX / nX,
				yawDeg = 0,
				team = teamAt(x),
				arc = false,
				nx = 0,
				nz = -sz,
			})
		end
	end
	for i = 1, nZ do
		local z = -(hz - r) + (i - 0.5) * runZ / nZ
		for _, sx in { -1, 1 } do
			table.insert(list, {
				name = (if sx < 0 then "WallW" else "WallE") .. i,
				x = sx * hx,
				z = z,
				length = runZ / nZ,
				yawDeg = -90,
				team = teamAt(sx),
				arc = false,
				nx = -sx,
				nz = 0,
			})
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
			local x, z = c[1] + dx * mid, c[2] + dz * mid
			table.insert(list, {
				name = "WallCorner" .. ci .. "_" .. k,
				x = x,
				z = z,
				length = chord,
				yawDeg = math.deg(math.atan2(-dx, -dz)), -- along the tangent, square to the radius (dx, dz)
				team = teamAt(x),
				arc = true,
				nx = -dx,
				nz = -dz,
			})
		end
	end
	return list
end

-- Tire stacks stand where two straight wall modules meet.
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
		for _, sx in { -1, 1 } do
			table.insert(list, { x = sx * hx, z = z, nx = -sx, nz = 0 })
		end
	end
	return list
end

-- Four orange-striped cover barriers on the floor, mirrored left to right.
function Layout.blocks(): { { name: string, x: number, z: number, yawDeg: number } }
	local list = {}
	local spots = { { 16, -2, 35 }, { 42, 24, -25 } }
	local n = 0
	for _, s in spots do
		for _, sx in { -1, 1 } do
			n += 1
			table.insert(list, { name = "Cover" .. n, x = sx * s[1], z = s[2], yawDeg = sx * s[3] })
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
	local function add(x: number, z: number)
		table.insert(pts, { x, z })
	end
	-- walk clockwise from the top left corner arc's start
	local function arc(cx: number, cz: number, a0: number, a1: number)
		local steps = 5
		for k = 0, steps do
			local a = a0 + (a1 - a0) * k / steps
			add(cx + r * math.cos(a), cz + r * math.sin(a))
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
		-- long straight stretches get several dashes, short arc chords one each
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

-- Painted arrows in the south corners: orange on the red side, blue on the blue side. They point
-- toward the middle of the arena.
function Layout.chevrons(): { { x: number, z: number, yawDeg: number, team: string } }
	local list = {}
	for _, sx in { -1, 1 } do
		table.insert(list, {
			x = sx * 60,
			z = 38,
			yawDeg = if sx < 0 then 35 else 145,
			team = teamAt(sx),
		})
	end
	return list
end

-- Where the garages stand: the red one behind the north wall's west end, the blue one at the east.
function Layout.garages(): { { side: string, x: number, z: number } }
	local g = Layout.garage
	local zc = -(Layout.halfZ + Layout.wallThickness + g.sz / 2)
	return { { side = "a", x = -g.x, z = zc }, { side = "b", x = g.x, z = zc } }
end

-- Trees and rocks on the grass, always the same ones. Nothing stands inside the walls or in a garage.
function Layout.scenery(): { { kind: string, x: number, z: number, yawDeg: number, scale: number } }
	local list = {}
	local seed = 20261020
	local function rnd(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local g = Layout.garage
	local keepX = Layout.halfX + Layout.wallThickness + 9
	local keepZ = Layout.halfZ + Layout.wallThickness + 9
	local tries = 0
	local trees, rocks = 0, 0
	while (trees < 34 or rocks < 16) and tries < 4000 do
		tries += 1
		local x = (rnd() * 2 - 1) * (Layout.totalX / 2 - 6)
		local z = (rnd() * 2 - 1) * (Layout.totalZ / 2 - 6)
		local inside = math.abs(x) < keepX and math.abs(z) < keepZ
		local inGarage = z < -(Layout.halfZ + Layout.wallThickness - 2)
			and math.abs(math.abs(x) - g.x) < g.sx / 2 + 12
			and z > -(Layout.halfZ + Layout.wallThickness + g.sz + 10)
		if not inside and not inGarage then
			local tooClose = false
			for _, o in list do
				if (o.x - x) ^ 2 + (o.z - z) ^ 2 < 144 then
					tooClose = true
					break
				end
			end
			if not tooClose then
				if trees < 34 and (rocks >= 16 or rnd() < 0.68) then
					trees += 1
					table.insert(list, {
						kind = "tree",
						x = x,
						z = z,
						yawDeg = rnd() * 360,
						scale = 0.8 + rnd() * 0.5,
					})
				elseif rocks < 16 then
					rocks += 1
					table.insert(list, {
						kind = "rock",
						x = x,
						z = z,
						yawDeg = rnd() * 360,
						scale = 0.7 + rnd() * 0.9,
					})
				end
			end
		end
	end
	return list
end

return Layout
