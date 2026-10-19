--!strict
-- One auto-battle car on the server: builds a battle clone from the supplied model, drives it
-- from the brain's answers, and measures weapon contact. The authored models stay untouched in
-- ReplicatedStorage.BattleModels (the clones are what fight).
--
-- Model contract (docs/BATTLE_MODELS.md): a Model named like BattleConfig.Fighters[id].model with a
-- part named "Body" (the PrimaryPart), nose toward -Z, up +Y. The supplied models are one merged
-- mesh each, so the weapon points are measured from the body size (BattleConfig weaponForward/Up).
-- A part named Muzzle / RamHit / SawHit inside the model overrides the measured one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BattleConfig = require(ReplicatedStorage.Shared.BattleConfig)
local BattleBrain = require(ReplicatedStorage.Shared.BattleBrain)

export type Car = {
	side: string,
	fighter: BattleConfig.Fighter,
	model: Model,
	body: BasePart,
	L: number,
	hp: number,
	maxHp: number,
	brain: BattleBrain.Brain?,
	hitRegion: BasePart?,
	muzzle: Attachment?,
	flipT: number,
	lastForward: Vector3,
	standIn: boolean,
	lastOut: BattleBrain.Output?,
}

local BattleCar = {}

local function planar(v: Vector3): Vector3
	local p = Vector3.new(v.X, 0, v.Z)
	if p.Magnitude < 1e-4 then
		return Vector3.new(0, 0, -1)
	end
	return p.Unit
end

local function hiddenPart(name: string, size: Vector3, cf: CFrame, body: BasePart): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = p
	weld.Parent = p
	p.Parent = body.Parent
	return p
end

-- A plain box standing in for a missing model. Studio only, switched on by hand, labeled TEST.
local function standInModel(fighter: BattleConfig.Fighter): Model
	local L = fighter.lengthStuds
	local m = Instance.new("Model")
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(0.5 * L, 0.45 * L, L)
	body.Color = Color3.fromRGB(200, 200, 200)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.Parent = m
	local nose = Instance.new("Part")
	nose.Name = "NoseMarker"
	nose.Size = Vector3.new(0.3 * L, 0.15 * L, 0.2 * L)
	nose.CFrame = body.CFrame * CFrame.new(0, 0.1 * L, -0.45 * L)
	nose.Color = Color3.fromRGB(255, 80, 80)
	nose.Anchored = true
	nose.CanCollide = false
	nose.Parent = m
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 24)
	gui.StudsOffset = Vector3.new(0, 0.6 * L, 0)
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "TEST STAND-IN: " .. fighter.name
	label.TextScaled = true
	label.Parent = gui
	gui.Parent = body
	m.PrimaryPart = body
	return m
end

local function findSource(fighter: BattleConfig.Fighter): (Model?, string?, boolean)
	local models = ReplicatedStorage:FindFirstChild("BattleModels")
	local src = if models then models:FindFirstChild(fighter.model) else nil
	if src and src:IsA("Model") then
		return src, nil, false
	end
	if
		RunService:IsStudio()
		and workspace:GetAttribute(BattleConfig.Test.standInAttribute) == true
	then
		return standInModel(fighter), nil, true
	end
	return nil, `missing model ReplicatedStorage.BattleModels.{fighter.model}`, false
end

-- Builds the battle clone, frozen, standing at the spawn. Returns nil and a reason when the
-- model or its Body part is missing (nothing is substituted).
function BattleCar.spawn(
	fighterId: string,
	side: string,
	arenaFolder: Folder,
	spawnPos: Vector3,
	facing: Vector3
): (Car?, string?)
	local fighter = BattleConfig.fighter(fighterId)
	if fighter == nil then
		return nil, "unknown fighter " .. tostring(fighterId)
	end
	local src, err, standIn = findSource(fighter)
	if src == nil then
		return nil, err
	end
	local model = if standIn then src else src:Clone()
	local body = model:FindFirstChild("Body", true)
	if body == nil or not body:IsA("BasePart") then
		model:Destroy()
		return nil, `model {fighter.model} has no part named Body`
	end
	model.PrimaryPart = body
	model.Name = "Car_" .. side

	-- scale so the body is one L long (nose -Z means the length is the Z size)
	local _, size0 = model:GetBoundingBox()
	if size0.Z > 0.001 then
		model:ScaleTo(model:GetScale() * fighter.lengthStuds / size0.Z)
	end
	if size0.X > size0.Z * 1.3 then
		warn(
			`[Battle] {fighter.model} looks sideways (longer along X than Z): rotate it so the nose points toward -Z`
		)
	end

	-- physics: one solid Body, everything else welded on and weightless
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			if d ~= body then
				d.Massless = true
				d.CanCollide = false
				if d.Name ~= "RamHit" and d.Name ~= "SawHit" then
					d.CanQuery = false
				end
				local hasJoint = false
				for _, j in d:GetJoints() do
					if j:IsA("Motor6D") or j:IsA("Weld") or j:IsA("WeldConstraint") then
						hasJoint = true
					end
				end
				if not hasJoint then
					local w = Instance.new("WeldConstraint")
					w.Part0 = body
					w.Part1 = d
					w.Parent = d
				end
			end
		end
	end
	body.CanCollide = true
	body.CanQuery = true
	if body:IsA("MeshPart") then
		-- A running game cannot write this (plugin only): set Box on the saved Body mesh in Studio.
		-- The pcall just makes a model that already has it, or a stand-in, work either way.
		pcall(function()
			(body :: MeshPart).CollisionFidelity = Enum.CollisionFidelity.Box
		end)
	end
	body.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.1, 0.2, 1, 1)

	-- stand on the floor, nose toward `facing`; the floor-middle of the body goes on the spawn point
	local bbCf, bbSize = model:GetBoundingBox()
	local L = bbSize.Z
	local floorMid = bbCf * CFrame.new(0, -bbSize.Y / 2, 0)
	local rel = model:GetPivot():ToObjectSpace(floorMid)
	local target =
		CFrame.lookAt(spawnPos + Vector3.new(0, 0.3, 0), spawnPos + facing + Vector3.new(0, 0.3, 0))
	model:PivotTo(target * rel:Inverse())

	-- weapon points
	local bbCf2, bbSize2 = model:GetBoundingBox()
	local floorMid2 = bbCf2 * CFrame.new(0, -bbSize2.Y / 2, 0)
	local car: Car = {
		side = side,
		fighter = fighter,
		model = model,
		body = body,
		L = L,
		hp = fighter.hp,
		maxHp = fighter.hp,
		brain = nil,
		hitRegion = nil,
		muzzle = nil,
		flipT = 0,
		lastForward = facing,
		standIn = standIn,
		lastOut = nil,
	}
	local at = floorMid2 * CFrame.new(0, fighter.weaponUp * L, -fighter.weaponForward * L)
	if fighterId == "CannonVan" then
		local m = model:FindFirstChild("Muzzle", true)
		if m and m:IsA("Attachment") then
			car.muzzle = m
		else
			local a = Instance.new("Attachment")
			a.Name = "Muzzle"
			a.CFrame = body.CFrame:ToObjectSpace(at)
			a.Parent = body
			car.muzzle = a
		end
	else
		local regionName = if fighterId == "RamTruck" then "RamHit" else "SawHit"
		local r = model:FindFirstChild(regionName, true)
		if r and r:IsA("BasePart") then
			car.hitRegion = r
		else
			local hs = fighter.hitSize
			car.hitRegion =
				hiddenPart(regionName, Vector3.new(hs[1] * L, hs[2] * L, hs[3] * L), at, body)
		end
	end
	model:SetAttribute("BattleSide", side)
	model:SetAttribute("FighterId", fighterId)
	model.Parent = arenaFolder
	return car, nil
end

-- Free the car to move. The server owns the physics of both cars.
function BattleCar.arm(car: Car, brain: BattleBrain.Brain)
	car.brain = brain
	for _, d in car.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
	car.body:SetNetworkOwner(nil)
end

-- Stop dead and hold still (round over). Keeps the model for the result screen.
function BattleCar.freeze(car: Car)
	car.brain = nil
	for _, d in car.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.AssemblyLinearVelocity = Vector3.zero
			d.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

function BattleCar.destroy(car: Car)
	car.brain = nil
	car.model:Destroy()
end

-- Body facing for the brain, flat on the floor.
function BattleCar.forward(car: Car): Vector3
	local f = planar(car.body.CFrame.LookVector)
	car.lastForward = f
	return f
end

-- Does this car's weapon region touch the other car's body right now?
function BattleCar.overlaps(car: Car, foe: Car): boolean
	local r = car.hitRegion
	if r == nil then
		return false
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { foe.body }
	return #workspace:GetPartBoundsInBox(r.CFrame, r.Size, params) > 0
end

-- Turns the brain's answer into movement. Only forward speed and turning are driven, so cars
-- steer like cars and do not slide sideways (sideways speed dies out fast); bumps still push.
function BattleCar.drive(car: Car, out: BattleBrain.Output, dt: number)
	local mv = BattleConfig.Move
	local body = car.body
	local f = BattleCar.forward(car)
	local v = body.AssemblyLinearVelocity
	local fwd = v.X * f.X + v.Z * f.Z
	local lat = Vector3.new(v.X - f.X * fwd, 0, v.Z - f.Z * fwd)
	local cruise = car.fighter.cruiseL * car.L
	local want = out.drive * cruise
	if want < 0 then
		want *= mv.reverseScale
	end
	local rate = if math.abs(want) > math.abs(fwd) then mv.accel else mv.brake
	if out.state == "charge" then
		rate *= 4 -- a charge gets up to speed fast
	end
	local step = rate * cruise * dt
	fwd += math.clamp(want - fwd, -step, step)
	lat *= math.max(0, 1 - 8 * dt)
	body.AssemblyLinearVelocity = Vector3.new(f.X * fwd + lat.X, v.Y, f.Z * fwd + lat.Z)
	local turnScale = math.clamp(math.abs(fwd) / (0.5 * cruise) + 0.35, 0, 1)
	if out.state == "charge" then
		turnScale = 0
	end
	local yaw = out.turn * math.rad(car.fighter.turnDeg) * turnScale
	body.AssemblyAngularVelocity = Vector3.new(0, yaw, 0)
end

-- Flipped cars are set upright in place after a short delay (no heal, attacks not restarted).
function BattleCar.checkFlip(car: Car, dt: number): boolean
	local up = car.body.CFrame.UpVector.Y
	if up >= BattleConfig.Move.flipUpDot then
		car.flipT = 0
		return false
	end
	car.flipT += dt
	if car.flipT < BattleConfig.Move.flipSeconds then
		return false
	end
	car.flipT = 0
	local pos = car.body.Position + Vector3.new(0, 0.25 * car.L, 0)
	local f = car.lastForward
	local newCf = CFrame.lookAt(pos, pos + f)
	local rel = car.body.CFrame:ToObjectSpace(car.model:GetPivot())
	car.model:PivotTo(newCf * rel)
	car.body.AssemblyLinearVelocity = Vector3.zero
	car.body.AssemblyAngularVelocity = Vector3.zero
	return true
end

-- Safety net: a car pushed or dropped outside the walls is put back just inside, where it was.
function BattleCar.keepInside(
	car: Car,
	originY: number,
	localX: number,
	localZ: number,
	halfX: number,
	halfZ: number,
	origin: Vector3
)
	local m = 0.4 * car.L
	local out = math.abs(localX) > halfX - m + 2
		or math.abs(localZ) > halfZ - m + 2
		or car.body.Position.Y < originY - 4
	if not out then
		return
	end
	local x = math.clamp(localX, -(halfX - m), halfX - m)
	local z = math.clamp(localZ, -(halfZ - m), halfZ - m)
	local pos = origin + Vector3.new(x, 0.6 * car.L, z)
	local rel = car.body.CFrame:ToObjectSpace(car.model:GetPivot())
	car.model:PivotTo(CFrame.lookAt(pos, pos + car.lastForward) * rel)
	car.body.AssemblyLinearVelocity = Vector3.zero
	car.body.AssemblyAngularVelocity = Vector3.zero
end

return BattleCar
