--!strict
-- RC car feel test: builds the tracks, gives every player a car and hands them its physics.
-- People start walking in the lobby (small copies of the plots); on a plot's pad, E (or the
-- prompt's tap button) drives their car on the full-size plot from its stand, and E again (or
-- WALK) goes back to walking in the lobby.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local CarBuilder = require(script.Parent.CarBuilder)
local LobbyBuilder = require(script.Parent.LobbyBuilder)
local MiniCars = require(script.Parent.MiniCars)
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
local miniCars = MiniCars.new(workspace:WaitForChild("Lobby"))

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

-- Who drives what. A real track has one driver at a time; the lobby slot is the small plot they
-- started from (its sign, its copy car, where they come back to). Walking people are in none.
local driving: { [Player]: number } = {} -- player -> real track index
local drivingSlot: { [Player]: number } = {} -- player -> lobby slot index
local driverOf: { [number]: Player } = {} -- real track index -> player
local lastPrompt: { [Player]: number } = {}

local function setSign(slotIndex: number)
	local slot = slots[slotIndex]
	local who: Player? = nil
	for p, si in drivingSlot do
		if si == slotIndex then
			who = p
		end
	end
	lobby.signs[slotIndex].Text = if who then `{slot.label}\n{who.DisplayName}` else slot.label
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

-- Start (or move) a player's drive: real track `track`, shown on lobby slot `slotIndex`.
local function claim(player: Player, track: number, slotIndex: number)
	local old = driving[player]
	if old then
		driverOf[old] = nil
	end
	local oldSlot = drivingSlot[player]
	driving[player] = track
	drivingSlot[player] = slotIndex
	driverOf[track] = player
	if oldSlot and oldSlot ~= slotIndex then
		setSign(oldSlot)
	end
	setSign(slotIndex)
end

local function release(player: Player)
	miniCars.remove(player)
	local old = driving[player]
	if old then
		driverOf[old] = nil
		driving[player] = nil
	end
	local oldSlot = drivingSlot[player]
	drivingSlot[player] = nil
	if oldSlot then
		setSign(oldSlot)
	end
end

-- Off the stand, back in the lobby in front of that small plot, walking.
local function walk(player: Player)
	local slotIndex = drivingSlot[player]
	if slotIndex == nil then
		return
	end
	release(player)
	local root = rootOf(player)
	if not root then
		loadWalker(player)
	else
		local slot = slots[slotIndex]
		local pos = Vector3.new(slot.exitX, 3, slot.exitZ)
		local char = player.Character :: Model
		root.Anchored = false
		-- look along the road, toward the plaza
		char:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)))
	end
	remote:FireClient(player, "walk")
end

-- E on a lobby pad: drive that plot's track (if nobody else is), or stop driving.
for slotIndex, prompt in lobby.prompts do
	local slot = slots[slotIndex]
	prompt.Triggered:Connect(function(player: Player)
		local now = os.clock()
		if now - (lastPrompt[player] or 0) < 0.5 then
			return
		end
		lastPrompt[player] = now
		if drivingSlot[player] == slotIndex then
			walk(player)
			return
		end
		if driving[player] ~= nil or driverOf[slot.track] ~= nil then
			return
		end
		local root = rootOf(player)
		if not (root and LobbyLayout.inReach(slot, root.Position.X, root.Position.Z)) then
			return
		end
		claim(player, slot.track, slotIndex)
		remote:FireClient(player, "drive", slot.track)
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
	-- keep the slot they started from when it shows this track, else the first one that does
	-- (show has no lobby slot: keep the old one)
	local slotIndex = drivingSlot[player] :: number
	if slots[slotIndex].track ~= i then
		slotIndex = LobbyLayout.slotFor(i) or slotIndex
	end
	claim(player, i, slotIndex)
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

-- Start walking in the plaza, car parked in front of the start pad.
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

-- Copy cars: about 15 times a second, every driver's car is mirrored onto their plot's small
-- copy in the lobby (the car's physics runs on the driver's device; the server sees where it is).
local mirrorWait = 0
RunService.Heartbeat:Connect(function(dt: number)
	mirrorWait -= dt
	if mirrorWait > 0 then
		return
	end
	mirrorWait = 1 / 15
	for player, index in driving do
		local slot = slots[drivingSlot[player]]
		local car = workspace:FindFirstChild("Car_" .. player.UserId)
		local body = car and (car :: Model).PrimaryPart
		if not body then
			miniCars.place(player, nil)
			continue
		end
		local t = TrackData.get(TrackData.order[index])
		local rc = carScale[player] ~= 1
		local p = body.Position
		local lx, ly, lz = TrackData.toLocal(t, rc, p.X, p.Y, p.Z)
		-- the copy car only shows on a small plot of the same track (not while on show)
		local mx, my, mz = LobbyLayout.toMini(slot, lx, ly, lz)
		if mx == nil or slot.track ~= index then
			miniCars.place(player, nil)
		else
			local turn = CFrame.Angles(0, slot.angle, 0)
			miniCars.place(player, turn * body.CFrame.Rotation + Vector3.new(mx, my, mz))
		end
	end
end)
