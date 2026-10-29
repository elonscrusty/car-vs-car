--!strict
-- The big boom when a car gets smashed, and its 3 s come-back (carter's pick: the Mega Fireball).
-- Numbers live in shared/CarBoom. Looks only, on this screen only: the server decides every smash
-- and marks the smashed car's model with the "Wrecked" attribute until it comes back.
--   CarBoom.boom(model)  - flash, rings, fireball, sparks, chunks, smoke; parts fly off (one wheel
--                          rolls away); the car goes burnt black and burns, with a 3-2-1 over it
--   CarBoom.back(model)  - the old spot poofs; at the new spot a light beam comes down, rings,
--                          stars and a white flash on the car
--   CarBoom.watch()      - plays both on every Car_<id> model by its "Wrecked" attribute
-- It also works in Studio's Edit mode (no player) so a picture can be taken without Play.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Spec = require(Shared:WaitForChild("CarBoom"))
local Match = require(Shared:WaitForChild("Match"))

local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local TRIM = Color3.fromRGB(216, 28, 42)
local TIRE = Color3.fromRGB(16, 16, 18)
local BURNT = Color3.fromRGB(Spec.BURNT[1], Spec.BURNT[2], Spec.BURNT[3])
local HOT = Color3.fromRGB(255, 122, 32)

local CarBoom = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function phone(): boolean
	local me = Players.LocalPlayer
	if me and me:GetAttribute("PhoneUi") == true then
		return true
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local folder: Folder? = nil
local function bits(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "CarBooms"
	nf.Parent = workspace
	folder = nf
	return nf
end

local function part(name: string, color: Color3, neon: boolean, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = bits()
	return p
end

local playing: { [Tween]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local paused = false

-- remove `obj` after `secs` (a paused boom waits)
local function gone(obj: Instance, secs: number)
	task.spawn(function()
		local left = secs
		while left > 0 do
			local dt = task.wait()
			if not paused then
				left -= dt
			end
		end
		obj:Destroy()
	end)
end

local function tween(obj: Instance, secs: number, goal: { [string]: any }, delay: number?)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(secs, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out, 0, false, delay or 0),
		goal
	)
	playing[t] = true
	t:Play()
end

-- one emitter made from a Spec layer, scaled by `u` (Rate 0: burst with :Emit, or set Rate)
local function emitter(layer: Spec.Layer, u: number, tex: string, parent: Instance): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = tex
	e.Rate = 0
	e.Color = ColorSequence.new(rgb(layer.from), rgb(layer.to))
	e.Size = NumberSequence.new(layer.size[1] * u, layer.size[2] * u)
	local see = layer.see or { 0.1, 1 }
	e.Transparency = NumberSequence.new(see[1], see[2])
	e.Speed = NumberRange.new(layer.speed[1] * u, layer.speed[2] * u)
	e.Lifetime = NumberRange.new(layer.life[1], layer.life[2])
	e.LightEmission = layer.glow
	e.LightInfluence = if layer.glow > 0 then 0 else 1
	e.Drag = layer.drag
	e.Acceleration = Vector3.new(0, layer.gravity * u, 0)
	e.SpreadAngle = Vector2.new(layer.spread, layer.spread)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = parent
	return e
end

-- where to put the effect: the model's middle, its floor, and its length
local function measure(model: Model): (CFrame, number, number)
	local cf, size = model:GetBoundingBox()
	local length = math.max(size.X, size.Z)
	return cf, cf.Position.Y - size.Y / 2, length
end

-- ===== flying things (parts and chunks), moved here every frame =====
type Flyer = {
	part: BasePart,
	vel: Vector3,
	spin: Vector3,
	floor: number,
	half: number,
	smoke: ParticleEmitter?,
	till: number,
	gravity: number,
}
local flyers: { Flyer } = {}
local stepping: RBXScriptConnection? = nil

local function step(dt: number)
	if paused then
		for _, f in flyers do
			f.till += dt
		end
		return
	end
	local now = os.clock()
	for i = #flyers, 1, -1 do
		local f = flyers[i]
		if now >= f.till or f.part.Parent == nil then
			if f.part.Parent then
				tween(f.part, 0.3, { Transparency = 1 })
				gone(f.part, 0.35)
			end
			table.remove(flyers, i)
			continue
		end
		local v = f.vel - Vector3.new(0, f.gravity * dt, 0)
		local pos = f.part.Position + v * dt
		if pos.Y < f.floor + f.half and v.Y < 0 then
			pos = Vector3.new(pos.X, f.floor + f.half, pos.Z)
			local x, y, z = Spec.bounce(v.X, v.Y, v.Z)
			v = Vector3.new(x, y, z)
			f.spin *= 0.7
			if f.smoke and y == 0 then
				f.smoke.Rate = 0
			end
		end
		f.vel = v
		f.part.CFrame = CFrame.new(pos)
			* (f.part.CFrame - f.part.Position)
			* CFrame.Angles(f.spin.X * dt, f.spin.Y * dt, f.spin.Z * dt)
	end
	if #flyers == 0 and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

local function fly(f: Flyer)
	table.insert(flyers, f)
	if not stepping then
		stepping = RunService.Heartbeat:Connect(step)
	end
end

-- ===== the wrecks being shown, by model =====
type Wreck = {
	at: CFrame,
	stuff: { Instance }, -- removed at the come-back
	highlight: Highlight,
	heat: PointLight,
	started: number,
	beat: thread?,
}
local wrecks: { [Model]: Wreck } = {}

local function ring(
	at: Vector3,
	r: { color: { number }, size: number, secs: number, delay: number },
	u: number
)
	local cf = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	local p = part("Ring", rgb(r.color), true, Vector3.new(0.05 * u, 0.2 * u, 0.2 * u), cf)
	p.Shape = Enum.PartType.Cylinder
	p.Transparency = 1
	local big = r.size * u
	task.delay(r.delay, function()
		p.Transparency = 0.05
		tween(p, r.secs, { Size = Vector3.new(0.05 * u, big, big), Transparency = 1 })
	end)
	gone(p, r.delay + r.secs + 0.1)
end

local function burst(layer: Spec.Layer, u: number, tex: string, at: CFrame, isPhone: boolean)
	local holder = part("Burst", Color3.new(), false, Vector3.one * 0.1, at)
	holder.Transparency = 1
	local e = emitter(layer, u, tex, holder)
	e:Emit(Spec.count(layer.count, isPhone))
	gone(holder, layer.life[2] + 0.2)
end

-- the 3-2-1 over somebody else's wreck (your own count is SmashFx's big one on screen)
local function countdown(holder: BasePart, u: number): BillboardGui
	local b = Instance.new("BillboardGui")
	b.Name = "Count"
	b.Size = UDim2.fromScale(4 * u, 4 * u)
	b.StudsOffsetWorldSpace = Vector3.new(0, 6 * u, 0)
	b.AlwaysOnTop = true
	b.LightInfluence = 0
	b.MaxDistance = 250
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = ""
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(28, 32, 64)
	s.Thickness = 3
	s.Parent = l
	l.Parent = b
	b.Parent = holder
	local started = os.clock()
	task.spawn(function()
		while b.Parent do
			local n = Spec.countdown(os.clock() - started, Match.RESPAWN)
			if not n then
				b.Enabled = false
				break
			end
			local t = tostring(n)
			if l.Text ~= t then
				l.Text = t
				l.TextColor3 = if n == 1 then Color3.fromRGB(255, 210, 60) else Color3.new(1, 1, 1)
			end
			task.wait(0.05)
		end
	end)
	return b
end

function CarBoom.boom(model: Model, mine: boolean?)
	if wrecks[model] then
		return
	end
	local isPhone = phone()
	local mid, floorY, length = measure(model)
	local u = Spec.unit(length)
	local at = CFrame.new(mid.Position)
	local ground = Vector3.new(mid.Position.X, floorY + 0.02 * u, mid.Position.Z)
	local stuff: { Instance } = {}

	-- 1 flash: a white ball that blows up and fades, and a big light
	local f = Spec.FLASH
	local ball = part("Flash", Color3.new(1, 1, 1), true, Vector3.one * f.size * 0.3 * u, at)
	ball.Shape = Enum.PartType.Ball
	tween(ball, f.secs, { Size = Vector3.one * f.size * u, Transparency = 1, Color = HOT })
	gone(ball, f.secs + 0.05)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 64)
	light.Brightness = f.light
	light.Range = f.range * u
	light.Parent = ball

	-- 2 rings on the ground + a dark scorch (the dark layer)
	for _, r in Spec.RINGS do
		ring(ground, r, u)
	end
	local scorch = part(
		"Scorch",
		Color3.fromRGB(10, 8, 6),
		false,
		Vector3.new(0.04 * u, Spec.SCORCH.size * u * 0.4, Spec.SCORCH.size * u * 0.4),
		CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90))
	)
	scorch.Shape = Enum.PartType.Cylinder
	scorch.Transparency = Spec.SCORCH.see
	local scorchBig = Spec.SCORCH.size * u
	tween(scorch, 0.12, { Size = Vector3.new(0.04 * u, scorchBig, scorchBig) })
	table.insert(stuff, scorch)

	-- 3 fireball + mushroom, 4 sparks, 5 smoke
	burst(Spec.BURST.fire, u, FIRE, at, isPhone)
	burst(Spec.BURST.mushroom, u, FIRE, at, isPhone)
	burst(Spec.BURST.sparks, u, SPARK, at, isPhone)
	burst(Spec.BURST.smoke, u, SMOKE, at * CFrame.new(0, 0.5 * u, 0), isPhone)

	-- glowing chunks
	local rng = Random.new()
	for i = 1, Spec.CHUNKS do
		local glow = i % 3 == 0
		local s = rng:NextNumber(0.6, 1.3) * u
		local c = part(
			"Chunk",
			if glow then HOT elseif i % 2 == 0 then TRIM else BURNT,
			glow,
			Vector3.new(0.4 * s, 0.3 * s, 0.5 * s),
			at
		)
		local dir =
			Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.2, 1), rng:NextNumber(-1, 1)).Unit
		fly({
			part = c,
			vel = (dir * rng:NextNumber(9, 17) + Vector3.new(0, 8, 0)) * u,
			spin = Vector3.new(
				rng:NextNumber(-12, 12),
				rng:NextNumber(-12, 12),
				rng:NextNumber(-12, 12)
			),
			floor = floorY,
			half = 0.15 * s,
			till = os.clock() + 1.6,
			gravity = Spec.GRAVITY * u,
		})
	end

	-- the car's parts fly off (made in its colors); one wheel rolls far away
	local body = model.PrimaryPart
	local paint = if body then body.Color else Color3.fromRGB(21, 22, 28)
	local look = mid.Rotation
	for _, p in Spec.PIECES do
		local size = Vector3.new(p.size[1], p.size[2], p.size[3]) * u
		local cf = CFrame.new(mid.Position)
			* look
			* CFrame.new(p.at[1] * u, p.at[2] * u, -p.at[3] * u)
		local color = if p.paint == "tire" then TIRE elseif p.paint == "trim" then TRIM else paint
		local piece = part(p.name, color, false, size, cf)
		piece.CastShadow = true
		if p.wheel then
			piece.Shape = Enum.PartType.Cylinder
			piece.Size = Vector3.new(size.X, size.Y, size.Y)
		end
		local x, y, z = Spec.fling(p, rng:NextNumber(), rng:NextNumber(), rng:NextNumber())
		local smoke: ParticleEmitter? = nil
		if p.smoke then
			local e = emitter(Spec.WRECK.smoke, u * 0.35, SMOKE, piece)
			e.Rate = 14
			smoke = e
		end
		fly({
			part = piece,
			vel = (look * Vector3.new(x, y, -z)) * u,
			spin = Vector3.new(
				rng:NextNumber(-14, 14),
				rng:NextNumber(-14, 14),
				rng:NextNumber(-14, 14)
			),
			floor = floorY,
			half = size.Y / 2,
			smoke = smoke,
			till = os.clock() + Spec.FLY_SECS,
			gravity = Spec.GRAVITY * u,
		})
	end

	-- the wreck: burnt black, burning, a flickering light, the 3-2-1
	local hl = Instance.new("Highlight")
	hl.Name = "Burnt"
	hl.Adornee = model
	hl.FillColor = BURNT
	hl.FillTransparency = 1
	hl.OutlineTransparency = 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = bits()
	tween(hl, Spec.BURN_IN, { FillTransparency = 0.12 })
	table.insert(stuff, hl)

	local top = part(
		"Fire",
		Color3.new(),
		false,
		Vector3.new(1.4 * u, 0.1, 2.4 * u),
		at * CFrame.new(0, 0.3 * u, 0)
	)
	top.Transparency = 1
	for name, layer in Spec.WRECK do
		local e = emitter(
			layer,
			u,
			if name == "smoke" then SMOKE elseif name == "embers" then SPARK else FIRE,
			top
		)
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Rate = Spec.count(layer.count, isPhone)
	end
	local heat = Instance.new("PointLight")
	heat.Color = HOT
	heat.Range = Spec.HEAT.range * u
	heat.Brightness = Spec.HEAT.light
	heat.Parent = top
	table.insert(stuff, top)
	if not mine then
		countdown(top, u)
	end

	local w: Wreck = { at = at, stuff = stuff, highlight = hl, heat = heat, started = os.clock() }
	wrecks[model] = w
	w.beat = task.spawn(function()
		while wrecks[model] == w do
			heat.Brightness = Spec.HEAT.light + rng:NextNumber(-0.5, 1) * Spec.HEAT.flicker
			task.wait(0.06)
		end
	end)
	-- never leave a wreck burning (a model that went away, a lost attribute)
	task.delay(Match.RESPAWN + 3, function()
		if wrecks[model] == w then
			CarBoom.back(model, true)
		end
	end)
end

-- The come-back. `quiet` = just clean up (no beam), e.g. the car left the game.
function CarBoom.back(model: Model, quiet: boolean?)
	local w = wrecks[model]
	if not w then
		return
	end
	wrecks[model] = nil
	local isPhone = phone()
	local _, _, length = measure(model)
	local u = Spec.unit(length)
	if not quiet then
		burst(Spec.BURST.poof, u, SMOKE, w.at, isPhone)
	end
	for _, s in w.stuff do
		if s:IsA("BasePart") then
			for _, e in s:GetDescendants() do
				if e:IsA("ParticleEmitter") then
					e.Rate = 0
				elseif e:IsA("PointLight") then
					e.Enabled = false
				elseif e:IsA("BillboardGui") then
					e.Enabled = false
				end
			end
			tween(s, 0.4, { Transparency = 1 })
			gone(s, 2.5)
		elseif s:IsA("Highlight") then
			s:Destroy()
		end
	end
	if quiet or model.Parent == nil then
		return
	end
	-- wait for the car to land on its new spot (the server or its driver moves it)
	local from = w.at.Position
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < Spec.FIND_BACK and model.Parent do
			if (model:GetPivot().Position - from).Magnitude > length then
				break
			end
			task.wait()
		end
		if model.Parent == nil or wrecks[model] then
			return
		end
		task.wait(0.05)
		local mid, floorY = measure(model)
		local ground = Vector3.new(mid.Position.X, floorY + 0.02 * u, mid.Position.Z)
		local b = Spec.BEAM
		local h = b.height * u
		local up = CFrame.new(ground + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		local beam = part(
			"Beam",
			Color3.fromRGB(111, 212, 255),
			true,
			Vector3.new(h, b.width * u, b.width * u),
			up
		)
		beam.Shape = Enum.PartType.Cylinder
		beam.Transparency = 0.3
		local core =
			part("BeamCore", Color3.new(1, 1, 1), true, Vector3.new(h, b.core * u, b.core * u), up)
		core.Shape = Enum.PartType.Cylinder
		tween(beam, b.secs, { Size = Vector3.new(h, 0.05 * u, 0.05 * u), Transparency = 1 })
		tween(core, b.secs, { Size = Vector3.new(h, 0.02 * u, 0.02 * u), Transparency = 1 })
		gone(beam, b.secs + 0.05)
		gone(core, b.secs + 0.05)
		for _, r in Spec.BACK_RINGS do
			ring(ground, r, u)
		end
		burst(Spec.BURST.stars, u, SPARK, CFrame.new(ground), isPhone)
		-- the car shines white, then fades to its own colors
		local hl = Instance.new("Highlight")
		hl.Name = "Back"
		hl.Adornee = model
		hl.FillColor = Color3.new(1, 1, 1)
		hl.FillTransparency = 0
		hl.OutlineColor = Color3.fromRGB(111, 212, 255)
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = bits()
		tween(hl, Spec.BACK_FLASH, { FillTransparency = 1, OutlineTransparency = 1 })
		gone(hl, Spec.BACK_FLASH + 0.05)
	end)
end

-- Studio pictures only: freeze every boom on screen (true) or let it go on (false).
function CarBoom.pause(on: boolean)
	paused = on
	for t in playing do
		if on and t.PlaybackState == Enum.PlaybackState.Playing then
			t:Pause()
		elseif not on and t.PlaybackState == Enum.PlaybackState.Paused then
			t:Play()
		end
	end
	for _, d in bits():GetDescendants() do
		if d:IsA("ParticleEmitter") then
			d.TimeScale = if on then 0 else 1
		end
	end
end

-- ===== watch every car =====
local watching = false
function CarBoom.watch()
	if watching then
		return
	end
	watching = true
	local me = Players.LocalPlayer
	local function hook(m: Instance)
		if not (m:IsA("Model") and string.match(m.Name, "^Car_%-?%d+$")) then
			return
		end
		local model = m :: Model
		local function changed()
			if model:GetAttribute("Wrecked") == true then
				local mine = me ~= nil and model.Name == "Car_" .. me.UserId
				CarBoom.boom(model, mine)
			else
				CarBoom.back(model)
			end
		end
		model:GetAttributeChangedSignal("Wrecked"):Connect(changed)
		model.AncestryChanged:Connect(function()
			if model.Parent == nil then
				CarBoom.back(model, true)
			end
		end)
		if model:GetAttribute("Wrecked") == true then
			changed()
		end
	end
	for _, m in workspace:GetChildren() do
		hook(m)
	end
	workspace.ChildAdded:Connect(hook)
	-- (kart models placed deeper than workspace are tagged)
	for _, m in CollectionService:GetTagged("Kart") do
		if m.Parent ~= workspace then
			hook(m)
		end
	end
end

return CarBoom
