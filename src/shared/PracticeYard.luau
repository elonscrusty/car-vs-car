--!strict
-- Builds the practice yard of the first-time tutorial: a small flat Wreck City junkyard made of
-- plain Parts (carter's L13, L56). Shared so the client can build it on the player's own screen (no
-- other player ever sees it) and the tests can run it on the fake Roblox. Where everything stands is
-- PracticeLayout; what counts as a smash is PracticeRules.
--
-- Only the floor, the four walls, three low blocks and the ground slab collide. The walls and blocks
-- are tagged "Bouncy" so a car that hits one is thrown back (BattleDrive.wallBounce). The boxes do
-- not collide: the car drives through them and they burst. Everything else is looks only.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.PracticeLayout)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local MapParts = require(ReplicatedStorage.Shared.MapParts)

local PracticeYard = {}

export type Crate = {
	index: number,
	x: number, -- yard coordinates
	z: number,
	model: Model,
	color: Color3, -- the strap color, for the burst
}

export type Yard = {
	root: Folder,
	origin: Vector3,
	crates: { Crate },
	toWorld: (x: number, z: number) -> Vector3, -- a point on the floor
	spawn: () -> CFrame, -- the car's floor-middle and facing at the start
	destroy: () -> (),
}

local rgb, part, can, group = MapParts.rgb, MapParts.part, MapParts.can, MapParts.group
local C = LobbyLayout.colors

-- Junk palette: dirt, rust, concrete, hazard paint.
local DIRT = { 150, 112, 76 }
local DIRT_DARK = { 118, 88, 62 }
local WALL = { 128, 134, 146 }
local CONCRETE = { 176, 181, 190 }
local RUST = { 150, 86, 52 }
local INK = { 36, 39, 43 }
local OIL = { 66, 48, 38 }
local YELLOW = { 255, 214, 64 }
local DRUM_COLORS = { C.orange, C.blue, { 232, 60, 60 }, { 46, 190, 96 } }
local CONTAINER_COLORS = {
	{ 232, 60, 60 },
	{ 255, 214, 48 },
	{ 46, 190, 96 },
	{ 40, 160, 220 },
	{ 245, 130, 32 },
	{ 160, 90, 230 },
}

local function yaw(deg: number): CFrame
	return CFrame.Angles(0, math.rad(deg), 0)
end

-- A repeatable 0..1 number from a seed and a counter (no math.random: the same yard every time).
local function noise(seed: number, k: number): number
	local x = math.sin(seed * 12.9898 + k * 78.233) * 43758.5453
	return x - math.floor(x)
end

local function darker(c: { number }, k: number): Color3
	return MapParts.shade(c, k)
end

-- Walls and blocks throw a car back (the weight 100 makes their bounce win over the car's).
local function bouncy(p: Part): Part
	p.CustomPhysicalProperties = PhysicalProperties.new(2, 0.1, 0.9, 1, 100)
	CollectionService:AddTag(p, "Bouncy")
	return p
end

-- A crushed car lying at `base` (the floor under its middle): a flat body, a squashed cabin, two
-- tires. `stacked` puts a second, smaller wreck on top.
local function wreck(
	parent: Instance,
	base: CFrame,
	color: { number },
	seed: number,
	stacked: boolean
)
	local body = part(
		parent,
		"WreckBody",
		Vector3.new(6.6, 1.8, 14.2),
		base * CFrame.new(0, 0.9, 0),
		rgb(color),
		false,
		nil,
		Enum.Material.Metal
	)
	body.CFrame = body.CFrame * CFrame.Angles(0, 0, math.rad((noise(seed, 1) - 0.5) * 6))
	part(
		parent,
		"WreckCabin",
		Vector3.new(5.4, 1.5, 6.2),
		base
			* CFrame.new(0, 2.5, 1.4)
			* CFrame.Angles(math.rad(5), 0, math.rad((noise(seed, 2) - 0.5) * 10)),
		darker(color, 0.7),
		false,
		nil,
		Enum.Material.Metal
	)
	for _, z in { -4.4, 4.6 } do
		local tire = part(
			parent,
			"WreckTire",
			Vector3.new(1.1, 3, 3),
			base * CFrame.new(3.7, 1.5, z),
			rgb(C.tire),
			false,
			nil,
			Enum.Material.Rubber
		)
		tire.Shape = Enum.PartType.Cylinder
	end
	if stacked then
		local top = base * CFrame.new(0, 2.6, 0) * yaw((noise(seed, 3) - 0.5) * 50)
		part(
			parent,
			"WreckBody",
			Vector3.new(6, 1.6, 12.4),
			top * CFrame.new(0, 0.8, 0),
			darker(color, 0.85),
			false,
			nil,
			Enum.Material.Metal
		)
	end
end

-- A stack of 3 or 4 bright tires, each a little off the one under it.
local function tireStack(parent: Instance, pos: Vector3, colorIndex: number, seed: number)
	local count = 3 + math.floor(noise(seed, 4) * 2)
	local color = C.rainbow[(colorIndex - 1) % #C.rainbow + 1]
	for k = 0, count - 1 do
		local off = Vector3.new((k % 2 - 0.5) * 0.5, k * 1.7, (0.5 - k % 2) * 0.4)
		can(
			parent,
			"Tire",
			Layout.tireStackDiameter,
			1.6,
			pos + off,
			rgb(color),
			false,
			nil,
			Enum.Material.Rubber
		)
	end
end

-- An oil drum with two darker rings.
local function drum(parent: Instance, pos: Vector3, colorIndex: number)
	local color = DRUM_COLORS[(colorIndex - 1) % #DRUM_COLORS + 1]
	local d = Layout.drumDiameter
	can(parent, "Drum", d, 4.4, pos, rgb(color), false, nil, Enum.Material.Metal)
	for _, y in { 0.7, 3.4 } do
		can(
			parent,
			"DrumRing",
			d + 0.15,
			0.35,
			pos + Vector3.new(0, y, 0),
			darker(color, 0.7),
			false,
			nil,
			Enum.Material.Metal
		)
	end
end

-- A shipping container: a colored box, a pale roof lip and a darker door end.
local function container(parent: Instance, pos: Vector3, spec: { [string]: any })
	local cf = CFrame.new(pos) * yaw(spec.yawDeg)
	local color = CONTAINER_COLORS[(spec.color - 1) % #CONTAINER_COLORS + 1]
	part(
		parent,
		"Container",
		Vector3.new(spec.w, spec.h, spec.d),
		cf * CFrame.new(0, spec.h / 2, 0),
		rgb(color),
		false,
		nil,
		Enum.Material.CorrodedMetal
	)
	part(
		parent,
		"ContainerLip",
		Vector3.new(spec.w + 0.5, 0.5, spec.d + 0.5),
		cf * CFrame.new(0, spec.h + 0.25, 0),
		darker(color, 1.15),
		false,
		nil,
		Enum.Material.Metal
	)
	part(
		parent,
		"ContainerDoors",
		Vector3.new(0.5, spec.h - 0.8, spec.d - 0.8),
		cf * CFrame.new(spec.w / 2 + 0.1, spec.h / 2, 0),
		darker(color, 0.65),
		false,
		nil,
		Enum.Material.Metal
	)
end

-- A heap of scrap: a few gray and rusty boxes piled up, each one resting on the ground or on the pile.
local function heap(parent: Instance, pos: Vector3, seed: number)
	for k = 1, 8 do
		local size = 3.2 + noise(seed, k) * 3.4
		local dims = Vector3.new(size, size * 0.8, size * 1.3)
		local r = (1 - k / 9) * 6
		local a = noise(seed, k + 20) * math.pi * 2
		local color = if k % 3 == 0 then RUST elseif k % 3 == 1 then WALL else INK
		local turn = CFrame.Angles(
			noise(seed, k + 40) * 0.5,
			noise(seed, k + 60) * 3,
			noise(seed, k + 80) * 0.5
		)
		-- how high the turned box reaches above and below its middle: it must not sink into the ground
		local reach = math.abs(turn.RightVector.Y) * dims.X / 2
			+ math.abs(turn.UpVector.Y) * dims.Y / 2
			+ math.abs(turn.LookVector.Y) * dims.Z / 2
		part(
			parent,
			"Scrap",
			dims,
			CFrame.new(
				pos
					+ Vector3.new(
						math.cos(a) * r,
						math.max(reach, size * 0.4 + (k // 3) * 2.2),
						math.sin(a) * r
					)
			) * turn,
			rgb(color),
			false,
			nil,
			Enum.Material.CorrodedMetal
		)
	end
end

-- A crate: a big wooden box with two painted straps. Not solid: the car drives through and it bursts.
local function crate(parent: Instance, pos: Vector3, strap: { number }): Model
	local s = Layout.crateSize
	local m = Instance.new("Model")
	m.Name = "Crate"
	local base = CFrame.new(pos) * yaw(noise(pos.X, pos.Z) * 30 - 15)
	local body = part(
		m,
		"Body",
		Vector3.new(s, s, s),
		base * CFrame.new(0, s / 2, 0),
		rgb(C.wood),
		false,
		nil,
		Enum.Material.Wood
	)
	for _, y in { 0.6, s - 0.6 } do
		part(
			m,
			"Strap",
			Vector3.new(s + 0.2, 0.9, s + 0.2),
			base * CFrame.new(0, y, 0),
			rgb(strap),
			false,
			nil,
			Enum.Material.SmoothPlastic
		)
	end
	m.PrimaryPart = body
	m.Parent = parent
	return m
end

-- Builds the yard under `parent` with its floor-middle at `origin` (the floor top is origin.Y).
function PracticeYard.build(parent: Instance, origin: Vector3): Yard
	local root = Instance.new("Folder")
	root.Name = "PracticeYard"
	root:SetAttribute("PracticeYard", true)
	root.Parent = parent
	local half, wall = Layout.half, Layout.wall
	local function at(x: number, z: number): Vector3
		return origin + Vector3.new(x, 0, z)
	end

	-- the ground slab (so the camera never sees the world's edge) and the play floor on top of it
	local ground = group(root, "Ground")
	part(
		ground,
		"Slab",
		Vector3.new(Layout.ground.half * 2, 2, Layout.ground.half * 2),
		CFrame.new(at(0, 0) + Vector3.new(0, -1.05, 0)),
		rgb(DIRT_DARK),
		true,
		nil,
		Enum.Material.Ground
	)
	part(
		ground,
		"Floor",
		Vector3.new(half.x * 2 + wall.thickness * 2, 1, half.z * 2 + wall.thickness * 2),
		CFrame.new(at(0, 0) + Vector3.new(0, -0.5, 0)),
		rgb(DIRT),
		true,
		nil,
		Enum.Material.Ground
	)

	-- floor marks: oil stains, tire skids, the start line (flat, looks only)
	local marks = group(root, "Marks")
	for _, st in Layout.stains do
		local stain = can(marks, "Stain", st.d, 0.08, at(st.x, st.z), rgb(OIL), false, nil)
		stain.Transparency = 0.35
	end
	for _, k in Layout.skids do
		local skid = part(
			marks,
			"Skid",
			Vector3.new(1.1, 0.07, k.len),
			CFrame.new(at(k.x, k.z) + Vector3.new(0, 0.04, 0)) * yaw(k.yawDeg),
			rgb(INK),
			false
		)
		skid.Transparency = 0.35
	end
	part(
		marks,
		"StartLine",
		Vector3.new(Layout.startLine.w, 0.07, 1.4),
		CFrame.new(at(0, Layout.startLine.z) + Vector3.new(0, 0.05, 0)),
		rgb(C.marking),
		false
	)

	-- the four walls: corrugated metal with an orange rail along the top. Bouncy.
	local walls = group(root, "Walls")
	local t, h = wall.thickness, wall.height
	for _, side in { -1, 1 } do
		bouncy(
			part(
				walls,
				"WallZ",
				Vector3.new(half.x * 2 + t * 2, h, t),
				CFrame.new(at(0, side * (half.z + t / 2)) + Vector3.new(0, h / 2, 0)),
				rgb(WALL),
				true,
				nil,
				Enum.Material.CorrodedMetal
			)
		)
		bouncy(
			part(
				walls,
				"WallX",
				Vector3.new(t, h, half.z * 2),
				CFrame.new(at(side * (half.x + t / 2), 0) + Vector3.new(0, h / 2, 0)),
				rgb(WALL),
				true,
				nil,
				Enum.Material.CorrodedMetal
			)
		)
		part(
			walls,
			"RailZ",
			Vector3.new(half.x * 2 + t * 2 + 0.6, 0.7, t + 0.6),
			CFrame.new(at(0, side * (half.z + t / 2)) + Vector3.new(0, h + 0.35, 0)),
			rgb(C.orange),
			false
		)
		part(
			walls,
			"RailX",
			Vector3.new(t + 0.6, 0.7, half.z * 2 + 0.6),
			CFrame.new(at(side * (half.x + t / 2), 0) + Vector3.new(0, h + 0.35, 0)),
			rgb(C.orange),
			false
		)
	end

	-- the low concrete blocks: solid and bouncy, with hazard stripes on top
	local blocks = group(root, "Barriers")
	for _, b in Layout.barriers do
		local cf = CFrame.new(at(b.x, b.z)) * yaw(b.yawDeg)
		bouncy(
			part(
				blocks,
				"Barrier",
				Vector3.new(b.w, b.h, b.d),
				cf * CFrame.new(0, b.h / 2, 0),
				rgb(CONCRETE),
				true,
				nil,
				Enum.Material.Concrete
			)
		)
		local long = math.max(b.w, b.d)
		local stripes = math.floor(long / 3)
		for k = 1, stripes do
			local along = -long / 2 + (k - 0.5) * (long / stripes)
			local offset = if b.w >= b.d then Vector3.new(along, 0, 0) else Vector3.new(0, 0, along)
			part(
				blocks,
				"Hazard",
				if b.w >= b.d
					then Vector3.new(long / stripes * 0.5, 0.1, b.d + 0.1)
					else Vector3.new(b.w + 0.1, 0.1, long / stripes * 0.5),
				cf * CFrame.new(offset + Vector3.new(0, b.h + 0.05, 0)),
				if k % 2 == 0 then rgb(INK) else rgb(YELLOW),
				false
			)
		end
	end

	-- the boxes
	local crateGroup = group(root, "Crates")
	local crates: { Crate } = {}
	for i, spot in Layout.crates do
		local strap = if i % 2 == 0 then C.blue else C.orange
		table.insert(crates, {
			index = i,
			x = spot.x,
			z = spot.z,
			model = crate(crateGroup, at(spot.x, spot.z), strap),
			color = rgb(strap),
		})
	end

	-- the scrapyard behind the walls (looks only)
	local decor = group(root, "Scrapyard")
	for i, j in Layout.junkCars() do
		local base = CFrame.new(at(j.x, j.z)) * yaw(j.yawDeg)
		wreck(decor, base, C.rainbow[j.color], j.seed, i % 2 == 0)
	end
	for _, j in Layout.tireStacks() do
		tireStack(decor, at(j.x, j.z), j.color, j.seed)
	end
	for _, j in Layout.drums() do
		drum(decor, at(j.x, j.z), j.color)
	end
	for _, spec in Layout.containers do
		container(decor, at(spec.x, spec.z), spec)
	end
	for _, j in Layout.heaps() do
		heap(decor, at(j.x, j.z), j.seed)
	end

	local yard: Yard = {
		root = root,
		origin = origin,
		crates = crates,
		toWorld = function(x: number, z: number): Vector3
			return at(x, z)
		end,
		spawn = function(): CFrame
			local s = Layout.spawn
			return CFrame.new(at(s.x, s.z)) * yaw(s.yawDeg)
		end,
		destroy = function()
			root:Destroy()
		end,
	}
	return yard
end

-- A box is smashed: its pieces fly off the way the car was going, then vanish. They never collide
-- (the car is still overlapping them at the burst; ChaseMap's breakables learned that in Studio).
function PracticeYard.burst(c: Crate, carVelocity: Vector3)
	local flat = Vector3.new(carVelocity.X, 0, carVelocity.Z)
	for _, d in c.model:GetDescendants() do
		if d:IsA("BasePart") then
			local p = d :: BasePart
			p.Anchored = false
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.CustomPhysicalProperties = PhysicalProperties.new(0.35, 0.3, 0.4, 1, 1)
			p.AssemblyLinearVelocity = flat * 0.7
				+ Vector3.new(
					math.random() * 16 - 8,
					14 + math.random() * 14,
					math.random() * 16 - 8
				)
			p.AssemblyAngularVelocity =
				Vector3.new(math.random() * 12 - 6, math.random() * 12 - 6, math.random() * 12 - 6)
		end
	end
	Debris:AddItem(c.model, 1.8)
end

return PracticeYard
