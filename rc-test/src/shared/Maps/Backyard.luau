--!strict
-- BACKYARD: a toy race track laid across a giant lawn. Start on the patio, round the sandbox,
-- a chicane between two giant sneakers, a sweeper by the shed corner, a jump over the garden
-- hose on the back straight, past the flower pots, a sweep round the bird bath and home.
-- Shortcut: a dirt lane through the flower bed cuts the back-right corner (mud on it).
-- Secret: a mown strip hidden behind the big bush runs through the dog house and cuts the
-- back-left corner. Picture: rc-game/maps/backyard.png in the project files.

local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local MapKit = sibling("MapKit")

local PI = math.pi
local function prop(
	kind: string,
	x: number,
	z: number,
	yaw: number,
	h: number,
	solid: boolean,
	w: number?,
	d: number?
): MapKit.Prop
	return { kind = kind, x = x, z = z, yaw = yaw, h = h, solid = solid, w = w, d = d }
end

local props: { MapKit.Prop } = {
	-- the patio under the start, the back door and steps behind it
	prop("patio", 0, 440, 0, 0.6, false, 900, 130),
	prop("steps", 0, 525, 0, 30, true, 260, 30),
	-- sandbox in the front-right corner, a castle in it
	prop("sandbox", 679, 470, 0, 22, true, 120, 110), -- inside the fence (sizes are not squeezed)
	prop("sandCastle", 679, 470, 0.4, 70, true, 70, 70),
	-- two giant sneakers make the chicane
	prop("sneaker", 680, 60, PI / 2, 30, true, 32, 68),
	prop("sneaker", 450, -20, -0.5, 30, true, 32, 68),
	-- the hose: from the tap on the back fence, across the back straight, curled in the grass
	prop("tap", 300, -525, 0, 50, true, 20, 20),
	prop("hoseReel", 160, -260, 0.3, 60, true, 70, 60),
	-- flower bed between the shortcut and the corner, pots on the back fence
	prop("flowerBed", 560, -380, 0.6, 6, false, 120, 90),
	prop("flowerPot", 720, -500, 0, 56, true, 52, 52),
	prop("flowerPot", 40, -509, 0, 50, true, 46, 46), -- against the fence, clear of the curb
	prop("flowerPot", -120, -508, 0, 60, true, 48, 48),
	prop("gnome", -40, -510, PI, 66, true, 34, 34),
	-- the dog house sits on the secret strip, door facing along it; bushes hide its start
	-- (the squeeze moves things but keeps their size: these sizes keep the house off the curb,
	-- the bushes off both roads, on the inside of the turn-off, and the bowl out of the house)
	prop("dogHouse", -395, -230, 0, 165, true, 170, 150),
	prop("bigBush", -179, -345, 0, 70, false, 80, 64),
	prop("bigBush", -216, -290, 0.4, 60, false, 70, 56),
	prop("dogBowl", -249, -157, 0, 12, true, 44, 44), -- by the side of the house
	-- bird bath in the left infield, a dropped bucket and a soda can near the road
	prop("birdBath", -330, 80, 0, 154, true, 90, 90),
	prop("bucket", 150, 120, 0.8, 66, true, 60, 60),
	prop("sodaCan", 300, 250, 1.2, 14, true, 26, 14),
	prop("ball", -150, 100, 0, 50, true, 50, 50), -- out of the start-line view
	prop("picnicTable", 120, -80, 0.2, 165, true, 400, 200),
	-- leaves and pinecones on the lawn (bumps you can drive round)
	prop("leaf", 380, 180, 0.7, 2, false, 60, 40),
	prop("leaf", -200, -40, 2.1, 2, false, 50, 34),
	prop("leaf", 260, -330, 1.3, 2, false, 56, 38),
	prop("pinecone", -680, 450, 0.3, 24, true, 20, 30),
	prop("pinecone", -710, -490, 1.6, 24, true, 20, 30),
	-- giant trees past the fence (you can't reach them)
	prop("tree", -1150, -1000, 0, 1000, false, 120, 120),
	prop("tree", 1150, -950, 0, 900, false, 110, 110),
	prop("tree", -1200, 250, 0, 800, false, 100, 100),
}

-- grass tufts along the outside (taller than the car: it's a giant world)
for i, spot in
	{
		{ -720, 300 },
		{ -720, -120 },
		{ 720, 300 },
		{ 730, -150 },
		{ -300, -505 },
		{ 160, -505 },
		{ 680, 520 },
		{ -660, -500 },
		{ -40, 160 },
		{ -420, 300 },
		{ 360, -40 },
		{ 250, 50 },
	}
do
	table.insert(props, prop("tuft", spot[1], spot[2], i * 0.9, 30, false, 26, 26))
end

local def: MapKit.Def = {
	id = "backyard",
	label = "BACKYARD",
	theme = "yard",
	road = 36,
	minX = -760,
	maxX = 760,
	minZ = -540,
	maxZ = 600, -- room behind the driver stand for its camera
	main = {
		{ x = -300, z = 420 }, -- front straight on the patio, driving right
		{ x = 300, z = 420 },
		{ x = 520, z = 380 }, -- round the sandbox
		{ x = 610, z = 240 },
		{ x = 590, z = 130 }, -- chicane: left of the first sneaker
		{ x = 520, z = 60 },
		{ x = 570, z = -40 }, -- right of the second
		{ x = 650, z = -140 },
		{ x = 660, z = -300 }, -- the sweeper
		{ x = 580, z = -440 },
		{ x = 420, z = -460 },
		{ x = 200, z = -440 }, -- back straight: hose jump
		{ x = -60, z = -440 },
		{ x = -300, z = -440 },
		{ x = -520, z = -400 }, -- back-left corner
		{ x = -640, z = -260 },
		{ x = -620, z = -60 },
		{ x = -510, z = 60 }, -- round the bird bath
		{ x = -540, z = 200 },
		{ x = -620, z = 320 },
		{ x = -520, z = 410 },
	},
	line = { x = -150, z = 420 },
	gates = {
		{ x = 610, z = 240 }, -- sandbox corner
		{ x = 570, z = -40 }, -- chicane
		{ x = 140, z = -440 }, -- back straight (after the shortcut comes back)
		{ x = -510, z = 60 }, -- bird bath (after the secret comes back)
		{ x = -620, z = 320 },
	},
	paths = {
		{
			kind = "shortcut",
			look = "dirt",
			width = 26,
			points = {
				{ x = 650, z = -150 },
				{ x = 560, z = -250 },
				{ x = 450, z = -330 },
				{ x = 300, z = -440 },
			},
		},
		{
			kind = "secret",
			look = "mown",
			width = 30,
			points = {
				{ x = -230, z = -440 },
				{ x = -300, z = -330 },
				{ x = -395, z = -230 }, -- through the dog house
				{ x = -500, z = -130 },
				{ x = -600, z = -30 },
			},
		},
	},
	pads = {
		{ kind = "boost", path = 0, at = { x = 240, z = 420 }, len = 50 }, -- clear of the LAP flash
		{ kind = "boost", path = 0, at = { x = 60, z = -440 }, len = 50 },
		{ kind = "puddle", path = 0, at = { x = -545, z = 170 }, len = 60 },
		{ kind = "mud", path = 1, at = { x = 500, z = -295 }, len = 50 },
		{ kind = "boost", path = 2, at = { x = -540, z = -85 }, len = 40 },
	},
	jumps = {
		{ path = 0, at = { x = 250, z = -440 } }, -- over the hose
		{ path = 0, at = { x = -50, z = -440 } }, -- a log ramp: land well before the secret turns off
	},
	props = props,
	lines = {
		{
			kind = "hose",
			width = 6,
			points = {
				{ x = 300, z = -545 },
				{ x = 280, z = -500 },
				{ x = 250, z = -440 }, -- under the jump
				{ x = 230, z = -380 },
				{ x = 200, z = -320 },
				{ x = 160, z = -260 }, -- the reel
			},
		},
	},
	-- the driver stand: a wooden deck on the patio by the start, left of the house steps
	stand = { x = -297, z = 523, w = MapKit.STAND_W, d = MapKit.STAND_D, h = MapKit.STAND_H },
	rcX = 3000,
	rcZ = 1000,
	rcAngle = 0,
}

-- squeezed so a lap is about 45 s (3 laps fit the 3 minute race)
return MapKit.make(MapKit.scale(def, 0.74))
