--!strict
-- Car effects for the 1v1 fight that follow the cars every frame: a dust burst and a thump when a
-- car lands from a jump, and the engine sound of YOUR car. (carter removed the boost flame, drift
-- smoke, skid marks and speed lines.) The server only sets the "Airborne" attribute on each car
-- model; everything here is local to this player's screen.

local Debris = game:GetService("Debris")

local SoundFx = require(script.Parent.SoundFx)

export type Options = {
	shake: (amp: number) -> (), -- add camera shake (studs)
	cruise: number, -- a typical cruise speed in studs per second (for the engine pitch)
}

export type Fx = {
	step: (dt: number, models: { Model }, mine: Model?) -> (),
	stop: () -> (),
}

type CarFx = {
	dust: ParticleEmitter,
	smoke: ParticleEmitter,
	fire: ParticleEmitter,
	bar: BillboardGui?, -- the enemy's HP bar above its car
	fill: Frame?,
	lastFrac: number,
	airborne: boolean,
}

local BattleFx = {}

local function build(body: BasePart): CarFx
	local rear = Instance.new("Attachment")
	rear.Name = "FxRear"
	rear.CFrame = CFrame.new(0, -0.25 * body.Size.Y - 0.5, math.max(body.Size.Z * 0.42, 3))
	rear.Parent = body

	local dust = Instance.new("ParticleEmitter")
	dust.Name = "LandDust"
	dust.Rate = 0
	dust.Enabled = false
	dust.Lifetime = NumberRange.new(0.5, 0.9)
	dust.Speed = NumberRange.new(10, 22)
	dust.SpreadAngle = Vector2.new(180, 40)
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 7),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Color = ColorSequence.new(Color3.fromRGB(215, 205, 190))
	dust.Parent = rear

	-- damage smoke from the hood: none above 60% HP, thicker and darker as HP drops
	local hood = Instance.new("Attachment")
	hood.Name = "FxHood"
	hood.CFrame = CFrame.new(0, 0.5 * body.Size.Y, -body.Size.Z * 0.3)
	hood.Parent = body
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "DamageSmoke"
	smoke.Rate = 0
	smoke.Lifetime = NumberRange.new(1, 1.5)
	smoke.Speed = NumberRange.new(5, 9)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.SpreadAngle = Vector2.new(25, 25)
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.5),
		NumberSequenceKeypoint.new(1, 6),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Color = ColorSequence.new(Color3.fromRGB(150, 150, 150))
	smoke.Parent = hood

	-- flames from the hood when the car is nearly dead
	local fire = Instance.new("ParticleEmitter")
	fire.Name = "DamageFire"
	fire.Rate = 0
	fire.Lifetime = NumberRange.new(0.4, 0.7)
	fire.Speed = NumberRange.new(6, 10)
	fire.EmissionDirection = Enum.NormalId.Top
	fire.SpreadAngle = Vector2.new(20, 20)
	fire.LightEmission = 1
	fire.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.2),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	fire.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 70, 20))
	fire.Parent = hood
	return {
		dust = dust,
		smoke = smoke,
		fire = fire,
		bar = nil,
		fill = nil,
		lastFrac = 1,
		airborne = false,
	}
end

-- A body panel flies off the car (local to this screen).
local function flyPanel(body: BasePart)
	for _ = 1, 2 do
		local p = Instance.new("Part")
		local k = 0.22 * body.Size.Z
		p.Size = Vector3.new(k, k * 0.25, k * 1.3)
		p.Color = body.Color
		p.Material = Enum.Material.SmoothPlastic
		p.CFrame = body.CFrame
			* CFrame.new((math.random() - 0.5) * body.Size.X, body.Size.Y * 0.5, 0)
		p.CanCollide = true
		p.CanQuery = false
		p.CanTouch = false
		p.AssemblyLinearVelocity = body.AssemblyLinearVelocity
			+ Vector3.new(
				(math.random() - 0.5) * 30,
				28 + math.random() * 14,
				(math.random() - 0.5) * 30
			)
		p.AssemblyAngularVelocity =
			Vector3.new(math.random() * 14, math.random() * 14, math.random() * 14)
		p.Parent = workspace
		Debris:AddItem(p, 3)
	end
end

-- The enemy's HP bar, floating above its car.
local function enemyBar(body: BasePart): (BillboardGui, Frame)
	local gui = Instance.new("BillboardGui")
	gui.Name = "EnemyHp"
	gui.Size = UDim2.fromOffset(120, 16)
	gui.StudsOffsetWorldSpace = Vector3.new(0, body.Size.Y * 0.5 + 5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 500
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(10, 12, 22)
	stroke.Thickness = 2
	stroke.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(240, 90, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(0, 5)
	c2.Parent = fill
	gui.Parent = body
	return gui, fill
end

function BattleFx.new(opts: Options): Fx
	local states: { [Model]: CarFx } = {}

	local function step(_dt: number, models: { Model }, mine: Model?)
		local seen: { [Model]: boolean } = {}
		for _, model in models do
			local body = model:FindFirstChild("Body")
			if body == nil or not body:IsA("BasePart") then
				continue
			end
			seen[model] = true
			local st = states[model]
			if st == nil then
				st = build(body)
				states[model] = st
			end
			local isMine = model == mine
			local airborne = model:GetAttribute("Airborne") == true
			-- landing: dust burst and a thump
			if st.airborne and not airborne then
				st.dust:Emit(18)
				if isMine then
					opts.shake(2.4)
					SoundFx.play("land")
				end
			end
			st.airborne = airborne
			local frac = model:GetAttribute("HpFrac")
			local f = if type(frac) == "number" then frac else 1
			-- panels fly off at 60% and 30%
			for _, t in { 0.6, 0.3 } do
				if st.lastFrac > t and f <= t then
					flyPanel(body :: BasePart)
				end
			end
			st.lastFrac = f
			st.fire.Rate = if f < 0.25 and f > 0 then 30 else 0
			if not isMine then
				if st.bar == nil then
					st.bar, st.fill = enemyBar(body :: BasePart)
				end
				if st.fill then
					st.fill.Size = UDim2.fromScale(math.clamp(f, 0, 1), 1)
				end
			end
			local hurt = math.clamp((0.6 - f) / 0.6, 0, 1)
			st.smoke.Rate = if hurt > 0 then 8 + hurt * 24 else 0
			local grey = math.floor(150 - 110 * hurt)
			st.smoke.Color = ColorSequence.new(Color3.fromRGB(grey, grey, grey))
			if isMine then
				local speed = (body :: BasePart).AssemblyLinearVelocity.Magnitude
				SoundFx.engine(speed / math.max(opts.cruise, 1))
			end
		end
		-- forget cars that are gone
		for model, st in states do
			if not seen[model] then
				pcall(function()
					st.dust:Destroy()
					st.smoke:Destroy()
					st.fire:Destroy()
					if st.bar then
						st.bar:Destroy()
					end
				end)
				states[model] = nil
			end
		end
	end

	local function stop()
		SoundFx.engine(nil)
		table.clear(states)
	end

	return { step = step, stop = stop }
end

return BattleFx
