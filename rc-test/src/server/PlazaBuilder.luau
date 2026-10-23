--!strict
-- Builds the lobby plaza (Plaza.luau) at the end of the street: paving, kerb, lamps, planters,
-- then each building in Plaza.spots whose module is in PlazaParts (Shop, Garage).
-- Each building module: build(parent, origin, width, depth) where origin is the middle of its
-- spot on the floor, LookVector = its open front, width across the front, depth front to back.
-- Looks only: flat colours, no text.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Plaza = require(ReplicatedStorage.Shared.Plaza)
local MeshProps = require(script.Parent.MeshProps)

local PlazaBuilder = {}

local PAVING = Color3.fromRGB(222, 214, 200)
local PAVING_DARK = Color3.fromRGB(196, 188, 176)
local KERB = Color3.fromRGB(150, 146, 140)
local IRON = Color3.fromRGB(46, 48, 54)
local GLOW = Color3.fromRGB(255, 214, 140)
local PLANTER = Color3.fromRGB(170, 160, 148)
local BUSH = Color3.fromRGB(88, 160, 72)

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function lamp(parent: Instance, at: CFrame)
	local m = Instance.new("Model")
	m.Name = "Lamp"
	block(m, "Base", Vector3.new(1.6, 0.8, 1.6), at * CFrame.new(0, 0.4, 0), IRON)
	block(m, "Post", Vector3.new(0.6, 9, 0.6), at * CFrame.new(0, 4.5, 0), IRON)
	block(m, "Cap", Vector3.new(1.8, 0.4, 1.8), at * CFrame.new(0, 11.3, 0), IRON)
	local light = block(m, "Light", Vector3.new(1.3, 1.8, 1.3), at * CFrame.new(0, 10.1, 0), GLOW)
	light.Material = Enum.Material.Neon
	light.CanCollide = false
	local glow = Instance.new("PointLight")
	glow.Color = GLOW
	glow.Range = 18
	glow.Brightness = 1.2
	glow.Parent = light
	block(m, "Frame", Vector3.new(1.6, 0.3, 1.6), at * CFrame.new(0, 9.1, 0), IRON)
	m.Parent = parent
end

-- Plaza frame: origin at the anchor, +X = plaza x, +Z = plaza z (into the plaza), +Y up.
-- With the anchor looking down world +z, plaza x is world x.
local function frame(anchor: CFrame): CFrame
	local look = anchor.LookVector
	local up = Vector3.yAxis
	return CFrame.fromMatrix(anchor.Position, up:Cross(look), up, look)
end

-- The paving: a big slab with the two far corners cut off, a kerb on the outside, and a slightly
-- darker band down the middle lane so the way in from the street reads at a glance.
local function paving(parent: Instance, f: CFrame)
	local b = Plaza.box()
	local c = Plaza.CORNER
	local k = Plaza.BORDER
	local w, d = b.maxX - b.minX, b.maxZ - b.minZ
	local function at(x: number, y: number, z: number): CFrame
		return f * CFrame.new(x, y, z)
	end
	-- front part (full width) + back part (narrower); a diamond on each side fills the corner
	-- triangle up to the cut (the rest of the diamond hides inside the two slabs)
	local frontD = d - c
	block(parent, "Paving", Vector3.new(w, 1, frontD), at(0, -0.45, frontD / 2), PAVING)
	block(parent, "PavingBack", Vector3.new(w - 2 * c, 1, c), at(0, -0.45, frontD + c / 2), PAVING)
	local diag = c * math.sqrt(2)
	for _, side in { -1, 1 } do
		local turn = CFrame.Angles(0, math.rad(45), 0)
		block(
			parent,
			"PavingCorner",
			Vector3.new(diag, 1, diag),
			at(side * (w / 2 - c), -0.45, frontD) * turn,
			PAVING
		)
		local cut = at(side * (w / 2 - c / 2), 0.2, d - c / 2)
			* CFrame.Angles(0, math.rad(45 * side), 0)
		block(parent, "KerbCorner", Vector3.new(diag, 0.4, k), cut * CFrame.new(0, 0, k / 2), KERB)
		block(
			parent,
			"KerbSide",
			Vector3.new(k, 0.4, frontD),
			at(side * (w / 2 - k / 2), 0.2, frontD / 2),
			KERB
		)
		local frontLen = w / 2 - Plaza.MOUTH / 2
		block(
			parent,
			"KerbFront",
			Vector3.new(frontLen, 0.4, k),
			at(side * (Plaza.MOUTH / 2 + frontLen / 2), 0.2, k / 2),
			KERB
		)
	end
	block(parent, "KerbBack", Vector3.new(w - 2 * c, 0.4, k), at(0, 0.2, d - k / 2), KERB)
	-- middle lane band (a hair above the paving so it never flickers)
	local laneEnd = d - c
	block(
		parent,
		"Lane",
		Vector3.new(Plaza.MOUTH - 8, 0.04, laneEnd),
		at(0, 0.07, laneEnd / 2),
		PAVING_DARK
	)
end

local PAVING_TOP = 0.05

-- Block stand-ins for the Meshy decor props (front = -Z of `at`, which sits on the floor).
local WOOD = Color3.fromRGB(150, 104, 62)
local GREEN_BIN = Color3.fromRGB(60, 120, 80)
local POT = Color3.fromRGB(196, 110, 70)
local RED = Color3.fromRGB(206, 52, 46)
local function standIn(parent: Instance, d: Plaza.Decor, at: CFrame)
	local m = Instance.new("Model")
	m.Name = d.name
	local function b(name: string, size: Vector3, x: number, y: number, z: number, color: Color3)
		block(m, name, size, at * CFrame.new(x, y, z), color)
	end
	if d.name == "ParkBench" then
		b("Seat", Vector3.new(5, 0.3, 1.4), 0, 1.2, 0, WOOD)
		b("Back", Vector3.new(5, 1.2, 0.3), 0, 2, 0.65, WOOD)
		for _, sx in { -2, 2 } do
			b("Leg", Vector3.new(0.3, 1.1, 1.2), sx, 0.55, 0, IRON)
		end
	elseif d.name == "TrashCan" then
		b("Bin", Vector3.new(1.4, 2.2, 1.4), 0, 1.1, 0, GREEN_BIN)
		b("Lid", Vector3.new(1.6, 0.2, 1.6), 0, 2.3, 0, IRON)
	elseif d.name == "PicnicTable" then
		b("Top", Vector3.new(5, 0.3, 2.4), 0, 2.4, 0, WOOD)
		for _, sz in { -1.9, 1.9 } do
			b("Seat", Vector3.new(5, 0.25, 0.9), 0, 1.3, sz, WOOD)
		end
		for _, sx in { -1.8, 1.8 } do
			b("Leg", Vector3.new(0.3, 2.3, 4.6), sx, 1.15, 0, WOOD)
		end
	elseif d.name == "FlowerPot" then
		b("Pot", Vector3.new(1.6, 1.2, 1.6), 0, 0.6, 0, POT)
		b("Flowers", Vector3.new(1.4, 0.9, 1.4), 0, 1.6, 0, BUSH)
	elseif d.name == "Mailbox" then
		b("Post", Vector3.new(0.3, 2.4, 0.3), 0, 1.2, 0, IRON)
		b("Box", Vector3.new(0.9, 0.9, 1.6), 0, 2.85, 0, Color3.fromRGB(46, 90, 180))
	else -- Hydrant
		b("Body", Vector3.new(0.8, 1.8, 0.8), 0, 0.9, 0, RED)
		b("Cap", Vector3.new(1, 0.3, 1), 0, 1.95, 0, RED)
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = d.name ~= "Flowers"
		end
	end
	m.Parent = parent
end

-- Meshy props whose front came out backwards from Import 3D: turned this much more (degrees).
local MESH_TURN: { [string]: number } = { ParkBench = 180 }

-- Invisible seats people can sit on (Seat faces its LookVector). Per prop: where each seat sits
-- in the prop's own space (front = -Z), for the Meshy model and for the block stand-in.
type SeatSpot = { x: number, y: number, z: number, turn: number }
local SEATS: { [string]: { mesh: { SeatSpot }, block: { SeatSpot } } } = {
	ParkBench = {
		-- the turned mesh: seat behind the middle, people look out along its back (+Z here)
		mesh = { { x = 0, y = 1.85, z = 0.6, turn = 180 } },
		block = { { x = 0, y = 1.35, z = 0, turn = 0 } },
	},
	-- one seat each side of the table, looking in at it (the mesh's benches run along its sides)
	PicnicTable = {
		mesh = { { x = 2.6, y = 1.9, z = 0, turn = 90 }, { x = -2.6, y = 1.9, z = 0, turn = -90 } },
		block = {
			{ x = 0, y = 1.425, z = 1.9, turn = 0 },
			{ x = 0, y = 1.425, z = -1.9, turn = 180 },
		},
	},
}
local function seats(parent: Instance, name: string, at: CFrame, isMesh: boolean)
	local spec = SEATS[name]
	if not spec then
		return
	end
	for i, s in if isMesh then spec.mesh else spec.block do
		local seat = Instance.new("Seat")
		seat.Name = "Seat" .. i
		seat.Anchored = true
		seat.Size = Vector3.new(3.6, 0.2, 1.2)
		-- top of the seat part on the sitting surface
		seat.CFrame = at * CFrame.new(s.x, s.y - 0.1, s.z) * CFrame.Angles(0, math.rad(s.turn), 0)
		seat.Transparency = 1
		seat.CanCollide = false
		seat.Parent = parent
	end
end

-- White zebra stripes across the end of the road (looks only).
local function crosswalk(parent: Instance, f: CFrame)
	local c = Plaza.CROSSWALK
	local step = c.stripe + c.gap
	local n = math.floor((c.roadW - c.gap) / step)
	local first = -(n - 1) * step / 2
	local len = c.toZ - c.fromZ
	for i = 0, n - 1 do
		local stripe = block(
			parent,
			"Crosswalk",
			Vector3.new(c.stripe, 0.06, len),
			f * CFrame.new(first + i * step, 0.14, (c.fromZ + c.toZ) / 2),
			Color3.fromRGB(240, 240, 240)
		)
		stripe.CanCollide = false
	end
end

-- A building module, in server/PlazaParts or ReplicatedStorage.Shared, or nil.
local function partModule(name: string): ModuleScript?
	local parts = script.Parent:FindFirstChild("PlazaParts")
	for _, where in { parts, ReplicatedStorage:FindFirstChild("Shared") } do
		local m = where and where:FindFirstChild(name)
		if m and m:IsA("ModuleScript") then
			return m
		end
	end
	return nil
end

-- anchor: the middle of the street's end edge on the ground, LookVector = into the plaza.
function PlazaBuilder.build(parent: Instance, anchor: CFrame): Model
	local plaza = Instance.new("Model")
	plaza.Name = "Plaza"
	local f = frame(anchor)
	local function at(x: number, z: number): CFrame
		return f * CFrame.new(x, 0, z)
	end

	paving(plaza, f)
	crosswalk(plaza, f)
	for _, l in Plaza.lamps do
		lamp(plaza, at(l[1], l[2]))
	end
	for _, p in Plaza.planters do
		local cf = at(p[1], p[2])
		block(plaza, "Planter", Vector3.new(p[3], 1.4, p[4]), cf * CFrame.new(0, 0.7, 0), PLANTER)
		local bush = block(
			plaza,
			"Bush",
			Vector3.new(p[3] - 0.8, 1.6, p[4] - 0.8),
			cf * CFrame.new(0, 2, 0),
			BUSH
		)
		bush.CanCollide = false
	end

	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = plaza
	for _, d in Plaza.decor do
		local pos = at(d.x, d.z).Position + Vector3.new(0, PAVING_TOP, 0)
		local a = math.rad(d.face)
		local look = f:VectorToWorldSpace(Vector3.new(math.sin(a), 0, math.cos(a)))
		local cf = CFrame.lookAt(pos, pos + look)
		local meshAt = cf * CFrame.Angles(0, math.rad(MESH_TURN[d.name] or 0), 0)
		local mesh = MeshProps.place(decor, d.name, meshAt, d.h)
		if mesh then
			seats(mesh, d.name, meshAt, true)
		else
			standIn(decor, d, cf)
			seats(decor:FindFirstChild(d.name) or decor, d.name, cf, false)
		end
	end

	for _, spot in Plaza.spots do
		local mod = partModule(spot.name)
		if mod then
			local b = spot.box
			local mid = at((b.minX + b.maxX) / 2, (b.minZ + b.maxZ) / 2).Position
			local a = math.rad(spot.face)
			local front = f:VectorToWorldSpace(Vector3.new(math.sin(a), 0, math.cos(a)))
			local origin = CFrame.lookAt(mid, mid + front)
			local sideways = math.abs(spot.face) == 90
			local across, along = b.maxX - b.minX, b.maxZ - b.minZ
			local width = if sideways then along else across
			local depth = if sideways then across else along
			local building = Instance.new("Model")
			building.Name = spot.name
			local ok, err = pcall(function()
				(require(mod) :: any).build(building, origin, width, depth)
			end)
			if not ok then
				warn("Plaza: " .. spot.name .. " failed: " .. tostring(err))
			end
			building.Parent = plaza
		end
	end

	plaza.Parent = parent
	return plaza
end

return PlazaBuilder
