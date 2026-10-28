--!strict
-- The toy karts (carter 10-28: we make the car looks; his models swap in later through
-- ReplicatedStorage.CarSkins). Clean low-poly Roblox look, NOT Lego: full-bright flat colours,
-- navy trim, wedge noses, neon lights, no studs, no logos, no text.
--
-- Every kart: a low wide deck over the wheels (the Body: the race paints it the car's colour), a
-- navy floor under it (neon in the accent for rare cars and up: underglow), a blocky driver
-- (shirt in the accent, a yellow head), a WeaponMount behind the driver (rockets go there),
-- neon head and tail lights, then its shape's nose and two parts of its own.
--
-- A look is "shape/accent" or "shape/accent/glow" (CarCatalog gives each car its own). The old
-- looks "race", "drift" and "rock" still work.
--
-- Toy space, at size 1 (Garage.toyCar scales and turns it): nose toward -Z, the ground at y = 0,
-- about 3.6 long. The four wheels sit at x = +-(1 + width / 2), z = +-1.25, where the race car's
-- own wheels are. Plain numbers only (Lune tests load it).

local ToyCars = {}

type V3 = { x: number, y: number, z: number }
export type Opts = { shape: string?, rot: V3?, material: string? }
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
local SKIN = { 245, 205, 48 } -- the classic yellow head
local LIGHT = { 255, 250, 230 }
local TAIL = { 255, 50, 60 }
local AMBER = { 255, 200, 60 }
local TIRE = { 28, 28, 30 }
local NEON: Opts = { material = "Neon" }
local WEDGE: Opts = { shape = "Wedge" } -- slopes down toward the nose
local BACK_WEDGE: Opts = { shape = "Wedge", rot = v(0, 180, 0) } -- slopes down toward the tail
local CYL: Opts = { shape = "Cylinder" } -- lies across the car
local UPRIGHT: Opts = { shape = "Cylinder", rot = v(0, 0, 90) } -- stands up
local PIPE: Opts = { shape = "Cylinder", rot = v(0, 90, 0) } -- points along the car

-- Wheels per shape: diameter, width, how far the deck is lifted. The race car's springs hold the
-- wheels where its own (about 1.05 across at this size) would be, so bigger tyres would sink:
-- keep them near that (the deck covers their tops, so they look small).
ToyCars.WHEELS = {
	muscle = { wd = 1, ww = 0.55, lift = 0 },
	coupe = { wd = 1, ww = 0.6, lift = 0 },
	hatch = { wd = 1, ww = 0.55, lift = 0.05 },
	wedge = { wd = 0.95, ww = 0.6, lift = 0 },
	buggy = { wd = 1.05, ww = 0.6, lift = 0.12 },
	formula = { wd = 0.95, ww = 0.5, lift = 0 },
	truck = { wd = 1.15, ww = 0.65, lift = 0.22 },
	crawler = { wd = 1.15, ww = 0.65, lift = 0.2 },
	bubble = { wd = 1, ww = 0.55, lift = 0 },
	jet = { wd = 0.95, ww = 0.5, lift = 0 },
	rally = { wd = 1, ww = 0.6, lift = 0.08 },
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

-- The rims' colour: the accent, white when the accent is navy (dark rims vanish on a phone).
function ToyCars.rim(style: string?): { number }
	local a = ToyCars.parse(style).accent
	return if a == NAVY then ToyCars.PALETTE.white else a
end

-- Half the kart's width over its wheels (or its deck, a bit wider), at size 1.
function ToyCars.halfWidth(style: string?): number
	local w = ToyCars.wheels(style)
	return 1 + w.ww + 0.05
end

-- a softer copy of a colour, for neon that glows without blinding a phone screen
local function dim(c: { number }): { number }
	return { math.floor(c[1] * 0.6), math.floor(c[2] * 0.6), math.floor(c[3] * 0.6) }
end

-- where the WeaponMount sits (z): just behind the driver, clear of every shape's rear parts
ToyCars.MOUNT_Z = 0.78
-- the top of the driver's head, at size 1 above the ground, for a kart with no lift (the hat
-- spot, CarBuilder's "Topper")
ToyCars.HEAD_TOP = 2.15

-- what a shape's own parts stand on
type Base = { top: number, front: number, back: number, wide: number, l: number }
type Build = (p: Put, c: { number }, a: { number }, b: Base) -> ()

local SHAPES: { [string]: Build } = {}

-- The parts every kart has (8). Returns where the shape's own parts go.
local function base(
	p: Put,
	c: { number },
	a: { number },
	w: Wheels,
	glow: boolean,
	len: number
): Base
	local l = w.lift
	local wide = 2 + 1.2 * w.ww -- over the inner part of both wheels
	local y = w.wd * 0.85 + l -- the deck covers the tyres' tops
	local top = y + 0.15
	local front, back = -len / 2, len / 2
	p("Body", v(wide, 0.3, len), 0, y, 0, c)
	-- the floor fills under the deck between the wheels (and hides the hub bars)
	local fy = 0.12 + l * 0.5
	local fh = y - 0.15 - fy
	local glowOpts: Opts? = if glow then NEON else nil
	local fl = 2 * (ToyCars.WHEEL_Z + 0.32) -- past both axles
	p(
		"Floor",
		v(2, fh, fl),
		0,
		fy + fh / 2,
		0,
		if glow then dim(if a == NAVY then ToyCars.PALETTE.sky else a) else NAVY,
		glowOpts
	)
	p("Driver", v(0.9, 0.65, 0.5), 0, top + 0.33, 0.3, a)
	p("Head", v(0.5, 0.6, 0.6), 0, top + 0.9, 0.3, SKIN, UPRIGHT)
	p("WeaponMount", v(0.45, 0.14, 0.45), 0, top + 0.07, ToyCars.MOUNT_Z, NAVY)
	p("Taillights", v(wide * 0.55, 0.12, 0.06), 0, y, back + 0.03, TAIL, NEON)
	return { top = top, front = front, back = back, wide = wide, l = l }
end

local function headlights(p: Put, b: Base, y: number, z: number, width: number)
	p("Headlights", v(width, 0.12, 0.06), 0, y, z, LIGHT, NEON)
end

-- Long sloped hood with a navy scoop, a ducktail.
SHAPES.muscle = function(p, c, a, b)
	p("Nose", v(1.8, 0.35, 0.9), 0, b.top - 0.15 + 0.175, b.front - 0.35, c, WEDGE)
	headlights(p, b, b.top - 0.1, b.front - 0.78, 1.4)
	p("Scoop", v(0.55, 0.2, 0.5), 0, b.top + 0.1, b.front + 0.45, NAVY, WEDGE)
	p("Ducktail", v(b.wide * 0.8, 0.22, 0.4), 0, b.top + 0.11, b.back - 0.2, a, BACK_WEDGE)
end

-- Drift coupe: a splitter nose and a big wing on one post.
SHAPES.coupe = function(p, c, a, b)
	p("Nose", v(1.9, 0.3, 0.8), 0, b.top - 0.15 + 0.15, b.front - 0.3, c, WEDGE)
	headlights(p, b, b.top - 0.12, b.front - 0.68, 1.5)
	p("WingPost", v(0.16, 0.55, 0.16), 0, b.top + 0.27, b.back - 0.25, NAVY)
	p("Wing", v(b.wide * 0.85, 0.1, 0.5), 0, b.top + 0.58, b.back - 0.25, a)
end

-- Hot hatch: a blunt nose, a tall back with a roof wing.
SHAPES.hatch = function(p, c, a, b)
	p("Nose", v(1.9, 0.35, 0.45), 0, b.top - 0.15, b.front - 0.15, c)
	headlights(p, b, b.top - 0.1, b.front - 0.39, 1.5)
	p("Back", v(1.6, 0.6, 0.4), 0, b.top + 0.3, b.back - 0.2, c, BACK_WEDGE)
	p("RoofWing", v(1.8, 0.1, 0.45), 0, b.top + 0.65, b.back - 0.2, a)
end

-- Flat supercar: a long low wedge nose, a fastback, a low wing.
SHAPES.wedge = function(p, c, a, b)
	p("Nose", v(1.8, 0.28, 1.1), 0, b.top - 0.15 + 0.14, b.front - 0.4, c, WEDGE)
	headlights(p, b, b.top - 0.12, b.front - 0.9, 1.4)
	p("Back", v(1.6, 0.4, 0.4), 0, b.top + 0.2, b.back - 0.2, c, BACK_WEDGE)
	p("Wing", v(b.wide * 0.8, 0.08, 0.4), 0, b.top + 0.42, b.back - 0.2, a)
end

-- Dune buggy: a short nose, one roll bar over the driver.
SHAPES.buggy = function(p, c, a, b)
	p("Nose", v(1.6, 0.4, 0.6), 0, b.top - 0.15 + 0.1, b.front - 0.25, c, WEDGE)
	headlights(p, b, b.top - 0.2, b.front - 0.53, 1.2)
	p("RollPost", v(0.16, 1.05, 0.16), 0, b.top + 0.52, 1.15, NAVY)
	p("RollBar", v(1.5, 0.16, 0.16), 0, b.top + 1.05, 1.15, a)
end

-- Open-wheel racer: a thin pointed nose and wings at both ends.
SHAPES.formula = function(p, c, a, b)
	p("Nose", v(0.8, 0.35, 0.9), 0, b.top - 0.15 + 0.03, b.front - 0.35, c, WEDGE)
	headlights(p, b, b.top - 0.25, b.front - 0.79, 0.6)
	p("FrontWing", v(b.wide * 0.9, 0.08, 0.35), 0, 0.3, b.front - 0.65, a)
	p("RearWing", v(b.wide * 0.85, 0.1, 0.45), 0, b.top + 0.55, b.back - 0.15, a)
end

-- Stadium truck: lifted, a navy bull bar and a light bar.
SHAPES.truck = function(p, c, a, b)
	p("Nose", v(1.9, 0.35, 0.5), 0, b.top - 0.15, b.front - 0.18, c)
	headlights(p, b, b.top - 0.15, b.front - 0.44, 1.5)
	p("BullBar", v(2.1, 0.3, 0.25), 0, b.top - 0.5, b.front - 0.4, NAVY)
	p("LightBar", v(1.3, 0.14, 0.18), 0, b.top + 1.1, 0.05, AMBER, NEON)
end

-- Rock crawler: lifted, a spare tyre on the back, a navy winch bumper.
SHAPES.crawler = function(p, c, a, b)
	p("Nose", v(1.8, 0.4, 0.45), 0, b.top - 0.13, b.front - 0.15, c)
	headlights(p, b, b.top - 0.1, b.front - 0.39, 1.4)
	p("Winch", v(1.3, 0.25, 0.3), 0, b.top - 0.48, b.front - 0.2, NAVY)
	p("Spare", v(0.28, 0.8, 0.8), 0, b.top + 0.3, b.back - 0.05, TIRE, PIPE)
end

-- Round bubble kart: a round nose and tail.
SHAPES.bubble = function(p, c, a, b)
	p("Nose", v(1.9, 0.6, 0.6), 0, b.top - 0.15, b.front, c, CYL)
	headlights(p, b, b.top - 0.1, b.front - 0.31, 1.2)
	p("Tail", v(1.9, 0.5, 0.5), 0, b.top - 0.25, b.back - 0.25, c, CYL)
	p("Hump", v(1.4, 0.5, 0.5), 0, b.top - 0.05, b.front + 0.55, a, CYL)
end

-- Rocket kart: a pointed nose, a tail fin and a jet.
SHAPES.jet = function(p, c, a, b)
	p("Nose", v(1.4, 0.4, 1.0), 0, b.top - 0.15 + 0.05, b.front - 0.3, c, WEDGE)
	headlights(p, b, b.top - 0.25, b.front - 0.79, 0.9)
	p("Fin", v(0.14, 0.75, 0.4), 0, b.top + 0.37, b.back - 0.15, a, BACK_WEDGE)
	p("Jet", v(0.4, 0.35, 0.35), 0, b.top - 0.42, b.back + 0.15, NAVY, PIPE)
end

-- Rally kart: an amber lamp pod on the nose and a roof scoop behind the driver.
SHAPES.rally = function(p, c, a, b)
	p("Nose", v(1.9, 0.35, 0.6), 0, b.top - 0.15 + 0.05, b.front - 0.22, c, WEDGE)
	headlights(p, b, b.top - 0.12, b.front - 0.54, 1.5)
	p("LampPod", v(1.2, 0.16, 0.12), 0, b.top + 0.1, b.front - 0.05, AMBER, NEON)
	p("Scoop", v(0.6, 0.35, 0.4), 0, b.top + 0.17, b.back - 0.2, a, BACK_WEDGE)
end

-- deck length per shape (the nose adds to it)
local LENGTH = {
	muscle = 2.9,
	coupe = 3,
	hatch = 3.1,
	wedge = 2.8,
	buggy = 3,
	formula = 2.8,
	truck = 3.1,
	crawler = 3.1,
	bubble = 2.9,
	jet = 2.7,
	rally = 3,
}

ToyCars.SHAPES = {} :: { string }
for name in SHAPES do
	table.insert(ToyCars.SHAPES, name)
end
table.sort(ToyCars.SHAPES)

-- The kart's parts but its wheels (Garage.toyCar puts those), for `style`: always 10, so a whole
-- kart is 16 parts with its wheels and two hub bars (phone budget).
ToyCars.MAX_BODY = 10
function ToyCars.body(p: Put, color: { number }, style: string?)
	local look = ToyCars.parse(style)
	local b = base(p, color, look.accent, ToyCars.WHEELS[look.shape], look.glow, LENGTH[look.shape])
	SHAPES[look.shape](p, color, look.accent, b)
end

return ToyCars
