--!strict
-- Drag-to-launch on the client (phone touch or mouse): press anywhere, pull back like a slingshot,
-- let go to launch. The arrow shows where the car will go and how hard. The client only sends
-- angle + power; the server checks them again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Aim = require(ReplicatedStorage.Shared.Aim)
local Duel = require(ReplicatedStorage.Shared.Duel)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

export type AimInput = {
	start: (carPos: Vector3) -> (),
	stop: () -> (),
}

local AimInput = {}

function AimInput.new(
	onPower: (power: number) -> (),
	onFire: (angle: number, power: number) -> ()
): AimInput
	local active = false
	local dragging: InputObject? = nil
	local startPos = Vector2.zero
	local curPos = Vector2.zero
	local rightX, rightZ, fwdX, fwdZ = 1, 0, 0, -1
	local carPos = Vector3.zero
	local arrow: Folder? = nil
	local shaft: Part? = nil
	local head: Part? = nil
	local lastAngle, lastPower = 0, 0

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

	-- Reads the current drag: returns (angleDeg, power 0..1). Power 0 = not a real aim yet.
	local function readDrag(): (number, number)
		local view = (workspace.CurrentCamera :: Camera).ViewportSize
		local short = math.min(view.X, view.Y)
		local d = curPos - startPos
		local power = Duel.dragPower(
			d.Magnitude,
			short * GameConfig.Drag.minFrac,
			short * GameConfig.Drag.maxFrac
		)
		local wx, wz = Duel.dragToWorld(d.X, d.Y, rightX, rightZ, fwdX, fwdZ)
		if wx * wx + wz * wz < 1e-6 then
			return lastAngle, 0
		end
		return Duel.angleOf(wx, wz), power
	end

	local function updateArrow(angle: number, power: number)
		if shaft == nil or head == nil then
			return
		end
		local dir = Aim.direction(Vector3.zAxis, angle)
		local len = 4 + 20 * power
		local start = carPos + Vector3.new(0, 3, 0)
		shaft.Size = Vector3.new(0.9, 0.3, len)
		shaft.CFrame = CFrame.lookAt(start + dir * (len / 2), start + dir * (len / 2 + 1))
		local tip = start + dir * (len + 1.5)
		head.CFrame = CFrame.lookAt(tip, tip + dir) * CFrame.Angles(0, 0, math.rad(45))
		local hot = Color3.fromRGB(255, 220, 40):Lerp(Color3.fromRGB(255, 40, 60), power)
		shaft.Color, head.Color = hot, hot
	end

	RunService.RenderStepped:Connect(function()
		if active and dragging then
			local angle, power = readDrag()
			lastAngle, lastPower = angle, power
			updateArrow(angle, power)
			onPower(power)
		end
	end)

	local self: AimInput = {} :: any

	self.start = function(pos: Vector3)
		destroyArrow()
		carPos = pos
		active = true
		dragging = nil
		lastAngle, lastPower = 0, 0
		local folder = Instance.new("Folder")
		folder.Name = "LocalAimArrow"
		-- Hidden until the player starts dragging.
		local newShaft = makeArrowPart(Vector3.new(0.9, 0.3, 4))
		local newHead = makeArrowPart(Vector3.new(3.2, 0.3, 3.2))
		newShaft.Transparency, newHead.Transparency = 1, 1
		newShaft.Parent, newHead.Parent = folder, folder
		folder.Parent = workspace
		arrow, shaft, head = folder, newShaft, newHead
	end

	self.stop = function()
		active = false
		dragging = nil
		destroyArrow()
	end

	local function isPointer(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not active or dragging or not isPointer(input) then
			return
		end
		dragging = input
		startPos = Vector2.new(input.Position.X, input.Position.Y)
		curPos = startPos
		-- Camera directions are fixed for this drag, flat on the ground.
		local cf = (workspace.CurrentCamera :: Camera).CFrame
		local r, f = cf.RightVector, cf.LookVector
		rightX, rightZ, fwdX, fwdZ = r.X, r.Z, f.X, f.Z
		if shaft and head then
			shaft.Transparency, head.Transparency = 0, 0
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging == nil then
			return
		end
		local isMove = input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		if
			isMove
			and (input == dragging or input.UserInputType == Enum.UserInputType.MouseMovement)
		then
			curPos = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if not active or dragging == nil then
			return
		end
		if
			input ~= dragging
			and not (isPointer(input) and input.UserInputType == dragging.UserInputType)
		then
			return
		end
		curPos = Vector2.new(input.Position.X, input.Position.Y)
		local angle, power = readDrag()
		dragging = nil
		if power <= 0 then
			-- Too short: cancel, try again.
			if shaft and head then
				shaft.Transparency, head.Transparency = 1, 1
			end
			onPower(0)
			return
		end
		active = false
		destroyArrow()
		onFire(angle, power)
	end)

	return self
end

return AimInput
