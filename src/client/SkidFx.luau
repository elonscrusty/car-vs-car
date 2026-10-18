--!strict
-- Tire marks and tire smoke for every car in the match (yours and the bot's), client only.
-- Marks are two Trails per car laid behind the rear wheels, on only while the car slides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SkidRules = require(ReplicatedStorage.Shared.SkidRules)

local FIND_EVERY = 0.5
local LIFT = 0.08 -- trail sits just above the floor
local CHECK_DOWN = 4 -- extra reach past the body for the ground check

type Rig = {
	model: Model,
	body: BasePart,
	trails: { Trail },
	smoke: ParticleEmitter,
	holder: Part,
	params: RaycastParams,
}

local SkidFx = {}

local function isCar(m: Instance): boolean
	return m:IsA("Model")
		and (string.sub(m.Name, 1, 10) == "PlayerCar_" or string.sub(m.Name, 1, 7) == "BotCar_")
end

-- Invisible anchored holder for the trail attachments (they move every frame).
local function makeRig(model: Model, body: BasePart): Rig
	local holder = Instance.new("Part")
	holder.Name = "SkidHolder"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = body.CFrame
	holder.Parent = workspace

	local trails = {}
	for i = 1, 2 do
		local a0 = Instance.new("Attachment")
		a0.Name = `Left{i}`
		a0.Parent = holder
		local a1 = Instance.new("Attachment")
		a1.Name = `Right{i}`
		a1.Parent = holder
		local t = Instance.new("Trail")
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.Color = ColorSequence.new(Color3.fromRGB(20, 20, 22))
		t.Transparency = NumberSequence.new(0.35)
		t.Lifetime = 4
		t.MinLength = 0.2
		t.FaceCamera = false
		t.LightEmission = 0
		t.Enabled = false
		t.Parent = holder
		table.insert(trails, t)
	end

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "TireSmoke"
	smoke.Color = ColorSequence.new(Color3.fromRGB(215, 215, 220))
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5),
		NumberSequenceKeypoint.new(1, 5),
	})
	smoke.Lifetime = NumberRange.new(0.6, 1.1)
	smoke.Speed = NumberRange.new(2, 6)
	smoke.SpreadAngle = Vector2.new(25, 25)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Rate = 0
	smoke.Enabled = false
	smoke.Parent = holder

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, holder }
	return {
		model = model,
		body = body,
		trails = trails,
		smoke = smoke,
		holder = holder,
		params = params,
	}
end

local function setSliding(rig: Rig, on: boolean, rate: number)
	for _, t in rig.trails do
		if t.Enabled ~= on then
			t.Enabled = on
		end
	end
	rig.smoke.Enabled = on
	rig.smoke.Rate = if on then rate else 0
end

local function step(rig: Rig)
	local body = rig.body
	local cf = body.CFrame
	local v = body.AssemblyLinearVelocity
	local half = body.Size / 2
	local down = Vector3.new(0, -(half.Y + CHECK_DOWN), 0)
	local hit = workspace:Raycast(cf.Position, down, rig.params)
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local slip = SkidRules.slipSpeed(v.X, v.Z, cf.LookVector.X, cf.LookVector.Z)
	local skid = not body.Anchored and SkidRules.isSkidding(slip, speed, hit ~= nil)
	if hit == nil or not skid then
		setSliding(rig, false, 0)
		-- keep the holder with the car so the next skid starts clean
		rig.holder.CFrame = cf
		return
	end
	local floorY = hit.Position.Y + LIFT
	local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit
	local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z).Unit
	local pos = cf.Position
	local rear = pos - flatLook * (half.Z * 0.85)
	local wheelX = half.X
	local width = 0.9
	for i, t in rig.trails do
		-- Trail 1 is the left rear wheel, trail 2 the right.
		local side = if i == 1 then -1 else 1
		local centre = rear + right * (wheelX * side)
		local a0 = t.Attachment0
		local a1 = t.Attachment1
		if a0 and a1 then
			a0.WorldPosition = Vector3.new(centre.X, floorY, centre.Z) - right * (width / 2)
			a1.WorldPosition = Vector3.new(centre.X, floorY, centre.Z) + right * (width / 2)
		end
	end
	rig.holder.CFrame = CFrame.new(Vector3.new(rear.X, floorY + 0.5, rear.Z))
	setSliding(rig, true, SkidRules.smokeRate(slip))
end

function SkidFx.new()
	local conn: RBXScriptConnection? = nil
	local rigs: { [Model]: Rig } = {}

	local function drop(model: Model)
		local rig = rigs[model]
		if rig then
			rig.holder:Destroy()
			rigs[model] = nil
		end
	end

	local function start()
		if conn then
			return
		end
		local sinceSearch = FIND_EVERY
		conn = RunService.Heartbeat:Connect(function(dt: number)
			sinceSearch += dt
			if sinceSearch >= FIND_EVERY then
				sinceSearch = 0
				for _, m in workspace:GetDescendants() do
					if isCar(m) and rigs[m :: Model] == nil then
						local b = m:FindFirstChild("Body")
						if b and b:IsA("BasePart") then
							rigs[m :: Model] = makeRig(m :: Model, b)
						end
					end
				end
			end
			for model, rig in rigs do
				if model.Parent == nil or rig.body.Parent == nil then
					drop(model)
				else
					step(rig)
				end
			end
		end)
	end

	local function stop()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		for model in rigs do
			drop(model)
		end
	end

	return { start = start, stop = stop }
end

return SkidFx
