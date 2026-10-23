--!strict
-- Builds the street decorations (LobbyDecor): block stand-ins, then carter's Meshy props in
-- place of them where they are imported (ServerStorage.LobbyMeshes, see Garage.useMeshes).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Garage = require(ReplicatedStorage.Shared.Garage)
local LobbyDecor = require(ReplicatedStorage.Shared.LobbyDecor)

local DecorBuilder = {}

function DecorBuilder.build(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Decor"
	local groups = Garage.makeParts(LobbyDecor.parts(), model, CFrame.identity)
	Garage.useMeshes(groups, CFrame.identity, LobbyDecor.MESHES)
	model.Parent = parent
	return model
end

return DecorBuilder
