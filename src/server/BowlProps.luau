--!strict
-- Small props and scenery for the round battle map, all built from plain Parts (no meshes, no
-- asset ids). Every builder takes the parent, a base CFrame (the middle of the model's foot on
-- the ground, facing -Z) and returns an anchored Model whose PrimaryPart is the part named "Body".
--
-- Breakable props (barrel, red barrel, crate, cone, sign, fence) carry the attributes
-- Breakable=true and BreakHealth=1. Their Body is the only part cars can touch: it does not
-- collide (cars drive through), but it fires Touched and can be queried, so the break script can
-- smash the model. A red barrel also carries Explosive=true. All other parts are looks only.
-- Trees, hills and containers never collide at all.
--
-- Part budgets (phones): barrel 3, red barrel 4, crate 3, cone 3, sign <= 4, fence 5, tree <= 4,
-- hill <= 3, container 2.

local MapParts = require(script.Parent.MapParts)
local MeshProps = require(script.Parent.MeshProps)

local BowlProps = {}

local rgb, part = MapParts.rgb, MapParts.part

local C = {
	white = { 248, 248, 242 },
	ink = { 36, 39, 43 },
	metal = { 128, 134, 146 },
	orange = { 245, 130, 32 },
	yellow = { 255, 214, 64 },
	red = { 214, 58, 52 },
	teal = { 40, 186, 170 },
	blue = { 37, 141, 221 },
	trunk = { 120, 82, 52 },
	leaf = { 86, 160, 58 },
	leafLight = { 118, 190, 70 },
	pine = { 52, 128, 78 },
	pineLight = { 72, 152, 92 },
	hill = { 142, 200, 84 },
	hillLight = { 160, 214, 98 },
}

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

-- Puts carter's low-poly model `name` into `m` (one MeshPart, look only). False when it is not
-- imported yet: the caller then builds its Part version.
local function mesh(m: Model, name: string, cf: CFrame, height: number): boolean
	local copy = MeshProps.place(name, m, cf, height)
	if copy == nil then
		return false
	end
	local p = copy.PrimaryPart :: BasePart
	p.Name = name
	p.Parent = m
	copy:Destroy()
	return true
end

-- Ends a look-only prop (Body already made with solid=false).
local function finish(m: Model, body: Part, parent: Instance): Model
	m.PrimaryPart = body
	m.Parent = parent
	return m
end

-- Oil drum 4.5 across, 5.5 tall in a bright toy colour: a white band round the middle and a dark
-- lid. 3 parts.
function BowlProps.barrel(parent: Instance, cf: CFrame, color: Color3): Model
	local m = newModel("Barrel")
	local body = post(m, "Body", 4.5, 5.5, cf, color)
	post(m, "Band", 4.62, 1.1, cf * CFrame.new(0, 2.2, 0), rgb(C.white))
	post(m, "Lid", 3.9, 0.14, cf * CFrame.new(0, 5.5, 0), darken(color, 0.6))
	return breakable(m, body, parent)
end

-- The red barrel: yellow band, a black fuse on the lid. It blows up when a car hits it.
-- 4 parts.
function BowlProps.boomBarrel(parent: Instance, cf: CFrame): Model
	local m = newModel("BoomBarrel")
	local red = rgb(C.red)
	local body = post(m, "Body", 4.7, 5.8, cf, red)
	if mesh(m, "RedBarrel", cf, 5.8) then
		body.Transparency = 1 -- the touch box stays; the model is what shows
		m:SetAttribute("Explosive", true)
		return breakable(m, body, parent)
	end
	post(m, "Band", 4.82, 1.3, cf * CFrame.new(0, 2.2, 0), rgb(C.yellow))
	post(m, "Lid", 4.0, 0.14, cf * CFrame.new(0, 5.8, 0), darken(red, 0.55))
	post(m, "Fuse", 0.9, 1.5, cf * CFrame.new(0.9, 5.9, 0), rgb(C.ink))
	m:SetAttribute("Explosive", true)
	return breakable(m, body, parent)
end

-- Two 3.6 stud painted crates, the top one turned a little and off centre, and a white strap
-- round the bottom one. The bottom crate is Body. 3 parts.
function BowlProps.crate(parent: Instance, cf: CFrame, color: Color3): Model
	local m = newModel("Crate")
	local s = 3.6
	if MeshProps.has("Crate") then
		local big = 4.4
		local hit =
			box(m, "Body", Vector3.new(big, big, big), cf * CFrame.new(0, big / 2, 0), color)
		hit.Transparency = 1
		mesh(m, "Crate", cf, big)
		return breakable(m, hit, parent)
	end
	local turn = 0.2 + hash(cf.Position, 2) * 0.4
	local top = cf * CFrame.new(0.3, s, -0.2) * CFrame.Angles(0, turn, 0)
	local body = box(
		m,
		"Body",
		Vector3.new(s, s, s),
		cf * CFrame.new(0, s / 2, 0),
		color,
		Enum.Material.Wood
	)
	box(
		m,
		"Crate",
		Vector3.new(s, s, s),
		top * CFrame.new(0, s / 2, 0),
		darken(color, 0.86),
		Enum.Material.Wood
	)
	box(
		m,
		"Strap",
		Vector3.new(s + 0.12, 0.7, s + 0.12),
		cf * CFrame.new(0, s / 2, 0),
		rgb(C.white)
	)
	return breakable(m, body, parent)
end

-- Traffic cone 3.5 tall: a dark square foot, the orange cone (Body) and a white tip. 3 parts.
function BowlProps.cone(parent: Instance, cf: CFrame): Model
	local m = newModel("Cone")
	local orange = rgb(C.orange)
	box(m, "Foot", Vector3.new(3.2, 0.4, 3.2), cf * CFrame.new(0, 0.2, 0), rgb(C.ink))
	local body = post(m, "Body", 2.5, 2.4, cf, orange)
	post(m, "Tip", 1.5, 1.2, cf * CFrame.new(0, 2.4, 0), rgb(C.white))
	return breakable(m, body, parent)
end

-- Road sign on a 14 stud post (the post is Body). The face looks along -Z. Kinds: "arrow"
-- (yellow board, black arrow pointing +X), "stop" (red board with STOP), "diner" (teal board with
-- DINER), "smash" (orange board with SMASH!). Anything else = arrow. At most 4 parts.
function BowlProps.sign(parent: Instance, cf: CFrame, kind: string): Model
	local m = newModel("RoadSign")
	local body = box(m, "Body", Vector3.new(0.9, 14, 0.9), cf * CFrame.new(0, 7, 0), rgb(C.metal))
	local at = cf * CFrame.new(0, 11, -0.75) -- the middle of the sign face, just in front of the post
	if kind == "stop" then
		box(m, "Rim", Vector3.new(7, 7, 0.3), at * CFrame.new(0, 0, 0.2), rgb(C.white))
		local board = box(m, "Board", Vector3.new(6.2, 6.2, 0.5), at, rgb(C.red))
		label(board, "STOP", rgb(C.white), darken(rgb(C.red), 0.6), Enum.NormalId.Front)
		label(board, "STOP", rgb(C.white), darken(rgb(C.red), 0.6), Enum.NormalId.Back)
	elseif kind == "diner" then
		local board = box(m, "Board", Vector3.new(9, 3.6, 0.5), at, rgb(C.teal))
		label(board, "DINER", rgb(C.yellow), rgb(C.ink), Enum.NormalId.Front)
		label(board, "DINER", rgb(C.yellow), rgb(C.ink), Enum.NormalId.Back)
	elseif kind == "smash" then
		local board = box(m, "Board", Vector3.new(9, 4.4, 0.5), at, rgb(C.orange))
		label(board, "SMASH!", rgb(C.white), rgb(C.blue), Enum.NormalId.Front)
		label(board, "SMASH!", rgb(C.white), rgb(C.blue), Enum.NormalId.Back)
	else
		box(m, "Board", Vector3.new(8, 4.4, 0.5), at, rgb(C.yellow))
		local face = at * CFrame.new(0, 0, -0.3)
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

-- Painted yard fence `length` long along local X, 4.5 tall: a white board between two posts, a
-- coloured top rail and a low rail along the foot. The low rail is Body (the touch trigger), so a
-- car hitting any part breaks the whole section. 5 parts.
function BowlProps.fence(parent: Instance, cf: CFrame, length: number, color: Color3): Model
	local m = newModel("Fence")
	local len = math.max(length, 2)
	local body = box(m, "Body", Vector3.new(len, 0.8, 0.6), cf * CFrame.new(0, 0.9, 0), color)
	for _, s in { -1, 1 } do
		box(
			m,
			"Post",
			Vector3.new(1.2, 4.5, 1.2),
			cf * CFrame.new(s * (len / 2 - 0.6), 2.25, 0),
			rgb(C.white)
		)
	end
	box(
		m,
		"Board",
		Vector3.new(len - 2.4, 2.1, 0.4),
		cf * CFrame.new(0, 2.35, 0),
		rgb(C.white),
		Enum.Material.Wood
	)
	box(m, "Rail", Vector3.new(len, 0.7, 0.6), cf * CFrame.new(0, 3.75, 0), color)
	return breakable(m, body, parent)
end

-- A tree, looks only. "round": a trunk and two puffy leaf balls (about 18 tall at scale 1).
-- "pine": a trunk, two stacked green cans and a ball on top (about 17 tall).
function BowlProps.tree(parent: Instance, cf: CFrame, kind: string, scale: number?): Model
	local m = newModel("Tree")
	local k = scale or 1
	local function at(x: number, y: number, z: number): Vector3
		return (cf * CFrame.new(x * k, y * k, z * k)).Position
	end
	local body: Part
	if kind == "pine" then
		body = post(m, "Body", 2.2 * k, 5 * k, cf, rgb(C.trunk), Enum.Material.Wood)
		for i = 0, 1 do
			post(
				m,
				"Pine",
				(11 - i * 4) * k,
				6 * k,
				cf * CFrame.new(0, (3.5 + i * 5) * k, 0),
				rgb(if i % 2 == 0 then C.pine else C.pineLight)
			)
		end
		sphere(m, "Tip", 2.6 * k, at(0, 16.5, 0), rgb(C.pineLight))
	else
		body = post(m, "Body", 2.8 * k, 8 * k, cf, rgb(C.trunk), Enum.Material.Wood)
		sphere(m, "Leaves", 13 * k, at(0, 12, 0), rgb(C.leaf))
		sphere(m, "Puff", 8 * k, at(2.5, 15.5, 1), rgb(C.leafLight))
	end
	return finish(m, body, parent)
end

-- A soft grass mound `radius` across its foot and `height` tall: the top cap of one big ball
-- sunk in the ground (Body), plus a smaller lighter bump on its side. Looks only.
function BowlProps.hill(parent: Instance, cf: CFrame, radius: number, height: number): Model
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
	return finish(m, body, parent)
end

-- A shipping container 28 long (local X), 8 wide and 8.5 tall in a bright colour, with a darker
-- door end. Looks only. 2 parts.
function BowlProps.container(parent: Instance, cf: CFrame, color: Color3): Model
	local model = MeshProps.place("Container", parent, cf, 8.5)
	if model then
		return model
	end
	local m = newModel("Container")
	local body = box(m, "Body", Vector3.new(28, 8.5, 8), cf * CFrame.new(0, 4.25, 0), color)
	box(m, "Door", Vector3.new(0.5, 7.4, 7.4), cf * CFrame.new(14.1, 4.25, 0), darken(color, 0.7))
	return finish(m, body, parent)
end

return BowlProps
