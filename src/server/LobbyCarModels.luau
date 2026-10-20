--!strict
-- Show cars for the lobby (stages, shop, turntable, parking spots): look-only copies of the battle
-- car models in ReplicatedStorage.BattleModels, scaled to a length, with a toy stand-in when a model
-- is missing so the lobby never has a hole. Cars face -Z (the models' nose) before `place` turns them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BattleConfig = require(ReplicatedStorage.Shared.BattleConfig)

local LobbyCarModels = {}

local STAND_IN_COLORS: { [string]: Color3 } = {
	RamTruck = Color3.fromRGB(214, 58, 52),
	CannonVan = Color3.fromRGB(37, 141, 221),
	SawBuggy = Color3.fromRGB(245, 130, 32),
}

local function box(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- A chunky box car, 1 stud = 1 unit, about 16 long.
local function standIn(id: string): Model
	local m = Instance.new("Model")
	local color = STAND_IN_COLORS[id] or Color3.fromRGB(200, 200, 210)
	local body = box(m, "Body", Vector3.new(8, 2.6, 16), Vector3.new(0, 2.2, 0), color)
	box(
		m,
		"Cabin",
		Vector3.new(6.4, 2.4, 7),
		Vector3.new(0, 4.6, 1.5),
		color:Lerp(Color3.new(0, 0, 0), 0.35)
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -5, 5 } do
			local w = box(
				m,
				"Wheel",
				Vector3.new(1.6, 3.2, 3.2),
				Vector3.new(sx * 4.4, 1.6, sz),
				Color3.fromRGB(36, 39, 43)
			)
			w.Shape = Enum.PartType.Cylinder
		end
	end
	m.PrimaryPart = body
	return m
end

-- A look-only car of `fighterId`, `length` studs long, parented to `parent`. Always returns a model.
function LobbyCarModels.make(parent: Instance, fighterId: string, length: number): Model
	local fighter = BattleConfig.Fighters[fighterId]
	local models = ReplicatedStorage:FindFirstChild("BattleModels")
	local src = if models and fighter then models:FindFirstChild(fighter.model) else nil
	local model: Model = if src and src:IsA("Model") then src:Clone() else standIn(fighterId)
	model.Name = "ShowCar_" .. fighterId
	local body = model:FindFirstChild("Body", true)
	if body and body:IsA("BasePart") then
		model.PrimaryPart = body
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		elseif d:IsA("BaseScript") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") then
			d:Destroy()
		end
	end
	model.Parent = parent
	local _, size0 = model:GetBoundingBox()
	local longest = math.max(size0.X, size0.Z, 0.1)
	model:ScaleTo(model:GetScale() * length / longest)
	return model
end

-- Stands the car on `cf` (its nose along cf.LookVector, wheels on cf.Y, middle over cf's x/z).
-- Returns the pivot it ended with (for spinning).
function LobbyCarModels.place(model: Model, cf: CFrame): CFrame
	local pos = cf.Position
	model:PivotTo(CFrame.new(pos) * cf.Rotation)
	local bbCf, bbSize = model:GetBoundingBox()
	local shift = Vector3.new(pos.X - bbCf.X, pos.Y - (bbCf.Y - bbSize.Y / 2), pos.Z - bbCf.Z)
	model:PivotTo(model:GetPivot() + shift)
	return model:GetPivot()
end

-- Turns a placed car round the upright line through `center`: pass the pivot `place` returned.
function LobbyCarModels.spin(model: Model, base: CFrame, center: Vector3, angle: number)
	model:PivotTo(CFrame.new(center) * CFrame.Angles(0, angle, 0) * CFrame.new(-center) * base)
end

-- Paints every part gold and shiny (the weekly #1's car).
function LobbyCarModels.gold(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d:IsA("MeshPart") then
				d.TextureID = ""
			end
			if d.Name ~= "Wheel" then
				d.Color = Color3.fromRGB(255, 205, 64)
				d.Material = Enum.Material.Metal
			end
		end
	end
end

function LobbyCarModels.paint(model: Model, color: Color3)
	for _, d in model:GetDescendants() do
		local name: string = d.Name
		if
			(d:IsA("MeshPart") and d.TextureID == "" and name ~= "Wheel")
			or (d:IsA("Part") and name == "Body")
		then
			d.Color = color
		end
	end
end

return LobbyCarModels
