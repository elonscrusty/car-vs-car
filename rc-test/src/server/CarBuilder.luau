--!strict
-- Builds the little RC car. Only the body is solid: the player's own device adds the wheels and
-- does all the pushing, so the car answers instantly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToyCars = require(ReplicatedStorage.Shared.ToyCars)
local Tuning = require(ReplicatedStorage.Shared.Tuning)

local CarBuilder = {}

local function addPart(
	model: Model,
	body: Part,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.Massless = true
	p.CFrame = body.CFrame * offset
	p.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = p
	weld.Parent = p
	return p
end

function CarBuilder.build(name: string, cf: CFrame, scale: number): Model
	local model = Instance.new("Model")
	model.Name = name

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(Tuning.bodyX, Tuning.bodyY, Tuning.bodyZ)
	body.Color = Color3.fromRGB(220, 50, 47)
	body.Material = Enum.Material.SmoothPlastic
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.CustomPhysicalProperties = PhysicalProperties.new(1, 0.05, 0, 1, 1)
	body.CFrame = cf
	body.Parent = model
	model.PrimaryPart = body

	local dark = Color3.fromRGB(35, 35, 40)
	addPart(model, body, "Cab", Vector3.new(2.2, 0.9, 2.4), CFrame.new(0, 0.9, 0.5), dark)
	addPart(model, body, "SpoilerWing", Vector3.new(3.2, 0.2, 0.9), CFrame.new(0, 1.2, 2.5), dark)
	addPart(
		model,
		body,
		"SpoilerLeft",
		Vector3.new(0.2, 0.7, 0.5),
		CFrame.new(-1.2, 0.8, 2.5),
		dark
	)
	addPart(
		model,
		body,
		"SpoilerRight",
		Vector3.new(0.2, 0.7, 0.5),
		CFrame.new(1.2, 0.8, 2.5),
		dark
	)
	local lamp = Color3.fromRGB(255, 240, 170)
	addPart(model, body, "LampLeft", Vector3.new(0.6, 0.3, 0.2), CFrame.new(-1, 0.1, -2.75), lamp)
	addPart(model, body, "LampRight", Vector3.new(0.6, 0.3, 0.2), CFrame.new(1, 0.1, -2.75), lamp)
	-- the hat spot (REWARDS welds the kart topper here): on top of the toy kart driver's head,
	-- worked out like CarSkin lines the toy kart up (its wheels' middle at the parked spring
	-- length, sized to the body's length), +Y up
	local rest =
		math.clamp(Tuning.maxSusp - workspace.Gravity / (Tuning.springOmega ^ 2), 0, Tuning.maxSusp)
	local toy = Tuning.bodyZ / 3.6 -- Garage.toyFit
	local topper = Instance.new("Attachment")
	topper.Name = "Topper"
	topper.Position =
		Vector3.new(0, Tuning.attachY - rest + (ToyCars.HEAD_TOP - 0.5) * toy, 0.3 * toy)
	topper.Parent = body
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	return model
end

return CarBuilder
