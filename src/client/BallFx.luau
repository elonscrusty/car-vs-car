--!strict
-- Ball feel (audit #91), car soccer only: a trail behind the ball whose length follows its speed,
-- and a small spark plus the "ballKick" sound event on a strong kick. A kick is a sudden jump in
-- the ball's velocity while a car body is right next to it (so wall bounces do not count).
-- Rules (pure, tested): FeelRules.trailLifetime and FeelRules.kickStrength; numbers: GameConfig.Feel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Effects = require(script.Parent.Effects)
local FeelRules = require(ReplicatedStorage.Shared.FeelRules)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Quality = require(script.Parent.Quality)
local SoundFx = require(script.Parent.SoundFx)

local BallFx = {}

local conn: RBXScriptConnection? = nil

local function findBall(): BasePart?
	local uid = Players.LocalPlayer.UserId
	for _, arena in workspace:GetChildren() do
		if arena.Name == "Arena" then
			for _, m in arena:GetChildren() do
				if m:IsA("Model") and m:GetAttribute("DriverUserId") == uid then
					local b = arena:FindFirstChild("Ball")
					return if b and b:IsA("BasePart") then b else nil
				end
			end
		end
	end
	return nil
end

-- A car body within kick reach of the ball?
local function carNear(ball: BasePart, reach: number): boolean
	local arena = ball.Parent
	if arena == nil then
		return false
	end
	local limit = ball.Size.X / 2 + reach
	for _, m in arena:GetChildren() do
		if m:IsA("Model") and m.PrimaryPart ~= nil then
			if
				(m.PrimaryPart.Position - ball.Position).Magnitude
				<= limit + m.PrimaryPart.Size.Magnitude / 2
			then
				return true
			end
		end
	end
	return false
end

function BallFx.start()
	if conn then
		return
	end
	local feel = GameConfig.Feel
	local ball: BasePart? = nil
	local trail: Trail? = nil
	local nextFind = 0
	local lastV = Vector3.zero
	local lastKick = 0
	local shownLife = 0

	conn = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if ball == nil or ball.Parent == nil then
			ball, trail = nil, nil
			if now < nextFind then
				return
			end
			nextFind = now + 0.3
			local b = findBall()
			if b == nil then
				return
			end
			ball = b
			lastV = b.AssemblyLinearVelocity
			local r = b.Size.X / 2
			local a0 = Instance.new("Attachment")
			a0.Name = "TrailTop"
			a0.Position = Vector3.new(0, r * 0.7, 0)
			a0.Parent = b
			local a1 = Instance.new("Attachment")
			a1.Name = "TrailBottom"
			a1.Position = Vector3.new(0, -r * 0.7, 0)
			a1.Parent = b
			local t = Instance.new("Trail")
			t.Attachment0 = a0
			t.Attachment1 = a1
			t.Color =
				ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 230, 120))
			t.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(1, 1),
			})
			t.LightEmission = 0.6
			t.FaceCamera = true
			t.MinLength = 0.1
			t.Lifetime = 0.1
			t.Enabled = false
			t.Parent = b
			trail = t
			shownLife = 0
			return
		end
		local b = ball :: BasePart
		local v = b.AssemblyLinearVelocity

		-- Trail: as long as the ball is fast.
		local t = trail
		if t ~= nil then
			local life = FeelRules.trailLifetime(v.Magnitude)
				* (if Quality.level() >= 2 then 0.6 else 1)
			if math.abs(life - shownLife) > 0.02 or (life == 0) ~= (shownLife == 0) then
				shownLife = life
				t.Enabled = life > 0
				if life > 0 then
					t.Lifetime = life
				end
			end
		end

		-- Kick: a sudden velocity change with a car right there.
		local strength = FeelRules.kickStrength((v - lastV).Magnitude)
		lastV = v
		if strength >= feel.kickSparkFrom and now - lastKick >= feel.kickCooldown then
			if carNear(b, feel.kickCarReach) then
				lastKick = now
				Effects.sparks(b.Position, strength)
				SoundFx.play("ballKick")
			end
		end
	end)
end

function BallFx.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
end

return BallFx
