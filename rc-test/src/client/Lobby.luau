--!strict
-- Lobby, player side: while driving, a WALK button (phone) and the E key ask the server to go
-- back to walking, and the stand prompts are hidden on this screen. While walking, the stand
-- prompts (E or tap) ask the server to drive; the server answers with "drive" / "walk".
-- Standing on a pad also shows a big DRIVE button in the same spot, for a thumb on a phone.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Lobby = {}

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

	local lobby = {} :: Lobby
	function lobby.setDriving(on: boolean)
		driving = on
		gui.Enabled = on
		if on then
			shown = nil
			driveGui.Enabled = false
		end
		showPrompts()
	end
	return lobby
end

return Lobby
