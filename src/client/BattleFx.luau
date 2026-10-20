--!strict
-- Car effects for the 1v1 fight that follow the cars every frame: a dust burst and a thump when a
-- car lands from a jump, and the engine sound of YOUR car. (carter removed the boost flame, drift
-- smoke, skid marks and speed lines.) The server only sets the "Airborne" attribute on each car
-- model; everything here is local to this player's screen.

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
	smoke.Lifetime = NumberRange.new(1.2, 2)
	smoke.Speed = NumberRange.new(8, 14)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.SpreadAngle = Vector2.new(25, 25)
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3),
		NumberSequenceKeypoint.new(1, 10),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Color = ColorSequence.new(Color3.fromRGB(150, 150, 150))
	smoke.Parent = hood
	return { dust = dust, smoke = smoke, airborne = false }
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
			local hurt = math.clamp((0.6 - f) / 0.6, 0, 1)
			st.smoke.Rate = if hurt > 0 then 12 + hurt * 48 else 0
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
