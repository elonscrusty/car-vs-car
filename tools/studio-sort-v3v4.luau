-- Run in Studio's command bar (Edit mode) after importing game-models-v3 and game-models-v4.
-- Moves each imported model from Workspace into ServerStorage.Models.<Garage|Bowl> and makes the
-- Neon_* parts glow with their color.
local ServerStorage = game:GetService("ServerStorage")
local models = ServerStorage:FindFirstChild("Models") or Instance.new("Folder")
models.Name = "Models"
models.Parent = ServerStorage

local function folder(name: string): Folder
	local f = models:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = models
	end
	return f :: Folder
end

local where: { [string]: string } = {}
local function add(folderName: string, names: string)
	for n in string.gmatch(names, "%S+") do
		where[n] = folderName
	end
end

add(
	"Garage",
	"SteelWall_Panel RollerDoor_Closed SteelColumn Workstation Lockers ToolWallCabinet PendantLamp WallFan HoseReel OilDrainCart WheelBalancer SteelBench DiamondPlateTile SafetyBollard WheelStop Sign_GarageSteel SpinWheel Board_MostWins Board_BestStreak LobbyFloorTile LobbyFloorLogo Mezzanine_Section Mezzanine_Stairs RoofPanel RoofSkylight BayTurntable TrashBin WaterCooler Wall_Window"
)
add(
	"Bowl",
	"HillPlatform HillCrown HillFlag IceRimSegment IceBlocks IceCrystal Tree_SnowPine SnowPile Board_CarsLeft SoccerBall SoccerGoal_Blue SoccerGoal_Red SoccerFieldLines Board_SoccerScore BowlFloor BowlSlopeSegment_A BowlSlopeSegment_B GrassRingSegment Cloud_A Cloud_B Cloud_C Pickup_Shield Pickup_BigHit Pickup_Speed Pickup_Magnet Pickup_Rocket PickupBase Fx_ShieldBubble Fx_SlamRing Fx_DashTrail SpawnPad_1 SpawnPad_2 SpawnPad_3 SpawnPad_4 SpawnPad_5 SpawnPad_6 SpawnPad_7 SpawnPad_8"
)

local hex: { [string]: string } = {
	Neon_Cyan = "3DE8FF",
	Neon_Yellow = "FFD23D",
	Neon_Red = "FF3048",
	Neon_White = "F4FBFF",
	Neon_Pink = "FF5FC8",
	Neon_Green = "4DFF7A",
	Neon_Blue = "4696FF",
	Neon_Orange = "FF8A1F",
}

for _, c in workspace:GetChildren() do
	local dest = where[c.Name]
	if c:IsA("Model") and dest then
		for _, d in c:GetDescendants() do
			local color = hex[d.Name]
			if d:IsA("BasePart") and color then
				d.Material = Enum.Material.Neon
				d.Color = Color3.fromHex(color)
				if d:IsA("MeshPart") then
					d.TextureID = ""
				end
			end
		end
		c.Parent = folder(dest)
	end
end
