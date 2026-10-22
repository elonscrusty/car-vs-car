--!strict
-- RC car feel test: builds the three tracks, gives every player a car and hands them its physics.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrackData = require(ReplicatedStorage.Shared.TrackData)
local CarBuilder = require(script.Parent.CarBuilder)
local TrackBuilder = require(script.Parent.TrackBuilder)

Players.CharacterAutoLoads = false

-- Fresh empty world: no default baseplate or spawn.
for _, name in { "Baseplate", "SpawnLocation" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

TrackBuilder.build()

local FIRST = TrackData.get(TrackData.order[1])

local function giveCar(player: Player)
	local s = FIRST.spawn
	local pos = Vector3.new(FIRST.originX + s.x, s.y, s.z)
	local cf = CFrame.lookAt(pos, pos + Vector3.new(s.dx, 0, s.dz))
	local car = CarBuilder.build("Car_" .. player.UserId, cf)
	car.Parent = workspace
	local body = car.PrimaryPart
	if body then
		body:SetNetworkOwner(player)
	end
	player:SetAttribute("CarReady", true)
end

Players.PlayerAdded:Connect(giveCar)
for _, p in Players:GetPlayers() do
	giveCar(p)
end

Players.PlayerRemoving:Connect(function(player)
	local car = workspace:FindFirstChild("Car_" .. player.UserId)
	if car then
		car:Destroy()
	end
end)
