--!strict
-- Builds the lobby's outside look (LobbyScenery.pieces) as plain anchored Parts: trees, pines,
-- bushes, hedges, boulders, cliffs and fences. Looks only; solid pieces can be bumped into.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyScenery = require(ReplicatedStorage.Shared.LobbyScenery)

local SceneryBuilder = {}

function SceneryBuilder.build(parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	for _, p in LobbyScenery.pieces() do
		local part: BasePart = if p.shape == "Wedge"
			then Instance.new("WedgePart")
			else Instance.new("Part")
		part.Name = p.kind
		part.Anchored = true
		part.Size = Vector3.new(p.sx, p.sy, p.sz)
		part.CFrame = CFrame.new(p.x, p.y, p.z)
			* CFrame.fromEulerAnglesYXZ(math.rad(p.rx), math.rad(p.ry), math.rad(p.rz))
		part.Color = Color3.fromRGB(p.r, p.g, p.b)
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.CanCollide = p.solid
		part.CanTouch = false
		part.CanQuery = p.solid
		-- small bits don't need shadows (cheaper on phones)
		part.CastShadow = p.kind ~= "Bush" and p.kind ~= "Fence"
		part.Parent = folder
	end
	folder.Parent = parent
	return folder
end

return SceneryBuilder
