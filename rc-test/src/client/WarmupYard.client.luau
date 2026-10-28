--!strict
-- Car VS Car Smash: the warm-up yard's clock. NEXT MATCH IN m:ss on the yard's big board, and
-- the same words big at the top of the screen while you're in the yard (workspace NextMatchAt,
-- server time, set by MatchRunner). Looks only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"))
local WarmupYard = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WarmupYard"))
local KartStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartStyle"))

if not (Features.CVC and Features.SMASH) then
	return
end

local me = Players.LocalPlayer

local function words(parent: Instance, size: UDim2, pos: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Font = Enum.Font.FredokaOne -- (UiTheme.FONT)
	l.TextScaled = true
	l.TextColor3 = KartStyle.YELLOW
	l.Text = ""
	local rim = Instance.new("UIStroke")
	rim.Thickness = KartStyle.TEXT_RIM
	rim.Color = KartStyle.INK
	rim.Parent = l
	l.Parent = parent
	return l
end

-- the board in the yard
local yard = workspace:WaitForChild("WarmupYard")
local face = yard:WaitForChild("Board"):WaitForChild("Face") :: BasePart
local board = Instance.new("SurfaceGui")
board.Face = Enum.NormalId.Front
board.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
board.PixelsPerStud = 40
board.LightInfluence = 0
board.Adornee = face
board.Parent = me:WaitForChild("PlayerGui")
local onBoard = words(board, UDim2.fromScale(0.92, 0.7), UDim2.fromScale(0.5, 0.15))

-- the top of the screen, only in the yard
local gui = Instance.new("ScreenGui")
gui.Name = "WarmupClock"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = me:WaitForChild("PlayerGui")
local onScreen = words(gui, UDim2.new(0.6, 0, 0, 44), UDim2.new(0.5, 0, 0, 56))
local sizeCap = Instance.new("UISizeConstraint")
sizeCap.MaxSize = Vector2.new(520, 60)
sizeCap.Parent = onScreen

local function where(): Vector3?
	local car = workspace:FindFirstChild("Car_" .. me.UserId)
	local body = car and (car :: Model).PrimaryPart
	if body then
		return body.Position
	end
	local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

while true do
	local at = workspace:GetAttribute("NextMatchAt")
	local left = if type(at) == "number" then at - workspace:GetServerTimeNow() else nil
	local text = WarmupYard.clock(left)
	onBoard.Text = text
	onScreen.Text = text
	local p = where()
	gui.Enabled = p ~= nil and WarmupYard.inside({ x = p.X, y = p.Y, z = p.Z })
	task.wait(0.25)
end
