--!strict
-- Builds the water round the lobby (LobbyWater: bank, shore, water, docks, island, footbridge)
-- into workspace.Lobby.Water. Looks only. Called at the end of LobbyBuilder.build().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyWater = require(ReplicatedStorage.Shared.LobbyWater)
local LobbyProps = require(script.Parent.LobbyProps)

local LobbyWaterBuilder = {}

function LobbyWaterBuilder.build(lobby: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Water"
	for _, pc in LobbyWater.pieces() do
		local cf = CFrame.new(pc.x, pc.y, pc.z)
			* CFrame.Angles(0, math.rad(pc.ry), 0)
			* CFrame.Angles(0, 0, math.rad(pc.rz))
		local size = Vector3.new(pc.sx, pc.sy, pc.sz)
		if pc.round then
			-- a Cylinder's round faces point along its X, so stand it up
			cf *= CFrame.Angles(0, 0, math.rad(90))
			size = Vector3.new(pc.sy, pc.sx, pc.sz)
		end
		local p = LobbyProps.part(
			folder,
			pc.name,
			size,
			cf,
			Color3.fromRGB(pc.color[1], pc.color[2], pc.color[3]),
			if pc.round then Enum.PartType.Cylinder else nil
		)
		p.CanCollide = pc.collide
		if not pc.collide then
			p.CanQuery = false
			p.CanTouch = false
		end
		if pc.hidden then
			p.Transparency = 1
		end
		-- nothing here moves, so let the engine skip shadows on the big flat sheets
		if pc.sx * pc.sz > 2000 then
			p.CastShadow = false
		end
	end
	folder.Parent = lobby
end

return LobbyWaterBuilder
