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
	-- cones either side of the start line
	{ name = "traffic_cone", x = -9, z = 66, face = 0 },
	{ name = "traffic_cone", x = 9, z = 66, face = 0 },
	{ name = "traffic_cone", x = -9, z = 22, face = 0 },
	{ name = "traffic_cone", x = 9, z = 22, face = 0 },
	-- drum cluster and gas cans by the gate
	{ name = "oil_drum", x = 33.5, z = 62, face = 20 },
	{ name = "oil_drum", x = 31.5, z = 64, face = 70 },
	{ name = "oil_drum", x = 33.5, z = 65.5, face = 130 },
	{ name = "gas_can", x = -31, z = 65, face = 25, scale = 1.6 },
	{ name = "gas_can", x = -29.5, z = 66.5, face = -20, scale = 1.6 },
	-- tires and a chest near the pad end
	{ name = "tire_stack", x = -34, z = -32, face = 0 },
	{ name = "tire_stack", x = -31.5, z = -33.5, face = 40 },
	{ name = "tool_chest", x = 34, z = -36, face = 90 },
	{ name = "tool_cart", x = 33, z = -42, face = 90 },
	{ name = "plant_box", x = 34, z = -4, face = 90 },
	{ name = "plant_box", x = -34, z = 52, face = -90 },
	-- wall pieces
	{ name = "pegboard_tools", x = -30, z = -70.8, face = 180, y = 7 },
	{ name = "pegboard_tools", x = 30, z = -70.8, face = 180, y = 7 },
	{ name = "neon_sign", x = -35.2, z = -58, face = -90, y = 10, scale = 1.2 },
	{ name = "neon_sign", x = 35.2, z = -58, face = 90, y = 10, scale = 1.2 },
	{ name = "tv_stand", x = -34, z = 62, face = -90 },
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
