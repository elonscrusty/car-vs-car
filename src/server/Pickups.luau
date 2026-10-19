--!strict
-- Spawns floating power-ups on the arena floor during a fight and gives them to the car that
-- drives into them. Rules and numbers: PickupLogic, PickupsConfig. Effects: Buffs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BowlConfig = require(ReplicatedStorage.Shared.BowlConfig)
local PickupLogic = require(ReplicatedStorage.Shared.PickupLogic)
local PickupsConfig = require(ReplicatedStorage.Shared.PickupsConfig)
local PickupStyle = require(ReplicatedStorage.Shared.PickupStyle)
local Types = require(ReplicatedStorage.Shared.Types)

local Arena = require(script.Parent.Arena)
local Buffs = require(script.Parent.Buffs)
local CarBuilder = require(script.Parent.CarBuilder)
local Impulse = require(script.Parent.Impulse)
local LobbyDecor = require(script.Parent.LobbyDecor)

export type Handle = { destroy: () -> () }

type IconItem = { part: BasePart, offset: CFrame }
type Pickup = {
	kind: string,
	model: Model,
	items: { IconItem },
	base: Vector3, -- resting spot of the icon center
	x: number,
	z: number,
	born: number, -- elapsed time when it spawned (for the bob phase)
	tweens: { Tween },
}

local Pickups = {}

-- Blender icons (ServerStorage.Models.Bowl); a missing one keeps the plain glowing shapes.
local ICON_MODELS: { [string]: string } = {
	shield = "Pickup_Shield",
	bighit = "Pickup_BigHit",
	speed = "Pickup_Speed",
	magnet = "Pickup_Magnet",
	rocket = "Pickup_Rocket",
}
local ICON_SCALE = 1.6

local function colorOf(kind: string): Color3
	local c = (PickupsConfig.colors :: any)[kind] or { 255, 255, 255 }
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- One floating, glowing icon with a name pill, a glow disc and a blob shadow on the floor.
-- Parts are anchored, so animate() moves them every frame.
local function makePickup(
	kind: string,
	pos: Vector3,
	floorSurfaceY: number,
	parent: Instance
): Pickup
	local color = colorOf(kind)
	local rgb = (PickupsConfig.colors :: any)[kind] or { 255, 255, 255 }
	local model = Instance.new("Model")
	model.Name = "Pickup_" .. kind

	local function look(part: Part, material: Enum.Material, c: Color3)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = material
		part.Color = c
	end

	local items: { IconItem } = {}
	local iconName = ICON_MODELS[kind]
	local icon = if iconName and LobbyDecor.has(iconName, "Bowl")
		then LobbyDecor.clone(iconName, model, nil, "Bowl")
		else nil
	if icon then
		icon:ScaleTo(icon:GetScale() * ICON_SCALE)
		local pivot = icon:GetPivot()
		local _, size = icon:GetBoundingBox()
		for _, d in icon:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(items, {
					part = d,
					offset = pivot:ToObjectSpace(d.CFrame) - Vector3.new(0, size.Y / 2, 0),
				})
			end
		end
	end
	if #items == 0 then
		for _, ps in PickupStyle.iconParts(kind, rgb) do
			local part = Instance.new("Part")
			part.Name = "Icon"
			part.Shape = (Enum.PartType :: any)[ps.shape]
			part.Size = Vector3.new(ps.size[1], ps.size[2], ps.size[3])
			look(part, Enum.Material.Neon, Color3.fromRGB(ps.color[1], ps.color[2], ps.color[3]))
			part.Parent = model
			table.insert(items, {
				part = part,
				offset = CFrame.new(ps.offset[1], ps.offset[2], ps.offset[3])
					* CFrame.Angles(0, math.rad(ps.yaw), 0),
			})
		end
	end
	local first = items[1].part

	-- Dark blob shadow and a soft colored glow on the floor (flat discs, axis pointing up).
	local flat = CFrame.new(pos.X, floorSurfaceY, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	local shadow = Instance.new("Part")
	shadow.Name = "Shadow"
	shadow.Shape = Enum.PartType.Cylinder
	shadow.Size = Vector3.new(0.1, 4, 4)
	look(shadow, Enum.Material.SmoothPlastic, Color3.new(0, 0, 0))
	shadow.Transparency = 0.6
	shadow.CFrame = flat + Vector3.new(0, 0.1, 0)
	shadow.Parent = model
	local glow = Instance.new("Part")
	glow.Name = "Glow"
	glow.Shape = Enum.PartType.Cylinder
	glow.Size = Vector3.new(0.1, 7, 7)
	look(glow, Enum.Material.Neon, color)
	glow.Transparency = 0.6
	glow.CFrame = flat + Vector3.new(0, 0.2, 0)
	glow.Parent = model
	local base = LobbyDecor.clone("PickupBase", model, nil, "Bowl")
	if base then
		base:PivotTo(CFrame.new(pos.X, floorSurfaceY + 0.1, pos.Z))
	end

	-- Name pill under the icon.
	local label = (PickupsConfig.names :: any)[kind] or kind
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromScale(PickupStyle.pillWidth(label), 1.1)
	sign.StudsOffset = Vector3.new(0, -3, 0)
	sign.AlwaysOnTop = true
	sign.Adornee = first
	sign.Parent = first
	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = Color3.fromRGB(18, 20, 32)
	pill.BackgroundTransparency = 0.15
	pill.Parent = sign
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = pill
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = pill
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(0.86, 0.7)
	text.Position = UDim2.fromScale(0.07, 0.15)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = label
	text.TextColor3 = color
	text.Parent = pill

	-- A few sparkles.
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(color)
	sparkles.LightEmission = 1
	sparkles.Rate = 6
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Speed = NumberRange.new(1, 2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Parent = first

	model.Parent = parent
	local pulse = TweenService:Create(
		glow,
		TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.8 }
	)
	pulse:Play()
	return {
		kind = kind,
		model = model,
		items = items,
		base = pos,
		x = 0,
		z = 0,
		born = 0,
		tweens = { pulse },
	}
end

-- Bob and spin the icon parts.
local function animate(pk: Pickup, t: number)
	local frame = CFrame.new(pk.base + Vector3.new(0, PickupStyle.bobOffset(t), 0))
		* CFrame.Angles(0, math.rad(PickupStyle.spinDeg(t)), 0)
	for _, item in pk.items do
		item.part.CFrame = frame * item.offset
	end
end

-- notify(car, update) sends a UiUpdate to that car's player (nil for bots / no listener).
function Pickups.start(
	arena: Arena.Arena,
	cars: { CarBuilder.Car },
	rng: Random,
	notify: ((car: CarBuilder.Car, update: Types.UiUpdate) -> ())?,
	onCollect: ((car: CarBuilder.Car, kind: string) -> ())?, -- repair etc. are decided by the mode
	override: { [string]: any }? -- other kinds / ring / timing for a mode (the car fight: only SHIELD)
): Handle
	local cfg: any = PickupsConfig
	if override then
		cfg = table.clone(PickupsConfig)
		for k, v in override do
			cfg[k] = v
		end
	end
	local center = arena.center
	local floorY = center.Y + cfg.hoverHeight
	local pickups: { Pickup } = {}
	local elapsed = 0
	local sinceAnimate = 0
	local lastSpawnAt: number? = nil
	local destroyed = false

	local function listenerFor(car: CarBuilder.Car): (string, number) -> ()
		return function(kind: string, seconds: number)
			if notify then
				notify(car, { kind = "buff", buff = kind, seconds = seconds })
			end
		end
	end
	for _, car in cars do
		Buffs.setListener(car, listenerFor(car))
	end

	local function spawn()
		local avoid: { PickupLogic.Point } = {}
		for _, car in cars do
			local p = car.body.Position
			table.insert(avoid, { x = p.X - center.X, z = p.Z - center.Z })
		end
		local taken: { PickupLogic.Point } = {}
		for _, pk in pickups do
			table.insert(taken, { x = pk.x, z = pk.z })
		end
		local rolls: { { number } } = {}
		for _ = 1, 8 do
			table.insert(rolls, { rng:NextNumber(), rng:NextNumber() })
		end
		local spot = PickupLogic.pickSpot(
			rolls,
			cfg.ringMin,
			cfg.ringMax,
			avoid,
			cfg.minCarDistance,
			taken,
			cfg.minPickupDistance
		)
		lastSpawnAt = elapsed -- even when no spot was free: try again after the usual wait
		if spot == nil then
			return
		end
		local kind = cfg.kinds[rng:NextInteger(1, #cfg.kinds)]
		local pk = makePickup(
			kind,
			Vector3.new(center.X + spot.x, floorY, center.Z + spot.z),
			center.Y,
			arena.model
		)
		pk.x = spot.x
		pk.z = spot.z
		pk.born = elapsed
		table.insert(pickups, pk)
	end

	-- A slick puddle behind the car: low friction, so cars that drive over it slide.
	local function dropOil(car: CarBuilder.Car)
		local look = car.body.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		local dir = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, 1)
		local at = car.body.Position - dir * cfg.oil.dropBehind
		local size = cfg.oil.puddleSize
		local puddle = Instance.new("Part")
		puddle.Name = "OilPuddle"
		puddle.Shape = Enum.PartType.Cylinder
		puddle.Size = Vector3.new(0.2, size, size)
		puddle.CFrame = CFrame.new(at.X, center.Y + 0.1, at.Z) * CFrame.Angles(0, 0, math.pi / 2)
		puddle.Color = Color3.fromRGB(40, 28, 70)
		puddle.Material = Enum.Material.Glass
		puddle.Reflectance = 0.35
		puddle.Anchored = true
		puddle.CanQuery = false
		puddle.CanTouch = false
		puddle.CastShadow = false
		puddle.CustomPhysicalProperties = PhysicalProperties.new(1, 0.01, 0, 100, 1)
		puddle.Parent = arena.model
		Debris:AddItem(puddle, cfg.oil.puddleSeconds)
	end

	local function remove(index: number)
		local pk = pickups[index]
		for _, t in pk.tweens do
			t:Cancel()
		end
		pk.model:Destroy()
		table.remove(pickups, index)
	end

	local conn = RunService.Heartbeat:Connect(function(dt)
		if destroyed then
			return
		end
		elapsed += dt
		if
			PickupLogic.shouldSpawn(
				elapsed,
				lastSpawnAt,
				#pickups,
				cfg.firstSpawnSeconds,
				cfg.spawnEverySeconds,
				cfg.maxOnFloor
			)
		then
			spawn()
		end
		-- Bob and spin at 20 updates a second: smooth enough, and far less network traffic.
		sinceAnimate += dt
		local doAnimate = sinceAnimate >= 0.05
		if doAnimate then
			sinceAnimate = 0
		end
		for i = #pickups, 1, -1 do
			local pk = pickups[i]
			if doAnimate then
				animate(pk, elapsed - pk.born)
			end
			for _, car in cars do
				if not car.dead then
					local p = car.body.Position
					if
						PickupLogic.touches(
							p.X - center.X,
							p.Z - center.Z,
							pk.x,
							pk.z,
							cfg.pickupRadius
						)
					then
						Buffs.apply(car, pk.kind)
						if pk.kind == "oil" then
							dropOil(car)
						end
						if onCollect then
							onCollect(car, pk.kind)
						end
						if pk.kind == "rocket" then
							-- Dash straight at the other car.
							for _, other in cars do
								if other ~= car and not other.dead then
									local d = other.body.Position - car.body.Position
									local flat = Vector3.new(d.X, 0, d.Z)
									if flat.Magnitude > 0.5 then
										Impulse.linear(
											car.body,
											flat.Unit
												* BowlConfig.Rocket.speed
												* car.body.AssemblyMass
										)
									end
								end
							end
						end
						remove(i)
						break
					end
				end
			end
		end
	end)

	return {
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			conn:Disconnect()
			while #pickups > 0 do
				remove(#pickups)
			end
			for _, car in cars do
				Buffs.setListener(car, nil)
			end
		end,
	}
end

return Pickups
