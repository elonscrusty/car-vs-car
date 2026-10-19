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
	local calm = source ~= "Bowl" -- the bowl keeps its red and white curbs; the lobby gets garage steel
	-- A steel-gray copy of the color sheet (red cells turned gray), set by hand once it is uploaded.
	local steel = if calm and models then models:GetAttribute("SteelPalette") else nil
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			local neon = string.sub(d.Name, 1, 5) == "Neon_"
			if steel and d:IsA("MeshPart") and d.TextureID ~= "" then
				d.TextureID = steel :: string
			end
			if calm and not neon then
				local c = d.Color
				if c.R > 0.6 and c.G < 0.35 and c.B < 0.35 then
					d.Color = Color3.fromRGB(78, 84, 96) -- racetrack red becomes garage steel
				end
			end
			if neon then
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
local LEFT, FRONT = -math.pi / 2, 0

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
		-- Right wall.
		-- Behind the player at the start, and the flags on the back wall.
		{ name = "Sign_CarVsCar", x = 0, z = HL - 1.5, y = 24, yaw = FRONT },
	}
	for _, s in SIGNS do
		put(s.name, s.x, s.y, s.z, s.yaw, 24)
	end

	-- One gas pump in the front corner, by the entrance.
	put("GasPump", -62, 0, 64, LEFT)
end

return LobbyDecor
