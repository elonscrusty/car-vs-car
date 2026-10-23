--!strict
-- The upgrades garage on the lobby plaza (looks only, no upgrades yet): an open-front dark
-- garage with a thick orange frame, a car lift with a car on it, a workbench, a tool board on
-- the back wall, a tool chest and tire stacks. Low-poly flat colours, no text.
--
-- Garage-local space: (0, 0, 0) is the middle of the floor at street height. +Z is the open
-- front (where people walk in), -Z is the back wall. Studs. Garage.build() takes a CFrame whose
-- LookVector points out of the open front, and turns it round to this.
-- Garage.parts() is plain numbers (Lune tests load it); Garage.build() makes the parts.
-- Each prop is its own Model (Lift, Workbench, ToolBoard, ToolChest, Tires...) so a Meshy model
-- can replace it by name later.

export type V3 = { x: number, y: number, z: number }
export type Piece = {
	group: string, -- the Model it goes in ("Shell", "Lift", ...)
	name: string,
	shape: string, -- "Block" or "Cylinder" (a Roblox cylinder lies along its x)
	size: V3,
	pos: V3, -- centre, garage-local
	rot: V3, -- degrees
	color: { number }, -- r, g, b
	material: string, -- Enum.Material name
	collide: boolean,
	light: number?, -- PointLight range, for lamps
}

local Garage = {}

Garage.WIDTH = 24 -- x, wall to wall
Garage.DEPTH = 16 -- z, back wall to the open front
Garage.HEIGHT = 9 -- floor to the underside of the roof
Garage.FLOOR = 0.3 -- floor top (a small step up from the plaza)
-- Everything (with the tires and bushes outside) fits in this box, garage-local.
Garage.BOX = { minX = -14, maxX = 16, minZ = -8.5, maxZ = 9.5, maxY = 11 }
-- Walking lane from the front to the middle of the floor: nothing solid stands here.
Garage.LANE = { minX = 2, maxX = 8, minZ = -3, maxZ = 8 }

local C = {
	shell = { 52, 54, 60 },
	roof = { 40, 42, 48 },
	rib = { 66, 68, 76 },
	orange = { 255, 128, 32 },
	cyan = { 70, 200, 255 },
	floor = { 128, 130, 136 },
	paint = { 255, 205, 40 },
	steel = { 150, 156, 166 },
	dark = { 60, 62, 68 },
	tire = { 28, 28, 30 },
	rim = { 120, 124, 132 },
	wood = { 168, 116, 72 },
	board = { 196, 198, 204 },
	chest = { 205, 52, 44 },
	car = { 255, 200, 30 },
	glass = { 40, 50, 66 },
	light = { 255, 250, 230 },
	planter = { 110, 112, 118 },
	bush = { 92, 172, 72 },
}

local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

function Garage.parts(): { Piece }
	local out: { Piece } = {}
	local function add(
		group: string,
		name: string,
		size: V3,
		pos: V3,
		color: { number },
		opts: {
			shape: string?,
			rot: V3?,
			material: string?,
			collide: boolean?,
			light: number?,
		}?
	)
		local o = opts or {}
		table.insert(out, {
			group = group,
			name = name,
			shape = o.shape or "Block",
			size = size,
			pos = pos,
			rot = o.rot or v(0, 0, 0),
			color = color,
			material = o.material or "SmoothPlastic",
			collide = if o.collide == nil then true else o.collide,
			light = o.light,
		})
	end

	local W, D, H, F = Garage.WIDTH, Garage.DEPTH, Garage.HEIGHT, Garage.FLOOR
	local front = D / 2

	-- ===== Shell: floor, three walls, roof with ribs, thick orange frame round the opening =====
	add("Shell", "Floor", v(W, F, D), v(0, F / 2, 0), C.floor, { material = "Concrete" })
	add("Shell", "BackWall", v(W, H, 1), v(0, H / 2, -front + 0.5), C.shell)
	add("Shell", "LeftWall", v(1, H, D), v(-W / 2 + 0.5, H / 2, 0), C.shell)
	add("Shell", "RightWall", v(1, H, D), v(W / 2 - 0.5, H / 2, 0), C.shell)
	add("Shell", "Roof", v(W + 1, 1, D + 1.5), v(0, H + 0.5, 0.25), C.roof)
	for i = -1, 1 do
		add(
			"Shell",
			"RoofRib",
			v(W - 2, 0.5, 1.2),
			v(0, H + 1.25, i * 5),
			C.rib,
			{ collide = false }
		)
	end
	-- the frame: two fat posts and a fat beam, sticking out past the walls and roof
	add(
		"Shell",
		"FramePostL",
		v(2.2, H + 1, 1.8),
		v(-W / 2 + 0.6, (H + 1) / 2, front + 0.3),
		C.orange
	)
	add(
		"Shell",
		"FramePostR",
		v(2.2, H + 1, 1.8),
		v(W / 2 - 0.6, (H + 1) / 2, front + 0.3),
		C.orange
	)
	add("Shell", "FrameBeam", v(W + 3.4, 2.4, 1.8), v(0, H + 0.2, front + 0.3), C.orange)
	-- orange band along the top of each side wall, and a cyan light strip on the left post
	add("Shell", "SideBandL", v(1.3, 1, D - 1), v(-W / 2 + 0.5, H - 0.3, -0.5), C.orange)
	add("Shell", "SideBandR", v(1.3, 1, D - 1), v(W / 2 - 0.5, H - 0.3, -0.5), C.orange)
	add(
		"Shell",
		"CyanStrip",
		v(0.3, H - 1, 0.4),
		v(-W / 2 - 0.6, H / 2, front + 0.3),
		C.cyan,
		{ material = "Neon", collide = false }
	)
	-- ceiling lights
	for i, x in { -6, 6 } do
		add(
			"Shell",
			"CeilingLight" .. i,
			v(6, 0.25, 1),
			v(x, H - 0.15, -1),
			C.light,
			{ material = "Neon", collide = false, light = 22 }
		)
	end

	-- ===== Car lift (left of middle), car up on it =====
	local lx, lz = -4, -1.5
	add("Lift", "FloorPaint", v(10, 0.04, 10.6), v(lx, F + 0.02, lz), C.paint, { collide = false })
	add("Lift", "FloorPaintIn", v(9, 0.05, 9.6), v(lx, F + 0.03, lz), C.floor, {
		material = "Concrete",
		collide = false,
	})
	for _, px in { lx - 4, lx + 4 } do
		for _, pz in { lz - 4.6, lz + 4.6 } do
			add("Lift", "Post", v(0.9, 6.3, 0.9), v(px, F + 3.15, pz), C.orange)
			add("Lift", "Foot", v(1.6, 0.3, 1.6), v(px, F + 0.15, pz), C.dark)
		end
	end
	for _, pz in { lz - 4.6, lz + 4.6 } do
		add("Lift", "TopBeam", v(9, 0.7, 0.9), v(lx, F + 6.6, pz), C.orange)
		add("Lift", "CrossBar", v(8.1, 0.4, 0.7), v(lx, F + 2.6, pz), C.dark)
	end
	local railTop = F + 3
	for _, side in { -1, 1 } do
		add("Lift", "Rail", v(1.2, 0.4, 9.2), v(lx + side * 1.6, railTop - 0.2, lz), C.steel, {
			material = "DiamondPlate",
		})
	end
	-- the car: chunky toy truck, nose to the back wall
	local wr = 0.8
	local wy = railTop + wr
	for _, side in { -1, 1 } do
		for _, wz in { lz - 1.8, lz + 1.8 } do
			add("Lift", "Wheel", v(0.7, wr * 2, wr * 2), v(lx + side * 1.6, wy, wz), C.tire, {
				shape = "Cylinder",
			})
			add("Lift", "Hub", v(0.72, 0.8, 0.8), v(lx + side * 1.61, wy, wz), C.rim, {
				shape = "Cylinder",
				collide = false,
			})
		end
	end
	add("Lift", "CarBody", v(2.8, 1.1, 5.6), v(lx, wy + 0.5, lz), C.car)
	add("Lift", "CarCab", v(2.3, 0.9, 2.4), v(lx, wy + 1.5, lz + 0.5), C.glass, { collide = false })
	add(
		"Lift",
		"CarRoof",
		v(2.5, 0.25, 2.6),
		v(lx, wy + 2.07, lz + 0.5),
		C.car,
		{ collide = false }
	)
	add("Lift", "CarBumper", v(3, 0.4, 0.4), v(lx, wy + 0.2, lz - 2.9), C.dark, { collide = false })

	-- turn the whole lift a quarter round so the car shows its side to the door
	for _, piece in out do
		if piece.group == "Lift" then
			local dx, dz = piece.pos.x - lx, piece.pos.z - lz
			piece.pos = v(lx + dz, piece.pos.y, lz - dx)
			piece.rot = v(piece.rot.x, piece.rot.y + 90, piece.rot.z)
		end
	end

	-- ===== Workbench on the back wall, right side =====
	local bx, bz = 5.5, -front + 2.4
	add("Workbench", "Top", v(8, 0.4, 2.6), v(bx, F + 3.1, bz), C.wood, { material = "WoodPlanks" })
	for _, dx in { -3.7, 3.7 } do
		for _, dz in { -1, 1 } do
			add("Workbench", "Leg", v(0.3, 2.9, 0.3), v(bx + dx, F + 1.45, bz + dz), C.dark)
		end
	end
	add("Workbench", "Shelf", v(7.6, 0.2, 2.3), v(bx, F + 0.8, bz), C.dark, { collide = false })
	add("Workbench", "Drawers", v(2.4, 2, 2.2), v(bx + 2.4, F + 1.9, bz), C.steel)
	for i = 0, 2 do
		add(
			"Workbench",
			"Handle",
			v(1, 0.12, 0.1),
			v(bx + 2.4, F + 1.3 + i * 0.6, bz + 1.15),
			C.orange,
			{ collide = false }
		)
	end
	add(
		"Workbench",
		"Vise",
		v(0.7, 0.6, 0.9),
		v(bx - 3, F + 3.6, bz + 0.6),
		C.dark,
		{ collide = false }
	)
	add("Workbench", "PartsBox", v(1.2, 0.5, 0.8), v(bx + 0.5, F + 3.55, bz - 0.4), C.chest, {
		collide = false,
	})
	add("Workbench", "Lamp", v(0.5, 0.3, 0.5), v(bx + 2.8, F + 3.45, bz - 0.6), C.light, {
		material = "Neon",
		collide = false,
	})
	add("Workbench", "SpareWheel", v(0.4, 1, 1), v(bx - 1.2, F + 3.5, bz + 0.2), C.tire, {
		shape = "Cylinder",
		rot = v(0, 0, 90),
		collide = false,
	})

	-- ===== Tool board on the back wall, above the bench =====
	local tz = -front + 1.1
	add("ToolBoard", "Board", v(8, 3.6, 0.2), v(bx, F + 6.3, tz), C.board, { collide = false })
	for i = 0, 3 do -- spanners, small to big
		local x = bx - 3 + i * 0.9
		local len = 1.2 + i * 0.25
		add(
			"ToolBoard",
			"Spanner",
			v(0.22, len, 0.1),
			v(x, F + 6.3, tz + 0.15),
			C.steel,
			{ collide = false }
		)
		add(
			"ToolBoard",
			"SpannerHead",
			v(0.55, 0.35, 0.1),
			v(x, F + 6.3 + len / 2, tz + 0.15),
			C.steel,
			{ collide = false }
		)
	end
	for i = 0, 2 do -- screwdrivers: orange handle, steel shaft
		local x = bx + 0.9 + i * 0.7
		add(
			"ToolBoard",
			"DriverHandle",
			v(0.3, 0.7, 0.2),
			v(x, F + 7.2, tz + 0.15),
			C.orange,
			{ collide = false }
		)
		add(
			"ToolBoard",
			"DriverShaft",
			v(0.1, 0.9, 0.1),
			v(x, F + 6.4, tz + 0.15),
			C.steel,
			{ collide = false }
		)
	end
	add(
		"ToolBoard",
		"HammerHandle",
		v(0.22, 1.6, 0.12),
		v(bx + 3.1, F + 6, tz + 0.15),
		C.wood,
		{ collide = false }
	)
	add(
		"ToolBoard",
		"HammerHead",
		v(0.9, 0.4, 0.2),
		v(bx + 3.1, F + 6.9, tz + 0.15),
		C.dark,
		{ collide = false }
	)
	add("ToolBoard", "Shelf", v(8, 0.2, 0.7), v(bx, F + 4.6, tz + 0.3), C.dark, { collide = false })
	for i, c in { C.chest, C.cyan, C.orange } do -- paint tins on the little shelf
		add(
			"ToolBoard",
			"Tin",
			v(0.5, 0.6, 0.5),
			v(bx - 3 + i * 1.1, F + 5, tz + 0.3),
			c,
			{ collide = false }
		)
	end

	-- ===== Tool chest on wheels against the right wall =====
	local cx, cz = W / 2 - 2.1, -0.5
	add("ToolChest", "Body", v(2, 4, 3), v(cx, F + 2.4, cz), C.chest)
	add("ToolChest", "Lid", v(2.1, 0.25, 3.1), v(cx, F + 4.5, cz), C.dark, { collide = false })
	for i = 0, 4 do
		add(
			"ToolChest",
			"Drawer",
			v(0.08, 0.1, 2.6),
			v(cx - 1.02, F + 1.2 + i * 0.7, cz),
			C.dark,
			{ collide = false }
		)
	end
	for _, dz in { -1.2, 1.2 } do
		add(
			"ToolChest",
			"Caster",
			v(0.4, 0.4, 0.4),
			v(cx, F + 0.2, cz + dz),
			C.tire,
			{ collide = false }
		)
	end

	-- ===== Tire stacks: one inside front right, two outside the left post =====
	local function tires(name: string, x: number, z: number, count: number)
		for i = 1, count do
			local y = F + 0.45 + (i - 1) * 0.9
			add(name, "Tire", v(0.9, 2.4, 2.4), v(x, y, z), C.tire, {
				shape = "Cylinder",
				rot = v(0, 0, 90),
			})
		end
		add(name, "Rim", v(0.05, 1.2, 1.2), v(x, F + count * 0.9 + 0.02, z), C.rim, {
			shape = "Cylinder",
			rot = v(0, 0, 90),
			collide = false,
		})
	end
	tires("TiresIn", W / 2 - 2.2, 4.8, 4)
	tires("TiresOut1", W / 2 + 2.4, 5.4, 4)
	tires("TiresOut2", W / 2 + 2.6, 2.6, 3)

	-- ===== Bush box beside the right post =====
	add("Bushes", "Planter", v(1.8, 1.2, 2.4), v(W / 2 + 2.4, 0.6, front - 0.4), C.planter)
	add(
		"Bushes",
		"Bush",
		v(1.7, 1.6, 2.2),
		v(W / 2 + 2.4, 2, front - 0.4),
		C.bush,
		{ material = "Grass" }
	)

	return out
end

-- Builds the garage under `parent`. `at` is the middle of the floor at plaza height, its
-- LookVector pointing out of the open front. Returns the Model "UpgradesGarage".
function Garage.build(parent: Instance, at: CFrame, _width: number?, _depth: number?): Model
	local origin = at * CFrame.Angles(0, math.pi, 0) -- garage-local +Z = the LookVector
	local model = Instance.new("Model")
	model.Name = "UpgradesGarage"
	local groups: { [string]: Model } = {}
	for _, p in Garage.parts() do
		local group = groups[p.group]
		if not group then
			group = Instance.new("Model")
			group.Name = p.group
			group.Parent = model
			groups[p.group] = group
		end
		local part = Instance.new("Part")
		part.Name = p.name
		part.Shape = (Enum.PartType :: any)[p.shape]
		part.Anchored = true
		part.CanCollide = p.collide
		part.CanTouch = false
		part.CastShadow = p.collide
		part.Size = Vector3.new(p.size.x, p.size.y, p.size.z)
		part.CFrame = origin
			* CFrame.new(p.pos.x, p.pos.y, p.pos.z)
			* CFrame.Angles(math.rad(p.rot.x), math.rad(p.rot.y), math.rad(p.rot.z))
		part.Color = Color3.fromRGB(p.color[1], p.color[2], p.color[3])
		part.Material = (Enum.Material :: any)[p.material]
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if p.light then
			local light = Instance.new("PointLight")
			light.Range = p.light
			light.Brightness = 1.2
			light.Color = part.Color
			light.Parent = part
		end
		part.Parent = group
	end
	model.PrimaryPart = (groups.Shell :: Model):FindFirstChild("Floor") :: BasePart
	model.Parent = parent
	return model
end

return Garage
