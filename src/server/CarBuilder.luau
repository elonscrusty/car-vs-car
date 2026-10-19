--!strict
-- Builds one placeholder car: a heavy box body plus massless welded decoration parts.
-- The car faces -Z (its LookVector). Only the Body has weight; everything else is Massless.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Ai = require(ReplicatedStorage.Shared.Ai)
local Abilities = require(ReplicatedStorage.Shared.Abilities)
local Build = require(ReplicatedStorage.Shared.Build)
local CarCatalog = require(ReplicatedStorage.Shared.CarCatalog)
local CarConfig = require(ReplicatedStorage.Shared.CarConfig)
local CarLook = require(ReplicatedStorage.Shared.CarLook)
local Fairness = require(ReplicatedStorage.Shared.Fairness)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local Progress = require(ReplicatedStorage.Shared.Progress)
local Appearance = require(script.Parent.Appearance)
local Badge = require(script.Parent.Badge)
local HpBar = require(script.Parent.HpBar)

export type Car = {
	idx: number, -- 1 or 2 (2 is the bot when only one player)
	id: string,
	stats: CarConfig.CarStats,
	model: Model,
	body: Part,
	hp: number,
	dead: boolean,
	ai: Ai.Memory,
	flipTimer: number,
	prevVel: Vector3, -- velocity from the end of last frame (used to measure impact)
	bar: HpBar.Bar,
	smoking: boolean,
}

local CarBuilder = {}

-- A real car model, when one was imported in Studio: ServerStorage.Models.Car_<id> (a MeshPart whose
-- length runs along its X axis, nose toward +X). Cars without one keep the box placeholders.
local function findCarMesh(id: string): MeshPart?
	local models = ServerStorage:FindFirstChild("Models")
	local mesh = models and models:FindFirstChild("Car_" .. id)
	if mesh and mesh:IsA("MeshPart") then
		return mesh
	end
	return nil
end

-- A catalog car's imported model: ServerStorage.Models.Cars.<catalog model name> (e.g. "02_sedan"),
-- a Model of MeshParts (Body + Wheel_*), origin bottom-centre, nose toward -Z, about 14 studs
-- long for a sedan. nil when it was not imported: the car keeps the box placeholders.
local function findCatalogModel(name: string?): Model?
	local models = ServerStorage:FindFirstChild("Models")
	local cars = models and models:FindFirstChild("Cars")
	local m = if cars and name then cars:FindFirstChild(name) else nil
	if m and m:IsA("Model") then
		return m
	end
	return nil
end

-- Adds a welded, massless part at `offset` from the body.
local function addPart(
	car: Model,
	body: Part,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	collide: boolean
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true
	p.CanCollide = collide
	p.Anchored = true -- stays anchored until launch
	p.CFrame = body.CFrame * offset
	p:SetAttribute("CarIdx", body:GetAttribute("CarIdx"))
	p.Parent = car
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = p
	weld.Parent = p
	return p
end

-- Build-and-watch parts: plain gray placeholder shapes, welded and massless (no weight, no
-- collisions), so the physics only sees the stats. Wheels, engine and armor each look different.
local PART_GRAY = Color3.fromRGB(150, 155, 168)
local PART_DARK = Color3.fromRGB(70, 72, 82)

local function attachBuild(model: Model, body: Part, size: Vector3, build: Build.BuildData)
	local sx, sy, sz = size.X, size.Y, size.Z
	local function gray(
		name: string,
		partSize: Vector3,
		offset: CFrame,
		color: Color3?,
		round: boolean?
	)
		local p = addPart(model, body, name, partSize, offset, color or PART_GRAY, false)
		if round then
			p.Shape = Enum.PartType.Cylinder
		end
		p.CanQuery = false
		p.CanTouch = false
		return p
	end
	local wheels, engine, armor = build.parts.wheels, build.parts.engine, build.parts.armor
	local wd = math.max(1.4, sy * 1.1)
	if wheels == "racing" or wheels == "grip" then
		local wide = if wheels == "grip" then 1.6 else 0.7
		local diameter = if wheels == "racing" then wd * 1.15 else wd
		for _, wx in { -1, 1 } do
			for _, wz in { -0.32, 0.32 } do
				gray(
					"WheelPart",
					Vector3.new(wide, diameter, diameter),
					CFrame.new(wx * (sx / 2 + wide / 2), -sy / 2 + diameter * 0.35, wz * sz),
					PART_DARK,
					true
				)
			end
		end
	end
	if engine == "turbo" then
		gray(
			"EnginePart",
			Vector3.new(sx * 0.45, sy * 0.5, sz * 0.22),
			CFrame.new(0, sy / 2 + sy * 0.3, sz * 0.32)
		)
		gray(
			"EngineFan",
			Vector3.new(0.3, sy * 0.5, sy * 0.5),
			CFrame.new(0, sy / 2 + sy * 0.3, sz * 0.32 + sz * 0.12),
			PART_DARK,
			true
		).CFrame *= CFrame.Angles(
			0,
			math.rad(90),
			0
		)
	elseif engine == "power" then
		for _, ex in { -1, 1 } do
			gray(
				"EnginePart",
				Vector3.new(sz * 0.3, 0.8, 0.8),
				CFrame.new(ex * sx * 0.28, sy / 2 + 0.6, sz * 0.38)
					* CFrame.Angles(0, math.rad(90), 0),
				PART_GRAY,
				true
			)
		end
	end
	if armor == "plates" then
		for _, ax in { -1, 1 } do
			gray(
				"ArmorPart",
				Vector3.new(0.5, sy * 0.9, sz * 0.8),
				CFrame.new(ax * (sx / 2 + 0.25), 0, 0)
			)
		end
		gray("ArmorPart", Vector3.new(sx, sy * 0.7, 0.5), CFrame.new(0, 0, sz / 2 + 0.25))
	elseif armor == "spikes" then
		for i = -2, 2 do
			gray(
				"ArmorPart",
				Vector3.new(0.7, 0.7, 2.2),
				CFrame.new(i * sx * 0.2, sy * 0.1, -sz / 2 - 1.1)
			)
		end
		for _, ax in { -1, 1 } do
			gray(
				"ArmorPart",
				Vector3.new(1.8, 0.7, 0.7),
				CFrame.new(ax * (sx / 2 + 0.9), sy * 0.1, -sz * 0.2)
			)
		end
	elseif armor == "ram" then
		gray(
			"ArmorPart",
			Vector3.new(sx * 0.95, sy * 0.6, sz * 0.25),
			CFrame.new(0, -sy * 0.1, -sz / 2 - sz * 0.1) * CFrame.Angles(math.rad(-20), 0, 0)
		)
	end
end

function CarBuilder.build(
	id: string,
	idx: number,
	cf: CFrame,
	parent: Instance,
	label: string,
	isBot: boolean,
	look: Appearance.Appearance?,
	build: Build.BuildData?, -- build-and-watch: the stats come from the parts (nil = the plain car)
	fair: boolean? -- human vs human: ignore the level bonus and use Common ability strength
): Car
	local neutral = fair == true
	-- garage parts + part levels count only outside a fair human match (audit #51)
	local plain = Fairness.stats(CarConfig.Cars[id], build, neutral, Build.stats)
	local stats =
		Progress.applyLevel(plain, Fairness.level(if look then look.level else nil, neutral)) -- car level: more HP + damage (not in a fair human match)
	local cosmeticRarity = stats.rarity -- rarity = identity: the look keeps the real one (audit #45)
	stats.rarity = Fairness.rarity(stats.rarity, neutral)
	local sx, sy, sz = stats.size[1], stats.size[2], stats.size[3]
	local color = Color3.fromRGB(stats.rgb[1], stats.rgb[2], stats.rgb[3])
	local dark = Color3.fromRGB(35, 35, 40)

	local model = Instance.new("Model")
	model.Name = (if isBot then "BotCar_" else "PlayerCar_") .. id
	-- For the UI/Studio (audit #45, #48): the car's real rarity (look only) and its ability
	-- cooldown. AbilityReadyAt is workspace server time (0 = ready); Specials updates it.
	model:SetAttribute("CosmeticRarity", cosmeticRarity)
	local ownAbility = Abilities.forCar(stats)
	model:SetAttribute("AbilityCooldown", if ownAbility then ownAbility.cooldown else 0)
	model:SetAttribute("AbilityReadyAt", 0)
	local rarityLook = CarCatalog.styleFor(cosmeticRarity)
	model:SetAttribute(
		"TrailColor",
		Color3.fromRGB(rarityLook.trailRgb[1], rarityLook.trailRgb[2], rarityLook.trailRgb[3])
	)
	model:SetAttribute(
		"AbilityEffectColor",
		Color3.fromRGB(rarityLook.effectRgb[1], rarityLook.effectRgb[2], rarityLook.effectRgb[3])
	)

	-- Body: the only part with weight. Density is picked so the body mass equals stats.mass.
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(sx, sy, sz)
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Anchored = true -- stays anchored until launch
	body.CFrame = cf
	body.CustomPhysicalProperties = PhysicalProperties.new(
		stats.mass / (sx * sy * sz),
		GameConfig.Drive.groundFriction,
		0.45,
		1,
		1
	)
	body:SetAttribute("CarIdx", idx)
	body.Parent = model
	-- Rare cars glow in their rarity color (look only; Common has none).
	if cosmeticRarity ~= "Common" and CarCatalog.RarityStyle[cosmeticRarity] then
		local rgb = rarityLook.effectRgb
		local light = Instance.new("PointLight")
		light.Name = "RarityGlow"
		light.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
		light.Range = if cosmeticRarity == "Legendary"
			then 20
			elseif cosmeticRarity == "Epic" then 16
			else 12
		light.Brightness = 2.5
		light.Parent = body
	end
	model.PrimaryPart = body

	local markerColor = if idx == 1
		then Color3.fromRGB(80, 255, 120)
		else Color3.fromRGB(255, 150, 40)
	local carMesh = findCarMesh(id)
	local catalogModel = findCatalogModel((stats :: any).model)
	local markerY = sy * 0.8 + sy * 0.3 + 0.15
	if catalogModel then
		-- Catalog car: its own model, scaled so a sedan fills the hitbox length (longer vehicles
		-- come out a bit bigger, shorter ones smaller, but not by the full ratio), standing on the
		-- hitbox bottom. The box body stays as the invisible physics part.
		local visual = catalogModel:Clone()
		local _, extent = visual:GetBoundingBox()
		local length = sz * math.sqrt(extent.Z / 14) * CarLook.Config.visualBoost
		visual:ScaleTo(visual:GetScale() * length / extent.Z)
		visual:PivotTo(body.CFrame * CFrame.new(0, -sy / 2, 0))
		local top = 0
		for _, d in visual:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true -- stays anchored until launch
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = true
				d:SetAttribute("CarIdx", idx)
				if d.Name == "Body" then
					d.Name = "Visual" -- Appearance paints the part with this name
					d.Color = color
				else
					d.Color = dark
				end
				if CarLook.isWheel(d.Name) then
					-- A joint (not a weld) so the client can roll the wheel by setting Transform.
					local motor = Instance.new("Motor6D")
					motor.Name = "WheelMotor"
					motor.Part0 = body
					motor.Part1 = d
					motor.C0 = body.CFrame:ToObjectSpace(d.CFrame)
					motor.Parent = d
					d:SetAttribute("WheelRadius", CarLook.wheelRadius(d.Size.Y, d.Size.Z))
				else
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = body
					weld.Part1 = d
					weld.Parent = d
				end
				top = math.max(top, d.Position.Y + d.Size.Y / 2)
			end
		end
		for _, d in visual:GetChildren() do
			d.Parent = model
		end
		visual:Destroy()
		body.Transparency = 1
		markerY = top - body.Position.Y + 0.6
	elseif carMesh then
		-- Real model: scaled so its length fills the hitbox length, bottom on the hitbox bottom,
		-- nose to -Z. The box body stays as the (invisible) physics part.
		local scale = sz / carMesh.Size.X
		local visual = carMesh:Clone()
		visual.Name = "Visual"
		visual.Size = carMesh.Size * scale
		if visual.TextureID == "" then
			visual.Color = color -- an untextured model takes the car colour; a textured one keeps its own
		end
		visual.Anchored = true -- stays anchored until launch
		visual.CanCollide = false
		visual.CanQuery = false
		visual.CanTouch = false
		visual.Massless = true
		visual.CFrame = body.CFrame
			* CFrame.new(0, -sy / 2 + visual.Size.Y / 2, 0)
			* CFrame.Angles(0, math.rad(90), 0)
		visual:SetAttribute("CarIdx", idx)
		visual.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = visual
		weld.Parent = visual
		body.Transparency = 1
		markerY = -sy / 2 + visual.Size.Y + 0.6
	else
		-- Cabin (dark window block) and 4 wheels (decoration only; the car is pushed by forces,
		-- wheels do not turn).
		addPart(
			model,
			body,
			"Cabin",
			Vector3.new(sx * 0.8, sy * 0.6, sz * 0.35),
			CFrame.new(0, sy * 0.8, sz * 0.1),
			color:Lerp(dark, 0.5),
			false
		)
		local wd = math.max(1.2, sy * 0.9)
		for _, wx in { -1, 1 } do
			for _, wz in { -0.3, 0.3 } do
				addPart(
					model,
					body,
					"Wheel",
					Vector3.new(0.9, wd, wd),
					CFrame.new(wx * (sx / 2 + 0.2), -sy / 2 + wd * 0.3, wz * sz),
					dark,
					false
				)
			end
		end
	end

	-- Team marker (green = you, orange = bot) so you can tell cars apart.
	local marker = addPart(
		model,
		body,
		"Marker",
		Vector3.new(1.2, 0.3, 1.2),
		CFrame.new(0, markerY, sz * 0.1),
		markerColor,
		false
	)
	marker.Material = Enum.Material.Neon

	if build then
		attachBuild(model, body, Vector3.new(sx, sy, sz), build)
	end
	-- Soft shadow blob under the car (cars no longer look like they float).
	local look3 = CarLook.Config
	local shadow = addPart(
		model,
		body,
		"Shadow",
		Vector3.new(look3.shadowThickness, sx * look3.shadowWidth, sz * look3.shadowLength),
		CFrame.new(0, -sy / 2 + look3.shadowThickness, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.new(0, 0, 0),
		false
	)
	shadow.Shape = Enum.PartType.Cylinder
	shadow.Transparency = look3.shadowTransparency
	shadow.CastShadow = false
	shadow.CanQuery = false
	shadow.CanTouch = false
	-- Toy outline by rarity: dark for Common, brighter for rarer cars.
	local rgb = CarLook.outlineRgb(cosmeticRarity)
	local outline = Instance.new("Highlight")
	outline.Name = "CarOutline"
	outline.Adornee = model
	outline.FillTransparency = 1
	outline.OutlineColor = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model
	Appearance.apply(model, body, look)
	Badge.apply(model, body, if look then look.level else nil)

	model.Parent = parent

	local bar = HpBar.create(body, label .. " " .. stats.name, sy + 3, markerColor)
	bar.set(stats.hp, stats.hp)

	return {
		idx = idx,
		id = id,
		stats = stats,
		model = model,
		body = body,
		hp = stats.hp,
		dead = false,
		ai = Ai.newMemory(stats.ai, if idx == 1 then 1 else -1),
		flipTimer = 0,
		prevVel = Vector3.zero,
		bar = bar,
		smoking = false,
	}
end

return CarBuilder
