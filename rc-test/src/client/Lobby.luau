--!strict
-- Lobby, player side: while driving, a WALK button (phone) and the E key ask the server to go
-- back to walking, and the stand prompts are hidden on this screen. While walking, the stand
-- prompts (E or tap) ask the server to drive; the server answers with "drive" / "walk".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Lobby = {}

export type Lobby = {
	setDriving: (on: boolean) -> (),
}

function Lobby.new(remote: RemoteEvent, canWalk: () -> boolean): Lobby
	local driving = false

	local gui = Instance.new("ScreenGui")
	gui.Name = "LobbyGui"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local button = Instance.new("TextButton")
	button.Name = "Walk"
	-- bottom, between the steer stick zone (left half) and BRAKE, above the PC key help line
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.fromScale(0.58, 0.9)
	button.Size = UDim2.fromOffset(110, 48)
	button.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	button.BackgroundTransparency = 0.2
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBlack
	button.TextSize = 20
	button.Text = "WALK (E)"
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

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

	local lobby = {} :: Lobby
	function lobby.setDriving(on: boolean)
		driving = on
		gui.Enabled = on
		showPrompts()
	end
	return lobby
end

return Lobby
