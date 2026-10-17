--!strict
-- Builds one placeholder car: a heavy box body plus massless welded decoration parts.
-- The car faces -Z (its LookVector). Only the Body has weight; everything else is Massless.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ai = require(ReplicatedStorage.Shared.Ai)
local CarConfig = require(ReplicatedStorage.Shared.CarConfig)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local HpBar = require(script.Parent.HpBar)

export type Car = {
	idx: number, -- 1 = player, 2 = bot
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
}

local CarBuilder = {}

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

function CarBuilder.build(id: string, idx: number, cf: CFrame, parent: Instance): Car
	local stats = CarConfig.Cars[id]
	local sx, sy, sz = stats.size[1], stats.size[2], stats.size[3]
	local color = Color3.fromRGB(stats.rgb[1], stats.rgb[2], stats.rgb[3])
	local dark = Color3.fromRGB(35, 35, 40)

	local model = Instance.new("Model")
	model.Name = (if idx == 1 then "PlayerCar_" else "BotCar_") .. id

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

	-- Cabin + team marker (green = you, orange = bot) so you can tell cars apart.
	addPart(
		model,
		body,
		"Cabin",
		Vector3.new(sx * 0.8, sy * 0.6, sz * 0.35),
		CFrame.new(0, sy * 0.8, sz * 0.1),
		color:Lerp(dark, 0.5),
		false
	)
	local markerColor = if idx == 1
		then Color3.fromRGB(80, 255, 120)
		else Color3.fromRGB(255, 150, 40)
	local marker = addPart(
		model,
		body,
		"Marker",
		Vector3.new(1.2, 0.3, 1.2),
		CFrame.new(0, sy * 0.8 + sy * 0.3 + 0.15, sz * 0.1),
		markerColor,
		false
	)
	marker.Material = Enum.Material.Neon

	-- 4 wheels (decoration only; the car is pushed by forces, wheels do not turn).
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

	-- Per-type look (placeholder shapes).
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

	model.Parent = parent

	local bar =
		HpBar.create(body, (if idx == 1 then "YOU " else "BOT ") .. stats.name, sy + 3, markerColor)
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
	}
end

return CarBuilder
