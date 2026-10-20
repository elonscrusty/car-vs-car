--!strict
-- carter's low-poly junkyard props (assets/lowpoly/props/*.fbx, imported in Studio into
-- ServerStorage.Models.Junk): Container, Crane, Crate, LightTower, PlayPad, RedBarrel, ScrapPile,
-- TireWall. Each one is a single MeshPart (or a Model holding one) with its long side along X.
-- `place` puts a look-only copy with the middle of its foot at `cf`, scaled to a height. A missing
-- model returns nil, so the map and the lobby keep their Part-built props until it is imported.

local ServerStorage = game:GetService("ServerStorage")

local MeshProps = {}

local function template(name: string): BasePart?
	local models = ServerStorage:FindFirstChild("Models")
	local junk = if models then models:FindFirstChild("Junk") else nil
	local src = if junk then junk:FindFirstChild(name) else nil
	if src == nil then
		return nil
	end
	if src:IsA("BasePart") then
		return src
	end
	return src:FindFirstChildWhichIsA("BasePart", true)
end

function MeshProps.has(name: string): boolean
	return template(name) ~= nil
end

-- A look-only copy of `name`, `height` studs tall (width and depth follow), or nil. `squash`
-- (optional) sets the height alone after the scale, for flat things like the play pad.
function MeshProps.place(
	name: string,
	parent: Instance,
	cf: CFrame,
	height: number,
	squash: number?
): Model?
	local src = template(name)
	if src == nil then
		return nil
	end
	local p = src:Clone()
	local k = height / math.max(src.Size.Y, 0.001)
	local size = src.Size * k
	if squash then
		size = Vector3.new(size.X, squash, size.Z)
	end
	p.Size = size
	p.Name = "Body"
	p.CFrame = cf * CFrame.new(0, size.Y / 2, 0)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = size.Y > 6 -- small props cast no shadow (cheap on phones)
	local m = Instance.new("Model")
	m.Name = name
	p.Parent = m
	m.PrimaryPart = p
	m.Parent = parent
	return m
end

return MeshProps
