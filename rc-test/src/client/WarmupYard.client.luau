--!strict
-- Car VS Car Smash: the warm-up yard's clock. NEXT MATCH IN m:ss small at the top edge of the
-- screen while you're in the yard (workspace NextMatchAt, server time, set by MatchRunner), clear of
-- the kart. The yard's big board just says WARM UP! (one clock only: audit R4-5). Looks only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WarmupYard = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WarmupYard"))
local KartStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KartStyle"))

if not WarmupYard.on() then
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
onBoard.Text = WarmupYard.clock(nil) -- WARM UP!

-- the top edge of the screen, small, only in the yard (a short phone screen: never over the kart)
local gui = Instance.new("ScreenGui")
gui.Name = "WarmupClock"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = me:WaitForChild("PlayerGui")
local onScreen = words(gui, UDim2.new(0.4, 0, 0, 28), UDim2.new(0.5, 0, 0, 4))
local sizeCap = Instance.new("UISizeConstraint")
sizeCap.MaxSize = Vector2.new(320, 28)
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
	onScreen.Text = text
	local p = where()
	gui.Enabled = p ~= nil and WarmupYard.inside({ x = p.X, y = p.Y, z = p.Z })
	task.wait(0.25)
end
