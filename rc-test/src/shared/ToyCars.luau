--!strict
-- The toy karts (carter 10-28: we make the car looks; his models swap in later through
-- ReplicatedStorage.CarSkins). Clean low-poly Roblox look, NOT Lego: full-bright flat colours,
-- navy trim, wedge noses, neon lights, no studs, no logos, no text.
--
-- 11 shapes (buggy, formula, muscle, truck, rally, crawler, wedge, jet, bubble, coupe, hatch),
-- each with a WeaponMount on its roof (rockets go there); glow cars light up their accent bits.
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
local GLASS = { 60, 82, 110 }
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
	truck = { wd = 1.2, ww = 0.65, lift = 0.5 },
	crawler = { wd = 1.2, ww = 0.65, lift = 0.45 },
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

-- The rims' colour: the accent, white when the accent is navy (dark rims vanish on a phone).
function ToyCars.rim(style: string?): { number }
	local a = ToyCars.parse(style).accent
	return if a == NAVY then ToyCars.PALETTE.white else a
end

-- Half the car's width over its wheels, at size 1.
function ToyCars.halfWidth(style: string?): number
	return 1 + ToyCars.wheels(style).ww
end

-- the hat spot (CarBuilder's "Topper"), at size 1: about a roof's height above the ground, at
-- the front of the roof (the WeaponMount is behind it)
ToyCars.HEAD_TOP = 1.8
ToyCars.TOPPER_Z = -0.05

type Build = (p: Put, c: { number }, a: { number }, l: number) -> ()

local SHAPES: { [string]: Build } = {}

-- Long hood with a scoop, twin stripes, short cab, ducktail, two pipes.
SHAPES.muscle = function(p, c, a, l)
	p("Body", v(2, 0.7, 3.6), 0, 0.85 + l, 0, c)
	p("Screen", v(1.6, 0.45, 0.5), 0, 1.43 + l, -0.1, GLASS, WEDGE)
	p("Cab", v(1.6, 0.45, 0.55), 0, 1.43 + l, 0.42, GLASS)
	p("Back", v(1.6, 0.45, 0.7), 0, 1.43 + l, 1.05, GLASS, BACK_WEDGE)
	p("Roof", v(1.62, 0.1, 0.6), 0, 1.7 + l, 0.42, c)
	p("Stripes", v(0.7, 0.02, 3.62), 0, 1.21 + l, 0, a)
	p("Taillight", v(1.7, 0.14, 0.06), 0, 1.0 + l, 1.82, TAIL, NEON)
	for _, x in { -0.55, 0.55 } do
		p("Headlight", v(0.4, 0.16, 0.06), x, 0.98 + l, -1.82, LIGHT, NEON)
	end
end

-- Low drift coupe: bulged hood, splitter, a big wing on posts, red tail bar.
SHAPES.coupe = function(p, c, a, l)
	p("Body", v(2, 0.6, 3.6), 0, 0.8 + l, 0, c)
	p("Screen", v(1.5, 0.42, 0.6), 0, 1.31 + l, -0.2, GLASS, WEDGE)
	p("Cab", v(1.5, 0.42, 1.0), 0, 1.31 + l, 0.6, GLASS)
	p("Splitter", v(2.1, 0.08, 0.35), 0, 0.52 + l, -1.72, a)
	p("Wing", v(2.15, 0.1, 0.45), 0, 1.72 + l, 1.55, a)
	p("WingPost", v(0.16, 0.6, 0.14), 0, 1.4 + l, 1.55, DARK)
	for _, x in { -0.6, 0.6 } do
		p("Headlight", v(0.45, 0.12, 0.06), x * 1.15, 0.92 + l, -1.82, LIGHT, NEON)
	end
	p("Taillight", v(1.6, 0.1, 0.06), 0, 0.95 + l, 1.82, TAIL, NEON)
end

-- Tall hot hatch: square back, roof wing, chunky bumpers, a belt line.
SHAPES.hatch = function(p, c, a, l)
	p("Body", v(2, 0.75, 3.3), 0, 0.875 + l, 0, c)
	p("Hood", v(1.9, 0.15, 0.9), 0, 1.325 + l, -1.15, c, WEDGE)
	p("Screen", v(1.7, 0.58, 0.6), 0, 1.54 + l, -0.35, GLASS, WEDGE)
	p("Cab", v(1.7, 0.58, 1.35), 0, 1.54 + l, 0.62, GLASS)
	p("Roof", v(1.76, 0.12, 1.4), 0, 1.89 + l, 0.62, c)
	p("RoofWing", v(1.76, 0.1, 0.45), 0, 1.9 + l, 1.48, a, BACK_WEDGE)
	p("Taillight", v(1.6, 0.14, 0.06), 0, 1.18 + l, 1.66, TAIL, NEON)
	for _, x in { -0.62, 0.62 } do
		p("Headlight", v(0.45, 0.2, 0.06), x, 1.08 + l, -1.66, LIGHT, NEON)
	end
end

-- Flat supercar: wedge nose, low glass, fastback, side intakes, low wing.
SHAPES.wedge = function(p, c, a, l)
	p("Body", v(2, 0.5, 3.6), 0, 0.75 + l, 0, c)
	p("Nose", v(2, 0.3, 1.3), 0, 1.15 + l, -1.15, c, WEDGE)
	p("Screen", v(1.5, 0.4, 0.7), 0, 1.2 + l, -0.15, GLASS, WEDGE)
	p("Cab", v(1.5, 0.4, 0.5), 0, 1.2 + l, 0.45, GLASS)
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
	p("Bumper", v(2, 0.18, 0.18), 0, 0.6 + l, -1.95, a)
	p("Seat", v(1, 0.5, 0.7), 0, 1.25 + l, 0.35, DARK)
	for _, x in { -0.72, 0.72 } do
		for _, z in { 0.9 } do
			p("CagePost", v(0.12, 0.85, 0.12), x, 1.45 + l, z, a)
		end
	end
	p("CageTop", v(1.56, 0.14, 0.3), 0, 1.9 + l, 0.9, a)
	p("Engine", v(1.2, 0.5, 0.55), 0, 1.02 + l, 1.45, DARK)
end

-- Open-wheel racer: thin body, side pods, a helmet, wings front and back.
SHAPES.formula = function(p, c, a, l)
	p("Body", v(0.9, 0.45, 2.7), 0, 0.62 + l, 0.15, c)
	p("Nose", v(0.8, 0.4, 0.7), 0, 0.6 + l, -1.55, c, WEDGE)
	p("FrontWing", v(2, 0.08, 0.4), 0, 0.3 + l, -1.7, a)
	for _, x in { -0.65, 0.65 } do
		p("SidePod", v(0.4, 0.35, 1.2), x, 0.58 + l, 0.4, c)
		p("Endplate", v(0.08, 0.5, 0.45), x * 1.52, 1.12 + l, 1.62, DARK)
	end
	p("Helmet", v(0.5, 0.5, 0.5), 0, 1.02 + l, 0.05, a, BALL)
	p("RearWing", v(2, 0.1, 0.45), 0, 1.35 + l, 1.62, a)
end

-- Stadium truck: high on a dark frame, cab and bed, light bar, fat bumpers.
SHAPES.truck = function(p, c, a, l)
	p("Body", v(2, 0.55, 3.5), 0, 0.72 + l, 0, c)
	p("Screen", v(1.6, 0.6, 0.45), 0, 1.3 + l, -0.6, GLASS, WEDGE)
	p("Cab", v(1.6, 0.6, 0.9), 0, 1.3 + l, 0.07, GLASS)
	p("Roof", v(1.7, 0.12, 1), 0, 1.66 + l, 0.07, c)
	p("LightBar", v(1.4, 0.14, 0.18), 0, 1.79 + l, -0.3, AMBER, NEON)
	p("BumperF", v(2, 0.25, 0.25), 0, 0.42 + l, -1.8, a)
	p("BumperR", v(2, 0.25, 0.25), 0, 0.42 + l, 1.8, a)
	for _, x in { -0.6, 0.6 } do
		p("Headlight", v(0.4, 0.16, 0.06), x, 0.82 + l, -1.76, LIGHT, NEON)
	end
end

-- Rock crawler: skid plate, roll hoop, spare tyre on the back, winch, roof lights.
SHAPES.crawler = function(p, c, a, l)
	p("Body", v(2, 0.55, 3), 0, 0.7 + l, 0, c)
	p("Screen", v(1.6, 0.6, 0.4), 0, 1.27 + l, -0.75, GLASS, WEDGE)
	p("Cab", v(1.6, 0.6, 1.2), 0, 1.27 + l, 0.05, GLASS)
	p("Roof", v(1.7, 0.12, 1.6), 0, 1.63 + l, -0.15, c)
	for _, x in { -0.8, 0.8 } do
		p("HoopPost", v(0.14, 0.75, 0.14), x, 1.35 + l, 0.95, a)
	end
	p("HoopTop", v(1.74, 0.14, 0.14), 0, 1.72 + l, 0.95, a)
	p("Spare", v(0.3, 0.85, 0.85), 0, 1.05 + l, 1.66, TIRE, PIPE)
	p("RoofLights", v(1.2, 0.14, 0.14), 0, 1.76 + l, -0.75, AMBER, NEON)
end

-- Round little bubble car: round nose and tail, a glass dome, big eyes, an antenna.
SHAPES.bubble = function(p, c, a, l)
	p("Body", v(2, 0.6, 3.15), 0, 0.8 + l, 0.175, c)
	p("Nose", v(2, 0.6, 0.6), 0, 0.8 + l, -1.4, c, CYL)
	p("Dome", v(1.6, 1.4, 1.4), 0, 1.05 + l, 0.25, c, CYL)
	p("Window", v(1.5, 1.1, 1.1), 0, 1.2 + l, -0.05, GLASS, CYL)
	p("Belt", v(2.02, 0.14, 2.8), 0, 0.85 + l, 0, a)
	for _, x in { -0.5, 0.5 } do
		p("Eye", v(0.45, 0.45, 0.45), x, 1.08 + l, -1.5, LIGHT, BALL)
		p("Pupil", v(0.22, 0.22, 0.22), x, 1.08 + l, -1.7, DARK, BALL)
	end
end

-- Rocket car: pointed nose, bubble cockpit, wings over the wheels, a tail fin and a jet.
SHAPES.jet = function(p, c, a, l)
	p("Body", v(1.4, 0.6, 2.6), 0, 0.8 + l, 0.2, c)
	p("Nose", v(1.4, 0.6, 0.8), 0, 0.8 + l, -1.45, c, WEDGE)
	p("Cockpit", v(1, 0.6, 0.9), 0, 1.1 + l, -0.25, GLASS, CYL)
	p("Stripe", v(1.42, 0.12, 2.6), 0, 0.85 + l, 0.2, a)
	for _, x in { -0.85, 0.85 } do
		p("Wing", v(0.35, 0.1, 1.2), x, 1.12 + l, 0.6, a)
	end
	p("Fin", v(0.12, 0.7, 0.8), 0, 1.45 + l, 1.1, a, BACK_WEDGE)
	p("Jet", v(0.4, 0.55, 0.55), 0, 0.85 + l, 1.68, DARK, PIPE)
	p("Flame", v(0.1, 0.35, 0.35), 0, 0.85 + l, 1.88, { 255, 150, 40 }, {
		shape = "Cylinder",
		rot = v(0, 90, 0),
		material = "Neon",
	})
end

-- Rally hatch: roof scoop, a lamp bar on the nose, mud flaps, a door patch.
SHAPES.rally = function(p, c, a, l)
	p("Body", v(2, 0.7, 3.4), 0, 0.85 + l, 0, c)
	p("Screen", v(1.7, 0.6, 0.55), 0, 1.5 + l, -0.45, GLASS, WEDGE)
	p("Cab", v(1.7, 0.6, 1.2), 0, 1.5 + l, 0.42, GLASS)
	p("Roof", v(1.8, 0.12, 1.25), 0, 1.86 + l, 0.42, c)
	p("Wing", v(1.9, 0.1, 0.4), 0, 1.88 + l, 1.2, a, BACK_WEDGE)
	p("Door", v(2.02, 0.4, 1), 0, 0.85 + l, 0.3, a)
	p("LampBar", v(1.4, 0.16, 0.08), 0, 1.0 + l, -1.73, AMBER, NEON)
	for _, x in { -0.9, 0.9 } do
		p("MudFlap", v(0.35, 0.4, 0.05), x, 0.4 + l, 1.82, DARK)
	end
end

-- Where each shape's WeaponMount sits: its roof (or deck) top and how far back, before the lift.
ToyCars.MOUNTS = {
	muscle = { y = 1.75, z = 0.42 },
	coupe = { y = 1.52, z = 0.6 },
	hatch = { y = 1.95, z = 0.62 },
	wedge = { y = 1.4, z = 0.45 },
	buggy = { y = 1.27, z = 1.45 },
	formula = { y = 0.85, z = 1.15 },
	truck = { y = 1.72, z = 0.35 },
	crawler = { y = 1.69, z = 0.25 },
	bubble = { y = 1.75, z = 0.25 },
	jet = { y = 1.1, z = 0.45 },
	rally = { y = 1.92, z = 0.6 },
} :: { [string]: { y: number, z: number } }

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
	if look.glow then
		-- rare cars and up: their accent bits light up (no extra parts)
		put = function(name, size, x, y, z, col, o)
			if col == look.accent then
				o = { shape = o and o.shape, rot = o and o.rot, material = "Neon" }
			end
			p(name, size, x, y, z, col, o)
		end
	end
	local lift = ToyCars.WHEELS[look.shape].lift
	SHAPES[look.shape](put, color, look.accent, lift)
	local m = ToyCars.MOUNTS[look.shape]
	p("WeaponMount", v(0.45, 0.14, 0.45), 0, m.y + lift + 0.07, m.z, NAVY)
end

-- The Blender kart models (ReplicatedStorage.CarSkins.Kart_*, made from assets/karts/build.py):
-- each shape wears one, painted per car below, so 6 models dress all 24 cars. carter's own model
-- for a car (CarSkins, named the car id) still wins over these.
ToyCars.KARTS = {
	formula = "Kart_Racer",
	jet = "Kart_Racer",
	buggy = "Kart_Buggy",
	crawler = "Kart_Buggy",
	wedge = "Kart_Speedster",
	coupe = "Kart_Speedster",
	muscle = "Kart_Muscle",
	rally = "Kart_Muscle",
	bubble = "Kart_Bubble",
	hatch = "Kart_Bubble",
	truck = "Kart_Truck",
} :: { [string]: string }

function ToyCars.kartModel(style: string?): string
	return ToyCars.KARTS[ToyCars.parse(style).shape]
end

local SHIRT = ToyCars.PALETTE.blue
-- A kart model's part, by name: its colour and whether it glows (nil: keep the model's own).
function ToyCars.kartPaint(name: string, color: { number }, style: string?): ({ number }?, boolean)
	local look = ToyCars.parse(style)
	if name == "Body" then
		return color, false
	elseif name == "Accent" then
		-- (a navy glow would be black: it lights up sky blue)
		return if look.glow and look.accent == NAVY then ToyCars.PALETTE.sky else look.accent,
			look.glow
	elseif name == "Trim" or name == "WeaponMount" then
		return NAVY, false
	elseif name == "Head" then
		return ToyCars.PALETTE.yellow, false
	elseif name == "Driver" then
		return if color == SHIRT then ToyCars.PALETTE.white else SHIRT, false
	elseif name == "Headlights" then
		return LIGHT, true
	elseif name == "Taillights" then
		return TAIL, true
	elseif string.sub(name, 1, 5) == "Wheel" then
		return TIRE, false
	end
	return nil, false
end

return ToyCars
