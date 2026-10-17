--!strict
-- Real (Blender) props for the lobby. They live in ServerStorage.Models.Props, are named like the
-- file they came from, and have their pivot at the bottom centre with the front toward -Z.
-- Look only: nothing collides. A missing prop is skipped, so the lobby still builds without them.

local ServerStorage = game:GetService("ServerStorage")

local LobbyProps = {}

local FLOOR_TOP = 0 -- the lobby origin sits on the floor surface

type Spot = { name: string, x: number, z: number, face: number, y: number?, scale: number? }

-- face: degrees. 0 looks toward the back of the hall (-Z), 180 toward the gate, 90 toward -X, -90 toward +X.
local SPOTS: { Spot } = {
	-- cones either side of the start line and the pad row
	{ name = "traffic_cone", x = -9, z = 40, face = 0 },
	{ name = "traffic_cone", x = 9, z = 40, face = 0 },
	{ name = "traffic_cone", x = -38, z = 28, face = 0 },
	{ name = "traffic_cone", x = 38, z = 24, face = 0 },
	-- drum cluster and gas cans in the front corners
	{ name = "oil_drum", x = 55, z = 37, face = 20 },
	{ name = "oil_drum", x = 53, z = 39.5, face = 70 },
	{ name = "oil_drum", x = 55, z = 41, face = 130 },
	{ name = "gas_can", x = -54, z = 40, face = 25, scale = 1.6 },
	{ name = "gas_can", x = -52.5, z = 41.5, face = -20, scale = 1.6 },
	-- tires, a chest and a cart on the right side
	{ name = "tire_stack", x = 56, z = -8, face = 0 },
	{ name = "tire_stack", x = 53.5, z = -9.5, face = 40 },
	{ name = "tool_chest", x = 56, z = -2, face = 90 },
	{ name = "tool_cart", x = 36, z = -32, face = 90 },
	{ name = "plant_box", x = -40, z = 38, face = 0 },
	{ name = "plant_box", x = 40, z = 38, face = 0 },
	-- wall pieces on the back wall
	{ name = "pegboard_tools", x = -28, z = -44.6, face = 180, y = 5 },
	{ name = "pegboard_tools", x = 28, z = -44.6, face = 180, y = 5 },
}

local SCALE = 1.4

function LobbyProps.build(folder: Folder, origin: Vector3)
	local models = ServerStorage:FindFirstChild("Models")
	local props = if models then models:FindFirstChild("Props") else nil
	if props == nil then
		return
	end
	local group = Instance.new("Folder")
	group.Name = "Props"
	group.Parent = folder
	for _, s in SPOTS do
		local src = props:FindFirstChild(s.name)
		if src ~= nil and src:IsA("Model") then
			local m = src:Clone()
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
					d.CastShadow = false
				end
			end
			m:ScaleTo(m:GetScale() * (s.scale or SCALE))
			m:PivotTo(
				CFrame.new(origin + Vector3.new(s.x, FLOOR_TOP + (s.y or 0), s.z))
					* CFrame.Angles(0, math.rad(s.face), 0)
			)
			m.Parent = group
		end
	end
end

return LobbyProps
