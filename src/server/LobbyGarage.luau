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
	local function put(name: string, x: number, y: number, z: number, yaw: number, glow: number?)
		local m = LobbyDecor.clone(name, group, glow, "Garage")
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

	put("LobbyFloorLogo", 0, 0.12, 13, FRONT)

	-- Spin wheel in the front left corner, the two boards on the back wall.
	put("SpinWheel", -50, 0, HL - 2.5, FRONT, 18)
	put("Board_MostWins", -28, 0, -HL + 2.2, BACK, 18)
	put("Board_BestStreak", 29, 0, -HL + 2.2, BACK, 18)

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
