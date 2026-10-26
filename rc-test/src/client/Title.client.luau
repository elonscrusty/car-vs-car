--!strict
-- The join moment: a plain title card over everything while the game loads, so a new player
-- sees CAR VS CAR instead of the HUD popping in piece by piece. It fades once the place has
-- loaded and the lobby HUD has had a moment to settle (at most a few seconds either way).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local MIN = 1.5 -- seconds on screen at least (no flash)
local MAX = 6 -- and at most, whatever is still loading

local gui = Instance.new("ScreenGui")
gui.Name = "TitleCard"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000 -- over every other screen
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local back = Instance.new("Frame")
back.Size = UDim2.fromScale(1, 1)
back.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
back.BorderSizePixel = 0
back.Active = true -- taps don't fall through to buttons underneath
back.Parent = gui

local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.45)
title.Size = UDim2.fromScale(0.8, 0.2)
title.BackgroundTransparency = 1
title.Font = Enum.Font.LuckiestGuy
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255, 213, 79)
title.Text = "CAR VS CAR"
title.Parent = back

local sub = Instance.new("TextLabel")
sub.AnchorPoint = Vector2.new(0.5, 0)
sub.Position = UDim2.fromScale(0.5, 0.58)
sub.Size = UDim2.fromScale(0.5, 0.07)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.LuckiestGuy
sub.TextScaled = true
sub.TextColor3 = Color3.fromRGB(200, 200, 210)
sub.Text = "BUILD. RACE. WIN."
sub.Parent = back

local started = os.clock()
if not game:IsLoaded() then
	game.Loaded:Wait()
end
-- the lobby HUD (Stars) is in: everything else made in the same first moments is too
Players.LocalPlayer
	:WaitForChild("PlayerGui")
	:WaitForChild("StarsHud", math.max(0.1, MAX - (os.clock() - started)))
local left = MIN - (os.clock() - started)
if left > 0 then
	task.wait(left)
end

local fade = TweenInfo.new(0.4)
TweenService:Create(back, fade, { BackgroundTransparency = 1 }):Play()
TweenService:Create(title, fade, { TextTransparency = 1 }):Play()
TweenService:Create(sub, fade, { TextTransparency = 1 }):Play()
back.Active = false
task.wait(0.45)
gui:Destroy()
