--!strict
-- Handles aiming + power bar on the client.
-- Step 1: hold A/D (or arrows, or the on-screen arrows) to turn the arrow, then lock aim.
-- Step 2: the power bar fills up and down; tap / click / space to fire.
-- The client only sends angle + power. The server checks them again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Aim = require(ReplicatedStorage.Shared.Aim)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Logic = require(ReplicatedStorage.Shared.Logic)

export type AimInput = {
	start: (carPos: Vector3, baseDir: Vector3) -> (),
	stop: () -> (),
	setHold: (dir: number) -> (),
	confirm: () -> (),
}

local AimInput = {}

function AimInput.new(
	onPower: (power: number) -> (),
	onFire: (angle: number, power: number) -> ()
): AimInput
	local stage = "off" -- "off" | "aim" | "power"
	local angle = 0
	local holdDir = 0 -- from on-screen buttons
	local keyLeft, keyRight = false, false
	local powerStart = 0
	local power = 0
	local carPos = Vector3.zero
	local baseDir = Vector3.zAxis
	local arrow: Folder? = nil
	local shaft: Part? = nil
	local head: Part? = nil

	local function makeArrowPart(size: Vector3): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 40, 120)
		p.Size = size
		return p
	end

	local function destroyArrow()
		if arrow then
			arrow:Destroy()
		end
		arrow, shaft, head = nil, nil, nil
	end

	local function updateArrow()
		if shaft == nil or head == nil then
			return
		end
		local dir = Aim.direction(baseDir, angle)
		local start = carPos + Vector3.new(0, 3, 0)
		shaft.CFrame = CFrame.lookAt(start + dir * 9, start + dir * 10)
		local tip = start + dir * 18.5
		head.CFrame = CFrame.lookAt(tip, tip + dir) * CFrame.Angles(0, 0, math.rad(45))
	end

	local function update(dt: number)
		if stage == "aim" then
			local dir = holdDir
			if keyLeft then
				dir += 1
			end
			if keyRight then
				dir -= 1
			end
			angle = Logic.clamp(
				angle + dir * GameConfig.Launch.aimDegPerSec * dt,
				-GameConfig.Match.aimMaxDeg,
				GameConfig.Match.aimMaxDeg
			)
			updateArrow()
		elseif stage == "power" then
			power = Logic.powerAt(os.clock() - powerStart, GameConfig.Launch.powerPeriod)
			onPower(power)
		end
	end
	RunService.RenderStepped:Connect(update)

	local self: AimInput = {} :: any

	self.start = function(pos: Vector3, base: Vector3)
		destroyArrow()
		carPos, baseDir, angle, power = pos, base, 0, 0
		stage = "aim"
		local folder = Instance.new("Folder")
		folder.Name = "LocalAimArrow"
		shaft = makeArrowPart(Vector3.new(0.9, 0.3, 17))
		head = makeArrowPart(Vector3.new(3.2, 0.3, 3.2));
		(shaft :: Part).Parent = folder;
		(head :: Part).Parent = folder
		folder.Parent = workspace
		arrow = folder
		updateArrow()
	end

	self.stop = function()
		stage = "off"
		holdDir = 0
		destroyArrow()
	end

	self.setHold = function(dir: number)
		holdDir = dir
	end

	self.confirm = function()
		if stage == "aim" then
			stage = "power"
			powerStart = os.clock()
		elseif stage == "power" then
			stage = "off"
			destroyArrow()
			onFire(angle, power)
		end
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local key = input.KeyCode
		if key == Enum.KeyCode.A or key == Enum.KeyCode.Left then
			keyLeft = true
		elseif key == Enum.KeyCode.D or key == Enum.KeyCode.Right then
			keyRight = true
		end
		if processed then
			return
		end
		if
			key == Enum.KeyCode.Space
			or key == Enum.KeyCode.Return
			or input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self.confirm()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local key = input.KeyCode
		if key == Enum.KeyCode.A or key == Enum.KeyCode.Left then
			keyLeft = false
		elseif key == Enum.KeyCode.D or key == Enum.KeyCode.Right then
			keyRight = false
		end
	end)

	return self
end

return AimInput
