--!strict
-- Car VS Car Smash: the warm-up yard's clock. NEXT MATCH IN m:ss small at the top edge of the
-- screen while you're in the yard (workspace NextMatchAt, server time, set by MatchRunner), clear of
-- the kart, and only while the yard's big board (the same words) is off screen: one clock at a
-- time (audit R4-5). Looks only.
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
onBoard.Text = WarmupYard.clock(nil) -- WARM UP! until a round is planned

-- the top edge of the screen, small, only in the yard (a short phone screen: never over the kart)
local gui = Instance.new("ScreenGui")
gui.Name = "WarmupClock"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = me:WaitForChild("PlayerGui")
-- a navy rounded pill behind it, so it reads as the screen's own clock and not as words on the
-- board behind (Studio r4)
local onScreen = words(gui, UDim2.new(0.4, 0, 0, 32), UDim2.new(0.5, 0, 0, 6))
onScreen.BackgroundTransparency = 0.1
onScreen.BackgroundColor3 = Color3.fromRGB(30, 42, 90) -- LOOK-BIBLE navy
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0.5, 0)
round.Parent = onScreen
local pad = Instance.new("UIPadding")
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
pad.Parent = onScreen
local sizeCap = Instance.new("UISizeConstraint")
sizeCap.MaxSize = Vector2.new(300, 32)
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

local seen = false -- the board's clock is on screen (then the pill hides)
while true do
	local at = workspace:GetAttribute("NextMatchAt")
	local left = if type(at) == "number" then at - workspace:GetServerTimeNow() else nil
	local text = WarmupYard.clock(left)
	onScreen.Text = text
	onBoard.Text = text
	local p = where()
	-- one clock at a time (audit R4-5): the board's while it's on screen, else the pill (Studio
	-- r5: the pill sat over the board's edge from the chase view)
	local cam = workspace.CurrentCamera
	if cam then
		-- the board's middle well inside the screen, seen from the front (behind it, there's only
		-- its back panel); a wider margin to stop seeing it than to start, so it doesn't flicker
		local mid, inView = cam:WorldToViewportPoint(face.Position)
		local front = (cam.CFrame.Position - face.Position):Dot(face.CFrame.LookVector) > 0
		local view = cam.ViewportSize
		local m = if seen then 0.05 else 0.12
		seen = inView
			and front
			and mid.X > view.X * m
			and mid.X < view.X * (1 - m)
			and mid.Y > view.Y * m
			and mid.Y < view.Y * (1 - m)
	else
		seen = false
	end
	gui.Enabled = p ~= nil and WarmupYard.inside({ x = p.X, y = p.Y, z = p.Z }) and not seen
	task.wait(0.25)
end
