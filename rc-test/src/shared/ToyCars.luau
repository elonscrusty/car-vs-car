--!strict
-- The toy karts (carter 10-28: we make the car looks; his models swap in later through
-- ReplicatedStorage.CarSkins). Clean low-poly Roblox look, NOT Lego: full-bright flat colours,
-- navy trim, wedge noses, neon lights, no studs, no logos, no text.
--
-- 11 shapes (buggy, formula, muscle, truck, rally, crawler, wedge, jet, bubble, coupe, hatch),
-- (no weapon on the car: carter 10-28, it shows as an icon above it); glow cars light up their accent bits.
-- These part cars hold the slot until the mesh karts land in ReplicatedStorage.CarSkins.
--
-- A look is "shape/accent" or "shape/accent/glow" (CarCatalog gives each car its own). The old
-- looks "race", "drift" and "rock" still work.
--
-- Toy space, at size 1 (Garage.toyCar scales and turns it): nose toward -Z, the ground at y = 0,
-- about 3.6 long. The four wheels sit at x = +-(1 + width / 2), z = +-1.25, where the race car's
-- own wheels are. Plain numbers only (Lune tests load it).

local ToyCars = {}

type V3 = { x: number, y: number, z: number }
export type Opts = { shape: string?, rot: V3?, material: string?, face: boolean?, mesh: string? }
-- puts one piece: name, size, middle x y z, colour, options
export type Put = (
	name: string,
	size: V3,
	x: number,
	y: number,
	z: number,
	color: { number },
	opts: Opts?
) -> ()
export type Wheels = { wd: number, ww: number, lift: number }

local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

ToyCars.WHEEL_Z = 1.25

-- the look rule's palette (FINISH-JOBS): grass green, sky blue, sunny yellow, cherry red, hot pink,
-- dark navy, plus a few brights between them
ToyCars.PALETTE = {
	red = { 232, 53, 46 },
	sky = { 61, 155, 255 },
	blue = { 30, 111, 217 },
	yellow = { 255, 199, 44 },
	green = { 45, 190, 78 },
	pink = { 255, 111, 181 },
	navy = { 27, 27, 47 },
	white = { 245, 245, 250 },
	orange = { 255, 140, 30 },
	purple = { 150, 80, 255 },
	lime = { 160, 230, 40 },
	teal = { 0, 200, 200 },
} :: { [string]: { number } }
ToyCars.ACCENTS = ToyCars.PALETTE

local NAVY = ToyCars.PALETTE.navy
local DARK = NAVY
local LIGHT = { 255, 250, 230 }
local TAIL = { 255, 50, 60 }
local AMBER = { 255, 200, 60 }
local TIRE = { 28, 28, 30 }
local NEON: Opts = { material = "Neon" }
local WEDGE: Opts = { shape = "Wedge" } -- slopes down toward the nose
local BACK_WEDGE: Opts = { shape = "Wedge", rot = v(0, 180, 0) } -- slopes down toward the tail
local CYL: Opts = { shape = "Cylinder" } -- lies across the car
local BALL: Opts = { shape = "Ball" }
local PIPE: Opts = { shape = "Cylinder", rot = v(0, 90, 0) } -- points along the car

-- Wheels per shape: diameter, width, how far the body is lifted. The race car's springs hold
-- the wheels where its own (about 1.05 across at this size) would be, so bigger tyres sink:
-- keep them near that.
ToyCars.WHEELS = {
	muscle = { wd = 1, ww = 0.55, lift = 0 },
	coupe = { wd = 1, ww = 0.65, lift = 0 },
	hatch = { wd = 1, ww = 0.55, lift = 0.05 },
	wedge = { wd = 1, ww = 0.6, lift = 0 },
	buggy = { wd = 1.05, ww = 0.6, lift = 0.15 },
	formula = { wd = 1, ww = 0.55, lift = 0 },
	truck = { wd = 1.2, ww = 0.65, lift = 0.2 },
	crawler = { wd = 1.2, ww = 0.65, lift = 0.2 },
	bubble = { wd = 1, ww = 0.55, lift = 0 },
	jet = { wd = 1, ww = 0.55, lift = 0 },
	rally = { wd = 1, ww = 0.6, lift = 0.1 },
} :: { [string]: Wheels }

local OLD = { race = "muscle", drift = "coupe", rock = "crawler" }

export type Look = { shape: string, accent: { number }, glow: boolean }

-- "truck/navy/glow" -> the truck shape, a navy accent, underglow. Unknown bits fall back.
function ToyCars.parse(style: string?): Look
	local bits = string.split(style or "", "/")
	local shape = OLD[bits[1]] or bits[1]
	if not ToyCars.WHEELS[shape] then
		shape = "muscle"
	end
	return {
		shape = shape,
		accent = ToyCars.PALETTE[bits[2] or ""] or ToyCars.PALETTE.yellow,
		glow = bits[3] == "glow",
	}
end

function ToyCars.wheels(style: string?): Wheels
	return ToyCars.WHEELS[ToyCars.parse(style).shape]
end

-- The rims' colour: the car's (the accent when no colour is given), white for navy (dark rims
-- vanish on a phone).
function ToyCars.rim(style: string?, color: { number }?): { number }
	-- carter's picture: rims in the car's own colour (navy would vanish against the tyre)
	local c = color or ToyCars.parse(style).accent
	return if c == NAVY or (c[1] == NAVY[1] and c[2] == NAVY[2] and c[3] == NAVY[3])
		then ToyCars.PALETTE.white
		else c
end

-- Half the car's width over its wheels, at size 1.
function ToyCars.halfWidth(style: string?): number
	return 1 + ToyCars.wheels(style).ww
end

-- the hat spot (CarBuilder's "Topper"), at size 1: about a roof's height above the ground, at
-- the front of the roof
ToyCars.HEAD_TOP = 2.25 -- (the kid sits up: the big head and smile show over the body)
ToyCars.TOPPER_Z = -0.05

type Build = (p: Put, c: { number }, a: { number }, l: number) -> ()

local SHAPES: { [string]: Build } = {}

-- carter's picture (10-28): open karts with a Roblox kid driving, shirt and cap in the car's
-- colour, yellow head. The cap's top is the hat spot (HEAD_TOP, TOPPER_Z), whatever the shape.
local SKIN = { 245, 205, 48 } -- Roblox yellow
-- the classic rounded Roblox head (a SpecialMesh "Head" on the part) with the smile
local HEAD: Opts = { mesh = "Head", face = true }
local ROUND: Opts = { shape = "Cylinder", rot = v(0, 0, 90) } -- standing up: its height is size.x
-- The kid's shirt and cap: the car's colour, unless that is near his yellow head (a yellow or
-- orange car: Studio 10-29 "the kid blends into the car"), then the accent (white if that's yellow
-- too). A copy, so a glow car's accent wrapper doesn't light the shirt.
function ToyCars.outfit(color: { number }, accent: { number }): { number }
	local function nearSkin(c: { number }): boolean
		return math.abs(c[1] - SKIN[1]) + math.abs(c[2] - SKIN[2]) + math.abs(c[3] - SKIN[3]) < 150
	end
	local c = if not nearSkin(color)
		then color
		elseif not nearSkin(accent) then accent
		else ToyCars.PALETTE.white
	return { c[1], c[2], c[3] }
end

local function driver(p: Put, c: { number }, a: { number })
	local shirt = ToyCars.outfit(c, a)
	-- all round, not Lego (LOOK-BIBLE rule 1, auditor 10-29 "cube-head driver"): round shoulders,
	-- the classic Roblox head with the smile, a round cap
	-- (a big head, Smash Karts style: it is what you see of the kid over the body)
	p("Driver", v(0.36, 1.1, 1.1), 0, 1.05, ToyCars.TOPPER_Z + 0.1, shirt, ROUND)
	p("Head", v(0.72, 0.64, 0.72), 0, ToyCars.HEAD_TOP - 0.62, ToyCars.TOPPER_Z, SKIN, HEAD)
	-- (a ball sunk in the head's top: its top half shows as a round cap)
	p("Cap", v(0.8, 0.8, 0.8), 0, ToyCars.HEAD_TOP - 0.4, ToyCars.TOPPER_Z, shirt, BALL)
end

-- Hot-rod: long hood, twin stripes, the driver out in the open.
SHAPES.muscle = function(p, c, a, l)
	-- (as tall as the grey race body it covers: racelooks test)
	p("Body", v(2, 0.62, 3.6), 0, 0.81 + l, 0, c)
	driver(p, c, a)
	p("Stripes", v(0.7, 0.02, 3.62), 0, 1.13 + l, 0, a)
	p("Taillight", v(1.7, 0.14, 0.06), 0, 0.85 + l, 1.82, TAIL, NEON)
	for _, x in { -0.55, 0.55 } do
		p("Headlight", v(0.4, 0.16, 0.06), x, 0.85 + l, -1.82, LIGHT, NEON)
	end
end

-- Low drift coupe: bulged hood, splitter, a big wing on posts, red tail bar.
SHAPES.coupe = function(p, c, a, l)
	p("Body", v(2, 0.5, 3.6), 0, 0.72 + l, 0, c)
	driver(p, c, a)
	p("Splitter", v(2.1, 0.08, 0.35), 0, 0.52 + l, -1.72, a)
	p("Wing", v(2.15, 0.1, 0.45), 0, 1.72 + l, 1.55, a)
	p("WingPost", v(0.16, 0.6, 0.14), 0, 1.4 + l, 1.55, DARK)
	for _, x in { -0.6, 0.6 } do
		p("Headlight", v(0.45, 0.12, 0.06), x * 1.15, 0.8 + l, -1.82, LIGHT, NEON)
	end
	p("Taillight", v(1.6, 0.1, 0.06), 0, 0.82 + l, 1.82, TAIL, NEON)
end

-- Bulldozer kart: boxy body, sloped hood, a big blade on the nose.
SHAPES.hatch = function(p, c, a, l)
	p("Body", v(2, 0.55, 3.3), 0, 0.775 + l, 0, c)
	p("Hood", v(1.9, 0.15, 0.9), 0, 1.125 + l, -1.15, c, WEDGE)
	driver(p, c, a)
	p("Blade", v(2.2, 0.45, 0.14), 0, 0.75 + l, -1.75, a)
	p("Taillight", v(1.6, 0.14, 0.06), 0, 0.95 + l, 1.66, TAIL, NEON)
	for _, x in { -0.62, 0.62 } do
		p("Headlight", v(0.45, 0.2, 0.06), x, 0.9 + l, -1.66, LIGHT, NEON)
	end
end

-- Flat supercar: wedge nose, low glass, fastback, side intakes, low wing.
SHAPES.wedge = function(p, c, a, l)
	p("Body", v(2, 0.5, 3.6), 0, 0.75 + l, 0, c)
	p("Nose", v(2, 0.3, 1.3), 0, 1.15 + l, -1.15, c, WEDGE)
	driver(p, c, a)
	p("Back", v(1.8, 0.4, 1.1), 0, 1.2 + l, 1.25, c, BACK_WEDGE)
	p("Wing", v(2.1, 0.08, 0.4), 0, 1.44 + l, 1.62, a)
	for _, x in { -0.65, 0.65 } do
		p("Headlight", v(0.45, 0.1, 0.06), x, 0.92 + l, -1.82, LIGHT, NEON)
	end
	p("Taillight", v(1.7, 0.08, 0.06), 0, 0.88 + l, 1.82, TAIL, NEON)
end

-- Dune buggy: open tub, seat, a roll cage, the engine out the back.
SHAPES.buggy = function(p, c, a, l)
	p("Body", v(1.7, 0.45, 2.9), 0, 0.8 + l, 0.15, c)
	p("Nose", v(1.7, 0.4, 0.7), 0, 0.82 + l, -1.65, c, WEDGE)
	p("Bumper", v(2, 0.2, 0.2), 0, 0.6 + l, -1.95, a, CYL)
	driver(p, c, a)
	for _, x in { -0.72, 0.72 } do
		for _, z in { 0.9 } do
			p("CagePost", v(0.12, 0.85, 0.12), x, 1.45 + l, z, a)
		end
	end
	p("CageTop", v(1.56, 0.14, 0.3), 0, 1.9 + l, 0.9, a)
	p("Engine", v(1.2, 0.5, 0.55), 0, 1.02 + l, 1.45, DARK)
end

-- Open-wheel racer: thin body, side pods, the driver, wings front and back.
SHAPES.formula = function(p, c, a, l)
	p("Body", v(0.9, 0.45, 2.7), 0, 0.62 + l, 0.15, c)
	p("Nose", v(0.8, 0.4, 0.7), 0, 0.6 + l, -1.55, c, WEDGE)
	p("FrontWing", v(2, 0.08, 0.4), 0, 0.3 + l, -1.7, a)
	for _, x in { -0.65, 0.65 } do
		p("SidePod", v(0.4, 0.35, 1.2), x, 0.58 + l, 0.4, c)
	end
	driver(p, c, a)
	p("RearWing", v(2, 0.1, 0.45), 0, 1.35 + l, 1.62, a)
end

-- Monster kart: big tyres, fat bumpers, a light bar on the hood.
SHAPES.truck = function(p, c, a, l)
	p("Body", v(2, 0.55, 3.5), 0, 0.62 + l, 0, c)
	driver(p, c, a)
	p("LightBar", v(1.4, 0.14, 0.18), 0, 0.97 + l, -1.5, AMBER, NEON)
	p("BumperF", v(2, 0.3, 0.3), 0, 0.35 + l, -1.8, a, CYL)
	p("BumperR", v(2, 0.3, 0.3), 0, 0.35 + l, 1.8, a, CYL)
	for _, x in { -0.6, 0.6 } do
		p("Headlight", v(0.4, 0.16, 0.06), x, 0.72 + l, -1.76, LIGHT, NEON)
	end
end

-- Rock crawler: roll hoop with lights on top, spare tyre on the back.
SHAPES.crawler = function(p, c, a, l)
	p("Body", v(2, 0.55, 3), 0, 0.6 + l, 0, c)
	driver(p, c, a)
	for _, x in { -0.8, 0.8 } do
		p("HoopPost", v(0.14, 0.75, 0.14), x, 1.35 + l, 0.95, a)
	end
	p("HoopTop", v(1.74, 0.14, 0.14), 0, 1.72 + l, 0.95, a)
	p("Spare", v(0.3, 0.85, 0.85), 0, 1.05 + l, 1.66, TIRE, PIPE)
	p("RoofLights", v(1.2, 0.14, 0.14), 0, 1.86 + l, 0.95, AMBER, NEON)
end

-- Round little bubble kart: round nose, big eyes, a belt.
SHAPES.bubble = function(p, c, a, l)
	p("Body", v(2, 0.5, 3.15), 0, 0.75 + l, 0.175, c)
	p("Nose", v(2, 0.6, 0.6), 0, 0.8 + l, -1.4, c, CYL)
	driver(p, c, a)
	p("Belt", v(2.02, 0.14, 2.8), 0, 0.85 + l, 0, a)
	for _, x in { -0.5, 0.5 } do
		p("Eye", v(0.45, 0.45, 0.45), x, 1.08 + l, -1.5, LIGHT, BALL)
		p("Pupil", v(0.22, 0.22, 0.22), x, 1.08 + l, -1.7, DARK, BALL)
	end
end

-- Rocket kart: pointed nose, wings over the wheels, a tail fin and a jet.
SHAPES.jet = function(p, c, a, l)
	p("Body", v(1.4, 0.5, 2.6), 0, 0.75 + l, 0.2, c)
	p("Nose", v(1.4, 0.5, 0.8), 0, 0.75 + l, -1.45, c, WEDGE)
	driver(p, c, a)
	for _, x in { -0.85, 0.85 } do
		p("Wing", v(0.35, 0.1, 1.2), x, 1.02 + l, 0.6, a)
	end
	p("Fin", v(0.12, 0.7, 0.8), 0, 1.45 + l, 1.1, a, BACK_WEDGE)
	p("Jet", v(0.4, 0.55, 0.55), 0, 0.85 + l, 1.68, DARK, PIPE)
	p("Flame", v(0.1, 0.35, 0.35), 0, 0.85 + l, 1.88, { 255, 150, 40 }, {
		shape = "Cylinder",
		rot = v(0, 90, 0),
		material = "Neon",
	})
end

-- Rally kart: a lamp bar on the nose, mud flaps, a door patch, a spoiler.
SHAPES.rally = function(p, c, a, l)
	p("Body", v(2, 0.5, 3.4), 0, 0.75 + l, 0, c)
	driver(p, c, a)
	p("Wing", v(1.9, 0.1, 0.4), 0, 1.4 + l, 1.45, a, BACK_WEDGE)
	p("Door", v(2.02, 0.3, 1), 0, 0.75 + l, 0.3, a)
	p("LampBar", v(1.4, 0.16, 0.08), 0, 1.0 + l, -1.73, AMBER, NEON)
	for _, x in { -0.9, 0.9 } do
		p("MudFlap", v(0.35, 0.4, 0.05), x, 0.4 + l, 1.82, DARK)
	end
end

ToyCars.SHAPES = {} :: { string }
for name in SHAPES do
	table.insert(ToyCars.SHAPES, name)
end
table.sort(ToyCars.SHAPES)

-- The car's parts but its wheels (Garage.toyCar puts those), for `style`. At most
-- ToyCars.MAX_BODY of them (a whole car stays at 16 parts with its wheels, phone budget).
ToyCars.MAX_BODY = 10
function ToyCars.body(p: Put, color: { number }, style: string?)
	local look = ToyCars.parse(style)
	local put = p
	local accent = look.accent
	if look.glow then
		-- rare cars and up: their accent bits light up (no extra parts); navy can't glow, sky does
		if accent == NAVY then
			accent = ToyCars.PALETTE.sky
		end
		put = function(name, size, x, y, z, col, o)
			if col == accent then
				o = { shape = o and o.shape, rot = o and o.rot, material = "Neon" }
			end
			p(name, size, x, y, z, col, o)
		end
	end
	local lift = ToyCars.WHEELS[look.shape].lift
	SHAPES[look.shape](put, color, accent, lift)
end

-- The Blender kart models (ReplicatedStorage.CarSkins.Kart_*, made from assets/karts/build.py):
-- each shape wears one, painted per car below, so 6 models dress all 24 cars. carter's own model
-- for a car (CarSkins, named the car id) still wins over these.
-- (the racers wear carter's own Meshy kart, 10-28; Kart_Racer stays in KartMeshData as the backup)
ToyCars.KARTS = {
	formula = "Kart_Carter1",
	coupe = "Kart_Carter1",
	wedge = "Kart_Carter1",
	jet = "Kart_Rocket",
	buggy = "Kart_Buggy",
	rally = "Kart_Buggy",
	crawler = "Kart_Monster",
	truck = "Kart_Monster",
	hatch = "Kart_Dozer",
	muscle = "Kart_HotRod",
	bubble = "Kart_HotRod",
} :: { [string]: string }

function ToyCars.kartModel(style: string?): string
	return ToyCars.KARTS[ToyCars.parse(style).shape]
end

local PAL = ToyCars.PALETTE
local METAL = { 205, 210, 220 }
local DARK_STEEL = { 70, 74, 84 }
-- a colour, a third of the way to white: a lamp of that colour (half way read pastel pink)
local function lit(c: { number }): { number }
	return {
		math.floor(c[1] + (255 - c[1]) / 3),
		math.floor(c[2] + (255 - c[2]) / 3),
		math.floor(c[3] + (255 - c[3]) / 3),
	}
end
-- the kart's accent bits: a navy accent would be black (white, or sky blue when it glows)
local function kartAccent(look: Look): { number }
	return if look.accent == NAVY then (if look.glow then PAL.sky else PAL.white) else look.accent
end
-- (carter's picture: the shirt, cap and rims are the kart's own colour)
-- A kart's rims: the kart's own colour.
function ToyCars.kartRim(color: { number }, _style: string?): { number }
	return color
end

-- A kart model's part, by name: its colour and whether it glows (nil: keep the model's own).
function ToyCars.kartPaint(name: string, color: { number }, style: string?): ({ number }?, boolean)
	local look = ToyCars.parse(style)
	if name == "Body" then
		return color, false
	elseif name == "Cap" or name == "Driver" then
		return ToyCars.outfit(color, look.accent), false
	elseif name == "Accent" then
		return kartAccent(look), look.glow
	elseif name == "Trim" or name == "Eyes" or name == "Seat" then
		return NAVY, false
	elseif name == "Metal" then
		return METAL, false
	elseif name == "Dark" then
		return DARK_STEEL, false
	elseif name == "Shade" then
		return {
			math.floor(color[1] * 0.55),
			math.floor(color[2] * 0.55),
			math.floor(color[3] * 0.55),
		},
			false
	elseif name == "Head" then
		return PAL.yellow, false
	elseif name == "Headlights" or name == "Glow" then
		-- (carter's picture: each kart's lights glow its own colour)
		return lit(color), true
	elseif name == "Taillights" then
		return TAIL, true
	elseif string.sub(name, 1, 5) == "Wheel" then
		return TIRE, false
	elseif string.sub(name, 1, 3) == "Rim" then
		return ToyCars.kartRim(color, style), false
	end
	return nil, false
end

return ToyCars
