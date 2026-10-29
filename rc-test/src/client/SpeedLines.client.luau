--!strict
-- Speed lines (UI kit v41 "speed", auditor cheap tells #1 "no speed lines"): near top speed in a
-- match, 4 thin white streaks slide down by the left and right edges of the screen, never in the
-- middle. Its own ScreenGui under the HUD, kept out of KartSkin's rims (NoKart). Off with reduced
-- motion. Numbers live in shared/KitWorld; looks only (driving is untouched).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KitWorld = require(Shared:WaitForChild("KitWorld"))
local Tuning = require(Shared:WaitForChild("Tuning"))
local Base = require(script.Parent:WaitForChild("Ui"):WaitForChild("Base"))

local player = Players.LocalPlayer
local MINE = "Car_" .. tostring(player.UserId)

local gui = Instance.new("ScreenGui")
gui.Name = "SpeedLines"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = Base.ORDER.hud - 2 -- (under the HUD and its back layer)
gui:SetAttribute("NoKart", true)
gui.Enabled = false

-- the kit's spots are for an 844 x 390 screen: scale them by the screen's height
local streaks: { Frame } = {}
for _, l in KitWorld.LINES do
	local f = Instance.new("Frame")
	f.Name = "Streak"
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(if l.side < 0 then 0 else 1, 0)
	f.Active = false
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = f
	f.Parent = gui
	table.insert(streaks, f)
end

local function place(view: Vector2, i: number, drop: number)
	local l = KitWorld.LINES[i]
	local k = view.Y / 390
	local f = streaks[i]
	f.Size = UDim2.fromOffset(math.max(2, l.w * k), l.h * k)
	local x = if l.side < 0 then l.x * k else view.X - l.x * k
	f.Position = UDim2.fromOffset(x, (l.y + drop) * k)
end

local t = 0
RunService.RenderStepped:Connect(function(dt: number)
	local car = workspace:FindFirstChild(MINE)
	local body = car and car:IsA("Model") and car.PrimaryPart
	local share = 0
	if body and Tuning.topSpeed > 0 then
		local v = body.AssemblyLinearVelocity
		share = Vector3.new(v.X, 0, v.Z).Magnitude / Tuning.topSpeed
	end
	local strength = KitWorld.speedLines(share, player:GetAttribute("InMatch"), Base.reduced())
	if strength <= 0 then
		if gui.Enabled then
			gui.Enabled = false
		end
		t = 0
		return
	end
	if not gui.Enabled then
		gui.Parent = player:FindFirstChildOfClass("PlayerGui")
		gui.Enabled = true
	end
	t += dt
	local cam = workspace.CurrentCamera
	local view = if cam then cam.ViewportSize else Vector2.new(844, 390)
	for i, l in KitWorld.LINES do
		local drop, a = KitWorld.streak(t + l.lag)
		place(view, i, drop)
		streaks[i].BackgroundTransparency = 1 - a * strength
	end
end)
