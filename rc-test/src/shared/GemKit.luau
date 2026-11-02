--!strict
-- The "Bold" faceted low-poly nature + rubble kit (carter's pick, 2026-10-29): trees, pines, rocks,
-- bushes, concrete chunks, a broken wall, a junk pile and a dead tree, plus the junkyard "crane yard"
-- set for the hills outside the wall (scrap heap, crane, car stacks, lamp, tyres; GemYardData), and the junkyard
-- arena props (tyre stacks, wrecks, drums, junk heap, barriers; JunkPropData, carter picked A 2026-10-29), the
-- ring of low junk hills outside the wall (JunkRingData, carter picked A "Low dunes" 2026-10-29), and the
-- breakable crate + its loose bits (CrateData, carter picked A Plain wood 2026-10-29).
-- Same call shape as PropKit
-- (a parent, a base point, a height), so a builder can swap one for the other.
--
-- The shapes are real meshes built at run time from GemData with EditableMesh, one template per
-- kind that is then cloned, so nothing has to be uploaded. If this server can't make an
-- EditableMesh, `build` returns nil and the caller keeps its PropKit prop.
--
-- A MeshPart made this way draws its vertices around the PART'S ORIGIN, not its bounding-box
-- centre, so every piece sits at the model's pivot (the foot of the prop).

local GemData = require(script.Parent.GemData)
local GemYardData = require(script.Parent.GemYardData)
local JunkPropData = require(script.Parent.JunkPropData)
local JunkRingData = require(script.Parent.JunkRingData)
local CrateData = require(script.Parent.CrateData)

local GemKit = {}

type Piece = GemYardData.Piece

local function dataOf(kind: string): { Piece }?
	local found: any = GemData[kind]
		or GemYardData[kind]
		or JunkPropData[kind]
		or JunkRingData.kinds[kind]
		or CrateData[kind]
	return found
end

-- pieces a car should bump into; leaves, needles and rebar are looks only
local SOLID: { [string]: boolean } = {
	Trunk = true,
	Rock = true,
	Rock2 = true,
	Concrete = true,
	Concrete2 = true,
	Wall = true,
	WallTop = true,
	Tyres = true,
	Crate = true,
}

-- the tallest vertex of a kind, in data units (the "height" of the prop)
function GemKit.height(kind: string): number
	local top = 0
	for _, piece in dataOf(kind) or {} do
		for _, p in piece.v do
			top = math.max(top, p[2])
		end
	end
	return top
end

function GemKit.kinds(): { string }
	local out = {}
	for k in GemData do
		table.insert(out, k)
	end
	for k in GemYardData do
		table.insert(out, k)
	end
	for k in JunkPropData do
		table.insert(out, k)
	end
	for k in JunkRingData.kinds do
		table.insert(out, k)
	end
	for k in CrateData do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

-- how many triangles a kind costs
function GemKit.triangles(kind: string): number
	local n = 0
	for _, piece in dataOf(kind) or {} do
		n += #piece.f
	end
	return n
end

local templates: { [string]: Model } = {}

-- A lamp face lights the ground under it. The MeshPart's own origin is the foot of the prop (see the
-- note at the top), so the light sits on a small hidden part at the middle of the glowing face.
local function addLamp(model: Model, piece: Piece)
	local sum = Vector3.zero
	for _, p in piece.v do
		sum += Vector3.new(p[1], p[2], p[3])
	end
	local lamp = Instance.new("Part")
	lamp.Name = "LampLight"
	lamp.Size = Vector3.new(0.2, 0.2, 0.2)
	lamp.Transparency = 1
	lamp.Anchored = true
	lamp.CanCollide = false
	lamp.CanQuery = false
	lamp.CanTouch = false
	lamp.CFrame = CFrame.new(sum / #piece.v - Vector3.new(0, 0.5, 0))
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Bottom
	light.Angle = 85
	light.Range = 45
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 205, 140)
	light.Shadows = false
	light.Parent = lamp
	lamp.Parent = model
end

local function makeTemplate(kind: string): Model?
	local AssetService = game:GetService("AssetService")
	local model = Instance.new("Model")
	model.Name = kind
	for _, piece in dataOf(kind) :: { Piece } do
		local em = AssetService:CreateEditableMesh()
		for _, t in piece.f do
			local ids = {}
			for i = 1, 3 do
				local p = piece.v[t[i]]
				ids[i] = em:AddVertex(Vector3.new(p[1], p[2], p[3]))
			end
			em:AddTriangle(ids[1], ids[3], ids[2])
		end
		local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
		mp.Name = piece.name
		mp.Anchored = true
		mp.Material = if piece.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		mp.Color = Color3.fromRGB(piece.color[1], piece.color[2], piece.color[3])
		mp.CanTouch = false
		mp.CanCollide = SOLID[piece.name] == true
		mp.CanQuery = mp.CanCollide
		mp.CollisionFidelity = Enum.CollisionFidelity.Box
		mp.CFrame = CFrame.new()
		mp.Parent = model
		if piece.glow then
			addLamp(model, piece)
		end
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- Puts one prop of `kind` in `parent`, its foot at `at`, `h` tall (in the caller's units),
-- turned `yaw` radians. `solid` (default true) can force the whole prop to be looks only.
-- Returns the Model, or nil when no EditableMesh can be made here.
function GemKit.build(
	parent: Instance,
	kind: string,
	at: Vector3,
	h: number,
	yaw: number?,
	solid: boolean?
): Model?
	if dataOf(kind) == nil then
		return nil
	end
	local template = templates[kind]
	if template == nil then
		local ok, made = pcall(makeTemplate, kind)
		if not ok or made == nil then
			return nil
		end
		template = made
		templates[kind] = made
	end
	local model = template:Clone()
	model:PivotTo(CFrame.new(at) * CFrame.Angles(0, yaw or 0, 0))
	model:ScaleTo(h / GemKit.height(kind))
	if solid == false then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
			end
		end
	end
	model.Parent = parent
	return model
end

-- The crane yard set (carter picked C, 2026-10-29): a scrap heap with a crane lifting a car, two car stacks,
-- a lamp and some tyres and a drum, laid out as in the picture. Its foot is at `at`; `scale` 1 is the preview
-- size (heap 20 wide, crane 25 tall). Looks only unless a piece is in SOLID. Returns nil when no
-- EditableMesh can be made here (nothing is left behind).
local YARD: { { kind: string, x: number, z: number, yaw: number } } = {
	{ kind = "yardHeap", x = -4, z = -4, yaw = 0 },
	{ kind = "yardCrane", x = 8, z = 10, yaw = 0 },
	{ kind = "yardStack3", x = -12, z = 16, yaw = 0.3 },
	{ kind = "yardStack2", x = -22, z = 12, yaw = -0.2 },
	{ kind = "yardLamp", x = 20, z = -6, yaw = 0 },
	{ kind = "yardDebris", x = 2, z = 16, yaw = 0 },
	{ kind = "yardDebris", x = 14, z = 18, yaw = 0.5 },
}

function GemKit.craneYard(
	parent: Instance,
	at: Vector3,
	scale: number,
	yaw: number?,
	solid: boolean?
): Model?
	local turn = CFrame.new(at) * CFrame.Angles(0, yaw or 0, 0)
	local yard = Instance.new("Model")
	yard.Name = "CraneYard"
	for _, piece in YARD do
		local foot = turn:PointToWorldSpace(Vector3.new(piece.x, 0, piece.z) * scale)
		local m = GemKit.build(
			yard,
			piece.kind,
			foot,
			GemKit.height(piece.kind) * scale,
			(yaw or 0) + piece.yaw,
			solid
		)
		if m == nil then
			yard:Destroy()
			return nil
		end
	end
	yard.Parent = parent
	return yard
end

-- The ring of low junk hills round the outside of the arena wall (carter picked A "Low dunes", 2026-10-29):
-- 36 scrap mounds (3 shapes, dark dirt with a few crushed cars, sheets, tyres and a drum poking out), 28 big
-- units outside the wall's centre line, about 11-15 big high. `at` is the arena centre, `scale` 1 = the arena's
-- big units (pass the arena's build scale). Looks only: nothing is solid. Returns nil when no EditableMesh can be
-- made here (nothing is left behind).
function GemKit.junkRing(parent: Instance, at: Vector3, scale: number): Model?
	local ring = Instance.new("Model")
	ring.Name = "JunkRing"
	for _, spot in JunkRingData.layout do
		local m = GemKit.build(
			ring,
			spot.k,
			at + Vector3.new(spot.x, 0, spot.z) * scale,
			GemKit.height(spot.k) * spot.s * scale,
			spot.yaw,
			false
		)
		if m == nil then
			ring:Destroy()
			return nil
		end
	end
	ring.Parent = parent
	return ring
end

return GemKit
