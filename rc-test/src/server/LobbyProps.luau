--!strict
-- Low-poly lobby props from plain blocks (flat colours, no text or logos): trees, lamps, cones
-- and tyres, the stand-ins for carter's meshes (MeshProps) until they are imported.

local LobbyProps = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end
LobbyProps.part = part

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local WOOD = rgb(140, 98, 60)
local DARK = rgb(45, 45, 52)
local LEAF = rgb(62, 140, 58)
local LEAF2 = rgb(84, 168, 70)
local CONCRETE = rgb(200, 198, 192)

-- A cylinder standing up (Roblox cylinders lie along x).
local function upright(cf: CFrame): CFrame
	return cf * CFrame.Angles(0, 0, math.pi / 2)
end

-- Low-poly tree: brown trunk and two stacked green blocks turned 45 degrees.
function LobbyProps.tree(parent: Instance, x: number, z: number, size: number)
	local m = Instance.new("Model")
	m.Name = "Tree"
	local s = size
	part(
		m,
		"Trunk",
		Vector3.new(1.2 * s, 1.2 * s, 1.2 * s) * Vector3.new(3, 1, 1),
		upright(CFrame.new(x, 1.8 * s, z)),
		WOOD,
		Enum.PartType.Cylinder
	)
	part(
		m,
		"Leaves",
		Vector3.new(5, 4, 5) * s,
		CFrame.new(x, 5 * s, z) * CFrame.Angles(0, math.pi / 4, 0),
		LEAF
	)
	part(
		m,
		"Top",
		Vector3.new(3.2, 3, 3.2) * s,
		CFrame.new(x, 7.8 * s, z) * CFrame.Angles(0, math.pi / 8, 0),
		LEAF2
	)
	m.Parent = parent
end

-- Street lamp: dark post, warm light box on top with a real light.
function LobbyProps.lamp(parent: Instance, x: number, z: number)
	local m = Instance.new("Model")
	m.Name = "Lamp"
	part(m, "Base", Vector3.new(1.4, 0.6, 1.4), CFrame.new(x, 0.3, z), CONCRETE)
	part(m, "Post", Vector3.new(0.5, 9, 0.5), CFrame.new(x, 4.8, z), DARK)
	part(m, "Cap", Vector3.new(1.6, 0.4, 1.6), CFrame.new(x, 10.6, z), DARK)
	local glow =
		part(m, "Light", Vector3.new(1.2, 1.2, 1.2), CFrame.new(x, 9.8, z), rgb(255, 226, 150))
	glow.Material = Enum.Material.Neon
	glow.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Color = rgb(255, 214, 150)
	light.Parent = glow
	m.Parent = parent
end

-- Traffic cone (block stand-in for the Cone mesh).
function LobbyProps.cone(parent: Instance, x: number, z: number)
	local m = Instance.new("Model")
	m.Name = "Cone"
	part(m, "Base", Vector3.new(1.2, 0.2, 1.2), CFrame.new(x, 0.1, z), DARK)
	part(m, "Cone", Vector3.new(0.7, 1.2, 0.7), CFrame.new(x, 0.8, z), rgb(240, 120, 40))
	m.Parent = parent
end

-- Stack of three tyres (block stand-in for the TireStack mesh).
function LobbyProps.tires(parent: Instance, x: number, z: number)
	local m = Instance.new("Model")
	m.Name = "TireStack"
	for i = 0, 2 do
		part(
			m,
			"Tire",
			Vector3.new(0.8, 2.4, 2.4),
			upright(CFrame.new(x, 0.4 + i * 0.8, z)),
			rgb(35, 35, 38),
			Enum.PartType.Cylinder
		)
	end
	m.Parent = parent
end

return LobbyProps
