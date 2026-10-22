--!strict
-- RC car feel test: builds the tracks, gives every player a car and hands them its physics.
-- People start walking in the lobby (small copies of the plots); on a plot's pad, E (or the
-- prompt's tap button) drives their car on the full-size plot from its stand, and E again (or
-- WALK) goes back to walking in the lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local CarBuilder = require(script.Parent.CarBuilder)
local LobbyBuilder = require(script.Parent.LobbyBuilder)
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
local lobby = LobbyBuilder.build()
local slots = LobbyLayout.slots()

-- Client -> server: ("place", rc: boolean, trackIndex: number) when the size or track changes
-- (only while driving), ("walk") to leave the stand.
-- Server -> client: ("drive", trackIndex) and ("walk").
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

local function giveCar(player: Player, t: TrackData.Track, rc: boolean, at: CFrame?)
	local name = "Car_" .. player.UserId
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local scale = if rc then TrackData.RC_SCALE else 1
	local car = CarBuilder.build(name, at or spawnCF(t, rc), scale)
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
	-- on top of the raised driver stand
	local y = 3 + TrackData.STAND_H * TrackData.RC_SCALE
	local pos = Vector3.new(x, y, z)
	root.Anchored = true -- the keys drive the car, not the person
	char:PivotTo(CFrame.lookAt(pos, Vector3.new(fx, y, fz)))
end

-- Who drives which plot (one driver per plot). Walking people are in neither table.
local driving: { [Player]: number } = {}
local driverOf: { [number]: Player } = {}
local lastPrompt: { [Player]: number } = {}

local function setSign(index: number)
	local who = driverOf[index]
	lobby.signs[index].Text = if who
		then `{slots[index].label}\n{who.DisplayName} is driving`
		else `{slots[index].label}\nFREE - press E on the pad`
end
for i in slots do
	setSign(i)
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function loadWalker(player: Player)
	player:LoadCharacter()
	local char = player.Character
	if not char then
		return
	end
	addRemote(char)
	local x, y, z = LobbyLayout.spawn()
	char:PivotTo(CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x, y, z - 1)))
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			task.wait(3)
			if player.Parent and player.Character == char and driving[player] == nil then
				loadWalker(player)
			end
		end)
	end
end

local function claim(player: Player, index: number)
	local old = driving[player]
	if old then
		driverOf[old] = nil
		setSign(old)
	end
	driving[player] = index
	driverOf[index] = player
	setSign(index)
end

local function release(player: Player)
	local old = driving[player]
	if old then
		driverOf[old] = nil
		driving[player] = nil
		setSign(old)
	end
end

-- Off the stand, back in the lobby in front of that small plot, walking.
local function walk(player: Player)
	local index = driving[player]
	if index == nil then
		return
	end
	release(player)
	local root = rootOf(player)
	if not root then
		loadWalker(player)
	else
		local slot = slots[index]
		local pos = Vector3.new(slot.exitX, 3, slot.exitZ)
		local char = player.Character :: Model
		root.Anchored = false
		char:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)))
	end
	remote:FireClient(player, "walk")
end

-- E on a lobby pad: drive that plot (if nobody else is), or stop driving.
for index, prompt in lobby.prompts do
	prompt.Triggered:Connect(function(player: Player)
		local now = os.clock()
		if now - (lastPrompt[player] or 0) < 0.5 then
			return
		end
		lastPrompt[player] = now
		if driving[player] == index then
			walk(player)
			return
		end
		if driving[player] ~= nil or driverOf[index] ~= nil then
			return
		end
		local root = rootOf(player)
		if not (root and LobbyLayout.inReach(slots[index], root.Position.X, root.Position.Z)) then
			return
		end
		claim(player, index)
		remote:FireClient(player, "drive", index)
	end)
end

remote.OnServerEvent:Connect(function(player: Player, kind: unknown, rc: unknown, index: unknown)
	if kind == "walk" then
		local now = os.clock()
		if now - (lastPrompt[player] or 0) >= 0.5 then
			lastPrompt[player] = now
			walk(player)
		end
		return
	end
	if kind ~= "place" or type(rc) ~= "boolean" or type(index) ~= "number" then
		return
	end
	local i = math.floor(index)
	if i < 1 or i > #TrackData.order then
		return
	end
	-- only drivers move their car; the plot keys may switch to a plot nobody else is driving
	if driving[player] == nil or (driverOf[i] ~= nil and driverOf[i] ~= player) then
		return
	end
	claim(player, i)
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

-- Start walking on the street, car parked beside the start pad.
local joined = 0
local function onJoin(player: Player)
	joined += 1
	local px, pz = LobbyLayout.parkSpot(joined)
	local park = CFrame.lookAt(Vector3.new(px, 1, pz), Vector3.new(px, 1, pz - 1))
	giveCar(player, TrackData.get(TrackData.order[1]), true, park)
	loadWalker(player)
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
	lastPrompt[player] = nil
	release(player)
end)
