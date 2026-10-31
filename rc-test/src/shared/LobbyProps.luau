--!strict
-- Two lobby models carter picked (10-29, lobby-preview/models/lobby-models.html): a pair of
-- floodlight towers either side of the SMASH! portal, their lamp banks facing the spawn, and a
-- scrap claw (a yard crane holding a crushed car over a wreck pile) in the back right corner.
-- Plain numbers only (Lune tests load it); SpawnLobby.parts() calls it when SpawnLobby.SMASH is on.
--
-- Lobby-local space as in SpawnLobby: the floor is W x D around (0, 0, 0), +Z is the front.
-- Each model is written in its own space (looks toward +Z, or reaches toward +X), then `placed`
-- scales it, turns it half a round if asked, and moves it to its spot.

-- Loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local Garage = sibling("Garage")

type V3 = Garage.V3

local LobbyProps = {}

LobbyProps.TOWERS = { { x = -21, z = 19 }, { x = 21, z = 19 } } -- banks face -Z, toward the spawn
LobbyProps.TOWER_SCALE = 0.6 -- the preview tower is 33 high; the lobby's box tops out at 21
LobbyProps.CLAW = { x = 40, z = -27 } -- the crane's base; its arm reaches toward -X, to the pile
LobbyProps.CLAW_SCALE = 0.9 -- (the box test reads a tilted arm as upright: the preview forearm would top 21)
LobbyProps.COLORS = {
	steel = { 42, 45, 58 },
	concrete = { 108, 108, 124 },
	yellow = { 255, 214, 40 },
	hazard = { 255, 177, 0 },
	black = { 34, 36, 46 },
	lens = { 255, 243, 192 },
	beacon = { 255, 58, 58 },
	orange = { 255, 138, 26 },
	glass = { 38, 48, 76 },
	ram = { 140, 144, 164 },
	tyre = { 24, 26, 34 },
	wreck = {
		{ 192, 71, 47 }, -- rust red (the one in the claw)
		{ 47, 143, 157 }, -- teal
		{ 227, 168, 43 }, -- mustard
		{ 166, 61, 109 }, -- plum
	},
}

local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

-- Wraps `add` so a model written at its own origin lands at (ox, oz), `scale` times the size and
-- (flip) turned half a round about Y. Half a round: (x, z) become (-x, -z), rot.y gains 180 and
-- rot.x changes sign (Rx * Ry * Rz with the Y turn taken out front), which is exact.
local function placed(
	add: Garage.Add,
	ox: number,
	oz: number,
	scale: number,
	flip: boolean
): Garage.Add
	return function(group, name, size, pos, color, opts)
		local o: Garage.Opts = opts or {}
		local rot = o.rot or v(0, 0, 0)
		local px, pz = pos.x * scale, pos.z * scale
		if flip then
			px, pz = -px, -pz
			rot = v(-rot.x, rot.y + 180, rot.z)
		end
		add(
			group,
			name,
			v(size.x * scale, size.y * scale, size.z * scale),
			v(ox + px, pos.y * scale, oz + pz),
			color,
			{
				shape = o.shape,
				rot = rot,
				material = o.material,
				collide = o.collide,
				light = if o.light then o.light * scale else nil,
			}
		)
	end
end

local function cyl(rot: V3?): Garage.Opts
	return { shape = "Cylinder", rot = rot or v(0, 0, 90) } -- (a Roblox cylinder lies along X)
end

-- ===== A: floodlight tower: hazard-striped mast, a catwalk, a tilted bank of 2 x 4 lamps =====
local TILT = 8 -- the lamp bank leans down toward the front, degrees
local RIG_Y, RIG_Z = 26.8, 1.2 -- the bank's middle

-- a point in the bank's own frame, moved to the tower's (turned by the tilt)
local function rigPos(x: number, y: number, z: number): V3
	local c, s = math.cos(math.rad(TILT)), math.sin(math.rad(TILT))
	return v(x, RIG_Y + y * c - z * s, RIG_Z + y * s + z * c)
end

local function tower(add: Garage.Add, group: string)
	local C = LobbyProps.COLORS
	add(group, "Base", v(7, 1.2, 7), v(0, 0.6, 0), C.concrete)
	for i = 0, 3 do -- hazard bands round the mast's foot
		add(
			group,
			"Band",
			v(1.4, 3.1, 3.1),
			v(0, 1.9 + i * 1.4, 0),
			if i % 2 == 0 then C.hazard else C.black,
			cyl()
		)
	end
	add(group, "Mast", v(8, 2.6, 2.6), v(0, 10.8, 0), C.steel, cyl())
	add(group, "MastTop", v(7.2, 2, 2), v(0, 18.4, 0), C.steel, cyl())
	-- ladder up the +X side: two rails and rungs
	for _, z in { -0.5, 0.5 } do
		add(group, "Rail", v(0.3, 20, 0.3), v(1.6, 11, z), C.ram, { collide = false })
	end
	for i = 0, 4 do
		add(group, "Rung", v(0.3, 0.25, 1.1), v(1.6, 3 + i * 4, 0), C.ram, { collide = false })
	end
	-- catwalk: floor, two side rails, a front rail
	add(group, "Walk", v(7, 0.6, 4), v(0, 19, 0), C.steel, { collide = false })
	for _, x in { -3.3, 3.3 } do
		add(group, "WalkRail", v(0.3, 1.6, 3.6), v(x, 20, 0), C.hazard, { collide = false })
	end
	add(group, "WalkRail", v(6.6, 0.3, 0.3), v(0, 20.9, 1.8), C.hazard, { collide = false })
	-- the lamp bank: dark back, yellow frame, 2 rows of 4 cans with bright lenses, a visor each row
	local r = v(TILT, 0, 0)
	local function onRig(
		name: string,
		size: V3,
		x: number,
		y: number,
		z: number,
		col: { number },
		opts: Garage.Opts?
	)
		local o: Garage.Opts = opts or {}
		o.rot = r
		o.collide = false
		add(group, name, size, rigPos(x, y, z), col, o)
	end
	onRig("Back", v(15, 8.6, 0.9), 0, 0, -0.5, C.steel)
	for _, y in { -4.5, 4.5 } do
		onRig("Frame", v(15.6, 0.8, 1.4), 0, y, -0.4, C.yellow)
	end
	for _, x in { -7.7, 7.7 } do
		onRig("Frame", v(0.8, 9.6, 1.4), x, 0, -0.4, C.yellow)
	end
	onRig("Frame", v(0.6, 8.6, 1.0), 0, 0, -0.2, C.yellow)
	for row = 0, 1 do
		local y = 2.1 - row * 4.2
		for k = 0, 3 do
			local x = -5.6 + k * 3.7
			onRig("Can", v(3.2, 3.3, 2.0), x, y, 0.55, C.black)
			onRig("Lens", v(2.7, 2.8, 0.2), x, y, 1.65, C.lens, {
				material = "Neon",
				-- one soft light per tower, on a middle lens, throws the glow on the paving
				light = if row == 0 and k == 1 then 60 else nil,
			})
		end
		onRig("Visor", v(15, 0.5, 2.3), 0, y + 1.85, 0.6, C.hazard)
	end
	-- red beacon on top
	add(group, "Beacon", v(1.8, 1.8, 1.8), v(0, 32.9, 0.6), C.beacon, {
		shape = "Ball",
		material = "Neon",
		collide = false,
	})
end

-- ===== C: scrap claw: a tracked yard crane, a 4-prong claw gripping a crushed car, a wreck pile =====
-- a crushed car (a squashed block with a flat cabin and four wheels), turned `yaw` degrees
local function wreck(
	add: Garage.Add,
	group: string,
	at: V3,
	yaw: number,
	col: { number },
	solid: boolean,
	wide: number?
)
	local C = LobbyProps.COLORS
	local k = wide or 1
	local a = math.rad(yaw)
	local ca, sa = math.cos(a), math.sin(a)
	-- a point in the car's frame (x along its length) moved to the world, turned by the yaw
	local function p(x: number, y: number, z: number): V3
		return v(at.x + x * ca + z * sa, at.y + y, at.z - x * sa + z * ca)
	end
	local dark = { math.floor(col[1] * 0.62), math.floor(col[2] * 0.62), math.floor(col[3] * 0.62) }
	local o: Garage.Opts = { rot = v(0, yaw, 0), collide = solid }
	add(group, "Crushed", v(5.6 * k, 2.4, 4.4), p(0, 0, 0), col, o)
	add(
		group,
		"CrushedFloor",
		v(5.6 * k, 0.4, 4.5),
		p(0, -1.1, 0),
		dark,
		{ rot = o.rot, collide = false }
	)
	add(
		group,
		"CrushedCabin",
		v(3 * k, 0.9, 3.4),
		p(-0.3, 1.4, 0),
		col,
		{ rot = o.rot, collide = false }
	)
	add(
		group,
		"CrushedGlass",
		v(2.4 * k, 0.5, 3.5),
		p(-0.3, 1.45, 0),
		C.glass,
		{ rot = o.rot, collide = false }
	)
	for _, wx in { -1.7, 1.7 } do
		for _, wz in { -2.3, 2.3 } do
			-- (the wheel lies along the car's Z: a cylinder's X axis turned 90 about Y, then the yaw)
			add(group, "Wheel", v(0.7, 2.2, 2.2), p(wx * k, -0.5, wz), C.tyre, {
				shape = "Cylinder",
				rot = v(0, yaw + 90, 0),
				collide = false,
			})
		end
	end
end

local function claw(add: Garage.Add, group: string)
	local C = LobbyProps.COLORS
	-- tracks and turntable
	for _, z in { -3.4, 3.4 } do
		add(group, "Track", v(10, 1.8, 2.2), v(0, 0.9, z), C.black)
		for _, x in { -3.6, 0, 3.6 } do
			add(group, "TrackWheel", v(2.3, 1.5, 1.5), v(x, 0.9, z), C.ram, {
				shape = "Cylinder",
				rot = v(0, 90, 0),
				collide = false,
			})
		end
	end
	add(group, "Turntable", v(8, 1, 7), v(0, 2.3, 0), C.steel)
	-- cab: yellow body, roof, dark window on the arm's side, counterweight with hazard stripes
	add(group, "Cab", v(6, 4, 5.6), v(-0.4, 4.8, 0), C.yellow)
	add(group, "CabRoof", v(6.2, 0.5, 5.8), v(-0.4, 7, 0), C.steel, { collide = false })
	add(group, "Window", v(0.3, 2.1, 4), v(2.7, 5.4, 0), C.glass, { collide = false })
	add(group, "Counterweight", v(4.2, 3.4, 5.4), v(-5, 4.7, 0), C.steel)
	for i = 0, 2 do
		add(
			group,
			"Stripe",
			v(0.3, 0.6, 5.5),
			v(-7.14, 3.2 + i * 1.2, 0),
			if i % 2 == 0 then C.hazard else C.black,
			{ collide = false }
		)
	end
	add(group, "Beacon", v(1.6, 1.6, 1.6), v(-1.2, 8.1, 0), C.orange, {
		shape = "Ball",
		material = "Neon",
		collide = false,
	})
	-- boom: arm up and forward, a joint, a forearm tipped down, two rams
	local a1, L1 = math.rad(55), 13
	local px, py = 0.6, 6.9
	add(
		group,
		"Arm",
		v(1.9, L1, 1.9),
		v(px + math.cos(a1) * L1 / 2, py + math.sin(a1) * L1 / 2, 0),
		C.yellow,
		{ rot = v(0, 0, 55 - 90), collide = false }
	)
	local e1x, e1y = px + math.cos(a1) * L1, py + math.sin(a1) * L1
	add(group, "Joint", v(2.4, 2.6, 2.6), v(e1x, e1y, 0), C.steel, {
		shape = "Cylinder",
		rot = v(0, 90, 0),
		collide = false,
	})
	local a2, L2 = math.rad(22), 6.2
	add(
		group,
		"Forearm",
		v(1.5, L2, 1.5),
		v(e1x + math.cos(a2) * L2 / 2, e1y + math.sin(a2) * L2 / 2, 0),
		C.yellow,
		{ rot = v(0, 0, 22 - 90), collide = false }
	)
	local ex, ey = e1x + math.cos(a2) * L2, e1y + math.sin(a2) * L2
	for _, z in { -1.3, 1.3 } do
		add(
			group,
			"Ram",
			v(0.6, 10, 0.6),
			v(3, 10.8, z),
			C.ram,
			{ rot = v(0, 0, -27.5), collide = false }
		)
	end
	-- chain, hub and four prongs hanging from the forearm's end, gripping a crushed car
	local CH = 6.5
	add(group, "Chain", v(0.45, CH, 0.45), v(ex, ey - CH / 2, 0), C.ram, { collide = false })
	add(group, "Hub", v(3.4, 1.5, 3.4), v(ex, ey - CH - 0.5, 0), C.steel, { collide = false })
	add(group, "HubPlate", v(3.8, 0.5, 3.8), v(ex, ey - CH + 0.1, 0), C.hazard, { collide = false })
	local hy = ey - CH - 0.9
	for k = 0, 3 do
		local a = math.rad(k * 90)
		local ca, sa = math.cos(a), math.sin(a)
		-- (a prong's local x runs out from the hub, turned about Y by k quarter turns)
		local function pp(x: number, y: number): V3
			return v(ex + x * ca, hy + y, -x * sa)
		end
		add(group, "ProngUp", v(0.95, 3.4, 0.95), pp(2.3, -1.3), C.yellow, {
			rot = v(0, k * 90, 40),
			collide = false,
		})
		add(group, "ProngLow", v(0.9, 3.7, 0.9), pp(3.7, -3.7), C.steel, {
			rot = v(0, k * 90, -17),
			collide = false,
		})
	end
	wreck(add, group, v(ex, ey - CH - 5, 0), 23, C.wreck[1], false)
	-- the wreck pile under it (two high), one more car and two tyre stacks beside
	wreck(add, group, v(ex - 0.2, 1.6, 0.6), 11.5, C.wreck[2], true)
	wreck(add, group, v(ex - 0.6, 4, 0.4), -14, C.wreck[3], true)
	wreck(add, group, v(19.6, 1.6, -3.6), -29, C.wreck[4], true)
	for _, t in { { 20.6, 3.2 }, { 18.4, 5.2 } } do
		for i = 0, 2 do
			add(
				group,
				"Tyre",
				v(1.5, 3.6, 3.6),
				v(t[1] + (i % 2) * 0.4, 0.75 + i * 1.5, t[2]),
				C.tyre,
				cyl()
			)
		end
	end
end

-- Adds both models' pieces (lobby-local) to `add`.
function LobbyProps.parts(add: Garage.Add)
	for i, t in LobbyProps.TOWERS do
		tower(placed(add, t.x, t.z, LobbyProps.TOWER_SCALE, true), "FloodTower" .. i)
	end
	claw(
		placed(add, LobbyProps.CLAW.x, LobbyProps.CLAW.z, LobbyProps.CLAW_SCALE, true),
		"ScrapClaw"
	)
end

return LobbyProps
