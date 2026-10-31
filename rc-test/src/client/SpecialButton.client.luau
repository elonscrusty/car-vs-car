--!strict
-- The SPECIAL button (Car VS Car SMASH special move; "A Ring Meter" look from the SPECIAL button
-- tries page). A round button with a ring of 16 ticks that light up as the special refills and
-- turn gold when it is ready. Tap it (or G, or a gamepad's L2) to ask the server through the
-- SpecialFire remote; the server's own timer is the real gate. It shows only in a match, and only
-- while the player's SpecialName attribute names a special (server/WeaponServer sets SpecialName
-- and SpecialReadyAt). Sits above the pink FIRE button on the right edge.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local FireSwarm = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FireSwarm"))

local player = Players.LocalPlayer

local TICKS = 16
local OFF = Color3.fromRGB(50, 54, 70)
local ON = Color3.fromRGB(255, 130, 30)
local FULL = Color3.fromRGB(255, 205, 40)
local FACE = Color3.fromRGB(20, 22, 32)
local GAP = 0.3 -- seconds between asks from this client

local gui = Instance.new("ScreenGui")
gui.Name = "SpecialButton"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local holder = Instance.new("Frame")
holder.Name = "Holder"
holder.BackgroundTransparency = 1
holder.AnchorPoint = Vector2.new(1, 0.5)
holder.Position = UDim2.fromScale(0.98, 0.6)
holder.Size = UDim2.fromOffset(92, 92) -- a thumb-sized tap (48 px and up)
holder.Parent = gui

local scale = Instance.new("UIScale")
scale.Parent = holder

local ticks: { Frame } = {}
for i = 1, TICKS do
	local a = (i - 1) / TICKS * math.pi * 2
	local t = Instance.new("Frame")
	t.Name = "Tick" .. i
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5 + 0.46 * math.sin(a), 0.5 - 0.46 * math.cos(a))
	t.Size = UDim2.fromScale(0.09, 0.17)
	t.Rotation = math.deg(a)
	t.BackgroundColor3 = OFF
	t.BorderSizePixel = 0
	t.Parent = holder
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = t
	table.insert(ticks, t)
end

local button = Instance.new("TextButton")
button.Name = "Special"
button.AnchorPoint = Vector2.new(0.5, 0.5)
button.Position = UDim2.fromScale(0.5, 0.5)
button.Size = UDim2.fromScale(0.68, 0.68)
button.BackgroundColor3 = FACE
button.AutoButtonColor = false
button.Font = Enum.Font.Oswald
button.TextColor3 = Color3.new(1, 1, 1)
button.TextScaled = true
button.Text = "SPECIAL"
button.Parent = holder
local face = Instance.new("UICorner")
face.CornerRadius = UDim.new(0.5, 0)
face.Parent = button
local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.new(0, 0, 0)
stroke.Parent = button
local pad = Instance.new("UIPadding")
pad.PaddingLeft, pad.PaddingRight = UDim.new(0.12, 0), UDim.new(0.12, 0)
pad.PaddingTop, pad.PaddingBottom = UDim.new(0.25, 0), UDim.new(0.25, 0)
pad.Parent = button

local function inMatch(): boolean
	return player:GetAttribute("InMatch") == true
end

local lastAsk = 0
local function ask()
	if
		not inMatch()
		or FireSwarm.fill(player:GetAttribute("SpecialReadyAt"), workspace:GetServerTimeNow())
			< 1
	then
		return
	end
	local now = os.clock()
	if now - lastAsk < GAP then
		return
	end
	lastAsk = now
	local remote = ReplicatedStorage:FindFirstChild(FireSwarm.REMOTE)
	if remote and remote:IsA("RemoteEvent") then
		-- aim: where the camera looks, flat (the server keeps it within 30 degrees of the nose)
		local cam = workspace.CurrentCamera
		local look = if cam then cam.CFrame.LookVector * Vector3.new(1, 0, 1) else Vector3.zero
		remote:FireServer(if look.Magnitude > 1e-3 then look.Unit else nil)
	end
end

button.Activated:Connect(ask)
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.G or input.KeyCode == Enum.KeyCode.ButtonL2 then
		ask()
	end
end)

local shown = -1
local wasFull = false
RunService.RenderStepped:Connect(function()
	local name = player:GetAttribute("SpecialName")
	gui.Enabled = inMatch() and type(name) == "string" and name ~= ""
	if not gui.Enabled then
		return
	end
	local f = FireSwarm.fill(player:GetAttribute("SpecialReadyAt"), workspace:GetServerTimeNow())
	local full = f >= 1
	local lit = if full then TICKS else math.floor(f * TICKS)
	if lit ~= shown or full ~= wasFull then
		shown = lit
		for i, t in ticks do
			t.BackgroundColor3 = if full then FULL elseif i <= lit then ON else OFF
		end
		button.Text = if full
			then FireSwarm.WORD
			else string.format("SPECIAL %d%%", math.floor(f * 100))
	end
	wasFull = full
	-- ready: a gentle pulse so you notice it
	scale.Scale = if full then 1 + 0.05 * math.sin(os.clock() * 7) else 1
end)
