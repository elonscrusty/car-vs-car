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
	face: boolean?, -- a Roblox smiley on its front (-Z) face: the toy kart driver's head
	mesh: string?, -- a SpecialMesh of this Enum.MeshType name on it ("Head": the classic round head)
	alpha: number?, -- Transparency (0..1), for light columns and glows
}

-- Loader: Roblox uses script.Parent, plain Lune (tests) uses relative paths.
local function sibling(name: string): any
	if script then
		return require((script :: any).Parent[name])
	end
	local luneRequire: any = require
	return luneRequire("./" .. name)
end

local CarCatalog = sibling("CarCatalog")
local ToyCars = sibling("ToyCars")
local Crates = sibling("Crates")

local Garage = {}

Garage.WIDTH = 24 -- x, wall to wall
Garage.DEPTH = 16 -- z, back wall to the open front
Garage.HEIGHT = 9 -- floor to the underside of the roof
Garage.FLOOR = 0.3 -- floor top (a small step up from the plaza)
-- Everything (with the tires and bushes outside) fits in this box, garage-local.
Garage.BOX = { minX = -14, maxX = 16, minZ = -8.5, maxZ = 9.5, maxY = 11 }
-- Walking lane from the front to the middle of the floor: nothing solid stands here.
Garage.LANE = { minX = 2, maxX = 8, minZ = -3, maxZ = 8 }
-- x of the shop's three turntables (z = 1.5). Close together: the CarShop mesh's front posts
-- hid cars at ±7 from the front (Studio 10-26).
Garage.SHOP_STANDS = { -5.6, 0, 5.6 }
-- The spawn lobby's three car shops: the building's trim colour, and the cars on show (from
-- CarCatalog, in shop order: colour, Garage.toyCar style, name, price in coins, id).
local SHOP_TRIM = { drift = { 150, 70, 210 }, race = { 226, 52, 46 }, rock = { 70, 176, 64 } }
-- Car VS Car's crate shop (carter's yes 10-26, rc-game/cvc/pics/crate-shop-top-down.png): the same
-- building with an orange trim and one crate per turntable, Crates.SHOP in order, each painted
-- the colour of the best kind of car it can give.
Garage.CRATE_TRIM = { 255, 140, 40 }
Garage.CRATE_SIZE = 2.6
Garage.CRATE_COLORS = {
	basic = { 61, 155, 255 },
	big = { 170, 80, 255 },
	mega = { 255, 199, 44 },
} :: { [string]: { number } }
Garage.SHOPS = {} :: {
	[string]: {
		color: { number },
		cars: { { number } },
		style: string,
		styles: { string }, -- each car's own look (ToyCars), same order as cars
		names: { string },
		prices: { number },
		ids: { string },
		display: { number }, -- which cars stand on the turntables (indexes into the lists)
	},
}
for kind, list in CarCatalog.SHOP do
	local shop = {
		color = SHOP_TRIM[kind],
		cars = {},
		style = kind,
		styles = {},
		names = {},
		prices = {},
		ids = {},
		display = {},
	}
	for _, car in list do
		table.insert(shop.cars, car.color)
		table.insert(shop.styles, car.style)
		table.insert(shop.names, car.name)
		table.insert(shop.prices, car.price)
		table.insert(shop.ids, car.id)
	end
	-- on show: the cheapest of each kind (common, rare, epic...), so the glows show from the
	-- street; then the cheapest left over if there are stands to spare. Cheapest first.
	local taken: { [number]: boolean } = {}
	for _, r in CarCatalog.RARITY_ORDER do
		for i, car in list do
			if #shop.display < #Garage.SHOP_STANDS and car.rarity == r then
				table.insert(shop.display, i)
				taken[i] = true
				break
			end
		end
	end
	for i in list do
		if #shop.display < #Garage.SHOP_STANDS and not taken[i] then
			table.insert(shop.display, i)
		end
	end
	table.sort(shop.display)
	Garage.SHOPS[kind] = shop
end

local C = {
	shell = { 52, 54, 60 },
	roof = { 40, 42, 48 },
	rib = { 66, 68, 76 },
	orange = { 228, 98, 22 },
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
	gold = { 255, 196, 40 },
	planter = { 110, 112, 118 },
	bush = { 92, 172, 72 },
	blue = { 38, 104, 214 },
	white = { 238, 238, 242 },
}
Garage.COLORS = C

local function v(x: number, y: number, z: number): V3
	return { x = x, y = y, z = z }
end

-- carter's Meshy props. When ServerStorage.LobbyMeshes has a model with this name, it is
-- fitted into `fit` (studs, garage-local x/y/z, kept in proportion), stood on the floor at `at`,
-- turned so its long side runs along `long` ("x" or "z"), and the block stand-ins of `group` are
-- removed, all but the `keep` ones. `onTop` stands it on another prop instead of the floor.
-- No model, no change: the block stand-ins stay. Group "Extras" has no stand-ins: those props
-- only show up once imported.
export type Mesh = {
	model: string,
	group: string,
	at: V3,
	fit: V3,
	long: string,
	keep: { string },
	hide: { string }?, -- of the kept ones: still there (a collider, a tag, a prompt), not seen
	onTop: string?,
	faceMinusX: boolean?, -- when turned, look toward -x (default +x)
	yaw: number?, -- extra turn about y, degrees (a model that came in facing the wrong way)
	carSkin: boolean?, -- take it from ReplicatedStorage.CarSkins instead of LobbyMeshes
	flat: number?, -- squash it to this height (studs) after fitting: a puddle or pad on a road
	collide: boolean,
}

Garage.LIFT = { x = -4, z = -1.5 }
Garage.BENCH = { x = 5.5, z = -Garage.DEPTH / 2 + 2.4 }

Garage.MESHES = {
	{
		model = "CarLift",
		group = "Lift",
		at = v(Garage.LIFT.x, Garage.FLOOR, Garage.LIFT.z),
		fit = v(9.6, 6.6, 3.6),
		long = "x", -- posts at the car's two ends, so the car shows whole from the door
		keep = {
			"CarBody",
			"CarCab",
			"CarRoof",
			"CarBumper",
			"Wheel",
			"Hub",
			"FloorPaint",
			"FloorPaintIn",
		},
		collide = true,
	},
	{
		model = "Workbench",
		group = "Workbench",
		at = v(Garage.BENCH.x, Garage.FLOOR, Garage.BENCH.z),
		fit = v(8, 3.4, 2.8),
		long = "x",
		yaw = 180, -- its drawers are on its -Z side: turn them out of the back wall, to the door
		keep = {},
		collide = true,
	},
	{
		model = "Toolbox",
		group = "Workbench",
		at = v(Garage.BENCH.x + 1.6, Garage.FLOOR + 3.3, Garage.BENCH.z), -- y: block bench top
		fit = v(1.8, 1.2, 1),
		yaw = 180, -- latch to the door, like the bench
		long = "x",
		keep = { "Top", "Leg", "Shelf", "Drawers", "Handle" }, -- only the small bits on top go
		onTop = "Workbench",
		collide = false,
	},
	{
		model = "TireStack",
		group = "TiresIn",
		at = v(Garage.WIDTH / 2 - 2.2, Garage.FLOOR, 4.8),
		fit = v(2.6, 3.4, 2.6),
		long = "x",
		keep = {},
		collide = true,
	},
	{
		model = "TireStack",
		group = "TiresOut1",
		at = v(Garage.WIDTH / 2 + 2.4, 0, 5.4),
		fit = v(2.6, 3.4, 2.6),
		long = "x",
		keep = {},
		collide = true,
	},
	{
		model = "TireStack",
		group = "TiresOut2",
		at = v(Garage.WIDTH / 2 + 2.6, 0, 2.6),
		fit = v(2.6, 2.6, 2.6),
		long = "x",
		keep = {},
		collide = true,
	},
	{
		model = "GasPump",
		group = "GasPump",
		at = v(-Garage.WIDTH / 2 + 2.6, Garage.FLOOR, Garage.DEPTH / 2 - 2.4),
		fit = v(2.4, 4.4, 1.8),
		long = "x",
		keep = {},
		collide = true,
	},
	{
		model = "TrophyShelf", -- up on the left wall, over the lift, looking into the garage
		group = "TrophyShelf",
		at = v(-Garage.WIDTH / 2 + 1.6, Garage.FLOOR + 4.2, -2.5),
		fit = v(2, 4.2, 7),
		long = "z",
		keep = {},
		collide = false,
	},
	-- extras: Meshy only, no block stand-ins
	{
		model = "WheelRack", -- back right corner, against the right wall
		faceMinusX = true,
		group = "Extras",
		at = v(Garage.WIDTH / 2 - 1.6, Garage.FLOOR, -4.7),
		fit = v(1.6, 3.4, 3.6),
		long = "z",
		keep = {},
		collide = true,
	},
	{
		model = "Barrel", -- front left, between the lift and the gas pump
		group = "Extras",
		at = v(-Garage.WIDTH / 2 + 1.8, Garage.FLOOR, 2.2),
		fit = v(1.5, 2.1, 1.5),
		long = "x",
		keep = {},
		collide = true,
	},
	{
		model = "GasCan", -- on the floor beside the gas pump
		group = "Extras",
		at = v(-Garage.WIDTH / 2 + 4.6, Garage.FLOOR, Garage.DEPTH / 2 - 1.8),
		fit = v(1, 1.1, 0.6),
		long = "x",
		keep = {},
		collide = false,
	},
	{
		model = "FloorJack", -- by the lift, handle toward the door
		group = "Extras",
		at = v(0.6, Garage.FLOOR, 5.2),
		fit = v(1, 1, 2.2),
		long = "z",
		keep = {},
		collide = false,
	},
	{
		model = "OilCan", -- on the bench, left end
		group = "Extras",
		at = v(Garage.BENCH.x - 2.6, Garage.FLOOR + 3.3, Garage.BENCH.z + 0.3),
		fit = v(0.8, 0.9, 0.5),
		long = "x",
		keep = {},
		onTop = "Workbench",
		collide = false,
	},
	{
		model = "Crate", -- outside, behind the tire stacks
		group = "Extras",
		at = v(Garage.WIDTH / 2 + 2.5, 0, -0.6),
		fit = v(2.2, 2.2, 2.2),
		long = "x",
		keep = {},
		collide = true,
	},
} :: { Mesh }

-- Meshy props for a car shop: a turntable per stand. (The cars stay toy cars so each shows its
-- own colour.)
function Garage.shopMeshes(_kind: string): { Mesh }
	local out: { Mesh } = {}
	local W, D, H, F = Garage.WIDTH, Garage.DEPTH, Garage.HEIGHT, Garage.FLOOR
	-- carter's CarShop (batch 6, open front at its -Z) over the block shell. The floor, walls and
	-- roof stay as hidden colliders (the mesh doesn't collide); the ceiling lights stay lit.
	table.insert(out, {
		model = "CarShop",
		group = "Shell",
		at = v(0, 0, 0.25),
		fit = v(W + 1, H + 1, D + 1.5),
		long = "x",
		yaw = 180, -- its open front to the garage-local +Z (the door side)
		keep = {
			"Floor",
			"BackWall",
			"LeftWall",
			"RightWall",
			"Roof",
			"CeilingLight1",
			"CeilingLight2",
		},
		hide = { "Floor", "BackWall", "LeftWall", "RightWall", "Roof" },
		collide = false,
	})
	-- carter's ShopCounter (drawer at its -Z: the staff side, toward the back wall) over the desk;
	-- the desk keeps the shop's prompt and the top its trim colour (CarShops, PadWords)
	table.insert(out, {
		model = "ShopCounter",
		group = "Counter",
		at = v(0, F, -D / 2 + 2.4),
		fit = v(8.4, 3.3, 2.2),
		long = "x",
		keep = { "Desk", "Top", "Stripe" },
		hide = { "Desk", "Top" },
		collide = true,
	})
	for i, x in Garage.SHOP_STANDS do
		table.insert(out, {
			model = "Turntable",
			group = "Stand" .. i,
			at = v(x, Garage.FLOOR, 1.5),
			fit = v(4.8, 0.7, 4.8),
			long = "x",
			keep = { "Ring" },
			collide = true,
		})
	end
	return out
end

export type Opts = {
	shape: string?,
	rot: V3?,
	material: string?,
	collide: boolean?,
	light: number?,
	face: boolean?,
	mesh: string?,
	alpha: number?,
}
export type Add = (
	group: string,
	name: string,
	size: V3,
	pos: V3,
	color: { number },
	opts: Opts?
) -> ()

-- A function that appends pieces to `out` (used by the garage, the shop and the spawn lobby).
function Garage.adder(out: { Piece }): Add
	return function(group: string, name: string, size: V3, pos: V3, color: { number }, opts: Opts?)
		local o: Opts = opts or {}
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
			face = o.face,
			mesh = o.mesh,
			alpha = o.alpha,
		})
	end
end

-- A chunky toy car, `s` times the size of a 3.6-stud one, standing with its bottom middle on
-- `at`, nose toward -Z turned by `yaw` degrees. Looks only (not solid).
-- style: a ToyCars look ("buggy/dark", "truck/purple/glow", ...; the old "race", "drift" and
-- "rock" still work), each car's own from CarCatalog.
-- The toy car's body is 3.6 long at s = 1: the s that makes it `length` long (a race car's toy
-- look is sized to the grey body it covers, so the chase camera sees the same size car; sized by
-- its wheels it came out a third bigger and filled the screen, Studio pr816 04b).
Garage.TOY_LENGTH = 3.6
function Garage.toyFit(length: number): number
	return length / Garage.TOY_LENGTH
end

function Garage.toyCar(
	add: Add,
	group: string,
	at: V3,
	yaw: number,
	color: { number },
	s: number,
	style: string?
)
	local spec = ToyCars.wheels(style)
	local wd, ww = spec.wd, spec.ww
	local r = math.rad(yaw)
	local c, sn = math.cos(r), math.sin(r)
	local function put(
		name: string,
		size: V3,
		x: number,
		y: number,
		z: number,
		col: { number },
		o: ToyCars.Opts?
	)
		local opts: Opts = {
			shape = o and o.shape,
			material = o and o.material,
			face = o and o.face,
			mesh = o and o.mesh,
		}
		local rot = o and o.rot or v(0, 0, 0)
		opts.rot = v(rot.x, rot.y + yaw, rot.z)
		opts.collide = false
		add(
			group,
			name,
			v(size.x * s, size.y * s, size.z * s),
			v(at.x + (c * x + sn * z) * s, at.y + y * s, at.z + (-sn * x + c * z) * s),
			col,
			opts
		)
	end
	local wx = 1 + ww / 2
	for _, wz in { -ToyCars.WHEEL_Z, ToyCars.WHEEL_Z } do
		for _, sx in { -wx, wx } do
			put("Wheel", v(ww, wd, wd), sx, wd / 2, wz, C.tire, { shape = "Cylinder" })
		end
		-- one hub bar through the axle shows as both wheels' rims (hidden in the body between)
		local hub = 0.62 * wd -- (a big rim, like carter's picture: not a bare tyre)
		put(
			"Hub",
			v(2 * wx + ww + 0.02, hub, hub),
			0,
			wd / 2,
			wz,
			ToyCars.rim(style, color),
			{ shape = "Cylinder" }
		)
	end
	ToyCars.body(put, color, style)
end

-- kind: "garage" (default, the upgrades garage), or a car shop "drift" / "race" / "rock" (the
-- same building with a frame in that shop's colour, three of its cars on turntables, a counter).
function Garage.parts(kind: string?): { Piece }
	local out: { Piece } = {}
	local add = Garage.adder(out)
	local shop = if kind then Garage.SHOPS[kind] else nil
	local crates = kind == "crates"

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
	local lx, lz = Garage.LIFT.x, Garage.LIFT.z
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
		for _, wz in { lz - 1.45, lz + 1.45 } do
			add("Lift", "Wheel", v(0.7, wr * 2, wr * 2), v(lx + side * 1.6, wy, wz), C.tire, {
				shape = "Cylinder",
			})
			add("Lift", "Hub", v(0.72, 0.8, 0.8), v(lx + side * 1.61, wy, wz), C.rim, {
				shape = "Cylinder",
				collide = false,
			})
		end
	end
	add("Lift", "CarBody", v(2.8, 1.1, 4.6), v(lx, wy + 0.5, lz), C.car)
	add("Lift", "CarCab", v(2.3, 0.9, 2.4), v(lx, wy + 1.5, lz + 0.5), C.glass, { collide = false })
	add(
		"Lift",
		"CarRoof",
		v(2.5, 0.25, 2.6),
		v(lx, wy + 2.07, lz + 0.5),
		C.car,
		{ collide = false }
	)
	add("Lift", "CarBumper", v(3, 0.4, 0.4), v(lx, wy + 0.2, lz - 2.4), C.dark, { collide = false })

	-- turn the whole lift a quarter round so the car shows its side to the door
	for _, piece in out do
		if piece.group == "Lift" then
			local dx, dz = piece.pos.x - lx, piece.pos.z - lz
			piece.pos = v(lx + dz, piece.pos.y, lz - dx)
			piece.rot = v(piece.rot.x, piece.rot.y + 90, piece.rot.z)
		end
	end

	-- ===== Workbench on the back wall, right side =====
	local bx, bz = Garage.BENCH.x, Garage.BENCH.z
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
	tires("TiresOut2", W / 2 + 2.6, 2.6, 3) -- keep these three spots in step with Garage.MESHES

	-- ===== Gas pump in the front left corner, facing the door =====
	local gx, gz = -W / 2 + 2.6, front - 2.4
	add("GasPump", "Base", v(2.4, 0.3, 1.8), v(gx, F + 0.15, gz), C.dark)
	add("GasPump", "Body", v(1.8, 3.6, 1.2), v(gx, F + 2.1, gz), C.chest)
	add("GasPump", "Top", v(2, 0.5, 1.4), v(gx, F + 4.15, gz), C.orange)
	add(
		"GasPump",
		"Screen",
		v(1.2, 0.8, 0.08),
		v(gx, F + 3.2, gz + 0.62),
		C.glass,
		{ collide = false }
	)
	add("GasPump", "Stripe", v(1.82, 0.25, 1.22), v(gx, F + 1.6, gz), C.light, { collide = false })
	add(
		"GasPump",
		"Holster",
		v(0.4, 0.6, 0.3),
		v(gx + 0.95, F + 2.4, gz + 0.2),
		C.dark,
		{ collide = false }
	)
	add(
		"GasPump",
		"Nozzle",
		v(0.25, 0.8, 0.25),
		v(gx + 1.05, F + 2.5, gz + 0.45),
		C.steel,
		{ collide = false }
	)
	add(
		"GasPump",
		"Hose",
		v(0.15, 1.8, 0.15),
		v(gx + 1.2, F + 1.7, gz + 0.45),
		C.tire,
		{ collide = false }
	)

	-- ===== Trophy shelf on the left wall, up high over the lift =====
	local sx, sz = -W / 2 + 1.4, -2.5
	add("TrophyShelf", "Back", v(0.2, 4, 7), v(sx - 0.3, F + 6.2, sz), C.wood, { collide = false })
	for i, y in { 4.6, 6.3, 8 } do
		add("TrophyShelf", "Shelf" .. i, v(1, 0.2, 7), v(sx + 0.2, F + y - 0.1, sz), C.wood, {
			material = "WoodPlanks",
			collide = false,
		})
		for j = -1, 1 do -- three gold cups on a shelf, the middle one biggest
			local h = if j == 0 then 1.1 else 0.8
			local tz = sz + j * 2.2
			add(
				"TrophyShelf",
				"CupBase",
				v(0.6, 0.25, 0.6),
				v(sx + 0.25, F + y + 0.12, tz),
				C.dark,
				{
					collide = false,
				}
			)
			add(
				"TrophyShelf",
				"CupStem",
				v(0.15, h * 0.4, 0.15),
				v(sx + 0.25, F + y + 0.25 + h * 0.2, tz),
				C.gold,
				{
					material = "Foil",
					collide = false,
				}
			)
			add(
				"TrophyShelf",
				"Cup",
				v(h * 0.6, h * 0.6, h * 0.6),
				v(sx + 0.25, F + y + 0.25 + h * 0.4 + h * 0.3, tz),
				C.gold,
				{ shape = "Cylinder", rot = v(0, 0, 90), material = "Foil", collide = false }
			)
		end
	end

	-- ===== Upgrade pad: a glowing square on the floor in the walk-in lane (looks only) =====
	local ux, uz = 5, 2
	add(
		"UpgradePad",
		"Rim",
		v(5.4, 0.06, 5.4),
		v(ux, F + 0.03, uz),
		C.orange,
		{ material = "Neon", collide = false }
	)
	add("UpgradePad", "Pad", v(4.6, 0.08, 4.6), v(ux, F + 0.04, uz), C.dark, { collide = false })
	add("UpgradePad", "Glow", v(3.4, 0.1, 3.4), v(ux, F + 0.05, uz), C.cyan, {
		material = "Neon",
		collide = false,
		light = 10,
	})
	add("UpgradePad", "Center", v(2.2, 0.12, 2.2), v(ux, F + 0.06, uz), C.dark, { collide = false })
	-- an up arrow (no words): a wedge of two bars and a stem, pointing into the garage
	add("UpgradePad", "ArrowStem", v(0.5, 0.14, 1.4), v(ux, F + 0.07, uz + 0.3), C.cyan, {
		material = "Neon",
		collide = false,
	})
	for _, side in { -1, 1 } do
		add(
			"UpgradePad",
			"ArrowHead",
			v(0.45, 0.14, 1.1),
			v(ux + side * 0.3, F + 0.07, uz - 0.55),
			C.cyan,
			{
				material = "Neon",
				collide = false,
				rot = v(0, side * 45, 0),
			}
		)
	end

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

	if shop or crates then
		-- keep only the building, turn the orange trim the shop's colour, then fill it like a showroom
		local trim = if shop then shop.color else Garage.CRATE_TRIM
		local shell: { Piece } = {}
		for _, piece in out do
			if piece.group == "Shell" then
				if piece.color == C.orange then
					piece.color = trim
				end
				table.insert(shell, piece)
			end
		end
		out = shell
		add = Garage.adder(out)
		add("Counter", "Desk", v(8, 3, 1.8), v(0, F + 1.5, -front + 2.4), C.white)
		add("Counter", "Top", v(8.4, 0.3, 2.2), v(0, F + 3.15, -front + 2.4), trim)
		add("Counter", "Stripe", v(0.1, 0.4, 8), v(-W / 2 + 1.05, F + 6, -0.5), trim, {
			material = "Neon",
			collide = false,
		})
		add("Counter", "Stripe", v(0.1, 0.4, 8), v(W / 2 - 1.05, F + 6, -0.5), trim, {
			material = "Neon",
			collide = false,
		})
		for i, x in Garage.SHOP_STANDS do
			local g = "Stand" .. i
			add(g, "Ring", v(0.08, 5.2, 5.2), v(x, F + 0.04, 1.5), C.cyan, {
				shape = "Cylinder",
				rot = v(0, 0, 90),
				material = "Neon",
				collide = false,
			})
			add(
				g,
				"Plinth",
				v(0.6, 4.8, 4.8),
				v(x, F + 0.3, 1.5),
				C.dark,
				{ shape = "Cylinder", rot = v(0, 0, 90) }
			)
			add(g, "Top", v(0.15, 4.4, 4.4), v(x, F + 0.67, 1.5), C.board, {
				shape = "Cylinder",
				rot = v(0, 0, 90),
				collide = false,
			})
			if shop then
				Garage.toyCar(
					add,
					"Car" .. i,
					v(x, F + 0.75, 1.5),
					-30 + (i - 1) * 30,
					shop.cars[shop.display[i]],
					1,
					shop.styles[shop.display[i]]
				)
			else
				Garage.crate(add, "Crate" .. i, v(x, F + 0.75, 1.5), Crates.SHOP[i])
			end
		end
		if crates then
			Garage.crateYard(add, W, front)
		end
	end
	return out
end

-- Round the crate shop, so it reads as a shop from across the plaza (Studio score 7, shots 28/29:
-- "a tiny kiosk on a big empty pad"): a tall sign post beside the door with a giant gold crate on
-- top and a CRATES board (CrateShop.client writes it), a mat out front in the trim colour, and
-- piles of crates at the front corners. Shop-local, like Garage.parts.
-- beside the left front post, out of the door's way (the right side had a street lamp in front of
-- the board from the spawn, Studio score 37)
Garage.CRATE_POST = { x = -16, z = 7, h = 9.5 }
function Garage.crateYard(add: Add, W: number, front: number)
	local trim = Garage.CRATE_TRIM
	local p = Garage.CRATE_POST
	add("CrateSign", "Foot", v(3, 1, 3), v(p.x, 0.5, p.z), C.dark)
	add("CrateSign", "Post", v(1, p.h, 1), v(p.x, p.h / 2, p.z), C.white)
	add("CrateSign", "Board", v(6, 3, 6), v(p.x, p.h - 2.2, p.z), trim) -- written front and back (CrateShop.client)
	Garage.crate(add, "CrateSign", v(p.x, p.h, p.z), "mega", 4, true)
	-- the mat out of the door: trim colour with a lighter middle
	add("CrateMat", "Mat", v(16, 0.06, 7), v(0, 0.03, front + 3.5), trim, { collide = false })
	add(
		"CrateMat",
		"MatIn",
		v(14, 0.07, 5.4),
		v(0, 0.035, front + 3.5),
		{ 255, 214, 120 },
		{ collide = false }
	)
	-- piles of crates at the front corners (solid: you walk round them)
	local right, left = W / 2 + 2.6, -W / 2 - 1
	Garage.crate(add, "CratePile", v(right, 0, front - 2.2), "basic", 2.4, true)
	Garage.crate(add, "CratePile", v(right, 0, front + 0.6), "big", 2.4, true)
	Garage.crate(add, "CratePile", v(right, 2.4, front - 0.8), "mega", 2, true)
	Garage.crate(add, "CratePile", v(left, 0, front + 2.1), "big", 2.2, true) -- clear of the post's foot
end

-- A toy crate standing on `at` (its bottom middle): a box in its kind's colour (Garage.CRATE_COLORS),
-- white straps round it like a present and a darker lid. The client spins it and gives it a prompt.
-- `size` (default CRATE_SIZE) and `solid` (the box collides) for the crates round the shop.
function Garage.crate(
	add: Add,
	group: string,
	at: V3,
	kind: string?,
	size: number?,
	solid: boolean?
)
	local c = Garage.CRATE_COLORS[kind or ""] or Garage.CRATE_COLORS.basic
	local dark = { math.floor(c[1] * 0.6), math.floor(c[2] * 0.6), math.floor(c[3] * 0.6) }
	local s = size or Garage.CRATE_SIZE
	local k = s / Garage.CRATE_SIZE
	local y = at.y + s / 2
	local box = { collide = false, material = "SmoothPlastic" }
	add(group, "Box", v(s, s, s), v(at.x, y, at.z), c, {
		collide = solid == true,
		material = "SmoothPlastic",
	})
	add(
		group,
		"Lid",
		v(s + 0.2 * k, 0.45 * k, s + 0.2 * k),
		v(at.x, at.y + s - 0.1 * k, at.z),
		dark,
		box
	)
	add(group, "StrapX", v(s + 0.08, s + 0.08, 0.4 * k), v(at.x, y, at.z), C.white, box)
	add(group, "StrapZ", v(0.4 * k, s + 0.08, s + 0.08), v(at.x, y, at.z), C.white, box)
	add(group, "Bow", v(0.7 * k, 0.7 * k, 0.7 * k), v(at.x, at.y + s + 0.4 * k, at.z), C.white, {
		shape = "Ball",
		collide = false,
	})
end

-- Makes real parts for `pieces` under `model`, one Model per group, placed with `origin`
-- (local +Z = front). Returns the groups by name.
function Garage.makeParts(pieces: { Piece }, model: Instance, origin: CFrame): { [string]: Model }
	local groups: { [string]: Model } = {}
	for _, p in pieces do
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
		if p.alpha then
			part.Transparency = p.alpha
			part.CanQuery = false
		end
		if p.light then
			local light = Instance.new("PointLight")
			light.Range = p.light
			light.Brightness = 1.2
			light.Color = part.Color
			light.Parent = part
		end
		if p.mesh then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = assert((Enum.MeshType :: any)[p.mesh], p.mesh)
			mesh.Scale = Vector3.new(1.25, 1.25, 1.25) -- (a Roblox character's own head size in its part)
			mesh.Parent = part
		end
		if p.face then
			local face = Instance.new("Decal")
			face.Name = "face"
			face.Texture = "rbxasset://textures/face.png" -- (Roblox's classic smile, built in)
			face.Face = Enum.NormalId.Front
			face.Parent = part
		end
		part.Parent = group
	end
	return groups
end

-- Builds the garage (or with a shop kind, that car shop) under `parent`. `at` is the middle of
-- the floor at plaza height, its LookVector pointing out of the open front.
function Garage.build(
	parent: Instance,
	at: CFrame,
	_width: number?,
	_depth: number?,
	kind: string?
): Model
	local origin = at * CFrame.Angles(0, math.pi, 0) -- garage-local +Z = the LookVector
	local model = Instance.new("Model")
	local shop = kind ~= nil and (Garage.SHOPS[kind] ~= nil or kind == "crates")
	model.Name = if shop
		then (kind :: string):sub(1, 1):upper() .. (kind :: string):sub(2) .. "Shop"
		else "UpgradesGarage"
	local groups = Garage.makeParts(Garage.parts(kind), model, origin)
	model.PrimaryPart = (groups.Shell :: Model):FindFirstChild("Floor") :: BasePart
	if shop then
		model:SetAttribute("ShopKind", kind) -- CarShops (client) spins its cars and opens its screen
	else
		model:SetAttribute("ShopKind", "looks") -- the LOOKS shop's door (PlotShop client)
	end
	Garage.useMeshes(
		groups,
		origin,
		if shop then Garage.shopMeshes(kind :: string) else Garage.MESHES
	)
	model.Parent = parent
	return model
end

-- Puts carter's Meshy props in place of the block stand-ins (see Garage.MESHES).
function Garage.useMeshes(groups: { [string]: Model }, origin: CFrame, meshes: { Mesh }?)
	local folder = game:GetService("ServerStorage"):FindFirstChild("LobbyMeshes")
	local skins = game:GetService("ReplicatedStorage"):FindFirstChild("CarSkins")
	local tops: { [string]: number } = {} -- prop top height, garage-local
	for _, m in meshes or Garage.MESHES do
		local from = if m.carSkin then skins else folder
		local template = from and from:FindFirstChild(m.model)
		if not (template and (template:IsA("Model") or template:IsA("BasePart"))) then
			continue
		end
		local group = groups[m.group]
		if not group then
			group = Instance.new("Model")
			group.Name = m.group
			local first = next(groups)
			group.Parent = if first then (groups[first] :: Model).Parent else nil
			groups[m.group] = group
		end
		local prop: Model
		if template:IsA("Model") then
			prop = template:Clone()
		else
			prop = Instance.new("Model")
			local p = (template :: BasePart):Clone()
			p.Parent = prop
			prop.PrimaryPart = p
		end
		prop.Name = m.model
		for _, d in prop:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = m.collide
				d.CanTouch = false
			end
		end
		-- turn the long side the right way, then shrink it to fit
		prop:PivotTo(CFrame.identity)
		local _, size = prop:GetBoundingBox()
		local quarter = if m.faceMinusX then -math.pi / 2 else math.pi / 2 -- model front is +Z
		local turn = if (m.long == "z") == (size.X > size.Z) then quarter else 0
		if turn ~= 0 then
			size = Vector3.new(size.Z, size.Y, size.X)
		end
		local k = math.min(m.fit.x / size.X, m.fit.y / size.Y, m.fit.z / size.Z)
		prop:ScaleTo(prop:GetScale() * k)
		if m.flat then
			for _, d in prop:GetDescendants() do
				if d:IsA("BasePart") then
					d.Size = Vector3.new(d.Size.X, m.flat, d.Size.Z)
				end
			end
		end
		-- stand it with its bottom middle on the spot
		local y = if m.onTop then tops[m.onTop] or m.at.y else m.at.y
		local spot = origin * CFrame.new(m.at.x, y, m.at.z)
		prop:PivotTo(spot * CFrame.Angles(0, turn + math.rad(m.yaw or 0), 0))
		local box, now = prop:GetBoundingBox()
		local bottom = box.Position - Vector3.yAxis * now.Y / 2
		prop:PivotTo(prop:GetPivot() + (spot.Position - bottom))
		tops[m.model] = y + now.Y
		-- the stand-ins it replaces go
		local keep: { [string]: boolean } = {}
		for _, name in m.keep do
			keep[name] = true
		end
		local hide: { [string]: boolean } = {}
		for _, name in m.hide or {} do
			hide[name] = true
		end
		for _, part in group:GetChildren() do
			if part:IsA("BasePart") and not keep[part.Name] then
				part:Destroy()
			elseif part:IsA("BasePart") and hide[part.Name] then
				part.Transparency = 1
			end
		end
		prop.Parent = group
	end
end

return Garage
