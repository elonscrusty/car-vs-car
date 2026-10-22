--!strict
-- RC car feel test: builds the tracks, gives every player a car and hands them its physics.
-- At real RC size the player also stands by the track holding a remote.

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

-- Client -> server: ("place", rc: boolean, trackIndex: number) when the size or track changes.
local remote = Instance.new("RemoteEvent")
remote.Name = "RCControl"
remote.Parent = ReplicatedStorage

local carScale: { [Player]: number } = {}
local lastAsk: { [Player]: number } = {}

local function spawnCF(t: TrackData.Track, rc: boolean): CFrame
	local s = t.spawn
	local x, y, z = TrackData.toWorld(t, rc, s.x, s.y, s.z)
	local pos = Vector3.new(x, y, z)
	return CFrame.lookAt(pos, pos + Vector3.new(s.dx, 0, s.dz))
end

local function giveCar(player: Player, t: TrackData.Track, rc: boolean)
	local name = "Car_" .. player.UserId
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local scale = if rc then TrackData.RC_SCALE else 1
	local car = CarBuilder.build(name, spawnCF(t, rc), scale)
	car.Parent = workspace
	local body = car.PrimaryPart
	if body then
		body:SetNetworkOwner(player)
	end
	carScale[player] = scale
end

local function addRemote(character: Model)
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not (hand and hand:IsA("BasePart")) then
		return
	end
	local box = Instance.new("Part")
	box.Name = "Remote"
	box.Size = Vector3.new(0.7, 0.25, 0.5)
	box.Color = Color3.fromRGB(35, 35, 40)
	box.CanCollide = false
	box.Massless = true
	box.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - 0.1, -0.2)
	box.Parent = character
	local antenna = Instance.new("Part")
	antenna.Name = "Antenna"
	antenna.Size = Vector3.new(0.06, 0.8, 0.06)
	antenna.Color = Color3.fromRGB(200, 200, 205)
	antenna.CanCollide = false
	antenna.Massless = true
	antenna.CFrame = box.CFrame * CFrame.new(0.25, 0.5, 0.15)
	antenna.Parent = character
	for _, p in { box, antenna } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = p
		weld.Parent = p
	end
end

-- Puts the player's person next to the small track (RC size), or removes them (big size).
local function placePerson(player: Player, t: TrackData.Track, rc: boolean)
	if not rc then
		local char = player.Character
		if char then
			char:Destroy()
			player.Character = nil
		end
		return
	end
	if player.Character == nil then
		player:LoadCharacter()
		local char = player.Character
		if char then
			addRemote(char)
		end
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (char and root and root:IsA("BasePart")) then
		return
	end
	local spot, lookX, lookZ = TrackData.standSpot(t)
	local x, _, z = TrackData.toWorld(t, true, spot.x, 0, spot.z)
	local fx, _, fz = TrackData.toWorld(t, true, lookX, 0, lookZ)
	local pos = Vector3.new(x, 3, z)
	root.Anchored = true -- the keys drive the car, not the person
	char:PivotTo(CFrame.lookAt(pos, Vector3.new(fx, 3, fz)))
end

remote.OnServerEvent:Connect(function(player: Player, kind: unknown, rc: unknown, index: unknown)
	if kind ~= "place" or type(rc) ~= "boolean" or type(index) ~= "number" then
		return
	end
	local i = math.floor(index)
	if i < 1 or i > #TrackData.order then
		return
	end
	local t = TrackData.get(TrackData.order[i])
	local want = if rc then TrackData.RC_SCALE else 1
	if carScale[player] ~= want then
		-- rebuilding the car is the costly part: at most 4 times a second
		local now = os.clock()
		if now - (lastAsk[player] or 0) < 0.25 then
			return
		end
		lastAsk[player] = now
		giveCar(player, t, rc)
	end
	placePerson(player, t, rc)
end)

local function onJoin(player: Player)
	giveCar(player, TrackData.get(TrackData.order[1]), false)
end

Players.PlayerAdded:Connect(onJoin)
for _, p in Players:GetPlayers() do
	onJoin(p)
end

Players.PlayerRemoving:Connect(function(player)
	local car = workspace:FindFirstChild("Car_" .. player.UserId)
	if car then
		car:Destroy()
	end
	carScale[player] = nil
	lastAsk[player] = nil
end)
