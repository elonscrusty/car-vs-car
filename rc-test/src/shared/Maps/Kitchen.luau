--!strict
-- KITCHEN: a toy race track on a giant kitchen floor. Start by the door mat, round the table
-- (or straight UNDER it: the shortcut, through a chair's legs), along the counters round the
-- mop bucket with a jump over a dropped spoon, through the spilled milk by the fridge, a
-- cutting-board jump down the left side and home.
-- Secret: two cabinet doors under the counter are open. Drive in one, along inside the cabinets,
-- and out of the other (it skips the mop bucket bend). Picture: rc-game/maps/kitchen.png in the
-- project files.

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

-- The track is laid out roomy and squeezed by K so a lap is about 45 s (3 laps fit the 3 minute
-- race). Things against the walls (fridge, counters, the cabinet tunnel) are placed after the
-- squeeze, at their real giant size: 5.5 big units = 1 inch, counters 36 in tall and 24 in deep.
local K = 0.78
local COUNTER_H, COUNTER_D = 198, 140
local BACK = -470 -- the back wall (after the squeeze)
local COUNTER_FRONT = BACK + COUNTER_D

-- loose things on the floor (squeezed with the track)
local props: { MapKit.Prop } = {
	-- the table and its chairs (the car drives between the legs)
	prop("table", 470, 0, 0, 165, true, 280, 380),
	prop("chair", 470, 70, 0, 100, true, 96, 96), -- pushed in on the shortcut: drive through
	prop("chair", 250, -120, PI / 2, 100, true, 96, 96),
	prop("chair", 250, 130, PI / 2, 100, true, 96, 96),
	-- the mop bucket in the bend, a wet floor sign
	prop("mopBucket", 0, -300, 0, 80, true, 80, 80),
	prop("wetSign", 150, -300, 0.3, 70, true, 50, 30),
	-- front: door mat by the start, trash can in the corner, dog bowls
	prop("doorMat", -330, 450, 0, 1, false, 200, 110),
	prop("trashCan", -680, 470, 0, 138, true, 84, 84),
	prop("dogBowl", 700, 480, 0, 14, true, 48, 48),
	prop("dogBowl", 620, 500, 0, 14, true, 48, 48),
	-- a rug in the middle with a spilled cereal box and a rolled apple
	prop("rug", -170, 140, 0, 1, false, 520, 300),
	prop("cerealBox", -280, 90, 1.2, 16, true, 66, 44),
	prop("cereal", -220, 130, 0, 6, true, 10, 10),
	prop("cereal", -200, 70, 0, 6, true, 10, 10),
	prop("cereal", -160, 120, 0, 6, true, 10, 10),
	prop("apple", -40, 220, 0, 18, true, 18, 18),
	prop("banana", 60, 40, 0.6, 12, true, 40, 12),
	prop("mug", -60, 20, 0, 22, true, 20, 20),
	prop("toyBlock", 120, 200, 0.4, 24, true, 24, 24),
	prop("toyBlock", 150, 210, 1.1, 24, true, 24, 24),
	-- the cutting board leaning by the left jump
	prop("cuttingBoard", -745, -60, 0, 40, false, 20, 110),
}

local def: MapKit.Def = {
	id = "kitchen",
	label = "KITCHEN",
	theme = "kitchen",
	road = 36,
	minX = -760,
	maxX = 760,
	minZ = BACK / K, -- squeezed to BACK
	maxZ = 540,
	main = {
		{ x = -300, z = 420 }, -- front straight by the door mat, driving right
		{ x = 250, z = 420 },
		{ x = 520, z = 400 }, -- round the table, past the dog bowls
		{ x = 670, z = 280 },
		{ x = 700, z = 80 },
		{ x = 690, z = -120 },
		{ x = 620, z = -300 },
		{ x = 470, z = -370 }, -- along the counters
		{ x = 280, z = -370 },
		{ x = 150, z = -130 }, -- round the mop bucket (spoon jump)
		{ x = 60, z = -130 }, -- flat across the bottom, so the jump is straight on
		{ x = -60, z = -130 },
		{ x = -150, z = -130 },
		{ x = -280, z = -370 },
		{ x = -450, z = -370 }, -- spilled milk by the fridge
		{ x = -630, z = -290 },
		{ x = -690, z = -180 },
		{ x = -690, z = 40 }, -- down the left side (cutting-board jump)
		{ x = -640, z = 220 },
		{ x = -600, z = 350 },
		{ x = -480, z = 420 },
	},
	line = { x = -150, z = 420 },
	gates = {
		{ x = 150, z = 420 }, -- front straight (before the shortcut)
		{ x = 510, z = -365 }, -- counters (after the shortcut, before the secret)
		{ x = -450, z = -370 }, -- milk (after the secret)
		{ x = -690, z = -180 },
		{ x = -690, z = 40 },
		{ x = -640, z = 220 },
		{ x = -600, z = 350 },
	},
	paths = {
		{
			kind = "shortcut",
			look = "tiles",
			width = 30,
			points = {
				{ x = 340, z = 418 },
				{ x = 440, z = 230 }, -- under the table
				{ x = 470, z = 70 }, -- through the chair's legs
				{ x = 470, z = -150 },
				{ x = 560, z = -350 },
			},
		},
		{ kind = "secret", look = "tunnel", width = 34, points = {} }, -- set after the squeeze
	},
	pads = {
		{ kind = "boost", path = 0, at = { x = 200, z = 420 }, len = 50 }, -- clear of the LAP flash
		{ kind = "boost", path = 0, at = { x = -692, z = 140 }, len = 50 },
		{ kind = "milk", path = 0, at = { x = -460, z = -370 }, len = 80 },
		{ kind = "sand", path = 1, at = { x = 466, z = -40 }, len = 40 }, -- crumbs under the table
		{ kind = "boost", path = 2, at = { x = 60 / K, z = (BACK + 70) / K }, len = 50 },
	},
	jumps = {
		{ path = 0, at = { x = 0, z = -130 }, h = 9, len = 84 }, -- over the dropped spoon
		{ path = 0, at = { x = -692, z = -60 }, h = 9, len = 84 }, -- the cutting board
	},
	props = props,
	lines = {
		{ kind = "spoon", width = 10, points = { { x = 0, z = -90 }, { x = 0, z = -170 } } },
	},
	rcX = -3000,
	rcZ = 1000,
	rcAngle = 0,
}

local d = MapKit.scale(def, K)
d.minZ = BACK
-- the fridge in the back-left corner, the counter run along the back wall (the builder fills the
-- rest of the run with plain cabinets), the cabinet tunnel's two open doors
for _, p in
	{
		prop("fridge", d.minX + 95, BACK + 85, 0, 385, true, 190, 170),
		prop("stove", 0, BACK + COUNTER_D / 2, 0, COUNTER_H, true, 170, COUNTER_D),
		prop("sink", 296, BACK + COUNTER_D / 2, 0, COUNTER_H, true, 180, COUNTER_D),
		prop("cabinetDoor", 330, COUNTER_FRONT, 0, 120, true, 66, 4),
		prop("cabinetDoor", -240, COUNTER_FRONT, 0, 120, true, 66, 4),
	}
do
	table.insert(d.props, p)
end
-- inside the cabinets: in at one open door, along behind the stove, out at the other
local mid = BACK + COUNTER_D / 2
d.paths[2].points = {
	{ x = 343, z = -289 },
	{ x = 330, z = COUNTER_FRONT - 10 },
	{ x = 270, z = mid },
	{ x = 50, z = mid },
	{ x = -170, z = mid },
	{ x = -240, z = COUNTER_FRONT - 10 },
	{ x = -257, z = -289 },
}
d.paths[2].width = 34

local Map: any = MapKit.make(d)
Map.COUNTER_H = COUNTER_H
Map.COUNTER_FRONT = COUNTER_FRONT
return Map
