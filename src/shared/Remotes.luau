--!strict
-- The only 5 RemoteEvents in the game. Server creates them, client waits for them.
--   SelectCar (client -> server): "I pick this car"
--   Launch    (client -> server): "launch with this angle and power"
--   UiUpdate  (server -> client): screen / HUD updates, hit effects
--   LobbyAction (client -> server): (action, arg) pickCar / buyGacha / buyCar / leavePad
--   LobbyUpdate (server -> client): lobby HUD, gacha, storeResult, countdown, choices, toLobby

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type RemoteSet = {
	SelectCar: RemoteEvent,
	Launch: RemoteEvent,
	UiUpdate: RemoteEvent,
	LobbyAction: RemoteEvent,
	LobbyUpdate: RemoteEvent,
}

local Remotes = {}

local function getOrMake(folder: Folder, name: string): RemoteEvent
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.get(): RemoteSet
	local folder: Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild("Remotes")
		if existing and existing:IsA("Folder") then
			folder = existing
		else
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		end
	else
		folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	return {
		SelectCar = getOrMake(folder, "SelectCar"),
		Launch = getOrMake(folder, "Launch"),
		UiUpdate = getOrMake(folder, "UiUpdate"),
		LobbyAction = getOrMake(folder, "LobbyAction"),
		LobbyUpdate = getOrMake(folder, "LobbyUpdate"),
	}
end

return Remotes
