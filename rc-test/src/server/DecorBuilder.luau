--!strict
-- Builds the street decorations (LobbyDecor): block stand-ins, then carter's Meshy props in
-- place of them where they are imported (ServerStorage.LobbyMeshes): LobbyDecor.MESHES through
-- Garage.useMeshes, and LobbyDecor.FACED (props that must face the road) through MeshProps.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Garage = require(ReplicatedStorage.Shared.Garage)
local LobbyDecor = require(ReplicatedStorage.Shared.LobbyDecor)
local MeshProps = require(script.Parent.MeshProps)

local DecorBuilder = {}

function DecorBuilder.build(parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Decor"
	local groups = Garage.makeParts(LobbyDecor.parts(), model, CFrame.identity)
	Garage.useMeshes(groups, CFrame.identity, LobbyDecor.MESHES)
	local swapped: { [string]: boolean } = {}
	for _, f in LobbyDecor.FACED do
		local group = groups[f.group]
		local at = Vector3.new(f.at.x, f.at.y, f.at.z)
		local cf = CFrame.lookAt(at, at + Vector3.new(f.face.x, f.face.y, f.face.z))
		local prop = group and MeshProps.place(group, f.model, cf, f.height)
		if prop then
			for _, d in prop:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanCollide = f.collide
					d.CanTouch = false
				end
			end
			-- the stand-ins it replaces go (once per group, never the props already placed)
			if not swapped[f.group] then
				swapped[f.group] = true
				for _, part in (group :: Model):GetChildren() do
					if part:IsA("BasePart") and not table.find(f.keep, part.Name) then
						part:Destroy()
					end
				end
			end
		end
	end
	model.Parent = parent
	return model
end

return DecorBuilder
