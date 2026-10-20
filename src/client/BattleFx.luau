--!strict
-- Car effects for the 1v1 fight that follow the cars every frame: a thump when a car lands from a
-- jump, the engine sound of YOUR car, damage smoke and flames, the enemy's HP bar, sparks where a
-- car scrapes the bowl's tire wall or the crusher, and skid marks that fade after a few seconds when
-- a car slides sideways (carter, Junkyard Bowl: sparks M42, skid marks M43, no dust clouds M44). The
-- server only sets the "Airborne" attribute (and, for a car it drives, "Drifting") on each car model;
-- everything here is local to this player's screen.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BowlView = require(ReplicatedStorage.Shared.BowlView)
local Quality = require(script.Parent.Quality)
local SoundFx = require(script.Parent.SoundFx)

export type Options = {
	shake: (amp: number) -> (), -- add camera shake (studs)
	cruise: number, -- a typical cruise speed in studs per second (for the engine pitch)
}

-- Set on the round bowl only: where its middle is (sparks need it; the box arenas have no scraping).
export type ArenaInfo = { center: Vector3 }

export type Fx = {
	step: (dt: number, models: { Model }, mine: Model?, arena: ArenaInfo?) -> (),
	stop: () -> (),
}

type CarFx = {
	sparkPart: Part, -- an invisible part that sits where the car scrapes, holding the sparks
	sparks: ParticleEmitter,
	scraping: boolean,
	skidAt: number, -- when this car last left a skid mark
	lastLeft: Vector3?, -- where each rear wheel's mark ended (nil = the car was not skidding)
	lastRight: Vector3?,
	smoke: ParticleEmitter,
	fire: ParticleEmitter,
	bar: BillboardGui?, -- the enemy's HP bar above its car
	fill: Frame?,
	lastFrac: number,
	airborne: boolean,
}

local BattleFx = {}

local function build(body: BasePart): CarFx
	-- sparks fly from where the car scrapes a wall: a hidden part that follows the contact point
	local sparkPart = Instance.new("Part")
	sparkPart.Name = "WallSparks"
	sparkPart.Anchored = true
	sparkPart.CanCollide = false
	sparkPart.CanQuery = false
	sparkPart.CanTouch = false
	sparkPart.CastShadow = false
	sparkPart.Transparency = 1
	sparkPart.Size = Vector3.new(0.4, 0.4, 0.4)
	sparkPart.CFrame = body.CFrame
	sparkPart.Parent = workspace
	local sparkAtt = Instance.new("Attachment")
	sparkAtt.Parent = sparkPart
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Rate = 0
	sparks.EmissionDirection = Enum.NormalId.Front -- along the attachment's look: away from the wall
	sparks.Lifetime = NumberRange.new(0.25, 0.5)
	sparks.Speed = NumberRange.new(14, 32)
	sparks.SpreadAngle = Vector2.new(32, 32)
	sparks.Acceleration = Vector3.new(0, -70, 0)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 240, 170), Color3.fromRGB(255, 120, 30))
	sparks.Parent = sparkAtt

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
		sparkPart = sparkPart,
		sparks = sparks,
		scraping = false,
		skidAt = 0,
		lastLeft = nil,
		lastRight = nil,
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

-- Skid marks: dark strips left on the ground by the rear wheels while a car slides sideways. A
-- fixed pool is reused (the oldest strip is taken first); each one fades out after a few seconds.
local MAX_MARKS = 90
local MARK_LIFE = 4 -- seconds until a strip is gone
local MARK_SOLID = 1.5 -- ... and it starts fading after this long
local MARK_EVERY = 0.07 -- seconds between strips while skidding

type Marks = { pool: { Part }, born: { [Part]: number }, next: number, folder: Folder? }

local function newMarks(): Marks
	return { pool = {}, born = {}, next = 1, folder = nil }
end

local function putMark(marks: Marks, from: Vector3, to: Vector3, normal: Vector3, now: number)
	local along = to - from
	local len = along.Magnitude
	if len < 0.2 or len > 9 then
		return -- a gap (the car was in the air, or the first point): no strip
	end
	if marks.folder == nil then
		local f = Instance.new("Folder")
		f.Name = "SkidMarks"
		f.Parent = workspace
		marks.folder = f
	end
	local old: Part? = marks.pool[marks.next]
	local p: Part
	if old then
		p = old
	else
		p = Instance.new("Part")
		p.Name = "SkidMark"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromRGB(34, 34, 38)
		p.Parent = marks.folder
		marks.pool[marks.next] = p
	end
	marks.next = marks.next % MAX_MARKS + 1
	local mid = (from + to) / 2 + normal * 0.05
	p.Size = Vector3.new(0.9, 0.05, len + 0.4)
	p.CFrame = CFrame.lookAt(mid, mid + along, normal)
	p.Transparency = 0.2
	marks.born[p] = now
end

local function fadeMarks(marks: Marks, now: number)
	for p, born in marks.born do
		local age = now - born
		if age >= MARK_LIFE then
			p.Transparency = 1
			marks.born[p] = nil
		else
			p.Transparency = 0.2
				+ 0.8 * math.clamp((age - MARK_SOLID) / (MARK_LIFE - MARK_SOLID), 0, 1)
		end
	end
end

-- A flat copy of a vector's direction (zero if it points straight up or down).
local function flatUnit(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then
		return nil
	end
	return f.Unit
end

function BattleFx.new(opts: Options): Fx
	local states: { [Model]: CarFx } = {}
	local marks = newMarks()
	local fadeAt = 0
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude

	-- sparks where the car scrapes the tire wall or the crusher (round bowl only)
	local function scrape(st: CarFx, body: BasePart, arena: ArenaInfo)
		local fwd = flatUnit(body.CFrame.LookVector)
		local rel = body.Position - arena.center
		local vel = body.AssemblyLinearVelocity
		local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local hit = if fwd
			then BowlView.scrape(
				rel.X,
				rel.Z,
				fwd.X,
				fwd.Z,
				speed,
				body.Size.Z / 2,
				body.Size.X / 2
			)
			else nil
		if hit == nil then
			st.sparks.Rate = 0
			st.scraping = false
			return
		end
		local at = Vector3.new(
			arena.center.X + hit.x,
			body.Position.Y - body.Size.Y * 0.15,
			arena.center.Z + hit.z
		)
		st.sparkPart.CFrame = CFrame.lookAt(at, at + Vector3.new(hit.nx, 0.35, hit.nz))
		st.sparks.Rate = if Quality.level() >= 2 then 30 else 70
		if not st.scraping then
			st.sparks:Emit(12) -- a burst the moment it touches
		end
		st.scraping = true
	end

	-- skid marks behind the rear wheels while the car slides sideways
	local function skid(st: CarFx, model: Model, body: BasePart, now: number)
		local fwd = flatUnit(body.CFrame.LookVector)
		local vel = body.AssemblyLinearVelocity
		local amount = 0
		if fwd and model:GetAttribute("Airborne") ~= true then
			local drifting = model:GetAttribute("Drifting") == true
			amount = BowlView.skid(vel.X, vel.Z, fwd.X, fwd.Z, opts.cruise, drifting)
		end
		if amount < 0.15 or Quality.level() >= 2 then
			st.lastLeft, st.lastRight = nil, nil
			return
		end
		if now - st.skidAt < MARK_EVERY then
			return
		end
		st.skidAt = now
		groundParams.FilterDescendantsInstances = if marks.folder
			then { model, marks.folder }
			else { model }
		local ray = workspace:Raycast(
			body.Position,
			Vector3.new(0, -(body.Size.Y * 0.5 + 6), 0),
			groundParams
		)
		if ray == nil then
			st.lastLeft, st.lastRight = nil, nil
			return
		end
		local right = body.CFrame.RightVector
		local back = -body.CFrame.LookVector
		local n = ray.Normal
		-- each rear wheel's spot on the ground plane under the car
		local function wheel(side: number): Vector3
			local off = right * (side * 0.36 * body.Size.X) + back * (0.3 * body.Size.Z)
			local rise = -(n.X * off.X + n.Z * off.Z) / math.max(n.Y, 0.2)
			return ray.Position + Vector3.new(off.X, rise, off.Z)
		end
		local left, rightW = wheel(-1), wheel(1)
		if st.lastLeft then
			putMark(marks, st.lastLeft, left, n, now)
		end
		if st.lastRight then
			putMark(marks, st.lastRight, rightW, n, now)
		end
		st.lastLeft, st.lastRight = left, rightW
	end

	local function step(_dt: number, models: { Model }, mine: Model?, arena: ArenaInfo?)
		local seen: { [Model]: boolean } = {}
		local now = os.clock()
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
			-- landing: a thump (no dust cloud)
			if st.airborne and not airborne then
				if isMine then
					opts.shake(2.4)
					SoundFx.play("land")
				end
			end
			st.airborne = airborne
			if arena then
				scrape(st, body :: BasePart, arena)
			end
			skid(st, model, body :: BasePart, now)
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
		-- the marks fade a few times a second, not every frame
		if now - fadeAt > 0.12 then
			fadeAt = now
			fadeMarks(marks, now)
		end
		-- forget cars that are gone
		for model, st in states do
			if not seen[model] then
				pcall(function()
					st.sparkPart:Destroy()
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
		for _, st in states do
			pcall(function()
				st.sparkPart:Destroy()
			end)
		end
		table.clear(states)
		-- the marks go with the fight
		if marks.folder then
			marks.folder:Destroy()
		end
		marks = newMarks()
	end

	return { step = step, stop = stop }
end

return BattleFx
