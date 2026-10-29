--!strict
-- The one prop kit for the whole game (LOOK-BIBLE.md, 2026-10-29): rounded, chunky, low-poly toy
-- props in the bible's palette, the Smash Karts way. The arena, lobby, yard and garage all build
-- their trees, bushes, barrels, tyre stacks, cones and flags from here, so it reads as one game.
--
-- Every builder takes a parent, a base point (the prop stands on it) and a size: the prop's
-- height in the caller's own units, so a lobby at one scale and the arena at another both work.
-- Props are anchored SmoothPlastic with no touch events. `solid` (default: the part that should
-- stop a car, like a trunk or a barrel) can be forced either way.

local PropKit = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- the bible's palette, plus a darker second tone (about 18% darker) for each
PropKit.C = {
	grass = rgb(91, 209, 91),
	grassDark = rgb(70, 172, 72),
	sky = rgb(90, 200, 250),
	yellow = rgb(255, 210, 63),
	yellowDark = rgb(222, 172, 40),
	red = rgb(242, 64, 74),
	redDark = rgb(198, 46, 58),
	pink = rgb(255, 95, 180),
	pinkDark = rgb(214, 70, 150),
	purple = rgb(142, 68, 255),
	purpleDark = rgb(112, 50, 214),
	navy = rgb(30, 42, 90),
	navyLight = rgb(56, 70, 130),
	road = rgb(141, 141, 150),
	sand = rgb(242, 217, 166),
	white = rgb(246, 244, 238),
	orange = rgb(255, 140, 40),
	trunk = rgb(214, 150, 96), -- a warm caramel: a trunk, never a muddy brown
	trunkDark = rgb(184, 122, 74),
}
local C = PropKit.C

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	solid: boolean,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	p.CanCollide = solid
	p.CanQuery = solid
	p.CastShadow = true
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end
PropKit.part = part

-- an upright cylinder `h` tall, `d` across, its foot at `at`
local function post(
	parent: Instance,
	name: string,
	at: Vector3,
	d: number,
	h: number,
	color: Color3,
	solid: boolean
): Part
	return part(
		parent,
		name,
		Vector3.new(h, d, d),
		CFrame.new(at + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		solid,
		Enum.PartType.Cylinder
	)
end
PropKit.post = post

local function ball(
	parent: Instance,
	name: string,
	at: Vector3,
	d: number,
	color: Color3,
	solid: boolean
): Part
	return part(
		parent,
		name,
		Vector3.new(d, d, d),
		CFrame.new(at),
		color,
		solid,
		Enum.PartType.Ball
	)
end
PropKit.ball = ball

export type TreeStyle = "green" | "pink" | "yellow"
local CROWNS: { [string]: { Color3 } } = {
	green = { C.grass, C.grassDark },
	pink = { C.pink, C.pinkDark },
	yellow = { C.yellow, C.yellowDark },
}

-- A chunky round tree: a short thick trunk and a crown of three round blobs in two tones.
-- `h` is the whole tree's height; `seed` turns the blobs so a row of trees isn't all the same.
-- The trunk is solid unless `solid` says no; the crown never is (it's up out of the way).
function PropKit.tree(
	parent: Instance,
	at: Vector3,
	h: number,
	style: TreeStyle?,
	seed: number?,
	solid: boolean?
)
	local c = CROWNS[style or "green"]
	local s = seed or 0
	local crown = h * 0.62 -- the big blob's size
	local trunkH = h - crown * 0.85
	local trunkD = math.max(h * 0.16, 0.6)
	post(parent, "TreeTrunk", at, trunkD, trunkH + crown * 0.2, C.trunk, solid ~= false)
	local top = at + Vector3.new(0, trunkH + crown * 0.35, 0)
	ball(parent, "TreeTop", top, crown, c[1], false)
	local a = s * 2.1
	ball(
		parent,
		"TreeTop",
		top + Vector3.new(math.cos(a), -0.15, math.sin(a)) * crown * 0.42,
		crown * 0.72,
		c[2],
		false
	)
	ball(
		parent,
		"TreeTop",
		top + Vector3.new(math.cos(a + 2.4) * 0.38, 0.3, math.sin(a + 2.4) * 0.38) * crown,
		crown * 0.62,
		c[1],
		false
	)
end

-- A low round bush: three overlapping blobs in two greens, `h` tall. Karts drive through it.
function PropKit.bush(parent: Instance, at: Vector3, h: number, seed: number?, solid: boolean?)
	local s = seed or 0
	local d = h * 1.4
	local a = s * 1.7
	ball(parent, "Bush", at + Vector3.new(0, d * 0.25, 0), d, C.grassDark, solid == true)
	ball(
		parent,
		"Bush",
		at + Vector3.new(math.cos(a) * d * 0.45, d * 0.2, math.sin(a) * d * 0.45),
		d * 0.75,
		C.grass,
		solid == true
	)
	ball(
		parent,
		"Bush",
		at + Vector3.new(math.cos(a + 2.6) * d * 0.4, d * 0.15, math.sin(a + 2.6) * d * 0.4),
		d * 0.6,
		C.grass,
		solid == true
	)
end

-- A fat barrel: a red cylinder, two white bands, `h` tall. Solid by default.
function PropKit.barrel(parent: Instance, at: Vector3, h: number, color: Color3?, solid: boolean?)
	local d = h * 0.8
	local body = post(parent, "Barrel", at, d, h, color or C.red, solid ~= false)
	for _, y in { 0.28, 0.72 } do
		part(
			parent,
			"BarrelBand",
			Vector3.new(h * 0.12, d + 0.12, d + 0.12),
			CFrame.new(at + Vector3.new(0, h * y, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			C.white,
			false,
			Enum.PartType.Cylinder
		)
	end
	return body
end

-- A stack of fat tyres, `n` high (default 3), `h` tall in all: navy with a red middle tyre.
function PropKit.tyreStack(parent: Instance, at: Vector3, h: number, n: number?, solid: boolean?)
	local count = n or 3
	local th = h / count
	local d = th * 2.6
	for k = 0, count - 1 do
		post(
			parent,
			"Tyre",
			at + Vector3.new(0, th * k, 0),
			d,
			th * 0.98,
			if k == 1 then C.red else C.navy,
			solid ~= false
		)
		-- the hole: a darker disc on top
		post(
			parent,
			"TyreHole",
			at + Vector3.new(0, th * (k + 1) - th * 0.08, 0),
			d * 0.45,
			math.max(0.1 * th, 0.12),
			C.navyLight,
			false
		)
	end
end

-- A chunky traffic cone, `h` tall: three stacked tapering cylinders, orange-red and white.
function PropKit.cone(parent: Instance, at: Vector3, h: number, solid: boolean?)
	local d = h * 0.55
	part(
		parent,
		"ConeBase",
		Vector3.new(d * 1.2, h * 0.1, d * 1.2),
		CFrame.new(at + Vector3.new(0, h * 0.05, 0)),
		C.red,
		solid ~= false
	)
	local rings: { { from: number, to: number, d: number, color: Color3 } } = {
		{ from = 0.1, to = 0.42, d = d, color = C.red },
		{ from = 0.42, to = 0.66, d = d * 0.72, color = C.white },
		{ from = 0.66, to = 1, d = d * 0.46, color = C.red },
	}
	for _, r in rings do
		post(
			parent,
			"Cone",
			at + Vector3.new(0, h * r.from, 0),
			r.d,
			h * (r.to - r.from),
			r.color,
			solid ~= false
		)
	end
end

-- A chunky flag: a fat pole with a ball on top and a pennant in a palette colour, `h` tall.
-- The pole is solid unless told otherwise; the pennant never is.
function PropKit.flag(
	parent: Instance,
	at: Vector3,
	h: number,
	color: Color3?,
	facing: Vector3?,
	solid: boolean?
)
	local d = math.max(h * 0.07, 0.5)
	post(parent, "FlagPole", at, d, h, C.white, solid ~= false)
	ball(parent, "FlagTop", at + Vector3.new(0, h + d * 0.4, 0), d * 1.8, C.yellow, false)
	local f = facing or Vector3.new(1, 0, 0)
	f = Vector3.new(f.X, 0, f.Z)
	f = if f.Magnitude > 1e-3 then f.Unit else Vector3.xAxis
	local len, tall = h * 0.4, h * 0.26
	local mid = at + Vector3.new(0, h - tall / 2 - d * 0.5, 0) + f * (len / 2 + d / 2)
	-- a WedgePart pennant: thick, so it never reads as a paper-thin sliver
	local w = Instance.new("WedgePart")
	w.Name = "FlagCloth"
	w.Anchored = true
	w.Size = Vector3.new(math.max(h * 0.04, 0.3), tall, len)
	w.CFrame = CFrame.lookAt(mid, mid + f)
	w.Color = color or C.red
	w.Material = Enum.Material.SmoothPlastic
	w.CanCollide = false
	w.CanQuery = false
	w.CanTouch = false
	w.Parent = parent
end

return PropKit
