--!strict
-- Low health (UI kit v41, HUD_HANDOFF "Low health"): at 25 health and under in a match, a soft red
-- edge round the screen breathes slowly (1.8 s). Never a fast full-screen flash (vault:
-- Accessibility); reduced motion keeps it steady. Its own ScreenGui under the HUD, so it never
-- covers a button. Numbers live in shared/KitWorld; looks only (the server decides health).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitWorld = require(Shared:WaitForChild("KitWorld"))
local Base = require(script.Parent:WaitForChild("Ui"):WaitForChild("Base"))

local player = Players.LocalPlayer
local RED = Color3.fromRGB(KitWorld.EDGE_RED[1], KitWorld.EDGE_RED[2], KitWorld.EDGE_RED[3])
local SOFT = 0.2 -- the soft red at its strongest is this see-through (kit: 0.8 strong)

local gui = Instance.new("ScreenGui")
gui.Name = "LowHealthEdge"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None -- (the whole screen, under the top bar too)
gui:SetAttribute("NoKart", true) -- (KartSkin's rims and pop scale stay off: Studio 10-29 saw lines)
gui.DisplayOrder = Base.ORDER.hud - 2 -- (under the HUD and its back layer)
gui.Enabled = false

-- the four soft sides: red at the screen's edge, gone DEPTH in (a 1.8 s breath on all of them)
local sides: { Frame } = {}
local function side(name: string, rotation: number, pos: UDim2, size: UDim2, anchor: Vector2)
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = RED
	f.AnchorPoint = anchor
	f.Position = pos
	f.Size = size
	f.Active = false
	f:SetAttribute("NoKart", true)
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.45, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
	f.Parent = gui
	table.insert(sides, f)
	return f
end
local top = side("Top", 90, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0), Vector2.zero)
local bottom = side("Bottom", -90, UDim2.fromScale(0, 1), UDim2.fromScale(1, 0), Vector2.new(0, 1))
local left = side("Left", 0, UDim2.fromScale(0, 0), UDim2.fromScale(0, 1), Vector2.zero)
local right = side("Right", 180, UDim2.fromScale(1, 0), UDim2.fromScale(0, 1), Vector2.new(1, 0))

-- the thin solid line at the very edge (kit: inset 0 0 0 6px)
local rimFrame = Instance.new("Frame")
rimFrame.Name = "Rim"
rimFrame.BackgroundTransparency = 1
rimFrame:SetAttribute("NoKart", true)
rimFrame.Position = UDim2.fromOffset(KitWorld.EDGE_RIM_PX, KitWorld.EDGE_RIM_PX)
rimFrame.Size = UDim2.new(1, -2 * KitWorld.EDGE_RIM_PX, 1, -2 * KitWorld.EDGE_RIM_PX)
local rim = Instance.new("UIStroke")
rim.Color = RED
rim.Thickness = KitWorld.EDGE_RIM_PX
rim.Parent = rimFrame
rimFrame.Parent = gui

-- the sides reach DEPTH of the short side in, whatever the screen
local function fit()
	local cam = workspace.CurrentCamera
	local view = if cam then cam.ViewportSize else Vector2.new(844, 390)
	local d = math.floor(math.min(view.X, view.Y) * KitWorld.EDGE_DEPTH)
	top.Size = UDim2.new(1, 0, 0, d)
	bottom.Size = UDim2.new(1, 0, 0, d)
	left.Size = UDim2.new(0, d, 1, 0)
	right.Size = UDim2.new(0, d, 1, 0)
end

-- ===== my health: my MatchBoard row =====
local health: number? = nil
local rowConn: RBXScriptConnection? = nil
local function watchRow(row: Instance)
	if row.Name ~= tostring(player.UserId) then
		return
	end
	if rowConn then
		rowConn:Disconnect()
	end
	local function read()
		local hp = row:GetAttribute("Health")
		health = if type(hp) == "number" then hp else nil
	end
	read()
	rowConn = row:GetAttributeChangedSignal("Health"):Connect(read)
	row.Destroying:Once(function()
		health = nil
	end)
end
task.spawn(function()
	local board = ReplicatedStorage:WaitForChild("MatchBoard")
	for _, row in board:GetChildren() do
		watchRow(row)
	end
	board.ChildAdded:Connect(watchRow)
end)

-- ===== every frame: fade in or out, breathe =====
local shown = 0 -- 0..1 how far in
local since = 0 -- s into the breath
RunService.RenderStepped:Connect(function(dt: number)
	local want = KitWorld.low(player:GetAttribute("InMatch"), health)
	if not want and shown <= 0 then
		if gui.Enabled then
			gui.Enabled = false
		end
		return
	end
	if want and not gui.Enabled then
		gui.Parent = player:FindFirstChildOfClass("PlayerGui")
		since = 0
		fit()
		gui.Enabled = true
	end
	local step = dt / KitWorld.EDGE_FADE
	shown = math.clamp(shown + (if want then step else -step), 0, 1)
	since += dt
	local a = shown * KitWorld.breath(since, Base.reduced())
	for _, f in sides do
		f.BackgroundTransparency = 1 - a * (1 - SOFT)
	end
	rim.Transparency = 1 - a * 0.9
end)

-- (the camera can be swapped: follow the current one)
local camConn: RBXScriptConnection? = nil
local function watchCam()
	if camConn then
		camConn:Disconnect()
		camConn = nil
	end
	local cam = workspace.CurrentCamera
	if cam then
		camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	fit()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCam)
watchCam()
