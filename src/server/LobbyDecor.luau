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

-- One kind of sign plate for the whole lobby: navy plate, white text, one yellow underline.
-- `cf` puts the plate's middle; its front (-Z) shows the text.
local PLATE_NAVY = Color3.fromRGB(22, 36, 66)
local PLATE_YELLOW = Color3.fromRGB(255, 205, 40)
function LobbyDecor.plate(parent: Instance, text: string, size: Vector3, cf: CFrame): Part
	local plate = Instance.new("Part")
	plate.Name = "SignPlate"
	plate.Size = size
	plate.CFrame = cf
	plate.Color = PLATE_NAVY
	plate.Material = Enum.Material.SmoothPlastic
	plate.Anchored = true
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	plate.CastShadow = false
	plate.Parent = parent
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = plate
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.62)
	label.Position = UDim2.fromScale(0.05, 0.08)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = gui
	local line = Instance.new("Part")
	line.Name = "SignUnderline"
	line.Size = Vector3.new(size.X * 0.5, size.Y * 0.07, 0.2)
	line.CFrame = cf * CFrame.new(0, -size.Y * 0.3, -size.Z / 2 - 0.05)
	line.Color = PLATE_YELLOW
	line.Material = Enum.Material.SmoothPlastic
	line.Anchored = true
	line.CanCollide = false
	line.CanQuery = false
	line.CanTouch = false
	line.CastShadow = false
	line.Parent = parent
	return plate
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

function LobbyDecor.build(parent: Folder, origin: Vector3)
	local room = LobbyLayout.room
	local HW, HL = room.halfW, room.halfL
	local group = Instance.new("Folder")
	group.Name = "Decor"
	group.Parent = parent

	-- The two lobby signs share one plate look (LobbyDecor.plate).
	LobbyDecor.plate(
		group,
		"GARAGES",
		Vector3.new(20, 5, 0.6),
		CFrame.lookAt(origin + Vector3.new(-HW + 1, 26.5, -40), origin + Vector3.new(0, 26.5, -40))
	)
	LobbyDecor.plate(
		group,
		"CAR VS CAR",
		Vector3.new(28, 6.5, 0.6),
		CFrame.lookAt(origin + Vector3.new(0, 24, HL - 1.5), origin + Vector3.new(0, 24, 0))
	)
end

return LobbyDecor
