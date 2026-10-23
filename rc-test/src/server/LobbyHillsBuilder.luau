--!strict
-- Builds the hills round the lobby (LobbyHills.layout). Each hill is one of carter's models
-- (DirtMound, or BigRock / FlatRock for cliffs) stretched to size and painted (a stepped block
-- mound when it isn't imported); tall far peaks get a snow cap. Trees are his PineTree /
-- LeafyTree or a coloured block tree, and the little things at the hills' feet are his props
-- or a patch of block flowers, all dropped onto the hill under them.

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
local function meshHill(
	parent: Instance,
	h: LobbyHills.Hill,
	at: CFrame,
	mesh: string,
	color: Color3,
	name: string
): boolean
	local m = MeshProps.place(parent, mesh, at, h.h)
	if not m then
		return false
	end
	m.Name = name
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
	local hills, trees, props = LobbyHills.layout()
	for i, b in LobbyHills.baseBoxes(hills) do
		local base = Instance.new("Part")
		base.Name = `HillGrass{i}`
		base.Size = Vector3.new(b.maxX - b.minX, 2, b.maxZ - b.minZ)
		base.CFrame =
			CFrame.new((b.minX + b.maxX) / 2, LobbyHills.BASE_TOP - 1, (b.minZ + b.maxZ) / 2)
		base.Color = Color3.fromRGB(108, 178, 80)
		tidy(base, true)
		base.CastShadow = false
		base.Parent = folder
	end
	for _, h in hills do
		local at = CFrame.new(h.x, -0.5, h.z) * CFrame.Angles(0, math.rad(h.turn), 0)
		local color = Color3.fromRGB(h.r, h.g, h.b)
		if
			not meshHill(folder, h, at, h.mesh, color, "Hill")
			and not meshHill(folder, h, at, "DirtMound", color, "Hill")
		then
			blockHill(folder, h, at)
		end
		if h.snow then
			-- a white cap: a smaller mound sunk into the peak's top
			local cap = table.clone(h)
			cap.w, cap.d, cap.h = h.w * 0.4, h.d * 0.4, h.h * 0.36
			local capAt = at * CFrame.new(0, h.h * 0.7, 0)
			meshHill(folder, cap, capAt, "DirtMound", Color3.fromRGB(244, 248, 252), "Snow")
		end
	end
	-- trees: drop each onto the hill under it (falls back to the planned height)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local treeFolder = Instance.new("Folder")
	treeFolder.Name = "HillTrees"
	local function drop(x: number, z: number, fallback: number): number
		local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), params)
		return if hit then hit.Position.Y - 0.4 else fallback
	end
	for _, t in trees do
		local at = CFrame.new(t.x, drop(t.x, t.z, t.y), t.z) * CFrame.Angles(0, math.rad(t.turn), 0)
		local m = if t.color then nil else MeshProps.place(treeFolder, t.mesh, at, t.height)
		if m then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.CanTouch = false
					d.CanQuery = false
				end
			end
		else
			-- block tree (autumn / blossom, or the stand-in): trunk + two turned blocks
			local c = t.color or { 70, 150, 70 }
			local trunk = Instance.new("Part")
			trunk.Size = Vector3.new(t.height * 0.09, t.height * 0.45, t.height * 0.09)
			trunk.CFrame = at * CFrame.new(0, trunk.Size.Y / 2, 0)
			trunk.Color = Color3.fromRGB(112, 78, 48)
			tidy(trunk, false)
			trunk.Parent = treeFolder
			for i, k in { { 0.5, 0.42, 0.62, 1 }, { 0.36, 0.3, 0.86, 1.1 } } do
				local top = Instance.new("Part")
				top.Size = Vector3.new(t.height * k[1], t.height * k[2], t.height * k[1])
				top.CFrame = at
					* CFrame.new(0, t.height * k[3], 0)
					* CFrame.Angles(0, math.rad(20 + i * 25), math.rad(i * 6))
				top.Color = Color3.fromRGB(
					math.min(255, c[1] * k[4]),
					math.min(255, c[2] * k[4]),
					math.min(255, c[3] * k[4])
				)
				tidy(top, false)
				top.Parent = treeFolder
			end
		end
	end
	treeFolder.Parent = folder

	-- little things at the hills' feet
	local propFolder = Instance.new("Folder")
	propFolder.Name = "HillProps"
	local FLOWER = {
		{ 246, 120, 170 },
		{ 250, 214, 70 },
		{ 250, 250, 250 },
		{ 170, 120, 230 },
		{ 236, 84, 72 },
	}
	for i, p in props do
		local at = CFrame.new(p.x, drop(p.x, p.z, 0), p.z) * CFrame.Angles(0, math.rad(p.turn), 0)
		if p.mesh == "Flowers" then
			local c = FLOWER[i % #FLOWER + 1]
			for j = 1, 5 do
				local a = j * 2.4 + i
				local r = p.height * (0.4 + (j % 3) * 0.5)
				local f = Instance.new("Part")
				f.Size = Vector3.new(0.7, 0.7, 0.7) * p.height
				f.CFrame = at
					* CFrame.new(math.cos(a) * r, f.Size.Y * 0.6, math.sin(a) * r)
					* CFrame.Angles(0, a, math.rad(45))
				local cc = if j == 5 then FLOWER[(i + 2) % #FLOWER + 1] else c
				f.Color = Color3.fromRGB(cc[1], cc[2], cc[3])
				tidy(f, false)
				f.CastShadow = false
				f.Parent = propFolder
			end
		else
			local m = MeshProps.place(propFolder, p.mesh, at, p.height)
			if m then
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") then
						d.CanCollide = false
						d.CanTouch = false
						d.CanQuery = false
					end
				end
			end
		end
	end
	propFolder.Parent = folder
	return folder
end

return LobbyHillsBuilder
