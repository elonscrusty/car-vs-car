--!strict
-- Small props and scenery for the chase map "Wreck City", all built from plain Parts (no meshes,
-- no asset ids). Every builder takes the parent, a base CFrame (the middle of the model's foot on
-- the ground, facing -Z) and returns an anchored Model whose PrimaryPart is the part named "Body".
--
-- Breakable props (barrel, fence, road sign, cone, crate stack) carry the attributes Breakable=true
-- and BreakHealth=1. Their Body is the only part cars can touch: it does not collide (cars drive
-- through), but it fires Touched and can be queried, so the break script can smash the model. All
-- other parts are looks only. Buildings have one solid box named "Core" (the walls) and nothing else
-- collides; trees, hills, bushes and lamp posts never collide at all.
--
-- Part budgets (phones): barrel 6, cone 4, sign <= 6, crates 6, fence <= 14, lamp 6, tree <= 5,
-- bush <= 3, hill <= 3, building <= 27.

local MapParts = require(script.Parent.MapParts)

local ChaseProps = {}

local rgb, part = MapParts.rgb, MapParts.part

-- The duel arena's palette, so both maps feel like one toy box.
local C = {
	orange = { 245, 130, 32 },
	blue = { 37, 141, 221 },
	red = { 214, 58, 52 },
	yellow = { 255, 214, 64 },
	white = { 248, 248, 242 },
	ink = { 36, 39, 43 },
	metal = { 128, 134, 146 },
	metalDark = { 70, 76, 88 },
	navy = { 44, 62, 110 },
	teal = { 40, 186, 170 },
	pink = { 255, 120, 150 },
	trunk = { 120, 82, 52 },
	leaf = { 86, 160, 58 },
	leafLight = { 118, 190, 70 },
	pine = { 52, 128, 78 },
	pineLight = { 72, 152, 92 },
	hill = { 142, 200, 84 },
	hillLight = { 160, 214, 98 },
	bush = { 70, 150, 64 },
	crate = { 176, 128, 76 },
	glass = { 196, 234, 255 },
	lamp = { 255, 236, 170 },
	flowers = { { 255, 214, 64 }, { 255, 120, 150 }, { 255, 255, 255 }, { 176, 120, 255 } },
}

-- Building walls: { wall, accent (door, awning, sign) }. Bright and a little chalky.
local PALETTES: { { wall: { number }, accent: { number } } } = {
	{ wall = { 255, 196, 92 }, accent = { 214, 58, 52 } }, -- sunny yellow, red trim
	{ wall = { 120, 196, 240 }, accent = { 245, 130, 32 } }, -- sky blue, orange trim
	{ wall = { 255, 150, 160 }, accent = { 37, 141, 221 } }, -- bubblegum, blue trim
	{ wall = { 150, 214, 120 }, accent = { 214, 58, 52 } }, -- mint, red trim
	{ wall = { 190, 156, 240 }, accent = { 255, 214, 64 } }, -- lavender, yellow trim
	{ wall = { 90, 206, 192 }, accent = { 245, 130, 32 } }, -- teal, orange trim
}

local SHOP_NAMES = { "TOYS", "PIZZA", "GARAGE", "DINER", "BURGERS", "MOTEL", "PARTS", "SODA" }

-- A repeatable 0..1 number from a position (no math.random: the same map every server).
local function hash(v: Vector3, salt: number): number
	local x = math.sin(v.X * 12.9898 + v.Z * 78.233 + salt * 37.719) * 43758.5453
	return x - math.floor(x)
end

local function darken(c: Color3, k: number): Color3
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

local function newModel(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	return m
end

-- Look-only box at `cf`.
local function box(
	m: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	return part(m, name, size, cf, color, false, nil, material)
end

-- Look-only upright cylinder: diameter `d`, height `h`, bottom middle at `base` (follows its turn).
local function post(
	m: Instance,
	name: string,
	d: number,
	h: number,
	base: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = part(
		m,
		name,
		Vector3.new(h, d, d),
		base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		false,
		nil,
		material
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Look-only flat disc facing -Z (a round sign face): diameter `d`, `thick` deep, centred at `cf`.
local function disc(
	m: Instance,
	name: string,
	d: number,
	thick: number,
	cf: CFrame,
	color: Color3
): Part
	local p =
		part(m, name, Vector3.new(thick, d, d), cf * CFrame.Angles(0, math.pi / 2, 0), color, false)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function sphere(m: Instance, name: string, d: number, pos: Vector3, color: Color3): Part
	local p = part(m, name, Vector3.new(d, d, d), CFrame.new(pos), color, false)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Bold FredokaOne text on one face of `p`, lit the same in sun and shade.
local function label(p: Part, text: string, color: Color3, stroke: Color3, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(0.9, 0.84)
	l.Position = UDim2.fromScale(0.05, 0.08)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextWrapped = true
	l.Text = text
	l.TextColor3 = color
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = stroke
	l.Parent = gui
end

-- Ends a breakable prop: Body becomes the touch trigger (no collision), the model gets its
-- break attributes and goes into the world.
local function breakable(m: Model, body: Part, parent: Instance): Model
	body.CanCollide = false
	body.CanTouch = true
	body.CanQuery = true
	m.PrimaryPart = body
	m:SetAttribute("Breakable", true)
	m:SetAttribute("BreakHealth", 1)
	m.Parent = parent
	return m
end

-- Ends a look-only prop (Body already made with solid=false).
local function finish(m: Model, body: Part, parent: Instance): Model
	m.PrimaryPart = body
	m.Parent = parent
	return m
end

-- Oil drum 4.5 across, 5.5 tall: two dark rims, a painted band round the middle, a lid and a
-- bung cap. Red with a yellow band unless a color is given (then the band is white).
function ChaseProps.barrel(parent: Instance, cf: CFrame, color: Color3?): Model
	local m = newModel("Barrel")
	local main = color or rgb(C.red)
	local bandColor = if color then rgb(C.white) else rgb(C.yellow)
	local rim = darken(main, 0.68)
	local body = post(m, "Body", 4.5, 5.5, cf, main)
	post(m, "RimLow", 4.8, 0.45, cf * CFrame.new(0, 0.35, 0), rim)
	post(m, "RimHigh", 4.8, 0.45, cf * CFrame.new(0, 4.7, 0), rim)
	post(m, "Band", 4.62, 1.1, cf * CFrame.new(0, 2.2, 0), bandColor)
	post(m, "Lid", 3.9, 0.14, cf * CFrame.new(0, 5.5, 0), rim)
	local a = hash(cf.Position, 1) * math.pi * 2 -- the bung sits somewhere different on each drum
	post(
		m,
		"Cap",
		0.8,
		0.35,
		cf * CFrame.new(math.cos(a) * 1.15, 5.5, math.sin(a) * 1.15),
		rgb(C.ink)
	)
	return breakable(m, body, parent)
end

-- Painted fence `length` long along local X, 4.5 tall: white posts at both ends and every ~6
-- studs (at most 4 bays, so longer fences get longer bays), a white board and a red top rail in
-- each bay, and one red kick rail along the whole foot. The kick rail is Body (the touch trigger),
-- so a car hitting any bay breaks the whole section.
function ChaseProps.fence(parent: Instance, cf: CFrame, length: number): Model
	local m = newModel("Fence")
	local len = math.max(length, 2)
	local bays = math.clamp(math.floor(len / 6 + 0.5), 1, 4)
	local bay = len / bays
	local white, red = rgb(C.white), rgb(C.red)
	local body = box(m, "Body", Vector3.new(len, 0.8, 0.6), cf * CFrame.new(0, 0.9, 0), red)
	for i = 0, bays do
		local x = -len / 2 + i * bay
		box(m, "Post", Vector3.new(1.2, 4.5, 1.2), cf * CFrame.new(x, 2.25, 0), white)
	end
	for i = 0, bays - 1 do
		local x = -len / 2 + (i + 0.5) * bay
		box(
			m,
			"Board",
			Vector3.new(math.max(bay - 1.2, 0.4), 2.1, 0.4),
			cf * CFrame.new(x, 2.35, 0),
			white,
			Enum.Material.Wood
		)
		box(m, "Rail", Vector3.new(bay, 0.7, 0.6), cf * CFrame.new(x, 3.75, 0), red)
	end
	return breakable(m, body, parent)
end

-- Road sign on a 14 stud post (the post is Body). The face looks along -Z (both sides of a text
-- board read the same). Kinds: "arrow" (yellow board, black arrow pointing +X), "stop" (red
-- octagon from four bars, white ring behind), "diner" (teal board, glowing pink bars), "wreck"
-- (orange WRECK CITY board), "star" (blue disc, yellow eight point burst). Anything else = arrow.
function ChaseProps.roadSign(parent: Instance, cf: CFrame, kind: string): Model
	local m = newModel("RoadSign")
	local body = box(m, "Body", Vector3.new(0.9, 14, 0.9), cf * CFrame.new(0, 7, 0), rgb(C.metal))
	local at = cf * CFrame.new(0, 11, -0.75) -- the middle of the sign face, just in front of the post
	local front = -0.3 -- a little nearer the viewer, for parts laid on the board
	if kind == "stop" then
		-- A regular octagon is exactly four bars (0, 45, 90, 135 degrees), each 6 long and
		-- 6 * (sqrt 2 - 1) thick. The white disc behind peeks out as a rim.
		local w = 6
		local s = w * (math.sqrt(2) - 1)
		local red = rgb(C.red)
		disc(m, "Rim", 6.7, 0.3, at * CFrame.new(0, 0, 0.25), rgb(C.white))
		local bar = box(m, "Face", Vector3.new(w, s, 0.5), at * CFrame.new(0, 0, -0.05), red)
		box(m, "Face", Vector3.new(s, w, 0.5), at, red)
		box(m, "Face", Vector3.new(w, s, 0.5), at * CFrame.Angles(0, 0, math.pi / 4), red)
		box(m, "Face", Vector3.new(w, s, 0.5), at * CFrame.Angles(0, 0, -math.pi / 4), red)
		label(bar, "STOP", rgb(C.white), darken(red, 0.6), Enum.NormalId.Front)
	elseif kind == "diner" then
		local board =
			box(m, "Board", Vector3.new(9, 3.6, 0.5), at, rgb(C.teal), Enum.Material.SmoothPlastic)
		for _, y in { 2.2, -2.2 } do
			box(
				m,
				"Glow",
				Vector3.new(9.4, 0.6, 0.6),
				at * CFrame.new(0, y, 0),
				rgb(C.pink),
				Enum.Material.Neon
			)
		end
		label(board, "DINER", rgb(C.yellow), rgb(C.ink), Enum.NormalId.Front)
		label(board, "DINER", rgb(C.yellow), rgb(C.ink), Enum.NormalId.Back)
	elseif kind == "wreck" then
		local board = box(m, "Board", Vector3.new(9, 4.4, 0.5), at, rgb(C.orange))
		box(m, "Stripe", Vector3.new(9, 0.8, 0.6), at * CFrame.new(0, -2.6, 0), rgb(C.ink))
		label(board, "WRECK CITY", rgb(C.white), rgb(C.blue), Enum.NormalId.Front)
		label(board, "WRECK CITY", rgb(C.white), rgb(C.blue), Enum.NormalId.Back)
	elseif kind == "star" then
		disc(m, "Board", 6.4, 0.5, at, rgb(C.blue))
		local burst = at * CFrame.new(0, 0, front)
		box(m, "Star", Vector3.new(3.4, 3.4, 0.2), burst, rgb(C.yellow))
		box(
			m,
			"Star",
			Vector3.new(3.4, 3.4, 0.2),
			burst * CFrame.Angles(0, 0, math.pi / 4),
			rgb(C.yellow)
		)
	else
		box(m, "Board", Vector3.new(8, 4.4, 0.5), at, rgb(C.yellow))
		local face = at * CFrame.new(0, 0, front)
		box(m, "Shaft", Vector3.new(4.2, 1.2, 0.2), face * CFrame.new(-0.6, 0, 0), rgb(C.ink))
		-- a diamond whose left half hides behind the shaft end: the point of the arrow
		box(
			m,
			"Head",
			Vector3.new(2.4, 2.4, 0.2),
			face * CFrame.new(1.5, 0, 0) * CFrame.Angles(0, 0, math.pi / 4),
			rgb(C.ink)
		)
	end
	return breakable(m, body, parent)
end

-- Traffic cone 3.5 tall: a dark square foot, the orange lower cone (Body), a white band and an
-- orange tip, stepped thinner like a toy.
function ChaseProps.cone(parent: Instance, cf: CFrame): Model
	local m = newModel("Cone")
	local orange = rgb(C.orange)
	box(m, "Foot", Vector3.new(3.2, 0.4, 3.2), cf * CFrame.new(0, 0.2, 0), rgb(C.ink))
	local body = post(m, "Body", 2.5, 1.9, cf, orange)
	post(m, "Band", 1.9, 0.6, cf * CFrame.new(0, 1.9, 0), rgb(C.white))
	post(m, "Tip", 1.25, 1.0, cf * CFrame.new(0, 2.5, 0), orange)
	return breakable(m, body, parent)
end

-- Two 3.5 stud wooden crates, the top one turned a little and off centre, each with a painted
-- strap round its top and bottom edges. The bottom crate is Body.
function ChaseProps.crateStack(parent: Instance, cf: CFrame): Model
	local m = newModel("CrateStack")
	local s = 3.5
	local wood = rgb(C.crate)
	local turn = 0.2 + hash(cf.Position, 2) * 0.4
	local top = cf * CFrame.new(0.3, s, -0.2) * CFrame.Angles(0, turn, 0)
	local body =
		box(m, "Body", Vector3.new(s, s, s), cf * CFrame.new(0, s / 2, 0), wood, Enum.Material.Wood)
	box(m, "Crate", Vector3.new(s, s, s), top * CFrame.new(0, s / 2, 0), wood, Enum.Material.Wood)
	local function straps(base: CFrame, color: Color3)
		for _, y in { 0.35, s - 0.35 } do
			box(m, "Strap", Vector3.new(s + 0.12, 0.5, s + 0.12), base * CFrame.new(0, y, 0), color)
		end
	end
	straps(cf, rgb(C.orange))
	straps(top, rgb(C.blue))
	return breakable(m, body, parent)
end

-- Street lamp about 22 tall: a foot, a navy pole (Body), an arm reaching forward (-Z) and a head
-- with a glowing Neon lamp under it. No collision, never breaks.
function ChaseProps.lampPost(parent: Instance, cf: CFrame): Model
	local m = newModel("LampPost")
	local navy = rgb(C.navy)
	post(m, "Foot", 2.4, 1.2, cf, rgb(C.metalDark))
	local body = post(m, "Body", 1.0, 21, cf, navy)
	box(m, "Arm", Vector3.new(0.8, 0.8, 6), cf * CFrame.new(0, 20.6, -2.75), navy)
	box(m, "Head", Vector3.new(2.6, 1.2, 3.6), cf * CFrame.new(0, 20.3, -5.4), rgb(C.orange))
	box(
		m,
		"Lamp",
		Vector3.new(2.0, 0.4, 3.0),
		cf * CFrame.new(0, 19.55, -5.4),
		rgb(C.lamp),
		Enum.Material.Neon
	)
	sphere(m, "Cap", 1.4, (cf * CFrame.new(0, 21.2, 0)).Position, navy)
	return finish(m, body, parent)
end

-- A tree, looks only. "round": a trunk and three puffy leaf balls (about 20 tall at scale 1).
-- "pine": a trunk, three stacked green cans getting thinner and a ball on top (about 19 tall).
function ChaseProps.tree(parent: Instance, cf: CFrame, kind: string, scale: number?): Model
	local m = newModel("Tree")
	local k = scale or 1
	local function at(x: number, y: number, z: number): Vector3
		return (cf * CFrame.new(x * k, y * k, z * k)).Position
	end
	local body: Part
	if kind == "pine" then
		body = post(m, "Body", 2.2 * k, 5 * k, cf, rgb(C.trunk), Enum.Material.Wood)
		for i = 0, 2 do
			post(
				m,
				"Pine",
				(12 - i * 3.6) * k,
				5.5 * k,
				cf * CFrame.new(0, (3.5 + i * 4.6) * k, 0),
				rgb(if i % 2 == 0 then C.pine else C.pineLight)
			)
		end
		sphere(m, "Tip", 2.6 * k, at(0, 18.3, 0), rgb(C.pineLight))
	else
		body = post(m, "Body", 2.8 * k, 8 * k, cf, rgb(C.trunk), Enum.Material.Wood)
		sphere(m, "Leaves", 13 * k, at(0, 12, 0), rgb(C.leaf))
		sphere(m, "Puff", 9 * k, at(2.5, 15.5, 1), rgb(C.leafLight))
		sphere(m, "Puff", 8 * k, at(-3, 13.5, -1.5), rgb(C.leafLight))
	end
	return finish(m, body, parent)
end

-- Toy city block, `w` wide (X), `d` deep (Z), `h` tall, front (door) on the -Z side. Best with
-- w, d >= 10 and h >= 14. The walls are one solid box "Core" (the only part that collides); round
-- it, looks only: a darker plinth (Body), a darker roof lip, a roof unit with a cap, a shop window
-- and door with a striped awning and a shop name board on the ground floor, and one window band per
-- upper floor that wraps all four sides as two crossed strips (walls show at the corners).
function ChaseProps.building(
	parent: Instance,
	cf: CFrame,
	w: number,
	d: number,
	h: number,
	paletteIndex: number
): Model
	local m = newModel("Building")
	local pal = PALETTES[(math.floor(paletteIndex) - 1) % #PALETTES + 1]
	local wall, accent = rgb(pal.wall), rgb(pal.accent)
	local trim = MapParts.shade(pal.wall, 0.72)
	local glass = rgb(C.glass)
	local fz = -d / 2 -- the front face

	part(m, "Core", Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0), wall, true)
	local body =
		box(m, "Body", Vector3.new(w + 0.8, 1.2, d + 0.8), cf * CFrame.new(0, 0.6, 0), trim)
	box(m, "RoofLip", Vector3.new(w + 1.2, 1.0, d + 1.2), cf * CFrame.new(0, h - 0.3, 0), trim)

	-- roof unit: a boxy vent or a round tank, picked by position so neighbours differ
	local pick = hash(cf.Position, 3)
	local rx, rz = (pick - 0.5) * w * 0.3, (0.5 - pick) * d * 0.3
	if pick < 0.5 then
		local bw, bd = math.max(w * 0.3, 3), math.max(d * 0.3, 3)
		box(m, "RoofBox", Vector3.new(bw, 3, bd), cf * CFrame.new(rx, h + 1.5, rz), rgb(C.metal))
		box(
			m,
			"RoofCap",
			Vector3.new(bw + 0.6, 0.6, bd + 0.6),
			cf * CFrame.new(rx, h + 3.2, rz),
			accent
		)
	else
		local td = math.max(math.min(w, d) * 0.3, 3)
		post(m, "RoofBox", td, 4, cf * CFrame.new(rx, h, rz), rgb(C.white))
		post(m, "RoofCap", td + 0.6, 0.6, cf * CFrame.new(rx, h + 4, rz), accent)
	end

	-- ground floor shop front
	local doorW, doorH = math.min(5, w * 0.4), 6.5
	box(
		m,
		"ShopWindow",
		Vector3.new(math.max(w - 4, 1), 4.4, 0.3),
		cf * CFrame.new(0, 3.4, fz - 0.15),
		glass
	)
	box(
		m,
		"Door",
		Vector3.new(doorW, doorH, 0.5),
		cf * CFrame.new(0, doorH / 2, fz - 0.25),
		darken(accent, 0.75)
	)
	box(
		m,
		"Awning",
		Vector3.new(math.min(doorW + 4, w - 1), 0.7, 3),
		cf * CFrame.new(0, doorH + 0.9, fz - 1.4) * CFrame.Angles(-0.3, 0, 0),
		accent
	)
	local sign = box(
		m,
		"ShopSign",
		Vector3.new(math.max(math.min(w - 2, 12), 2), 2.4, 0.5),
		cf * CFrame.new(0, doorH + 3.1, fz - 0.25),
		rgb(C.white)
	)
	local name = SHOP_NAMES[math.floor(hash(cf.Position, 4) * #SHOP_NAMES) + 1]
	label(sign, name, accent, rgb(C.white), Enum.NormalId.Front)

	-- upper floors, 9 studs apart; at most 9 bands keeps the whole building at 27 parts
	local floors = math.clamp(math.floor((h - 8.1) / 9), 0, 9)
	for i = 1, floors do
		local y = i * 9 + 4.5
		box(
			m,
			"Windows",
			Vector3.new(w + 0.3, 3.2, math.max(d - 3, 0.4)),
			cf * CFrame.new(0, y, 0),
			glass
		)
		box(
			m,
			"Windows",
			Vector3.new(math.max(w - 3, 0.4), 3.2, d + 0.3),
			cf * CFrame.new(0, y, 0),
			glass
		)
	end
	return finish(m, body, parent)
end

-- A soft grass mound `radius` across its foot and `height` tall: the top cap of one big ball
-- sunk in the ground (Body), plus a smaller lighter bump on its side. Looks only. Very flat
-- mounds are made a little taller so the ball stays under Roblox's 2048 stud size limit.
function ChaseProps.hill(parent: Instance, cf: CFrame, radius: number, height: number): Model
	local m = newModel("Hill")
	local function cap(
		name: string,
		r: number,
		hh: number,
		x: number,
		z: number,
		color: Color3
	): Part
		local h2 = math.max(hh, r * r / 1900, 0.5)
		local R = (r * r + h2 * h2) / (2 * h2) -- ball radius whose cap is r wide and h2 tall
		return sphere(m, name, R * 2, (cf * CFrame.new(x, h2 - R, z)).Position, color)
	end
	local body = cap("Body", radius, height, 0, 0, rgb(C.hill))
	local a = hash(cf.Position, 5) * math.pi * 2
	local off = radius * 0.5
	cap("Bump", radius * 0.5, height * 0.75, math.cos(a) * off, math.sin(a) * off, rgb(C.hillLight))
	if radius > 30 then
		cap(
			"Bump",
			radius * 0.35,
			height * 0.6,
			-math.cos(a) * off,
			-math.sin(a) * off,
			rgb(C.hillLight)
		)
	end
	return finish(m, body, parent)
end

-- A round bush of two green balls; about half of them have a flower on top. Looks only.
function ChaseProps.bush(parent: Instance, cf: CFrame): Model
	local m = newModel("Bush")
	local function at(x: number, y: number, z: number): Vector3
		return (cf * CFrame.new(x, y, z)).Position
	end
	local body = sphere(m, "Body", 5, at(0, 1.8, 0), rgb(C.bush))
	sphere(m, "Puff", 3.8, at(2, 1.4, 0.8), rgb(C.leafLight))
	local f = hash(cf.Position, 6)
	if f < 0.5 then
		sphere(m, "Flower", 1.2, at(-0.6, 4.2, -0.8), rgb(C.flowers[math.floor(f * 8) + 1]))
	end
	return finish(m, body, parent)
end

return ChaseProps
