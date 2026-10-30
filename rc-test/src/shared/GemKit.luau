--!strict
-- The "Bold" faceted low-poly nature + rubble kit (carter's pick, 2026-10-29): trees, pines, rocks,
-- bushes, concrete chunks, a broken wall, a junk pile and a dead tree. Same call shape as PropKit
-- (a parent, a base point, a height), so a builder can swap one for the other.
--
-- The shapes are real meshes built at run time from GemData with EditableMesh, one template per
-- kind that is then cloned, so nothing has to be uploaded. If this server can't make an
-- EditableMesh, `build` returns nil and the caller keeps its PropKit prop.
--
-- A MeshPart made this way draws its vertices around the PART'S ORIGIN, not its bounding-box
-- centre, so every piece sits at the model's pivot (the foot of the prop).

local GemData = require(script.Parent.GemData)

local GemKit = {}

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
	for _, piece in GemData[kind] or {} do
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
	table.sort(out)
	return out
end

-- how many triangles a kind costs
function GemKit.triangles(kind: string): number
	local n = 0
	for _, piece in GemData[kind] or {} do
		n += #piece.f
	end
	return n
end

local templates: { [string]: Model } = {}

local function makeTemplate(kind: string): Model?
	local AssetService = game:GetService("AssetService")
	local model = Instance.new("Model")
	model.Name = kind
	for _, piece in GemData[kind] do
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
		mp.Material = Enum.Material.SmoothPlastic
		mp.Color = Color3.fromRGB(piece.color[1], piece.color[2], piece.color[3])
		mp.CanTouch = false
		mp.CanCollide = SOLID[piece.name] == true
		mp.CanQuery = mp.CanCollide
		mp.CollisionFidelity = Enum.CollisionFidelity.Box
		mp.CFrame = CFrame.new()
		mp.Parent = model
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
	if GemData[kind] == nil then
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

return GemKit
