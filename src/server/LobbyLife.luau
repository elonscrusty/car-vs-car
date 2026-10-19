--!strict
-- Things that move or glow in the lobby so it never feels frozen: the lift car rises and sinks,
-- neon signs flicker, the big sign changes colour, pad lights pulse, steam puffs from the floor
-- grates, a welder throws sparks, dust floats in the light, and light beams sweep the hero stage.
-- Everything is cheap (a few emitters, one 20 Hz loop) so phones stay smooth.
-- Parts are found by name, so a missing piece is just skipped.

local RunService = game:GetService("RunService")

local LobbyLife = {}

local CYAN = Color3.fromRGB(60, 220, 255)
local YELLOW = Color3.fromRGB(255, 205, 40)

local function emitterOn(
	parent: Instance,
	size: Vector3,
	pos: Vector3,
	color: Color3,
	build: (e: ParticleEmitter) -> ()
): ParticleEmitter
	local p = Instance.new("Part")
	p.Name = "LifeEmitter"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.Position = pos
	p.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Rate = 0
	build(e)
	e.Parent = p
	return e
end

function LobbyLife.build(folder: Folder, origin: Vector3, stage: Vector3, stageTop: number)
	local rng = Random.new()
	local life = Instance.new("Folder")
	life.Name = "Life"
	life.Parent = folder

	-- Parts that ride up and down with the lift.
	local liftParts: { { part: BasePart, base: CFrame } } = {}
	for _, d in folder:GetChildren() do
		if
			d:IsA("BasePart") and (string.sub(d.Name, 1, 7) == "LiftCar" or d.Name == "LiftPlate")
		then
			table.insert(liftParts, { part = d, base = d.CFrame })
		end
	end

	-- Neon sign texts that flicker.
	local signs: { TextLabel } = {}
	for _, d in folder:GetChildren() do
		if d.Name == "NeonSign" then
			local t = d:FindFirstChildWhichIsA("TextLabel", true)
			if t then
				table.insert(signs, t)
			end
		end
	end
	local bigSign: TextLabel? = nil
	local ws = folder:FindFirstChild("WallSign")
	if ws then
		bigSign = ws:FindFirstChildWhichIsA("TextLabel", true)
	end

	-- Pad lights.
	local padLights: { PointLight } = {}
	for i = 1, 4 do
		local pad = folder:FindFirstChild("MatchPad" .. i)
		local l = if pad then pad:FindFirstChildWhichIsA("PointLight") else nil
		if l then
			table.insert(padLights, l)
		end
	end

	-- Hero stage extras: a floating holo ring and one light beam from the ceiling.
	local holo = Instance.new("Part")
	holo.Name = "HoloRing"
	holo.Shape = Enum.PartType.Cylinder
	holo.Size = Vector3.new(0.2, 24, 24)
	holo.Anchored = true
	holo.CanCollide = false
	holo.CanQuery = false
	holo.CanTouch = false
	holo.CastShadow = false
	holo.Material = Enum.Material.Neon
	holo.Color = CYAN
	holo.Transparency = 0.97
	holo.Parent = life
	local holoBase = origin + stage + Vector3.new(0, stageTop + 12, 0)

	local beams: { Part } = {}
	for _, sx in { 1 } do -- one spotlight
		local from = origin + stage + Vector3.new(sx * 24, 36, 6)
		local to = origin + stage + Vector3.new(0, stageTop, 0)
		local len = (to - from).Magnitude
		local b = Instance.new("Part")
		b.Name = "StageBeam"
		b.Shape = Enum.PartType.Cylinder
		b.Size = Vector3.new(len, 8, 8)
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.CastShadow = false
		b.Material = Enum.Material.Neon
		b.Color = Color3.fromRGB(255, 232, 180)
		b.Transparency = 0.97
		b.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to) * CFrame.Angles(0, math.pi / 2, 0)
		b.Parent = life
		table.insert(beams, b)
	end

	-- Dust floating in the light, over the whole hall.
	emitterOn(
		life,
		Vector3.new(170, 30, 130),
		origin + Vector3.new(0, 18, 0),
		Color3.new(1, 1, 1),
		function(e)
			e.Rate = 12
			e.Lifetime = NumberRange.new(10, 14)
			e.Speed = NumberRange.new(0.2, 0.7)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Size = NumberSequence.new(0.18)
			e.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.55),
				NumberSequenceKeypoint.new(0.8, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			})
			e.LightEmission = 0.6
			e.EmissionDirection = Enum.NormalId.Top
		end
	)

	-- Sparkles rising off the hero stage.
	emitterOn(
		life,
		Vector3.new(26, 0.5, 20),
		origin + stage + Vector3.new(0, stageTop + 0.4, 0),
		CYAN,
		function(e)
			e.Rate = 10
			e.Lifetime = NumberRange.new(2, 3.5)
			e.Speed = NumberRange.new(2, 5)
			e.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(1, 0),
			})
			e.LightEmission = 1
			e.EmissionDirection = Enum.NormalId.Top
			e.SpreadAngle = Vector2.new(10, 10)
		end
	)

	-- Steam from the floor grates, a puff every few seconds.
	local steams: { ParticleEmitter } = {}
	for _, d in folder:GetChildren() do
		if d.Name == "DrainGrate" and d:IsA("BasePart") then
			table.insert(
				steams,
				emitterOn(
					life,
					Vector3.new(2, 0.2, 2),
					d.Position + Vector3.new(0, 0.3, 0),
					Color3.fromRGB(230, 235, 245),
					function(e)
						e.Lifetime = NumberRange.new(1.6, 2.6)
						e.Speed = NumberRange.new(3, 6)
						e.Size = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1.2),
							NumberSequenceKeypoint.new(1, 5),
						})
						e.Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.7),
							NumberSequenceKeypoint.new(1, 1),
						})
						e.EmissionDirection = Enum.NormalId.Top
						e.SpreadAngle = Vector2.new(12, 12)
					end
				)
			)
		end
	end

	-- Welder sparks at the workbench.
	local sparks: ParticleEmitter? = nil
	local bench = folder:FindFirstChild("Workbench")
	if bench and bench:IsA("BasePart") then
		sparks = emitterOn(
			life,
			Vector3.new(1, 0.2, 1),
			bench.Position + Vector3.new(0, bench.Size.Y / 2 + 0.3, 0),
			YELLOW,
			function(e)
				e.Lifetime = NumberRange.new(0.4, 0.8)
				e.Speed = NumberRange.new(10, 18)
				e.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.3),
					NumberSequenceKeypoint.new(1, 0),
				})
				e.Acceleration = Vector3.new(0, -40, 0)
				e.LightEmission = 1
				e.EmissionDirection = Enum.NormalId.Top
				e.SpreadAngle = Vector2.new(50, 50)
			end
		)
	end

	local t = 0
	local acc = 0
	local nextFlicker = 3
	local flickerLeft = 0
	local nextPuff = 2
	local nextWeld = 4
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		acc += dt
		if acc < 0.05 then
			return
		end
		acc = 0

		-- Lift: up for a while, down for a while.
		local lift = (math.sin(t * 0.35) * 0.5 + 0.5) * 3.2
		for _, lp in liftParts do
			lp.part.CFrame = lp.base + Vector3.new(0, lift, 0)
		end

		-- Holo ring bobs and spins; beams breathe.
		holo.CFrame = CFrame.new(holoBase + Vector3.new(0, math.sin(t * 1.2) * 0.6, 0))
			* CFrame.Angles(0, t * 0.8, math.pi / 2)
		for i, b in beams do
			b.Transparency = 0.965 + 0.02 * math.sin(t * 0.9 + i * 2)
		end

		-- Pad lights pulse.
		for i, l in padLights do
			l.Brightness = 1.5 + 0.4 * math.sin(t * 2.2 + i) -- the PLAY pads are the brightest thing in the hall
		end

		-- Big sign swaps between yellow and cyan.
		if bigSign then
			bigSign.TextColor3 = YELLOW:Lerp(CYAN, math.sin(t * 0.8) * 0.5 + 0.5)
		end

		-- Neon flicker: now and then the signs stutter.
		nextFlicker -= 0.05
		if nextFlicker <= 0 then
			flickerLeft = 6
			nextFlicker = 5 + rng:NextNumber(0, 6)
		end
		for _, s in signs do
			s.TextTransparency = if flickerLeft > 0 and flickerLeft % 2 == 0 then 0.7 else 0
		end
		if flickerLeft > 0 then
			flickerLeft -= 1
		end

		nextPuff -= 0.05
		if nextPuff <= 0 then
			nextPuff = 4 + rng:NextNumber(0, 6)
			local e = steams[rng:NextInteger(1, math.max(1, #steams))]
			if e then
				e:Emit(10)
			end
		end
		nextWeld -= 0.05
		if nextWeld <= 0 and sparks then
			sparks:Emit(14)
			if nextWeld < -0.6 then
				nextWeld = 3 + rng:NextNumber(0, 4)
			end
		end
	end)
	folder.Destroying:Connect(function()
		conn:Disconnect()
	end)
end

return LobbyLife
