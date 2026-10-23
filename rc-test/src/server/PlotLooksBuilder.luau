--!strict
-- Shows each lobby plot's look for its owner's stars (PlotLooks): watches the plot model's
-- OwnerStars attribute (set by Stars.server; a Studio-only TestStars attribute wins over it for
-- tests) and, when the tier changes, rebuilds the plot's Looks folder: night tints the plot and
-- turns its lamps on, snow adds snow and a light snowfall, the top tier adds string lights,
-- fans and searchlights. Looks only: colours change, sizes and collisions never do.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Garage = require(ReplicatedStorage.Shared.Garage)
local LobbyLayout = require(ReplicatedStorage.Shared.LobbyLayout)
local PlotLooks = require(ReplicatedStorage.Shared.PlotLooks)

local PlotLooksBuilder = {}

local DAY = "DayColor" -- attribute holding a part's own colour while it is tinted

-- night tint on the plot's own parts (called with the Looks folder gone; neon stays bright)
local function tint(plot: Model, on: boolean)
	for _, d in plot:GetDescendants() do
		if not d:IsA("BasePart") or d.Material == Enum.Material.Neon then
			continue
		end
		local day = d:GetAttribute(DAY)
		if on then
			if day == nil then
				d:SetAttribute(DAY, d.Color)
				d.Color = d.Color:Lerp(Color3.fromRGB(20, 26, 60), 1 - PlotLooks.NIGHT_TINT)
			end
		elseif typeof(day) == "Color3" then
			d.Color = day
			d:SetAttribute(DAY, nil)
		end
	end
end

local function snowfall(cloud: BasePart)
	cloud.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Rate = PlotLooks.SNOW_RATE
	e.Lifetime = NumberRange.new(8, 10)
	e.Speed = NumberRange.new(3, 4)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(10, 10)
	e.Size = NumberSequence.new(0.25)
	e.Color = ColorSequence.new(Color3.new(1, 1, 1))
	e.LightEmission = 0.3
	e.Parent = cloud
end

local function apply(plot: Model, pivot: CFrame, kind: string, t: number)
	local old = plot:FindFirstChild("Looks")
	if old then
		old:Destroy()
	end
	tint(plot, t >= 1)
	-- PlotDecor's lanterns glow brighter at night
	for _, d in plot:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Lantern" or d.Name == "Light") then
			local light = d:FindFirstChildOfClass("PointLight")
			if t >= 1 and not light and d.Name == "Lantern" then
				local glow = Instance.new("PointLight")
				glow.Name = "NightLight"
				glow.Range = 14
				glow.Brightness = 1.5
				glow.Color = d.Color
				glow.Parent = d
			elseif t == 0 and light and light.Name == "NightLight" then
				light:Destroy()
			end
		end
	end
	if t == 0 then
		return
	end
	local looks = Instance.new("Model")
	looks.Name = "Looks"
	Garage.makeParts(PlotLooks.allParts(kind, t), looks, pivot)
	for _, d in looks:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
			if d.Name == "SnowCloud" then
				snowfall(d)
			elseif d.Name == "SearchBeam" then
				d.Transparency = 0.75
			end
		end
	end
	looks.Parent = plot
end

local function stars(plot: Model): number
	local test = plot:GetAttribute("TestStars")
	if RunService:IsStudio() and typeof(test) == "number" then
		return test
	end
	local s = plot:GetAttribute("OwnerStars")
	return if typeof(s) == "number" then s else 0
end

function PlotLooksBuilder.start()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, slot in LobbyLayout.slots() do
		local plot = plots:FindFirstChild(slot.index .. "_" .. slot.id)
		if not (plot and plot:IsA("Model")) then
			continue
		end
		local pivot = CFrame.new(slot.plotX, 0, slot.plotZ) * CFrame.Angles(0, slot.angle, 0)
		local shown = 0
		local function update()
			local t = PlotLooks.tier(stars(plot))
			if t ~= shown then
				shown = t
				apply(plot, pivot, slot.id, t)
			end
		end
		plot:GetAttributeChangedSignal("OwnerStars"):Connect(update)
		plot:GetAttributeChangedSignal("TestStars"):Connect(update)
		update()
	end
end

return PlotLooksBuilder
