--!strict
-- Puts a plot's star look on it (PlotLooks): night tint + lamps, snow, party. Called by Stars
-- whenever an owner's stars change; only rebuilds when the tier changes. Every piece is looks
-- only: no collisions, no touches, and never hit by the car's suspension rays.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Garage = require(ReplicatedStorage.Shared.Garage)
local PlotLooks = require(ReplicatedStorage.Shared.PlotLooks)

local PlotLooksBuilder = {}

local function tint(plot: Model, on: boolean)
	for _, d in plot:GetDescendants() do
		if not d:IsA("BasePart") or d.Material == Enum.Material.Neon then
			continue
		end
		local day = d:GetAttribute("DayColor")
		if on then
			if typeof(day) ~= "Color3" then
				day = d.Color
				d:SetAttribute("DayColor", day)
			end
			local c = day :: Color3
			local n = PlotLooks.nightColor({ c.R * 255, c.G * 255, c.B * 255 })
			d.Color = Color3.fromRGB(n[1], n[2], n[3])
		elseif typeof(day) == "Color3" then
			d.Color = day
		end
	end
end

local function snowFall(cloud: BasePart)
	cloud.Transparency = 1
	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.Color = ColorSequence.new(Color3.new(1, 1, 1))
	p.LightEmission = 0.3
	p.Size = NumberSequence.new(0.25)
	p.Rate = 25
	p.Lifetime = NumberRange.new(7, 9)
	p.Speed = NumberRange.new(2.5, 3.5)
	p.SpreadAngle = Vector2.new(10, 10)
	p.EmissionDirection = Enum.NormalId.Bottom
	p.Acceleration = Vector3.new(0.4, 0, 0)
	p.Parent = cloud
end

local function searchlight(lamp: BasePart)
	local s = Instance.new("SpotLight")
	s.Face = Enum.NormalId.Front
	s.Range = 45
	s.Angle = 25
	s.Brightness = 3
	s.Color = lamp.Color
	s.Parent = lamp
	CollectionService:AddTag(lamp, "StarSearch")
end

-- `pivot` = the plot's middle on the floor, facing its front (as PlotDecorBuilder).
function PlotLooksBuilder.apply(plot: Model, pivot: CFrame, tier: number)
	if plot:GetAttribute("LookTier") == tier then
		return
	end
	local old = plot:FindFirstChild("Looks")
	if old then
		old:Destroy()
	end
	tint(plot, tier >= 1)
	plot:SetAttribute("LookTier", tier)
	if tier == 0 then
		return
	end
	local looks = Instance.new("Model")
	looks.Name = "Looks"
	Garage.makeParts(PlotLooks.pieces(tier), looks, pivot)
	for _, d in looks:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if d.Name == "SnowCloud" then
				snowFall(d)
			elseif d.Name == "SearchLamp" then
				searchlight(d)
			elseif string.sub(d.Name, 1, 3) == "Fan" then
				CollectionService:AddTag(d, "StarFan")
			end
		end
	end
	looks.Parent = plot
end

return PlotLooksBuilder
