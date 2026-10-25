--!strict
-- Crash test dummy: 6 block parts joined with ball sockets = a simple ragdoll.
-- Launched upward out of the loser's car.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local Dummy = {}

local function limb(model: Model, name: string, size: Vector3, pos: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- Joins two limbs with a ball socket. Offsets are where the joint sits on each limb (local).
local function joint(a: Part, offsetA: Vector3, b: Part, offsetB: Vector3)
	local attA = Instance.new("Attachment")
	attA.Position = offsetA
	attA.Parent = a
	local attB = Instance.new("Attachment")
	attB.Position = offsetB
	attB.Parent = b
	local socket = Instance.new("BallSocketConstraint")
	socket.Attachment0 = attA
	socket.Attachment1 = attB
	socket.LimitsEnabled = true
	socket.UpperAngle = 70
	socket.Parent = a
end

-- Spawns the dummy above `at` and throws it up. Returns the torso (camera target).
function Dummy.launch(at: Vector3, parent: Instance): Part
	local cfg = GameConfig.Dummy
	local model = Instance.new("Model")
	model.Name = "CrashDummy"

	local yellow = Color3.fromRGB(255, 205, 40)
	local orange = Color3.fromRGB(255, 130, 30)
	local origin = at + Vector3.new(0, 6, 0)

	local torso = limb(model, "Torso", Vector3.new(2, 2, 1), origin, orange)
	local head =
		limb(model, "Head", Vector3.new(1.4, 1.4, 1.4), origin + Vector3.new(0, 1.8, 0), yellow)
	local armL = limb(model, "ArmL", Vector3.new(1, 2, 1), origin + Vector3.new(-1.6, 0, 0), yellow)
	local armR = limb(model, "ArmR", Vector3.new(1, 2, 1), origin + Vector3.new(1.6, 0, 0), yellow)
	local legL =
		limb(model, "LegL", Vector3.new(1, 2, 1), origin + Vector3.new(-0.5, -2, 0), yellow)
	local legR = limb(model, "LegR", Vector3.new(1, 2, 1), origin + Vector3.new(0.5, -2, 0), yellow)

	joint(torso, Vector3.new(0, 1, 0), head, Vector3.new(0, -0.7, 0))
	joint(torso, Vector3.new(-1, 0.8, 0), armL, Vector3.new(0.5, 0.8, 0))
	joint(torso, Vector3.new(1, 0.8, 0), armR, Vector3.new(-0.5, 0.8, 0))
	joint(torso, Vector3.new(-0.5, -1, 0), legL, Vector3.new(0, 1, 0))
	joint(torso, Vector3.new(0.5, -1, 0), legR, Vector3.new(0, 1, 0))

	model.PrimaryPart = torso
	model.Parent = parent
	pcall(function()
		torso:SetNetworkOwner(nil) -- server owns the physics
	end)

	-- Big up-throw plus a random sideways push, and a tumble.
	local rng = Random.new()
	local side = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * cfg.launchSpread
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = Vector3.new(0, cfg.launchUp, 0) + side
			part.AssemblyAngularVelocity =
				Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
		end
	end
	Debris:AddItem(model, cfg.lifetime)
	return torso
end

return Dummy
