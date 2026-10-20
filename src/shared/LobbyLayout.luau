--!strict
-- The Car Battle Lobby (carter's reference sheet + 70 picks, docs/LOBBY_SPEC.md). Pure data and
-- small geometry helpers, no Roblox objects, so the tests can check every number. The server
-- builds it from this file (Lobby.luau and the Lobby* modules next to it).
--
-- Studs, relative to the lobby origin. x = right, z = toward the spawn (+z = front, the player
-- looks toward -z), y = up, the asphalt top is y = 0. The reference sheet was 220 x 180 studs and
-- 32 high; carter's later pick L41 ("make the lobby smaller", docs/LOBBY_POLISH.md) pulled the
-- plaza in to 172 x 126 so the walk from the spawn to PLAY and the gumball machine is shorter.

local Layout = {}

export type Rect = { x: number, z: number, w: number, d: number, yawDeg: number } -- centre + full size

Layout.size = { x = 220, z = 180, height = 32 }
Layout.walkSpeed = 24 -- a bit faster than the normal 16

Layout.colors = {
	asphalt = { 72, 83, 99 }, -- #485363
	asphaltDark = { 58, 66, 80 },
	path = { 176, 181, 190 }, -- light gray paths
	orange = { 204, 104, 44 }, -- rusty orange (sunset junkyard, 2026-10-20)
	orangeWall = { 160, 76, 34 }, -- the same orange on big painted walls: the sun lights it up, so it is darker
	blue = { 64, 112, 140 }, -- weathered steel blue
	tire = { 36, 39, 43 }, -- #24272B
	grass = { 112, 92, 72 }, -- packed junkyard dirt (the name stays)
	hill = { 100, 82, 66 }, -- dirt mounds
	marking = { 237, 240, 234 }, -- #EDF0EA
	light = { 255, 168, 60 }, -- steady glow
	metal = { 128, 134, 146 },
	metalDark = { 70, 76, 88 },
	dirt = { 168, 128, 86 },
	trunk = { 120, 82, 52 },
	leaf = { 86, 160, 58 },
	leafLight = { 118, 190, 70 },
	pine = { 52, 128, 78 },
	pineLight = { 72, 152, 92 },
	rock = { 138, 142, 150 },
	rockDark = { 108, 112, 122 },
	bush = { 70, 150, 64 },
	wood = { 150, 104, 64 },
	panel = { 22, 28, 44 }, -- dark navy board / sign backs
	gold = { 255, 205, 64 },
	flowers = { { 255, 214, 64 }, { 255, 120, 150 }, { 255, 255, 255 }, { 176, 120, 255 } },
	-- carter's polish picks (docs/LOBBY_POLISH.md): rainbow cones with no orange (L22), bright tire
	-- stacks (L29), junk piles of old car parts (L28), puffy trees (L31), puffy clouds (L48)
	-- low-poly sunset junk (carter, 2026-10-20): rust, faded paint and steel, still no orange
	rainbow = {
		{ 176, 70, 56 },
		{ 200, 164, 72 },
		{ 120, 132, 70 },
		{ 70, 124, 102 },
		{ 74, 126, 136 },
		{ 84, 102, 140 },
		{ 112, 82, 140 },
		{ 160, 92, 120 },
	},
	puff = { { 112, 112, 70 }, { 128, 124, 80 }, { 96, 98, 62 } }, -- dusty scrub
	cloud = { 255, 196, 176 }, -- lit by the sunset
	cloudShade = { 156, 112, 150 },
	skyBlue = { 96, 178, 255 },
	-- the far city against the sunset: dark purple blocks, warm lit windows
	city = { { 58, 44, 84 }, { 72, 52, 98 }, { 48, 40, 72 }, { 86, 60, 104 } },
	window = { 255, 186, 96 },
}

-- The paved plaza (asphalt) inside the tire walls. The grass border and the world sit outside it.
Layout.plaza = { halfX = 86, frontZ = 56, backZ = -70, corner = 14 }

-- Spawn: on the front path, looks at the middle of the PLAY pads.
Layout.spawn = { x = 0, z = 42, size = 8 }

-- The big PLAY ring in the middle and the four small pads on it.
Layout.ring = { x = 0, z = 6, radius = 24, hubRadius = 6 }
Layout.padRadius = 5.5 -- each mini pad (a pad is "stood on" inside radius + padSlack)
Layout.padSlack = 0.5
Layout.padDist = 14.5 -- from the ring middle to each mini pad
Layout.padAngles = { 45, 135, 225, 315 } -- degrees; 0 = +x, counter-clockwise seen from above
Layout.padMax = 2 -- players per pad

function Layout.pads(): { { x: number, z: number } }
	local list = {}
	for _, a in Layout.padAngles do
		local r = math.rad(a)
		table.insert(list, {
			x = Layout.ring.x + math.cos(r) * Layout.padDist,
			z = Layout.ring.z - math.sin(r) * Layout.padDist,
		})
	end
	return list
end

-- Which pad (1..4) is a point standing on, or nil. `extra` widens the ring (walk-off tolerance).
function Layout.padAt(x: number, z: number, extra: number?): number?
	local r = Layout.padRadius + Layout.padSlack + (extra or 0)
	for i, p in Layout.pads() do
		if (p.x - x) ^ 2 + (p.z - z) ^ 2 <= r * r then
			return i
		end
	end
	return nil
end

-- Where a player lands when they come back from a fight or leave a pad: on the ring's outer
-- edge next to the pads, away from the spawn path. `k` (1..) spreads several players out.
function Layout.returnSpot(k: number): { x: number, z: number }
	local a = math.rad(90 + ((k - 1) % 8) * 45 + 22.5) -- the gaps between the pads and their mirror
	local d = Layout.ring.radius - 4
	return { x = Layout.ring.x + math.cos(a) * d, z = Layout.ring.z - math.sin(a) * d }
end

-- Three buildings along the back, all looking at the ring. `yawDeg` turns a building that was
-- drawn facing +z (the mouth on its +z side). w = across the mouth, d = depth, h = height.
Layout.workshop = { x = 0, z = -52, w = 56, d = 34, h = 24, yawDeg = 0 }
Layout.customize = { x = -57, z = -45, w = 40, d = 30, h = 18, yawDeg = 32 }
Layout.shop = { x = 56, z = -45, w = 44, d = 30, h = 18, yawDeg = -32 }

-- Inside the workshop (workshop-local: u across, v toward the mouth, from its middle).
Layout.gumball = { u = 0, v = -8, radius = 7.5 } -- the giant machine (ball radius)
Layout.stageRare = { u = -19, v = 4, radius = 8 } -- the rarest gumball car
Layout.stageGold = { u = 19, v = 4, radius = 8 } -- the gold car of this week's #1
Layout.oddsSign = { u = 14, v = -14.2, w = 9, h = 6.4 } -- standing sign by the machine

-- Inside the customize garage: the turntable, and the shop: the counter and the 3 display cars.
Layout.turntable = { u = 0, v = -2, radius = 8 }
Layout.counter = { u = 0, v = -6, w = 22, d = 4 }
Layout.shopCars = { { u = -14, v = 6 }, { u = 0, v = 8 }, { u = 14, v = 6 } }

-- The two physical boards (L47): beside the front path near the spawn, turned toward it. The
-- readable face is the +z side before the yaw, so a board turned +-60 degrees looks at the path.
Layout.boards = {
	weekly = { x = -19, z = 37, w = 14, h = 12, yawDeg = 60 },
	wins = { x = 19, z = 37, w = 14, h = 12, yawDeg = -60 },
}

-- Light gray paths: spawn -> ring, ring -> each building, two side entrances.
Layout.paths = {
	{ x = 0, z = 43, w = 14, d = 30, yawDeg = 0 }, -- the front path (spawn side)
	{ x = 0, z = -27, w = 18, d = 20, yawDeg = 0 }, -- ring to the workshop
	{ x = -33.2, z = -19.9, w = 14, d = 42, yawDeg = 52 }, -- to the customize garage
	{ x = 32.6, z = -20, w = 14, d = 42, yawDeg = -52 }, -- to the shop
	{ x = -56, z = -12, w = 14, d = 64, yawDeg = 90 }, -- left entrance
	{ x = 56, z = -12, w = 14, d = 64, yawDeg = 90 }, -- right entrance
}

-- The entrance arch over the spawn path (no sign on it: carter's L55, nothing big at the spawn).
Layout.arch = { z = 54, halfOpening = 11, height = 16 }

-- Where the music plays from (silent until carter gives a sound id).
Layout.music = { x = 0, y = 12, z = 0 }

-- Parked cars on car-show stands: 2 columns on each side of the front path, nose toward the path.
-- 4 rows, so 16 spots. `side` is -1 (left) or 1 (right). A player's car takes a spot; empty spots
-- show a car you can win from the gumball machine (carter's L23, L24).
Layout.parkingSize = { w = 14, d = 10.4 } -- one spot: along the car, across the car
Layout.parkingRows = { 14, 25, 36, 47 }
Layout.parkingCols = { 46, 62 } -- |x| of the two columns (the spot middles)

export type Spot = { x: number, z: number, yawDeg: number, side: number }

function Layout.parking(): { Spot }
	local list: { Spot } = {}
	for _, side in { -1, 1 } do
		for _, cx in Layout.parkingCols do
			for _, z in Layout.parkingRows do
				-- a car drawn facing +z turned 90 degrees faces +x; the left side faces +x
				table.insert(
					list,
					{ x = side * cx, z = z, yawDeg = side == -1 and 90 or -90, side = side }
				)
			end
		end
	end
	return list
end

-- The tire wall round the plaza: a station every `Layout.tireStep` studs, except at the entrances.
Layout.tireStep = 5.6
Layout.entrances = {
	{ axis = "z", pos = Layout.plaza.frontZ, from = -9, to = 9 }, -- front (spawn path), x range
	{ axis = "x", pos = -Layout.plaza.halfX, from = -29, to = 5 }, -- left entrance, z range
	{ axis = "x", pos = Layout.plaza.halfX, from = -29, to = 5 }, -- right entrance
}

export type Station = { x: number, z: number, yawDeg: number, light: boolean }

local function inGap(axis: string, along: number, edgePos: number): boolean
	for _, e in Layout.entrances do
		if e.axis == axis and e.pos == edgePos and along > e.from and along < e.to then
			return true
		end
	end
	return false
end

function Layout.tireWall(): { Station }
	local list: { Station } = {}
	local p = Layout.plaza
	local n = 0
	local function add(x: number, z: number, yawDeg: number)
		n += 1
		table.insert(list, { x = x, z = z, yawDeg = yawDeg, light = n % 5 == 1 })
	end
	local x = -p.halfX
	while x <= p.halfX + 0.01 do
		if not inGap("z", x, p.frontZ) then
			add(x, p.frontZ, 0)
		end
		x += Layout.tireStep
	end
	local z = p.frontZ
	while z >= p.backZ - 0.01 do
		for _, sx in { -1, 1 } do
			if not inGap("x", z, sx * p.halfX) then
				add(sx * p.halfX, z, 90)
			end
		end
		z -= Layout.tireStep
	end
	return list
end

-- Big painted signs on the tire wall, all looking at the PLAY ring. x, z = the middle of the board
-- on the wall line; `yawDeg` turns a sign drawn facing +z (180 = front wall, 90 = left, -90 =
-- right). w, h = board size, the bottom sits `signBottom` up so it stands above the tires.
-- `arrow`: 1 = points right, -1 = left, 0 = none (as seen from the plaza); `frame` = trim color.
export type WallSign = {
	x: number,
	z: number,
	yawDeg: number,
	w: number,
	h: number,
	text: string,
	arrow: number,
	frame: string,
}
Layout.wallSignBottom = 6 -- clear of the tire tops
Layout.wallSigns = {
	{
		x = -26,
		z = Layout.plaza.frontZ,
		yawDeg = 180,
		w = 14,
		h = 6,
		text = "PLAY HERE",
		arrow = 0,
		frame = "orange",
	},
	-- the side signs sit just in front of the side entrances; "back" is to the viewer's right / left
	{
		x = -Layout.plaza.halfX,
		z = 14,
		yawDeg = 90,
		w = 16,
		h = 8,
		text = "GUMBALL",
		arrow = 1,
		frame = "blue",
	},
	{
		x = Layout.plaza.halfX,
		z = 14,
		yawDeg = -90,
		w = 14,
		h = 8,
		text = "SHOP",
		arrow = -1,
		frame = "orange",
	},
}

-- Invisible tall walls so nobody climbs props, walks into a garage or out of the plaza.
-- Rect: centre + size, all of them 40 studs tall.
function Layout.blockers(): { Rect }
	local list: { Rect } = {}
	local p = Layout.plaza
	local function add(x: number, z: number, w: number, d: number, yaw: number?)
		table.insert(list, { x = x, z = z, w = w, d = d, yawDeg = yaw or 0 })
	end
	-- the plaza edge, one stud past the tire wall
	add(0, p.frontZ + 3, p.halfX * 2 + 10, 2) -- front
	add(0, p.backZ - 4, p.halfX * 2 + 10, 2) -- back
	add(-p.halfX - 3, 0, 2, (p.frontZ - p.backZ) + 12) -- left
	add(p.halfX + 3, 0, 2, (p.frontZ - p.backZ) + 12) -- right
	-- the three garage mouths (nobody walks inside)
	for _, b in { Layout.workshop, Layout.customize, Layout.shop } do
		local c, s = math.cos(math.rad(b.yawDeg)), math.sin(math.rad(b.yawDeg))
		local mouthV = b.d / 2 + 1.5
		table.insert(list, {
			x = b.x + s * mouthV,
			z = b.z + c * mouthV,
			w = b.w,
			d = 2,
			yawDeg = b.yawDeg,
		})
		-- the back and both side walls are solid too (the shell itself has no collision)
		for _, wall in
			{
				{ u = 0, v = -b.d / 2 - 1, w = b.w + 4, d = 2 },
				{ u = -b.w / 2 - 1, v = 0, w = 2, d = b.d },
				{ u = b.w / 2 + 1, v = 0, w = 2, d = b.d },
			}
		do
			table.insert(list, {
				x = b.x + c * wall.u + s * wall.v,
				z = b.z - s * wall.u + c * wall.v,
				w = wall.w,
				d = wall.d,
				yawDeg = b.yawDeg,
			})
		end
	end
	return list
end

-- Everything that takes floor room inside the plaza, for the "nothing overlaps" test.
function Layout.footprints(): { [string]: Rect }
	local out: { [string]: Rect } = {}
	local r = Layout.ring
	out.ring = { x = r.x, z = r.z, w = r.radius * 2, d = r.radius * 2, yawDeg = 0 }
	out.workshop = Layout.workshop
	out.customize = Layout.customize
	out.shop = Layout.shop
	out.boardWeekly = {
		x = Layout.boards.weekly.x,
		z = Layout.boards.weekly.z,
		w = Layout.boards.weekly.w,
		d = 2,
		yawDeg = Layout.boards.weekly.yawDeg,
	}
	out.boardWins = {
		x = Layout.boards.wins.x,
		z = Layout.boards.wins.z,
		w = Layout.boards.wins.w,
		d = 2,
		yawDeg = Layout.boards.wins.yawDeg,
	}
	for i, s in Layout.parking() do
		out["spot" .. i] =
			{ x = s.x, z = s.z, w = Layout.parkingSize.w, d = Layout.parkingSize.d, yawDeg = 0 }
	end
	local a = Layout.arch
	out.archLeft = { x = -a.halfOpening - 2, z = a.z, w = 4, d = 4, yawDeg = 0 }
	out.archRight = { x = a.halfOpening + 2, z = a.z, w = 4, d = 4, yawDeg = 0 }
	return out
end

-- Rectangle overlap by the separating axis test (both can be turned).
function Layout.overlaps(a: Rect, b: Rect): boolean
	local function corners(r: Rect): { { number } }
		local c, s = math.cos(math.rad(r.yawDeg)), math.sin(math.rad(r.yawDeg))
		local out = {}
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local lx, lz = sx * r.w / 2, sz * r.d / 2
				table.insert(out, { r.x + lx * c + lz * s, r.z - lx * s + lz * c })
			end
		end
		return out
	end
	local function axes(r: Rect): { { number } }
		local c, s = math.cos(math.rad(r.yawDeg)), math.sin(math.rad(r.yawDeg))
		return { { c, -s }, { s, c } }
	end
	local ca, cb = corners(a), corners(b)
	for _, rect in { a, b } do
		for _, ax in axes(rect) do
			local aMin, aMax, bMin, bMax = math.huge, -math.huge, math.huge, -math.huge
			for _, p in ca do
				local d = p[1] * ax[1] + p[2] * ax[2]
				aMin, aMax = math.min(aMin, d), math.max(aMax, d)
			end
			for _, p in cb do
				local d = p[1] * ax[1] + p[2] * ax[2]
				bMin, bMax = math.min(bMin, d), math.max(bMax, d)
			end
			if aMax <= bMin or bMax <= aMin then
				return false
			end
		end
	end
	return true
end

-- Is a point on the paved plaza (inside the tire wall)?
function Layout.onPlaza(x: number, z: number): boolean
	local p = Layout.plaza
	return math.abs(x) <= p.halfX and z <= p.frontZ and z >= p.backZ
end

-- The yaw (radians) a part drawn facing +z needs to look from the spawn at the ring middle.
function Layout.spawnYaw(): number
	local dx = Layout.ring.x - Layout.spawn.x
	local dz = Layout.ring.z - Layout.spawn.z
	return math.atan2(dx, dz)
end

-- Dirt paths on the grass outside, from each entrance away from the plaza: x, z, size x, size z, yaw.
function Layout.outsidePaths(): { { x: number, z: number, sx: number, sz: number, yawDeg: number } }
	return {
		{ x = 0, z = 84, sx = 14, sz = 50, yawDeg = 0 },
		{ x = 6, z = 122, sx = 14, sz = 40, yawDeg = 18 },
		{ x = -110, z = -12, sx = 44, sz = 12, yawDeg = 0 },
		{ x = -146, z = -30, sx = 36, sz = 12, yawDeg = 25 },
		{ x = 110, z = -12, sx = 44, sz = 12, yawDeg = 0 },
		{ x = 146, z = -30, sx = 36, sz = 12, yawDeg = -25 },
	}
end

-- Soft green hills far away: x, z, diameter.
function Layout.hills(): { { x: number, z: number, d: number } }
	return {
		{ x = -230, z = -250, d = 210 },
		{ x = 10, z = -290, d = 250 },
		{ x = 250, z = -240, d = 220 },
		{ x = 330, z = 0, d = 190 },
		{ x = 270, z = 230, d = 230 },
		{ x = -20, z = 300, d = 240 },
		{ x = -270, z = 230, d = 210 },
		{ x = -340, z = -20, d = 200 },
	}
end

export type Scenery = {
	kind: string, -- "tree" "rock"
	x: number,
	z: number,
	yawDeg: number,
	scale: number,
	far: boolean, -- far away: the first thing to cut if phones lag
}

-- How far outside the plaza edge the chain fence stands (see LobbyProps.fence).
Layout.fenceGap = 10

-- Round puffy trees (carter's L31) and a few rocks on the grass round the plaza, always the same
-- ones. No pines, bushes or flowers (L32). Nothing stands inside the fence, on a dirt path or
-- under the arch. The near ring comes first so the lobby always has trees in view; the far ones
-- are the first thing to cut if phones lag.
function Layout.scenery(): { Scenery }
	local list: { Scenery } = {}
	local seed = 20261020
	local function rnd(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local p = Layout.plaza
	local paths = Layout.outsidePaths()
	local gap = Layout.fenceGap + 5
	local function blocked(x: number, z: number, r: number): boolean
		if math.abs(x) < p.halfX + gap + r and z < p.frontZ + gap + r and z > p.backZ - gap - r then
			return true
		end
		for _, q in paths do
			local c, s = math.cos(math.rad(q.yawDeg)), math.sin(math.rad(q.yawDeg))
			local dx, dz = x - q.x, z - q.z
			local lx = math.abs(dx * c - dz * s)
			local lz = math.abs(dx * s + dz * c)
			if lx < q.sx / 2 + r + 1 and lz < q.sz / 2 + r + 1 then
				return true
			end
		end
		return false
	end
	local radius = { tree = 7, rock = 4 }
	local function crowded(kind: string, x: number, z: number): boolean
		for _, o in list do
			local rr = radius[kind] + radius[o.kind]
			if (o.x - x) ^ 2 + (o.z - z) ^ 2 < rr * rr then
				return true
			end
		end
		return false
	end
	-- pass: `reach` = how far from the plaza centre the picks may land, `far` marks the pass
	local function pass(want: { [string]: number }, reachX: number, reachZ: number, far: boolean)
		local order = { "tree", "rock" }
		local made: { [string]: number } = { tree = 0, rock = 0 }
		local tries = 0
		while tries < 20000 and (made.tree < want.tree or made.rock < want.rock) do
			tries += 1
			local kind = order[tries % #order + 1]
			if made[kind] < want[kind] then
				local x = (rnd() * 2 - 1) * reachX
				local z = (rnd() * 2 - 1) * reachZ
				if not blocked(x, z, radius[kind]) and not crowded(kind, x, z) then
					made[kind] += 1
					table.insert(list, {
						kind = kind,
						x = x,
						z = z,
						yawDeg = rnd() * 360,
						scale = 0.8 + rnd() * 0.6,
						far = far,
					})
				end
			end
		end
	end
	pass({ tree = 34, rock = 6 }, p.halfX + 70, 130, false)
	pass({ tree = 26, rock = 8 }, 300, 300, true)
	return list
end

return Layout
