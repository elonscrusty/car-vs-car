--!strict
-- Turns the best car on each plot's car show podium (PlotStandsBuilder tags it "ShowSpin"; its
-- pivot is the podium's top middle). Only on this screen: the server copy stays still.
-- Also: a spot tagged "ShowNew" for this player (a car they just bought or won) glows gold with a
-- burst of sparkles the first time they come within NEW_NEAR of it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SPEED = 0.6 -- radians a second

local spinning: { [Model]: CFrame } = {} -- each car and where it started

local function add(m: Instance)
	if m:IsA("Model") then
		spinning[m] = m:GetPivot()
	end
end
for _, m in CollectionService:GetTagged("ShowSpin") do
	add(m)
end
CollectionService:GetInstanceAddedSignal("ShowSpin"):Connect(add)
CollectionService:GetInstanceRemovedSignal("ShowSpin"):Connect(function(m: Instance)
	spinning[m :: Model] = nil
end)

local NEAR = 150 -- farther than this the turn can't be seen: that car waits (phone speed)

RunService.RenderStepped:Connect(function()
	local turn = CFrame.Angles(0, (os.clock() * SPEED) % (2 * math.pi), 0)
	local cam = workspace.CurrentCamera
	local eye = if cam then cam.CFrame.Position else Vector3.zero
	for m, start in spinning do
		if m.Parent then
			if (start.Position - eye).Magnitude < NEAR then
				m:PivotTo(start * turn)
			end
		else
			spinning[m] = nil
		end
	end
end)

-- ===== New car glow =====

local NEW_NEAR = 30 -- studs
local GLOW = 4 -- seconds
local GOLD = Color3.fromRGB(255, 210, 60)
local me = Players.LocalPlayer
local waiting: { [BasePart]: boolean } = {}

local function glow(spot: BasePart)
	local color, material = spot.Color, spot.Material
	spot.Color = GOLD
	spot.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 10
	light.Brightness = 3
	light.Parent = spot
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1))
	sparks.LightEmission = 0.8
	sparks.Size = NumberSequence.new(0.25, 0)
	sparks.Lifetime = NumberRange.new(0.8, 1.4)
	sparks.Speed = NumberRange.new(4, 8)
	sparks.SpreadAngle = Vector2.new(40, 40)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Acceleration = Vector3.new(0, -6, 0)
	sparks.Enabled = false
	sparks.Parent = spot
	sparks:Emit(40)
	local pulse = TweenService:Create(
		light,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Brightness = 0.5 }
	)
	pulse:Play()
	task.delay(GLOW, function()
		pulse:Cancel()
		light:Destroy()
		if spot.Parent then
			spot.Color, spot.Material = color, material
		end
		task.delay(2, function()
			sparks:Destroy()
		end)
	end)
end

local function addNew(spot: Instance)
	if spot:IsA("BasePart") and spot:GetAttribute("NewFor") == me.UserId then
		waiting[spot] = true
	end
end
for _, s in CollectionService:GetTagged("ShowNew") do
	addNew(s)
end
CollectionService:GetInstanceAddedSignal("ShowNew"):Connect(addNew)

task.spawn(function()
	while true do
		task.wait(0.5)
		local char = me.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		for spot in waiting do
			if not spot.Parent then
				waiting[spot] = nil
			elseif root and (spot.Position - root.Position).Magnitude < NEW_NEAR then
				waiting[spot] = nil
				glow(spot)
			end
		end
	end
end)
