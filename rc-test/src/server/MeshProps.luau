--!strict
-- carter's Meshy props, brought into Studio with Import 3D and kept in ServerStorage.LobbyMeshes,
-- named like their files (StreetLamp, Cone, TireStack, ...; /mnt/project-files/rc-game/props).
-- They live in the place, not in Rojo, so they can be missing: place() then returns nil and the
-- caller builds its block stand-in.
-- Import 3D brings them in about 100x too big with the front at +Z; place() sizes each one by
-- its height and turns its front to the spot's look direction.

local ServerStorage = game:GetService("ServerStorage")

local MeshProps = {}

local function template(name: string): Instance?
	local folder = ServerStorage:FindFirstChild("LobbyMeshes")
	local t = folder and folder:FindFirstChild(name)
	return if t and (t:IsA("Model") or t:IsA("BasePart")) then t else nil
end

-- Is this prop imported?
function MeshProps.has(name: string): boolean
	return template(name) ~= nil
end

-- A copy of prop `name`, `height` studs tall, standing on the floor at `at` with its front
-- looking along at.LookVector. Anchored. nil when it isn't imported.
function MeshProps.place(parent: Instance, name: string, at: CFrame, height: number): Model?
	local t = template(name)
	if not t then
		return nil
	end
	local m: Model
	if t:IsA("Model") then
		m = t:Clone()
	else
		m = Instance.new("Model")
		m.Name = name
		local p = (t :: BasePart):Clone()
		p.Parent = m
		m.PrimaryPart = p
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local _, size = m:GetBoundingBox()
	if size.Y > 0 then
		m:ScaleTo(m:GetScale() * height / size.Y)
	end
	-- pivot = middle of the bottom, upright, front (+Z) turned to look along -Z like a CFrame
	local box, sized = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(box.Position - Vector3.new(0, sized.Y / 2, 0))
		* CFrame.Angles(0, math.pi, 0)
	m:PivotTo(at)
	m.Parent = parent
	return m
end

return MeshProps
