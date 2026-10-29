--!strict
-- The black+red muscle car (the Redline) built from boxes, wedges and cylinders, with lots of small
-- boxes for detail (carter 10-29 22:19: "i want blocky ... it has to have more boxes for detail";
-- a smooth body with blocky dragon heads did not match). Plain numbers only: a test checks it, a
-- preview page draws it, and the Studio script (assets/drake/build_blocky_redline.luau) turns it
-- into real parts and bakes each colour into one union so a phone moves ~25 parts, not ~200.
--
-- Units are studs, the body's middle is (0, 0, 0), nose +Z, up +Y, the car is about 5.9 wide,
-- 3.3 tall and 9.2 long (the size of the old smooth model). Rotations are degrees like
-- CFrame.Angles(x, y, z). A wedge's tall edge is at its +Z end (ArenaBuilder), so a plain wedge
-- slopes down toward the tail.

local BlockyRedlineData = {}

export type Part = {
	g: string, -- colour group: body, dark, chrome, glass, red, headlight, taillight, amber
	shape: "Block" | "Wedge" | "Cylinder",
	size: { number },
	at: { number },
	rot: { number },
}

BlockyRedlineData.COLORS = {
	body = { 21, 22, 27 },
	dark = { 8, 8, 12 },
	chrome = { 205, 210, 220 },
	glass = { 28, 36, 50 },
	red = { 232, 32, 47 },
	headlight = { 255, 255, 240 },
	taillight = { 255, 40, 50 },
	amber = { 255, 154, 32 },
} :: { [string]: { number } }
BlockyRedlineData.NEON =
	{ headlight = true, taillight = true, amber = true } :: { [string]: boolean }

-- where the wheels are (front +Z), and how big
BlockyRedlineData.WHEEL = { x = 2.45, y = -0.96, z = 2.82, radius = 0.95, width = 0.9 }

export type Variant = {
	name: string,
	cabinZ: number, -- the cabin's middle
	cabinL: number,
	cabinW: number,
	cabinH: number,
	fastback: boolean, -- a rear window that slopes down (else a flat trunk lid and upright glass)
	hoodH: number, -- how high the hood's top is
	octa: boolean?, -- two octagon headlights a side and three red lights on the scoop (the reference)
	heads: { x: number, y: number, z: number, yaw: number, scale: number, open: number }?, -- the dragon heads: at the front corners, turned out
}

BlockyRedlineData.VARIANTS = {
	{
		name = "Sharp Muscle",
		cabinZ = -0.6,
		cabinL = 3.0,
		cabinW = 4.3,
		cabinH = 1.15,
		fastback = true,
		hoodH = 0.62,
	},
	{
		name = "Reference Drake",
		cabinZ = -0.6,
		cabinL = 3.0,
		cabinW = 4.3,
		cabinH = 1.1,
		fastback = true,
		hoodH = 0.62,
		octa = true,
		heads = { x = 2.5, y = 0.35, z = 3.25, yaw = 26, scale = 1.0, open = 22 },
	},
	{
		name = "Boxy Bruiser",
		cabinZ = -0.9,
		cabinL = 4.0,
		cabinW = 4.7,
		cabinH = 1.3,
		fastback = false,
		hoodH = 0.7,
	},
} :: { Variant }

local function build(v: Variant): { Part }
	local P: { Part } = {}
	local function box(
		g: string,
		w: number,
		h: number,
		l: number,
		x: number,
		y: number,
		z: number,
		rot: { number }?
	)
		table.insert(P, {
			g = g,
			shape = "Block",
			size = { w, h, l },
			at = { x, y, z },
			rot = rot or { 0, 0, 0 },
		})
	end
	local function wedge(
		g: string,
		w: number,
		h: number,
		l: number,
		x: number,
		y: number,
		z: number,
		rot: { number }?
	)
		table.insert(P, {
			g = g,
			shape = "Wedge",
			size = { w, h, l },
			at = { x, y, z },
			rot = rot or { 0, 0, 0 },
		})
	end
	-- a cylinder along Z (exhaust tips, lamps): Roblox cylinders run along X, so turned 90
	local function pipe(g: string, dia: number, len: number, x: number, y: number, z: number)
		table.insert(P, {
			g = g,
			shape = "Cylinder",
			size = { len, dia, dia },
			at = { x, y, z },
			rot = { 0, 90, 0 },
		})
	end

	local hoodTop = v.hoodH
	local cabinFront = v.cabinZ + v.cabinL / 2
	local cabinBack = v.cabinZ - v.cabinL / 2
	local roofY = 0.4 + v.cabinH
	-- the main slab and the hood and trunk decks
	box("body", 4.7, 1.45, 8.8, 0, -0.45, 0)
	box("body", 5.5, 0.38, 4.4 - cabinFront, 0, hoodTop - 0.19, (4.4 + cabinFront) / 2)
	box("body", 5.5, 0.34, 2.3, 0, 0.45, -3.25)
	-- front and rear faces, sills, splitter, diffuser
	box("body", 5.5, 1.3, 0.4, 0, -0.55, 4.5)
	box("body", 5.5, 1.1, 0.4, 0, -0.55, -4.5)
	box("body", 5.8, 0.14, 1.0, 0, -1.4, 4.9)
	box("body", 3.4, 0.25, 0.9, 0, -1.35, -4.6)
	for _, s in { 1, -1 } do
		-- the wheels stand out of the sides: doors between them, a fender over each, a front and
		-- a rear quarter beyond them
		box("body", 0.5, 1.2, 3.4, s * 2.6, -0.55, 0)
		box("body", 0.3, 0.35, 3.4, s * 2.75, -1.0, 0)
		for _, z in { 2.82, -2.82 } do
			box("body", 0.95, 0.5, 3.0, s * 2.55, 0.17, z)
			box("red", 0.97, 0.05, 3.0, s * 2.55, 0.43, z)
			box("body", 0.5, 0.18, 2.4, s * 2.35, -0.06, z)
		end
		box("body", 0.6, 1.2, 0.7, s * 2.6, -0.55, 4.2)
		box("body", 0.6, 1.2, 0.7, s * 2.6, -0.55, -4.2)
		-- door seams, handles, mirrors, side vents behind the front wheel
		for _, z in { 1.0, -1.7 } do
			box("dark", 0.07, 1.15, 0.07, s * 2.86, -0.4, z)
		end
		box("dark", 0.07, 0.07, 3.3, s * 2.86, -0.95, 0)
		for _, z in { 0.2, -1.0 } do
			box("chrome", 0.1, 0.1, 0.45, s * 2.88, -0.05, z)
		end
		box("chrome", 0.35, 0.28, 0.45, s * 2.55, 0.85, cabinFront - 0.1)
		box("dark", 0.1, 0.2, 0.3, s * 2.4, 0.78, cabinFront - 0.1)
		for i = 0, 3 do
			box("red", 0.06, 0.55, 0.1, s * 2.92, -0.15, 3.95 + i * 0.2)
		end
		box("red", 0.06, 0.14, 3.3, s * 2.86, -0.72, 0)
		-- a cabin: windows and a pillar
		box(
			"glass",
			0.1,
			v.cabinH * 0.6,
			v.cabinL * 0.38,
			s * (v.cabinW / 2 + 0.01),
			0.4 + v.cabinH * 0.5,
			v.cabinZ + v.cabinL * 0.22
		)
		box(
			"glass",
			0.1,
			v.cabinH * 0.6,
			v.cabinL * 0.3,
			s * (v.cabinW / 2 + 0.01),
			0.4 + v.cabinH * 0.5,
			v.cabinZ - v.cabinL * 0.2
		)
		box(
			"body",
			0.22,
			v.cabinH * 0.9,
			0.3,
			s * (v.cabinW / 2),
			0.4 + v.cabinH * 0.5,
			v.cabinZ - v.cabinL * 0.02
		)
		-- the lights and the grille's frame at the front
		box("chrome", 0.9, 0.9, 0.12, s * 2.0, -0.1, 4.72)
		if not v.octa then
			box("headlight", 0.62, 0.62, 0.1, s * 2.0, -0.1, 4.76)
		end
		box("amber", 0.3, 0.16, 0.1, s * 2.55, -0.65, 4.74)
		box("taillight", 1.3, 0.34, 0.1, s * 1.85, 0.12, -4.72)
		box("dark", 1.5, 0.5, 0.08, s * 1.85, 0.12, -4.7)
		pipe("chrome", 0.5, 0.7, s * 1.2, -1.0, -4.9)
		pipe("dark", 0.34, 0.72, s * 1.2, -1.0, -4.92)
		-- wing end plates and uprights
		box("red", 0.1, 0.55, 1.2, s * 2.7, 1.4, -4.1)
		box("body", 0.18, 0.8, 0.3, s * 1.8, 1.0, -4.1)
		-- hood pins
		box("chrome", 0.1, 0.1, 0.1, s * 1.5, hoodTop + 0.04, cabinFront + 0.5)
	end
	if v.octa then
		-- two octagon lamps a side (a square and the same square turned 45 degrees), amber strips under
		for _, s in { 1, -1 } do
			for _, x in { 1.3, 2.05 } do
				-- an octagon: a wide box, a tall box and a box turned 45 degrees over the corners
				table.insert(P, {
					g = "headlight",
					shape = "Block",
					size = { 0.54, 0.38, 0.1 },
					at = { s * x, -0.1, 4.8 },
					rot = { 0, 0, 0 },
				})
				table.insert(P, {
					g = "headlight",
					shape = "Block",
					size = { 0.38, 0.54, 0.1 },
					at = { s * x, -0.1, 4.8 },
					rot = { 0, 0, 0 },
				})
				table.insert(P, {
					g = "headlight",
					shape = "Block",
					size = { 0.4, 0.4, 0.1 },
					at = { s * x, -0.1, 4.8 },
					rot = { 0, 0, 45 },
				})
			end
			box("amber", 0.6, 0.14, 0.1, s * 2.4, -0.7, 4.78)
		end
		for _, x in { -0.45, 0, 0.45 } do
			box("taillight", 0.28, 0.2, 0.1, x, hoodTop + 0.3, cabinFront + 1.92)
		end
	end
	-- the grille, its bars, the intake, the bumpers
	box("dark", 3.4, 0.6, 0.12, 0, -0.35, 4.72)
	for i = 0, 4 do
		box("chrome", 3.3, 0.04, 0.1, 0, -0.58 + i * 0.12, 4.78)
	end
	box("red", 0.1, 0.3, 0.1, 0, -0.35, 4.8)
	box("dark", 3.2, 0.3, 0.1, 0, -1.0, 4.72)
	box("chrome", 5.9, 0.3, 0.35, 0, -0.85, 4.85)
	box("chrome", 5.9, 0.3, 0.35, 0, -0.85, -4.8)
	box("taillight", 1.2, 0.12, 0.1, 0, 0.12, -4.72)
	-- the hood: scoop, vents, stripes
	box("body", 1.5, 0.35, 1.8, 0, hoodTop + 0.17, cabinFront + 1.0)
	box("dark", 1.1, 0.2, 0.1, 0, hoodTop + 0.2, cabinFront + 1.95)
	for i = 0, 3 do
		box("dark", 0.9, 0.03, 0.09, 0, hoodTop + 0.4, cabinFront + 0.3 + i * 0.25)
	end
	for _, s in { 1, -1 } do
		box("red", 0.42, 0.04, (4.4 - cabinFront), s * 0.45, hoodTop + 0.02, (4.4 + cabinFront) / 2)
		box("red", 0.42, 0.04, v.cabinL * 0.75, s * 0.45, roofY + 0.1, v.cabinZ)
		box("red", 0.42, 0.04, 2.2, s * 0.45, 0.63, -3.25)
	end
	-- the roof
	box("body", v.cabinW + 0.15, 0.2, v.cabinL - 0.1, 0, roofY, v.cabinZ)
	box("body", v.cabinW, v.cabinH, v.cabinL, 0, 0.4 + v.cabinH / 2, v.cabinZ)
	-- the windscreen slopes down toward the nose; the rear window slopes (fastback) or stands (boxy)
	wedge(
		"glass",
		v.cabinW - 0.3,
		v.cabinH,
		1.5,
		0,
		0.4 + v.cabinH / 2,
		cabinFront + 0.75,
		{ 0, 180, 0 }
	)
	wedge(
		"body",
		0.2,
		v.cabinH,
		1.5,
		v.cabinW / 2 - 0.1,
		0.4 + v.cabinH / 2,
		cabinFront + 0.75,
		{ 0, 180, 0 }
	)
	wedge(
		"body",
		0.2,
		v.cabinH,
		1.5,
		-v.cabinW / 2 + 0.1,
		0.4 + v.cabinH / 2,
		cabinFront + 0.75,
		{ 0, 180, 0 }
	)
	if v.fastback then
		wedge("glass", v.cabinW - 0.3, v.cabinH, 1.6, 0, 0.4 + v.cabinH / 2, cabinBack - 0.8)
		wedge("body", 0.2, v.cabinH, 1.6, v.cabinW / 2 - 0.1, 0.4 + v.cabinH / 2, cabinBack - 0.8)
		wedge("body", 0.2, v.cabinH, 1.6, -v.cabinW / 2 + 0.1, 0.4 + v.cabinH / 2, cabinBack - 0.8)
	else
		box("glass", v.cabinW - 0.3, v.cabinH * 0.6, 0.1, 0, 0.4 + v.cabinH * 0.5, cabinBack - 0.01)
	end
	-- a duck-tail lip and the wing: red blade, dark centre block
	box("body", 4.8, 0.14, 0.7, 0, 0.7, -4.3)
	box("red", 5.4, 0.12, 1.2, 0, 1.5, -4.1)
	box("dark", 1.6, 0.1, 0.3, 0, 1.4, -4.1)
	-- an underbody plate and a front tow hook
	box("dark", 4.6, 0.12, 8.2, 0, -1.2, 0)
	box("red", 0.18, 0.18, 0.4, 0, -1.15, 5.0)
	return P
end

function BlockyRedlineData.parts(variant: number): { Part }
	return build(BlockyRedlineData.VARIANTS[variant])
end

-- the four wheels: a tyre with tread blocks and a red five-spoke rim with a chrome hub. Each is one
-- piece in Studio (tyre + rim + hub unioned); `x` and `z` are signs (+1 left/front).
function BlockyRedlineData.wheelParts(): { Part }
	local W = BlockyRedlineData.WHEEL
	local P: { Part } = {}
	local d = W.radius * 2
	table.insert(P, {
		g = "dark",
		shape = "Cylinder",
		size = { W.width, d, d },
		at = { 0, 0, 0 },
		rot = { 0, 0, 0 },
	})
	-- tread: twelve small blocks round the tyre
	for i = 0, 11 do
		local a = i * 30
		table.insert(P, {
			g = "dark",
			shape = "Block",
			size = { W.width * 0.8, 0.14, 0.34 },
			at = { 0, W.radius * math.cos(math.rad(a)), W.radius * math.sin(math.rad(a)) },
			rot = { a, 0, 0 },
		})
	end
	-- the rim: a red disc standing a little proud of the tyre, five spokes, a chrome hub
	table.insert(P, {
		g = "red",
		shape = "Cylinder",
		size = { W.width + 0.06, d * 0.66, d * 0.66 },
		at = { 0, 0, 0 },
		rot = { 0, 0, 0 },
	})
	for i = 0, 4 do
		table.insert(P, {
			g = "dark",
			shape = "Block",
			size = { W.width + 0.1, 0.16, d * 0.62 },
			at = { 0, 0, 0 },
			rot = { i * 36, 0, 0 },
		})
	end
	table.insert(P, {
		g = "chrome",
		shape = "Cylinder",
		size = { W.width + 0.14, d * 0.2, d * 0.2 },
		at = { 0, 0, 0 },
		rot = { 0, 0, 0 },
	})
	return P
end

return BlockyRedlineData
