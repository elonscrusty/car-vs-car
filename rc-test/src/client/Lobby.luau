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
local UserInputService = game:GetService("UserInputService")

local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)

local Lobby = {}

-- A see-through light column on a pad with a YOUR PLOT sign on top, seen from far away.
local function makeMarker(x: number, z: number): Model
	local marker = Instance.new("Model")
	marker.Name = "YourPlotMarker"
	local height = 30
	local column = Instance.new("Part")
	column.Name = "Light"
	column.Shape = Enum.PartType.Cylinder
	column.Size = Vector3.new(height, 3, 3)
	column.CFrame = CFrame.new(x, height / 2, z) * CFrame.Angles(0, 0, math.pi / 2)
	column.Material = Enum.Material.Neon
	column.Color = Color3.fromRGB(255, 220, 90)
	column.Transparency = 0.65
	column.Anchored = true
	column.CanCollide = false
	column.CanQuery = false
	column.CanTouch = false
	column.CastShadow = false
	column.Parent = marker
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(150, 56)
	sign.StudsOffsetWorldSpace = Vector3.new(0, height / 2 + 2, 0) -- above the column top
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.Parent = column
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(255, 210, 63)
	text.TextColor3 = Color3.fromRGB(30, 30, 34)
	text.Font = Enum.Font.GothamBlack
	text.TextScaled = true
	text.Text = "YOUR PLOT"
	text.Parent = sign
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = text
	return marker
end

export type Lobby = {
	setDriving: (on: boolean) -> (),
}

function Lobby.new(remote: RemoteEvent, canWalk: () -> boolean): Lobby
	local driving = false

	-- a big dark button at the bottom, between the steer stick zone (left half) and BRAKE, above
	-- the PC key help line
	local function bigButton(name: string, text: string): (ScreenGui, TextButton)
		local gui = Instance.new("ScreenGui")
		gui.Name = name .. "Gui"
		gui.ResetOnSpawn = false
		gui.Enabled = false
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		local button = Instance.new("TextButton")
		button.Name = name
		button.AnchorPoint = Vector2.new(0.5, 1)
		button.Position = UDim2.fromScale(0.54, 0.9) -- clear of BRAKE on a 16:9 phone
		button.Size = UDim2.fromOffset(120, 52)
		button.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
		button.BackgroundTransparency = 0.2
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Font = Enum.Font.GothamBlack
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
	local driveGui, driveButton = bigButton("Drive", "DRIVE (E)")
	driveButton.BackgroundColor3 = Color3.fromRGB(230, 180, 30)
	driveButton.TextColor3 = Color3.fromRGB(30, 30, 34)

	-- FRIENDS: ON / OFF for the plot you own (the server says which one, and its state)
	local friendsGui, friendsButton = bigButton("Friends", "FRIENDS: OFF")
	friendsButton.AnchorPoint = Vector2.new(0.5, 0)
	friendsButton.Position = UDim2.new(0.5, 0, 0, 12)
	friendsButton.Size = UDim2.fromOffset(170, 44)
	friendsButton.TextSize = 18
	local ownSlot: number? = nil
	local friendsOn = false
	local marker: Model? = nil
	local function showFriends()
		friendsButton.Text = if friendsOn then "FRIENDS: ON" else "FRIENDS: OFF"
		friendsButton.BackgroundColor3 = if friendsOn
			then Color3.fromRGB(60, 170, 80)
			else Color3.fromRGB(40, 40, 46)
		friendsGui.Enabled = ownSlot ~= nil and not driving
		if marker then
			marker.Parent = if driving then nil else workspace
		end
	end
	friendsButton.Activated:Connect(function()
		if ownSlot then
			remote:FireServer("open", not friendsOn)
		end
	end)
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
			showFriends()
		elseif kind == "closed" then
			-- not your plot and not open (or someone is on it): say so on the DRIVE button
			driveButton.Text = "NOT OPEN"
			task.delay(1.5, function()
				driveButton.Text = "DRIVE (E)"
			end)
		end
	end)

	local function askWalk()
		if driving and canWalk() then
			remote:FireServer("walk")
		end
	end
	button.Activated:Connect(askWalk)
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

	-- the car shop's stands turn slowly (looks only, so each screen turns its own)
	RunService.RenderStepped:Connect(function(dt: number)
		for _, stand in CollectionService:GetTagged("LobbySpin") do
			if stand:IsA("Model") then
				stand:PivotTo(stand:GetPivot() * CFrame.Angles(0, dt * 0.6, 0))
			end
		end
	end)

	-- DRIVE button: shown while a pad's prompt is (the prompt still checks everything); a tap
	-- presses that prompt, so the server sees the same request as E
	local shown: ProximityPrompt? = nil
	ProximityPromptService.PromptShown:Connect(function(p: ProximityPrompt)
		if CollectionService:HasTag(p, "DrivePrompt") then
			shown = p
			driveGui.Enabled = not driving
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(p: ProximityPrompt)
		if p == shown then
			shown = nil
			driveGui.Enabled = false
		end
	end)
	driveButton.Activated:Connect(function()
		local p = shown
		if p and not driving then
			p:InputHoldBegin()
			p:InputHoldEnd()
		end
	end)

	-- QUICK RACE (while walking): the server finds a free race plot and starts the drive there
	local quickGui, quickButton = bigButton("Quick", "QUICK RACE")
	quickButton.AnchorPoint = Vector2.new(0.5, 0)
	quickButton.Position = UDim2.new(0.5, 0, 0, 64) -- under FRIENDS
	quickButton.Size = UDim2.fromOffset(170, 48)
	quickButton.BackgroundColor3 = Color3.fromRGB(225, 55, 50)
	quickGui.Enabled = true
	quickButton.Activated:Connect(function()
		if not driving then
			remote:FireServer("quick")
		end
	end)
	remote.OnClientEvent:Connect(function(kind: unknown)
		if kind == "noRace" then
			quickButton.Text = "ALL RACES BUSY"
			task.delay(1.5, function()
				quickButton.Text = "QUICK RACE"
			end)
		end
	end)

	local lobby = {} :: Lobby
	function lobby.setDriving(on: boolean)
		driving = on
		gui.Enabled = on
		quickGui.Enabled = not on
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
