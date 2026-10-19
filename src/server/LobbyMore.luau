--!strict
-- The second batch of Blender lobby pieces (ServerStorage.Models.More): start lights over the lane,
-- a podium, the top racers board, a small lounge with arcade, vending machine and couch, a
-- traffic light, a PLAY sign, and a few garage tools. Few and deliberate. Look only. A missing
-- model is skipped. The booths are placed by LobbyProps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyDecor = require(script.Parent.LobbyDecor)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)

local LobbyMore = {}

local FRONT = 0

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

	-- No podium in the middle any more. The top racers board hangs on the front wall (it used to
	-- stand among the match pads).
	put("Leaderboard", -47, 0, HL - 2, FRONT)
	-- (The PLAY sign is built over the pads in Lobby.luau now, not beside the machines.)

	-- Lounge in the front corners.
	put("VendingMachine", 61, 0, HL - 2.5, FRONT) -- front wall, its front toward the hall (the paint booth has the corner)
	put("ArcadeCabinet", 32, 0, 90, FRONT)
	put("ArcadeCabinet", 38, 0, 90, FRONT)
	put("Couch", -33, 0, 90, FRONT)

	-- (No floating wall clock, steering wheel or plate art, and the per-garage tools are in
	-- LobbyGarage now, against the garage wall.)
end

return LobbyMore
