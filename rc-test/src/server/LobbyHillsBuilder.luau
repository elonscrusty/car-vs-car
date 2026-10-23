--!strict
-- Builds the hills round the lobby (LobbyHills.layout). Each hill is carter's DirtMound model
-- stretched to size and painted grass green (a stepped block mound when it isn't imported),
-- and the trees are his PineTree / LeafyTree, dropped onto the hill they stand on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyHills = require(ReplicatedStorage.Shared.LobbyHills)
local MeshProps = require(script.Parent.MeshProps)

local LobbyHillsBuilder = {}

local function tidy(part: BasePart, solid: boolean)
	part.Anchored = true
	part.CanCollide = solid
	part.CanTouch = false
	part.CanQuery = solid
	part.Material = Enum.Material.SmoothPlastic
end

-- the hill as carter's mound, stretched; false when it isn't imported
local function meshHill(parent: Instance, h: LobbyHills.Hill, at: CFrame): boolean
	local m = MeshProps.place(parent, "DirtMound", at, h.h)
	if not m then
		return false
	end
	m.Name = "Hill"
	local color = Color3.fromRGB(h.r, h.g, h.b)
	for _, d in m:GetDescendants() do
		if d:IsA("SurfaceAppearance") then
			d:Destroy()
		elseif d:IsA("MeshPart") then
			d.TextureID = ""
		end
	end
	-- stretch to w x h x d about the foot (the mound's own x/z are along w/d)
	local box, size = m:GetBoundingBox()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = box:ToObjectSpace(d.CFrame)
			local sx, sz = h.w / size.X, h.d / size.Z
			d.Size = Vector3.new(d.Size.X * sx, d.Size.Y, d.Size.Z * sz)
			d.CFrame = box * CFrame.new(rel.X * sx, rel.Y, rel.Z * sz) * rel.Rotation
			d.Color = color
			tidy(d, true)
			d.CastShadow = h.row < 3
		end
	end
	return true
end

-- stand-in: three stacked, shrinking, slightly turned blocks
local function blockHill(parent: Instance, h: LobbyHills.Hill, at: CFrame)
	local model = Instance.new("Model")
	model.Name = "Hill"
	for i, k in { { 1, 0.45 }, { 0.72, 0.35 }, { 0.45, 0.2 } } do
		local p = Instance.new("Part")
		local y = 0
		for j = 1, i - 1 do
			y += h.h * ({ 0.45, 0.35 })[j]
		end
		p.Size = Vector3.new(h.w * k[1], h.h * k[2], h.d * k[1])
		p.CFrame = at * CFrame.new(0, y + p.Size.Y / 2, 0) * CFrame.Angles(0, math.rad(i * 9), 0)
		p.Color = Color3.fromRGB(h.r, h.g, h.b)
		tidy(p, true)
		p.CastShadow = h.row < 3
		p.Parent = model
	end
	model.Parent = parent
end

function LobbyHillsBuilder.build(parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Hills"
	folder.Parent = parent
	local hills, trees = LobbyHills.layout()
	for _, h in hills do
		local at = CFrame.new(h.x, -0.5, h.z) * CFrame.Angles(0, math.rad(h.turn), 0)
		if not meshHill(folder, h, at) then
			blockHill(folder, h, at)
		end
	end
	-- trees: drop each onto the hill under it (falls back to the planned height)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local treeFolder = Instance.new("Folder")
	treeFolder.Name = "HillTrees"
	for _, t in trees do
		local hit = workspace:Raycast(Vector3.new(t.x, 200, t.z), Vector3.new(0, -400, 0), params)
		local y = if hit then hit.Position.Y - 0.4 else t.y
		local at = CFrame.new(t.x, y, t.z) * CFrame.Angles(0, math.rad(t.turn), 0)
		local m = MeshProps.place(treeFolder, t.mesh, at, t.height)
		if m then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.CanTouch = false
					d.CanQuery = false
				end
			end
		else
			-- stand-in: trunk + one green block
			local trunk = Instance.new("Part")
			trunk.Size = Vector3.new(1, t.height * 0.4, 1)
			trunk.CFrame = at * CFrame.new(0, trunk.Size.Y / 2, 0)
			trunk.Color = Color3.fromRGB(112, 78, 48)
			tidy(trunk, false)
			trunk.Parent = treeFolder
			local top = Instance.new("Part")
			top.Size = Vector3.new(t.height * 0.45, t.height * 0.55, t.height * 0.45)
			top.CFrame = at * CFrame.new(0, t.height * 0.65, 0) * CFrame.Angles(0, math.rad(45), 0)
			top.Color = Color3.fromRGB(70, 150, 70)
			tidy(top, false)
			top.Parent = treeFolder
		end
	end
	treeFolder.Parent = folder
	return folder
end

return LobbyHillsBuilder
