--!strict
-- The first moment in the lobby, on this player's screen only: the street lights switch on one
-- after another from the spawn down the street, and a burst of confetti pops over the player.
-- Once per join. Looks only: nothing here touches the server or anyone else's screen.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LobbyWelcome = {}

LobbyWelcome.LIGHTS_TIME = 2.5 -- seconds from the first light on to the last
LobbyWelcome.CONFETTI = 140
LobbyWelcome.COLORS = {
	Color3.fromRGB(238, 70, 70),
	Color3.fromRGB(255, 190, 50),
	Color3.fromRGB(70, 170, 240),
	Color3.fromRGB(110, 200, 80),
	Color3.fromRGB(240, 120, 200),
}

local done = false

-- Street lights on, nearest the spawn first.
local function lightsOn(lobby: Instance, from: Vector3)
	local lights: { { light: Light, dist: number, brightness: number } } = {}
	for _, d in lobby:GetDescendants() do
		if d:IsA("PointLight") or d:IsA("SpotLight") then
			local light = d :: Light
			local holder = light.Parent
			if light.Enabled and holder and holder:IsA("BasePart") then
				table.insert(lights, {
					light = light,
					dist = (holder.Position - from).Magnitude,
					brightness = light.Brightness,
				})
				light.Enabled = false
			end
		end
	end
	table.sort(lights, function(a, b)
		return a.dist < b.dist
	end)
	local far = if #lights > 0 then lights[#lights].dist else 1
	for _, l in lights do
		task.delay(0.4 + LobbyWelcome.LIGHTS_TIME * l.dist / math.max(far, 1), function()
			-- a little flicker, then a soft glow up to its own brightness
			l.light.Brightness = 0
			l.light.Enabled = true
			TweenService:Create(
				l.light,
				TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Brightness = l.brightness }
			):Play()
		end)
	end
end

-- A pop of confetti over the player, gone after a few seconds.
local function confetti(at: Vector3)
	local holder = Instance.new("Part")
	holder.Name = "WelcomeConfetti"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(4, 1, 4)
	holder.CFrame = CFrame.new(at + Vector3.new(0, 9, 0))
	holder.Parent = workspace
	local keys = {}
	for i, c in LobbyWelcome.COLORS do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#LobbyWelcome.COLORS - 1), c))
	end
	local fx = Instance.new("ParticleEmitter")
	fx.Color = ColorSequence.new(keys)
	fx.Size = NumberSequence.new(0.35)
	fx.Lifetime = NumberRange.new(2.5, 3.5)
	fx.Speed = NumberRange.new(14, 24)
	fx.SpreadAngle = Vector2.new(70, 70)
	fx.Acceleration = Vector3.new(0, -18, 0)
	fx.Drag = 1.5
	fx.Rotation = NumberRange.new(0, 360)
	fx.RotSpeed = NumberRange.new(-300, 300)
	fx.LightEmission = 0.3
	fx.Enabled = false
	fx.Parent = holder
	fx:Emit(LobbyWelcome.CONFETTI)
	task.delay(0.35, function()
		fx:Emit(math.floor(LobbyWelcome.CONFETTI / 2))
	end)
	task.delay(5, function()
		holder:Destroy()
	end)
end

function LobbyWelcome.start()
	if done then
		return
	end
	done = true
	task.spawn(function()
		local player = Players.LocalPlayer
		local char = player.Character or player.CharacterAdded:Wait()
		local root = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		local lobby = workspace:WaitForChild("Lobby", 10)
		if not root then
			return
		end
		if lobby then
			lightsOn(lobby, root.Position)
		end
		confetti(root.Position)
	end)
end

return LobbyWelcome
