--!strict
-- Builds the lobby's outside look (LobbyScenery.layout): carter's Meshy trees, pines, bushes,
-- rocks and cacti where they are imported (MeshProps, ServerStorage.LobbyMeshes), and the plain
-- block stand-ins for any that aren't. Fences and hedges are always blocks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyScenery = require(ReplicatedStorage.Shared.LobbyScenery)
local MeshProps = require(script.Parent.MeshProps)

local SceneryBuilder = {}

local function tidy(part: BasePart, solid: boolean, shadow: boolean)
	part.Anchored = true
	part.CanCollide = solid
	part.CanTouch = false
	part.CanQuery = solid
	part.CastShadow = shadow
end

-- carter's model for one prop; false when that model isn't imported
local function placeMesh(parent: Instance, pr: LobbyScenery.Prop): boolean
	local at = CFrame.new(pr.x, 0, pr.z) * CFrame.Angles(0, math.rad(pr.turn), 0)
	local m = MeshProps.place(parent, pr.mesh, at, pr.height)
	if not m then
		return false
	end
	-- small things don't need shadows (cheaper on phones)
	local shadow = pr.mesh ~= "Bush" and pr.mesh ~= "FlatRock"
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			tidy(d, pr.solid, shadow)
		end
	end
	-- trees and cacti: only a thin hidden trunk is solid, not the whole leafy shape
	if pr.trunk > 0 then
		local trunk = Instance.new("Part")
		trunk.Name = "Trunk"
		trunk.Size = Vector3.new(pr.trunk, pr.height * 0.4, pr.trunk)
		trunk.CFrame = CFrame.new(pr.x, pr.height * 0.2, pr.z)
		trunk.Transparency = 1
		tidy(trunk, true, false)
		trunk.Parent = m
	end
	return true
end

function SceneryBuilder.build(parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	local pieces, props = LobbyScenery.layout()
	local meshed: { [number]: boolean } = {}
	for _, pr in props do
		meshed[pr.id] = placeMesh(folder, pr)
	end
	for _, p in pieces do
		if not meshed[p.prop] then
			local part: BasePart = if p.shape == "Wedge"
				then Instance.new("WedgePart")
				else Instance.new("Part")
			part.Name = p.kind
			part.Size = Vector3.new(p.sx, p.sy, p.sz)
			part.CFrame = CFrame.new(p.x, p.y, p.z)
				* CFrame.fromEulerAnglesYXZ(math.rad(p.rx), math.rad(p.ry), math.rad(p.rz))
			part.Color = Color3.fromRGB(p.r, p.g, p.b)
			part.Material = Enum.Material.SmoothPlastic
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			tidy(part, p.solid, p.kind ~= "Bush" and p.kind ~= "Fence")
			part.Parent = folder
		end
	end
	folder.Parent = parent
	return folder
end

return SceneryBuilder
