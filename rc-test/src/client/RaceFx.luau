--!strict
-- Race looks (carter's picks 14 and 15, 10-26): white speed lines rush past the screen edges while
-- the car boosts, and sparks fly when the car slams into something. Looks only: race feel stays
-- LOCKED, nothing here touches the car.

local Players = game:GetService("Players")

export type RaceFx = {
	update: (dt: number, boosting: boolean) -> (),
	sparks: (at: Vector3, away: Vector3, size: number) -> (),
	confetti: (at: Vector3, n: number, size: number) -> (),
}

local RaceFx = {}

local LINES = 18

function RaceFx.new(): RaceFx
	local gui = Instance.new("ScreenGui")
	gui.Name = "RaceFx"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	-- under every button (they drew over BRAKE / GAS / DRIFT, carter's phone 10-28)
	gui.DisplayOrder = -1
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	type Line = { frame: Frame, angle: number, at: number, speed: number }
	local lines: { Line } = {}
	local rng = Random.new()
	for i = 1, LINES do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BorderSizePixel = 0
		f.Visible = false
		f.Parent = gui
		local angle = (i / LINES) * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		table.insert(
			lines,
			{ frame = f, angle = angle, at = rng:NextNumber(), speed = rng:NextNumber(1.6, 2.6) }
		)
	end
	local strength = 0 -- fades in and out

	local self = {} :: RaceFx

	function self.update(dt: number, boosting: boolean)
		strength = math.clamp(strength + (if boosting then 6 else -4) * dt, 0, 1)
		local show = strength > 0.01
		for _, l in lines do
			l.frame.Visible = show
			if show then
				-- from 70% of the way out to past the edge, over and over (the edges only)
				l.at = (l.at + l.speed * dt) % 1
				local r = 0.7 + 0.3 * l.at
				local x, y = 0.5 + math.cos(l.angle) * r * 0.62, 0.5 + math.sin(l.angle) * r
				l.frame.Position = UDim2.fromScale(x, y)
				l.frame.Size = UDim2.fromOffset(4, 30 + 70 * l.at)
				l.frame.Rotation = math.deg(l.angle) + 90
				l.frame.BackgroundTransparency = 1 - strength * 0.7 * (1 - l.at * 0.5)
			end
		end
	end

	-- a burst of sparks at `at`, flying off along `away` (size = the car's scale)
	function self.sparks(at: Vector3, away: Vector3, size: number)
		local spot = Instance.new("Part")
		spot.Name = "Sparks"
		spot.Size = Vector3.new(0.2, 0.2, 0.2)
		spot.Transparency = 1
		spot.Anchored = true
		spot.CanCollide = false
		spot.CanQuery = false
		spot.CanTouch = false
		spot.CFrame =
			CFrame.lookAt(at, at + (if away.Magnitude > 1e-3 then away else Vector3.yAxis))
		spot.Parent = workspace
		local fx = Instance.new("ParticleEmitter")
		fx.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 120, 30))
		fx.LightEmission = 1
		fx.Size = NumberSequence.new(0.35 * size, 0)
		fx.Lifetime = NumberRange.new(0.25, 0.5)
		fx.Speed = NumberRange.new(20 * size, 45 * size)
		fx.SpreadAngle = Vector2.new(55, 55)
		fx.Acceleration = Vector3.new(0, -60 * size, 0)
		fx.EmissionDirection = Enum.NormalId.Front
		fx.Rate = 0
		fx.Parent = spot
		fx:Emit(28)
		task.delay(0.8, spot.Destroy, spot)
	end

	-- the finish (MASTER race moment: confetti within 0.5 s of crossing the line): a pop of
	-- confetti over the car, at once, gone in a few seconds (size = the car's scale)
	local CONFETTI = {
		Color3.fromRGB(255, 199, 44),
		Color3.fromRGB(255, 92, 92),
		Color3.fromRGB(70, 170, 255),
		Color3.fromRGB(90, 220, 120),
		Color3.fromRGB(200, 120, 255),
	}
	function self.confetti(at: Vector3, n: number, size: number)
		local spot = Instance.new("Part")
		spot.Name = "FinishConfetti"
		spot.Size = Vector3.new(0.2, 0.2, 0.2)
		spot.Transparency = 1
		spot.Anchored = true
		spot.CanCollide = false
		spot.CanQuery = false
		spot.CanTouch = false
		spot.CFrame = CFrame.lookAt(at, at + Vector3.yAxis)
		spot.Parent = workspace
		local keys = {}
		for i, c in CONFETTI do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#CONFETTI - 1), c))
		end
		local fx = Instance.new("ParticleEmitter")
		fx.Color = ColorSequence.new(keys)
		fx.Size = NumberSequence.new(0.5 * size)
		fx.Lifetime = NumberRange.new(1.8, 2.6)
		fx.Speed = NumberRange.new(30 * size, 55 * size)
		fx.SpreadAngle = Vector2.new(50, 50)
		fx.Acceleration = Vector3.new(0, -50 * size, 0)
		fx.Drag = 1.5
		fx.Rotation = NumberRange.new(0, 360)
		fx.RotSpeed = NumberRange.new(-300, 300)
		fx.LightEmission = 0.3
		fx.EmissionDirection = Enum.NormalId.Front
		fx.Rate = 0
		fx.Parent = spot
		fx:Emit(n)
		task.delay(3, spot.Destroy, spot)
	end

	return self
end

return RaceFx
