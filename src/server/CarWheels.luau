--!strict
-- Puts the one shared wheel model on a car body four times (positions from CarRig) and spins and
-- steers them. The wheel model is ReplicatedStorage.BattleModels.MonsterWheel: a MeshPart, or a
-- Model holding one. Its axle is found from its shape (the thin side), so the import direction
-- does not matter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarRig = require(ReplicatedStorage.Shared.CarRig)

export type Handle = {
	part: MeshPart,
	weld: Weld,
	rest: CFrame, -- where the wheel sits on the body
	fix: CFrame, -- turns the wheel's own axle onto X
	front: boolean,
}

export type Wheels = {
	list: { Handle },
	radiusStuds: number,
	spin: number,
}

local CarWheels = {}

local TEMPLATE_NAME = "MonsterWheel"

local function findTemplate(): MeshPart?
	local models = ReplicatedStorage:FindFirstChild("BattleModels")
	local t = if models then models:FindFirstChild(TEMPLATE_NAME) else nil
	if t == nil then
		return nil
	end
	if t:IsA("MeshPart") then
		return t
	end
	return t:FindFirstChildWhichIsA("MeshPart", true)
end

-- The CFrame that turns the template's thinnest side onto the X axis.
local function axleFix(size: Vector3): CFrame
	if size.Y <= size.X and size.Y <= size.Z then
		return CFrame.Angles(0, 0, math.rad(90))
	elseif size.Z <= size.X and size.Z <= size.Y then
		return CFrame.Angles(0, math.rad(90), 0)
	end
	return CFrame.identity
end

-- Adds the four wheels to `body` (the car's Body part, `body.Size.Z` long). Returns nil when this
-- model has no rig or the wheel model is missing (the car just has no wheels).
function CarWheels.attach(body: BasePart, modelId: string): Wheels?
	local rig = CarRig.of(modelId)
	local template = findTemplate()
	if rig == nil or template == nil then
		return nil
	end
	local L = body.Size.Z
	local diameterRaw = math.max(template.Size.X, template.Size.Y, template.Size.Z)
	local scale = 2 * rig.wheelRadius * L / diameterRaw
	local fix = axleFix(template.Size)
	local list = {}
	for _, w in rig.wheels do
		local part = template:Clone()
		part.Name = "Wheel_" .. w.name
		part.Size = template.Size * scale
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		for _, c in part:GetChildren() do
			if c:IsA("Weld") or c:IsA("WeldConstraint") or c:IsA("Motor6D") then
				c:Destroy()
			end
		end
		local rest = CFrame.new(w.at[1] * L, w.at[2] * L - body.Size.Y / 2, w.at[3] * L)
		part.CFrame = body.CFrame * rest * fix
		local weld = Instance.new("Weld")
		weld.Part0 = body
		weld.Part1 = part
		weld.C0 = rest * fix
		weld.Parent = part
		part.Parent = body.Parent
		table.insert(list, { part = part, weld = weld, rest = rest, fix = fix, front = w.front })
	end
	return { list = list, radiusStuds = rig.wheelRadius * L, spin = 0 }
end

-- Rolls and steers the wheels from how the body is moving. Call every step.
function CarWheels.step(wheels: Wheels, body: BasePart, dt: number)
	local look = body.CFrame.LookVector
	local v = body.AssemblyLinearVelocity
	local forward = v.X * look.X + v.Z * look.Z
	wheels.spin = CarRig.spin(wheels.spin, forward, wheels.radiusStuds, dt)
	local steer = CarRig.steer(body.AssemblyAngularVelocity.Y, forward)
	for _, h in wheels.list do
		-- forward is -Z, so rolling forward turns the wheel about +X
		local roll = CFrame.Angles(-wheels.spin, 0, 0)
		local turn = if h.front then CFrame.Angles(0, steer, 0) else CFrame.identity
		h.weld.C0 = h.rest * turn * roll * h.fix
	end
end

return CarWheels
