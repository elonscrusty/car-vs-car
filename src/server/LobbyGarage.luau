--!strict
-- The third batch of Blender lobby pieces (ServerStorage.Models.Garage): steel garage props, the
-- spin wheel, two leaderboards, wall fans, pendant lamps and a workstation in each garage. The
-- spin wheel's "Wheel" and the fans' "FanBlades" turn slowly. Look only. A missing model is skipped.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LobbyDecor = require(script.Parent.LobbyDecor)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)

local LobbyGarage = {}

local LEFT, RIGHT, BACK, FRONT = -math.pi / 2, math.pi / 2, math.pi, 0

-- Which part of a model turns, and how fast (radians a second).
local TURNING: { [string]: string } = {
	SpinWheel = "Wheel",
	WallFan = "FanBlades",
	BayTurntable = "Turntable",
}
local SPEED: { [string]: number } = { SpinWheel = 0.5, WallFan = 3, BayTurntable = 0.4 }

-- The wheel and the fan face forward, so they turn around their front-to-back axis; the turntable lies flat.
local FLAT: { [string]: boolean } = { BayTurntable = true }

type Spinner = { part: BasePart, base: CFrame, speed: number, flat: boolean }

function LobbyGarage.build(folder: Folder, origin: Vector3)
	local L = LobbyLayout
	local HL = L.room.halfL
	local group = Instance.new("Folder")
	group.Name = "Garage"
	group.Parent = folder

	local spinners: { Spinner } = {}
	local function put(
		name: string,
		x: number,
		y: number,
		z: number,
		yaw: number,
		glow: number?,
		source: string?
	)
		local m = LobbyDecor.clone(name, group, glow, source or "Garage")
		if m == nil then
			return
		end
		m:PivotTo(CFrame.new(origin + Vector3.new(x, y, z)) * CFrame.Angles(0, yaw, 0))
		local partName = TURNING[name]
		if partName then
			local part = m:FindFirstChild(partName, true)
			if part and part:IsA("BasePart") then
				table.insert(spinners, {
					part = part,
					base = part.CFrame,
					speed = SPEED[name],
					flat = FLAT[name] == true,
				})
			end
		end
	end

	-- Spin wheel out in the open, beside the hero stage where everyone walking up the lane can see
	-- it (it used to sit in the front corner). It faces the entrance.
	put("SpinWheel", -34, 0, -46, BACK, 18)

	-- Fans high on the back wall, lamps over the hall.
	put("WallFan", -38, 27, -HL + 2, BACK)
	put("WallFan", 38, 27, -HL + 2, BACK)
	for _, x in { -18, 18 } do
		for _, z in { 32, 4, -24 } do
			put("PendantLamp", x, 31, z, FRONT, 30)
		end
	end

	-- A little lounge extra and the bins.
	put("TrashBin", 31, 0, HL - 3, FRONT)
	put("WaterCooler", 56, 0, 66.5, RIGHT)

	-- Garage dressing: each garage keeps its LIFT on the left (LobbyBays) and the tool props on the
	-- RIGHT side, against the right-hand divider, so the walk-in opening stays empty. (The props
	-- used to stand in the side aisle in front of the garages.) Left and right are as seen from
	-- the door looking in.
	local BIG = { "TireRack", "Workbench", "Lockers", "PartsShelf" }
	local BIG_SRC =
		{ TireRack = "Decor", Workbench = "Decor", Lockers = "Garage", PartsShelf = "More" }
	local SMALL = { "ToolCart", "FireExtinguisher", "OilDrainCart", "SteelBench" }
	local SMALL_SRC = {
		ToolCart = "More",
		FireExtinguisher = "More",
		OilDrainCart = "Garage",
		SteelBench = "Garage",
	}
	local ART = { "SteeringWheelArt", "PlateWall", "WallClock", "PlateWall" }
	for i, b in L.bays do
		local side = if b.face > 0 then -1 else 1
		local yaw = if b.face > 0 then LEFT else RIGHT
		local art = ART[(i - 1) % #ART + 1]
		-- Wall art stays on the hall wall above each garage; plate tiles in the doorway.
		put(art, side * 62.3, 9, b.z - 13.5, yaw, nil, "More")
		for _, dz in { -4, 4 } do
			put("DiamondPlateTile", side * 56, 0.05, b.z + dz, 0)
		end
		local rightZ = b.z - b.face * 17.5 -- against the right-hand divider
		local big = BIG[(i - 1) % #BIG + 1]
		local small = SMALL[(i * 3 - 1) % #SMALL + 1]
		put(big, b.x + b.face * 1, 0, rightZ, yaw, nil, BIG_SRC[big])
		put(small, b.x + b.face * 5, 0, rightZ, yaw, nil, SMALL_SRC[small])
	end
	for _, side in { -1, 1 } do
		for _, z in { 32, 4, -24 } do
			put("PendantLamp", side * 46, 31, z, FRONT, 30)
		end
		-- Back left corner: lockers and a tool cabinet on the back wall. (The right corner belongs
		-- to the gumball machine and the left-center to the leaderboards.)
		if side < 0 then
			put("Lockers", side * 56, 0, -HL + 1.5, BACK)
			put("ToolWallCabinet", side * 47, 0, -HL + 1.5, BACK)
		end
	end
	put("PalletCrates", -60, 0, -HL + 4, BACK, nil, "More")

	-- A workstation on the back wall of each garage.
	for _, b in L.bays do
		local yaw = if b.face > 0 then LEFT else RIGHT
		put("Workstation", b.x - b.face * 21.5, 0, b.z, yaw)
	end

	if #spinners == 0 then
		return
	end
	local t = 0
	local acc = 0
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		acc += dt
		if acc < 0.05 then
			return
		end
		acc = 0
		for _, s in spinners do
			local a = t * s.speed
			s.part.CFrame = s.base
				* (if s.flat then CFrame.Angles(0, a, 0) else CFrame.Angles(0, 0, a))
		end
	end)
	folder.Destroying:Connect(function()
		conn:Disconnect()
	end)
end

return LobbyGarage
