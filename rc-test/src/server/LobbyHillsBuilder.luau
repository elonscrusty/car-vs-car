--!strict
-- Builds the hills round the lobby (LobbyHills.layout). Each hill is one of carter's models
-- (DirtMound, or BigRock / FlatRock for cliffs) stretched to size and painted (a stepped block
-- mound when it isn't imported); tall far peaks get a snow cap. Trees are his PineTree /
-- LeafyTree or a coloured block tree, and the little things at the hills' feet are his props
-- or a patch of block flowers, all dropped onto the hill under them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyHills = require(ReplicatedStorage.Shared.LobbyHills)
local SpawnLobby = require(ReplicatedStorage.Shared.SpawnLobby)
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

-- a thin trail of grey smoke from the cabin's roof (a few slow puffs: cheap on phones)
local function chimneySmoke(cabin: Model)
	local box, size = cabin:GetBoundingBox()
	local holder = Instance.new("Part")
	holder.Name = "Smoke"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.CFrame = CFrame.new(box.Position + Vector3.new(0, size.Y / 2 + 0.3, 0))
	tidy(holder, false)
	holder.CastShadow = false
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 3
	smoke.Lifetime = NumberRange.new(3, 5)
	smoke.Speed = NumberRange.new(1.5, 2.5)
	smoke.SpreadAngle = Vector2.new(8, 8)
	smoke.Acceleration = Vector3.new(0.5, 0.3, 0.3)
	smoke.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 4) })
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Color = ColorSequence.new(Color3.fromRGB(228, 228, 232))
	smoke.RotSpeed = NumberRange.new(-20, 20)
	smoke.LightInfluence = 1
	smoke.Parent = holder
	holder.Parent = cabin
end

-- Smash (LOOK-BIBLE rule 6, one world): the same hills as soft round domes in the arena's
-- palette (green near, deeper green behind, pink and purple far away), round trees from ARENA's
-- PropKit on the near two rows, and nothing else: no rocks, snow, cabins, windmill or props.
local SMASH_ROW = {
	{ Color3.fromRGB(91, 209, 91), Color3.fromRGB(76, 190, 80) },
	{ Color3.fromRGB(62, 172, 86), Color3.fromRGB(52, 156, 92) },
	{ Color3.fromRGB(255, 150, 206), Color3.fromRGB(176, 128, 255) },
}
type Dome = { at: CFrame, w: number, h: number, d: number }
local function dome(
	parent: Instance,
	at: CFrame,
	size: Vector3,
	color: Color3,
	solid: boolean,
	list: { Dome }
)
	local p = Instance.new("Part")
	p.Name = "Hill"
	-- an ellipsoid half sunk in the ground: a rounded hill from one part. Its collision would be
	-- the whole box (flat invisible tops and corners), so it never collides; a solid hill gets a
	-- hidden block inside the curve to stop walkers instead
	p.Size = Vector3.new(size.X, size.Y * 2, size.Z)
	p.CFrame = at
	p.Color = color
	tidy(p, false)
	p.CastShadow = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	p.Parent = parent
	if solid then
		local wall = Instance.new("Part")
		wall.Name = "HillStop"
		wall.Size = Vector3.new(size.X * 0.7, size.Y * 0.7, size.Z * 0.7)
		wall.CFrame = at * CFrame.new(0, size.Y * 0.35, 0)
		wall.Transparency = 1
		tidy(wall, true)
		wall.CastShadow = false
		wall.Parent = parent
	end
	table.insert(list, { at = at, w = size.X, h = size.Y, d = size.Z })
end

-- the ground's height at x, z: the highest dome surface over it (the hills' grass at -0.2 else)
local function heightAt(list: { Dome }, x: number, z: number): number
	local y = LobbyHills.BASE_TOP
	for _, d in list do
		local l = d.at:PointToObjectSpace(Vector3.new(x, d.at.Y, z))
		local k = (l.X / (d.w / 2)) ^ 2 + (l.Z / (d.d / 2)) ^ 2
		if k < 1 then
			y = math.max(y, d.at.Y + d.h * math.sqrt(1 - k))
		end
	end
	return y
end

local function smashBuild(folder: Instance, hills: { LobbyHills.Hill }, trees: { LobbyHills.Tree })
	for i, b in LobbyHills.baseBoxes(hills) do
		local base = Instance.new("Part")
		base.Name = `HillGrass{i}`
		base.Size = Vector3.new(b.maxX - b.minX, 2, b.maxZ - b.minZ)
		base.CFrame =
			CFrame.new((b.minX + b.maxX) / 2, LobbyHills.BASE_TOP - 1, (b.minZ + b.maxZ) / 2)
		base.Color = SMASH_ROW[1][2]
		tidy(base, true)
		base.CastShadow = false
		base.Parent = folder
	end
	local list: { Dome } = {}
	for i, h in hills do
		local tone = SMASH_ROW[h.row] or SMASH_ROW[3]
		local turn = CFrame.Angles(0, math.rad(h.turn), 0)
		local at = CFrame.new(h.x, -0.5, h.z) * turn
		local hh = if h.row == 3 then h.h * 0.8 else h.h
		dome(folder, at, Vector3.new(h.w, hh, h.d), tone[i % 2 + 1], h.row == 1, list)
		-- a smaller lump on its shoulder, so the ring isn't a row of eggs
		dome(
			folder,
			at * CFrame.new(h.w * 0.28, 0, h.d * 0.12),
			Vector3.new(h.w * 0.55, hh * 0.7, h.d * 0.6),
			tone[(i + 1) % 2 + 1],
			false,
			list
		)
	end
	local ok, PropKit = pcall(function()
		return require(ReplicatedStorage.Shared:FindFirstChild("PropKit") :: ModuleScript)
	end)
	if not ok or type(PropKit) ~= "table" or type(PropKit.tree) ~= "function" then
		return
	end
	local treeFolder = Instance.new("Folder")
	treeFolder.Name = "HillTrees"
	local STYLES = { "green", "green", "pink", "green", "yellow" }
	for i, t in trees do
		if i % 3 ~= 0 then
			continue -- (a third as many: round crowns read fuller, and phones come first)
		end
		local y = heightAt(list, t.x, t.z) - 0.6 -- (a little sunk, so it never floats)
		pcall(
			PropKit.tree,
			treeFolder,
			Vector3.new(t.x, y, t.z),
			t.height,
			STYLES[i % #STYLES + 1],
			i,
			false
		)
	end
	treeFolder.Parent = folder
end

function LobbyHillsBuilder.build(parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Hills"
	folder.Parent = parent
	local hills, trees, props, marks = LobbyHills.layout()
	if SpawnLobby.SMASH then
		smashBuild(folder, hills, trees)
		return folder
	end
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
		local m = if t.mesh == "BlockTree"
			then nil
			else MeshProps.place(treeFolder, t.mesh, at, t.height)
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
		local mesh = if p.mesh == "Flowers"
			then MeshProps.place(propFolder, "Flowers", at, p.height * 1.6)
			else nil
		if mesh then
			for _, d in mesh:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.CanTouch = false
					d.CanQuery = false
				end
			end
		elseif p.mesh == "Flowers" then
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

	-- set pieces: cabin / windmill / watch tower on a hill top, a dirt path down to the foot, a
	-- little fence round the yard (open on the path side), a campfire and log seats
	local markFolder = Instance.new("Folder")
	markFolder.Name = "HillLandmarks"
	local function ground(x: number, z: number): Vector3
		return Vector3.new(x, drop(x, z, 0) + 0.4, z)
	end
	local function plank(
		a: Vector3,
		b: Vector3,
		width: number,
		thick: number,
		color: Color3,
		y: number
	)
		local p = Instance.new("Part")
		local mid = (a + b) / 2 + Vector3.new(0, y, 0)
		p.Size = Vector3.new(width, thick, (b - a).Magnitude + 0.6)
		p.CFrame = CFrame.lookAt(mid, mid + (b - a))
		p.Color = color
		tidy(p, false)
		p.CastShadow = false
		p.Parent = markFolder
	end
	local DIRT = Color3.fromRGB(176, 132, 84)
	local WOOD = Color3.fromRGB(132, 92, 56)
	for _, l in marks do
		local base = ground(l.x, l.z)
		local turn = math.rad(l.turn)
		local at = CFrame.new(base - Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, turn, 0)
		local m = MeshProps.place(markFolder, l.mesh, at, l.height)
		if m then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanCollide = true
					d.CanTouch = false
				end
			end
			if l.mesh == "Cabin" then
				chimneySmoke(m)
			end
		end
		-- the path: a flat yard patch, then planks of dirt down the slope
		local last = base
		for _, pt in l.path do
			local here = ground(pt[1], pt[2])
			plank(last, here, 3.4, 0.3, DIRT, -0.3)
			last = here
		end
		if l.fence then
			-- posts round a square yard, rails on three sides (the path side stays open)
			local fwd = Vector3.new(math.sin(turn), 0, math.cos(turn))
			local side = Vector3.new(fwd.Z, 0, -fwd.X)
			local r = 10
			local corners = {
				base + (fwd + side) * r,
				base + (-fwd + side) * r,
				base + (-fwd - side) * r,
				base + (fwd - side) * r,
			}
			for i, c in corners do
				corners[i] = ground(c.X, c.Z)
				local post = Instance.new("Part")
				post.Size = Vector3.new(0.6, 2.6, 0.6)
				post.CFrame = CFrame.new(corners[i] + Vector3.new(0, 0.9, 0))
				post.Color = WOOD
				tidy(post, false)
				post.Parent = markFolder
			end
			for i = 1, 3 do
				local a, b = corners[i], corners[i + 1]
				plank(a, b, 0.3, 0.35, WOOD, 1.6)
				plank(a, b, 0.3, 0.35, WOOD, 0.7)
			end
		end
		for _, e in l.extras do
			local eat = CFrame.new(ground(e.x, e.z) - Vector3.new(0, 0.4, 0))
				* CFrame.Angles(0, math.rad(e.turn), 0)
			local em = MeshProps.place(markFolder, e.mesh, eat, e.height)
			if em then
				for _, d in em:GetDescendants() do
					if d:IsA("BasePart") then
						d.CanCollide = false
						d.CanTouch = false
						d.CanQuery = false
					end
				end
			end
		end
	end
	markFolder.Parent = folder
	return folder
end

return LobbyHillsBuilder
