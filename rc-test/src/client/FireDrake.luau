--!strict
-- The Fire Drake: two dragon heads grown out of the black+red car's front fenders (carter's pick
-- 1 "Fender Heads", 10-29), with the Fire Swarm tubes resting between their jaws. The weapon is part
-- of the car's body, not stuck on top.
--
-- The car model (ReplicatedStorage.CarSkins.race_bolt) lives only in carter's place, so the heads
-- are made here from plain parts (shared/FireDrakeData) and added to that model once per device,
-- sized by the car's body. After that they are ordinary parts of the model: CarSkin carries them on
-- the driving car (its Extras) and OtherCars on everyone else's. The heads are look-only.
--
-- To try it on another car: add its id to FireDrake.CARS. To tune where the heads sit, change
-- FireDrakeData.PLACE (fractions of the body) and look at it close up in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.FireDrakeData)

local FireDrake = {}

-- the CarSkins models that wear the heads
FireDrake.CARS = { race_bolt = true } :: { [string]: boolean }

local MIN_SIZE = 0.05 -- Roblox's smallest part

function FireDrake.wants(name: string): boolean
	return FireDrake.CARS[name] == true
end

local function color(key: string): Color3
	local c = Data.COLORS[key]
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function made(spec: Data.Spec, u: number, at: CFrame): BasePart
	local p: BasePart
	if spec.shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		if spec.shape == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		end
		p = part
	end
	p.Name = "Drake" .. spec.name
	p.Size = Vector3.new(
		math.max(spec.size[1] * u, MIN_SIZE),
		math.max(spec.size[2] * u, MIN_SIZE),
		math.max(spec.size[3] * u, MIN_SIZE)
	)
	p.CFrame = at
		* CFrame.new(spec.at[1] * u, spec.at[2] * u, spec.at[3] * u)
		* CFrame.Angles(math.rad(spec.rot[1]), math.rad(spec.rot[2]), math.rad(spec.rot[3]))
	p.Color = color(spec.mat)
	p.Material = if spec.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.Massless = true
	p.CastShadow = false
	return p
end

-- Adds the two heads to a car model (once; later calls do nothing). Needs the model's Body and
-- the Extras attribute: CarSkin only carries a model's other parts when it has that.
function FireDrake.addTo(model: Model)
	if model:GetAttribute("DrakeAdded") ~= nil then
		return
	end
	model:SetAttribute("DrakeAdded", false)
	local body = model:FindFirstChild("Body", true)
	if not (body and body:IsA("BasePart")) or body.Size.Z <= 0 then
		return
	end
	if model:GetAttribute("Extras") ~= true then
		warn(`FireDrake: {model.Name} needs its Extras attribute set, or its heads would not show`)
		return
	end
	local u = body.Size.Z / Data.DESIGN_LENGTH
	local place = Data.PLACE
	local folder = Instance.new("Folder")
	folder.Name = "Drake"
	for _, side in { 1, -1 } do
		local at = body.CFrame
			* CFrame.new(
				side * place.x * body.Size.X,
				(place.y - 0.5) * body.Size.Y,
				place.z * body.Size.Z
			)
		for _, spec in Data.pod() do
			local s = if side > 0 then spec else Data.mirror(spec)
			local p = made(s, u, at)
			p.Name ..= if side > 0 then "R" else "L"
			p.Parent = folder
		end
	end
	folder.Parent = model
	model:SetAttribute("DrakeAdded", true)
end

return FireDrake
