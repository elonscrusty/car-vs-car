--!strict
-- Lobby, player side: while driving, a WALK button (phone) and the E key ask the server to go
-- back to walking, and the stand prompts are hidden on this screen. While walking, the stand
-- prompts (E or tap) ask the server to drive; the server answers with "drive" / "walk".
-- Standing on a pad also shows a big DRIVE button in the same spot, for a thumb on a phone.
-- While walking, a FRIENDS button at the top lets the owner of a plot let others drive it, and a
-- light column with a YOUR PLOT sign stands on your own plot's pad (this screen only), so a new
-- player sees from the spawn lobby where to go.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local HudLayout = require(ReplicatedStorage.Shared.HudLayout)
local KartStyle = require(ReplicatedStorage.Shared.KartStyle)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local SoundLevels = require(ReplicatedStorage.Shared.SoundLevels)
local PlotGuide = require(script.Parent.PlotGuide)
local StageGate = require(script.Parent.StageGate)

local Lobby = {}

-- A see-through light column on a pad with a YOUR PLOT sign on top, seen from far away.
local SIGN_Y = 24 -- YOUR PLOT sign height (studs): on screen from the spawn, over the pad words
local function makeMarker(x: number, z: number): Model
	local marker = Instance.new("Model")
	marker.Name = "YourPlotMarker"
	local height = 60 -- tall enough to see over the hills from the spawn
	-- a bright core inside a wide soft glow
	local function beam(name: string, width: number, alpha: number): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(height, width, width)
		p.CFrame = CFrame.new(x, height / 2, z) * CFrame.Angles(0, 0, math.pi / 2)
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 220, 90)
		p.Transparency = alpha
		p:SetAttribute("Alpha", alpha)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = marker
		return p
	end
	local column = beam("Light", 4, 0.15)
	beam("Glow", 10, 0.75)
	-- the sign sits low enough to be on a phone screen from the spawn and above the spawn
	-- lobby's pad words
	local sign = Instance.new("BillboardGui")
	-- pixel size, so it reads the same from 100 studs away as up close
	sign.Size = UDim2.fromOffset(190, 56)
	sign.StudsOffsetWorldSpace = Vector3.new(0, SIGN_Y - height / 2, 0)
	-- centred over the beam, its bottom at SIGN_Y: hung to one side it ran under the NEXT RACE
	-- chip (tour 6) or the coins chip (tour 7) on a phone
	sign.SizeOffset = Vector2.new(0, 0.5)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.Parent = column
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(255, 210, 63)
	text.TextColor3 = Color3.fromRGB(30, 30, 34)
	text.Font = Enum.Font.LuckiestGuy
	text.TextScaled = true
	text.Text = "YOUR PLOT"
	text.Parent = sign
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(30, 30, 34)
	stroke.Thickness = 3
	stroke.Parent = text
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = text
	return marker
end

export type Lobby = {
	setDriving: (on: boolean) -> (),
}

local function building(): boolean
	return Players.LocalPlayer:GetAttribute("Building") == true
end

function Lobby.new(remote: RemoteEvent, canWalk: () -> boolean): Lobby
	local driving = false
	local guide = PlotGuide.new(building)
	local refreshDrive: () -> ()

	-- a big dark button at the bottom, between the steer stick zone (left half) and BRAKE, above
	-- the PC key help line
	local function bigButton(name: string, text: string): (ScreenGui, TextButton)
		local gui = Instance.new("ScreenGui")
		gui.Name = name .. "Gui"
		gui.ResetOnSpawn = false
		gui.Enabled = false
		gui.IgnoreGuiInset = true -- spots in HudLayout count from the very top
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		local button = Instance.new("TextButton")
		button.Name = name
		HudLayout.place(button, "Drive") -- clear of BRAKE on a 16:9 phone (Walk uses the same spot)
		button.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
		button.BackgroundTransparency = 0.2
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Font = Enum.Font.LuckiestGuy
		button.TextSize = 20
		button.Text = text
		button.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = button
		return gui, button
	end
	local gui, button = bigButton("Walk", "WALK (E)")
	gui.Name = "LobbyGui"
	HudLayout.place(button, "Walk", "drive") -- (shown while driving: the drive layout's spot)
	local driveGui, driveButton = bigButton("Drive", "DRIVE")
	-- a thumb-size button on a phone; long names (MIA - LOCKED) shrink to fit
	driveButton.TextScaled = true
	driveButton.TextWrapped = false -- one line, shrunk to fit (it broke into two on a phone)
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 26
	fit.Parent = driveButton
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft = UDim.new(0, 8)
	inset.PaddingRight = UDim.new(0, 8)
	inset.Parent = driveButton
	local DRIVE_ON = KartStyle.GREEN
	local DRIVE_OFF = Color3.fromRGB(70, 70, 78)
	driveButton:SetAttribute("KartPulse", true) -- the one thing to press (KartSkin)

	-- FRIENDS: ON / OFF for the plot you own (the server says which one, and its state)
	local friendsGui, friendsButton = bigButton("Friends", "FRIENDS: OFF")
	HudLayout.place(friendsButton, "Friends")
	friendsButton.TextSize = 18
	StageGate.hold(friendsButton, "friends") -- not for a brand new player (JoinStage)
	local ownSlot: number? = nil
	local friendsOn = false
	local marker: Model? = nil
	local function showFriends()
		friendsButton.Text = if friendsOn then "FRIENDS: ON" else "FRIENDS: OFF"
		friendsButton.BackgroundColor3 = if friendsOn
			then Color3.fromRGB(60, 170, 80)
			else Color3.fromRGB(40, 40, 46)
		-- (not for a brand new player: fewer buttons until the first drive)
		friendsGui.Enabled = ownSlot ~= nil
			and not driving
			and not building()
			and Players.LocalPlayer:GetAttribute("DroveOnce") == true
			and #Players:GetPlayers() > 1 -- nobody to let in when you're alone
		if marker then
			marker.Parent = if driving then nil else workspace
		end
	end
	friendsButton.Activated:Connect(function()
		if ownSlot then
			remote:FireServer("open", not friendsOn)
		end
	end)
	-- DRIVE button: shown while a pad's prompt is; it says DRIVE only on a plot you may drive,
	-- else BUSY or whose it is + LOCKED (and a tap does nothing)
	local shown: ProximityPrompt? = nil
	local mayDrive = false
	local function plotOf(p: ProximityPrompt): Instance?
		local slot = p:GetAttribute("Slot")
		local s = type(slot) == "number" and LobbyLayout.slots()[slot]
		local plots = workspace:FindFirstChild("Plots")
		return if s and plots then plots:FindFirstChild(slot .. "_" .. s.id) else nil
	end
	refreshDrive = function()
		local p = shown
		local plot = p and plotOf(p)
		if not plot then
			mayDrive = true
		else
			local ownerId = plot:GetAttribute("OwnerId")
			local ownerName = plot:GetAttribute("OwnerName")
			local driverId = plot:GetAttribute("DriverId")
			mayDrive, driveButton.Text = LobbyLayout.padButton(
				if type(ownerId) == "number" then ownerId else 0,
				if type(ownerName) == "string" then ownerName else "",
				if type(driverId) == "number" then driverId else 0,
				plot:GetAttribute("Open") == true,
				Players.LocalPlayer.UserId
			)
		end
		if mayDrive then
			driveButton.Text = "DRIVE"
		end
		driveButton.BackgroundColor3 = if mayDrive then DRIVE_ON else DRIVE_OFF
		driveButton.TextColor3 = Color3.new(1, 1, 1)
		driveButton.AutoButtonColor = mayDrive
	end
	-- the plot's owner, driver or FRIENDS can change while you stand there
	local watching: { RBXScriptConnection } = {}
	local function watch(p: ProximityPrompt?)
		for _, c in watching do
			c:Disconnect()
		end
		table.clear(watching)
		local plot = p and plotOf(p)
		if plot then
			for _, name in { "OwnerId", "OwnerName", "DriverId", "Open" } do
				table.insert(watching, plot:GetAttributeChangedSignal(name):Connect(refreshDrive))
			end
		end
	end

	remote.OnClientEvent:Connect(function(kind: unknown, slot: unknown, open: unknown)
		if kind == "own" and type(slot) == "number" and type(open) == "boolean" then
			local s = LobbyLayout.slots()[slot]
			if s and slot ~= ownSlot then
				if marker then
					marker:Destroy()
				end
				marker = makeMarker(s.padX, s.padZ)
			end
			ownSlot = slot
			friendsOn = open
			guide.setSlot(slot)
			showFriends()
		elseif kind == "closed" and shown then
			-- the server said no after all (it changed as you tapped): show why
			refreshDrive()
			driveGui.Enabled = not driving
		end
	end)

	local function askWalk()
		if driving and canWalk() then
			remote:FireServer("walk")
		end
	end
	button.Activated:Connect(askWalk)
	-- WALK steps aside while the race result and prize cards are up (on a phone they reach down to it);
	-- E still works
	local pgui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local cards: { [string]: Instance } = {} -- found once and kept (checked every frame)
	local function cardShown(guiName: string, name: string): boolean
		local o = cards[name]
		if not (o and o.Parent) then
			local holder = pgui:FindFirstChild(guiName)
			local found = if holder then holder:FindFirstChild(name) else nil
			if not found then
				return false
			end
			cards[name] = found
			o = found
		end
		return o:IsA("GuiObject") and o.Visible
	end
	-- standing by your own pad, the beam would fill the middle of the screen: it fades out
	-- (the YOUR PLOT sign stays) and comes back as you walk away
	local BEAM_HIDE = 40
	local beamHidden = false
	RunService.Heartbeat:Connect(function()
		button.Visible = not (
			cardShown("ServerRace", "Result") or cardShown("StarsTop", "RacePrize")
		)
		local m = marker
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local s = ownSlot and LobbyLayout.slots()[ownSlot]
		local near = false
		if m and s and root and root:IsA("BasePart") then
			local dx, dz = root.Position.X - s.padX, root.Position.Z - s.padZ
			near = dx * dx + dz * dz < BEAM_HIDE * BEAM_HIDE
		end
		if m and near ~= beamHidden then
			beamHidden = near
			for _, p in m:GetChildren() do
				local alpha = p:GetAttribute("Alpha")
				if p:IsA("BasePart") and type(alpha) == "number" then
					p.Transparency = if near then 1 else alpha
				end
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.E then
			askWalk()
		end
	end)

	local function showPrompts()
		for _, p in CollectionService:GetTagged("DrivePrompt") do
			if p:IsA("ProximityPrompt") then
				p.Enabled = not driving -- only on this screen
			end
		end
	end

	-- (the server still checks everything); a tap presses that prompt, so the server sees the
	-- same request as E
	ProximityPromptService.PromptShown:Connect(function(p: ProximityPrompt)
		if CollectionService:HasTag(p, "DrivePrompt") then
			shown = p
			watch(p)
			refreshDrive()
			driveGui.Enabled = not driving
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(p: ProximityPrompt)
		if p == shown then
			shown = nil
			watch(nil)
			driveGui.Enabled = false
		end
	end)
	driveButton.Activated:Connect(function()
		local p = shown
		if p and not driving and mayDrive then
			p:InputHoldBegin()
			p:InputHoldEnd()
		end
	end)
	-- the car is on its way (tap or E): DRIVE and the goal line go at once, so the first frames
	-- of the drive show the road, not the buttons. Back after a moment if the server said no.
	ProximityPromptService.PromptTriggered:Connect(function(p: ProximityPrompt)
		if p ~= shown or driving or not mayDrive then
			return
		end
		driveGui.Enabled = false
		guide.hold(2)
		task.delay(2, function()
			if shown == p and not driving then
				driveGui.Enabled = true
			end
		end)
	end)

	-- QUICK RACE (while walking): the server finds a free race plot and starts the drive there.
	-- Off for now: everyone races in the server race, and new players were lost by one more button.
	local QUICK = false
	local quickGui, quickButton = bigButton("Quick", "QUICK RACE")
	HudLayout.place(quickButton, "Quick") -- under FRIENDS
	StageGate.hold(quickButton, "quick")
	quickButton.BackgroundColor3 = Color3.fromRGB(225, 55, 50)
	quickGui.Enabled = QUICK
	quickButton.Activated:Connect(function()
		if not driving then
			remote:FireServer("quick")
		end
	end)
	remote.OnClientEvent:Connect(function(kind: unknown)
		if kind == "noRace" or kind == "raceJoined" then
			quickButton.Text = if kind == "noRace" then "ALL RACES BUSY" else "IN THE NEXT RACE!"
			task.delay(2, function()
				quickButton.Text = "QUICK RACE"
			end)
		end
	end)

	-- the build screen covers the lobby: hide QUICK RACE and FRIENDS under it (BuildScreen sets it)
	Players.LocalPlayer:GetAttributeChangedSignal("Building"):Connect(function()
		quickGui.Enabled = QUICK and not driving and not building()
		showFriends()
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("DroveOnce"):Connect(showFriends)
	Players.PlayerAdded:Connect(showFriends)
	Players.PlayerRemoving:Connect(function()
		task.defer(showFriends)
	end)

	-- the lobby speakers' music fades out while you drive or race, and back in on foot (this
	-- screen only: the server's sounds stay as they are for everyone else)
	local music: { Sound } = {}
	local function fadeMusic(on: boolean)
		if #music == 0 then
			local lobbyFolder = workspace:FindFirstChild("Lobby")
			for _, d in if lobbyFolder then lobbyFolder:GetDescendants() else {} do
				if d:IsA("Sound") and d.Name == "Music" then
					table.insert(music, d)
				end
			end
		end
		local info = TweenInfo.new(SoundLevels.MUSIC_FADE)
		for _, s in music do
			local want = if on then SoundLevels.MUSIC_DRIVING else SoundLevels.MUSIC
			TweenService:Create(s, info, { Volume = want }):Play()
		end
	end

	local lobby = {} :: Lobby
	function lobby.setDriving(on: boolean)
		driving = on
		fadeMusic(on)
		guide.setDriving(on)
		Players.LocalPlayer:SetAttribute("Driving", on) -- lobby chips and buttons hide while driving
		if on then
			Players.LocalPlayer:SetAttribute("DroveOnce", true) -- the rest of the lobby buttons show
		end
		gui.Enabled = on
		quickGui.Enabled = QUICK and not on and not building()
		showFriends()
		if on then
			shown = nil
			driveGui.Enabled = false
		end
		showPrompts()
	end
	return lobby
end

return Lobby
