--!strict
-- Car effects for the 1v1 fight that follow the cars every frame: tire smoke and skid marks while
-- drifting, a flame while boosting, a dust burst on landing, speed lines and an engine sound for
-- YOUR car. The server only sets attributes on each car model ("Drifting", "Airborne", "Boosting");
-- everything here is local to this player's screen.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Effects = require(script.Parent.Effects)
local SoundFx = require(script.Parent.SoundFx)

export type Options = {
	shake: (amp: number) -> (), -- add camera shake (studs)
	cruise: number, -- a typical cruise speed in studs per second (for speed lines / engine pitch)
}

export type Fx = {
	step: (dt: number, models: { Model }, mine: Model?) -> (),
	stop: () -> (),
}

type CarFx = {
	smoke: ParticleEmitter,
	flame: ParticleEmitter,
	dust: ParticleEmitter,
	airborne: boolean,
	drifting: boolean,
	lastMark: Vector3?,
}

local BattleFx = {}

local MAX_MARKS = 90
local MARK_GAP = 2.4 -- studs travelled between skid mark pieces

local function emitter(parent: Instance, name: string): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.Enabled = false
	e.Parent = parent
	return e
end

local function build(body: BasePart): CarFx
	local rear = Instance.new("Attachment")
	rear.Name = "FxRear"
	rear.CFrame = CFrame.new(0, -0.25 * body.Size.Y - 0.5, math.max(body.Size.Z * 0.42, 3))
	rear.Parent = body

	local smoke = emitter(rear, "DriftSmoke")
	smoke.Rate = 60
	smoke.Lifetime = NumberRange.new(0.5, 0.9)
	smoke.Speed = NumberRange.new(3, 8)
	smoke.SpreadAngle = Vector2.new(35, 35)
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.4),
		NumberSequenceKeypoint.new(1, 5),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Color = ColorSequence.new(Color3.fromRGB(235, 235, 240))

	local flame = emitter(rear, "BoostFlame")
	flame.Rate = 120
	flame.Lifetime = NumberRange.new(0.15, 0.3)
	flame.Speed = NumberRange.new(14, 26)
	flame.EmissionDirection = Enum.NormalId.Back
	flame.SpreadAngle = Vector2.new(10, 10)
	flame.LightEmission = 1
	flame.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	flame.Color = ColorSequence.new(Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 140, 40))

	local dust = emitter(rear, "LandDust")
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

	return {
		smoke = smoke,
		flame = flame,
		dust = dust,
		airborne = false,
		drifting = false,
		lastMark = nil,
	}
end

function BattleFx.new(opts: Options): Fx
	local states: { [Model]: CarFx } = {}
	local marks: { Part } = {}
	local linesT = 0

	local function addMark(at: Vector3, dir: Vector3, side: number, body: BasePart)
		local p = Instance.new("Part")
		p.Name = "SkidMark"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromRGB(25, 25, 30)
		p.Transparency = 0.3
		p.Size = Vector3.new(0.9, 0.05, MARK_GAP * 1.3)
		local right = dir:Cross(Vector3.yAxis)
		local pos = at + right * side * body.Size.X * 0.32 + Vector3.new(0, 0.06, 0)
		p.CFrame = CFrame.lookAt(pos, pos + dir)
		p.Parent = workspace
		table.insert(marks, p)
		if #marks > MAX_MARKS then
			local old = table.remove(marks, 1)
			if old then
				old:Destroy()
			end
		end
		TweenService:Create(p, TweenInfo.new(3, Enum.EasingStyle.Linear), { Transparency = 1 })
			:Play()
		Debris:AddItem(p, 3.1)
	end

	local function step(dt: number, models: { Model }, mine: Model?)
		linesT = math.max(0, linesT - dt)
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
			local drifting = model:GetAttribute("Drifting") == true and not airborne
			local boosting = model:GetAttribute("Boosting") == true
			st.smoke.Enabled = drifting
			st.flame.Enabled = boosting

			-- landing: dust burst and a thump
			if st.airborne and not airborne then
				st.dust:Emit(18)
				if isMine then
					opts.shake(2.4)
					SoundFx.play("land")
				end
			end
			st.airborne = airborne

			-- drift start: a screech once
			if isMine and drifting and not st.drifting then
				SoundFx.play("skid")
			end
			st.drifting = drifting

			-- skid marks behind the rear wheels
			if drifting then
				local b = body :: BasePart
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { model }
				local hit =
					workspace:Raycast(b.Position, Vector3.new(0, -body.Size.Y * 3, 0), params)
				if hit then
					local last = st.lastMark
					local v = b.AssemblyLinearVelocity
					local dir = Vector3.new(v.X, 0, v.Z)
					if
						dir.Magnitude > 1
						and (last == nil or (hit.Position - last).Magnitude >= MARK_GAP)
					then
						dir = dir.Unit
						local back = hit.Position - dir * (b.Size.Z * 0.3)
						addMark(back, dir, -1, b)
						addMark(back, dir, 1, b)
						st.lastMark = hit.Position
					end
				end
				if isMine then
					opts.shake(0.35) -- a little rumble while sliding
				end
			else
				st.lastMark = nil
			end

			if isMine then
				local b = body :: BasePart
				local speed = b.AssemblyLinearVelocity.Magnitude
				SoundFx.engine(speed / math.max(opts.cruise, 1))
				if boosting then
					opts.shake(0.5)
				end
				-- speed lines when going fast or boosting
				if (boosting or speed > 0.9 * opts.cruise) and linesT <= 0 then
					linesT = if boosting then 0.35 else 0.8
					Effects.speedLines(0.5)
				end
			end
		end
		-- forget cars that are gone
		for model, st in states do
			if not seen[model] then
				pcall(function()
					st.smoke:Destroy()
					st.flame:Destroy()
					st.dust:Destroy()
				end)
				states[model] = nil
			end
		end
	end

	local function stop()
		SoundFx.engine(nil)
		for _, m in marks do
			m:Destroy()
		end
		table.clear(marks)
		table.clear(states)
	end

	return { step = step, stop = stop }
end

return BattleFx
