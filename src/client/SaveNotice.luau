--!strict
-- Small text at the bottom of the screen while the server could not load this player's save
-- (player attribute ProfileUnsaved = true, set by Profiles). Client text only; display only.

local Players = game:GetService("Players")

local SaveNotice = {}

local TEXT = "Progress not saving right now"

function SaveNotice.new()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "SaveNotice"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -8)
	label.Size = UDim2.fromOffset(300, 28)
	label.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.fromRGB(255, 200, 120)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = TEXT
	label.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	label.Parent = gui

	local function refresh()
		label.Visible = player:GetAttribute("ProfileUnsaved") == true
	end
	player:GetAttributeChangedSignal("ProfileUnsaved"):Connect(refresh)
	refresh()
end

return SaveNotice
