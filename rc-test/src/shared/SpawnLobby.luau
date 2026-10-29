--!strict
-- The spawn lobby at the top of the street (carter's plan v5, shops from his v2 idea): where
-- everyone appears. A warm paved square with a drift car shop and a race car shop down the left,
-- a rock crawler shop and the upgrades garage down the right, everyone's car on a row of
-- turntables at the back, a giant toy car on a plinth in the middle, three
-- play pads at the front (drift, race, rock: stand on one and QueuePads sends you to an open plot
-- of that kind), and a checkered arch where the street starts. Lamps, bunting and trees round it. No text.
--
-- Lobby-local space: (0, 0, 0) is the middle of the square on the floor. +Z is the front (the
-- street), -Z the back. SpawnLobby.build() takes a CFrame whose LookVector points down the
-- street and turns it round to this. Plain numbers in parts()/allParts() (Lune tests load them).

-- Loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local CarCatalog = sibling("CarCatalog")
local CarGlow = sibling("CarGlow")
local Features = sibling("Features")
local Garage = sibling("Garage")

type V3 = Garage.V3
type Piece = Garage.Piece
type Mesh = Garage.Mesh

local SpawnLobby = {}

SpawnLobby.WIDTH = 120 -- x
SpawnLobby.DEPTH = 72 -- z
-- Everything fits in here (trees stand just behind the back edge).
SpawnLobby.BOX = { minX = -60, maxX = 60, minZ = -45, maxZ = 36, maxY = 15 }
-- The buildings down the two sides, open fronts facing the middle (yaw: which way the open front
-- turns, in degrees; 90 = toward +X). Drift and race shops on the left, the upgrades garage on
-- the right (carter's spawn plan v2; rocks dropped 23:42).
SpawnLobby.BUILDINGS = if Features.CVC
	then {
		-- Car VS Car (carter's yes 10-26): the race shop's spot is the crate shop; no drift shop
		{ kind = "crates", x = -50, z = 12, yaw = 90 },
		{ kind = "garage", x = 50, z = 10, yaw = -90 },
	}
	else {
		{ kind = "drift", x = -50, z = -20, yaw = 90 },
		{ kind = "race", x = -50, z = 12, yaw = 90 },
		{ kind = "garage", x = 50, z = 10, yaw = -90 },
	}
SpawnLobby.SPAWN = { x = 0, z = 15 } -- where people appear, looking at the pads and the street (+Z)
SpawnLobby.GAP = 13 -- the front edge is open for |x| < GAP: the walk onto the street
SpawnLobby.STATUE = { x = 0, z = -6 }
SpawnLobby.STAND_Z = -28
SpawnLobby.STANDS = { -19.25, -13.75, -8.25, -2.75, 2.75, 8.25, 13.75, 19.25 } -- the dream cars
-- On the stands: the gumball's cars (rare to legend), each glowing its kind, so a new kid sees
-- what there is to win (tycoon plan)
SpawnLobby.STAND_CARS = {} :: { string }
for _, g in CarCatalog.GUMBALL do
	table.insert(SpawnLobby.STAND_CARS, g.car.id)
end
SpawnLobby.PAD_Z = 23
-- play pads (queue pads): race and drift send you to an open plot of that kind (each owner picks
-- race or drift; rocks dropped, carter 23:42)
-- (Features.SMASH: Car VS Car Smash, FINISH-JOBS; in Studio also workspace attribute Smash, the
-- same switch Main gives MatchRunner)
SpawnLobby.SMASH = Features.CVC
	and (
		Features.SMASH
		or (
			script ~= nil
			and game:GetService("RunService"):IsStudio()
			and workspace:GetAttribute("Smash") == true
		)
	)
SpawnLobby.PADS = if SpawnLobby.SMASH
	then { { x = 0, kind = "smash", color = { 255, 64, 160 } } } -- Smash: one SMASH! portal
	elseif Features.CVC then { { x = 0, kind = "race", color = { 226, 52, 46 } } } -- racing only
	else {
		{ x = -27, kind = "drift", color = { 150, 70, 210 } },
		{ x = 0, kind = "race", color = { 226, 52, 46 } },
	}
-- the gumball machine (Car VS Car has crates instead)
SpawnLobby.HAS_GUMBALL = not Features.CVC
SpawnLobby.ARCH_Z = 33.5
SpawnLobby.GUMBALL = { x = 17, z = 7 } -- the gumball machine (rare cars), by the spawn
-- Where you step out of each shop (in front of its open side), and the walk from there out onto
-- the street: across to a side lane (x = +-LANE_X, clear of the play pads, the statue and the
-- gumball), then down it through the front gap. Lobby-local points; PlotGuide lays arrows on it.
SpawnLobby.DOORS = {
	{ x = -35, z = -20 }, -- drift shop
	{ x = -35, z = 12 }, -- race shop
	{ x = 35, z = 10 }, -- garage
	{ x = 13, z = 9 }, -- gumball
}
SpawnLobby.LANE_X = 11.8
SpawnLobby.CROSS_Z = 13 -- the row the walk crosses the square on
function SpawnLobby.exitPath(door: number): { { number } }
	local d = SpawnLobby.DOORS[door]
	local side = if d.x < 0 then -1 else 1
	local lane = side * SpawnLobby.LANE_X
	return {
		{ d.x, d.z },
		{ d.x, SpawnLobby.CROSS_Z },
		{ lane, SpawnLobby.CROSS_Z },
		{ lane, SpawnLobby.BOX.maxZ + 2 }, -- just out on the street
	}
end
SpawnLobby.LAMPS = {
	{ x = -34, z = -33 },
	{ x = 34, z = -33 },
	{ x = -38, z = -5 },
	{ x = 38, z = -5 },
	{ x = -57, z = 32 },
	{ x = 57, z = 32 },
	{ x = -10, z = 31 },
	{ x = 10, z = 31 },
}
SpawnLobby.TREES = { -54, -38, -22, -8, 8, 22, 38, 54 } -- x, behind the back edge
SpawnLobby.TREE_Z = -40
SpawnLobby.BUSHES = {
	{ x = -36, z = 31 },
	{ x = 36, z = 31 },
	{ x = -27, z = -13 },
	{ x = 27, z = -13 },
}

local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

local C = Garage.COLORS
local L = {
	paving = { 236, 214, 172 },
	paving2 = { 246, 232, 202 },
	kerb = { 196, 166, 124 },
	ring = { 240, 140, 40 },
	stone = { 150, 162, 182 },
	iron = { 46, 48, 54 },
	glow = { 255, 214, 140 },
	trunk = { 130, 88, 56 },
	leaf = { 104, 186, 78 },
	pine = { 58, 140, 84 },
	pot = { 196, 110, 66 },
	yellow = { 255, 205, 40 },
	black = { 30, 30, 34 },
	white = { 245, 245, 245 },
	red = { 230, 60, 50 },
	green = { 70, 210, 90 },
	statue = { 214, 48, 44 },
}
-- one colour per player's car on the stands, and the bunting
local CAR_COLORS = {
	{ 214, 48, 44 },
	{ 40, 110, 220 },
	{ 246, 196, 40 },
	{ 70, 180, 80 },
	{ 240, 130, 30 },
	{ 150, 80, 210 },
	{ 30, 190, 200 },
	{ 240, 240, 240 },
}

local function cyl(rotZ: boolean?): Garage.Opts
	return { shape = "Cylinder", rot = if rotZ == false then v(0, 0, 0) else v(0, 0, 90) }
end

-- The square itself and everything on it except the two buildings.
function SpawnLobby.parts(): { Piece }
	local out: { Piece } = {}
	local add = Garage.adder(out)
	local W, D = SpawnLobby.WIDTH, SpawnLobby.DEPTH
	local front, back = D / 2, -D / 2

	-- ===== Ground: warm paving, kerb round three sides, a cream circle with an orange ring =====
	add("Ground", "Floor", v(W, 0.4, D), v(0, -0.2, 0), L.paving)
	add("Ground", "Ring", v(0.03, 30, 30), v(0, 0.015, -4), L.ring, {
		shape = "Cylinder",
		rot = v(0, 0, 90),
		collide = false,
	})
	add("Ground", "Circle", v(0.05, 27, 27), v(0, 0.025, -4), L.paving2, {
		shape = "Cylinder",
		rot = v(0, 0, 90),
		collide = false,
	})
	add(
		"Ground",
		"Path",
		-- (from the ring's outer edge: it used to start inside and cut a gap in it, playtest u18)
		v(2 * SpawnLobby.GAP - 6, 0.05, front - 11),
		v(0, 0.025, (front + 11) / 2),
		L.paving2,
		{
			collide = false,
		}
	)
	add("Ground", "KerbBack", v(W, 0.6, 1), v(0, 0.3, back + 0.5), L.kerb)
	add("Ground", "KerbLeft", v(1, 0.6, D), v(-W / 2 + 0.5, 0.3, 0), L.kerb)
	add("Ground", "KerbRight", v(1, 0.6, D), v(W / 2 - 0.5, 0.3, 0), L.kerb)
	local side = W / 2 - SpawnLobby.GAP
	for _, sx in { -1, 1 } do
		add(
			"Ground",
			"KerbFront",
			v(side, 0.6, 1),
			v(sx * (SpawnLobby.GAP + side / 2), 0.3, front - 0.5),
			L.kerb
		)
	end

	-- ===== Giant toy car on a round plinth in the middle =====
	local st = SpawnLobby.STATUE
	add("Statue", "Plinth", v(2, 9, 9), v(st.x, 1, st.z), L.stone, cyl())
	add("Statue", "Band", v(0.4, 9.6, 9.6), v(st.x, 2.2, st.z), L.ring, cyl())
	Garage.toyCar(add, "StatueCar", v(st.x, 2.4, st.z), 215, L.statue, 1.9) -- nose to the spawn

	-- ===== Everyone's car on a turntable, in a row between the shop and the garage =====
	for i, x in SpawnLobby.STANDS do
		local g = "Stand" .. i
		local z = SpawnLobby.STAND_Z
		add(g, "Ring", v(0.06, 5.1, 5.1), v(x, 0.03, z), C.cyan, {
			shape = "Cylinder",
			rot = v(0, 0, 90),
			material = "Neon",
			collide = false,
		})
		add(g, "Plinth", v(0.8, 4.8, 4.8), v(x, 0.4, z), C.dark, cyl())
		add(g, "Top", v(0.15, 4.4, 4.4), v(x, 0.875, z), C.board, {
			shape = "Cylinder",
			rot = v(0, 0, 90),
			collide = false,
		})
		local dream = CarCatalog.get(SpawnLobby.STAND_CARS[i])
		Garage.toyCar(
			add,
			"StandCars",
			v(x, 0.95, z),
			180,
			if dream then dream.color else CAR_COLORS[i],
			1,
			if dream then dream.style else nil
		)
	end

	-- ===== Bunting over the stands, on two poles =====
	local bz, by = SpawnLobby.STAND_Z - 3, 9.5
	for _, px in { -25, 25 } do
		add("Bunting", "Pole", v(0.4, 10, 0.4), v(px, 5, bz), L.iron)
		add("Bunting", "Knob", v(0.8, 0.8, 0.8), v(px, 10.2, bz), L.yellow, { shape = "Cylinder" })
	end
	add("Bunting", "Rope", v(50, 0.1, 0.1), v(0, by, bz), L.iron, { collide = false })
	for i = 0, 24 do
		add(
			"Bunting",
			"Flag",
			v(0.9, 0.9, 0.08),
			v(-24 + i * 2, by - 0.55, bz),
			CAR_COLORS[(i % 6) + 1],
			{
				rot = v(0, 0, 45),
				collide = false,
			}
		)
	end

	-- ===== Play pads at the front: a start grid in the pad's colour, a start light beside it =====
	for i, pad in SpawnLobby.PADS do
		local g = "QueuePad" .. i
		local px, pz = pad.x, SpawnLobby.PAD_Z
		add(
			g,
			"Rim",
			v(12.6, 0.06, 10.6),
			v(px, 0.03, pz),
			pad.color,
			{ material = "Neon", collide = false }
		)
		add(g, "Base", v(12, 0.08, 10), v(px, 0.04, pz), C.dark, { collide = false })
		if pad.kind == "smash" then
			-- Smash (FINISH-JOBS LOBBY): a hot pink portal ring standing over the pad, so it reads
			-- as "go through here" from the spawn; no start grid or start lights (no racing now)
			local R, N = 5.2, 16
			local seg = 2 * R * math.tan(math.pi / N) + 0.1
			for k = 0, N - 1 do
				local a = (k + 0.5) / N * 2 * math.pi
				add(
					"Portal" .. i, -- its own group: the PlayPad mesh would replace the pad's
					"Ring",
					v(seg, 0.9, 0.9),
					v(px + math.cos(a) * R, R + 0.35 + math.sin(a) * R, pz),
					pad.color,
					{ rot = v(0, 0, math.deg(a) + 90), material = "Neon", collide = false }
				)
			end
			continue
		end
		for _, lx in { -2.8, 2.8 } do
			add(
				g,
				"Lane",
				v(4.6, 0.1, 7),
				v(px + lx, 0.05, pz + 0.8),
				pad.color,
				{ collide = false }
			)
			add(
				g,
				"LaneIn",
				v(4, 0.11, 6.4),
				v(px + lx, 0.055, pz + 0.8),
				C.dark,
				{ collide = false }
			)
		end
		for row = 0, 1 do
			for t = 0, 9 do
				add(
					g,
					"Check",
					v(1.1, 0.12, 0.6),
					v(px - 4.95 + t * 1.1, 0.06, pz - 4.1 + row * 0.6),
					if (t + row) % 2 == 0 then L.black else L.white,
					{ collide = false }
				)
			end
		end
		-- beside the pad (not behind it: the middle pad sits on the walk to the street)
		local sg = "StartLight" .. i
		local lx, lz = px + 8, pz - 3
		add(sg, "Post", v(0.5, 5, 0.5), v(lx, 2.5, lz), L.iron)
		add(sg, "Box", v(3.8, 1.4, 0.8), v(lx, 5.6, lz), L.iron)
		for k, col in { L.red, L.yellow, L.green } do
			add(sg, "Light", v(0.2, 0.9, 0.9), v(lx - 2.2 + k * 1.1, 5.6, lz + 0.45), col, {
				shape = "Cylinder",
				rot = v(0, 90, 0),
				material = "Neon",
				collide = false,
			})
		end
	end

	-- ===== Checkered arch where the street starts =====
	local az = SpawnLobby.ARCH_Z
	local ax = SpawnLobby.GAP + 1.5
	if SpawnLobby.SMASH then
		-- Smash: no racing, so no checkers or start lights. A plain arch in the SMASH! portal's
		-- pink and navy, a sunny strip under the beam. No words.
		local pink, navy, sun = { 255, 64, 160 }, { 32, 40, 74 }, { 255, 210, 60 }
		for _, sx in { -1, 1 } do
			add("Arch", "Pillar", v(2.4, 13.6, 2.4), v(sx * ax, 6.8, az), navy)
			add("Arch", "Foot", v(3.2, 0.8, 3.2), v(sx * ax, 0.4, az), navy)
			add("Arch", "Cap", v(3.2, 1, 3.2), v(sx * ax, 14, az), pink)
		end
		add("Arch", "Beam", v(2 * ax, 1.6, 1.6), v(0, 12.8, az), pink)
		add("Arch", "Trim", v(2 * ax - 2.4, 0.4, 1.7), v(0, 11.8, az), sun, { collide = false })
	else
		for _, sx in { -1, 1 } do
			add("Arch", "Pillar", v(2.4, 13.6, 2.4), v(sx * ax, 6.8, az), C.blue)
			add("Arch", "Foot", v(3.2, 0.8, 3.2), v(sx * ax, 0.4, az), L.iron)
			add("Arch", "Cap", v(3, 0.6, 3), v(sx * ax, 13.9, az), C.blue)
		end
		add("Arch", "Beam", v(2 * ax, 0.8, 1.6), v(0, 13.2, az), C.blue)
		-- the banner is solid black and white blocks, so it stays crisp from both sides
		local span = 2 * ax - 2.4
		local tw = span / 16
		for t = 0, 15 do
			local x = -span / 2 + tw / 2 + t * tw
			for row = 0, 2 do
				add(
					"Arch",
					"Check",
					v(tw, tw, 1.2),
					v(x, 12.8 - tw / 2 - row * tw, az),
					if (t + row) % 2 == 0 then L.black else L.white,
					{ collide = false }
				)
			end
		end
		add(
			"Arch",
			"Trim",
			v(span, 0.3, 1.4),
			v(0, 12.8 - 3 * tw - 0.15, az),
			C.blue,
			{ collide = false }
		)
	end

	-- ===== Gumball machine: a big toy one, a dome of coloured balls on a red stand =====
	if SpawnLobby.HAS_GUMBALL then
		local g, gx, gz = "Gumball", SpawnLobby.GUMBALL.x, SpawnLobby.GUMBALL.z
		add(g, "Base", v(3.6, 3.6, 3.6), v(gx, 1.8, gz), L.statue)
		add(g, "Chute", v(1.4, 1, 0.5), v(gx, 1.3, gz + 1.9), L.iron)
		add(g, "Knob", v(0.4, 1.1, 1.1), v(gx, 2.7, gz + 1.95), C.white, {
			shape = "Cylinder",
			rot = v(0, 90, 0),
		})
		add(g, "Neck", v(0.6, 3.2, 3.2), v(gx, 3.9, gz), L.iron, {
			shape = "Cylinder",
			rot = v(0, 0, 90),
		})
		-- the balls, in three rings and a top one
		local cols = { L.red, L.yellow, L.green, C.blue, L.ring, { 255, 120, 190 }, C.white }
		local n = 0
		for ring, r in { 1.5, 1.7, 1.1 } do
			local y = 4.7 + (ring - 1) * 0.95
			local count = if ring == 3 then 5 else 8
			for k = 1, count do
				n += 1
				local a = (k + ring * 0.5) / count * 2 * math.pi
				add(
					g,
					"Ball",
					v(1.1, 1.1, 1.1),
					v(gx + math.cos(a) * r, y, gz + math.sin(a) * r),
					cols[(n % #cols) + 1],
					{ shape = "Ball", collide = false }
				)
			end
		end
		add(
			g,
			"Ball",
			v(1.1, 1.1, 1.1),
			v(gx, 7.2, gz),
			L.yellow,
			{ shape = "Ball", collide = false }
		)
		add(g, "Cap", v(0.8, 2, 2), v(gx, 7.9, gz), L.statue, {
			shape = "Cylinder",
			rot = v(0, 0, 90),
		})
	end

	-- ===== Lamps =====
	for i, p in SpawnLobby.LAMPS do
		local g = "Lamp" .. i
		add(g, "Base", v(1.6, 0.8, 1.6), v(p.x, 0.4, p.z), L.iron)
		add(g, "Post", v(0.6, 9, 0.6), v(p.x, 4.5, p.z), L.iron)
		add(g, "Cap", v(1.8, 0.4, 1.8), v(p.x, 11.3, p.z), L.iron)
		add(
			g,
			"Light",
			v(1.3, 1.8, 1.3),
			v(p.x, 10.1, p.z),
			L.glow,
			{ material = "Neon", collide = false, light = 18 }
		)
	end

	-- ===== Trees behind the back, bushes and flower pots round the edge =====
	for i, x in SpawnLobby.TREES do
		local g = "Tree" .. i
		local z = SpawnLobby.TREE_Z + (if i % 2 == 0 then 1.5 else -1)
		add(g, "Trunk", v(1.2, 4, 1.2), v(x, 2, z), L.trunk)
		if i % 2 == 1 then
			add(g, "Leaves", v(6, 5, 6), v(x, 6.5, z), L.leaf, { rot = v(0, 45, 0) })
			add(g, "Leaves", v(4, 3, 4), v(x + 1, 9, z), L.leaf, { rot = v(0, 20, 0) })
		else
			for k, sz in { 6, 4.6, 3 } do
				add(
					g,
					"Needles",
					v(sz, 2.6, sz),
					v(x, 3.8 + k * 2.2, z),
					L.pine,
					{ rot = v(0, 45, 0) }
				)
			end
		end
	end
	for i, p in SpawnLobby.BUSHES do
		local g = "Bush" .. i
		add(g, "Pot", v(1.2, 2, 2), v(p.x, 0.6, p.z), L.pot, cyl())
		add(g, "Leaves", v(2.6, 2, 2.6), v(p.x, 2.2, p.z), L.leaf, { rot = v(0, 45, 0) })
	end

	return out
end

-- Every piece, the shop and the garage too (shifted to their spots). For pictures and tests.
function SpawnLobby.allParts(): { Piece }
	local out = SpawnLobby.parts()
	for _, b in SpawnLobby.BUILDINGS do
		local r = math.rad(b.yaw)
		local c, sn = math.cos(r), math.sin(r)
		for _, p in Garage.parts(b.kind) do
			p.group = b.kind .. "/" .. p.group
			-- turned like CFrame.Angles(0, yaw, 0), then moved to its spot
			p.pos = v(b.x + c * p.pos.x + sn * p.pos.z, p.pos.y, b.z - sn * p.pos.x + c * p.pos.z)
			p.rot = v(p.rot.x, p.rot.y + b.yaw, p.rot.z)
			table.insert(out, p)
		end
	end
	return out
end

-- carter's Meshy models for the lobby's own props (see Garage.Mesh). No model, blocks stay.
SpawnLobby.MESHES = {} :: { Mesh }
do
	local M = SpawnLobby.MESHES
	local function mesh(
		model: string,
		group: string,
		at: V3,
		fit: V3,
		keep: { string },
		collide: boolean
	)
		table.insert(M, {
			model = model,
			group = group,
			at = at,
			fit = fit,
			long = if fit.z > fit.x then "z" else "x",
			keep = keep,
			collide = collide,
		})
	end
	local st = SpawnLobby.STATUE
	table.insert(M, {
		model = "RockCrawler", -- carter's own truck, made big
		group = "StatueCar",
		at = v(st.x, 2.4, st.z),
		-- smaller than the old 7x7x11: on a phone it was the biggest car on screen (4.4%), bigger
		-- than the kid's own (art report #2)
		fit = v(5, 5, 7.8),
		long = "z",
		keep = {},
		collide = false,
		carSkin = true,
	})
	for i, x in SpawnLobby.STANDS do
		mesh(
			"Turntable",
			"Stand" .. i,
			v(x, 0, SpawnLobby.STAND_Z),
			v(4.8, 0.9, 4.8),
			{ "Ring" },
			true
		)
	end
	for i, pad in SpawnLobby.PADS do
		if pad.kind == "smash" then
			continue
		end
		mesh(
			"StartLight",
			"StartLight" .. i,
			v(pad.x + 8, 0, SpawnLobby.PAD_Z - 3),
			v(4, 6.4, 1.2),
			{},
			true
		)
	end
	-- carter's PlayPad (batch 6) over each play pad's start grid. The neon rim stays round it
	-- (the pad's colour, and it blinks while someone waits); the base stays as the hidden tagged
	-- QueuePad that the server watches.
	for i, pad in SpawnLobby.PADS do
		if pad.kind == "smash" then
			continue -- its start grid is a race look: the SMASH! pad is its rim, base and portal
		end
		table.insert(M, {
			model = "PlayPad",
			group = "QueuePad" .. i,
			at = v(pad.x, 0, SpawnLobby.PAD_Z),
			fit = v(12, 1, 10),
			long = "x",
			keep = { "Rim", "Base" },
			hide = { "Base" },
			collide = false,
		})
	end
	-- carter's StartGantry (batch 6; drive through along Z, lights at its -Z) in place of the
	-- checkered arch where the street starts: the lights look back at the spawn. Not in Smash
	-- (start lights are racing): the plain pink arch stays.
	if not SpawnLobby.SMASH then
		local ax = SpawnLobby.GAP + 1.5
		table.insert(M, {
			model = "StartGantry",
			group = "Arch",
			at = v(0, 0, SpawnLobby.ARCH_Z),
			fit = v(2 * ax + 3.2, 14.5, 3.2),
			long = "x",
			keep = {},
			collide = true,
		})
	end
	for i, p in SpawnLobby.LAMPS do
		mesh("StreetLamp", "Lamp" .. i, v(p.x, 0, p.z), v(2, 11.5, 2), {}, true)
	end
	for i, x in SpawnLobby.TREES do
		local z = SpawnLobby.TREE_Z + (if i % 2 == 0 then 1.5 else -1)
		if i % 2 == 1 then
			mesh("LeafyTree", "Tree" .. i, v(x, 0, z), v(9, 11, 9), {}, true)
		else
			mesh("PineTree", "Tree" .. i, v(x, 0, z), v(7, 12, 7), {}, true)
		end
	end
	for i, p in SpawnLobby.BUSHES do
		mesh("FlowerPot", "Bush" .. i, v(p.x, 0, p.z), v(2.6, 3.2, 2.6), {}, true)
	end
end

-- Where people appear (world), looking at the statue. `at` as in build().
function SpawnLobby.spawnCFrame(at: CFrame): CFrame
	local origin = at * CFrame.Angles(0, math.pi, 0)
	local s = SpawnLobby.SPAWN
	-- facing the play pads and the street (lobby-local +Z): where to go first, nothing in the way
	return origin * CFrame.new(s.x, 3, s.z) * CFrame.Angles(0, math.pi, 0)
end

-- Builds it under `parent`. `at` is the middle of the square on the floor, its LookVector
-- pointing down the street. Play pad bases are tagged "QueuePad" (attributes Pad = 1..3 and
-- PlotType = "drift" / "race"); QueuePads (server) watches them.
function SpawnLobby.build(parent: Instance, at: CFrame): Model
	local origin = at * CFrame.Angles(0, math.pi, 0) -- lobby-local +Z = the LookVector
	local model = Instance.new("Model")
	model.Name = "SpawnLobby"
	local groups = Garage.makeParts(SpawnLobby.parts(), model, origin)
	model.PrimaryPart = (groups.Ground :: Model):FindFirstChild("Floor") :: BasePart
	for i, pad in SpawnLobby.PADS do
		local base = (groups["QueuePad" .. i] :: Model):FindFirstChild("Base") :: BasePart
		base:SetAttribute("Pad", i)
		base:SetAttribute("PlotType", pad.kind)
		game:GetService("CollectionService"):AddTag(base, "QueuePad")
	end
	-- CarShops (client) puts the "spin" prompt on it
	local gumball = groups.Gumball and groups.Gumball:FindFirstChild("Base")
	if gumball then
		game:GetService("CollectionService"):AddTag(gumball, "Gumball")
	end
	Garage.useMeshes(groups, origin, SpawnLobby.MESHES)
	-- each dream car's kind: its turntable ring glows in that colour
	for i in SpawnLobby.STANDS do
		local stand = groups["Stand" .. i]
		local ring = stand and stand:FindFirstChild("Ring", true)
		local id = SpawnLobby.STAND_CARS[i]
		if ring and ring:IsA("BasePart") and id then
			local kind = CarCatalog.rarity(id)
			ring.Color = Color3.fromRGB(kind.color[1], kind.color[2], kind.color[3])
			CarGlow.apply(ring, kind.id)
		end
	end
	for _, b in SpawnLobby.BUILDINGS do
		Garage.build(
			model,
			origin
				* CFrame.new(b.x, 0, b.z)
				* CFrame.Angles(0, math.rad(b.yaw), 0)
				* CFrame.Angles(0, math.pi, 0),
			nil,
			nil,
			b.kind
		)
	end
	model.Parent = parent
	return model
end

return SpawnLobby
