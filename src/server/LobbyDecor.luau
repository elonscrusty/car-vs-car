--!strict
-- Blender decor for the lobby (ServerStorage.Models.Decor): neon signs, real car lifts and a few
-- hero props. Each model has its pivot at the bottom centre with the front toward -Z. Parts named
-- "Neon_*" glow. A missing model is simply skipped. Everything is look only (no collision).

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)

local LobbyDecor = {}

-- Is there a model with this name (in ServerStorage.Models.<source>, default "Decor")?
function LobbyDecor.has(name: string, source: string?): boolean
	local models = ServerStorage:FindFirstChild("Models")
	local dir = if models then models:FindFirstChild(source or "Decor") else nil
	local m = if dir then dir:FindFirstChild(name) else nil
	return m ~= nil and m:IsA("Model")
end

-- A look-only copy of a decor model (anchored, no collision, "Neon_*" parts glowing), or nil.
function LobbyDecor.clone(
	name: string,
	parent: Instance,
	glowRange: number?,
	source: string? -- the folder under ServerStorage.Models (default "Decor")
): Model?
	local models = ServerStorage:FindFirstChild("Models")
	local decor = if models then models:FindFirstChild(source or "Decor") else nil
	local src = if decor then decor:FindFirstChild(name) else nil
	if src == nil or not src:IsA("Model") then
		return nil
	end
	local m = src:Clone()
	local lit = false
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if string.sub(d.Name, 1, 5) == "Neon_" then
				d.Material = Enum.Material.Neon
				if glowRange and not lit then
					lit = true
					local l = Instance.new("PointLight")
					l.Color = d.Color
					l.Range = glowRange
					l.Brightness = 0.8
					l.Shadows = false
					l.Parent = d
				end
			end
		end
	end
	m.Parent = parent
	return m
end

-- Signs high on the walls. facing: yaw so the front looks into the hall.
local LEFT, RIGHT, BACK, FRONT = -math.pi / 2, math.pi / 2, math.pi, 0

type Sign = { name: string, x: number, z: number, y: number, yaw: number }

function LobbyDecor.build(parent: Folder, origin: Vector3)
	local room = LobbyLayout.room
	local HW, HL = room.halfW, room.halfL
	local group = Instance.new("Folder")
	group.Name = "Decor"
	group.Parent = parent

	local function put(name: string, x: number, y: number, z: number, yaw: number, glow: number?)
		local m = LobbyDecor.clone(name, group, glow)
		if m then
			m:PivotTo(CFrame.new(origin + Vector3.new(x, y, z)) * CFrame.Angles(0, yaw, 0))
		end
	end

	local SIGNS: { Sign } = {
		-- Left wall, above the garages.
		{ name = "Sign_Garage", x = -HW + 1, z = -40, y = 26.5, yaw = LEFT },
		{ name = "Sign_Wrench", x = -HW + 1, z = -8, y = 26.5, yaw = LEFT },
		{ name = "Sign_FlameTire", x = -HW + 1, z = 22, y = 26.5, yaw = LEFT },
		-- Right wall.
		{ name = "Sign_PitStop", x = HW - 1, z = -40, y = 26.5, yaw = RIGHT },
		{ name = "Sign_Piston", x = HW - 1, z = -8, y = 26.5, yaw = RIGHT },
		{ name = "Sign_Open247", x = HW - 1, z = 22, y = 26.5, yaw = RIGHT },
		-- Behind the player at the start, and the flags on the back wall.
		{ name = "Sign_CarVsCar", x = 0, z = HL - 1.5, y = 24, yaw = FRONT },
		{ name = "Sign_CheckerFlags", x = -52, z = -HL + 1.5, y = 22, yaw = BACK },
	}
	for _, s in SIGNS do
		put(s.name, s.x, s.y, s.z, s.yaw, 24)
	end

	-- One gas pump in the front corner, by the entrance.
	put("GasPump", -62, 0, 64, LEFT)
end

return LobbyDecor
