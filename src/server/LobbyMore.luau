--!strict
-- The second batch of Blender lobby pieces (ServerStorage.Models.More): start lights over the lane,
-- a podium, the top racers board, a small lounge with arcade, vending machine and couch, a
-- traffic light, a PLAY sign, and a few garage tools. Few and deliberate. Look only. A missing
-- model is skipped. The booths are placed by LobbyProps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyDecor = require(script.Parent.LobbyDecor)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)

local LobbyMore = {}

local LEFT, RIGHT, BACK, FRONT = -math.pi / 2, math.pi / 2, math.pi, 0

function LobbyMore.build(folder: Folder, origin: Vector3)
	local L = LobbyLayout
	local HL = L.room.halfL
	local group = Instance.new("Folder")
	group.Name = "More"
	group.Parent = folder

	local function put(name: string, x: number, y: number, z: number, yaw: number)
		local m = LobbyDecor.clone(name, group, nil, "More")
		if m then
			m:PivotTo(CFrame.new(origin + Vector3.new(x, y, z)) * CFrame.Angles(0, yaw, 0))
		end
	end

	-- The start lights hang on the front wall (over the lane they hid the stage).
	put("Podium", 24, 0, -54, BACK)
	put("Sign_Nitro", -52, 24, -HL + 1.5, BACK)
	put("Sign_Turbo", 52, 24, -HL + 1.5, BACK)
	put("Sign_Bolt", -L.room.halfW + 1, 26.5, 84, LEFT)
	put("Leaderboard", -50, 0, -64, BACK)
	put("Sign_Play", 40, 22, HL - 1.5, FRONT)

	-- Lounge in the front corners.
	put("VendingMachine", 61, 0, 86, RIGHT)
	put("ArcadeCabinet", 32, 0, 90, FRONT)
	put("ArcadeCabinet", 38, 0, 90, FRONT)
	put("Couch", -33, 0, 90, FRONT)

	-- A tool and a shelf or cart in each garage, by the back wall.
	local tools = { "TireChanger", "AirCompressor", "FloorJack", "JackStands" }
	for i, b in L.bays do
		local yaw = if b.face > 0 then LEFT else RIGHT
		put(tools[(i - 1) % #tools + 1], b.x - b.face * 17, 0, b.z + 10, yaw)
		put(if i % 2 == 1 then "PartsShelf" else "ToolCart", b.x - b.face * 21, 0, b.z - 10, yaw)
	end

	-- Small wall pieces by the store and the paint booth.
	put("PlateWall", -L.room.halfW + 0.6, 8, 84, LEFT)
	put("SteeringWheelArt", -L.room.halfW + 0.6, 12, 90, LEFT)
	put("WallClock", L.room.halfW - 0.6, 11, 84, RIGHT)
end

return LobbyMore
