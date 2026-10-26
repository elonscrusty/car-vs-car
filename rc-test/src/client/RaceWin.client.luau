--!strict
-- Car VS Car win moment from the stand: the winner of your league's race gets a trophy and a
-- burst of confetti over their avatar on the driver stand, a cheer plays, and their 10 min coin
-- boost shows (RaceWin has the rules). Looks only: the prize itself is TrainingServer's.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Features = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Features"))
local RaceWin = require(ReplicatedStorage.Shared:WaitForChild("RaceWin"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local player = Players.LocalPlayer
local event = ReplicatedStorage:WaitForChild("ServerRace") :: RemoteEvent

local function confetti(parent: Instance)
	local fx = Instance.new("ParticleEmitter")
	fx.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 210, 60)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 230, 110)),
	})
	fx.Size = NumberSequence.new(0.35)
	fx.Lifetime = NumberRange.new(1.5, 2.5)
	fx.Speed = NumberRange.new(10, 18)
	fx.SpreadAngle = Vector2.new(50, 50)
	fx.Acceleration = Vector3.new(0, -14, 0)
	fx.Rotation = NumberRange.new(0, 360)
	fx.RotSpeed = NumberRange.new(-200, 200)
	fx.EmissionDirection = Enum.NormalId.Top
	fx.Rate = 0
	fx.Parent = parent
	fx:Emit(90)
	task.delay(1.2, function()
		if fx.Parent then
			fx:Emit(60) -- a second pop
		end
	end)
end

local function label(parent: Instance, text: string, y: number, h: number, color: Color3)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, h, 0)
	l.Position = UDim2.new(0, 0, y, 0)
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.TextStrokeTransparency = 0
	l.Parent = parent
end

local function show(w: RaceWin.Winner)
	local who = Players:GetPlayerByUserId(w.uid)
	local char = who and who.Character
	local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
	if not (head and head:IsA("BasePart")) then
		return
	end
	local spot = Instance.new("Attachment")
	spot.Name = "RaceWin"
	spot.Position = Vector3.new(0, 2.5, 0)
	spot.Parent = head
	confetti(spot)
	local top, boost = RaceWin.words(w)
	local gui = Instance.new("BillboardGui")
	gui.Name = "RaceWinTag"
	gui.Adornee = spot
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(220, 150)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	gui.MaxDistance = 1000
	gui.ResetOnSpawn = false
	label(gui, "🏆", 0, 0.5, Color3.fromRGB(255, 210, 60))
	label(gui, top, 0.5, 0.27, Color3.new(1, 1, 1))
	label(gui, boost, 0.77, 0.23, Color3.fromRGB(255, 220, 40))
	gui.Parent = player:FindFirstChildOfClass("PlayerGui") or spot
	-- the crowd cheers (the winner's own trophy sound is the result screen's, Sfx.trophy)
	local cheer = (Sfx :: any).cheer
	if type(cheer) == "function" then
		cheer()
	elseif not w.mine then
		Sfx.finish(1)
	end
	task.delay(RaceWin.SHOW, function()
		gui:Destroy()
		spot:Destroy()
	end)
end

event.OnClientEvent:Connect(function(what: unknown, rows: unknown)
	if what ~= "result" or not Features.CVC then
		return
	end
	local w = RaceWin.winner(rows, player.UserId)
	if w then
		show(w)
	end
end)
