--!strict
-- RC car feel test: builds the tracks, gives every player a car and hands them its physics.
-- People start walking in the lobby, whose plots ARE the tracks: on a plot's pad, E (or the
-- DRIVE button) drives their car on that plot right there, from its stand, and E again (or
-- WALK) goes back to walking. Everyone on the street sees every drive live.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local TrackData = require(ReplicatedStorage.Shared.TrackData)
local CarBuilder = require(script.Parent.CarBuilder)
local LobbyBuilder = require(script.Parent.LobbyBuilder)
local LobbyPlots = require(script.Parent.LobbyPlots)
local TrackBuilder = require(script.Parent.TrackBuilder)
local PlotDecorBuilder = require(script.Parent.PlotDecorBuilder)
local PlotLooksBuilder = require(script.Parent.PlotLooksBuilder)
local PlotShop = require(script.Parent.PlotShop)

Players.CharacterAutoLoads = false

-- Fresh empty world: no default baseplate or spawn.
for _, name in { "Baseplate", "SpawnLocation" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

TrackBuilder.build()
PlotDecorBuilder.build()
PlotLooksBuilder.start()
PlotShop.start()
local lobby = LobbyBuilder.build()
LobbyPlots.init()
require(script.Parent.PlotStandsBuilder).start() -- owners' cars on their plot's stands
local slots = LobbyLayout.slots()

-- Client -> server: ("place", rc: boolean, slotIndex: number) when a drive (re)starts (only
-- while driving that plot), ("walk") to leave the stand, ("open", on: boolean) to let friends
-- drive your plot, ("quick") for QUICK RACE (a free race plot).
-- Server -> client: ("drive", slotIndex), ("walk"), ("own", slotIndex, open) for your plot,
-- ("closed") when a pad tap can't drive that plot and ("noRace") when QUICK RACE found none.
local remote = Instance.new("RemoteEvent")
remote.Name = "RCControl"
remote.Parent = ReplicatedStorage

local carScale: { [Player]: number } = {}
local lastAsk: { [Player]: number } = {}

local function spawnCF(t: TrackData.Track, rc: boolean): CFrame
	local s = t.spawn
	local x, y, z = TrackData.toWorld(t, rc, s.x, s.y, s.z)
	local dx, dz = TrackData.dirToWorld(t, rc, s.dx, s.dz)
	local pos = Vector3.new(x, y, z)
	return CFrame.lookAt(pos, pos + Vector3.new(dx, 0, dz))
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

-- Who owns and drives what: LobbyPlots.
local lastPrompt: { [Player]: number } = {}

-- the name board over each plot's entrance arch (PlotDecor's), road side: same text as the sign
local archNames: { [number]: TextLabel } = {}
for _, d in workspace.Plots:GetDescendants() do
	local slotIndex = d:GetAttribute("Slot")
	if d:IsA("BasePart") and d:GetAttribute("NameBoard") and typeof(slotIndex) == "number" then
		local gui = Instance.new("SurfaceGui")
		gui.Face = (Enum.NormalId :: any)[d:GetAttribute("NameFace") or "Back"]
		-- one canvas pixel per 1/50 stud, so the letters keep their shape on a long thin board
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = d
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(30, 30, 34)
		text.Parent = gui
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0.06, 0)
		padding.PaddingRight = UDim.new(0.06, 0)
		padding.PaddingTop = UDim.new(0.1, 0)
		padding.PaddingBottom = UDim.new(0.1, 0)
		padding.Parent = text
		archNames[slotIndex] = text
	end
end

local function setSign(slotIndex: number)
	local owner = LobbyPlots.ownerOf(slotIndex)
	local who = LobbyPlots.driverOf(slotIndex) or owner
	local text = LobbyLayout.signText(
		if who then who.DisplayName else nil,
		slots[slotIndex].label,
		owner ~= nil and LobbyPlots.isOpen(slotIndex)
	)
	lobby.signs[slotIndex].Text = text
	local arch = archNames[slotIndex]
	if arch then
		arch.Text = text
	end
end
for i in slots do
	setSign(i)
end
LobbyPlots.changed:Connect(function(slotIndex: number)
	setSign(slotIndex)
	local owner = LobbyPlots.ownerOf(slotIndex)
	if owner and owner.Parent then
		remote:FireClient(owner, "own", slotIndex, LobbyPlots.isOpen(slotIndex))
	end
end)

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
	char:PivotTo(lobby.spawn or CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x, y, z + 1)))
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			task.wait(3)
			if
				player.Parent
				and player.Character == char
				and LobbyPlots.drivingOf(player) == nil
			then
				loadWalker(player)
			end
		end)
	end
end

LobbyPlots.onDrive = function(player: Player, slotIndex: number)
	remote:FireClient(player, "drive", slotIndex)
end

-- The spawn lobby's drift / race / rock pads: stand on one to go drive an open plot of that kind.
require(script.Parent.QueuePads).start({
	findOpen = LobbyPlots.findOpen,
	sendTo = LobbyPlots.sendTo,
})

-- Off the stand, back on that plot's pad, walking.
local function walk(player: Player)
	local slotIndex = LobbyPlots.release(player)
	if slotIndex == nil then
		return
	end
	local root = rootOf(player)
	if not root then
		loadWalker(player)
	else
		local slot = slots[slotIndex]
		local pos = Vector3.new(slot.exitX, 3, slot.exitZ)
		local char = player.Character :: Model
		root.Anchored = false
		-- facing the road
		char:PivotTo(CFrame.lookAt(pos, Vector3.new(0, 3, slot.exitZ)))
	end
	remote:FireClient(player, "walk")
end

-- E on a lobby pad: drive that plot (if it's yours, nobody's or open, and free), or stop.
for slotIndex, prompt in lobby.prompts do
	local slot = slots[slotIndex]
	prompt.Triggered:Connect(function(player: Player)
		local now = os.clock()
		if now - (lastPrompt[player] or 0) < 0.5 then
			return
		end
		lastPrompt[player] = now
		if LobbyPlots.drivingOf(player) == slotIndex then
			walk(player)
			return
		end
		local root = rootOf(player)
		if not (root and LobbyLayout.inReach(slot, root.Position.X, root.Position.Z)) then
			return
		end
		if not LobbyPlots.sendTo(player, slotIndex) then
			remote:FireClient(player, "closed") -- someone else's plot, not open (or busy)
		end
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
	if kind == "quick" then
		-- QUICK RACE from the lobby: the best free race plot (their own first), like the race pad
		local now = os.clock()
		if now - (lastPrompt[player] or 0) < 0.5 or LobbyPlots.drivingOf(player) ~= nil then
			return
		end
		lastPrompt[player] = now
		local slot = LobbyPlots.findOpen("race", player)
		if not slot or not LobbyPlots.sendTo(player, slot) then
			remote:FireClient(player, "noRace")
		end
		return
	end
	if kind == "open" then
		if type(rc) == "boolean" then
			LobbyPlots.setOpen(player, rc)
		end
		return
	end
	if kind ~= "place" or type(rc) ~= "boolean" or type(index) ~= "number" then
		return
	end
	-- only the plot being driven (the big test size is gone with the big plots)
	local i = math.floor(index)
	if not rc or LobbyPlots.drivingOf(player) ~= i then
		return
	end
	local t: TrackData.Track = LobbyLayout.track(i)
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

-- Start walking in the spawn lobby, car parked at the top of the road.
local joined = 0
local function onJoin(player: Player)
	joined += 1
	local px, pz = LobbyLayout.parkSpot(joined)
	local park = CFrame.lookAt(Vector3.new(px, 1, pz), Vector3.new(px, 1, pz + 1))
	giveCar(player, TrackData.get(TrackData.order[1]), true, park)
	LobbyPlots.addPlayer(player)
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
	LobbyPlots.removePlayer(player)
end)
