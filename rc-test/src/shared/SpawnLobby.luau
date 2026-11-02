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
local LobbyGarage = sibling("LobbyGarage")

type V3 = Garage.V3
type Piece = Garage.Piece
type Mesh = Garage.Mesh
local LobbyProps = sibling("LobbyProps")

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
-- where people appear, looking at the pads and the street (+Z). Smash (LOOK-BIBLE rule 9): further
-- back, so the first frame is the big SMASH! portal with the street behind it
SpawnLobby.SPAWN = if SpawnLobby.SMASH then { x = 0, z = -6 } else { x = 0, z = 15 }
-- Smash match pads (carter 10-29: no portal, "just pads to stand on to queue into the next match";
-- try C "light ring" of camera: lobby-preview/match-pads.html): three round light-ring pads in a
-- row, a short pink beam over each and three rings turning round it. Stand on one 2 s to join.
SpawnLobby.PAD_R = 6 -- a pad's radius (its plate is a little wider)
SpawnLobby.PAD_BEAM = 9 -- studs the light column stands
SpawnLobby.PAD_RINGS = { 2.6, 4.8, 7 } -- heights of the turning rings
SpawnLobby.PAD_BASE = 8.4 -- the hidden square the server watches, inside the round pad
SpawnLobby.SMASH_PADS = { -19, 0, 19 }
-- The Garage Hub look (carter picked layout F, 10-30; it replaces the Junkyard Dock): a garage hall
-- round the plaza (LobbyGarage), grey concrete paving, yellow hazard kerbs. Smash only; false =
-- the sandy plaza.
SpawnLobby.GARAGE = SpawnLobby.SMASH
if SpawnLobby.GARAGE then
	-- the back and front walls stand just outside the floor (1.6 deep)
	SpawnLobby.BOX = { minX = -60, maxX = 60, minZ = -41, maxZ = 38, maxY = 21 }
end
SpawnLobby.PADS = if SpawnLobby.SMASH
	then {
		{ x = SpawnLobby.SMASH_PADS[1], kind = "smash", color = { 255, 95, 180 } },
		{ x = SpawnLobby.SMASH_PADS[2], kind = "smash", color = { 255, 95, 180 } },
		{ x = SpawnLobby.SMASH_PADS[3], kind = "smash", color = { 255, 95, 180 } },
	} -- Smash: three light-ring match pads (bible pink)
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
-- Smash: the themed prop clusters (dress()), in the spawn view and off the walk lines
SpawnLobby.CLUSTERS = {
	{ x = -22, z = -2 },
	{ x = 22, z = -2 },
	{ x = -25, z = 26 },
	{ x = 25, z = 26 },
}
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
	-- (sandy, not near-white: under the sun the old cream read as snow, critic 10-29)
	paving = { 222, 186, 132 },
	paving2 = { 234, 204, 156 },
	kerb = { 166, 128, 88 },
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
if SpawnLobby.GARAGE then
	-- concrete, not sand: two greys under the yellow hazard kerbs
	L.paving = { 112, 116, 130 }
	L.paving2 = { 134, 138, 152 }
	L.kerb = { 255, 205, 40 }
end
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

	-- ===== Ground: warm paving, kerb round three sides, a light sand circle with an orange ring =====
	add("Ground", "Floor", v(W, 0.4, D), v(0, -0.2, 0), L.paving)
	-- (Smash: no spawn circle; the checker paving and the portal's painted ring instead)
	if not SpawnLobby.SMASH then
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
	end
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
	if SpawnLobby.SMASH then
		-- two-tone paving (LOOK-BIBLE rule 5, auditor looks round 2): big light slabs in a
		-- checker, none touching the walk out or the portal's painted ring
		local TILE, GAP_IN = 12, 1
		local pr = SpawnLobby.PAD_R + 1.5 -- clear round each pad's plate
		for ix = 0, math.floor(W / TILE) - 1 do
			for iz = 0, math.floor(D / TILE) - 1 do
				local x = -W / 2 + TILE / 2 + ix * TILE
				local z = back + TILE / 2 + iz * TILE
				local far = TILE * 0.71 -- the slab's half diagonal
				local clear = not (math.abs(x) < SpawnLobby.GAP + TILE / 2 and z > 11 - TILE / 2)
				for _, px in SpawnLobby.SMASH_PADS do
					if math.sqrt((x - px) ^ 2 + (z - SpawnLobby.PAD_Z) ^ 2) <= pr + 1 + far then
						clear = false
					end
				end
				for _, b in SpawnLobby.BUILDINGS do
					-- (off the shops and their yards: the crate mat lies flat on the plaza)
					if math.abs(x - b.x) < 22 and math.abs(z - b.z) < 22 then
						clear = false
					end
				end
				if (ix + iz) % 2 == 0 and clear then
					-- a darker edge band round every slab (auditor cheap tells #2)
					add(
						"Ground",
						"SlabEdge",
						v(TILE - GAP_IN, 0.04, TILE - GAP_IN),
						v(x, 0.02, z),
						if SpawnLobby.GARAGE then { 96, 100, 114 } else { 200, 158, 104 },
						{ collide = false }
					)
					add(
						"Ground",
						"Slab",
						v(TILE - GAP_IN - 1.6, 0.08, TILE - GAP_IN - 1.6),
						v(x, 0.04, z),
						L.paving2,
						{ collide = false }
					)
				end
			end
		end
	end
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
	-- (Smash: no statue, no toy cars on stands, no bunting: the portal is the one hero, and the
	-- spawn stands where the statue was)
	local st = SpawnLobby.STATUE
	if not SpawnLobby.SMASH then
		add("Statue", "Plinth", v(2, 9, 9), v(st.x, 1, st.z), L.stone, cyl())
		add("Statue", "Band", v(0.4, 9.6, 9.6), v(st.x, 2.2, st.z), L.ring, cyl())
		Garage.toyCar(add, "StatueCar", v(st.x, 2.4, st.z), 215, L.statue, 1.9) -- nose to the spawn
	end

	-- ===== Everyone's car on a turntable, in a row between the shop and the garage =====
	for i, x in if SpawnLobby.SMASH then {} else SpawnLobby.STANDS do
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
	for _, px in if SpawnLobby.SMASH then {} else { -25, 25 } do
		add("Bunting", "Pole", v(0.4, 10, 0.4), v(px, 5, bz), L.iron)
		add("Bunting", "Knob", v(0.8, 0.8, 0.8), v(px, 10.2, bz), L.yellow, { shape = "Cylinder" })
	end
	if not SpawnLobby.SMASH then
		add("Bunting", "Rope", v(50, 0.1, 0.1), v(0, by, bz), L.iron, { collide = false })
	end
	for i = 0, if SpawnLobby.SMASH then -1 else 24 do
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
		local lift = 0
		if pad.kind == "smash" then
			-- carter's pick C, "light ring": a navy plate with a sunny lip, a pink glowing disc, a
			-- short light column and three rings turning round it. "Rim" is the glowing disc (it
			-- blinks while someone waits); "Base" is the square the server watches, hidden under
			-- the paler core. No collision: you drive straight on.
			local R, B = SpawnLobby.PAD_R, SpawnLobby.PAD_BASE
			local flat = { shape = "Cylinder", rot = v(0, 0, 90), collide = false }
			local function disc(
				name: string,
				d: number,
				y: number,
				h: number,
				c: { number },
				neon: boolean
			)
				add(g, name, v(h, d, d), v(px, y, pz), c, {
					shape = flat.shape,
					rot = flat.rot,
					collide = false,
					material = if neon then "Neon" else nil,
				})
			end
			disc("Plate", 2 * R + 0.8, 0.15, 0.3, { 30, 42, 90 }, false)
			disc("Lip", 2 * R + 0.4, 0.31, 0.1, { 255, 210, 63 }, false)
			disc("Rim", 2 * R - 0.4, 0.37, 0.08, pad.color, true)
			add(g, "Base", v(B, 0.08, B), v(px, 0.38, pz), pad.color, {
				material = "Neon",
				collide = false,
			})
			disc("Core", 0.75 * R * 2, 0.43, 0.06, { 255, 170, 215 }, true)
			local P = "Portal" .. i -- the beam and the turning rings (LobbyMotion "PortalSpin")
			local H = SpawnLobby.PAD_BEAM
			add(P, "Beam", v(H, 0.72 * 2 * R, 0.72 * 2 * R), v(px, H / 2 + 0.4, pz), pad.color, {
				shape = "Cylinder",
				rot = v(0, 0, 90),
				material = "Neon",
				collide = false,
				alpha = 0.62,
			})
			add(P, "BeamCore", v(H, 4.4, 4.4), v(px, H / 2 + 0.4, pz), { 255, 224, 120 }, {
				shape = "Cylinder",
				rot = v(0, 0, 90),
				material = "Neon",
				collide = false,
				alpha = 0.72,
			})
			local N, RR, T = 12, 0.87 * R, 0.5
			local seg = 2 * RR * math.tan(math.pi / N) + 0.1
			for ri, y in SpawnLobby.PAD_RINGS do
				for k = 0, N - 1 do
					local a = (k + 0.5) / N * 2 * math.pi
					add(
						P,
						"Ring",
						v(seg, T, T),
						v(px + math.cos(a) * RR, y, pz + math.sin(a) * RR),
						if (k + ri) % 2 == 0 then pad.color else { 255, 210, 63 },
						{ rot = v(0, -math.deg(a) + 90, 0), material = "Neon", collide = false }
					)
				end
			end
			continue
		end
		add(
			g,
			"Rim",
			v(12.6, 0.06, 10.6),
			v(px, 0.03 + lift, pz),
			pad.color,
			{ material = "Neon", collide = false }
		)
		add(g, "Base", v(12, 0.08, 10), v(px, 0.04 + lift, pz), C.dark, { collide = false })
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
	-- (the garage hall has its own lamp arms: LobbyGarage)
	for i, p in if SpawnLobby.GARAGE then {} else SpawnLobby.LAMPS do
		local g = "Lamp" .. i
		if SpawnLobby.SMASH then
			-- chunky navy posts with a sunny ball (LOOK-BIBLE rules 2 and 3)
			add(g, "Foot", v(0.8, 1.6, 1.6), v(p.x, 0.4, p.z), { 30, 42, 90 }, cyl())
			add(g, "Post", v(9.5, 1, 1), v(p.x, 4.75, p.z), { 30, 42, 90 }, cyl())
			-- (SmoothPlastic and a soft light, not Neon: up close Neon bloomed into big yellow
			-- blobs, auditor shadow shots)
			add(g, "Light", v(2.4, 2.4, 2.4), v(p.x, 10.3, p.z), { 255, 226, 110 }, {
				shape = "Ball",
				collide = false,
				light = 12,
			})
			continue
		end
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

	-- ===== Smash: two floodlight towers by the portal and the scrap claw (LobbyProps) =====
	if SpawnLobby.SMASH then
		LobbyProps.parts(add)
	end

	-- ===== Trees behind the back, bushes and flower pots round the edge =====
	-- (Smash: ARENA's PropKit trees and bushes, put in by build())
	for i, x in if SpawnLobby.SMASH then {} else SpawnLobby.TREES do
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
	for i, p in if SpawnLobby.SMASH then {} else SpawnLobby.BUSHES do
		local g = "Bush" .. i
		add(g, "Pot", v(1.2, 2, 2), v(p.x, 0.6, p.z), L.pot, cyl())
		add(g, "Leaves", v(2.6, 2, 2.6), v(p.x, 2.2, p.z), L.leaf, { rot = v(0, 45, 0) })
	end

	if SpawnLobby.GARAGE then
		LobbyGarage.parts(add, W, D, SpawnLobby.SMASH_PADS)
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
	-- (Smash: no statue or stands, block lamps, PropKit trees: none of these models)
	local SMASH = SpawnLobby.SMASH
	if not SMASH then
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
	end
	for i, x in if SMASH then {} else SpawnLobby.STANDS do
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
	for i, p in if SMASH then {} else SpawnLobby.LAMPS do
		mesh("StreetLamp", "Lamp" .. i, v(p.x, 0, p.z), v(2, 11.5, 2), {}, true)
	end
	for i, x in if SMASH then {} else SpawnLobby.TREES do
		local z = SpawnLobby.TREE_Z + (if i % 2 == 0 then 1.5 else -1)
		if i % 2 == 1 then
			mesh("LeafyTree", "Tree" .. i, v(x, 0, z), v(9, 11, 9), {}, true)
		else
			mesh("PineTree", "Tree" .. i, v(x, 0, z), v(7, 12, 7), {}, true)
		end
	end
	for i, p in if SMASH then {} else SpawnLobby.BUSHES do
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

-- Smash: ARENA's PropKit round trees along the back, bushes round the edge, and a palette flag
-- each side of the row of match pads (LOOK-BIBLE rules 1, 7). Missing PropKit = none.
function SpawnLobby.dress(model: Instance, origin: CFrame)
	local m = script and (script :: any).Parent:FindFirstChild("PropKit")
	local ok, kit = pcall(function()
		return require(m)
	end)
	if not ok or type(kit) ~= "table" then
		return
	end
	local CollectionService = game:GetService("CollectionService")
	local folder = Instance.new("Folder")
	folder.Name = "Dressing"
	local function at(x: number, z: number): Vector3
		return origin:PointToWorldSpace(Vector3.new(x, 0, z))
	end
	-- (the garage hall has container walls there instead of the trees and bushes)
	for i, x in if SpawnLobby.GARAGE then {} else SpawnLobby.TREES do
		local z = SpawnLobby.TREE_Z + (if i % 2 == 0 then 1.5 else -1)
		pcall(
			kit.tree,
			folder,
			at(x, z),
			13 + (i % 3) * 1.5,
			if i % 3 == 0 then "pink" else "green",
			200 + i
		)
	end
	for i, p in if SpawnLobby.GARAGE then {} else SpawnLobby.BUSHES do
		pcall(kit.bush, folder, at(p.x, p.z), 3, 300 + i, false)
	end
	local pz = SpawnLobby.PAD_Z
	-- (simple and clear, carter 10-30: no flags, balloons or clusters round the pads)
	for k, sx in if SpawnLobby.GARAGE then {} else { -1, 1 } do
		local pos = at(sx * (SpawnLobby.SMASH_PADS[3] + SpawnLobby.PAD_R + 4), pz)
		pcall(
			kit.flag,
			folder,
			pos,
			12,
			if k == 1 then Color3.fromRGB(255, 210, 63) else Color3.fromRGB(91, 209, 91),
			origin:VectorToWorldSpace(Vector3.new(sx, 0, 0)), -- (outward: clear of the turning ring)
			false
		)
	end
	-- (one pcall: a PropKit change must never take the whole lobby down)
	pcall(function()
		-- themed clusters in the mid-ground (auditor cheap tells #5): a tyre stack, a barrel, a
		-- cone and a bunch of balloons that bob (LobbyMotion), off every walk line
		local BALLOONS = {
			Color3.fromRGB(255, 95, 180),
			Color3.fromRGB(255, 210, 63),
			Color3.fromRGB(142, 68, 255),
		}
		for i, c in if SpawnLobby.GARAGE then {} else SpawnLobby.CLUSTERS do
			local side = if c.x < 0 then -1 else 1
			pcall(kit.tyreStack, folder, at(c.x, c.z), 3, 3, false)
			local bx = c.x + side * 2.6 -- (the outer side, off the walk to the shop doors)
			pcall(
				kit.barrel,
				folder,
				at(bx, c.z + 1),
				2.6,
				if i % 2 == 0 then Color3.fromRGB(242, 64, 74) else Color3.fromRGB(142, 68, 255),
				false
			)
			pcall(kit.cone, folder, at(c.x - side * 2.2, c.z - 1.6), 2, false)
			local cord = kit.post(
				folder,
				"BalloonString",
				at(bx, c.z + 1) + Vector3.new(0, 2.6, 0),
				0.15,
				5.6,
				Color3.fromRGB(255, 255, 255),
				false
			)
			cord.CastShadow = false
			for k, col in BALLOONS do
				local a = (k + i) * 2.1
				local b = kit.ball(
					folder,
					"Balloon",
					at(bx + math.cos(a) * 0.9, c.z + 1 + math.sin(a) * 0.9)
						+ Vector3.new(0, 8 + k * 0.5, 0),
					2.3,
					col,
					false
				)
				b.CastShadow = false -- (it moves every frame)
				b:SetAttribute("Phase", i * 1.3 + k)
				CollectionService:AddTag(b, "LobbyBob")
			end
		end
		-- (no "?" box over the crate shop any more: next to the camera it always sat in the top
		-- corner under the coin chip, Studio r5/r6, and the portal is the one hero here: LOOK-BIBLE)
	end)
	folder.Parent = model
end

-- Builds it under `parent`. `at` is the middle of the square on the floor, its LookVector
-- pointing down the street. Play pad bases are tagged "QueuePad" (attributes Pad = 1..3 and
-- PlotType = "drift" / "race"); QueuePads (server) watches them.
-- Smash (LOOK-BIBLE rules 3, 4): the shops' dark grey shell, roof and concrete floor in the
-- bible's purple, navy and sand, all SmoothPlastic (the orange frame and the insides stay)
SpawnLobby.REPAINT = {
	BackWall = { 142, 68, 255 },
	LeftWall = { 142, 68, 255 },
	RightWall = { 142, 68, 255 },
	Roof = { 30, 42, 90 },
	RoofRib = { 255, 210, 63 },
	Floor = { 242, 217, 166 },
} :: { [string]: { number } }
if SpawnLobby.GARAGE then
	-- the garage's palette: steel-blue shells, dark roof, hazard ribs, concrete floor
	SpawnLobby.REPAINT = {
		BackWall = { 58, 111, 176 },
		LeftWall = { 58, 111, 176 },
		RightWall = { 58, 111, 176 },
		Roof = { 42, 45, 58 },
		RoofRib = { 255, 177, 0 },
		Floor = { 160, 160, 172 },
	}
end
function SpawnLobby.repaint(shop: Instance)
	local shell = shop:FindFirstChild("Shell")
	if not shell then
		return
	end
	for _, p in shell:GetChildren() do
		local c = SpawnLobby.REPAINT[p.Name]
		if c and p:IsA("BasePart") then
			p.Color = Color3.fromRGB(c[1], c[2], c[3])
			p.Material = Enum.Material.SmoothPlastic
		end
	end
end

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
	-- Smash: the rings turn slowly round each pad's beam on each screen (LobbyMotion): every piece
	-- knows the ring's middle and its axis (straight up)
	for i, pad in SpawnLobby.PADS do
		local ring = groups["Portal" .. i]
		if pad.kind == "smash" and ring then
			local c = origin:PointToWorldSpace(Vector3.new(pad.x, 0, SpawnLobby.PAD_Z))
			local axis = origin:VectorToWorldSpace(Vector3.new(0, 1, 0))
			for _, p in ring:GetChildren() do
				if p.Name == "Ring" then
					p:SetAttribute("SpinCentre", c)
					p:SetAttribute("SpinAxis", axis)
					p.CanQuery = false -- (it moves every frame on screens: keep it out of queries)
					game:GetService("CollectionService"):AddTag(p, "PortalSpin")
				end
			end
		end
	end
	-- CarShops (client) puts the "spin" prompt on it
	local gumball = groups.Gumball and groups.Gumball:FindFirstChild("Base")
	if gumball then
		game:GetService("CollectionService"):AddTag(gumball, "Gumball")
	end
	Garage.useMeshes(groups, origin, SpawnLobby.MESHES)
	if SpawnLobby.SMASH then
		SpawnLobby.dress(model, origin)
	end
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
		local shop = Garage.build(
			model,
			origin
				* CFrame.new(b.x, 0, b.z)
				* CFrame.Angles(0, math.rad(b.yaw), 0)
				* CFrame.Angles(0, math.pi, 0),
			nil,
			nil,
			b.kind
		)
		if SpawnLobby.SMASH then
			SpawnLobby.repaint(shop)
		end
	end
	model.Parent = parent
	return model
end

return SpawnLobby
