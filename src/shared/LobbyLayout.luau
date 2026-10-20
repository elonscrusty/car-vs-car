--!strict
-- The Car Battle Lobby (carter's reference sheet + 70 picks, docs/LOBBY_SPEC.md). Pure data and
-- small geometry helpers, no Roblox objects, so the tests can check every number. The server
-- builds it from this file (Lobby.luau and the Lobby* modules next to it).
--
-- Studs, relative to the lobby origin. x = right, z = toward the spawn (+z = front, the player
-- looks toward -z), y = up, the asphalt top is y = 0. The sheet is 220 x 180 studs and 32 high.

local Layout = {}

export type Rect = { x: number, z: number, w: number, d: number, yawDeg: number } -- centre + full size

Layout.size = { x = 220, z = 180, height = 32 }
Layout.walkSpeed = 24 -- a bit faster than the normal 16

Layout.colors = {
	asphalt = { 72, 83, 99 }, -- #485363
	asphaltDark = { 58, 66, 80 },
	path = { 176, 181, 190 }, -- light gray paths
	orange = { 245, 130, 32 }, -- #F58220
	blue = { 37, 141, 221 }, -- #258DDA
	tire = { 36, 39, 43 }, -- #24272B
	grass = { 127, 186, 66 }, -- #7FBA42
	hill = { 142, 200, 84 },
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
}

-- The paved plaza (asphalt) inside the tire walls. The grass border and the world sit outside it.
Layout.plaza = { halfX = 100, frontZ = 84, backZ = -86, corner = 14 }

-- Spawn: on the front path, looks at the middle of the PLAY pads.
Layout.spawn = { x = 0, z = 68, size = 8 }

-- The big PLAY ring in the middle and the four small pads on it.
Layout.ring = { x = 0, z = 8, radius = 24, hubRadius = 6 }
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
Layout.workshop = { x = 0, z = -68, w = 56, d = 34, h = 24, yawDeg = 0 }
Layout.customize = { x = -74, z = -58, w = 40, d = 30, h = 18, yawDeg = 32 }
Layout.shop = { x = 74, z = -58, w = 44, d = 30, h = 18, yawDeg = -32 }

-- Inside the workshop (workshop-local: u across, v toward the mouth, from its middle).
Layout.gumball = { u = 0, v = -8, radius = 8.5 } -- the giant machine (ball radius)
Layout.stageRare = { u = -19, v = 4, radius = 8 } -- the rarest gumball car
Layout.stageGold = { u = 19, v = 4, radius = 8 } -- the gold car of this week's #1
Layout.oddsSign = { u = 0, v = 11, w = 14, h = 9 } -- standing sign by the machine

-- Inside the customize garage: the turntable, and the shop: the counter and the 3 display cars.
Layout.turntable = { u = 0, v = -2, radius = 8 }
Layout.counter = { u = 0, v = -6, w = 22, d = 4 }
Layout.shopCars = { { u = -14, v = 6 }, { u = 0, v = 8 }, { u = 14, v = 6 } }

-- The two physical boards, one each side of the workshop, turned a little toward the ring.
Layout.boards = {
	weekly = { x = -36, z = -58, w = 15, h = 12, yawDeg = 14 },
	wins = { x = 36, z = -58, w = 15, h = 12, yawDeg = -14 },
}

-- Light gray paths: spawn -> ring, ring -> each building, two side entrances.
Layout.paths = {
	{ x = 0, z = 76, w = 14, d = 26, yawDeg = 0 }, -- the front path (spawn side)
	{ x = 0, z = -38, w = 18, d = 44, yawDeg = 0 }, -- ring to the workshop
	{ x = -42, z = -30, w = 14, d = 50, yawDeg = -55 }, -- to the customize garage
	{ x = 42, z = -30, w = 14, d = 50, yawDeg = 55 }, -- to the shop
	{ x = -70, z = -12, w = 14, d = 62, yawDeg = 90 }, -- left entrance
	{ x = 70, z = -12, w = 14, d = 62, yawDeg = 90 }, -- right entrance
}

-- Orange / blue X flags at the entrances: two poles at each, colors alternate.
Layout.flags = {
	{ x = -9, z = 80, color = "orange" },
	{ x = 9, z = 80, color = "blue" },
	{ x = -98, z = -22, color = "orange" },
	{ x = -98, z = -2, color = "blue" },
	{ x = 98, z = -22, color = "blue" },
	{ x = 98, z = -2, color = "orange" },
}

-- The entrance arch over the spawn path with the big CAR VS CAR sign.
Layout.arch = { z = 82, halfOpening = 11, height = 26, signW = 34, signH = 9 }

-- Where the music plays from (silent until carter gives a sound id).
Layout.music = { x = 0, y = 12, z = 0 }

Layout.benches = {
	{ x = -26, z = 40, yawDeg = 90 },
	{ x = 26, z = 40, yawDeg = -90 },
	{ x = -30, z = -22, yawDeg = 0 },
	{ x = 30, z = -22, yawDeg = 0 },
	{ x = -14, z = 58, yawDeg = 90 },
	{ x = 14, z = 58, yawDeg = -90 },
}
Layout.cones = {
	{ x = -8, z = 50 },
	{ x = 8, z = 50 },
	{ x = -52, z = -16 },
	{ x = -50, z = -12 },
	{ x = 52, z = -16 },
	{ x = 50, z = -12 },
	{ x = -22, z = -50 },
	{ x = 22, z = -50 },
	{ x = -9, z = 90 },
}
Layout.carts = {
	{ x = -50, z = -44, yawDeg = 20 },
	{ x = 50, z = -44, yawDeg = -20 },
	{ x = -18, z = -32, yawDeg = 0 },
}

-- Parked player cars: 2 columns on each side of the front path, nose toward the path.
-- 6 rows, so 24 spots. `side` is -1 (left) or 1 (right).
Layout.parkingSize = { w = 14, d = 9.5 } -- one spot: along the car, across the car
Layout.parkingRows = { 22, 32.5, 43, 53.5, 64, 74.5 }
Layout.parkingCols = { 58, 76 } -- |x| of the two columns (the spot middles)

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
	{ axis = "z", pos = 84, from = -9, to = 9 }, -- front (spawn path), x range
	{ axis = "x", pos = -100, from = -29, to = 5 }, -- left entrance, z range
	{ axis = "x", pos = 100, from = -29, to = 5 }, -- right entrance
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
	for i, b in Layout.benches do
		out["bench" .. i] = { x = b.x, z = b.z, w = 3, d = 8, yawDeg = 0 }
	end
	for i, c in Layout.carts do
		out["cart" .. i] = { x = c.x, z = c.z, w = 6, d = 4, yawDeg = c.yawDeg }
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
		{ x = 0, z = 112, sx = 14, sz = 50, yawDeg = 0 },
		{ x = 6, z = 150, sx = 14, sz = 40, yawDeg = 18 },
		{ x = -124, z = -12, sx = 44, sz = 12, yawDeg = 0 },
		{ x = -160, z = -30, sx = 36, sz = 12, yawDeg = 25 },
		{ x = 124, z = -12, sx = 44, sz = 12, yawDeg = 0 },
		{ x = 160, z = -30, sx = 36, sz = 12, yawDeg = -25 },
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
	kind: string, -- "tree" "pine" "rock" "bush" "flower"
	x: number,
	z: number,
	yawDeg: number,
	scale: number,
	far: boolean, -- far away: the first thing to cut if phones lag
	pick: number, -- which flower color
}

-- Trees, rocks, bushes and flowers on the grass round the plaza, always the same ones. Nothing
-- stands on the plaza, on a dirt path or under the arch.
function Layout.scenery(): { Scenery }
	local list: { Scenery } = {}
	local seed = 20261020
	local function rnd(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local p = Layout.plaza
	local paths = Layout.outsidePaths()
	local function blocked(x: number, z: number, r: number): boolean
		if math.abs(x) < p.halfX + 6 + r and z < p.frontZ + 6 + r and z > p.backZ - 8 - r then
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
	local want = { tree = 44, pine = 30, rock = 26, bush = 40, flower = 30 }
	local made: { [string]: number } = { tree = 0, pine = 0, rock = 0, bush = 0, flower = 0 }
	local order = { "tree", "pine", "rock", "bush", "flower" }
	local radius = { tree = 7, pine = 6, rock = 4, bush = 3, flower = 1.5 }
	local tries = 0
	local done = false
	while not done and tries < 30000 do
		tries += 1
		local kind = order[tries % #order + 1]
		if made[kind] < want[kind] then
			-- the sheet's own grass border (x +-110, z -90 .. 90) first, then farther out
			local x = (rnd() * 2 - 1) * 300
			local z = (rnd() * 2 - 1) * 300
			local far = math.abs(x) > 150 or math.abs(z) > 150
			if (not far or rnd() < 0.5) and not blocked(x, z, radius[kind]) then
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
