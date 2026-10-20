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
local CollectionService = game:GetService("CollectionService")

local BattleConfig = require(ReplicatedStorage.Shared.BattleConfig)
local BattleBrain = require(ReplicatedStorage.Shared.BattleBrain)
local BattleRecap = require(ReplicatedStorage.Shared.BattleRecap)

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
	lungeT: number, -- momentum: time since the last forward lunge
	human: boolean, -- a player drives this car (manual driving)
	momentum: boolean, -- the momentum prototype: launch, skid, rebound, weak steering
	stats: BattleRecap.Stats, -- what this car's weapon did this round (for the recap)
	stagger: number, -- > 0 while knocked: the car slides and cannot steer
	slide: Vector3, -- flat velocity a wall bounce keeps pushing while knocked (floor friction would eat it)
	prevVel: Vector3, -- velocity at the end of the last step (before any crash changed it)
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
	-- a heavy car shoves a light one in a crash; walls bounce a car without hurting it
	body.CustomPhysicalProperties = PhysicalProperties.new(fighter.density, 0.2, 0.55, 1, 1)

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
		stagger = 0,
		slide = Vector3.zero,
		prevVel = Vector3.zero,
		human = false,
		momentum = false,
		lungeT = 0,
		stats = BattleRecap.newStats(),
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
-- Momentum prototype: bouncy, slippery body and a launch along the opening aim.
function BattleCar.launch(car: Car, momentum: boolean)
	car.momentum = momentum
	if not momentum then
		return
	end
	local mom = BattleConfig.Momentum
	car.body.CustomPhysicalProperties =
		PhysicalProperties.new(0.7, mom.friction, mom.elasticity, 1, 100)
	local f = car.lastForward
	local speed = mom.launchL * car.L
	car.body.AssemblyLinearVelocity = Vector3.new(f.X * speed, 0, f.Z * speed)
end

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

-- A wall part the map tags "Bouncy" (the duel arena walls, cover blocks and tires) throws a car back
-- that runs into it, instead of letting the drive code push it to a dead stop. The car loses a bit
-- of speed, slides back for a moment and cannot steer meanwhile (the knocked state). No damage.
-- Every car has the same top speed (spec: only weight and turning differ).
function BattleCar.topSpeed(_car: Car): number
	return BattleConfig.Human.topSpeed
end

local function wallBounce(car: Car, v: Vector3, dt: number): boolean
	local body = car.body
	local flat = Vector3.new(v.X, 0, v.Z)
	local speed = flat.Magnitude
	if speed < 0.3 * BattleCar.topSpeed(car) then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { car.model }
	local reach = body.Size.Z / 2 + math.max(speed * dt * 3, 3) + 1
	local hit = workspace:Raycast(body.Position, flat.Unit * reach, params)
	if hit == nil or not CollectionService:HasTag(hit.Instance, "Bouncy") then
		return false
	end
	local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
	if n.Magnitude < 1e-3 then
		return false
	end
	n = n.Unit
	local props = (hit.Instance :: BasePart).CustomPhysicalProperties
	local keep = (if props then props.Elasticity else 0.5) * 0.85
	local r = (flat - 2 * flat:Dot(n) * n) * keep
	body.AssemblyLinearVelocity = Vector3.new(r.X, v.Y, r.Z)
	car.stagger = math.max(car.stagger, 0.6)
	car.slide = Vector3.new(r.X, 0, r.Z)
	return true
end

-- Turns the brain's answer into movement. Only forward speed and turning are driven, so cars
-- steer like cars and do not slide sideways (sideways speed dies out fast); bumps still push.
function BattleCar.drive(car: Car, out: BattleBrain.Output, dt: number)
	local mv = BattleConfig.Move
	local body = car.body
	local f = BattleCar.forward(car)
	local v = body.AssemblyLinearVelocity
	if car.stagger <= 0 and wallBounce(car, v, dt) then
		return
	end
	if car.stagger > 0 then
		-- knocked: slide and spin on the shove, no steering
		car.stagger = math.max(0, car.stagger - dt)
		local keep = math.max(0, 1 - mv.knockFriction * dt)
		if car.slide.Magnitude > 0 then
			-- a wall bounce: hold the slide ourselves so the floor does not stop it in a blink
			car.slide *= keep
			body.AssemblyLinearVelocity = Vector3.new(car.slide.X, v.Y, car.slide.Z)
			if car.stagger <= 0 then
				car.slide = Vector3.zero
			end
			return
		end
		body.AssemblyLinearVelocity = Vector3.new(v.X * keep, v.Y, v.Z * keep)
		return
	end
	if car.human then
		BattleCar.driveHuman(car, out, dt, f, v)
		return
	end
	local fwd = v.X * f.X + v.Z * f.Z
	local lat = Vector3.new(v.X - f.X * fwd, 0, v.Z - f.Z * fwd)
	local cruise = BattleCar.topSpeed(car)
	local want = out.drive * cruise
	if want < 0 then
		want *= mv.reverseScale
	end
	local mom = BattleConfig.Momentum
	local rate = if math.abs(want) > math.abs(fwd)
		then (if car.momentum then mom.accel else mv.accel)
		else (if car.momentum then mom.brake else mv.brake)
	if out.state == "charge" or out.state == "rev" then
		rate *= 4 -- a charge gets up to speed fast
	end
	local step = rate * cruise * dt
	local skidding = out.state == "skid"
	if skidding then
		step = mv.skidBrake * cruise * dt -- keep rolling: the truck overshoots
	end
	fwd += math.clamp(want - fwd, -step, step)
	lat *= math.max(
		0,
		1 - (if car.momentum then mom.side elseif skidding then mv.skidSide else 8) * dt
	)
	body.AssemblyLinearVelocity = Vector3.new(f.X * fwd + lat.X, v.Y, f.Z * fwd + lat.Z)
	local turnScale = math.clamp(math.abs(fwd) / (0.5 * cruise) + 0.35, 0, 1)
	if car.momentum then
		turnScale = mom.turnScale
	end
	if out.state == "charge" then
		turnScale = 0
	end
	local yaw = out.turn * math.rad(car.fighter.turnDeg) * turnScale * BattleConfig.Bot.turnMult
	body.AssemblyAngularVelocity = Vector3.new(0, yaw, 0)
end

-- A car the player drives: quicker getaway, tight turns from a standstill, a drift when steering
-- hard at speed, and no forced speed while airborne (so a ramp launches it properly).
function BattleCar.driveHuman(car: Car, out: BattleBrain.Output, dt: number, f: Vector3, v: Vector3)
	local mv = BattleConfig.Move
	local H = BattleConfig.Human
	local body = car.body
	local cruise = BattleCar.topSpeed(car)
	local yawRate = out.turn * math.rad(car.fighter.turnDeg)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { car.model }
	local onGround = workspace:Raycast(
		body.Position,
		Vector3.new(0, -(body.Size.Y * 0.5 + H.groundRayL * car.L), 0),
		params
	) ~= nil
	car.model:SetAttribute("Airborne", not onGround)
	if not onGround then
		-- in the air: keep the speed and spin the ramp gave it, steer a little
		local w = body.AssemblyAngularVelocity
		body.AssemblyAngularVelocity = Vector3.new(w.X, yawRate * H.airYawScale, w.Z)
		return
	end

	local fwd = v.X * f.X + v.Z * f.Z
	local lat = Vector3.new(v.X - f.X * fwd, 0, v.Z - f.Z * fwd)
	local want = out.drive * cruise
	if want < 0 then
		want *= mv.reverseScale
	end
	local speeding = math.abs(want) > math.abs(fwd)
	local rate = if speeding then mv.accel * H.accelMult else mv.brake * H.brakeMult
	if out.state == "charge" then
		rate = mv.accel * 4 -- a charge gets up to speed fast
	end
	local step = rate * cruise * dt
	local skidding = out.state == "skid"
	if skidding then
		step = mv.skidBrake * cruise * dt -- a missed charge rolls on
	end
	fwd += math.clamp(want - fwd, -step, step)

	local speedFrac = math.abs(fwd) / cruise
	local drifting = not skidding
		and out.state ~= "charge"
		and math.abs(out.turn) >= H.driftSteer
		and speedFrac >= H.driftSpeed
	car.model:SetAttribute("Drifting", drifting)
	local sideGrip = if skidding then mv.skidSide elseif drifting then H.driftSide else 8
	lat *= math.max(0, 1 - sideGrip * dt)
	local maxSlide = H.slideMaxFrac * cruise
	if lat.Magnitude > maxSlide then
		lat = lat.Unit * maxSlide
	end
	body.AssemblyLinearVelocity = Vector3.new(f.X * fwd + lat.X, v.Y, f.Z * fwd + lat.Z)

	local turnScale = math.clamp(speedFrac / 0.5 + H.turnMinScale, H.turnMinScale, 1)
	if out.state == "charge" then
		turnScale = 0
	elseif drifting then
		turnScale = H.driftYawBoost
	end
	body.AssemblyAngularVelocity = Vector3.new(0, yawRate * turnScale, 0)
end

-- Are the two cars' bodies touching (or almost) right now?
function BattleCar.bodiesTouch(a: Car, b: Car): boolean
	local pad = BattleConfig.Crash.touchPadL * a.L
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { b.body }
	return #workspace:GetPartBoundsInBox(
		a.body.CFrame,
		a.body.Size + Vector3.one * (2 * pad),
		params
	) > 0
end

-- Remember this step's velocity (the next step reads it as the speed from BEFORE a crash).
function BattleCar.rememberVelocity(car: Car)
	car.prevVel = car.body.AssemblyLinearVelocity
end

-- Momentum prototype: a car that has slowed down is thrown forward again along its heading
-- (toward the foe, since it keeps steering that way), so the fight never goes sleepy.
function BattleCar.lunge(car: Car, dt: number)
	if not car.momentum or car.stagger > 0 then
		return
	end
	car.lungeT += dt
	local mom = BattleConfig.Momentum
	if car.lungeT < mom.lungeSeconds then
		return
	end
	car.lungeT = 0
	local f = car.lastForward
	local v = car.body.AssemblyLinearVelocity
	local fwd = v.X * f.X + v.Z * f.Z
	local want = mom.lungeL * car.L
	if fwd < want then
		car.body.AssemblyLinearVelocity = Vector3.new(f.X * want, v.Y, f.Z * want)
	end
end

-- A shove along `dir` (flat): the car slides away and cannot steer for `stagger` seconds, and it
-- spins a little. A white flash on the car shows the hit before anything else.
function BattleCar.knock(car: Car, dir: Vector3, speed: number, stagger: number)
	local d = planar(dir)
	if car.momentum then
		speed *= BattleConfig.Momentum.knockMult
	end
	car.stagger = math.max(car.stagger, stagger)
	car.slide = Vector3.zero -- a fresh shove replaces a wall slide
	local v = car.body.AssemblyLinearVelocity
	car.body.AssemblyLinearVelocity = Vector3.new(d.X * speed, v.Y, d.Z * speed)
	local side = if (d:Cross(car.lastForward)).Y >= 0 then 1 else -1
	car.body.AssemblyAngularVelocity = Vector3.new(0, side * 4.5, 0)
	local flash = Instance.new("Highlight")
	flash.FillColor = Color3.new(1, 1, 1)
	flash.FillTransparency = 0.25
	flash.OutlineTransparency = 1
	flash.DepthMode = Enum.HighlightDepthMode.Occluded
	flash.Parent = car.model
	task.delay(0.14, function()
		flash:Destroy()
	end)
end

-- Knock-out finish: the car stops, smokes and goes dark. Removed with the model.
function BattleCar.wreck(car: Car)
	car.brain = nil
	car.stagger = 0.001
	car.slide = Vector3.zero
	local body = car.body
	local burn = Instance.new("Highlight")
	burn.FillColor = Color3.fromRGB(30, 25, 25)
	burn.FillTransparency = 0.35
	burn.OutlineColor = Color3.fromRGB(255, 120, 30)
	burn.OutlineTransparency = 0.2
	burn.Parent = car.model
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(40, 40, 40)
	smoke.Size = 0.9 * car.L
	smoke.RiseVelocity = 0.5 * car.L
	smoke.Opacity = 0.8
	smoke.Parent = body
	local fire = Instance.new("Fire")
	fire.Size = 0.5 * car.L
	fire.Heat = 6
	fire.Parent = body
	local boom = Instance.new("Explosion")
	boom.BlastPressure = 0
	boom.BlastRadius = 0.7 * car.L
	boom.DestroyJointRadiusPercent = 0
	boom.Position = body.Position + Vector3.new(0, 0.3 * car.L, 0)
	boom.Parent = body
end

-- Rolls to a stop (used while the finish plays).
function BattleCar.coast(car: Car, dt: number)
	local v = car.body.AssemblyLinearVelocity
	local keep = math.max(0, 1 - 3 * dt)
	car.body.AssemblyLinearVelocity = Vector3.new(v.X * keep, v.Y, v.Z * keep)
	local w = car.body.AssemblyAngularVelocity
	car.body.AssemblyAngularVelocity = Vector3.new(0, w.Y * keep, 0)
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
