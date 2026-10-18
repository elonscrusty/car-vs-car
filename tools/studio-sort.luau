-- Run in Studio's command bar (Edit mode) after importing every .fbx from assets/models.
-- Imported models land in Workspace; this moves each one into ServerStorage.Models.<Folder>.
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
	"Shell",
	"BayDoorFrame BigSign_CarVsCar GarageFront_A1 GarageFront_A2 GarageFront_A3 GarageFront_A4 GarageFront_B1 GarageFront_B2 GarageFront_B3 GarageFront_B4 GarageRoom JoinPad_01 JoinPad_02 JoinPad_03 JoinPad_04 LaneChevrons LaneTrim RoofTruss TruckStage Wall_Panel Wall_Upper SpawnPad"
)
add(
	"Decor",
	"EngineStand FourPostLift GasPump OilDrum Pegboard ShopLight Sign_CarVsCar Sign_FlameTire Sign_Garage Sign_Open247 Sign_Piston Sign_Wrench TireRack ToolChest TwoPostLift Workbench"
)
add(
	"More",
	"AirCompressor ArcadeCabinet Booth_Paint Booth_Shop Couch FireExtinguisher FloorJack GasCan JackStands Leaderboard Podium Sign_Play TireChanger VendingMachine HydraulicPress PalletCrates PartsShelf PennantString PlateWall Sign_Bolt Sign_Nitro Sign_Turbo SteeringWheelArt ToolCart WallClock WeldingCart"
)
add(
	"Bowl",
	"AbilityPad Barrier BoostPad BowlRimSegment Cone FlagPole_Checker FlagPole_Racing Grandstand Hill LightTower OceanEdge RingRoadSegment Rock_A Rock_B TireStack Tree_Palm Tree_Pine Tree_Round BeachUmbrella Blimp Boat FinishArch HotAirBalloon Jumbotron Lighthouse PitWall Billboard Buoy CameraCrane ChevronBoard Dock FeatherFlag FerrisWheel FireworkLauncher TireWall VIPTower WaterTower"
)
add(
	"Props",
	"plant_box plant_box_yellow traffic_cone tire_stack oil_drum oil_drum_yellow roller_door claw_machine store_booth paint_booth"
)
add("Extras", "Coin Crate Trophy")

local moved, left = 0, {}
for _, m in workspace:GetChildren() do
	if m:IsA("Model") then
		if m.Name == "claw-machine-v1" then
			m.Name = "ClawMachine"
			m.Parent = models
			moved += 1
		elseif where[m.Name] then
			m.Parent = folder(where[m.Name])
			moved += 1
		else
			table.insert(left, m.Name)
		end
	end
end
print("moved", moved, "left in Workspace:", table.concat(left, ", "))
