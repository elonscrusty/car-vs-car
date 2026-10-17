--!strict
-- Builds one placeholder car: a heavy box body plus massless welded decoration parts.
-- The car faces -Z (its LookVector). Only the Body has weight; everything else is Massless.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Ai = require(ReplicatedStorage.Shared.Ai)
local Build = require(ReplicatedStorage.Shared.Build)
local CarConfig = require(ReplicatedStorage.Shared.CarConfig)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
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
	build: Build.BuildData? -- build-and-watch: the stats come from the parts (nil = the plain car)
): Car
	local stats = if build then Build.stats(CarConfig.Cars[id], build) else CarConfig.Cars[id]
	local sx, sy, sz = stats.size[1], stats.size[2], stats.size[3]
	local color = Color3.fromRGB(stats.rgb[1], stats.rgb[2], stats.rgb[3])
	local dark = Color3.fromRGB(35, 35, 40)

	local model = Instance.new("Model")
	model.Name = (if isBot then "BotCar_" else "PlayerCar_") .. id

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
	model.PrimaryPart = body

	local markerColor = if idx == 1
		then Color3.fromRGB(80, 255, 120)
		else Color3.fromRGB(255, 150, 40)
	local carMesh = findCarMesh(id)
	local markerY = sy * 0.8 + sy * 0.3 + 0.15
	if carMesh then
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

	-- Per-type look (placeholder shapes; skipped when a real model is used).
	if carMesh == nil then
		if id == "Heavy" then
			addPart(
				model,
				body,
				"Bumper",
				Vector3.new(sx, 1, 1),
				CFrame.new(0, -sy * 0.2, -sz / 2 - 0.5),
				Color3.fromRGB(70, 70, 75),
				true
			)
		elseif id == "Ramp" then
			-- Tilted plate in front: low at the nose, rising toward the body.
			addPart(
				model,
				body,
				"RampPlate",
				Vector3.new(sx * 0.95, 0.5, sz * 0.55),
				CFrame.new(0, -sy * 0.15, -sz / 2 - 1.2) * CFrame.Angles(math.rad(-25), 0, 0),
				Color3.fromRGB(150, 190, 255),
				true
			)
		elseif id == "Spike" then
			local metal = Color3.fromRGB(200, 205, 215)
			for _, sxo in { -0.3, 0, 0.3 } do
				local len = if sxo == 0 then 4.5 else 3
				addPart(
					model,
					body,
					"Spike",
					Vector3.new(0.6, 0.6, len),
					CFrame.new(sxo * sx, 0, -sz / 2 - len / 2),
					metal,
					true
				)
			end
		end
	end

	if build then
		attachBuild(model, body, Vector3.new(sx, sy, sz), build)
	end
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
