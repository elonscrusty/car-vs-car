--!strict
-- The Ram Truck a new player drives in the practice yard (carter's L6): the very same model, size,
-- weight and driving code as in a real fight (BattleCar.spawn and BattleDrive), but built on this
-- device only, so it answers the stick at once and no other player ever sees it. If the Ram model is
-- missing from this place, a plain box truck stands in so the lesson still works.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BattleConfig = require(ReplicatedStorage.Shared.BattleConfig)
local CarWheels = require(ReplicatedStorage.Shared.CarWheels)

local PracticeCar = {}

export type Car = {
	model: Model,
	body: BasePart,
	L: number, -- the body's length after scaling (the fight code calls this one L)
	standIn: boolean,
	-- put the car back on its start spot, nose forward, standing still
	reset: () -> (),
	destroy: () -> (),
}

local FIGHTER_ID = "RamTruck"

-- A plain box truck: a blue body, a white cab, four black wheels. Nose toward -Z like every model.
local function standInModel(length: number): Model
	local m = Instance.new("Model")
	local function part(name: string, size: Vector3, offset: Vector3, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CFrame = CFrame.new(offset)
		p.Anchored = true
		p.Parent = m
		return p
	end
	local L = length
	local body = part(
		"Body",
		Vector3.new(0.5 * L, 0.3 * L, L),
		Vector3.new(0, 0.3 * L, 0),
		Color3.fromRGB(0, 113, 245)
	)
	part(
		"Cab",
		Vector3.new(0.46 * L, 0.2 * L, 0.3 * L),
		Vector3.new(0, 0.55 * L, -0.25 * L),
		Color3.fromRGB(251, 253, 255)
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local wheel = part(
				"Wheel",
				Vector3.new(0.1 * L, 0.22 * L, 0.22 * L),
				Vector3.new(sx * 0.3 * L, 0.11 * L, sz * 0.32 * L),
				Color3.fromRGB(2, 10, 20)
			)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	m.PrimaryPart = body
	return m
end

-- Builds the truck standing at `spawnCf` (floor middle, nose where the CFrame looks) under `parent`.
-- Returns nil and a reason when it cannot be built.
function PracticeCar.spawn(parent: Instance, spawnCf: CFrame): (Car?, string?)
	local fighter = BattleConfig.fighter(FIGHTER_ID)
	if fighter == nil then
		return nil, "no fighter " .. FIGHTER_ID
	end
	local models = ReplicatedStorage:FindFirstChild("BattleModels")
	local source = if models then models:FindFirstChild(fighter.model) else nil
	local standIn = source == nil or not source:IsA("Model")
	local model: Model = if standIn
		then standInModel(fighter.lengthStuds)
		else (source :: Model):Clone()
	local found = model:FindFirstChild("Body", true)
	if found == nil or not found:IsA("BasePart") then
		model:Destroy()
		return nil, "the Ram model has no part named Body"
	end
	local body = found :: BasePart
	model.PrimaryPart = body
	model.Name = "PracticeCar"

	-- scale so the body is one fighter length long (nose -Z: the length is the Z size)
	local _, size0 = model:GetBoundingBox()
	if size0.Z > 0.001 then
		model:ScaleTo(model:GetScale() * fighter.lengthStuds / size0.Z)
	end

	-- physics: one solid Body, everything else welded on and weightless
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local p = d :: BasePart
			p.Anchored = true
			if p ~= body then
				p.Massless = true
				p.CanCollide = false
				p.CanQuery = false
				local hasJoint = false
				for _, j in p:GetJoints() do
					if j:IsA("Motor6D") or j:IsA("Weld") or j:IsA("WeldConstraint") then
						hasJoint = true
					end
				end
				if not hasJoint then
					local w = Instance.new("WeldConstraint")
					w.Part0 = body
					w.Part1 = p
					w.Parent = p
				end
			end
		end
	end
	body.CanCollide = true
	body.CanQuery = true
	if body:IsA("MeshPart") then
		pcall(function()
			(body :: MeshPart).CollisionFidelity = Enum.CollisionFidelity.Box
		end)
	end
	-- the same weight, grip and bounce as in a fight
	body.CustomPhysicalProperties = PhysicalProperties.new(fighter.density, 0.2, 0.55, 1, 1)

	-- the shared wheels (still, they do not spin here); the box below then reaches down to them
	CarWheels.attach(body, fighter.model)

	-- stand on the floor: the floor middle of the body goes on the spawn point
	local bbCf, bbSize = model:GetBoundingBox()
	local floorMid = bbCf * CFrame.new(0, -bbSize.Y / 2, 0)
	local rel = model:GetPivot():ToObjectSpace(floorMid)
	local start = spawnCf.Position
	local facing = spawnCf.LookVector
	local function stand()
		local target = CFrame.lookAt(
			start + Vector3.new(0, 0.3, 0),
			start + Vector3.new(facing.X, 0, facing.Z) + Vector3.new(0, 0.3, 0)
		)
		model:PivotTo(target * rel:Inverse())
	end
	stand()

	model:SetAttribute("CarL", bbSize.Z)
	model:SetAttribute("FighterId", FIGHTER_ID)
	model:SetAttribute("ClientDriven", true) -- BattleDriver drives only models that say so
	model.Parent = parent
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			(d :: BasePart).Anchored = false
		end
	end

	local car = {} :: Car
	car.model = model
	car.body = body
	car.L = bbSize.Z
	car.standIn = standIn
	car.reset = function()
		stand()
		body.AssemblyLinearVelocity = Vector3.zero
		body.AssemblyAngularVelocity = Vector3.zero
	end
	car.destroy = function()
		model:Destroy()
	end
	return car, nil
end

return PracticeCar
